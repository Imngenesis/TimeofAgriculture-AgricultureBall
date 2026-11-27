extends RefCounted

const V = preload("res://valley.gd")
const OPERATORS = ["canal", "nursery", "station", "pasture", "engineering"]
const WORKING_CONDITION = 50
const CAMP_BEDS = 10
const HOUSE_BEDS = 4
const CAMP_STORAGE = 48
const STORE_STORAGE = 36
const LESSON = 18
const C = preload("res://crop_book.gd")
const ERA_FOOD = [12, 20, 32, 0]
const Curriculum = preload("res://curriculum.gd")

static func working(c: Dictionary) -> bool:
 return c.kind != "" and c.project == "" and not c.flood and c.condition >= WORKING_CONDITION and(c.kind not in["farm", "house", "store", "canal", "nursery", "station", "wood", "stone", "pasture", "engineering"] or c.get("connected", false))

static func facilities(s: Dictionary, kind: String, active: bool = true) -> Array:
 var found = []
 for id in s.cells.size():
  var c = s.cells[id]
  if c.kind != kind: continue
  if active and not working(c): continue
  if active and kind in OPERATORS:
   var staffed = false
   for worker in s.workers:
    if worker.job == "t" + str(id) and worker.travel == 0: staffed = true; break
   if not staffed: continue
  found.append(id)
 return found

static func total_level(s: Dictionary, kind: String) -> int:
 var levels = 0
 for c in s.cells:
  if c.kind == kind and working(c): levels += c.level
 return levels

static func lesson_time(s: Dictionary) -> int:
 return 15 if "field_trials" in s.tech else LESSON

static func beds(s: Dictionary) -> int:
 return CAMP_BEDS + HOUSE_BEDS * total_level(s, "house")

static func store_levels(s: Dictionary, zone: int) -> int:
 var levels = 0
 for id in facilities(s, "store"):
  if V.sector(id) == zone: levels += s.cells[id].level
 return levels

static func storage(s: Dictionary, zone: int = 0) -> int:
 var baseline = CAMP_STORAGE if zone == 0 else 24
 return baseline + (STORE_STORAGE + (8 if "seed_vault" in s.tech else 0)) * store_levels(s, zone)

static func seed_space(s: Dictionary, zone: int) -> int:
 var plots = 0
 for id in facilities(s, "farm"):
  if V.sector(id) == zone: plots += 1
 var stores = store_levels(s, zone)
 return 8 + 3 * plots + 6 * stores + (6 if stores > 0 and "seed_vault" in s.tech else 0)

static func material_space(s: Dictionary, zone: int, key: String) -> int:
 var bonus = STORE_STORAGE * store_levels(s, zone)
 return(40 if key == "wood" else 30) + floori(bonus / 2.0)

static func seed_ready(game) -> bool:
 var need = {}
 for id in game.farms():
  var zone = V.sector(id)
  var next = C.for_sowing(game.s, id)
  need[zone] = need.get(zone, 0) + C.seed_cost(game.s, next[0], next[1])
 for zone in need:
  var bin = game.s if zone == 0 else game.s.frontier.posts[zone]
  if bin.seed < need[zone]: return false
 return not need.is_empty()

static func covered(s: Dictionary, id: int, kind: String) -> bool:
 for other in facilities(s, kind):
  var extended = (kind == "canal" and "pump" in s.tech) or (kind == "station" and "tractor" in s.tech)
  if V.distance(id, other) <= s.cells[other].level + int(extended): return true
 return false

static func demographics(s: Dictionary, served: int) -> int:
 var need = s.pop
 var shortage = need - served
 s.last_need = need
 s.last_served = served
 s.happiness = clampi(s.happiness + (2 if shortage == 0 else - ceili(12.0 * shortage / maxi(need, 1))), 0, 100)
 var maintained = true
 for c in s.cells:
  if c.kind != "" and c.condition < WORKING_CONDITION: maintained = false; break
 var morale = 1 if shortage == 0 and maintained else(-1 if shortage == 0 else -3)
 s.organization = clampi(s.organization + morale, 0, 100)
 s.shortage = s.shortage + 1 if shortage > 0 else 0
 if s.shortage >= 2:
  s.shortage = 0
  return -1
 return 0

static func requirements(game) -> Dictionary:
 var s = game.s
 var structures = []
 var survival = []
 var farms = facilities(s, "farm")
 var safe_store = false
 var expanded_store = false
 for id in facilities(s, "store"):
  if V.tier(id) > 0 or not game.flood_map().has(id): safe_store = true
  if s.cells[id].level >= 2: expanded_store = true
 match s.era:
  0:
   structures = [[not facilities(s, "academy").is_empty(), "1 所农专"], [not farms.is_empty(), "1 块投产农田"], [not facilities(s, "store").is_empty(), "1 座备荒粮仓"]]
   survival = [[s.first_crop and s.winter, "完成首收并越冬"], [s.seed >= 2, "至少保留 2 份种粮"]]
  1:
   var wall = false
   for e in s.edges.values():
    if e.built and e.condition >= WORKING_CONDITION: wall = true; break
   structures = [[farms.size() >= 2, "2 块投产农田"], [not facilities(s, "house").is_empty(), "1 栋农舍"], [wall or safe_store, "有效田堤或安全粮仓"]]
   survival = [[s.flood_at >= 0 and s.flood_time == 0 and s.resown, "度过洪峰并完成复播"], [s.full >= 1, "最近一季足额供粮"]]
  2:
   structures = [[game.tagged("terrace") or game.tagged("rotation"), "1 块梯田或轮作田"], [not facilities(s, "canal").is_empty() or expanded_store, "有效灌渠或二级粮仓"]]
   survival = [[s.rain and game.mean_soil() >= 54, "经历梅雨且平均地力 ≥ 54"], [s.full >= 2, "连续两季足额供粮"]]
  3:
   structures = [[farms.size() >= 2, "2 块投产农田"], [not facilities(s, "station").is_empty() or game.tagged("ditch"), "有效农机站或田间净水沟"]]
   survival = [[s.modern_harvest, "使用农机、配肥或净水沟完成一次秋收"], [not s.sick and(s.blight_at < 0 or s.after_blight), "出现病情时，受影响农田恢复收获"], [s.water[2] <= 23, "下游污染 ≤ 23（当前 %d）" % s.water[2]], [s.full >= 2 and seed_ready(game), "连续两季供足口粮，留足下次播种所需"]]
 if s.era == 3:
  var ac = game.academy_id()
  structures.append([ac >= 0 and s.cells[ac].get("campus", "") == "agronomy", "由农专升建农学院"])
  structures.append([not facilities(s, "engineering").is_empty(), "1 所已通路、有教师到岗的农机学院"])
  structures.append([farms.size() >= 3 and not facilities(s, "store").is_empty(), "3 块投产农田和 1 座通路粮仓"])
  survival.append([s.pop >= 12, "营地至少 12 名居民"])
 var techs = []
 var paths = Curriculum.ROUTES.data.eras[s.era]
 if paths.size() == 1:
  for key in paths[0].tech: techs.append([key in s.tech, game.tech_name(key)])
 else:
  var names = []
  for path in paths: names.append(path.name)
  techs.append([Curriculum.any_met(game, paths), "达成一条农学路线（" + " / ".join(names) + "）"])
 return {"建设": structures, "科技": techs, "生存": survival}
