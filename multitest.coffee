
canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 1024
canvas.height = 768

ctx = canvas.getContext '2d'

clamp = (x, min, max) -> Math.max(Math.min(x, max), min)

ws = new WebSocket "ws://#{window.location.host}"
#ws.binaryType = 'arraybuffer'

ws.onerror = (e) -> console.log e

entities = null

# The entity that represents the local player
avatar = null

# Frame count is measured in dt units. Eg, frame 62 is 1 second after frame 0.
frame = 0

# The world is always lerping between prevSnapshot and pendingSnapshots[0]. The world pauses
# in frames after pendingSnapshots[0]
prevSnapshot = {frame:-5, data:{}}
pendingSnapshots = []

# World update frequency in seconds. 62.5fps.
dt = 16 / 1000

requestAnimationFrame = window.requestAnimationFrame or window.mozRequestAnimationFrame or
                        window.webkitRequestAnimationFrame or window.msRequestAnimationFrame

# Is a redraw required?
dirty = false

locked = false

fps = 0

update = (dt) ->
  if dt
    fps = 0.7*fps + 0.3*1000 / dt

  if avatar
    if !locked
      avatar.dx = 2 * Math.sin Date.now()/1000
      avatar.dy = 2 * Math.cos Date.now()/1700

    if avatar.dx or avatar.dy
      avatar.x += avatar.dx
      avatar.y += avatar.dy
      avatar.dx = avatar.dy = 0

      avatar.x = clamp avatar.x, 150, canvas.width-150
      avatar.y = clamp avatar.y, 150, canvas.height-150
      #avatar.x = clamp avatar.x, 0, canvas.width
      #avatar.y = clamp avatar.y, 0, canvas.height
      avatar.dirty = true

    if avatar.dirty
      ws.send JSON.stringify
        t:'p'
        x:Math.floor avatar.x
        y:Math.floor avatar.y
      avatar.dirty = false

draw = ->
  if entities
    ctx.fillStyle = 'thistle'
    ctx.fillRect 0, 0, canvas.width, canvas.height
  
    for id, e of entities
      ctx.fillStyle = if e is avatar then 'blue' else 'black'
      ctx.fillRect e.x-5, e.y-5, 10, 10

  else
    ctx.fillStyle = 'white'
    ctx.fillRect 0, 0, canvas.width, canvas.height

  ctx.fillStyle = 'black'
  ctx.font = "20px sans-serif"
  ctx.textAlign = 'start'
  ctx.fillText "FPS:", 30, 80
  ctx.textAlign = 'end'
  ctx.fillText Math.floor(10*fps)/10, 140, 80

oldT = 0
frame = (t) ->
  update t-oldT
  oldT = t
  draw()
  requestAnimationFrame frame

frame 0

ws.onmessage = (msg) ->
  msg = JSON.parse msg.data

  switch msg.t
    when 's'
      entities = msg.entities
      avatar = entities[msg.yourid]
      avatar.id = msg.yourid
      avatar.dx = avatar.dy = 0
    when 'u'
      delete entities[id] for id in msg.remove
      entities[id] = e for id, e of msg.add
      for id, data of msg.update
        e = entities[id]
        e[k] = v for k, v of data
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


