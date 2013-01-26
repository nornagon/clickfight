collision = require './collision'
Vect = collision.Vect

c1 =
  tc: {x:100, y:100}
  r: 100

c2 =
  tc: {x:100, y:299}
  r: 100

#console.log collision.circle2circle c1, c2


c3 =
  tc: {x:150, y:150}
  r: 50

seg =
  ta: {x:100, y:100}
  tb: {x:100, y:200}
  r: 10

#console.log collision.circle2segment c3, seg


poly1 =
  verts: [-50, -50,  -50, 50,  50, 50,  50, -50]

collision.setupPoly poly1
collision.updatePoly poly1, new Vect(100, 100), 0


poly2 =
  verts: [-50, -50,  -50, 50,  50, 50,  50, -50]

collision.setupPoly poly2
collision.updatePoly poly2, new Vect(100, 199), 0


#console.log collision.poly2poly poly1, poly2



c4 =
  tc: {x:200, y:100}
  r: 49

console.log collision.circle2poly c4, poly1



###
for i in [0...360] by 1
  angle = Math.PI * i / 180
  collision.updatePoly poly, new Vect(100, 100), angle
  console.log poly
###
