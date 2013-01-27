canvas = document.getElementsByTagName('canvas')[0]
canvas.width = 1024
canvas.height = 768
ctx = canvas.getContext '2d'
maxSpeed = 300 # px/s

room = new Entity

room.tpos = v.zero
room.trot = v.forangle 0
room.width = canvas.width
room.height = canvas.height
room.players = []
room.time = 0

players = {}

randInt = (max) -> Math.floor Math.random() * max

staticIndex = new BBTree()
dynamicIndex = new BBTree staticIndex

shapeQuery = (shape, callback) ->
  shape.cachePos v(0,0), v(1,0) unless typeof shape.bb_l is 'number'
  box = bb shape.bb_l, shape.bb_b, shape.bb_r, shape.bb_t
  dynamicIndex.query box, (s) ->
    collisions = collide shape, s
    if collisions.length
      callback s.owner, s, collisions

drawShapes = false

do ->
  boss room

  for i in [1..3]
    players[i] = player = room.addEntity 'player'
    player.x = i*100
    player.y = 200
    player.dx = player.dy = 0
    player.addShape circle 0, 0, 10

    player.frozen = no

    player.hp = 3

    player.cooldown = 0
    player.specialcooldown = 0
    player.on 'update', ->
      @cooldown = Math.max 0, @cooldown-dt
      @specialcooldown = Math.max 0, @specialcooldown-dt

      if @frozen
        @dx = @dy = 0
        return
      d = Math.sqrt(@dx*@dx+@dy*@dy)
      if d > 0.0001
        @angle = Math.atan2 @dy, @dx
        t = Math.atan2 @dy, @dx
        d = Math.min d, maxSpeed*dt/1000

        @prevX = @x
        @prevY = @y
        @x += d * Math.cos(t)
        @y += d * Math.sin(t)

        @x = Math.max 0, Math.min canvas.width, @x
        @y = Math.max 0, Math.min canvas.height, @y
        @dx *= 0.64
        @dy *= 0.64


    player.special = ->
      if @specialcooldown is 0
        @specialcooldown = 1500
        jump = v.mult @trot, 120
        @x += jump.x
        @y += jump.y
    
    player.attack = ->
      if @cooldown is 0
        @cooldown = 500
        @frozen = yes
        @after 250, ->
          @frozen = no
        swipe = @addEntity 'attack'
        swipe.x = swipe.y = 0
        swipe.attackTime = 0
        swipe.on 'update', ->
          @attackTime += dt
          if @attackTime >= 250
            @remove = yes
        swipe.draw = ->
          ctx.fillStyle = 'red'
          ctx.beginPath()
          ctx.moveTo 0, 0
          start = -Math.PI
          t = start + @attackTime/250*Math.PI*2
          ctx.lineTo Math.cos(t)*30, Math.sin(t)*30
          ctx.arc 0, 0, 30, t, Math.max(start,t-0.6), true
          ctx.closePath()
          ctx.fill()

        @after 100, ->
          shapeQuery circle(@x, @y, 30), (e) =>
            return if e is this
            #return if e.name is 'player'
            e.damage 1

    player.on 'draw', ->
      ctx.save()

      m = maxSpeed*16/1000
      d = Math.min m, Math.sqrt(@dx * @dx + @dy * @dy)
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
        x = Math.cos(i*Math.PI*2/3)*4
        y = Math.sin(i*Math.PI*2/3)*4
        ctx.beginPath()
        ctx.arc x, y, 3, 0, Math.PI*2
        ctx.fill()

      ctx.restore()

      if drawShapes
        ctx.fillStyle = 'black'
        d = v.unrotate v(@dx, @dy), @trot
        ctx.fillRect d.x - 5, d.y - 5, 10, 10

    player.on 'death', ->
      @remove = yes
      room.players = (p for p in room.players when !p.dead)

    room.players.push player


draw = ->
  ctx.fillStyle = 'thistle'
  ctx.fillRect 0, 0, canvas.width, canvas.height
  ctx.strokeStyle = 'black'
  
  room.draw()

  if drawShapes
    ctx.globalAlpha = 0.5
    staticIndex.each (s) -> s.draw()
    dynamicIndex.each (s) -> s.draw()
    ctx.globalAlpha = 1

#into.deadZoneLeftStick = 7849.0/32767.0;
#into.deadZoneRightStick = 8689/32767.0;

update = ->
  pads = navigator.webkitGetGamepads()
  for c, i in pads when c
    dead = 7849.0/32767.0
    dx = if Math.abs(c.axes[0]) > dead then c.axes[0] else 0
    dy = if Math.abs(c.axes[1]) > dead then c.axes[1] else 0

    p = players[i+2]

    if c.buttons[0] and !p.prevButtonState
      p.attack()
    if c.buttons[1] and !p.prevButtonState
      p.special()

    p.prevButtonState = c.buttons[0]

    if dx or dy
      angle = Math.atan2 dy, dx
      dist = dx * dx + dy * dy

      if p
        p.dx = 20 * dist * Math.cos angle
        p.dy = 20 * dist * Math.sin angle

  room.update()

  room.forAll (e) ->
    e.touching.length = 0
    e.color = 'blue' if drawShapes
      

  dynamicIndex.reindexQuery (a, b) ->
    ae = a.owner
    be = b.owner
    return if ae.group and ae.group is be.group
    return unless ae.layers & be.layers
    
    collisions = collide a, b
    return unless collisions.length

    if a.owner.name > b.owner.name
      [a, b] = [b, a]
      c.n = v.neg c.n for c in collisions

    ae = a.owner
    be = b.owner

    ae.touching.push b.owner
    be.touching.push a.owner
  
    if drawShapes
      ae.color = be.color = 'red'

    switch
      when ae.name == 'player' and be.name == 'wall'
        c = collisions[0]
        p = v.add v(ae.x, ae.y), v.mult c.n, c.dist

        ae.x = p.x
        ae.y = p.y
        ae.dx = ae.dy = 0
        ae.cachePos()
      else
        #console.log ae.name, be.name

  room.time += 16

oldT = 0
frame = (t) ->
  update t-oldT
  oldT = t
  draw()
  webkitRequestAnimationFrame frame
frame(0)


mousemove = (e) ->
  players[1].dx += e.webkitMovementX
  players[1].dy += e.webkitMovementY

mousedown = (e) ->
  #console.log players[1].x, players[1].y
  if e.button is 0
    players[1].attack()
  else if e.button is 2
    players[1].special()

mouseup = (e) ->

canvas.addEventListener 'click', lockPointer = ->
  canvas.webkitRequestPointerLock()

document.addEventListener 'keydown', (e) ->
  if e.keyCode is 192
    drawShapes = !drawShapes

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

