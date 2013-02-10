http = require 'http'
express = require 'express'
fs = require 'fs'
v = require './vect'
vm = require 'vm'
shapes = require './shapes'
uglify = require 'uglify-js'

{BBTree, BB} = require './bbtree'
Entity = require './entity'

port = 8123

# How frequently (in ms) should we advance the world
{dt, snapshotDelay} = require './misc'
bytesSent = bytesReceived = 0
frameCount = 1
pendingAdds = []
pendingRemoves = []


app = express()
server = http.createServer app
app.use express.static("#{__dirname}/")

{Server:WebSocketServer, OPEN:WSOPEN} = require('ws')
wss = new WebSocketServer {server}


loadBoss = (filename) ->
  contents = fs.readFileSync filename, 'utf8'
  vm.createScript "(function(){ #{contents} }).call(room);", filename

entities = {}

room = new Entity 'room'
room.room = room
room.onChildAdded = (e) ->
  entities[e.id] = e
  pendingAdds.push e.id
room.onChildRemoved = (e) ->
  pendingRemoves.push e.id
  delete entities[e.id]
room.players = []
room.tpos = v.zero
room.trot = v.forangle 0
room.width = 1024
room.height = 768

entityTypes = {}
entityTypesDirty = true

thing = room.addEntity 'thing'
thing.on 'update', ->
  @x = room.width/2 + Math.sin(frameCount/100)*250
  @y = room.height/2 + Math.cos(frameCount/100)*250
  @dirty = true

start = ->
  console.log 'start'
  #boss = ->
  boss = loadBoss 'boss.js'

  for c in room.children
    if c.type isnt 'player'
      c.removeInternal()
   
  boss.runInNewContext
    room:room
    console:console
    v:v
    width:room.width
    height:room.height
    circle:shapes.circle
    rect:shapes.rect

  entityTypes = room.entities
  entityTypesDirty = true
  #boss.call room, room


send = (c, msg) ->
  msg = JSON.stringify msg, (key, val) ->
    if typeof val is 'function'
      #(uglify.minify "(#{val.toString()})", fromString:yes).code
      # ^ This isn't working right - I think its minifying the entire expression as a no-op.
      val.toString()
    else
      val
  if c.readyState is WSOPEN
    c.send msg
    bytesSent += msg.length

idealTime = Date.now()
frame = ->
  frameCount++

  room.update()

  if frameCount % snapshotDelay is 0
    snapshotCopy = (e) ->
      data = {}
      data[k] = e[k] for k in ['x', 'y', 'angle', 'type', 'hp'] when e[k]?
      data

    add = {}
    add[id] = snapshotCopy entities[id] for id in pendingAdds

    for c in wss.clients
      if c.needsSnapshot
        snapshot = {}
        snapshot[id] = snapshotCopy e for id, e of entities

        send c,
          t:'s' # type = snapshot
          yourid:c.id
          et:entityTypes
          entities:snapshot # entities in the world
          f:frameCount

        c.needsSnapshot = false
      else
        update = {}
        for id, e of entities when e.dirty and id isnt c.id
          update[id] =
            x:e.x
            y:e.y
            dx:e.dx
            dy:e.dy

        packet =
          t:'u' # type = update
          u:update
          a:add if pendingAdds.length
          r:pendingRemoves if pendingRemoves.length
          f:frameCount
          et:entityTypes if entityTypesDirty

        send c, packet

    pendingAdds.length = pendingRemoves.length = 0
    entityTypesDirty = false
    e.dirty = false for id, e of entities

  idealTime += dt * 1000
  setTimeout frame, idealTime - Date.now()

frame()

wss.on 'connection', (c) ->
  player = room.addEntity 'player'
  id = c.id = player.id.toString()
  player.x = Math.random() * 1024
  player.y = Math.random() * 768
  player.hp = 3

  room.players.push player

  buffer = []

  player.on 'update', ->
    #console.log buffer.length
    msg = buffer.pop()
    if msg
      #console.log msg.f
      player.x = msg.x
      player.y = msg.y
      player.dx = msg.dx
      player.dy = msg.dy
      player.dirty = true

  c.needsSnapshot = true

  c.on 'message', (msg) ->
    bytesReceived += msg.length
    try
      msg = JSON.parse msg
    catch e
      console.log 'invalid JSON', e, msg
  
    switch msg.t
      when 'p'
        # position update
        buffer.unshift msg
        #console.log 'packet', buffer.length
        #console.log "trunc #{buffer.length - 5}" if buffer.length > 5
        buffer.length = Math.min buffer.length, 5
      when 's'
        start()
      when 'say', 'backspace'
        for client in wss.clients when client isnt c
          client.send JSON.stringify msg
      else
        console.log msg

  c.on 'close', ->
    player.remove = true

setInterval ->
    console.log "TX: #{bytesSent/5}  RX: #{bytesReceived/5}"
    bytesSent = bytesReceived = 0
  , 5000

server.listen port
console.log "Listening on port #{port}"

