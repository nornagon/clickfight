dt = 16 # hm
class Entity
  currentPhase = 'always'
  @phase: (name, fn) ->
    currentPhase = name
    fn()
    currentPhase = 'always'
    return

  constructor: ->
    @children = []
    @dead = no
    @handlers = {}
    @timers = {}
    @nextTimerID = 1
    @shapes = []

  addEntity: ->
    @children.push e = new Entity
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

    (c.trigger 'death' for c in @children when c.dead)
    @children = (c for c in @children when not c.dead)

  draw: ->

  addShape: (s) ->
    s.owner = @

  trigger: (event, args...) ->
    @handlers.always?[event]?.call @, args...
    @handlers[phase]?[event]?.call @, args...

  on: (name, fn) ->
    (@handlers[currentPhase] ?= {})[e] = fn

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

phase = Entity.phase.bind(Entity)
window.Entity = Entity
window.phase = phase
