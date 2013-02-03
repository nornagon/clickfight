canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 1024
canvas.height = 768

ctx = canvas.getContext '2d'

ws = new WebSocket "ws://#{window.location.host}"
#ws.binaryType = 'arraybuffer'

ws.onerror = (e) -> console.log e

entities = null

# The entity that represents the local player
avatar = null

# Frame count is measured in dt units. Eg, frame 62 is 1 second after frame 0.
frame = 0

# The world is always lerping between lerpA and lerpB. The world pauses when lerpB is undefined.
# in frames after pendingSnapshots[0]
lerpA = lerpB = null
pendingUpdates = []
lastReceivedUpdate = null

# World update frequency in seconds. 62.5fps.
serverDt = 16 / 1000

# Is a redraw required?
dirty = false

locked = false

fps = 0
serverFrame = 0
renderFramesAhead = 0.1 / serverDt
serverFrameTarget = 0

renderFrame = 0

send = (msg) ->
  ws.send JSON.stringify msg

update = (dt) ->
  if dt
    fps = 0.7*fps + 0.3 / dt

  return unless lerpA and lerpB

  dtInFrames = dt / serverDt
  if Math.abs(serverFrame - serverFrameTarget) > 1
    if serverFrameTarget < serverFrame
      serverFrame += dtInFrames * 0.9
    else if serverFrameTarget > serverFrame
      serverFrame += dtInFrames * 1.1

  serverFrameTarget += dt / serverDt

  # Render frame is ~100ms behind
  renderFrame = serverFrame - renderFramesAhead

  while renderFrame > lerpB.f
    if pendingUpdates.length == 0
      # Out of data. Pause simulation.
      renderFrame = lerpB.f
      serverFrame = lerpB.f + renderFramesAhead
    else
      lerpA = lerpB
      lerpB = pendingUpdates.shift()

      delete entities[id] for id in lerpA.remove if lerpA.remove
      entities[id] = e for id, e of lerpA.add if lerpA.add

  lerpPoint = Math.max 0, (renderFrame - lerpA.f) / (lerpB.f - lerpA.f)

  for id, d1 of lerpA.data when id isnt avatar.id and d1 isnt null
    d2 = lerpB.data[id]
    continue if d2 is null # the object is about to be removed.

    e = entities[id]

    e.x = v.lerp2 d1.x, d2.x, lerpPoint
    e.y = v.lerp2 d1.y, d2.y, lerpPoint


  # Update the local player

  if avatar
    if !locked
      avatar.dx = 2 * Math.sin Date.now()/1000
      avatar.dy = 2 * Math.cos Date.now()/1700

    if avatar.dx or avatar.dy
      avatar.x += avatar.dx
      avatar.y += avatar.dy
      avatar.dx = avatar.dy = 0

      avatar.x = v.clamp avatar.x, 0, canvas.width
      avatar.y = v.clamp avatar.y, 0, canvas.height
      avatar.dirty = true

  # Update all the text
  for k, cs of chars
    c.update dt for c in cs
    chars[k] = (c for c in cs when not c.dead)


setInterval ->
  if avatar?.dirty
    ws.send JSON.stringify
      t:'p'
      x:Math.floor avatar.x
      y:Math.floor avatar.y
      f:0.1 * Math.floor renderFrame * 10
    avatar.dirty = false
, serverDt

draw = ->
  if entities
    ctx.fillStyle = 'thistle'
    ctx.fillRect 0, 0, canvas.width, canvas.height
  
    for id, e of entities
      ctx.fillStyle = if e is avatar then 'blue' else 'black'
      ctx.fillRect e.x-5, e.y-5, 10, 10

    # FPS display
    ctx.fillStyle = 'black'
    #ctx.font = "20px sans-serif"
    #ctx.textAlign = 'start'
    ctx.fillText "FPS:", 30, 80
    #ctx.textAlign = 'end'
    ctx.fillText Math.floor(10*fps)/10, 140, 80

  else
    ctx.fillStyle = 'white'
    ctx.fillRect 0, 0, canvas.width, canvas.height


  for k,cs of chars
    c.draw() for c in cs
  
raf = window.requestAnimationFrame or window.mozRequestAnimationFrame or
        window.webkitRequestAnimationFrame or window.msRequestAnimationFrame

oldT = 0
frame = (t) ->
  t = Date.now()
  t /= 1000 # in seconds please.
  update t-oldT
  oldT = t
  draw()
  raf frame

frame 0

ws.onclose = ->
  entities = null
  avatar = null

ws.onmessage = (msg) ->
  msg = JSON.parse msg.data

  copy = (e) -> {x:e.x, y:e.y}

  switch msg.t
    when 's'
      entities = msg.entities
      avatar = entities[msg.yourid]
      avatar.id = msg.yourid
      avatar.dx = avatar.dy = 0
      data = {}
      data[id] = copy e for id, e of msg.entities
      lerpA = lastReceivedUpdate = {f:msg.f, data}

      serverFrame = msg.f
    when 'u'
      #console.log JSON.stringify msg
      data = {}
      data[id] = null for id in msg.r if msg.r # Remove
      data[id] = copy e for id, e of msg.a if msg.a # Add
      data[id] = copy e for id, e of msg.u # Update
      # & copy in anything else that hasn't been updated
      data[id] = copy e for id, e of lastReceivedUpdate.data when data[id] is undefined and e
 
      lastReceivedUpdate = f:msg.f, data:data, add:msg.a, remove:msg.r
      
      if lerpB
        pendingUpdates.push lastReceivedUpdate
      else
        lerpB = lastReceivedUpdate

      serverFrameTarget = msg.f
    when 'say'
      playerTyped msg.p, msg.x, msg.y, msg.c
    when 'backspace'
      playerBackspaced msg.p
    else
      console.log msg

FONT = 'bold 14px helvetica'
class Char
  constructor: (@x, @y, @c, @life=6+Math.random()*0.5) ->
    ctx.font = FONT
    @width = ctx.measureText(@c).width
    @maxLife = @life
  update: (dt) ->
    @life -= dt
    if @life <= 0
      @dead = yes
  draw: ->
    fadeIn = if (@maxLife-@life) < 0.2
      (@maxLife-@life) / 0.2
    else
      1
    fadeOut = if @life < 0.2
      @life/0.2
    else
      1
    ctx.font = FONT
    ctx.fillStyle = 'black'
    ctx.globalAlpha = Math.min fadeOut, fadeIn
    ctx.fillText @c, @x, @y + (1-fadeIn)*20
    ctx.globalAlpha = 1
chars = {}

playerTyped = (playerId, x, y, c) ->
  (chars[playerId] ?= []).push char = new Char x, y, c
  char
playerBackspaced = (playerId) ->
  if chars[playerId]?.length
    chars[playerId].pop()

whereWasILastSpeaking = null
lastAdvance = 0
MOVE_THRESHOLD = 40
dist = ({x:x0,y:y0}, {x:x1,y:y1}) -> dx = x0-x1; dy = y0-y1; Math.sqrt dx*dx + dy*dy
sayChars = (cs) ->
  moved = (!whereWasILastSpeaking or dist({x:avatar.x,y:avatar.y}, whereWasILastSpeaking) > MOVE_THRESHOLD)
  if moved
    whereWasILastSpeaking = {x:avatar.x, y:avatar.y}

  if chars[avatar.id]?.length is 0 or moved
    lastAdvance = 0

  x = whereWasILastSpeaking.x - 40 + lastAdvance
  y = whereWasILastSpeaking.y - 40

  c = playerTyped avatar.id, x, y, cs
  send {t:'say',p:avatar.id,x,y,c:cs}
  lastAdvance += c.width

window.onkeypress = (e) ->
  sayChars String.fromCharCode e.charCode
window.onkeydown = (e) ->
  if e.which is 8
    if chars[avatar.id].length
      c = playerBackspaced avatar.id
      send {t:'backspace',p:avatar.id}
      lastAdvance -= c.width
    e.preventDefault()

mousemove = (e) ->
  return unless avatar
  avatar.dx += e.webkitMovementX
  avatar.dy += e.webkitMovementY

mousedown = (e) ->
mouseup = (e) ->

canvas.addEventListener 'click', lockPointer = ->
  canvas.webkitRequestPointerLock()

document.addEventListener 'keydown', (e) ->
  if e.keyCode is 192
    drawShapes = !drawShapes
  if e.keyCode is 'S'.charCodeAt 0
    ws.send JSON.stringify {t:'s'}

document.addEventListener 'webkitpointerlockchange', ->
  if document.webkitPointerLockElement is canvas
    locked = true
    canvas.addEventListener 'mousemove', mousemove
    canvas.addEventListener 'mousedown', mousedown
    canvas.addEventListener 'mouseup', mouseup
    canvas.removeEventListener 'click', lockPointer
  else
    locked = false
    canvas.removeEventListener 'mousemove', mousemove
    canvas.removeEventListener 'mousedown', mousedown
    canvas.removeEventListener 'mouseup', mouseup
    canvas.addEventListener 'click', lockPointer


