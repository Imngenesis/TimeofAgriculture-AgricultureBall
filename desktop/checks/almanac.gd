extends SceneTree

const M = preload("res://simulation.gd")
const C = preload("res://crop_book.gd")
const R = preload("res://streets.gd")
const T = preload("res://settlement.gd")
const A = preload("res://agronomy.gd")
const F = preload("res://frontier.gd")
var errors = 0
func _initialize(): call_deferred("run")
func verify(ok: bool, what: String):
 if not ok: errors += 1; printerr("FAIL " + what)
func lab(region: int = 0):
 var m = M.new()
 m.reset(1, region)
 m.s.cells[38].kind = "academy"
 R.rebuild(m.s)
 return m

func research_economy():
 var roots = {}
 for biome in C.REGIONS.size():
  var m = lab(biome)
  var c = C.START[biome]
  roots[m.tech_name("seed")] = true
  verify(A.discovered(m.s, c) and m.techs.has(A.id(c, 2)), "initial crop branch exists")
  for other in C.NAMES:
   if other != c: verify(not A.discovered(m.s, other) and m.research_reason(A.id(other, 0)).contains("种源"), "unseen branches locked")
 verify(roots.size() == 5, "six biomes select five distinct starting crop curricula")
 var m = lab()
 var s = m.s
 m.assign("t38", 1); m.assign("t38", 1)
 for n in 320: m.work()
 verify(s.cells[38].notes == A.limit(s, 1) and s.science == 0, "archive stops at its physical cap before collection")
 m.collect(38)
 for n in 80: m.work()
 verify(s.cells[38].notes == 0, "moving notes into the player's bank does not reset the shared cap")
 var starting = s.science
 s.food = 0
 verify(m.research("seed") != "" and s.science == starting and s.study == "", "resource failure is atomic")
 s.food = 20
 var bill = A.bill(s, "seed", m.techs.seed)
 verify(m.research("seed") == "" and s.food == 20 - bill[0] and s.science == starting - 2 and s.ledger.research == bill[0], "research charges food and points together")
 verify(m.research("seed") != "" and s.food == 20 - bill[0], "double confirmation charges once")
 for n in 7: m.work()
 verify(s.study == "seed", "research consumes worker time")
 m.work()
 verify("seed" in s.tech, "paid trial completes with real work")
 C.add_sample(s.frontier, "麦", 0, 1)
 verify(A.discovered(s, "麦") and m.research_reason("wheat_1") == "", "finding first sample opens the field notebook")
 s.era = 2; s.tech.append("wheat_1")
 verify(m.research_reason("wheat_2").contains("驯化"), "the second crop technique needs a domesticated line")
 s.frontier.lines["麦"] = C.line(); C.profiles(s)
 verify(m.research_check("wheat_2")[0] == "待择径" and "drill" in A.Curriculum.parents("wheat_2",m.techs.wheat_2), "wheat and rice use different prerequisites")
 s.seed = T.seed_space(s, 0); s.food = 300
 verify(m.reserve(false) != "" and s.food == 300, "warehouses cannot turn excess food into unlimited banked seed")
 s.wood = T.material_space(s, 0, "wood")
 verify(m.E.trade(s, "wood", true) != "" and s.food == 300, "market obeys material capacity")

func roads_and_varieties():
 var m = lab(4)
 var s = m.s
 var f = s.frontier
 var tile = 39
 s.cells[tile].kind = "farm"
 s.seed = 7
 m.assign("t39", 1)
 for n in 25: m.work()
 verify(not s.cells[tile].crop and m.expected_yield(tile) == 0, "fully staffed but isolated field cannot sow")
 var quote = R.quote(s, 38, tile)
 var wood = s.wood; s.wood = 0
 verify(R.build(s, 38, tile) != "" and s.streets.is_empty(), "unfunded preview never places a partial street")
 s.wood = wood
 verify(R.build(s, 38, tile) == "" and s.wood == wood - quote.wood and s.cells[tile].connected, "player builds a charged physical street")
 var cost = s.wood
 verify(R.build(s, 38, tile) != "" and s.wood == cost, "land shared by roads is billed once")
 for n in 6: m.work()
 verify(s.cells[tile].crop and s.seed == 5, "network restores sowing")
 var saved = s.duplicate(true)
 verify(R.dismantle(s, 38, tile) == "" and not s.cells[tile].connected, "demolition updates operation immediately")
 m.restore(saved); s = m.s; f = s.frontier
 verify(s.cells[tile].connected, "loaded access is rebuilt from the actual street graph")
 var tuples = {}
 for crop in C.NAMES:
  f.lines[crop] = C.line(); C.profiles(s); f.plots[tile] = crop; f.cultivars[tile] = "原种"
  s.cells[tile].crop = false
  tuples[str([m.expected_yield(tile), C.seed_cost(s, crop, "原种"), C.fodder(s, crop), C.SOIL[crop]])] = true
 verify(tuples.size() == 6, "six distinct agronomic net-return profiles")
 var crop = "稻"; f.plots[tile] = crop
 f.varieties[crop] ["丰穗系"] = C.line(2, 0)
 f.varieties[crop] ["耐逆系"] = C.line(0, 2)
 f.cultivars[tile] = "丰穗系"; var flush = m.expected_yield(tile)
 f.cultivars[tile] = "耐逆系"; var moderate = m.expected_yield(tile)
 f.water_short = 3
 var resilient = m.expected_yield(tile)
 f.cultivars[tile] = "丰穗系"
 verify(flush > moderate and resilient > m.expected_yield(tile) and C.seed_cost(s, crop, "丰穗系") > C.seed_cost(s, crop, "耐逆系"), "variety choice reverses under stress and changes seeding cost")
 s.tech.append("drill")
 verify(C.seed_cost(s, "麦", "原种") == 1, "the historical seed drill saves real sowing stock")
 s.tech.append("maize_3"); s.tech.append("bean_3")
 verify(C.fodder(s, "玉米") == 6 and C.fodder(s, "豆") == 1, "crop specialization changes useful feed returns")
 print("HARVEST rice at site 39: abundant ", flush, ", resilient ", moderate, ", under water stress ", m.expected_yield(tile), " / ", resilient)

func run():
 research_economy()
 roads_and_varieties()
 if errors == 0: print("PASS formal crop curricula, heritage prerequisites, cost accounting, archive and inventory caps, physical roads and variety economics")
 quit(0 if errors == 0 else 1)
