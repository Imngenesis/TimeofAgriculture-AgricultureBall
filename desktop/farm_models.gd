extends RefCounted

const TIMBER = Color("#76523d")
const DARK = Color("#423f34")
const TILE = Color("#52676b")
const PLASTER = Color("#cebf9d")
const STONE = Color("#969787")


static func tile_house(g, p: Vector3, scale_by: float, yaw: float, raised: bool):
 var x = Vector3(cos(yaw), 0, sin(yaw)) * scale_by
 var z = Vector3(- sin(yaw), 0, cos(yaw)) * scale_by
 var y = Vector3.UP * scale_by
 var b = p + y * (0.32 if raised else 0.08)
 g.box(p + y * 0.035, Vector3(1.14, 0.12, 0.84) * scale_by, STONE, yaw)
 g.finish = 4
 g.box(b + y * 0.3, Vector3(1.0, 0.6, 0.7) * scale_by, PLASTER, yaw)
 g.finish = 2
 for xx in[-0.47, -0.17, 0.16, 0.47]:
  for zz in[-0.36, 0.36]:
   var foot = b + x * xx + z * zz
   g.beam(foot - y * 0.31, foot + y * 0.65, 0.035 * scale_by, 0.035 * scale_by, TIMBER, 8)
 g.box(b + y * 0.22 + z * 0.355, Vector3(0.27, 0.44, 0.034) * scale_by, DARK, yaw)
 for xx in[-0.32, 0.32]:
  var w = b + x * xx + z * 0.365 + y * 0.34
  g.box(w, Vector3(0.21, 0.22, 0.03) * scale_by, Color("#394f4d"), yaw)
  for n in[-1, 0, 1]:
   g.box(w + x * n * 0.056 + z * 0.019, Vector3(0.014, 0.23, 0.02) * scale_by, TIMBER, yaw)
  g.box(w + z * 0.023, Vector3(0.22, 0.02, 0.02) * scale_by, TIMBER, yaw)
 var profile = [Vector2(0.0, 1.02), Vector2(0.19, 0.84), Vector2(0.38, 0.69), Vector2(0.54, 0.65)]
 g.finish = 3
 for side in[-1, 1]:
  for bay in 16:
   var u = -0.64 + bay * 0.08
   var lip = 0.064 * pow(absf(u) / 0.64, 4)
   for j in 3:
    var a = b + x * u + y * (profile[j].y + lip * j / 3.0) + z * (side * profile[j].x)
    var d = b + x * u + y * (profile[j + 1].y + lip * (j + 1) / 3.0) + z * (side * profile[j + 1].x)
    g.quad(a, a + x * 0.081, d + x * 0.081, d, TILE.lightened(0.028 * ((bay + j) % 4)), y + z * side)
    if j == 2 or bay % 2 == 0: g.beam(a, d, 0.019 * scale_by, 0.022 * scale_by, TILE.lightened(0.16), 5)
  var a = b - x * 0.68 + z * side * 0.54 + y * 0.66
  g.beam(a, a + x * 1.36, 0.031 * scale_by, 0.031 * scale_by, TIMBER, 6)
 g.beam(b - x * 0.7 + y * 1.03, b + x * 0.7 + y * 1.03, 0.043 * scale_by, 0.043 * scale_by, TILE.lightened(0.15), 8)
 g.finish = 0
 for n in 3:
  g.box(b + z * (0.42 + n * 0.07) - y * (0.02 + n * 0.035), Vector3(0.36, 0.07, 0.12) * scale_by, STONE.darkened(n * 0.03), yaw)

static func wheel(g, p: Vector3):
 var radius = 0.42
 for k in 16:
  var a = TAU * k / 16
  var b = TAU * (k + 1) / 16
  var arm = Vector3(0, cos(a), sin(a))
  var edge = Vector3(0, cos(b), sin(b))
  for dx in[-0.09, 0.09]:
   var hub = p + Vector3.RIGHT * dx
   g.beam(hub + arm * radius, hub + edge * radius, 0.029, 0.029, TIMBER, 5)
   if k % 2 == 0: g.beam(hub, hub + arm * radius, 0.018, 0.021, DARK, 5)
  g.box(p + arm * (radius + 0.018), Vector3(0.27, 0.045, 0.1), TIMBER.lightened(0.2))
 g.beam(p - Vector3.RIGHT * 0.3, p + Vector3.RIGHT * 0.32, 0.052, 0.052, DARK, 8)

static func depot(g, p: Vector3, kind: String):
 if kind == "wood":
  for row in 3:
   for j in(4 - row):
    var a = p + Vector3(-0.65, row * 0.13 + 0.09, 0.08 + j * 0.155 + row * 0.075)
    g.beam(a, a + Vector3(1.0, 0.015, 0.08), 0.085, 0.079, TIMBER.darkened(0.06 * j), 10)
    g.beam(a - Vector3.RIGHT * 0.012, a + Vector3.RIGHT * 0.003, 0.078, 0.078, Color("#c6a876"), 10)
  for dx in[-0.46, 0.44]:
   g.beam(p + Vector3(dx - 0.14, 0, -0.6), p + Vector3(dx, 0.44, -0.47), 0.04, 0.033, DARK)
   g.beam(p + Vector3(dx + 0.13, 0, -0.33), p + Vector3(dx, 0.42, -0.47), 0.04, 0.033, DARK)
  g.beam(p + Vector3(-0.71, 0.4, -0.53), p + Vector3(0.72, 0.42, -0.45), 0.12, 0.085, TIMBER, 10)
 else:
  for i in 8:
   var q = p + Vector3(-0.51 + (i % 3) * 0.37, 0.08 + 0.16 * floori(i / 6.0), -0.39 + 0.36 * (floori(i / 3.0) % 2))
   g.box(q, Vector3(0.34, 0.19, 0.28), STONE.darkened(i % 3 * 0.08), 0.08 * (i % 3))
  g.beam(p + Vector3(0.52, 0, 0.43), p + Vector3(0.34, 0.64, 0.42), 0.027, 0.027, TIMBER)
  g.beam(p + Vector3(0.21, 0.58, 0.42), p + Vector3(0.47, 0.65, 0.42), 0.045, 0.02, DARK)

static func tractor(g, p: Vector3):
 var paint = Color("#a75f40")
 g.box(p + Vector3(0, 0.19, 0), Vector3(0.76, 0.11, 0.29), DARK)
 g.box(p + Vector3(0.16, 0.3, 0), Vector3(0.44, 0.21, 0.31), paint)
 for dx in[-0.25, 0.26]:
  var radius = 0.19 if dx < 0 else 0.115
  for side in[-1, 1]:
   var hub = p + Vector3(dx, radius, 0.2 * side)
   var axis = Vector3.BACK * side
   g.beam(hub - axis * 0.06, hub + axis * 0.06, radius, radius, Color("#303733"), 14)
   g.beam(hub + axis * 0.061, hub + axis * 0.071, radius * 0.54, radius * 0.54, Color("#c3ab70"), 12)
   for k in 10:
    var u = Vector3(cos(TAU * k / 10), sin(TAU * k / 10), 0)
    g.beam(hub + u * radius - axis * 0.04, hub + u * radius + axis * 0.05, 0.012, 0.012, DARK, 4)
 for dx in[-0.36, -0.09]:
  for dz in[-0.145, 0.145]:
   var base = p + Vector3(dx, 0.29, dz)
   g.beam(base, base + Vector3.UP * 0.34, 0.016, 0.014, TIMBER)
 g.box(p + Vector3(-0.22, 0.64, 0), Vector3(0.38, 0.04, 0.38), Color("#c8bea2"))
 g.beam(p + Vector3(0.19, 0.4, 0.085), p + Vector3(0.19, 0.59, 0.085), 0.024, 0.024, DARK, 8)
 for k in 4: g.box(p + Vector3(0.385, 0.26 + 0.033 * k, 0), Vector3(0.015, 0.014, 0.23), DARK)
