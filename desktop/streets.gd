extends RefCounted

const V = preload("res://valley.gd")
const WORKS = ["farm", "house", "store", "nursery", "canal", "station", "wood", "stone", "engineering", "pasture"]
static var terrain_graphs = {}

static func graph() -> Array:
 if terrain_graphs.has(V.biome): return terrain_graphs[V.biome]
 var graph_rows = []
 for id in V.COLS * V.ROWS:
  var links = []
  if V.tier(id) >= 0:
   var p = V.center(id)
   for dir in 6:
    var other = V.nb(id, dir)
    if other < 0 or V.tier(other) < 0: continue
    var q = V.center(other)
    if(p.x - V.river(p.y)) * (q.x - V.river(q.y)) > 0: links.append(other)
  graph_rows.append(links)
 for z in[-3.5, 4.8]:
  var banks = []
  for side in[-1, 1]:
   var landing = Vector2(V.river(z) + side * (V.breadth(z) + 1.75), z)
   var nearest = -1
   var distance = INF
   for id in graph_rows.size():
    if V.tier(id) < 0: continue
    var p = V.center(id)
    if(p.x - V.river(p.y)) * side <= 0: continue
    var d = p.distance_squared_to(landing)
    if d < distance: nearest = id; distance = d
   banks.append(nearest)
  if banks[1] not in graph_rows[banks[0]]:
   graph_rows[banks[0]].append(banks[1])
   graph_rows[banks[1]].append(banks[0])
 terrain_graphs[V.biome] = graph_rows
 return graph_rows

static func passable(s: Dictionary, id: int) -> bool:
 return id >= 0 and id < s.cells.size() and V.tier(id) >= 0 and V.sector(id) in s.districts

static func explore(s: Dictionary, start: int, target: int, built: bool) -> Dictionary:
 var seen = {start: -1}
 var queue = [start]
 var edges = graph()
 var next = 0
 while next < queue.size():
  var id: int = queue[next]
  next += 1
  if id == target: break
  for neighbor in edges[id]:
   if seen.has(neighbor) or V.sector(neighbor) not in s.districts: continue
   if built and not s.streets.has(V.edge_key(id, neighbor)): continue
   seen[neighbor] = id
   queue.append(neighbor)
 return seen

static func path(s: Dictionary, start: int, target: int, built: bool = false) -> Array:
 if not passable(s, start) or not passable(s, target): return[]
 var prev = explore(s, start, target, built)
 if not prev.has(target): return[]
 var tiles = [target]
 while tiles[0] != start: tiles.push_front(prev[tiles[0]])
 return tiles

static func bridge(a: int, b: int) -> bool:
 var p = V.center(a)
 var q = V.center(b)
 return(p.x - V.river(p.y)) * (q.x - V.river(q.y)) < 0

static func points(tiles: Array) -> PackedVector2Array:
 var shape = PackedVector2Array()
 if tiles.is_empty(): return shape
 shape.append(V.center(tiles[0]))
 for i in range(1, tiles.size()):
  var curve = V.crossing(V.center(tiles[i - 1]), V.center(tiles[i]))
  for j in range(1, curve.size()): shape.append(curve[j])
 return shape

static func quote(s: Dictionary, a: int, b: int) -> Dictionary:
 var tiles = path(s, a, b)
 var extra = []
 var stone = 0
 for i in range(1, tiles.size()):
  var left: int = tiles[i - 1]; var right: int = tiles[i]
  if s.streets.has(V.edge_key(left, right)): continue
  extra.append([left, right])
  if bridge(left, right): stone += 1
 var wood = ceili(extra.size() / 2.0)
 var why = ""
 if tiles.is_empty(): why = "两端须是已开通的陆地，跨河请从桥头通过"
 elif extra.is_empty(): why = "沿线已铺好，请延伸到另一块地"
 elif s.wood < wood or s.stone < stone: why = "营地材料不足，需要 %d 木、%d 石" % [wood, stone]
 return {"tiles": tiles, "extra": extra, "wood": wood, "stone": stone, "reason": why}

static func removal(s: Dictionary, a: int, b: int) -> Dictionary:
 var tiles = path(s, a, b, true)
 var segments = []
 for i in range(1, tiles.size()): segments.append([tiles[i - 1], tiles[i]])
 return {"tiles": tiles, "extra": segments, "wood": 0, "stone": 0, "reason": "请选择同一条现有道路上的两个端点" if segments.is_empty() else ""}

static func dismantle(s: Dictionary, a: int, b: int) -> String:
 var plan = removal(s, a, b)
 if plan.reason != "": return plan.reason
 for pair in plan.extra: s.streets.erase(V.edge_key(pair[0], pair[1]))
 rebuild(s)
 s.rev += 1
 return ""

static func root(s: Dictionary) -> int:
 for id in s.cells.size():
  if s.cells[id].kind == "academy": return id
 return -1

static func rebuild(s: Dictionary):
 var source = root(s)
 var seen = explore(s, source, -1, true) if source >= 0 else {}
 for id in s.cells.size(): s.cells[id].connected = seen.has(id)

static func build(s: Dictionary, a: int, b: int) -> String:
 var plan = quote(s, a, b)
 if plan.reason != "": return plan.reason
 for pair in plan.extra: s.streets[V.edge_key(pair[0], pair[1])] = pair
 for k in["wood", "stone"]:
  s[k] -= plan[k]
  s.ledger[k + "_out"] += plan[k]
 rebuild(s)
 s.rev += 1
 return ""

static func inherit_path(s: Dictionary, a: int, b: int):
 var tiles = path(s, a, b)
 for i in range(1, tiles.size()):
  s.streets[V.edge_key(tiles[i - 1], tiles[i])] = [tiles[i - 1], tiles[i]]

static func migrate(s: Dictionary, anchors: Array):
 s.streets = {}
 for route in s.frontier.roads.values(): inherit_path(s, anchors[route[0]], anchors[route[1]])
 var source = root(s)
 if source >= 0:
  inherit_path(s, source, s.frontier.home)
  for z in s.frontier.posts: inherit_path(s, source, anchors[z])
  for id in s.cells.size():
   if s.cells[id].kind in WORKS or s.cells[id].project != "": inherit_path(s, source, id)
 s.frontier.roads.clear()
 rebuild(s)
