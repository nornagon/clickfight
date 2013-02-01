http = require 'http'
express = require 'express'

{BBTree, BB} = require './bbtree'

app = express()
server = http.createServer app

app.use express.static("#{__dirname}/")
port = 8123

# How frequently (in ms) should we advance the world
dt = 16 / 1000
snapshotDelay = 3
bytesSent = bytesReceived = 0
frameCount = 1

WebSocketServer = require('ws').Server
wss = new WebSocketServer {server}

#state = 'menu' # Big button in the middle to start. Other state = 'playing'.

boss = require './boss'

b = null

players = {}
pendingAdds = []
pendingRemoves = []
nextId = 1000

send = (c, msg) ->
  msg = JSON.stringify msg
  c.send msg
  bytesSent += msg.length

idealTime = Date.now()
frame = ->
  frameCount++

  if frameCount % snapshotDelay is 0
    add = {}
    add[id] = players[id] for id in pendingAdds

    for c in wss.clients
      if c.needsSnapshot
        send c, {t:'s', yourid:c.id, entities:players, f:frameCount}
        c.needsSnapshot = false
      else
        update = {}
        update[id] = {x:p.x, y:p.y} for id, p of players when p.dirty and id isnt c.id

        packet =
          t:'u'
          u:update
          a:add if pendingAdds.length
          r:pendingRemoves if pendingRemoves.length
          f:frameCount

        send c, packet

    pendingAdds.length = pendingRemoves.length = 0
    p.dirty = false for id, p of players

  idealTime += dt * 1000
  setTimeout frame, idealTime - Date.now()

frame()

wss.on 'connection', (c) ->
  id = c.id = (nextId++).toString()
  players[id] =
    x: Math.random() * 1024
    y: Math.random() * 768
  pendingAdds.push id
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
        players[id].x = msg.x
        players[id].y = msg.y
        players[id].dirty = true
      else
        console.log msg

  c.on 'close', ->
    delete players[id]
    pendingRemoves.push id

setInterval ->
    console.log "TX: #{bytesSent/5}  RX: #{bytesReceived/5}"
    bytesSent = bytesReceived = 0
  , 5000

server.listen port
console.log "Listening on port #{port}"

