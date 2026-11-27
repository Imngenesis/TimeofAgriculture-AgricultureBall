extends RefCounted

const V = preload("res://valley.gd")
const Roads = preload("res://streets.gd")
const E = preload("res://economy.gd")
const Town = preload("res://settlement.gd")
const Crops = preload("res://crop_book.gd")
const Farm = preload("res://farmstead.gd")
const REGIONS = Crops.REGIONS
const START = Crops.START
const POSTS = [28, 73, 125, 177]
const HOMES = [28, 27, 20, 45]
const LOCAL_HOME = [28, 20, 27, 45, 29, 36]
const GOODS = ["food", "seed", "wood", "stone", "feed"]
const LABEL = {"food": "口粮", "seed": "种粮", "wood": "木料", "stone": "石料", "people": "居民", "feed": "饲料"}
const LOCAL = ["营地仓库", "每人每季产 1 粮、2 木", "每位得到口粮的居民采 2 石", "每人每季产 2 粮，每用 1 种再增 2 粮"]
const BOOK = ["husbandry", "livestock", "explore", "freight_in", "freight_out", "eggs", "milk", "dairy_loss"]

static func setup(s: Dictionary, region: int = 0, home: int = 28):
 var crop = START[region]
 s.frontier = {"region": region, "home": home, "samples": {}, "lines": {}, "plots": {}, "trials": {}, "mutation_turn": {},
  "serial": 0, "survey": [], "missions": [], "posts": {}, "roads": {}, "yards": {},
  "fresh": 22 if region == 4 else 0, "wells": 0, "water_short": 0, "feed": 0,
  "last": "本地作物 · " + Crops.title(crop), "rng": randi_range(1, 2147483646), "disease": {}}
 s.frontier.lines[crop] = Crops.line()
 for zone in s.districts:
  if zone > 0: E.open_district(s, zone)

static func anchor(s: Dictionary, zone: int) -> int:
 return s.frontier.home if zone == 0 else POSTS[zone]

static func samples_at(s: Dictionary, zone: int) -> Array:
 var pool = Crops.NAMES.duplicate()
 pool.erase(START[s.frontier.region])
 var offset = (zone - 1) * 2
 return[pool[offset % pool.size()], pool[(offset + 1) % pool.size()]]

static func incoming(s: Dictionary) -> int:
 var reserved = 0
 for j in s.frontier.missions:
  if j.kind == "survey" or(j.key == "people" and j.to == 0): reserved += j.amount
 return reserved

static func people_total(s: Dictionary) -> int:
 var total = s.pop
 for p in s.frontier.posts.values(): total += p.people
 for j in s.frontier.missions:
  if j.key == "people": total += j.amount
 return total

static func road_key(a: int, b: int) -> String:
 return "%d-%d" % [mini(a, b), maxi(a, b)]

static func route_points(s: Dictionary, a: int, b: int) -> PackedVector2Array:
 var start = V.center(anchor(s, a))
 var end = V.center(anchor(s, b))
 var bends = V.crossing(start, end)
 var path = PackedVector2Array([start])
 for i in bends.size() - 1:
  var left: Vector2 = bends[i]
  var right: Vector2 = bends[i + 1]
  var steps = maxi(1, ceili(left.distance_to(right) / 0.85))
  var l = left.x - V.river(left.y)
  var r = right.x - V.river(right.y)
  for j in range(1, steps + 1):
   var t = float(j) / steps
   var p = left.lerp(right, t)
   if l * r > 0:
    var margin = lerpf(absf(l) - V.breadth(left.y), absf(r) - V.breadth(right.y), t)
    p.x = V.river(p.y) + signf(l) * (V.breadth(p.y) + margin)
   path.append(p)
 return path

static func travel_time(path: PackedVector2Array, road: bool) -> int:
 var distance = 0.0
 for i in path.size() - 1: distance += path[i].distance_to(path[i + 1])
 return 2 + ceili(distance / (2.55 if road else 1.05))

static func route(s: Dictionary, a: int, b: int) -> Dictionary:
 var start = anchor(s, a)
 var end = anchor(s, b)
 var tiles = Roads.path(s, start, end, true) if s.cells[start].connected and s.cells[end].connected else[]
 var paved = not tiles.is_empty()
 var line = Roads.points(tiles) if paved else route_points(s, a, b)
 var stops = []
 for tile in tiles:
  for place in s.districts:
   if place not in[a, b] and anchor(s, place) == tile: stops.append(place)
 var seconds = travel_time(line, paved)
 if "trade_routes" in s.tech: seconds = maxi(1, ceili(seconds * 0.75))
 var capacity = 4
 if paved:
  capacity = 8 + (2 if "trade_routes" in s.tech else 0) + (4 if "harvest_network" in s.tech else 0)
 return {"path": line, "time": seconds, "capacity": capacity, "road": paved, "stops": stops}

static func journey_point(job: Dictionary, time: float) -> Vector2:
 var ratio = clampf((time - job.start) / maxf(1, job.due - job.start), 0, 1)
 if job.kind == "survey": ratio = 1.0 - absf(2.0 * ratio - 1.0)
 var path: PackedVector2Array = job.path
 var target = ratio * (path.size() - 1)
 var i = mini(floori(target), path.size() - 2)
 return path[i].lerp(path[i + 1], target - i)

static func stock(s: Dictionary, z: int, k: String) -> int:
 if z == 0:
  if k == "feed": return s.frontier.feed
  return s.pop if k == "people" else s[k]
 return s.frontier.posts[z] [k]

static func free_space(s: Dictionary, z: int, k: String) -> int:
 var capacity = Town.seed_space(s, z) if k == "seed" else Town.material_space(s, z, k)
 if k == "feed": capacity = Farm.Yards.feed_space(s, z)
 return maxi(0, capacity - stock(s, z, k) - E.inbound(s, z, k))

static func reason(m, cmd: String, arg) -> String:
 var s = m.s
 var f = s.frontier
 match cmd:
  "trial": return Crops.trial_reason(s, arg[0], arg[1])
  "sow":
   var id = int(arg[0])
   if id < 0 or id >= s.cells.size() or not f.lines.has(arg[1]) or s.cells[id].kind != "farm": return "请选择已投产的农田和已驯化作物"
  "survey":
   var z = int(arg[0])
   if z < 1 or z > 3 or arg[1] not in samples_at(s, z): return "请选择营地外的一处种源"
   for job in f.missions:
    if job.kind == "survey" and job.to == z: return "该地已有队伍在途中"
   if s.pop <= 2 or m.free_workers() < 2: return "需两名空闲居民，营地至少留一人"
   if s.food < 4 or s.wood < 1: return "行囊需 4 粮和 1 木"
  "road", "ship":
   var a = int(arg[0])
   var b = int(arg[1])
   if a == b or a not in s.districts or b not in s.districts: return "请选择两个不同的已开放聚落"
   if cmd == "road":
    return Roads.quote(s, anchor(s, a), anchor(s, b)).reason
   else:
    var k = str(arg[2])
    var amount = int(arg[3])
    if k not in LABEL or amount < 1: return "请选择货物和数量"
    if k == "people":
     if amount != 1: return "每次迁移一名居民"
     if a == 0 and(m.free_workers() < 1 or s.pop <= 1): return "营地需保留居民且有空闲人手"
     if b == 0 and s.pop + incoming(s) >= Town.beds(s): return "需要一个未预留的营地床位"
    elif amount > route(s, a, b).capacity: return "数量超过单批运力"
    if stock(s, a, k) < amount: return "出发地库存不足"
    if k in["seed", "wood", "stone", "feed"]:
     if amount > free_space(s, b, k): return "目的地仓位不足，已计入在途货物"
  _: return Farm.reason(s, cmd, arg)
 return ""

static func take_person(m):
 for i in range(m.s.workers.size() - 1, -1, -1):
  if m.s.workers[i].job == "":
   m.s.workers.remove_at(i)
   m.s.pop -= 1
   return

static func exchange(m, z: int, k: String, amount: int):
 var s = m.s
 if z != 0: s.frontier.posts[z] [k] += amount
 elif k == "people":
  if amount < 0: take_person(m)
  else:
   m.add_worker()
   s.pop += 1
 elif k == "feed": s.frontier.feed += amount
 elif k in["food", "seed"]:
  s[k] += amount
  s.ledger["freight_in" if amount > 0 else "freight_out"] += absi(amount)
 else: E.supply(s, k, amount)

static func action(m, cmd: String, arg) -> String:
 var why = reason(m, cmd, arg)
 if why != "": return why
 var s = m.s
 var f = s.frontier
 match cmd:
  "trial": Crops.start_trial(s, arg[0], arg[1])
  "sow":
   var id = int(arg[0])
   var name = arg[2] if arg.size() > 2 else f.preferred.get(arg[1], "原种")
   if not f.varieties.get(arg[1], {}).has(name): return "尚未育成此品系"
   if s.cells[id].crop:
    s.cells[id].next_species = arg[1]
    s.cells[id].next_variety = name
   else:
    f.plots[id] = arg[1]
    f.cultivars[id] = name
    s.cells[id].erase("next_species")
    s.cells[id].erase("next_variety")
   f.last = V.address(id) + "下茬安排种植" + Crops.title(arg[1]) + "。"
  "survey":
   var z = int(arg[0])
   var path = route_points(s, 0, z)
   s.food -= 4
   s.ledger.explore += 4
   E.supply(s, "wood", -1)
   take_person(m)
   take_person(m)
   f.missions.append({"kind": "survey", "key": "people", "amount": 2, "from": 0, "to": z, "crop": arg[1],
    "start": s.time, "due": s.time + 32, "path": path})
   f.last = "两人启程，32 秒后带着种源返回。"
  "road":
   Roads.build(s, anchor(s, arg[0]), anchor(s, arg[1]))
   f.last = V.SECTORS[arg[0]] + "至" + V.SECTORS[arg[1]] + "的道路已通车。"
  "ship":
   var itinerary = route(s, arg[0], arg[1])
   exchange(m, arg[0], arg[2], - arg[3])
   f.missions.append({"kind": "ship", "from": arg[0], "to": arg[1], "key": arg[2], "amount": arg[3],
    "start": s.time, "due": s.time + itinerary.time, "path": itinerary.path})
   f.last = "%s发往%s，%d 秒后到达。" % [LABEL[arg[2]], V.SECTORS[arg[1]], itinerary.time]
  _:
   Farm.act(s, cmd, arg)
   f.last = {"well": "集雨池已接好，下次季末生效。", "hens": "鸡群已经入栏。", "goats": "山羊已经入栏。", "feed": "四份饲料已经入库。", "brood": "幼畜开始哺育，已预留栏位。", "provision": "蛋奶折为口粮，已登记粮账。", "manure": "厩肥已施入农田。"} [cmd]
 if cmd in["survey", "ship"]:
  f.serial += 1
  f.missions.back().id = f.serial
 s.rev += 1
 return ""

static func tick(m):
 var s = m.s
 var f = s.frontier
 Crops.finish_trials(m)
 Farm.tick(m)
 for j in f.missions.duplicate():
  if s.time < j.due: continue
  if j.kind == "survey":
   E.open_district(s, j.to)
   if j.to not in f.survey: f.survey.append(j.to)
   exchange(m, 0, "people", 1)
   exchange(m, 0, "people", 1)
   var samples = 3 if "foreign_introduction" in s.tech else 2
   Crops.add_sample(f, j.crop, 0, samples)
   Crops.add_sample(f, j.crop, 1, samples)
   f.last = "%s勘探归来，带回%s丰穗、耐逆种源各 %d 份。" % [V.SECTORS[j.to], Crops.title(j.crop), samples]
  else:
   exchange(m, j.to, j.key, j.amount)
   f.last = "%s已接收 %d %s。" % [V.SECTORS[j.to], j.amount, LABEL[j.key]]
  m.note(f.last)
  f.missions.erase(j)
  s.rev += 1

static func season(m):
 var s = m.s
 var f = s.frontier
 for z in f.posts:
  var p = f.posts[z]
  var workers = int(p.people)
  var connected = s.cells[anchor(s, z)].connected
  var local_labor = workers if connected else 0
  if z == 1: p.food += local_labor
  if z == 3:
   var planted = mini(local_labor, p.seed)
   p.seed -= planted
   p.food += 2 * local_labor + 2 * planted
  var fed = mini(p.food, workers)
  p.food -= fed
  p.short = workers - fed
  if connected and z == 1: p.wood += mini(2 * fed, free_space(s, z, "wood"))
  if connected and z == 2: p.stone += mini(2 * fed, free_space(s, z, "stone"))
  p.spoil = maxi(0, p.food - Town.storage(s, z))
  p.food -= p.spoil
  if p.short > 0:
   m.note("%s缺 %d 份口粮，未领粮的居民本季停工。" % [V.SECTORS[z], p.short])
 Farm.settle(m)
