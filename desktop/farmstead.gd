extends RefCounted

const E = preload("res://economy.gd")
const RAIN = [7, 13, 6, 4]
const Yards = preload("res://pastures.gd")
const Weather = preload("res://weather.gd")

static func spring_water(s: Dictionary) -> Dictionary:
 var f = s.frontier
 var intake = RAIN[s.turn % 4] + (9 if "coastal_cistern" in s.tech else 6) * f.wells + Weather.water_delta(s)
 if f.region == 4 and preload("res://field_events.gd").algae(s): intake = maxi(0,intake - 2)
 var need = ceili(s.pop * 0.75)
 var plots = 0
 for c in s.cells:
  if c.kind == "farm": plots += 1
 need += ceili(plots / 2.0) if "precision_irrigation" in s.tech else plots
 var capacity = 40 + 8 * f.wells
 var available = mini(capacity, f.fresh + intake)
 return {"rain": intake, "need": need, "capacity": capacity, "balance": maxi(0, available - need), "short": maxi(0, need - available)}

static func reason(s: Dictionary, cmd: String, arg) -> String:
 if cmd != "well": return Yards.reason(s, cmd, arg)
 if s.frontier.region != 4: return "集雨池适用于滨海河口"
 return E.inputs_reason(s, [3, 2])

static func act(s: Dictionary, cmd: String, arg):
 if cmd == "well":
  E.supply(s, "wood", -3); E.supply(s, "stone", -2)
  s.frontier.wells += 1
 else: Yards.action(s, cmd, arg)

static func tick(m):
 Yards.tick(m)

static func settle(m):
 Yards.settle(m)
 var s = m.s
 var f = s.frontier
 if f.region == 4:
  var water = spring_water(s)
  f.fresh = water.balance
  f.water_short = water.short
  if water.short > 0:
   s.organization = maxi(0, s.organization - 3)
   m.note("本季淡水短缺 %d 份，组织度降低 3。可搭集雨池补水。" % water.short)
