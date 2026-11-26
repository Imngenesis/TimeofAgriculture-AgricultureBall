extends RefCounted

const Crops = preload("res://crop_book.gd")
const COPY = preload("res://content/field_guide.json")
const RESEARCH = {
 "dry": "谷物晾晒", "dike": "早期水利", "scout": "田间巡查", "terrace": "等高筑田",
 "nursery": "育秧移栽", "machine": "机械稻作", "precise": "测土配肥", "fertilizer": "工业合成氨",
 "rice_2": "育秧移栽", "pump": "提水器械", "plough": "曲辕犁",
 "stone_tools": "早期农具", "slash_burn": "火耕水耨", "phenology": "物候与历法",
 "weather_station": "物候与历法", "water_management": "早期水利", "canal_gates": "提水器械",
 "deep_plowing": "曲辕犁", "foreign_introduction": "引进占城稻",
 "tractor": "机械稻作", "combine": "机械稻作", "variable_rate": "测土配肥",
 "pedigree": "杂交水稻", "regional_trials": "杂交水稻", "pest_control": "绿色防控与生物农药"
}

static func enqueue(s: Dictionary, key: String):
 if key not in s.guide.read and key not in s.guide.queue:
  s.guide.queue.append(key)

static func discover(s: Dictionary):
 var f = s.frontier
 enqueue(s, "env/" + Crops.REGIONS[f.region])
 enqueue(s, "era/" + str(s.era))
 for crop in Crops.NAMES:
  if not f.samples.has(crop) and not f.lines.has(crop): continue
  enqueue(s, "crop/" + crop)
  for line in f.varieties.get(crop, {}):
   if line in Crops.SOURCES: enqueue(s, "var/" + crop + "/" + line)

static func setup(s: Dictionary, historical: bool = false):
 s.guide = {"read": [], "queue": []}
 if historical:
  for era in s.era: s.guide.read.append("era/" + str(era))
 discover(s)
 if historical:
  s.guide.read.append_array(s.guide.queue)
  s.guide.queue.clear()

static func acknowledge(s: Dictionary):
 if s.guide.queue.is_empty(): return
 s.guide.read.append(s.guide.queue.pop_front())
 s.rev += 1

static func authored(group: String, name: String, section: String) -> String:
 var body: String = COPY.data[group].get(name, "")
 if body.begins_with("@"): return COPY.data.technologies[body.substr(1)].body
 if body == "": return "【待补文案 · " + name + " · " + section + "】"
 return body

static func entry(key: String) -> Dictionary:
 var part = key.split("/")
 var name = part[1]
 match part[0]:
  "env":
   return {"category": "开局环境", "name": name, "body": authored("environments", name, "环境介绍"), "plate": "habitat", "index": Crops.REGIONS.find(name)}
  "era":
   var era = COPY.data.eras[int(name)]
   return {"category": "时代 · 农业文化", "name": era.title, "body": era.body, "plate": "era", "index": int(name)}
  "tech":
   var tech = COPY.data.technologies[name]
   return {"category": "农技文献", "name": name, "body": tech.body, "plate": "era", "index": int(tech.era)}
  "var":
   var cultivar = Crops.cultivar_title(name, part[2])
   return {"category": "首次获得品种", "name": cultivar, "body": authored("varieties", cultivar, "品种介绍"), "plate": "crop", "index": Crops.NAMES.find(name)}
 var title = Crops.title(name)
 return {"category": "首次发现作物", "name": title, "body": authored("crops", title, "作物介绍"), "plate": "crop", "index": Crops.NAMES.find(name)}

static func research_source(s: Dictionary, key: String) -> String:
 if key == "seed" and Crops.START[s.frontier.region] == "稻": return "驯化水稻"
 return RESEARCH.get(key, "")
