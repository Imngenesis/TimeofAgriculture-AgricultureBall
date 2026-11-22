extends RefCounted

const V=preload("res://valley.gd")
const NAMES=["稻","粟","麦","薯","豆","玉米"]
const TITLES=["水稻","珍珠粟","小麦","马铃薯","菜豆","玉米"]
const DESCRIPTIONS=[
	"悬垂的稻穗成熟时转金黄。河岸低田便于引水，每块基础秋收增加 3 粮。",
	"穗形紧密的小粒谷物。在雨养草原或高地生长，每块基础秋收增加 4 粮。",
	"成熟麦穗长有细芒，谷粒便于储运。温带麦区或台地每块基础秋收增加 4 粮。",
	"地下块茎可食用、也可留作繁殖材料。高地或山地开局每块基础秋收增加 5 粮。",
	"豆荚包着可食用种子。每次收获恢复 5 点地力，可穿插在谷物茬口之间。",
	"籽粒整齐生在带苞叶的果穗上。旱季高原或台地每块基础秋收增加 4 粮。"]
const REGIONS=["长江湿地","萨赫勒雨养地","多瑙河麦区","安第斯高地","滨海河口","墨西哥高原"]
const START=["稻","粟","麦","薯","稻","玉米"]
const ECOLOGY=[
	"河网与浅湿地为稻作供水。低田增产，夏汛需要留心来水口。",
	"短雨季集中在夏天。春季野粮较少，粟适合在旱地留种。",
	"河阶平缓，麦田与林地相间。春季野粮充足，适合种麦、畜养。",
	"高差大，坡上冷凉。高地块茎增产，冬季可采野粮较少。",
	"下游通海，咸水无法饮用。十人携 22 份淡水登陆，集雨池能补充枯水季库存。",
	"季节性干湿交替。玉米适合台地，配合豆茬能给土地恢复地力。"]
const FORAGE=[[0,0,0,0],[-2,3,0,-1],[2,0,0,0],[0,1,1,-2],[1,1,-1,0],[0,2,0,-1]]
const MUTATION=[[22,5],[14,12],[7,22]]
const SOURCES=["丰穗系","耐逆系"]

static func title(crop: String) -> String:
	return TITLES[NAMES.find(crop)]

static func add_sample(f: Dictionary,crop: String,source: int,amount: int):
	if not f.samples.has(crop): f.samples[crop]=[0,0]
	f.samples[crop][source]+=amount

static func field_species(s: Dictionary,id: int) -> String:
	return s.frontier.plots.get(id,START[s.frontier.region])

static func line(yield_bonus: int=0,vigor: int=0) -> Dictionary:
	return {"yield_bonus":yield_bonus,"vigor":vigor}

static func roll(f: Dictionary) -> int:
	f.rng=(int(f.rng)*48271)%2147483647
	return f.rng%100

static func trial_reason(s: Dictionary,crop: String,source: int) -> String:
	var f=s.frontier
	if crop not in NAMES or source not in [0,1]: return "请选择一种作物与亲本"
	if f.trials.has(crop): return "该作物的试验田正在生长"
	if f.samples.get(crop,[0,0])[source]<2: return "要有两份同系的地方种源"
	if s.food<2: return "试验田需 2 份工粮"
	return ""

static func start_trial(s: Dictionary,crop: String,source: int):
	var f=s.frontier
	var cultivated=f.lines.has(crop)
	var parent=f.lines.get(crop,line())
	var offspring=parent.duplicate()
	if source==0: offspring.yield_bonus=mini(8,parent.yield_bonus+(2 if cultivated else 1))
	else: offspring.vigor=mini(4,parent.vigor+1)
	f.samples[crop][source]-=2
	s.food-=2
	s.ledger.husbandry+=2
	f.trials[crop]={"due":s.time+40,"line":offspring,"cross":cultivated,"source":source}
	f.last="%s%s开始，用%s%s。40 秒后可验收。" % [title(crop),"杂交" if cultivated else "驯化",SOURCES[source],"与栽培品系配组" if cultivated else "建立试验田"]

static func finish_trials(m):
	var f=m.s.frontier
	for crop in f.trials.keys():
		var trial=f.trials[crop]
		if m.s.time<trial.due: continue
		f.lines[crop]=trial.line
		f.trials.erase(crop)
		f.last="%s%s完成，丰产 %+d，耐逆 %d。可在农田安排下茬。" % [title(crop),"杂交" if trial.cross else "驯化",trial.line.yield_bonus,trial.line.vigor]
		m.note(f.last)
		m.s.rev+=1

static func field_bonus(s: Dictionary,id: int) -> int:
	var f=s.frontier
	var crop=field_species(s,id)
	var cell=s.cells[id]
	var variety=cell.get("sown_line",{}) if cell.crop else {}
	if variety.is_empty(): variety=f.lines.get(crop,line())
	var tier=V.tier(id)
	var bonus=int(variety.yield_bonus)
	match crop:
		"稻": bonus+=3 if tier==0 else 0
		"粟": bonus+=4 if tier==2 or f.region==1 else 0
		"麦": bonus+=4 if tier==1 or f.region==2 else 0
		"薯": bonus+=5 if tier==2 or f.region==3 else 0
		"玉米": bonus+=4 if tier==1 or f.region==5 else 0
	var dry=f.region==4 and f.water_short>0
	if cell.soil<58 or cell.disease>0 or dry:
		bonus+=2*int(variety.vigor)
	if dry: bonus-=4
	return bonus

static func harvested(m,id: int):
	var f=m.s.frontier
	var crop=field_species(m.s,id)
	if crop=="豆": m.s.cells[id].soil=mini(96,m.s.cells[id].soil+5)
	add_sample(f,crop,0,1)
	if f.mutation_turn.get(crop,-1)==m.s.turn: return
	f.mutation_turn[crop]=m.s.turn
	var odds=MUTATION[m.s.difficulty]
	var dice=roll(f)
	var delta=1 if dice<odds[0] else (-1 if dice<odds[0]+odds[1] else 0)
	if delta!=0:
		var current=f.lines[crop]
		current.yield_bonus=clampi(current.yield_bonus+delta,-4,8)
		f.last="%s留种出现%s变异。下茬丰产修正 %+d。" % [title(crop),"有利" if delta>0 else "不利",current.yield_bonus]
		m.note(f.last)
