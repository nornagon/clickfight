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

maxSpeed = 300

updateFns =
  player: (dt) ->
    if !locked and this is avatar
      @dx = 2 * Math.sin Date.now()/1000
      @dy = 2 * Math.cos Date.now()/1700

    if @dx or @dy
      d = Math.sqrt @dx*@dx + @dy*@dy
      if d > 0.0001
        @angle = t = Math.atan2 @dy, @dx
        @d = d = Math.min d, maxSpeed * dt

        if this is avatar
          @prevX = @x
          @prevY = @y
          @x += d * Math.cos t
          @y += d * Math.sin t
          @x = v.clamp @x, 0, canvas.width
          @y = v.clamp @y, 0, canvas.height

          @dx *= 0.64
          @dy *= 0.64

          @dirty = true

drawFns =
  player: ->
    ctx.save()
    ctx.translate @x, @y
    ctx.rotate @angle
    m = maxSpeed * 16/1000
    d = Math.min m, 0.2 * Math.sqrt(@dx * @dx + @dy * @dy)
    ctx.scale 1+0.5*d/m, 1 - d*0.2/m
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
      x = Math.cos(i*Math.PI*2/3)*4
      y = Math.sin(i*Math.PI*2/3)*4
      ctx.beginPath()
      ctx.arc x, y, 3, 0, Math.PI*2
      ctx.fill()

    ctx.restore()


update = (dt) ->
  if dt
    fps = 0.7*fps + 0.3 / dt

  return unless lerpA and lerpB

  dtInFrames = dt / serverDt
  if Math.abs(serverFrame - serverFrameTarget) > 1
    if serverFrameTarget < serverFrame
      dtInFrames *= 0.9
    else
      dtInFrames *= 1.1

  serverFrame += dtInFrames

  serverFrameTarget += dt / serverDt

  # Render frame is ~100ms behind
  prevRenderFrame = renderFrame
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

    #console.log d1
    e.x = v.lerp2 d1.x, d2.x, lerpPoint
    e.y = v.lerp2 d1.y, d2.y, lerpPoint
    #console.log d1.a, d2.a

    if d1.dx?
      e.dx = v.lerp2 d1.dx, d2.dx, lerpPoint
      e.dy = v.lerp2 d1.dy, d2.dy, lerpPoint
    #e.angle = v.lerp2 d1.a, d2.a, lerpPoint
    #e.d = v.lerp2 d1.d, d2.d, lerpPoint if d1.d?


  # Update
  updateFns[e.type]?.call(e, dt) for id, e of entities

  if Math.floor(prevRenderFrame) < Math.floor(renderFrame) and avatar?.dirty
    ws.send JSON.stringify
      t:'p'
      x:Math.floor avatar.x
      y:Math.floor avatar.y
      dx:Math.floor avatar.dx
      dy:Math.floor avatar.dy
      f:0.1 * Math.floor renderFrame * 10
    avatar.dirty = false

draw = ->
  if entities
    ctx.fillStyle = 'thistle'
    ctx.fillRect 0, 0, canvas.width, canvas.height
  
    for id, e of entities
      if drawFns[e.type]
        drawFns[e.type].call e
      else
        ctx.fillStyle = if e is avatar then 'blue' else 'black'
        ctx.fillRect e.x-5, e.y-5, 10, 10

    # FPS display
    ctx.fillStyle = 'black'
    ctx.font = "20px sans-serif"
    ctx.textAlign = 'start'
    ctx.fillText "FPS:", 30, 80
    ctx.textAlign = 'end'
    ctx.fillText Math.floor(10*fps)/10, 140, 80

  else
    ctx.fillStyle = 'white'
    ctx.fillRect 0, 0, canvas.width, canvas.height
  
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

  copy = (e) -> {x:e.x, y:e.y, dx:e.dx, dy:e.dy}

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
    else
      console.log msg

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


