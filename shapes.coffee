circle = (x, y, radius) ->
  c: v(x,y) # center
  tc: null # transformed center
  r: radius # radius
  type: 'circle'

  update: ->
    @tc = v.add @owner.tpos, v.rotate(@c, @owner.trot)
    @bb_l = @tc.x - @r
    @bb_r = @tc.x + @r
    @bb_b = @tc.y - @r
    @bb_t = @tc.y + @r

  draw: ->
    ctx.fillStyle = @owner.color or 'green'
    ctx.strokeStyle = 'black'
    ctx.lineWidth = 2

    ctx.beginPath()
    ctx.arc @c.x, @c.y, @r, 0, 2*Math.PI, false
    ctx.fill()
    ctx.stroke()



Axis = (@n, @d) ->

# Check that a set of vertexes is convex and has a clockwise winding.
polyValidate = (verts) ->
  len = verts.length
  for i in [0...len] by 2
    x1 = verts[i]
    y1 = verts[i+1]
    x2 = verts[(i+2)%len]
    y2 = verts[(i+3)%len]
    x3 = verts[(i+4)%len]
    y3 = verts[(i+5)%len]
    
    return false if vcross2(x2 - x1, y2 - y1, x3 - x2, y3 - y2) > 0
  
  true


setAxes = (poly) ->
  verts = poly.verts
  len = verts.length
  numVerts = len >> 1

  poly.axes = for i in [0...len] by 2
    x1 = verts[i  ]
    y1 = verts[i+1]
    x2 = verts[(i+2)%len]
    y2 = verts[(i+3)%len]

    n = v.normalize new Vect y1-y2, x2-x1
    d = v.dot2 n.x, n.y, x1, y1
    new Axis n, d

setupPoly = (poly) ->
  throw new Error 'points must be clockwise' unless polyValidate poly
  setAxes poly
  poly.tVerts = new Array poly.verts.length
  poly.tAxes = (new Axis v.zero, 0 for [0...poly.axes.length])

transformVerts = (poly, p, rot) ->
  src = poly.verts
  dst = poly.tVerts
  
  l = Infinity; r = -Infinity
  b = Infinity; t = -Infinity
  
  for i in [0...src.length] by 2
    x = src[i]
    y = src[i+1]

    vx = p.x + x*rot.x - y*rot.y
    vy = p.y + x*rot.y + y*rot.x

    dst[i] = vx
    dst[i+1] = vy

    l = min l, vx
    r = max r, vx
    b = min b, vy
    t = max t, vy

  poly.bb_l = l
  poly.bb_b = b
  poly.bb_r = r
  poly.bb_t = t

transformAxes = (poly, p, rot) ->
  src = poly.axes
  dst = poly.tAxes
  
  for i in [0...src.length]
    n = v.rotate src[i].n, rot
    dst[i].n = n
    dst[i].d = v.dot(p, n) + src[i].d

updatePoly = (poly, p, rot) ->
  rot = v.forangle rot if typeof rot is 'number'
  transformVerts poly, p, rot
  transformAxes poly, p, rot


poly = (x, y, verts) ->
  p =
    verts: verts
    update: ->
      updatePoly this, v(@owner.tpos.x + x, @owner.tpos.y + y), @owner.trot
    draw: ->
      ctx.fillStyle = @owner.color or 'green'
      ctx.strokeStyle = 'black'
      ctx.lineWidth = 2

      ctx.beginPath()

      len = @verts.length

      ctx.moveTo @verts[len - 2] + x, @verts[len - 1] + y
      for i in [0...len] by 2
        ctx.lineTo @verts[i] + x, @verts[i+1] + y
      ctx.fill()
      ctx.stroke()
    type: 'poly'

  setupPoly p

  p


rect = (x, y, w, h) -> poly x, y, [0, 0,  0, h,  w, h,  w, 0]


collide = (a, b) ->
  switch a.type
    when 'circle'
      switch b.type
        when 'circle'
          circle2circle a, b
        when 'poly'
          circle2poly a, b
    when 'poly'
      switch b.type
        when 'circle'
          circle2poly b, a
        when 'poly'
          poly2poly a, b


