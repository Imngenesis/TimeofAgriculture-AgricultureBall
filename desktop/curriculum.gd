extends RefCounted

const TOPICS = preload("res://content/research_curriculum.json")
const TRACKS = ["育种", "耕作", "防灾", "经济"]
const PERKS = {
	"育种": "每块田秋收时再收集一份本作物的丰穗种源。",
	"耕作": "有人照料的在田作物每秒额外获得 1 点照料。",
	"防灾": "提前部署防护后，天灾损害强度再降低 2 点。",
	"经济": "码头每卖出整批木料或石料，额外收回 1 份口粮。"
}
const OBSERVATIONS = 8
const ROUTES = preload("res://content/research_routes.json")
const MERGED = {
	"large_field_management": "deep_plowing", "cash_crops": "market_trade",
	"long_distance_trade": "trade_routes", "granary_vent": "seed_vault",
	"manure_cycle": "straw_return", "apprentice": "field_trials"
}
# A field condition is checked when opening the project. Progress already paid for is retained.
const FIELDWORK = {
	"farms": ["相邻且有种植记录的通路田", 2], "store": ["有效粮仓", 1], "crops": ["已驯化作物", 2],
	"post": ["路网接通的外圩", 1], "pasture": ["有牧工与牲畜的牧场", 1],
	"canal": ["有人值守的灌渠", 1], "shelter": ["洪水威胁外的粮仓", 1],
	"expanded_store": ["有效二级粮仓", 1]
}

static func paths(key: String) -> Array:
	return ROUTES.data.topics.get(key, [])

static func parents(key: String, spec: Array) -> Array:
	var result = spec[3].duplicate()
	for path in paths(key):
		for id in path.tech:
			if id not in result: result.append(id)
	return result

static func field_count(m, field: String) -> int:
	var s = m.s
	match field:
		"farms":
			var planted = []
			for id in m.Town.facilities(s, "farm"):
				var cell = s.cells[id]
				if not cell.crop and cell.harvests == 0: continue
				for other in planted:
					if m.V.sector(other) == m.V.sector(id) and m.V.distance(other,id) == 1: return 2
				planted.append(id)
			return mini(1,planted.size())
		"store": return m.Town.facilities(s, "store").size()
		"crops": return s.frontier.lines.size()
		"canal": return m.Town.facilities(s, "canal").size()
		"post":
			var count = 0
			for zone in s.frontier.posts:
				var anchor = m.F.anchor(s, zone)
				if s.cells[s.frontier.home].connected and s.cells[anchor].connected: count += 1
			return count
		"pasture":
			var count = 0
			for id in m.Town.facilities(s, "pasture"):
				var herd = s.frontier.yards.get(id, {})
				if herd.get("hens", 0) + herd.get("goats", 0) > 0: count += 1
			return count
		"shelter", "expanded_store":
			var count = 0
			var low = m.flood_map() if field == "shelter" else []
			for id in m.Town.facilities(s, "store"):
				if field == "expanded_store" and s.cells[id].level >= 2: count += 1
				elif field == "shelter" and (m.V.tier(id) > 0 or id not in low): count += 1
			return count
	return 0

static func field_label(m, field: String) -> String:
	var rule = FIELDWORK[field]
	return "%s %d/%d" % [rule[0], mini(field_count(m, field), rule[1]), rule[1]]

static func path_met(m, path: Dictionary) -> bool:
	for id in path.tech:
		if id not in m.s.tech: return false
	return not path.has("field") or field_count(m, path.field) >= FIELDWORK[path.field][1]

static func any_met(m, choices: Array) -> bool:
	for path in choices:
		if path_met(m, path): return true
	return choices.is_empty()

static func requirements_text(m, path: Dictionary) -> String:
	var details = []
	for id in path.tech:
		details.append(("✓ " if id in m.s.tech else "◇ ") + m.tech_name(id))
	if path.has("field"): details.append(field_label(m, path.field))
	return "、".join(details)

static func integrate_save(s: Dictionary):
	var known = []
	for old in s.tech:
		var current = MERGED.get(old, old)
		if current not in known: known.append(current)
	s.tech = known
	s.study = MERGED.get(s.study, s.study)
	if s.study != "" and s.study in known:
		s.study = ""
		s.study_time = 0
		s.research_record.terms = 0
		s.research_record.observations = 0

static func new_record() -> Dictionary:
	return {"focus":"", "terms":0, "observations":0, "hazards":[]}

static func choose(s: Dictionary, track: String) -> String:
	if s.era < 1: return "进入早期农耕时代后可确立专精"
	if track not in TRACKS: return "请选择一个农业方向"
	if s.research_record.focus != "": return "这场战役已经确立专精"
	s.research_record.focus = track
	s.rev += 1
	return ""

static func focused(s: Dictionary, track: String) -> bool:
	return s.research_record.focus == track

static func terms(key: String) -> int:
	return int(TOPICS.data.get(key, {}).get("terms", 0))

static func eligible_region(s: Dictionary, key: String) -> bool:
	return int(TOPICS.data.get(key, {}).get("region", s.frontier.region)) == s.frontier.region

static func migrate(s: Dictionary):
	s.research_record = new_record()
	for entry in s.weather.history:
		var fields = String(entry).split(" · ")
		if fields.size() >= 3:
			var hazard = fields[fields.size() - 2]
			if hazard not in s.research_record.hazards: s.research_record.hazards.append(hazard)
