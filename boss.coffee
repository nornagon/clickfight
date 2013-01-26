## Crux, a cross shaped boss who descends on a city, slamming it with its
## four giant arms. It also possesses healing power and lightning attacks

boss = (room) ->
  head = room.addEntity 'head'
  head.radius = 160
  head.x = room.width/2
  head.y = room.height/2

  head.addShape circle(0, 0, head.radius)

  ## ArmSlam - a phase where Crux slams the ground under its four giant arms
  ## while defending itself with an electric shell

  
  head.phase('ArmSlam').on 'draw', ->
    ctx.beginPath()
    ctx.arc 0, 0, @radius, 0, Math.PI*2
    ctx.fillStyle = 'red'
    ctx.fill()
    ctx.strokeStyle = 'black'
    ctx.lineWidth = 2
    ctx.stroke()
  
  
  makeArm = (angle) ->
    a = head.addEntity 'arm'
    w = 700
    h = 100
    a.x = 0
    a.y = 0#-h/2
    a.addShape rect(h/2, -h/2, w, h)
    a.angle = angle

    a.phase('ArmSlam').phaseTimer { interval: [3000,8000], initial: [5000,8000] }, (again) ->
      @telegraphing = true
      @color = 'yellow'
      play 'slam.wav'
      @after 600, ->
        delete @color
        # damage all enemies in hitbox
        for p in room.players
          #console.log p, @_touching
          if @touching p
            p.damage 2
        again()

    
    a.on 'draw', ->
      ctx.fillStyle = if @telgraphing then 'orange' else if @damaged then 'grey' else 'red'
      ctx.fillRect 0, -h/2, w, h
    
    a

  arms = null

  # TODO: Change to making dead arms if necessary
  head.phase('ArmSlam').on 'enter', ->
    ratio = @health/@maxHealth
    
    arms = (makeArm(i*Math.PI/2) for i in [0...4])
    
    #if ratio > 0.75
    #  arms = (makeArm(i*Math.PI/2) for i in [0...4])
    #else if ratio > 0.5
    #  #arms = (makeArm
    #else if ratio > 0.25
    #else
    
    head.invincible = true
    head.lastPulse = null
    
    for a in arms
      a.on 'death', ->
        room.enterPhase 'Retract'
      
    for a in arms
      a.phase('Retract').on 'enter',  ->
        a.destroy()

  head.phase('ArmSlam').on 'update', ->
    head.angle += Math.PI/20 * dt/1000

  # pulse
  head.phase('ArmSlam').on 'update', ->
    return unless @lastPulse <= room.time - 500
    pulse = =>
      # find all players within some radius
      # deal them 1 damage
      play 'pulse.wav'
      for p in room.players
        if p.dist(head) <= head.radius + 15
          p.damage 1
    for e in @_touching
      if e.type is 'player'
        pulse()
        @lastPulse = room.time


  head.phase('ArmSlam').phaseTimer { initial: 30000 }, ->
    room.enterPhase 'ArmHeal'

  ## ArmHeal - Crux pauses for a moment and heals its most injured arms

  head.phase('ArmHeal').on 'enter', ->
    head.invincible = true
    a.invincible = true for a in arms
    maxArmHealth = Math.max.apply(Math, (a.hp for a in arms))
    a.hp = maxArmHealth for a in arms
    play 'heal.wav'
    head.after 3000, ->
      room.enterPhase 'ArmSlam'

  head.phase('ArmHeal').on 'draw', ->
    ctx.beginPath()
    ctx.arc 0, 0, @radius, 0, Math.PI*2
    ctx.fillStyle = 'purple'
    ctx.fill()
    ctx.strokeStyle = 'black'
    ctx.lineWidth = 2
    ctx.stroke()

  ## Retract - Crux reacts to losing an arm by retracting them all
  
  room.phase('Retract').on 'enter', ->
    play 'retract.wav'

  head.phase('Retract').phaseTimer { initial: 3000 }, ->
    room.enterPhase 'HeadChase'
  
  ## HeadChase - With its arms protected, Crux decides to use its lightning
  ## attacks to focus down and kill its attackers
  
  head.phase('HeadChase').on 'enter', ->
    head.target = room.randomLivePlayer()
    head.boltsFired = 0;
    @invincible = false

  head.phase('HeadChase').on 'update', ->
    if @boltsFired >= 2
      head.target = room.differentRandomLivePlayer()
      @boltsFired = 0
    head.moveTowards(@target, 100) #pixels per second
    
  head.phase('HeadChase').phaseTimer { interval: [3000,5000], initial: [3000,5000] }, (again) ->
    @telegraphing = true
    @after 250, ->
      @telegraphing = false
      play 'pulse.wav'
      for p in room.players
        if p.dist(head) <= head.radius + 15
          p.damage 1
      bolt = head.beam(@x, @y, target.x, target.y) #source, target
      bolt.collidesWith = ['wall', 'player']
      bolt.fire()
      head.boltsFired++
      again()

  head.phase('HeadChase').phaseTimer { interval: 40000 }, ->
    room.enterPhase 'Expand'
    
  ## Expand - With healed (or permanently damaged) arms brought back out
  ## Crux goes on the offensive again
  
  head.phase('Expand').on 'enter', ->
    head.invincible = true
    head.target = [room.width/2, room.height/2 ]
    play 'expand.wav'

  head.phase('Expand').on 'update', ->
    head.moveTowards(@target, 500)
  
  head.phase('Expand').phaseTimer { initial: 3000 }, ->
    room.enterPhase 'ArmSlam'
  
  room.enterPhase 'ArmSlam'


# while true; do curl -s http://sharejs.org/doc/code:1q6nt3i > boss-temp.coffee && mv boss-temp.coffee boss.coffee; sleep 1; done