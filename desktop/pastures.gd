extends RefCounted

const V = preload("res://valley.gd")
const Town = preload("res://settlement.gd")
const E = preload("res://economy.gd")
const Roads = preload("res://streets.gd")

static func herd() -> Dictionary:
 return {"hens": 0, "goats": 0, "eggs": 0, "milk": 0, "manure": 0, "bedding": 0, "broods": {}, "extra": 0}

static func migrate(s: Dictionary):
 var f = s.frontier
 var old_pens = int(f.get("pens", 0))
 f.yards = {}
 if old_pens > 0:
  var site = int(f.home)
  var distance = INF
  for id in s.cells.size():
   var c = s.cells[id]
   if V.sector(id) != 0 or V.tier(id) < 0 or c.kind != "" or c.project != "": continue
   var step = V.distance(id, f.home)
   if step < distance: site = id; distance = step

  if site != f.home: s.cells[site].kind = "pasture"
  f.yards[site] = herd()
  for key in["hens", "goats", "eggs", "milk", "manure", "bedding", "broods"]:
   f.yards[site] [key] = f[key]
  f.yards[site].extra = old_pens - 1
  if Roads.root(s) >= 0: Roads.inherit_path(s, Roads.root(s), site)
 for key in["pens", "hens", "goats", "eggs", "milk", "manure", "bedding", "broods"]: f.erase(key)

static func capacity(s: Dictionary, id: int) -> int:
 return 3 * (s.cells[id].level + s.frontier.yards[id].extra)

static func feed_bin(s: Dictionary, zone: int) -> Dictionary:
 return s.frontier if zone == 0 else s.frontier.posts[zone]

static func feed_space(s: Dictionary, zone: int) -> int:
 var space = 8 if zone == 0 else 12
 for id in s.frontier.yards:
  if V.sector(id) == zone and s.cells[id].connected: space += 4 * (s.cells[id].level + s.frontier.yards[id].extra)
 return space

static func total(s: Dictionary, key: String) -> int:
 var result = 0
 for yard in s.frontier.yards.values(): result += yard[key]
 return result

static func status(s: Dictionary, id: int) -> String:
 var c = s.cells[id]
 if not c.connected: return "牧场与农专断路"
 if c.project != "" or c.flood or c.condition < Town.WORKING_CONDITION: return "施工、受淹或失修，牧场停工"
 for worker in s.workers:
  if worker.job == "t" + str(id) and worker.travel == 0: return ""
 return "需要一名到岗的牧工"

static func store_near(s: Dictionary, id: int) -> bool:
 for store in Town.facilities(s, "store"):
  if V.sector(store) == V.sector(id) and V.distance(store, id) <= 2: return true
 return false

static func manure_source(s: Dictionary, plot: int) -> int:
 if plot < 0 or plot >= s.cells.size() or s.cells[plot].kind != "farm" or not Town.working(s.cells[plot]): return -1
 for id in s.frontier.yards:
  if V.sector(id) == V.sector(plot) and V.distance(id, plot) <= 2 and s.frontier.yards[id].manure > 0 and status(s, id) == "": return id
 return -1

static func reason(s: Dictionary, cmd: String, arg) -> String:
 if cmd == "manure":
  if typeof(arg) != TYPE_INT or manure_source(s, arg) < 0: return "两格内需有通路、有人且存有厩肥的牧场"
  return "本田本季已施肥" if s.cells[arg].compost == s.turn else ""
 if not arg is Array or arg.is_empty() or not s.frontier.yards.has(arg[0]): return "请先在地图建成并选择牧场"
 var id = int(arg[0])
 var why = status(s, id)
 if why != "": return why
 var yard = s.frontier.yards[id]
 var zone = V.sector(id)
 var bin = E.warehouse(s, zone)
 var feed = feed_bin(s, zone)
 match cmd:
  "hens", "goats", "brood":
   if yard.hens + yard.goats + yard.broods.size() >= capacity(s, id): return "本场栏位已满，可扩建或另建牧场"
   if cmd == "brood":
    if arg.size() != 2 or arg[1] not in["hens", "goats"] or yard[arg[1]] < 2: return "本场需有两群同种成畜"
    if yard.broods.has(arg[1]): return "已有幼畜在养"
    if feed.feed < 3: return "本地需 3 份饲料"
   elif bin.food < 3 or bin.wood < 2: return "本地需 3 粮和 2 木"
  "feed":
   if feed.feed + E.inbound(s, zone, "feed") + 4 > feed_space(s, zone): return "当地饲料架不足四个空位"
   if bin.food < 2: return "当地需 2 粮"
  "provision":
   if yard.eggs + yard.milk == 0: return "本场暂无蛋奶"
   if bin.food + E.inbound(s, zone, "food") >= Town.storage(s, zone): return "当地粮仓已满"
  _: return "未知牧场事务"
 return ""

static func action(s: Dictionary, cmd: String, arg):
 if cmd == "manure":
  var source = manure_source(s, arg)
  s.frontier.yards[source].manure -= 1
  s.cells[arg].soil = mini(96, s.cells[arg].soil + 10)
  s.cells[arg].compost = s.turn
  return
 var id = int(arg[0])
 var zone = V.sector(id)
 var yard = s.frontier.yards[id]
 var feed = feed_bin(s, zone)
 match cmd:
  "hens", "goats":
   E.book_stock(s, zone, "wood", -2)
   E.book_stock(s, zone, "food", -3, "husbandry")
   yard[cmd] += 1
  "brood":
   feed.feed -= 3
   yard.broods[arg[1]] = s.time + 40
  "feed":
   E.book_stock(s, zone, "food", -2, "husbandry")
   feed.feed += 4
  "provision":
   var room = Town.storage(s, zone) - E.warehouse(s, zone).food - E.inbound(s, zone, "food")
   var milk = mini(yard.milk, room)
   var eggs = mini(yard.eggs, room - milk)
   yard.eggs -= eggs; yard.milk -= milk
   E.book_stock(s, zone, "food", eggs + milk, "livestock")

static func tick(m):
 for id in m.s.frontier.yards:
  var yard = m.s.frontier.yards[id]
  if yard.broods.is_empty(): continue
  var operating = status(m.s, id) == ""
  for species in yard.broods.keys():
   if not operating:
    yard.broods[species] += 1
   elif m.s.time >= yard.broods[species]:
    yard[species] += 1; yard.broods.erase(species)
    m.note(V.address(id) + "牧场幼畜长成。"); m.s.rev += 1

static func settle(m):
 var s = m.s
 for id in s.frontier.yards:
  var yard = s.frontier.yards[id]
  s.ledger.dairy_loss += yard.milk
  yard.milk = 0
  if status(s, id) != "": continue
  var feed = feed_bin(s, V.sector(id))
  var eggs = mini(feed.feed, yard.hens)
  feed.feed -= eggs
  var milk = 2 * mini(yard.goats, floori(feed.feed / 2.0))
  feed.feed -= milk
  var limit = 4 + capacity(s, id) + (4 if store_near(s, id) else 0)
  yard.eggs += mini(eggs, maxi(0, limit - yard.eggs))
  yard.milk = milk
  yard.manure = mini(2 * capacity(s, id) + 2, yard.manure + floori((eggs + milk + yard.bedding) / 2.0))
  yard.bedding = (eggs + milk + yard.bedding) % 2
  s.ledger.eggs += eggs; s.ledger.milk += milk
