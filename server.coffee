http = require 'http'
express = require 'express'
fs = require 'fs'
v = require './vect'

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
  new Function 'room', contents

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


start = ->
  boss = ->
  #boss = loadBoss 'boss.js'

  for c in room.children
    if c.type isnt 'player'
      c.removeInternal()
    
  boss.call room, room


send = (c, msg) ->
  msg = JSON.stringify msg
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
      data[k] = e[k] for k in ['x', 'y', 'angle', 'type']
      data

    add = {}
    add[id] = snapshotCopy entities[id] for id in pendingAdds

    for c in wss.clients
      if c.needsSnapshot
        snapshot = {}
        snapshot[id] = snapshotCopy e for id, e of entities

        send c, {t:'s', yourid:c.id, entities:snapshot, f:frameCount}
        c.needsSnapshot = false
      else
        update = {}
        update[id] = {x:Math.floor(e.x), y:Math.floor(e.y)} for id, e of entities when e.dirty and id isnt c.id

        packet =
          t:'u'
          u:update
          a:add if pendingAdds.length
          r:pendingRemoves if pendingRemoves.length
          f:frameCount

        send c, packet

    pendingAdds.length = pendingRemoves.length = 0
    e.dirty = false for id, e of entities

  idealTime += dt * 1000
  setTimeout frame, idealTime - Date.now()

frame()

wss.on 'connection', (c) ->
  player = room.addEntity 'player'
  id = c.id = player.id.toString()
  player.x = Math.random() * 1024
  player.y = Math.random() * 768

  room.players.push player

  buffer = []

  player.on 'update', ->
    msg = buffer.pop()
    if msg
      player.x = msg.x
      player.y = msg.y
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
        buffer.length = Math.max buffer.length, 5
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

