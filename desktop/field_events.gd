extends RefCounted

const COPY = preload("res://content/field_events.json")
const V = preload("res://valley.gd")
const Town = preload("res://settlement.gd")
const E = preload("res://economy.gd")
const Crops = preload("res://crop_book.gd")
const Weather = preload("res://weather.gd")
const IDS = ["E01", "E02", "E03"]
# Stocks are charged in the same order used by the research desk.
const STOCKS = ["food", "seed", "wood", "stone"]
const NAMES = ["口粮", "种粮", "木", "石"]
const COSTS = {
 "E01": [[0,0,0,0], [3,0,2,0]], "E02": [[2,2,0,0], [0,0,2,0]], "E03": [[0,0,0,0], [3,0,0,2]]
}

static func setup(s: Dictionary):
 # Independent, saveable random stream, including on migration from a previous campaign.
 s.field_events = {"rng": 1 + posmod(int(s.frontier.rng) + 7919, 2147483646),
  "pending": "", "rolled": {}, "records": {}, "dry_turn": -1}

static func valid(record: Variant) -> bool:
 if not record is Dictionary or record.get("pending") not in ["","E01","E02","E03"]: return false
 if not record.get("rng") is int or not record.get("dry_turn") is int or not record.get("rolled") is Dictionary or not record.get("records") is Dictionary: return false
 for key in record.records:
  var entry = record.records[key]
  if key not in IDS or key == record.pending or not entry is Dictionary or entry.get("choice") not in [0,1] or not entry.get("turn") is int: return false
 return true

static func eligible(m, key: String) -> bool:
 var s = m.s
 if s.era != IDS.find(key) + 1: return false
 match key:
  "E01":
   if s.turn % 4 != 0 or "seed" not in s.tech: return false
   var low = 0
   for id in m.farms():
    if V.tier(id) == 0: low += 1
   return low >= 2
  "E02":
   var school = m.academy_id()
   if school < 0 or s.cells[school].kind != "academy" or not Town.working(s.cells[school]) or m.assigned("t" + str(school),true) == 0: return false
   var forecast = Weather.outlook(s).slice(0,2)
   return "暑热" in forecast or "旱灾" in forecast
  "E03":
   if "fertilizer" not in s.tech: return false
   var intensive = 0
   for id in m.farms():
    if s.cells[id].fertilized: intensive += 1
   return intensive >= 2
 return false

static func shortfall(s: Dictionary, key: String, index: int) -> String:
 var costs = COSTS[key][index]
 var missing = []
 for i in STOCKS.size():
  var deficit = int(costs[i]) - int(s[STOCKS[i]])
  if deficit > 0: missing.append("%d %s" % [deficit, NAMES[i]])
 return "" if missing.is_empty() else "尚缺 " + "、".join(missing)

static func consider(m):
 var s = m.s
 var rec = s.field_events
 if s.era < 1 or s.era > 3 or s.pending != "" or s.outcome != "" or rec.pending != "" or not s.incidents.is_empty(): return
 var key = IDS[s.era - 1]
 if rec.records.has(key) or rec.rolled.get(key,-1) == s.turn: return
 if not eligible(m,key) or (shortfall(s,key,0) != "" and shortfall(s,key,1) != ""): return
 var previously_missed = rec.rolled.has(key)
 rec.rolled[key] = s.turn
 rec.rng = (int(rec.rng) * 48271) % 2147483647
 if previously_missed or rec.rng % 100 < 60: offer(m,key)

static func offer(m, key: String) -> String:
 var s = m.s
 if key not in IDS or s.field_events.records.has(key): return "这件农事已结案"
 if s.field_events.pending != "" or s.pending != "" or not s.incidents.is_empty(): return "请先处理待议农情"
 if shortfall(s,key,0) != "" and shortfall(s,key,1) != "": return "当前物资无法支付任何方案"
 s.field_events.pending = key
 m.queue_incident(COPY.data[key].title,COPY.data[key].story,"field_event")
 s.rev += 1
 return ""

static func this_turn(s: Dictionary, key: String, pick: int) -> bool:
 var entry = s.field_events.records.get(key)
 return entry != null and entry.choice == pick and entry.turn == s.turn

static func note_room(m) -> int:
 var school = m.academy_id()
 if school < 0 or m.s.cells[school].kind != "academy": return 0
 var cell = m.s.cells[school]
 return maxi(0,m.Study.limit(m.s,cell.level) - cell.notes - m.s.science)

static func grant_notes(m, amount: int):
 var earned = mini(amount,note_room(m))
 if earned == 0: return
 var cell = m.s.cells[m.academy_id()]
 cell.notes += earned
 m.s.ledger.science += earned

static func mark_crop(s: Dictionary, id: int):
 var c = s.cells[id]
 if upland_weather(s,id) > 0: c.heat_relief = true
 for key in IDS:
  var pick = 1 if key == "E02" else 0
  if not this_turn(s,key,pick): continue
  if not c.has("dispatches"): c.dispatches = []
  if key in c.dispatches: continue
  c.dispatches.append(key)
  if key != "E01": continue
  c.weeds = 0
  for direction in 6:
   var other = V.nb(id,direction)
   if other >= 0 and s.cells[other].kind == "wood": s.cells[other].scorch_turn = s.turn

static func apply(m, key: String, pick: int) -> String:
 var s = m.s
 var rec = s.field_events
 if key not in IDS or pick not in [0,1] or rec.pending != key or rec.records.has(key): return "这件农事已经结案"
 var reason = shortfall(s,key,pick)
 if reason != "": return reason
 for i in STOCKS.size():
  var cost = int(COSTS[key][pick][i])
  if cost: E.book_stock(s,0,STOCKS[i],-cost,"field_cost")
 rec.records[key] = {"turn":s.turn,"choice":pick}
 rec.pending = ""
 for i in s.incidents.size():
  if s.incidents[i].kind == "field_event":
   s.incidents.remove_at(i)
   break
 var fields = m.farms()
 for id in fields:
  if s.cells[id].crop: mark_crop(s,id)
 match key:
  "E01":
   if pick == 1:
    for id in fields:
     if V.tier(id) == 0: s.cells[id].soil = mini(96,s.cells[id].soil + 5)
    grant_notes(m,1)
  "E02":
   if pick == 0:
    var trials = s.frontier.trials
    if trials.is_empty():
     Crops.add_sample(s.frontier,"稻",1,2)
    else:
     var crop = "稻"
     if not trials.has(crop):
      crop = trials.keys().front()
      for candidate in trials:
       if trials[candidate].due < trials[crop].due: crop = candidate
     trials[crop].due = maxi(s.time,trials[crop].due - 12)
     Crops.finish_trials(m)
    m.Guide.discover(s)
  "E03":
   if pick == 0:
    for id in fields:
     if not s.cells[id].fertilized: continue
     s.cells[id].pollution = mini(100,s.cells[id].pollution + 3)
     var reach = V.reach(id)
     s.water[reach] = mini(100,s.water[reach] + 3)
   else:
    for r in s.water.size(): s.water[r] = maxi(0,s.water[r] - 4)
    grant_notes(m,2)
    if s.study in ["precise","buffer_wetland"]:
     s.study_time = maxi(0,s.study_time - 15)
     m.complete_study()
 m.note("农事议决 · " + COPY.data[key].title + " · " + COPY.data[key].choices[pick].name)
 s.rev += 1
 return ""

static func crop_bonus(s: Dictionary, id: int) -> int:
 var flags = s.cells[id].get("dispatches",[])
 var amount = 2 * int("E01" in flags) + 5 * int("E03" in flags)
 if "E02" in flags and V.tier(id) == 0 and Town.covered(s,id,"canal"): amount += 3
 return amount

static func next_weather(s: Dictionary):
 var rec = s.field_events
 var entry = rec.records.get("E02")
 if entry == null or rec.dry_turn >= 0 or entry.turn >= s.turn: return
 if entry.choice == 1 and s.turn > entry.turn + 2: return
 if s.weather.now != "暑热" and s.weather.threat != "旱灾": return
 rec.dry_turn = s.turn
 if entry.choice == 0:
  for id in s.cells.size():
   if s.cells[id].kind == "farm" and s.cells[id].crop and upland_weather(s,id) > 0: s.cells[id].heat_relief = true

static func upland_weather(s: Dictionary, id: int) -> int:
 if s.field_events.dry_turn != s.turn or V.tier(id) < 1 or Town.covered(s,id,"canal"): return 0
 return 2 if s.field_events.records.E02.choice == 0 else -2

static func algae(s: Dictionary) -> bool:
 var entry = s.field_events.records.get("E03")
 return entry != null and entry.choice == 0 and s.turn > entry.turn and s.turn <= entry.turn + 2
