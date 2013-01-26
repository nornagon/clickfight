boss = (room) ->
  head = room.addEntity()
  head.radius = 75
  head.x = room.width/2
  head.y = room.height/2

  head.addHitbox circle(head.x, head.y, head.radius)

  ## ArmSlam

  head.phase('ArmSlam').on 'draw', ->
    ctx.beginPath()
    ctx.arc @x, @y, @radius, 0, Math.PI*2
    ctx.fillStyle = 'red'
    ctx.fill()
    ctx.strokeStyle = 'black'
    ctx.lineWidth = 2
    ctx.stroke()

  makeArm = (angle) ->
    a = head.addEntity()
    w = 500
    h = 30
    a.addHitbox rect(0, -h/2, w, h)
    a.rot = angle

    a.phase('ArmSlam').phaseTimer { interval: [3000,8000], initial: [5000,8000] }, (again) ->
      @telegraphing = true
      @after 250, ->
        @telegraphing = false
        # damage all enemies in hitbox
        for p in room.players
          if @touching p
            p.damage 2
        again()

    a.on 'draw', ->
      ctx.fillStyle = if @telgraphing then 'orange' else 'red'
      ctx.fillRect 0, -h/2, w, h

  arms = (makeArm(i*Math.PI/2) for i in [0...4])

  head.lastPulse = null

  head.phase('ArmSlam').on 'update', ->
    head.rot += Math.PI/20 * dt/1000

    # pulse
    head.collidesWith 'player', ->
      return unless @lastPulse <= room.time - 500
      # find all players within some radius
      # deal them 1 damage
      for p in room.players
        if p.dist(head) <= head.radius + 15
          p.damage 1


  head.phase('ArmSlam').phaseTimer { inital: 30000 }, ->
    room.enterPhase 'ArmHeal'

  ## ArmHeal

  head.phase('ArmHeal').on 'enter', ->
    head.invincible = true
    a.invincible = true for a in arms
    maxArmHealth = Math.max.apply(Math, (a.hp for a in arms))
    a.hp = maxArmHealth for a in arms
    head.after 3000, ->
      room.enterPhase 'ArmSlam'

  head.phase('ArmHeal').on 'draw', ->
    ctx.beginPath()
    ctx.arc @x, @y, @radius, 0, Math.PI*2
    ctx.fillStyle = 'purple'
    ctx.fill()
    ctx.strokeStyle = 'black'
    ctx.lineWidth = 2
    ctx.stroke()
