# Stolen from Chipmunk

min = Math.min
max = Math.max

Vect = (@x, @y) ->
v = (x, y) -> new Vect x, y
window.v = v
#module.exports = v
v.Vect = Vect

v.add = (v1, v2) -> new Vect v1.x + v2.x, v1.y + v2.y
v.sub = (v1, v2) -> new Vect v1.x - v2.x, v1.y - v2.y
v.neg = (a) -> new Vect -a.x, -a.y
v.mult = (a, f) -> new Vect a.x * f, a.y * f
v.dot = (v1, v2) -> v1.x * v2.x + v1.y * v2.y
v.dot2 = (x1, y1, x2, y2) -> x1 * x2 + y1 * y2
v.cross = (v1, v2) -> v1.x * v2.y - v1.y * v2.x
v.cross2 = (x1, y1, x2, y2) -> x1 * y2 - y1 * x2
v.lensq = (a) -> v.dot a, a
v.len = (a) -> Math.sqrt v.dot a, a
v.perp = (a) -> new Vect -a.y, a.x
v.normalize = (a) -> v.mult a, 1/v.len(a)
v.rotate = (v1, v2) -> new Vect v1.x*v2.x - v1.y*v2.y, v1.x*v2.y + v1.y*v2.x
v.rotate2 = (x, y, a) -> new Vect x*a.x - y*a.y, x*a.y + y*a.x
v.forangle = (a) -> new Vect Math.cos(a), Math.sin(a)
v.clamp = (f, minv, maxv) -> min(max(f, minv), maxv)
v.clamp01 = (f) -> min(max(f, 0), 1)

v.zero = new Vect(0,0)

