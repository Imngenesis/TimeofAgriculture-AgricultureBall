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

static func new_record() -> Dictionary:
	return {"focus": "", "terms": 0, "observations": 0, "hazards": []}

static func choose(s: Dictionary, track: String) -> String:
	if s.era < 1: return "进入早期农耕时代后可确立专精"
	if track not in TRACKS: return "请选择一个农业方向"
	if s.research_record.focus != "": return "本次发展已经确立专精"
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
