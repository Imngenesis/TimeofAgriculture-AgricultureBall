extends RefCounted

const V = preload("res://valley.gd")
const Town = preload("res://settlement.gd")
const DIFFICULTIES = [
 {"name": "丰年", "food": 42, "wood": 22, "stone": 12, "yield_pct": 115, "cost_pct": 75},
 {"name": "常年", "food": 30, "wood": 16, "stone": 9, "yield_pct": 100, "cost_pct": 100},
 {"name": "荒年", "food": 24, "wood": 12, "stone": 7, "yield_pct": 88, "cost_pct": 135}]
const BUDGETS = ["节用", "常规", "充足"]
const FUND_COST = [70, 100, 135]
const FUND_YIELD = [85, 100, 115]
const ERA_COST = [0, 2, 5, 8]
const ERA_YIELD = [0, 2, 5, 8]
const LAND_FEE = [0, 2, 1, 2]
const LAND_PRICE = [0, 8, 6, 10]
const LAND_FEATURE = ["", "竹木场每 7 人秒产 1 木。", "采石场每 9 人秒产 1 石。", "临河低田每块基础秋收加 5 份，夏汛时要留意来水口。"]
const HIRE_FOOD = 6
const HIRE_WOOD = 2
const MATERIALS = {"pasture": [3, 2], "agcollege": [8, 5], "engineering": [9, 6], "university": [20, 14], "academy": [3, 1], "house": [4, 0], "farm": [1, 0], "store": [3, 1], "levee": [2, 3],
 "canal": [1, 3], "terrace": [0, 2], "nursery": [3, 1], "station": [4, 3], "ditch": [0, 2], "upgrade": [3, 2], "repair": [1, 0]}
const DEPOTS = {"wood": "竹木场", "stone": "采石场"}
const DEPOSITS = {18: "wood", 35: "stone", 73: "wood", 99: "stone", 114: "wood", 125: "stone", 153: "stone", 177: "wood"}
const LOT = {"wood": 4, "stone": 3}

static func extraction_time(kind: String, id: int) -> int:
 if kind == "wood": return 7 if V.sector(id) == 1 else 10
 return 9 if V.sector(id) == 2 else 14

static func supply(s: Dictionary, kind: String, amount: int):
 s[kind] += amount
 s.ledger[kind + ("_in" if amount >= 0 else "_out")] += absi(amount)

static func warehouse(s: Dictionary, zone: int) -> Dictionary:
 return s if zone == 0 else s.frontier.posts[zone]

static func inbound(s: Dictionary, zone: int, key: String) -> int:
 var booked = 0
 for order in s.frontier.missions:
  if order.kind == "ship" and order.to == zone and order.key == key: booked += order.amount
 return booked

static func book_stock(s: Dictionary, zone: int, key: String, amount: int, column: String = ""):
 if zone == 0 and key in["wood", "stone"]:
  supply(s, key, amount)
  return
 var bin = warehouse(s, zone)
 bin[key] += amount
 if zone == 0 and column != "": s.ledger[column] += absi(amount)

static func open_district(s: Dictionary, zone: int):
 if not s.districts.has(zone): s.districts.append(zone)
 if not s.frontier.posts.has(zone):
  s.frontier.posts[zone] = {"people": 0, "food": 0, "seed": 0, "wood": 0, "stone": 0, "short": 0, "spoil": 0, "feed": 0}

static func inputs_reason(s: Dictionary, materials: Array) -> String:
 if s.wood < materials[0] or s.stone < materials[1]: return "工程需 %d 木、%d 石。可到料场派工或在收支面板换货" % materials
 return ""

static func input_text(kind: String) -> String:
 var pair = MATERIALS[kind]
 var costs = []
 if pair[0] > 0: costs.append("%d 木" % pair[0])
 if pair[1] > 0: costs.append("%d 石" % pair[1])
 return " · ".join(costs)

static func district_fee(s: Dictionary) -> int:
 var fee = 0
 for district in s.districts: fee += LAND_FEE[district]
 return fee

static func budget(s: Dictionary, era: int = -1, policy: int = -1) -> Dictionary:
 var infrastructure = 0
 for c in s.cells:
  if c.kind in["academy", "store", "canal", "nursery", "station", "pasture", "engineering"]: infrastructure += c.level
 for edge in s.edges.values():
  if edge.built: infrastructure += 1
 var services = ceili(infrastructure / 3.0)
 var administration = ERA_COST[s.era if era < 0 else era]
 var land = district_fee(s)
 var profile = DIFFICULTIES[s.difficulty]

 var funded = ceili((services + administration) * FUND_COST[s.budget if policy < 0 else policy] / 100.0)
 return {"era": administration, "services": services, "land": land, "total": ceili((funded + land) * profile.cost_pct / 100.0)}

static func settle(s: Dictionary):
 var due = budget(s).total
 var paid = mini(s.food, due)
 s.food -= paid
 s.ledger.operations = paid
 s.ledger.due = due
 var fraction = 1.0 if due == 0 else float(paid) / due
 s.efficiency = roundi(FUND_YIELD[s.budget] * lerpf(0.55, 1.0, fraction))
 if paid < due: s.organization = maxi(0, s.organization - 2)

static func flows(b: Dictionary) -> Array:
 return[b.gather + b.crop + b.refund + b.exports + b.get("freight_in", 0) + b.get("livestock", 0), b.get("freight_out", 0) + b.get("husbandry", 0) + b.get("explore", 0) + b.get("research", 0) + b.eat + b.build + b.maintenance + b.sow + b.advance + b.loss + b.spoil + b.operations + b.imports + b.recruit + b.land]

static func trade_reason(s: Dictionary, kind: String, buy: bool) -> String:
 if not LOT.has(kind): return "未知货物"
 var amount = LOT[kind]
 if buy:
  if s[kind] + amount + inbound(s, 0, kind) > Town.material_space(s, 0, kind): return "营地料仓放不下整批货物"
  if s.food < 5: return "换货需要 5 份口粮"
 elif s[kind] < amount: return "库存不足一批"
 return ""

static func trade(s: Dictionary, kind: String, buy: bool) -> String:
 var why = trade_reason(s, kind, buy)
 if why != "": return why
 var amount = LOT[kind]
 if buy:
  s.food -= 5
  s.ledger.imports += 5
  supply(s, kind, amount)
 else:
  supply(s, kind, - amount)
  s.food += 2
  s.ledger.exports += 2
 return ""

static func claim(s: Dictionary, sector: int) -> String:
 if sector < 1 or sector >= V.SECTORS.size() or s.districts.has(sector): return "此区域已开放"
 if s.food < LAND_PRICE[sector] or s.wood < 2: return "拓地需要 %d 粮、2 木" % LAND_PRICE[sector]
 s.food -= LAND_PRICE[sector]
 s.ledger.land += LAND_PRICE[sector]
 supply(s, "wood", -2)
 open_district(s, sector)
 s.rev += 1
 return ""
