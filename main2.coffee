canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 1224
canvas.height = 768

ctx = canvas.getContext '2d'

playerX = canvas.width/2
playerY = canvas.height/2
attacking = false
attackTime = 0
AttackMs = 250

offX = 0
offY = 0
dir = 0

maxSpeed = 900 # px/s

class Line
  constructor: (@x, @y, @dx, @dy) ->
  intersects: (o) ->
    den = (@dx*o.dy - @dy*o.dx)
    if den is 0
      return # parallel
    t = ((o.x - @x)*o.dy + (@y - o.y)*o.dx) / den
    if o.dx isnt 0
      t2 = @x/o.dx + t*@dx/o.dx - o.x/o.dx
    else
      t2 = @y/o.dy + t*@dy/o.dy - o.y/o.dy
    if 0 <= t < 1 and 0 <= t2 < 1
      return t

  dot: (o) -> @dx*o.dx + @dy*o.dy
  scale: (k) -> new Line @x, @y, @dx*k, @dy*k
  normal: ->
    d = @length()
    new Line @x, @y, @dx/d, @dy/d
  length: -> Math.sqrt(@dx*@dx+@dy*@dy)

lines = [
  new Line 10, 10, 100, 100
]

window.ctx = ctx

FONT = 'bold 14px helvetica'
class Char
  constructor: (@x, @y, @c, @life=2000) ->
    ctx.font = FONT
    @width = ctx.measureText(@c).width
  update: (dt) ->
    @life -= dt
    if @life <= 0
      @dead = yes
  draw: ->
    fadeIn = if (2000-@life) < 200
      (2000-@life) / 200
    else
      1
    fadeOut = if @life < 200
      @life/200
    else
      1
    ctx.font = FONT
    ctx.fillStyle = 'black'
    ctx.globalAlpha = Math.min fadeOut, fadeIn
    ctx.fillText @c, @x, @y + (1-fadeIn)*20
    ctx.globalAlpha = 1
chars = []

draw = ->
  ctx.clearRect 0, 0, canvas.width, canvas.height
  ctx.strokeStyle = 'black'
  for l in lines
    ctx.beginPath()
    ctx.moveTo l.x, l.y
    ctx.lineTo l.x+l.dx, l.y+l.dy
    ctx.stroke()

  for c in chars
    c.draw()


  ctx.save()
  ctx.translate playerX, playerY
  ctx.rotate Math.atan2 offY, offX
  m = maxSpeed*16/1000
  d = Math.min m, Math.sqrt(offX*offX+offY*offY)
  ctx.scale 1+d*1/m, 1 - d*0.2/m
  ctx.beginPath()
  ctx.arc 0, 0, 10, 0, Math.PI*2
  ctx.fillStyle = 'blue'
  ctx.fill()
  ctx.beginPath()
  ctx.moveTo 0, 0
  ctx.lineTo 10, 0
  ctx.strokeStyle = 'red'
  ctx.stroke()

  if attacking
    ctx.fillStyle = 'red'
    ctx.beginPath()
    ctx.moveTo 0, 0
    start = -Math.PI
    t = start + attackTime/AttackMs*Math.PI*2
    ctx.lineTo Math.cos(t)*30, Math.sin(t)*30
    ctx.arc 0, 0, 30, t, Math.max(start,t-0.6), true
    ctx.closePath()
    ctx.fill()

  ctx.restore()

update = (dt) ->
  targetX = playerX + offX
  targetY = playerY + offY
  dx = targetX - playerX
  dy = targetY - playerY
  d = Math.sqrt(dx*dx+dy*dy)
  if d > 0
    dir = Math.atan2 offY, offX

  minT = 1
  wall = undefined
  pvec = new Line(playerX, playerY, dx, dy)
  for l in lines
    t_int = pvec.intersects(l)
    if t_int and t_int < minT
      wall = l
      minT = t_int-1/d
  d *= minT
  t = Math.atan2 dy, dx

  targetX = playerX + Math.cos(t)*d
  targetY = playerY + Math.sin(t)*d

  d = Math.min d, maxSpeed*dt/1000
  playerX += d * Math.cos(t)
  playerY += d * Math.sin(t)

  if minT < 1
    # there was some remaining impetus; bend it past |wall|
    d = Math.sqrt(dx*dx+dy*dy)*(1-minT)
    c = wall.dot(pvec)/wall.length()/pvec.length()
    d *= c*c
    if d > 0
      dir = Math.atan2 offY, offX

    minT = 1
    dp = if pvec.dot(wall) < 0 then -1 else 1
    pvec = wall.normal().scale(dp*d)
    pvec.x = playerX
    pvec.y = playerY
    for l in lines when l isnt wall
      t_int = pvec.intersects(l)
      if t_int and t_int < minT
        minT = t_int-1/d
    d *= minT
    t = Math.atan2 pvec.dy, pvec.dx

    targetX = playerX + Math.cos(t)*d
    targetY = playerY + Math.sin(t)*d

    d = Math.min d, maxSpeed*dt/1000
    playerX += d * Math.cos(t)
    playerY += d * Math.sin(t)


  playerX = Math.max 0, Math.min canvas.width, playerX
  playerY = Math.max 0, Math.min canvas.height, playerY
  offX *= 0.04*dt
  offY *= 0.04*dt

  if attacking
    attackTime += dt
    if attackTime >= AttackMs
      attacking = false

  c.update dt for c in chars
  chars = (c for c in chars when not c.dead)


oldT = 0
frame = (t) ->
  update t-oldT
  oldT = t
  draw()
  webkitRequestAnimationFrame frame
frame(0)

mousemove = (e) ->
  offX += e.webkitMovementX
  offY += e.webkitMovementY

inp = document.body.appendChild(document.createElement('input'))
inp.style.opacity = '0.01'
mousedown = (e) ->
  return if attacking
  attacking = true
  attackTime = 0

mouseup = (e) ->

whereWasILastSpeaking = null
lastAdvance = 0
MOVE_THRESHOLD = 40
dist = ({x:x0,y:y0}, {x:x1,y:y1}) -> dx = x0-x1; dy = y0-y1; Math.sqrt dx*dx + dy*dy
sayChars = (cs) ->
  moved = (!whereWasILastSpeaking or dist({x:playerX,y:playerY}, whereWasILastSpeaking) > MOVE_THRESHOLD)
  if moved
    whereWasILastSpeaking = {x:playerX, y:playerY}

  if chars.length is 0 or moved
    lastAdvance = 0

  x = whereWasILastSpeaking.x - 40 + lastAdvance
  y = whereWasILastSpeaking.y - 40
  chars.push c = new Char x, y, cs
  lastAdvance += c.width

inp.addEventListener 'input', (e) ->
  sayChars inp.value
  inp.value = ''
inp.addEventListener 'keydown', (e) ->
  if e.which is 8
    c = chars.pop()
    lastAdvance -= c.width if c

canvas.addEventListener 'click', lockPointer = ->
  canvas.webkitRequestPointerLock()

document.addEventListener 'webkitpointerlockchange', ->
  if document.webkitPointerLockElement is canvas
    canvas.addEventListener 'mousemove', mousemove
    canvas.addEventListener 'mousedown', mousedown
    canvas.addEventListener 'mouseup', mouseup
    inp.focus()
    canvas.removeEventListener 'click', lockPointer
  else
    canvas.removeEventListener 'mousemove', mousemove
    canvas.removeEventListener 'mousedown', mousedown
    canvas.removeEventListener 'mouseup', mouseup
    inp.blur()
    canvas.addEventListener 'click', lockPointer
