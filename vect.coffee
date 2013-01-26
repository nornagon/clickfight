# Stolen from Chipmunk

min = Math.min
max = Math.max

Vect = (@x, @y) ->
window.v = v = (x, y) -> new Vect x, y
v.Vect = Vect

v.add = (v1, v2) -> new Vect v1.x + v2.x, v1.y + v2.y
v.sub = (v1, v2) -> new Vect v1.x - v2.x, v1.y - v2.y
v.neg = (v) -> new Vect -v.x, -v.y
v.mult = (v, f) -> new Vect v.x * f, v.y * f
v.dot = (v1, v2) -> v1.x * v2.x + v1.y * v2.y
v.dot2 = (x1, y1, x2, y2) -> x1 * x2 + y1 * y2
v.cross = (v1, v2) -> v1.x * v2.y - v1.y * v2.x
v.cross2 = (x1, y1, x2, y2) -> x1 * y2 - y1 * x2
v.lengthsq = (v) -> v.dot v, v
v.length = (v) -> Math.sqrt v.dot v, v
v.perp = (v) -> new Vect -v.y, v.x
v.normalize = (v) -> v.mult v, 1/v.length(v)
v.rotate = (v1, v2) -> new Vect v1.x*v2.x - v1.y*v2.y, v1.x*v2.y + v1.y*v2.x
v.rotate2 = (x, y, v) -> new Vect x*v.x - y*v.y, x*v.y + y*v.x
v.forangle = (a) -> new Vect Math.cos(a), Math.sin(a)
v.clamp = (f, minv, maxv) -> min(max(f, minv), maxv)
v.clamp01 = (f) -> min(max(f, 0), 1)

v.zero = v(0,0)

