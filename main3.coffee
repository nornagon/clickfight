canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 1024
canvas.height = 768
ctx = canvas.getContext '2d'
maxSpeed = 300 # px/s

#dt = 16

players =
  mouse:
    x:100
    y:100
    dx:0
    dy:0
  gamepad0:
    x:200
    y:100
    dx:0
    dy:0
  gamepad1:
    x:300
    y:100
    dx:0
    dy:0

room = new Entity

room.tpos = v.zero
room.trot = v.forangle 0
room.width = canvas.width
room.height = canvas.height
room.players = []
room.time = 0

do ->
  boss room

  for i,p of players
    do (p) ->
      player = room.addEntity()
      player.type = 'player'
      player.x = p.x
      player.y = p.y
      player.addShape circle 0, 0, 10
      player.on 'update', ->
        @x = p.x
        @y = p.y

      player.hp = 3
      player.damage = ->
        @hp--

      player.on 'draw', ->
        ctx.save()

        ctx.translate p.x, p.y
        ctx.rotate Math.atan2 p.dy, p.dx
        m = maxSpeed*16/1000
        d = Math.min m, Math.sqrt(p.dx * p.dx + p.dy * p.dy)
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

        ctx.fillStyle = 'red'
        for i in [0...@hp]
          x = Math.cos(i*Math.PI*2/3)*3
          y = Math.sin(i*Math.PI*2/3)*3
          ctx.beginPath()
          ctx.arc x, y, 3, 0, Math.PI*2
          ctx.fill()

        ctx.restore()

      room.players.push player


draw = ->
  ctx.fillStyle = 'thistle'
  ctx.fillRect 0, 0, canvas.width, canvas.height
  ctx.strokeStyle = 'black'

  ###
  for id, p of players
    ctx.save()
    ctx.translate p.x, p.y
    ctx.rotate Math.atan2 p.dy, p.dx
    m = maxSpeed*16/1000
    d = Math.min m, Math.sqrt(p.dx * p.dx + p.dy * p.dy)
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

    ctx.restore()
  ###
  room.draw()
  #room.forAll (e) -> e.draw()

#into.deadZoneLeftStick = 7849.0/32767.0;
#into.deadZoneRightStick = 8689/32767.0;

update = (dt) ->
  pads = navigator.webkitGetGamepads()
  for c, i in pads when c
    dead = 7849.0/32767.0
    dx = if Math.abs(c.axes[0]) > dead then c.axes[0] else 0
    dy = if Math.abs(c.axes[1]) > dead then c.axes[1] else 0

    if dx or dy
      angle = Math.atan2 dy, dx
      dist = dx * dx + dy * dy

      p = players["gamepad#{i}"]
      if p
        p.dir = angle
        p.dx = 20 * dist * Math.cos angle
        p.dy = 20 * dist * Math.sin angle



  for id, p of players
    d = Math.sqrt(p.dx*p.dx+p.dy*p.dy)
    if d > 0
      p.dir = Math.atan2 p.dy, p.dx
      t = Math.atan2 p.dy, p.dx
      d = Math.min d, maxSpeed*dt/1000
      p.x += d * Math.cos(t)
      p.y += d * Math.sin(t)
      p.x = Math.max 0, Math.min canvas.width, p.x
      p.y = Math.max 0, Math.min canvas.height, p.y
      p.dx *= 0.04*dt
      p.dy *= 0.04*dt

  room.update()

  shapes = []
  room.forAll (e) ->
    shapes = shapes.concat e.shapes if e.shapes
    e._touching.length = 0

  for a,x in shapes
    for b,y in shapes when x < y
      collisions = collide a, b
      if collisions.length
        a.owner._touching.push b.owner
        b.owner._touching.push a.owner
  room.time += 16

oldT = 0
frame = (t) ->
  update t-oldT
  oldT = t
  draw()
  webkitRequestAnimationFrame frame
frame(0)


mousemove = (e) ->
  players.mouse.dx += e.webkitMovementX
  players.mouse.dy += e.webkitMovementY

mousedown = (e) ->

mouseup = (e) ->

canvas.addEventListener 'click', lockPointer = ->
  canvas.webkitRequestPointerLock()

document.addEventListener 'webkitpointerlockchange', ->
  if document.webkitPointerLockElement is canvas
    canvas.addEventListener 'mousemove', mousemove
    canvas.addEventListener 'mousedown', mousedown
    canvas.addEventListener 'mouseup', mouseup
    canvas.removeEventListener 'click', lockPointer
  else
    canvas.removeEventListener 'mousemove', mousemove
    canvas.removeEventListener 'mousedown', mousedown
    canvas.removeEventListener 'mouseup', mouseup
    canvas.addEventListener 'click', lockPointer

play = ->

