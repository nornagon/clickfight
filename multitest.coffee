
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

correction = false


renderFrame = 0


seq = 0

update = (dt) ->
  if dt
    fps = 0.7*fps + 0.3 / dt

  return unless lerpA and lerpB

  dtInFrames = dt / serverDt

  if Math.abs(serverFrame - serverFrameTarget) > 1
    correction = true
    if serverFrameTarget < serverFrame
      dtInFrames *= 0.9
    else if serverFrameTarget > serverFrame
      dtInFrames *= 1.1
  else
    correction = false

  serverFrameTarget += dt / serverDt
  serverFrame += dtInFrames

  # Render frame is 100ms behind
  renderFrame = serverFrame - renderFramesAhead

  while renderFrame > lerpB.f
    if pendingUpdates.length == 0
      renderFrame = lerpB.f
      serverFrame = lerpB.f + renderFramesAhead

      seq = (seq + 1) % 5
      #console.log 'out of data'
      #console.log lerpA.f, lerpB.f, serverFrame, Math.floor(serverFrame - 0.1/serverDt)
    else
      lerpA = lerpB
      lerpB = pendingUpdates.shift()

      delete entities[id] for id in lerpA.remove if lerpA.remove
      entities[id] = e for id, e of lerpA.add if lerpA.add


  #console.log lerpA.f, lerpB.f, Math.floor renderFrame if Math.random() < 0.01


  lerpPoint = Math.max 0, (renderFrame - lerpA.f) / (lerpB.f - lerpA.f)

  for id, d1 of lerpA.data when id isnt avatar.id and d1 isnt null
    d2 = lerpB.data[id]
    continue if d2 is null # the object is about to be removed.

    e = entities[id]

    e.x = v.lerp2 d1.x, d2.x, lerpPoint
    e.y = v.lerp2 d1.y, d2.y, lerpPoint


  if avatar
    if !locked
      avatar.dx = 2 * Math.sin Date.now()/1000
      avatar.dy = 2 * Math.cos Date.now()/1700

    if avatar.dx or avatar.dy
      avatar.x += avatar.dx
      avatar.y += avatar.dy
      avatar.dx = avatar.dy = 0

      avatar.x = v.clamp avatar.x, 150, canvas.width-150
      avatar.y = v.clamp avatar.y, 150, canvas.height-150
      #avatar.x = v.clamp avatar.x, 0, canvas.width
      #avatar.y = v.clamp avatar.y, 0, canvas.height
      avatar.dirty = true


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
    ctx.font = "20px sans-serif"
    ctx.textAlign = 'start'
    ctx.fillText "FPS:", 30, 80
    ctx.textAlign = 'end'
    ctx.fillText Math.floor(10*fps)/10, 140, 80

  else
    ctx.fillStyle = 'white'
    ctx.fillRect 0, 0, canvas.width, canvas.height

  ctx.fillStyle = 'blue'
  ctx.fillRect seq * 50, 500, 50, 20
  if lastReceivedUpdate
    ctx.fillStyle = 'black'
    #behind = (lastReceivedUpdate.f - lerpA.f) * serverDt
    #behind = (lastReceivedUpdate.f - lerpA.f) * serverDt
    behind = (lastReceivedUpdate.f - renderFrame) * serverDt
    #behind = (serverFrameTarget - serverFrame) * serverDt
    ctx.fillRect 100, 200, behind * 1000, 20
    ctx.strokeStyle = 'red'
    ctx.strokeRect 100, 200, 100, 20
    ctx.fillText "#{Math.floor (1000 * behind)} ms", 200, 190
    ctx.fillText "f #{pendingUpdates.length}", 200, 160

  if correction
    ctx.fillStyle = 'red'
    ctx.fillRect 0,300,40,40

raf = window.requestAnimationFrame or window.mozRequestAnimationFrame or
        window.webkitRequestAnimationFrame or window.msRequestAnimationFrame

oldT = 0
frame = (t) ->
  t = Date.now() # ... the high performance timer gets clock skew.
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

      #if msg.f > serverFrame
      #  console.log 'catching up'

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


