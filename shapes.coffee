circle = (x, y, radius) ->
  c: v(x,y) # center
  tc: null # transformed center
  r: radius # radius

  update: ->
    @tc = v.add @owner.tpos, v.rotate(@c, @owner.trot)

  draw: ->
    ctx.fillStyle = @owner.color or 'green'
    ctx.strokeStyle = 'black'
    ctx.lineWidth = 2

    ctx.beginPath()
    ctx.arc @tc.x, @tc.y, @r, 0, 2*Math.PI, false
    ctx.fill()
    ctx.stroke()

poly = (x, y, verts) ->
  p =
    verts: verts
    update: ->
      updatePoly this, v(owner.tpos.x + x, owner.tpos.y + y), owner.trot
    draw: ->
      ctx.fillStyle = @owner.color or 'green'
      ctx.strokeStyle = 'black'
      ctx.lineWidth = 2

      ctx.beginPath()

      verts = @tVerts
      len = @length

      ctx.moveTo verts[len - 2], verts[len - 1]
      for i in [0...len] by 2
        ctx.lineTo verts[i], verts[i+1]
      ctx.fill()
      ctx.stroke()

  setupPoly p

  p


rect = (x, y, w, h) -> poly x, y, [0, 0,  0, h,  w, h,  w, 0]


