extends SceneTree

const Model = preload("res://simulation.gd")
const D = preload("res://field_events.gd")
const V = preload("res://valley.gd")
const Saves = preload("res://saves.gd")
var errors = 0
var checks = 0

func expect(ok: bool, message: String):
 checks += 1
 if not ok: errors += 1; printerr("FAIL " + message)

func campus(age: int, region: int = 0):
 var m = Model.new()
 m.reset(0,region)
 var s = m.s
 s.era = age; s.turn = 4; s.food = 40; s.seed = 8; s.wood = 20; s.stone = 10
 s.ledger = m.book(s.food+s.seed,s.wood,s.stone)
 s.cells[38].kind = "academy"
 s.field_events.rng = 2
 m.Roads.rebuild(s)
 m.assign("t38",1)
 for worker in s.workers: worker.travel = 0
 return m

func field(m, tier: int, near: int = -1) -> int:
 for id in V.CORE_CELLS:
  if V.tier(id) != tier or m.s.cells[id].kind != "": continue
  if near >= 0 and V.distance(id,near) != 1: continue
  var c = m.s.cells[id]
  c.kind = "farm"; c.crop = true; c.soil = 60
  m.Roads.inherit_path(m.s,38,id); m.Roads.rebuild(m.s)
  return id
 return -1

func forester(m, plot: int) -> int:
 for d in 6:
  var id = V.nb(plot,d)
  if id >= 0 and V.tier(id) >= 0 and m.s.cells[id].kind in ["","wood"]:
   var c = m.s.cells[id]
   c.kind = "wood"; m.Roads.inherit_path(m.s,38,id); m.Roads.rebuild(m.s)
   m.assign("t"+str(id),1)
   for worker in m.s.workers: worker.travel = 0
   return id
 return -1

func clone(m):
 var other = Model.new()
 other.restore(m.s.duplicate(true))
 return other

func require_offer(m, key: String):
 D.consider(m); expect(m.s.field_events.pending == key,"eligible offer " + key)

func riverbanks():
 var m = campus(1); var s = m.s
 var a = field(m,0); var b = field(m,0)
 var wood = forester(m,a)
 expect(a >= 0 and b >= 0 and wood >= 0,"riverbank fixture")
 expect(not D.eligible(m,"E01"),"seed knowledge required")
 s.tech = ["seed"]; s.turn = 5
 expect(not D.eligible(m,"E01"),"spring only")
 s.turn = 4; s.cells[b].kind = ""
 expect(not D.eligible(m,"E01"),"two separate low fields")
 s.cells[b].kind = "farm"; s.field_events.rng = 1
 var weather_rng = s.weather.rng
 D.consider(m); var cursor = s.field_events.rng
 expect(s.field_events.pending == "" and s.weather.rng == weather_rng,"miss uses a separate RNG")
 var restored = clone(m)
 D.consider(restored)
 expect(restored.s.field_events.rng == cursor and restored.s.field_events.pending == "","an eligible miss survives a reload")
 s.turn += 4; require_offer(m,"E01")
 var p = clone(m); var ps = p.s
 ps.cells[a].weeds = 34; ps.cells[wood].wildwork = m.E.extraction_time("wood",wood) - 1
 var t = ps.time; p.tick(); expect(ps.time == t,"time waits for a decision")
 expect(D.apply(p,"E01",0) == "" and ps.cells[a].weeds == 0,"fire clears weeds immediately")
 var stock = ps.wood; p.work()
 expect(ps.wood == stock and ps.cells[wood].get("wood_withheld",-1) == ps.turn,"one wood withheld at the adjacent working forest")
 ps.cells[wood].wildwork = m.E.extraction_time("wood",wood)-1; p.work()
 expect(ps.wood == stock + 1,"wood loss happens once per forest")
 p.seasonal_pressure(); expect(ps.cells[a].weeds == 0,"no spring weed rebound")
 var later = clone(p); later.s.cells[a].erase("dispatches"); later.s.cells[b].erase("dispatches")
 ps.turn += 2; later.s.turn = ps.turn
 var gross = p.expected_yield(a); expect(gross == later.expected_yield(a)+2,"fire crop bonus survives to autumn")
 p.harvest(); later.harvest()
 expect(ps.food == later.s.food + 4 and ps.seed == later.s.seed,"bonus is food for both fields")
 expect(ps.cells[a].soil == later.s.cells[a].soil - 4 and not ps.cells[a].has("dispatches"),"harvest spends fertility and clears one crop's reward")
 expect(D.apply(p,"E01",1) != "","a resolved choice cannot be applied twice")
 s.wood = 1
 expect(D.apply(m,"E01",1) != "" and s.field_events.pending == "E01" and s.food == 40,"insufficient resources preserve the decision")
 s.wood = 20; expect(D.apply(m,"E01",1) == "","alternative dike choice")
 expect([s.food,s.wood,s.ledger.field_cost,s.cells[a].soil,s.cells[38].notes] == [37,18,3,65,1],"dike costs, soil and unclaimed note")
 var care = s.cells[a].care; m.work(); expect(s.cells[a].care == care + 1,"bonus care reaches growing crops")
 s.turn += 1; care = s.cells[a].care; m.work(); expect(s.cells[a].care == care,"care expires")

func set_dry_outlook(m, dry: bool):
 for cursor in range(1,100):
  m.s.weather.rng = cursor
  if ("暑热" in m.Weather.outlook(m.s)) == dry: return
 expect(false,"find a forecast of the required type")

func rice_ship():
 var m = campus(2); var s = m.s; var a = field(m,0); var high = field(m,2)
 set_dry_outlook(m,false); expect(not D.eligible(m,"E02"),"visible dry forecast required")
 set_dry_outlook(m,true)
 for w in s.workers:
  if w.job == "t38": w.travel = 5
 expect(not D.eligible(m,"E02"),"school must be staffed and running")
 for w in s.workers: w.travel = 0
 s.food = 0; s.wood = 1; D.consider(m)
 expect(s.field_events.pending == "" and s.field_events.rolled.is_empty(),"an unaffordable pair cannot trap the player or spend a roll")
 s.food = 40; s.wood = 20; require_offer(m,"E02")
 var backup = clone(m); var canal = clone(m)
 D.apply(m,"E02",0)
 expect(s.frontier.samples["稻"] == [0,2] and [s.food,s.seed,s.ledger.field_cost] == [38,6,4],"two drought-line rice samples are charged once")
 s.turn += 1; s.weather.now = "暑热"; D.next_weather(s)
 expect(s.field_events.dry_turn == s.turn and s.cells[high].get("heat_relief",false) and not s.cells[a].get("heat_relief",false),"next hot spell protects exposed uplands")
 s.turn += 1; s.weather.now = "阴"
 var baseline = clone(m); baseline.s.cells[high].erase("heat_relief")
 expect(m.expected_yield(high) == baseline.expected_yield(high)+2,"hot-season relief survives to the actual harvest")
 m.harvest(); expect(not s.cells[high].has("heat_relief"),"protection is limited to this crop")
 s.turn += 1; s.weather.now = "暑热"; D.next_weather(s)
 expect(s.field_events.dry_turn < s.turn,"a second heat wave cannot consume protection again")
 var f = backup.s.frontier
 backup.F.Crops.add_sample(f,"稻",1,2); backup.F.Crops.start_trial(backup.s,"稻",1)
 var due = f.trials["稻"].due
 D.apply(backup,"E02",0)
 expect(f.trials["稻"].due == due-12 and f.samples["稻"][1] == 0,"ongoing trial shortens instead of adding samples")
 var cs = canal.s
 var channel = forester(canal,a); cs.cells[channel].kind = "canal"
 expect(canal.Town.covered(cs,a,"canal"),"staffed canal reaches the low field")
 cs.cells[channel].level = 1; D.apply(canal,"E02",1)
 expect(cs.wood == 18 and D.crop_bonus(cs,a) == 3 and D.crop_bonus(cs,high) == 0,"dredging rewards irrigated low fields")
 cs.turn += 1; cs.weather.now = "暑热"; cs.weather.threat = "旱灾"; D.next_weather(cs)
 var comparison = clone(canal); comparison.s.field_events.dry_turn = -1
 canal.Weather.settle(canal); comparison.Weather.settle(comparison)
 expect(cs.cells[high].soil == comparison.s.cells[high].soil-2 and cs.cells[a].soil == comparison.s.cells[a].soil,"exposed uplands take two more drought pressure")

func river_algae():
 var m = campus(3,4); var s = m.s
 var a = field(m,0); var b = field(m,0)
 s.tech = ["fertilizer"]; s.cells[a].fertilized = true
 expect(not D.eligible(m,"E03"),"one high-input farm is insufficient")
 s.cells[b].fertilized = true; s.water = [7,9,12]
 require_offer(m,"E03"); var green = clone(m)
 var standard = m.expected_yield(a); var river = s.water.duplicate()
 D.apply(m,"E03",0)
 for id in [a,b]: river[V.reach(id)] += 3
 expect(s.cells[a].pollution == 3 and s.water == river and m.expected_yield(a) == standard+5,"fertilizer boosts the current crop and pollutes its river reach")
 var wet = forester(m,a); s.cells[wet].kind = "canal"; s.tech.append("rice_3")
 for offset in 4:
  s.turn = 4 + offset
  var reference = clone(m); reference.s.field_events.records.erase("E03")
  var expected = 2 if offset in [1,2] else 0
  expect(reference.F.Farm.spring_water(reference.s).rain - m.F.Farm.spring_water(s).rain == expected,"estuary fresh-water window " + str(offset))
  expect(reference.expected_yield(a) - m.expected_yield(a) == expected,"rice-fish window " + str(offset))
 var gs = green.s
 gs.study = "precise"; gs.study_time = 24
 D.apply(green,"E03",1)
 expect([gs.food,gs.stone,gs.ledger.field_cost,gs.cells[38].notes,gs.study_time] == [37,8,3,2,9],"filtration costs, unclaimed notes and 15 person-seconds")
 expect(gs.water == [3,5,8],"all river reaches clean immediately")
 var extra = field(green,1)
 var before_water = gs.water.duplicate()
 expect(green.field_action(extra,"fertilized") == "" and gs.water == before_water,"new fertilizer applications respect this season of filtration")
 var comparison = clone(green)
 for id in [a,b,extra]: comparison.s.cells[id].fertilized = false
 green.water_step(); comparison.water_step()
 expect(gs.water == comparison.s.water and gs.cells[a].pollution == 0,"zero new discharges during filtration")
 gs.turn += 1; green.water_step()
 expect(gs.cells[a].pollution > 0,"suppression expires next season")

func forecast_sequence():
 for region in 6:
  var m = campus(2,region)
  for season in 8:
   var s = m.s
   var rng_before = s.weather.rng
   var preview = m.Weather.outlook(s)
   expect(preview == m.Weather.outlook(s) and s.weather.rng == rng_before,"reading the forecast cannot reroll weather")
   var compare = clone(m)
   for i in 2:
    compare.Weather.settle(compare); compare.s.turn += 1; compare.Weather.next_season(compare)
    expect(compare.s.weather.now == preview[i],"two-season forecast matches normal draws")
   m.Weather.settle(m); s.turn += 1; m.Weather.next_season(m)

func _initialize():
 riverbanks(); rice_ship(); river_algae(); forecast_sequence()
 if errors == 0: print("PASS ",checks," event checks, prerequisites, all six choices, stocks, harvest, weather, RNG and persistence")
 quit(1 if errors else 0)
