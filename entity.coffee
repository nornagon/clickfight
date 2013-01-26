dt = 16 # hm
class Entity
  constructor: (name) ->
    @name = name if name
    @children = []
    @dead = no
    @handlers = {}
    @timers = {}
    @nextTimerID = 1
    @shapes = []
    # phase that events will bind to. overridden sometimes.
    @targetPhase = 'always'

  addEntity: (name) ->
    @children.push e = new Entity name
    e.parent = @
    e

  forAll: (fn) ->
    fn(@)
    c.forAll fn for c in @children

  update: ->
    @trigger 'update'
    for i,t of @timers
      t.t += dt
      if t.t >= t.time
        t.fn.call @
        if t.repeat
          t.t = 0
        else
          delete @timers[i]

    if @parent and @x?
      @trot = v.rotate v.forangle(@angle), @parent.trot
      @tpos = v.add @parent.tpos, v.rotate2(@x, @y, @parent.trot)

    s.update() for s in @shapes

    c.update() for c in @children

    (c.trigger 'removed' for c in @children when c.dead)
    @children = (c for c in @children when not c.dead)

  draw: ->
    if @handlers['always']?.draw?.length or @handlers[@currentPhase()]?.draw?.length
      @trigger 'draw'
    else
      s.draw() for s in @shapes

  addShape: (s) ->
    s.owner = @

  trigger: (event, args...) ->
    for handler in @handlers['always']?[event] ? []
      handler.call @, args...
    for handler in @handlers[@currentPhase()]?[event] ? []
      handler.call @, args...
    return

  on: (name, fn) ->
    ((@handlers[@targetPhase] ?= {})[name] ?= []).push fn

  phaseTimer: (opts, fn) ->
    timeFor = (t) ->
      if typeof t is 'number' then t else Math.random()*(t[1]-t[0])+t[0]
    nextEventID = null
    @on 'enter', ->
      again = ->
        nextEventID = @after timeFor(opts.interval), ->
          fn.call @, again
      nextEventID = @after timeFor(opts.initial), ->
        fn.call @, again
    @on 'exit', ->
      @cancelTimer nextEventID
      nextEventID = null

  every: (ms, fn) ->
    @timers[@nextTimerID++] =
      t: 0
      time: ms
      fn: fn
      repeat: yes

  after: (ms, fn) ->
    @timers[@nextTimerID++] =
      t: 0
      time: ms
      fn: fn
      repeat: no

  afterRandom: (minms, maxms, fn) ->
    @timers[@nextTimerID++] =
      t: 0
      time: Math.floor(Math.random()*(maxms-minms)+minms)
      fn: fn
      repeat: no

  cancelTimer: (id) ->
    delete @timers[id]

  currentPhase: ->
    return @currentPhase_ if @currentPhase_
    if @parent
      @parent.currentPhase()
    else
      'always'

  enterPhase: (phase) ->
    @forAll (e) ->
      e.trigger 'exit'
    @currentPhase_ = phase
    @forAll (e) ->
      e.trigger 'enter'

  phase: (name) ->
    a = {}
    a.__proto__ = @
    a.targetPhase = name

window.Entity = Entity
