extends RefCounted

const Town = preload("res://settlement.gd")
const V = preload("res://valley.gd")
const E = preload("res://economy.gd")

const POOLS = [
 [["晴", "小雨", "阴"], ["小雨", "暴雨", "暑热"], ["晴", "晴", "小雨"], ["阴", "晴", "冷霜"]],
 [["晴", "暑热", "风"], ["小雨", "暑热", "小雨"], ["晴", "暑热", "风"], ["晴", "风", "阴"]],
 [["小雨", "晴", "阴"], ["晴", "小雨", "风"], ["晴", "阴", "风"], ["冷霜", "冷霜", "阴"]],
 [["冷霜", "晴", "小雨"], ["晴", "小雨", "风"], ["晴", "风", "冷霜"], ["冷霜", "冷霜", "阴"]],
 [["小雨", "阴", "风"], ["暴雨", "风", "暑热"], ["小雨", "风", "晴"], ["晴", "阴", "风"]],
 [["晴", "暑热", "风"], ["小雨", "暴雨", "暑热"], ["晴", "小雨", "风"], ["晴", "冷霜", "风"]]]
const THREATS = {"暑热": "旱灾", "暴雨": "暴雨冲刷", "风": "风灾", "冷霜": "霜冻"}
const DEFENSE = {"旱灾": "分水抗旱", "暴雨冲刷": "清沟护土", "风灾": "加固屋顶", "霜冻": "铺草护苗"}
const FORECAST = {
 "晴": "秋收估产每田加 1 粮。",
 "阴": "田间收成按常规结算。",
 "小雨": "田块季末恢复 1 地力，河口集雨增加 2 水。",
 "暴雨": "河口多收 4 水，裸露坡地需防表土流失。",
 "暑热": "未受灌渠覆盖的田块估产减少 2 粮，河口少收 3 水。",
 "风": "野粮采集上限减少 1，留意建筑的完好度。",
 "冷霜": "麦与薯以外的在田作物估产减少 2 粮。"}
const IMPACT = {"旱灾": "未通灌渠的农田损失地力，河口还会损失淡水。",
 "暴雨冲刷": "坡地流失表土，梯田、轮作能护住地力。",
 "风灾": "牧场、粮仓和农舍损失完好度。",
 "霜冻": "在田作物损失照料，秧圃覆盖的田块受保护。"}

static func draw(s: Dictionary, turn: int) -> String:
 var w = s.weather
 w.rng = (int(w.rng) * 48271) % 2147483647
 var choices = POOLS[s.frontier.region] [turn % 4]
 return choices[w.rng % choices.size()]

static func setup(s: Dictionary):
 s.weather = {"rng": maxi(1, int(s.frontier.rng) % 2147483647), "now": "晴", "next": "", "threat": "", "prepared": false, "last_hit": -4, "history": []}
 if s.turn > 0: s.weather.now = draw(s, s.turn)
 s.weather.next = draw(s, s.turn + 1)

static func next_season(s: Dictionary):
 var w = s.weather
 var previous = w.now
 w.now = w.next
 w.next = draw(s, s.turn + 1)
 w.threat = ""
 w.prepared = false
 if s.turn < 4 or s.turn - w.last_hit < [6, 4, 3] [s.difficulty]: return
 if THREATS.has(w.now) and(w.now == previous or s.turn - w.last_hit >= 7 or s.difficulty == 2):
  w.threat = THREATS[w.now]

static func water_delta(s: Dictionary) -> int:
 return {"小雨": 2, "暴雨": 4, "暑热": -3}.get(s.weather.now, 0)

static func yield_delta(s: Dictionary, id: int, crop: String) -> int:
 match s.weather.now:
  "晴": return 1
  "暑热": return 0 if Town.covered(s, id, "canal") else -2
  "冷霜": return 0 if crop in["麦", "薯"] else -2
 return 0

static func prepare_reason(s: Dictionary) -> String:
 if s.weather.threat == "": return "本季无需动员"
 if s.weather.prepared: return "本季已经部署"
 if s.food < 2 or s.wood < 1: return "需要 2 口粮、1 木料"
 return ""

static func prepare(m) -> String:
 var s = m.s
 var why = prepare_reason(s)
 if why != "": return why
 E.book_stock(s, 0, "food", -2, "maintenance")
 E.supply(s, "wood", -1)
 s.weather.prepared = true
 s.rev += 1
 m.note(DEFENSE[s.weather.threat] + "已部署。")
 return ""

static func settle(m):
 var s = m.s
 var w = s.weather
 if w.now == "小雨":
  for plot in m.farms(): s.cells[plot].soil = mini(96, s.cells[plot].soil + 1)
 if w.threat == "": return
 var strength = (2 + s.difficulty) if w.prepared else(6 + 2 * s.difficulty)
 var affected = 0
 for id in s.cells.size():
  var c = s.cells[id]
  match w.threat:
   "旱灾":
    if c.kind != "farm" or Town.covered(s, id, "canal"): continue
    c.soil = maxi(10, c.soil - strength)
   "暴雨冲刷":
    if c.kind != "farm" or V.tier(id) < 1 or c.terrace or c.rotation: continue
    c.soil = maxi(10, c.soil - strength)
   "风灾":
    if c.kind not in["pasture", "store", "house"]: continue
    c.condition = maxi(0, c.condition - strength)
   "霜冻":
    if not c.crop or Town.covered(s, id, "nursery"): continue
    c.care = maxi(0, c.care - strength * 2)
  affected += 1
 if w.threat == "旱灾" and s.frontier.region == 4: s.frontier.fresh = maxi(0, s.frontier.fresh - strength)
 var message = "%s · %s · %d 处受影响%s" % [m.date(), w.threat, affected, "，防护已生效" if w.prepared else ""]
 w.history.push_front(message)
 if w.history.size() > 8: w.history.pop_back()
 w.last_hit = s.turn
 m.note(message)
