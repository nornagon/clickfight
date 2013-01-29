## Crux, a cross shaped boss who descends on a city, slamming it with its
## four giant arms. It also regenerates its limbs and uses lightning attacks

###
        @after 100, ->
          shapeQuery circle(@x, @y, 30), (e) =>
            return if e is this
            #return if e.name is 'player'
            e.damage 1
###

walls = [
  [300, 20, 150, 20]
  [150, 20, 150, 120]
  [150, 120, 250, 120]

  [450, 200, 290, 200]
  [290, 200, 290, 300]

  [510, 0, 510, 170]

  [100, 200, 200, 400]

  [600, 100, 740, 140]
  [650, 140, 710, 300]

  [800, 100, 980, 100]
  [980, 100, 980, 200]
  [980, 200, 800, 200]
  [800, 200, 800, 100]

  [650, 400, 900, 400]

  [830, 440, 820, 560]
  [820, 560, 970, 540]


  [40, 495, 110, 340]
  [110, 340, 205, 496]
  [205, 496, 280, 410]

  [380, 600, 460, 600]
  [460, 600, 470, 768]
  [540, 520, 540, 640]
  [540, 640, 675, 640]
]

boss = (room) ->
  # TODO: Add a bunch of ruins so that movement is hindered
  head = room.addEntity 'head'
  head.radius = 160
  head.x = room.width/2
  head.y = room.height/2
  head.group = 'boss'
  head.layers = 1

  head.addShape circle(0, 0, head.radius)
  makeArm = (angle) ->
    a = head.addEntity 'arm'
    a.group = 'boss'
    a.layers = 1
    w = 700
    h = 100
    a.x = 0
    a.y = 0#-h/2
    a.addShape rect(h/2, -h/2, w, h)
    a.angle = angle
    a.hp = 1

    a.phase('ArmSlam').phaseTimer { interval: [1000,3000], initial: [3000,5000] }, (again) ->
      @telegraphing = true
      @color = 'yellow'
      play 'slam.wav'
      @after 700, ->
        @telegraphing = false
        delete @color
        # damage all enemies in hitbox
        for p in room.players
          if @isTouching p
            p.damage 2
        again()
    
    a.on 'draw', ->
      ctx.fillStyle = if @telegraphing then 'yellow' else if @damaged then 'grey' else 'red'
      ctx.fillRect h/2, -h/2, w, h
      ctx.fillStyle = 'orange'
      for i in [1..@hp]
        ctx.beginPath()
        ctx.arc 75+i*25, Math.sin(i)*15, 10, 0, Math.PI*2
        ctx.fill()
        
    a.phase('ArmHeal').on 'draw', ->
      ctx.fillStyle = 'purple'
      ctx.fillRect h/2, -h/2, w, h
      ctx.fillStyle = 'orange'
      for i in [1..@hp]
        ctx.beginPath()
        ctx.arc 75+i*25, Math.sin(i)*15, 10, 0, Math.PI*2
        ctx.fill()
    
    a.on 'death', ->
      room.enterPhase 'Retract'
    
    a
    
  arms = null

  wall = room.addEntity 'wall'
  wall.layers = 2
  wall.x = wall.y = 0
  wall.color = '#444'
  wall.addStaticShape segment w[0], w[1], w[2], w[3], 2 for w in walls

  wall.on 'draw', -> s.draw() for s in @shapes
  
  ## ArmSlam - a phase where Crux slams the ground under its four giant arms
  ## while defending itself with an electric shell
  
  head.on 'draw', ->
    ctx.beginPath()
    ctx.arc 0, 0, @radius, 0, Math.PI*2
    ctx.fillStyle = @color or 'red'
    ctx.fill()
    ctx.strokeStyle = 'black'
    ctx.lineWidth = 2
    ctx.stroke()

  # TODO: Change to making dead arms if necessary
  head.phase('ArmSlam').on 'enter', ->
    #ratio = @health/@maxHealth
    arms = (makeArm(i*Math.PI/2) for i in [0...4])
    for a in arms
      a.invincible = false
    
    @color = 'red'
    
    #if ratio > 0.75
    #  arms = (makeArm(i*Math.PI/2) for i in [0...4])
    #else if ratio > 0.5
    #  #arms = (makeArm
    #else if ratio > 0.25
    #else
    
    @invincible = true
    @lastPulse = 0
    @target = null
    
  head.phase('Retract').on 'enter', ->
    for a in arms
      a.destroy()
    arms.length = 0

  head.phase('ArmSlam').on 'update', ->
    # Always rotate the boss
    head.angle += Math.PI/20 * dt/1000
    
    # If the pulse cooldown is up and a person is in collision radius with Crux
    # then fire a pulse to hit everyone nearby
    if @lastPulse < room.time - 500 and @isTouching 'player'
      @lastPulse = room.time
      # find all players within some radius
      # deal them 1 damage
      play 'pulse.wav'
      p.damage 1 for p in @touching when p.name is 'player'

  head.phase('ArmSlam').phaseTimer { initial: 10000 }, ->
    room.enterPhase 'ArmHeal'

  ## ArmHeal - Crux pauses for a moment and heals its most injured arms

  head.phase('ArmHeal').on 'enter', ->
    head.invincible = true
    head.color = 'purple'
    a.invincible = true for a in arms
    maxArmHealth = Math.max.apply(Math, (a.hp for a in arms))
    a.hp = maxArmHealth for a in arms
    play 'heal.wav'
    head.after 3000, ->
      room.enterPhase 'ArmSlam'

  ## Retract - Crux reacts to losing an arm by retracting them all
  
  room.phase('Retract').on 'enter', ->
    play 'retract.wav'

  head.phase('Retract').on 'enter', ->
    @color = 'cyan'

  head.phase('Retract').phaseTimer { initial: 3000 }, ->
    room.enterPhase 'HeadChase'
  
  ## HeadChase - With its arms protected, Crux decides to use its lightning
  ## attacks to focus down and kill its attackers
  
  head.phase('HeadChase').on 'enter', ->
    head.target = room.randomLivePlayer()
    head.boltsFired = 0
    @invincible = false
    @color = 'teal'

  head.phase('HeadChase').on 'update', ->
    if @boltsFired >= 2 and room.players.length > 1
      loop
        target = room.randomLivePlayer()
        if @target isnt target
          @target = target
          break
      @boltsFired = 0
    head.moveTowards(@target, 100) #pixels per second
  
  head.phase('HeadChase').phaseTimer { interval: [3000,5000], initial: [3000,5000] }, (again) ->
    @telegraphing = true
    @color = 'cyan'
    @after 700, ->
      @telegraphing = false
      @color = 'teal'
      play 'pulse.wav'
      for p in room.players
        if p.dist(head) <= head.radius + 15
          p.damage 1
      bolt = head.beam(@x, @y, @target.x, @target.y) #source, target
      bolt.collidesWith = ['wall', 'player']
      bolt.fire()
      head.boltsFired++
      again()

  head.phase('HeadChase').phaseTimer { interval: 20000 }, ->
    room.enterPhase 'Expand'
    
  ## Expand - With healed (or permanently damaged) arms brought back out
  ## Crux goes on the offensive again
  
  head.phase('Expand').on 'enter', ->
    head.invincible = true
    @color = 'orange'
    head.moveTowards {x:room.width/2, y:room.height/2}, 200
    play 'expand.wav'

  head.phase('Expand').phaseTimer { initial: 3000 }, ->
    room.enterPhase 'ArmSlam'
  
  room.enterPhase 'ArmSlam'
