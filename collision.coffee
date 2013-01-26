# Stolen from Chipmunk

min = Math.min
max = Math.max

exports.Vect = Vect = (@x, @y) ->

vadd = (v1, v2) -> new Vect v1.x + v2.x, v1.y + v2.y
vsub = (v1, v2) -> new Vect v1.x - v2.x, v1.y - v2.y
vneg = (v) -> new Vect -v.x, -v.y
vmult = (v, f) -> new Vect v.x * f, v.y * f
vdot = (v1, v2) -> v1.x * v2.x + v1.y * v2.y
vdot2 = (x1, y1, x2, y2) -> x1 * x2 + y1 * y2
vcross = (v1, v2) -> v1.x * v2.y - v1.y * v2.x
vcross2 = (x1, y1, x2, y2) -> x1 * y2 - y1 * x2
vlengthsq = (v) -> vdot v, v
vlength = (v) -> Math.sqrt vdot v, v
vperp = (v) -> new Vect -v.y, v.x
vnormalize = (v) -> vmult v, 1/vlength(v)
vrotate = (v1, v2) -> new Vect v1.x*v2.x - v1.y*v2.y, v1.x*v2.y + v1.y*v2.x
vforangle = (a) -> new Vect Math.cos(a), Math.sin(a)
clamp = (f, minv, maxv) -> min(max(f, minv), maxv)
clamp01 = (f) -> min(max(f, 0), 1)

vzero = new Vect 0,0

Contact = (@p, @n, @dist) ->
  this.r1 = this.r2 = vzero
  this.nMass = this.tMass = this.bounce = this.bias = 0

  this.jnAcc = this.jtAcc = this.jBias = 0

NONE = []


# Add contact points for circle to circle collisions.
# Used by several collision tests.
circle2circleQuery = (p1, p2, r1, r2) ->
  mindist = r1 + r2
  delta = vsub(p2, p1)
  distsq = vlengthsq(delta)
  return if distsq >= mindist*mindist
  
  dist = Math.sqrt distsq

  # Allocate and initialize the contact.
  new Contact(
    vadd(p1, vmult(delta, 0.5 + (r1 - 0.5*mindist)/(dist ? dist : Infinity))),
    (if dist then vmult(delta, 1/dist) else new Vect 1, 0),
    dist - mindist
  )

# Collide circle shapes.
exports.circle2circle = (circ1, circ2) ->
  contact = circle2circleQuery circ1.tc, circ2.tc, circ1.r, circ2.r
  if contact then [contact] else NONE

exports.circle2segment = (circleShape, segmentShape) ->
  seg_a = segmentShape.ta
  seg_b = segmentShape.tb
  center = circleShape.tc
  
  seg_delta = vsub(seg_b, seg_a)
  closest_t = clamp01(vdot(seg_delta, vsub(center, seg_a))/vlengthsq(seg_delta))
  closest = vadd(seg_a, vmult(seg_delta, closest_t))
  
  contact = circle2circleQuery(center, closest, circleShape.r, segmentShape.r)

  if contact
    n = contact.n
    
    # Reject endcap collisions if tangents are provided.
    if(
      (closest_t == 0 and vdot(n, segmentShape.a_tangent) < 0) ||
      (closest_t == 1 and vdot(n, segmentShape.b_tangent) < 0)
    ) then NONE else [contact]
  else
    NONE


Axis = (@n, @d) ->

setAxes = (poly) ->
  verts = poly.verts
  len = verts.length
  numVerts = len >> 1

  poly.axes = for i in [0...len] by 2
    x1 = verts[i  ]
    y1 = verts[i+1]
    x2 = verts[(i+2)%len]
    y2 = verts[(i+3)%len]

    n = vnormalize new Vect y1-y2, x2-x1
    d = vdot2 n.x, n.y, x1, y1
    new Axis n, d

exports.setupPoly = (poly) ->
  setAxes poly
  poly.tVerts = new Array poly.verts.length
  poly.tAxes = (new Axis vzero, 0 for [0...poly.axes.length])

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
    n = vrotate src[i].n, rot
    dst[i].n = n
    dst[i].d = vdot(p, n) + src[i].d

exports.updatePoly = (poly, p, rot) ->
  rot = vforangle rot if typeof rot is 'number'
  transformVerts poly, p, rot
  transformAxes poly, p, rot

valueOnAxis = (poly, n, d) ->
  tVerts = poly.tVerts
  m = vdot2 n.x, n.y, tVerts[0], tVerts[1]
  
  for i in [2...tVerts.length] by 2
    m = min m, vdot2(n.x, n.y, tVerts[i], tVerts[i+1])
  
  m - d

containsVert = (poly, vx, vy) ->
  tAxes = poly.tAxes
  for i in [0...tAxes.length]
    n = tAxes[i].n
    dist = vdot2(n.x, n.y, vx, vy) - tAxes[i].d
    return false if dist > 0
  
  true

containsVertPartial = (poly, vx, vy, n) ->
  tAxes = poly.tAxes
  for i in [0...tAxes.length]
    n2 = tAxes[i].n
    continue if(vdot(n2, n) < 0)
    dist = vdot2(n2.x, n2.y, vx, vy) - tAxes[i].d
    return false if dist > 0
  
  true

# Find the minimum separating axis for the given poly and axis list.
#
# This function needs to return two values - the index of the min. separating axis and
# the value itself. Short of inlining MSA, returning values through a global like this
# is the fastest implementation.
#
# See: http://jsperf.com/return-two-values-from-function/2
last_MSA_min = 0
findMSA = (poly, axes) ->
  min_index = 0
  msa_min = valueOnAxis poly, axes[0].n, axes[0].d
  return -1 if msa_min > 0
  
  for i in [1...axes.length]
    dist = valueOnAxis poly, axes[i].n, axes[i].d
    return -1 if dist > 0

    if dist > msa_min
      msa_min = dist
      min_index = i
  
  last_MSA_min = msa_min
  return min_index

# Add contacts for probably penetrating vertexes.
# This handles the degenerate case where an overlap was detected, but no vertexes fall inside
# the opposing polygon. (like a star of david)
findVertsFallback = (poly1, poly2, n, dist) ->
  arr = []

  verts1 = poly1.tVerts
  for i in [0...verts1.length] by 2
    vx = verts1[i]
    vy = verts1[i+1]
    if containsVertPartial poly2, vx, vy, vneg(n)
      arr.push new Contact new Vect(vx, vy), n, dist
  
  verts2 = poly2.tVerts
  for i in [0...verts2.length] by 2
    vx = verts2[i]
    vy = verts2[i+1]
    if containsVertPartial poly1, vx, vy, n
      arr.push new Contact new Vect(vx, vy), n, dist
  
  arr

# Add contacts for penetrating vertexes.
findVerts = (poly1, poly2, n, dist) ->
  arr = []

  verts1 = poly1.tVerts
  for i in [0...verts1.length] by 2
    vx = verts1[i]
    vy = verts1[i+1]
    if containsVert poly2, vx, vy
      arr.push new Contact new Vect(vx, vy), n, dist
    
  verts2 = poly2.tVerts
  for i in [0...verts2.length] by 2
    vx = verts2[i]
    vy = verts2[i+1]
    if containsVert poly2, vx, vy
      arr.push new Contact new Vect(vx, vy), n, dist
  
  if arr.length then arr else findVertsFallback poly1, poly2, n, dist

# Collide poly shapes together.
exports.poly2poly = (poly1, poly2) ->
  mini1 = findMSA poly2, poly1.tAxes
  return NONE if mini1 is -1
  min1 = last_MSA_min
  
  mini2 = findMSA poly1, poly2.tAxes
  return NONE if mini2 is -1
  min2 = last_MSA_min
  
  # There is overlap, find the penetrating verts
  if min1 > min2
    findVerts poly1, poly2, poly1.tAxes[mini1].n, min1
  else
    findVerts poly1, poly2, vneg(poly2.tAxes[mini2].n), min2

###
// Like cpPolyValueOnAxis(), but for segments.
var segValueOnAxis = function(seg, n, d)
{
  var a = vdot(n, seg.ta) - seg.r;
  var b = vdot(n, seg.tb) - seg.r;
  return min(a, b) - d;
};

// Identify vertexes that have penetrated the segment.
var findPointsBehindSeg = function(arr, seg, poly, pDist, coef) 
{
  var dta = vcross(seg.tn, seg.ta);
  var dtb = vcross(seg.tn, seg.tb);
  var n = vmult(seg.tn, coef);
  
  var verts = poly.tVerts;
  for(var i=0; i<verts.length; i+=2){
    var vx = verts[i];
    var vy = verts[i+1];
    if(vdot2(vx, vy, n.x, n.y) < vdot(seg.tn, seg.ta)*coef + seg.r){
      var dt = vcross2(seg.tn.x, seg.tn.y, vx, vy);
      if(dta >= dt && dt >= dtb){
        arr.push(new Contact(new Vect(vx, vy), n, pDist, hashPair(poly.hashid, i)));
      }
    }
  }
};

// This one is complicated and gross. Just don't go there...
// TODO: Comment me!
var seg2poly = function(seg, poly)
{
  var arr = [];

  var axes = poly.tAxes;
  var numVerts = axes.length;
  
  var segD = vdot(seg.tn, seg.ta);
  var minNorm = poly.valueOnAxis(seg.tn, segD) - seg.r;
  var minNeg = poly.valueOnAxis(vneg(seg.tn), -segD) - seg.r;
  if(minNeg > 0 || minNorm > 0) return NONE;
  
  var mini = 0;
  var poly_min = segValueOnAxis(seg, axes[0].n, axes[0].d);
  if(poly_min > 0) return NONE;
  for(var i=0; i<numVerts; i++){
    var dist = segValueOnAxis(seg, axes[i].n, axes[i].d);
    if(dist > 0){
      return NONE;
    } else if(dist > poly_min){
      poly_min = dist;
      mini = i;
    }
  }
  
  var poly_n = vneg(axes[mini].n);
  
  var va = vadd(seg.ta, vmult(poly_n, seg.r));
  var vb = vadd(seg.tb, vmult(poly_n, seg.r));
  if(poly.containsVert(va.x, va.y))
    arr.push(new Contact(va, poly_n, poly_min, hashPair(seg.hashid, 0)));
  if(poly.containsVert(vb.x, vb.y))
    arr.push(new Contact(vb, poly_n, poly_min, hashPair(seg.hashid, 1)));
  
  // Floating point precision problems here.
  // This will have to do for now.
//  poly_min -= cp_collision_slop; // TODO is this needed anymore?
  
  if(minNorm >= poly_min || minNeg >= poly_min) {
    if(minNorm > minNeg)
      findPointsBehindSeg(arr, seg, poly, minNorm, 1);
    else
      findPointsBehindSeg(arr, seg, poly, minNeg, -1);
  }
  
  // If no other collision points are found, try colliding endpoints.
  if(arr.length === 0){
    var mini2 = mini * 2;
    var verts = poly.tVerts;

    var poly_a = new Vect(verts[mini2], verts[mini2+1]);
    
    var con;
    if((con = circle2circleQuery(seg.ta, poly_a, seg.r, 0, arr))) return [con];
    if((con = circle2circleQuery(seg.tb, poly_a, seg.r, 0, arr))) return [con];

    var len = numVerts * 2;
    var poly_b = new Vect(verts[(mini2+2)%len], verts[(mini2+3)%len]);
    if((con = circle2circleQuery(seg.ta, poly_b, seg.r, 0, arr))) return [con];
    if((con = circle2circleQuery(seg.tb, poly_b, seg.r, 0, arr))) return [con];
  }

//  console.log(poly.tVerts, poly.tAxes);
//  console.log('seg2poly', arr);
  return arr;
};
###

exports.circle2poly = (circ, poly) ->
  axes = poly.tAxes
  
  mini = 0
  least = vdot(axes[0].n, circ.tc) - axes[0].d - circ.r
  for i in [0...axes.length]
    dist = vdot(axes[i].n, circ.tc) - axes[i].d - circ.r
    if dist > 0
      return NONE
    else if dist > least
      least = dist
      mini = i
  
  n = axes[mini].n

  verts = poly.tVerts
  len = verts.length
  mini2 = mini<<1

  #var a = poly.tVerts[mini]
  #var b = poly.tVerts[(mini + 1)%poly.tVerts.length]
  x1 = verts[mini2]
  y1 = verts[mini2+1]
  x2 = verts[(mini2+2)%len]
  y2 = verts[(mini2+3)%len]

  dta = vcross2 n.x, n.y, x1, y1
  dtb = vcross2 n.x, n.y, x2, y2
  dt = vcross n, circ.tc
    
  if dt < dtb
    con = circle2circleQuery(circ.tc, new Vect(x2, y2), circ.r, 0, con)
    if con then [con] else NONE
  else if dt < dta
    [new Contact(
      vsub(circ.tc, vmult(n, circ.r + least/2)),
      vneg(n),
      least
    )]
  else
    con = circle2circleQuery(circ.tc, new Vect(x1, y1), circ.r, 0, con)
    if con then [con] else NONE
