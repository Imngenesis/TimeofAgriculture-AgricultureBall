extends RefCounted

const V = preload("res://valley.gd")
const VIEW = Vector3(10.8, 21.4, 25.8)

static func material(texture: Texture2D, grass: bool = false) -> ShaderMaterial:
 var mat = ShaderMaterial.new()
 mat.shader = preload("res://foliage.gdshader")
 mat.set_shader_parameter("leaves", texture)
 mat.set_shader_parameter("flex", 0.041 if grass else 0.019)
 return mat



static func batch(items: Array, mat: Material) -> MultiMeshInstance3D:
 var quad = QuadMesh.new()
 quad.size = Vector2.ONE; quad.material = mat
 var mesh = MultiMesh.new()
 mesh.transform_format = MultiMesh.TRANSFORM_3D
 mesh.use_custom_data = true
 mesh.mesh = quad; mesh.instance_count = items.size()
 var front = VIEW.normalized()
 var right = Vector3.UP.cross(front).normalized()
 var up = front.cross(right).normalized()
 for i in items.size():
  var item = items[i]
  var basis = Basis(right * item[1], up * item[2], front)
  mesh.set_instance_transform(i, Transform3D(basis, item[0] + up * (0.5 * item[2])))
  mesh.set_instance_custom_data(i, Color(item[3], item[4], item[5], 1))
 var node = MultiMeshInstance3D.new()
 node.multimesh = mesh
 return node


static func record_clearances(groups: Array):
 var front = VIEW.normalized()
 var right = Vector3.UP.cross(front).normalized()
 var up = front.cross(right)
 for trees in groups:
  for tree in trees:
   var plots = PackedInt32Array()
   for id in V.COLS * V.ROWS:
    var offset = V.v3(V.center(id), 0.45) - tree[0]
    if absf(offset.dot(front)) > 5.4: continue
    var across = absf(offset.dot(right))
    var above = offset.dot(up)
    var near_trunk = Vector2(offset.x, offset.z).length_squared() < 4.84
    var masks_site = across < 0.94 + tree[1] * 0.47 and above >= -0.68 and above < tree[2] + 1.03
    if near_trunk or masks_site:
     plots.append(id)
   tree.append(plots)

static func visible_trees(trees: Array, developed: PackedByteArray) -> Array:
 var result = []
 for tree in trees:
  var visible = true
  for id in tree[6]:
   if developed[id]:
    visible = false
    break
  if visible: result.append(tree)
 return result

static func rice_field(id: int, c: Dictionary, season: int, mat: Material) -> MultiMeshInstance3D:
 var plants = []
 var rng = RandomNumberGenerator.new(); rng.seed = id * 379 + 41
 var mature = season == 2
 for row in 8:
  for col in 8:
   var x = -0.84 + col * 0.24 + rng.randf_range(-0.035, 0.035)
   var z = -0.84 + row * 0.24 + rng.randf_range(-0.035, 0.035)
   var lift = 0.066 + (0.052 * floori(clampi(floori((z + 0.96) / (1.92 / 7)), 0, 6) / 2.0) if c.terrace else 0.0)
   var base = V.v3(V.center(id) + Vector2(x, z), lift)
   var height = rng.randf_range(0.35, 0.46) if mature else rng.randf_range(0.22, 0.3)
   plants.append([base, height * 0.85, height, rng.randf(), 1.0 if mature else 0.0, rng.randf()])
 return batch(plants, mat)
