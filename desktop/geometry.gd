extends RefCounted

var vertices = PackedVector3Array()
var normals = PackedVector3Array()
var colors = PackedColorArray()
var finishes = PackedVector2Array()
var mark_finishes = false
var finish = 0

func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, outward: Vector3 = Vector3.UP):
 var n = (c - a).cross(b - a)
 if n.length_squared() < 1e-8: return
 if n.dot(outward) < 0:
  var swap = b
  b = c
  c = swap
  n = - n
 n = n.normalized()
 vertices.append(a); vertices.append(b); vertices.append(c)
 normals.append(n); normals.append(n); normals.append(n)
 colors.append(color); colors.append(color); colors.append(color)
 if mark_finishes:
  var id = Vector2(finish, 0)
  finishes.append(id); finishes.append(id); finishes.append(id)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, outward: Vector3 = Vector3.UP):
 tri(a, b, c, col, outward)
 tri(a, c, d, col, outward)

func gradient_triangle(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, na: Vector3, nb: Vector3, nc: Vector3):
 vertices.append(a); vertices.append(b); vertices.append(c)
 colors.append(ca); colors.append(cb); colors.append(cc)
 normals.append(na); normals.append(nb); normals.append(nc)
 if mark_finishes:
  var id = Vector2(finish, 0)
  finishes.append(id); finishes.append(id); finishes.append(id)

func beam(a: Vector3, b: Vector3, ra: float, rb: float, col: Color, sides: int = 6):
 var axis = b - a
 if axis.length_squared() < 0.000001: return
 axis = axis.normalized()
 var u = axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
 var v = axis.cross(u)
 for i in sides:
  var t = TAU * i / sides
  var w = TAU * (i + 1) / sides
  var p = u * cos(t) + v * sin(t)
  var q = u * cos(w) + v * sin(w)
  quad(a + p * ra, a + q * ra, b + q * rb, b + p * rb, col, p + q)
  if rb > 0.009: tri(b, b + p * rb, b + q * rb, col, axis)

func box(p: Vector3, size: Vector3, col: Color, yaw: float = 0.0):
 var x = Vector3(cos(yaw), 0, sin(yaw)) * size.x * 0.5
 var y = Vector3.UP * size.y * 0.5
 var z = Vector3(- sin(yaw), 0, cos(yaw)) * size.z * 0.5
 quad(p + x + y + z, p - x + y + z, p - x + y - z, p + x + y - z, col, Vector3.UP)
 quad(p + x - y + z, p + x + y + z, p + x + y - z, p + x - y - z, col, x)
 quad(p - x - y + z, p - x + y + z, p - x + y - z, p - x - y - z, col, - x)
 quad(p + x - y + z, p + x + y + z, p - x + y + z, p - x - y + z, col, z)
 quad(p + x - y - z, p + x + y - z, p - x + y - z, p - x - y - z, col, - z)
 quad(p + x - y + z, p - x - y + z, p - x - y - z, p + x - y - z, col, Vector3.DOWN)

func oval(p: Vector3, size: Vector3, col: Color, seed_value: float = 0.0, sides: int = 8, rings: int = 4):
 for k in rings:
  var lat = - PI / 2 + PI * k / rings
  var high = lat + PI / rings
  for j in sides:
   var lon = TAU * j / sides + seed_value
   var east = lon + TAU / sides
   var a = _ov(size, lat, lon, seed_value)
   var b = _ov(size, lat, east, seed_value)
   var c = _ov(size, high, east, seed_value)
   var d = _ov(size, high, lon, seed_value)
   var shade = clampf(0.95 + 0.055 * sin(j * 39.2 + k * 55.1 + seed_value) + 0.04 * sin(lat), 0.85, 1.04)
   quad(p + a, p + b, p + c, p + d, Color(col.r * shade, col.g * shade, col.b * shade), a + b + c + d)

func _ov(size: Vector3, lat: float, lon: float, seed_value: float) -> Vector3:
 var wobble = 1.0 + 0.06 * sin(3 * lon + seed_value + lat) * cos(lat)
 return Vector3(size.x * cos(lat) * cos(lon) * wobble, size.y * sin(lat), size.z * cos(lat) * sin(lon) * wobble)

func crown(p: Vector3, extent: Vector3, col: Color, phase: float):
 var verts = []
 var shades = []
 var dirs = []
 for j in 6:
  var lat = - PI / 2.0 + j * PI / 5
  for i in 11:
   var lon = TAU * i / 11 + phase + 0.16 * (j % 2)
   var normal = Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
   var rough = 0.91 + 0.095 * sin(phase * 5 + lon * 4 + lat * 2) * cos(lat) + 0.049 * cos(lat * 5 + lon * 3)
   verts.append(p + normal * extent * rough)
   dirs.append((normal / extent).normalized())
   var shade = 0.61 + 0.23 * (normal.y + 1.0) * 0.5 + 0.14 * (1.0 + sin(lon * 4 + lat * 5 + phase)) * 0.5
   shades.append(Color(col.r * shade, col.g * shade, col.b * shade))
 for j in 5:
  for i in 11:
   var a = j * 11 + i
   var b = j * 11 + (i + 1) % 11
   for face in[[a, b, a + 11], [b, b + 11, a + 11]]:
    var k = face[0]; var l = face[1]; var m = face[2]
    gradient_triangle(verts[k], verts[l], verts[m], shades[k], shades[l], shades[m], dirs[k], dirs[l], dirs[m])

func bake(mat: Material) -> MeshInstance3D:
 var node = MeshInstance3D.new()
 if vertices.is_empty(): return node
 var a = []
 a.resize(Mesh.ARRAY_MAX)
 a[Mesh.ARRAY_VERTEX] = vertices
 a[Mesh.ARRAY_NORMAL] = normals
 a[Mesh.ARRAY_COLOR] = colors
 if mark_finishes: a[Mesh.ARRAY_TEX_UV] = finishes
 var mesh = ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
 mesh.surface_set_material(0, mat)
 node.mesh = mesh
 return node
