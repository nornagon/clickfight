# Stolen from Chipmunk

min = Math.min
max = Math.max

exports = window

Contact = (@p, @n, @dist) ->
  this.r1 = this.r2 = v.zero
  this.nMass = this.tMass = this.bounce = this.bias = 0

  this.jnAcc = this.jtAcc = this.jBias = 0

NONE = []


# Add contact points for circle to circle collisions.
# Used by several collision tests.
circle2circleQuery = (p1, p2, r1, r2) ->
  mindist = r1 + r2
  delta = v.sub(p2, p1)
  distsq = v.lengthsq(delta)
  return if distsq >= mindist*mindist
  
  dist = Math.sqrt distsq

  # Allocate and initialize the contact.
  new Contact(
    v.add(p1, v.mult(delta, 0.5 + (r1 - 0.5*mindist)/(dist ? dist : Infinity))),
    (if dist then v.mult(delta, 1/dist) else new Vect 1, 0),
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
  
  seg_delta = v.sub(seg_b, seg_a)
  closest_t = clamp01(v.dot(seg_delta, v.sub(center, seg_a))/v.lengthsq(seg_delta))
  closest = v.add(seg_a, v.mult(seg_delta, closest_t))
  
  contact = circle2circleQuery(center, closest, circleShape.r, segmentShape.r)

  if contact
    n = contact.n
    
    # Reject endcap collisions if tangents are provided.
    if(
      (closest_t == 0 and v.dot(n, segmentShape.a_tangent) < 0) ||
      (closest_t == 1 and v.dot(n, segmentShape.b_tangent) < 0)
    ) then NONE else [contact]
  else
    NONE

valueOnAxis = (poly, n, d) ->
  tVerts = poly.tVerts
  m = v.dot2 n.x, n.y, tVerts[0], tVerts[1]
  
  for i in [2...tVerts.length] by 2
    m = min m, v.dot2(n.x, n.y, tVerts[i], tVerts[i+1])
  
  m - d

containsVert = (poly, vx, vy) ->
  tAxes = poly.tAxes
  for i in [0...tAxes.length]
    n = tAxes[i].n
    dist = v.dot2(n.x, n.y, vx, vy) - tAxes[i].d
    return false if dist > 0
  
  true

containsVertPartial = (poly, vx, vy, n) ->
  tAxes = poly.tAxes
  for i in [0...tAxes.length]
    n2 = tAxes[i].n
    continue if(v.dot(n2, n) < 0)
    dist = v.dot2(n2.x, n2.y, vx, vy) - tAxes[i].d
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
    findVerts poly1, poly2, v.neg(poly2.tAxes[mini2].n), min2

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
  least = v.dot(axes[0].n, circ.tc) - axes[0].d - circ.r
  for i in [0...axes.length]
    dist = v.dot(axes[i].n, circ.tc) - axes[i].d - circ.r
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

  dta = v.cross2 n.x, n.y, x1, y1
  dtb = v.cross2 n.x, n.y, x2, y2
  dt = v.cross n, circ.tc
    
  if dt < dtb
    con = circle2circleQuery(circ.tc, new Vect(x2, y2), circ.r, 0, con)
    if con then [con] else NONE
  else if dt < dta
    [new Contact(
      v.sub(circ.tc, v.mult(n, circ.r + least/2)),
      v.neg(n),
      least
    )]
  else
    con = circle2circleQuery(circ.tc, new Vect(x1, y1), circ.r, 0, con)
    if con then [con] else NONE
