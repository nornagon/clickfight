{dt} = require './misc'
v = require './vect'

nextId = 1000

module.exports = class Entity
  constructor: (@type) ->
    @id = nextId++
    @angle = 0
    @children = []
    @shapes = []
    @remove = no
    @dirty = true


    @dead = no
    @handlers = {}
    @timers = {}
    @nextTimerID = 1
    # phase that events will bind to. overridden sometimes.
    @targetPhase = 'always'
    @layers = ~0

  addEntity: (type) ->
    @children.push e = new Entity type
    e.room = @room
    e.parent = @
    @room.onChildAdded e
    e
  spawn: (type) -> @addEntity type # alias for marc.

  each: (fn) ->
    fn(@)
    c.each fn for c in @children

  childOf: (entity) ->
    return true if @parent is entity or @parent?.childOf entity
    return false

  cachePos: ->
    if @parent and @x?
      @parent.cachePos() unless @parent.tpos

      @trot = v.rotate v.forangle(@angle), @parent.trot
      @tpos = v.add @parent.tpos, v.rotate2(@x, @y, @parent.trot)

  removeInternal: ->
    @trigger 'removed'
    @each (e) -> e.trigger 'removed'
    @room.onChildRemoved this

  update: ->
    @trigger 'update'

    if @target
      speed = @targetSpeed * dt

      dest = if @target.constructor is Entity then @target.tpos else @target
      pos = v(dest.x - @tpos.x, dest.y - @tpos.y)
      len = v.len pos
      delta = v.mult pos, Math.min(speed/len, 1)
      delta = v.unrotate delta, @parent.trot
      @x += delta.x
      @y += delta.y

    for i,t of @timers
      t.t += dt
      if t.t >= t.time
        t.fn.call @
        if t.repeat
          t.t = 0
        else
          delete @timers[i]

    @cachePos()
    s.cachePos @tpos, @trot for s in @shapes

    c.update() for c in @children

    c.removeInternal() for c in @children when c.remove

    @children = (c for c in @children when not c.remove)

  draw: ->
    ctx.save()
    ctx.translate @x, @y
    ctx.rotate @angle

    if @handlers['always']?.draw?.length or @handlers[@currentPhase()]?.draw?.length
      @trigger 'draw'

    e.draw() for e in @children
    ctx.restore()

  addShape: (s) ->
    s.owner = @
    @shapes.push s
    @cachePos()
    s.cachePos @tpos, @trot
    dynamicIndex.insert s
    @on 'removed', -> dynamicIndex.remove s

  addStaticShape: (s) ->
    s.owner = @
    @shapes.push s
    @cachePos()
    s.cachePos @tpos, @trot
    staticIndex.insert s
    @on 'removed', -> staticIndex.remove s

  trigger: (event, args...) ->
    for handler in @handlers['always']?[event] ? []
      handler.call @, args...
    #for handler in @handlers[@currentPhase()]?[event] ? []
    #  handler.call @, args...
    return

  on: (name, fn) ->
    ((@handlers[@targetPhase] ?= {})[name] ?= []).push fn

  once: (name, fn) ->
    targetPhase = @targetPhase
    @on name, f = (args...) ->
      fn.apply @, args
      @handlers[targetPhase][name] = (h for h in @handlers[targetPhase][name] when h isnt f)

  phaseTimer: (opts, fn) ->
    timeFor = (t) ->
      if typeof t is 'number' then t else Math.random()*(t[1]-t[0])+t[0]
    nextEventID = null
    @on 'enter', ->
      broken = false
      again = =>
        if broken then return
        nextEventID = @after timeFor(opts.interval), ->
          fn.call @, again
      nextEventID = @after timeFor(opts.initial or opts.interval), ->
        fn.call @, again
      @once 'exit', ->
        throw new Error if broken
        broken = true
        @cancelTimer nextEventID
        nextEventID = null

  every: (ms, fn) ->
    @timers[id = @nextTimerID++] =
      t: 0
      time: ms
      fn: fn
      repeat: yes
    id

  after: (ms, fn) ->
    @timers[id = @nextTimerID++] =
      t: 0
      time: ms
      fn: fn
      repeat: no
    id

  afterRandom: (minms, maxms, fn) ->
    @timers[id = @nextTimerID++] =
      t: 0
      time: Math.floor(Math.random()*(maxms-minms)+minms)
      fn: fn
      repeat: no
    id

  cancelTimer: (id) ->
    #console.log 'cancelling', id, @timers[id]
    delete @timers[id]

  currentPhase: ->
    return @currentPhase_ if @currentPhase_
    if @parent
      @parent.currentPhase()
    else
      'always'

  enterPhase: (phase) ->
    return if phase is @currentPhase_
    @forAll (e) ->
      e.trigger 'exit'
    @currentPhase_ = phase
    @forAll (e) ->
      e.trigger 'enter'

  phase: (name) ->
    a = {}
    a.__proto__ = @
    a.targetPhase = name
    a

  isTouching: (other) ->
    if typeof other is 'string'
      for o in @touching
        return o if o.type is other
      false
    else
      other in @touching

  damage: (amt) ->
    if typeof @hp is 'number' and @invincible != true and !@dead
      @hp = Math.max @hp - amt, 0
      if @hp <= 0
        @dead = true
        @trigger 'death'

  destroy: ->
    @remove = yes

  dist: (other) -> v.len v.sub @tpos, other.tpos

  moveTowards: (@target, @targetSpeed) ->

  beam: -> {fire:->}

  randomLivePlayer: ->
    @players[randInt @players.length]

