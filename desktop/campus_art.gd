extends RefCounted

const BRICK = Color("#a66c55")
const STONE = Color("#d4c6a2")
const GLASS = Color("#719d99")
const ROOF = Color("#536c6a")
const FRAME = Color("#6e6655")

static func hall(g, p: Vector3, width: float, height: float):
 var depth = 0.62
 g.box(p + Vector3.UP * 0.055, Vector3(width + 0.12, 0.11, depth + 0.14), STONE)
 g.box(p + Vector3.UP * (0.1 + height / 2), Vector3(width, height, depth), BRICK)
 for floor_index in 2:
  for column in 5:
   var center = p + Vector3((column - 2) * width / 5.6, 0.22 + floor_index * height * 0.46, depth / 2 + 0.014)
   g.box(center, Vector3(width * 0.095, height * 0.2, 0.024), GLASS)
   g.box(center + Vector3.UP * height * 0.11, Vector3(width * 0.12, 0.021, 0.04), STONE)
 var top = p + Vector3.UP * (height + 0.11)
 for side in[-1, 1]:
  var a = top + Vector3(- width / 2 - 0.07, 0, side * (depth / 2 + 0.07))
  var b = top + Vector3(- width / 2 - 0.07, 0.2, 0)
  g.quad(a, a + Vector3.RIGHT * (width + 0.14), b + Vector3.RIGHT * (width + 0.14), b, ROOF, Vector3.UP)
 g.beam(top + Vector3(- width / 2 - 0.07, 0.2, 0), top + Vector3(width / 2 + 0.07, 0.2, 0), 0.025, 0.025, STONE)

static func greenhouse(g, p: Vector3):
 var span = Vector3(0.53, 0.28, 0.84)
 g.box(p + Vector3.UP * 0.16, span, GLASS)
 for end in[-1, 1]:
  var a = p + Vector3(end * 0.28, 0.3, -0.46)
  var b = p + Vector3(0, 0.49, -0.46)
  g.quad(a, b, b + Vector3.BACK * 0.92, a + Vector3.BACK * 0.92, GLASS.lightened(0.16), Vector3.UP)
  for i in 5:
   var offset = Vector3.BACK * i * 0.22
   g.beam(a + offset, b + offset, 0.014, 0.014, STONE, 5)
   g.beam(a + offset, a + offset - Vector3.UP * 0.26, 0.013, 0.013, STONE, 5)

static func campus(g, p: Vector3, university: bool):
 hall(g, p + Vector3(-0.13, 0, -0.32), 1.42 if university else 0.98, 0.77 if university else 0.55)
 if university:
  var portico = p + Vector3(-0.12, 0, 0.18)
  g.box(portico + Vector3.UP * 0.66, Vector3(0.64, 0.1, 0.29), STONE)
  for x in[-0.23, 0.23]:
   g.beam(portico + Vector3(x, 0.08, 0.1), portico + Vector3(x, 0.64, 0.1), 0.055, 0.055, STONE, 8)
  for n in 3:
   g.box(portico + Vector3(0, 0.09 - n * 0.025, 0.17 + n * 0.07), Vector3(0.68, 0.06, 0.12), STONE)
  hall(g, p + Vector3(-0.63, 0, 0.49), 0.47, 0.35)
 greenhouse(g, p + Vector3(0.62, 0, 0.55))
 for row in 3:
  g.box(p + Vector3(0.08, 0.06, 0.47 + row * 0.13), Vector3(0.43, 0.07, 0.075), Color("#81955e").lightened(0.06 * row))

static func engineering(g, p: Vector3):
 hall(g, p + Vector3(-0.13, 0, -0.27), 1.38, 0.52)
 preload("res://farm_models.gd").tractor(g, p + Vector3(0.22, 0.04, 0.5))
 var base = p + Vector3(-0.67, 0, 0.48)
 g.beam(base, base + Vector3.UP * 1.0, 0.065, 0.035, FRAME, 6)
 for arm in 3:
  var axis = Vector3(cos(arm * TAU / 3), 0, sin(arm * TAU / 3)) * 0.23
  g.beam(base + Vector3.UP, base + Vector3.UP + axis, 0.014, 0.012, STONE)
  g.oval(base + Vector3.UP + axis, Vector3(0.052, 0.041, 0.052), ROOF)
