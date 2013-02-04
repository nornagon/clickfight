## Crux, a cross shaped boss who descends on a city, slamming it with its
## four giant arms. It also regenerates its limbs and uses lightning attacks

# Pre Game Setup

# First, create the static city walls
wallGeometry = [
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

@walls = @spawn 'walls'
@walls.static = true
@walls.blocksplayers = true

# Spawn the entities that exist at the start of the game
head = @spawn 'head'
head.x = room.width/2
head.y = room.height/2

head.arms =
  for i in [0..3]
    a = head.spawn 'arm'
    a.angle = i*Math.PI/2
    a

# Set player starting locations
for p in room.players
  p.x = 10
  p.y = 10

# Entities
@entities =
  head:
    radius: 160
    shapes: [circle 0, 0, @radius]
    health: 100
    draw: ->
      ctx.beginPath()
      ctx.arc 0, 0, @radius, 0, Math.PI*2
      ctx.fillStyle = if @telegraphing then 'cyan' else @colour
      ctx.fill()

  arm:
    width: 700
    height: 100
    shapes: [rect height/2, -height/2, width, height]
    health: 10
    draw: ->
      ctx.fillStyle = if @telegraphing then 'yellow' else @colour
      ctx.fillRect h/2, -h/2, w, h
      ctx.fillStyle = 'orange'
      for i in [1..@health]
        ctx.beginPath()
        ctx.arc 75+i*25, Math.sin(i)*15, 10, 0, Math.PI*2
        ctx.fill()

# Phases
@phases =
  ## ArmSlam - a phase where Crux slams the ground under its four giant arms
  ## while defending itself with an electric shell
  ArmSlam:
    begin: ->
      head.color = 'red'
      for a in arms
        if a.damaged
          a.colour = 'grey'
        else
          a.colour = 'red'
        a.invincible = false
      head.invincible = true

      @lastPulse = 0

      # Occasional Arm Slams
      for arm in arms
        after between(3, 5) -> every between(1,3), (done) ->
          arm.set 'telegraphing', true
          alwaysAfter 0.7, ->
            # TODO: arm.slam as an inherent function of the arm
            arm.set 'telegraphing', false
            for p in room.players
              if p.touching arm
                p.damage 2
            done()
      after 10, ->
        room.enterPhase 'ArmHeal'
    
    onUpdate: ->
      # Go to Retract Phase when any one arm dies
      for arm in arms
        if arm.health < 1
          room.enterPhase 'Retract'
      
      # constant boss rotation
      head.angle += Math.PI/20 * dt
      
      # If the pulse cooldown is up and a person is in collision radius with Crux
      # then fire a pulse to hit everyone nearby
      if @lastPulse < room.time - 0.5 and head.touching 'player'
        @lastPulse = room.time
        for p in room.players
          if p.touching circle head.x, head.y, 200
            p.damage 1
    
  ## ArmHeal - Crux pauses for a moment and heals its most injured arms
  ArmHeal:
    begin: ->
      head.colour = 'purple'
      head.invincible = true
      for a in arms
        a.colour = 'purple'
        a.invincible = true
      after 1.5, ->
        maxArmHealth = Math.max.apply(Math, (a.health for a in arms))
        a.health = maxArmHealth for a in arms
      after 3, ->
        room.enterPhase 'ArmSlam'

  ## Retract - Crux reacts to losing an arm by retracting them all
  Retract:
    begin: ->
      head.colour = 'cyan'
      head.invincible = true
      for a in arms
        a.colour = 'cyan'
        a.invincible = true
      after 1.5, ->
        for a in arms
          a.destroy()
        arms.length = 0
      after 3, ->
        room.enterPhase 'HeadChase'
    
  ## HeadChase - With its arms protected, Crux decides to use its lightning
  ## attacks to focus down and kill its attackers
  HeadChase: {}
    
  ## Expand - With healed (or permanently damaged) arms brought back out
  ## Crux goes on the offensive again
  Expand: {}

