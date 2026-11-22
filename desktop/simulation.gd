extends RefCounted

const V = preload("res://valley.gd")
const F=preload("res://frontier.gd")
const Town = preload("res://settlement.gd")
const E = preload("res://economy.gd")
const SEASONS = ["春","夏","秋","冬"]
const ERAS = ["原始采集","早期农耕","传统农耕","工业与现代农业"]
const CHAPTERS = ["在江边扎根","与洪水争田","留住坡上的土","让河水重归清澈"]
const ROMAN = ["Ⅰ","Ⅱ","Ⅲ","Ⅳ"]
const SEASON_TIME = 40
const TECH = {
	"seed": ["留种试种",0,2,[],"解锁农田。春夏从种仓播种，秋季收粮。"],
	"dry": ["谷物晾晒",0,2,[],"解锁粮仓。建仓后的第一个收获季会引来谷鸟。"],
	"dike": ["圩堤排水",1,3,["seed"],"解锁田堤与灌渠。新渠第一次灌到在田作物时会出现草害。"],
	"scout": ["田间巡查",1,2,["seed"],"解锁巡田。提前护住下一次可能染病的作物。"],
	"terrace": ["等高筑田",2,4,["dike"],"解锁梯田。阶坎减缓冲刷，完工时补充地力。"],
	"rotate": ["谷豆轮作",2,4,["seed"],"解锁轮作。每季恢复地力，梅雨时保护表土。"],
	"nursery": ["集中育秧",2,3,["seed"],"选修。公共秧圃覆盖田增产 4 份，首次在田使用会出现作物病情预警。"],
	"machine": ["机械耕作",3,5,["seed"],"解锁农机站。服务范围内的农田增产 5 份。"],
	"precise": ["测土配肥",3,5,["terrace","rotate"],"解锁精准配肥与净水沟，控制尾水排放。"],
	"fertilizer": ["化肥增产",3,3,["rotate","terrace"],"选修。田块首次启用高投入施肥会触发尾水预警，每茬增产 6 份，也会积累污染。"]
}
# 名称、所需科技、口粮成本、完工所需人秒
const BUILD = {
	"academy":["农专","",3,8], "house":["农舍","",4,10],
	"farm":["试验农田","seed",2,9], "store":["备荒粮仓","dry",4,14],
	"levee":["田堤","dike",4,16], "canal":["共用灌渠","dike",5,13], "terrace":["等高梯田","terrace",4,14],
	"nursery":["公共秧圃","nursery",5,14], "station":["农机服务站","machine",6,18], "ditch":["农田净水沟","precise",3,12],
	"upgrade":["扩建二级","",6,16], "repair":["修复设施","",2,8]
}
const FACILITIES=["academy","house","farm","store","canal","nursery","station"]
const SERVICE={"academy":"到岗人员每合计 12 人秒编成 1 点，点农专领取。","house":"每级提供 4 个安居名额。","farm":"春夏使用 2 份种粮播种，秋收后留种。二级田增产 4 份。","store":"每级增加 36 份口粮仓容，高处可避洪。","levee":"封住进水边，保护连通低地。","canal":"建在河岸低地。范围内农田增产 3 份，扩建后覆盖两格。","terrace":"改良已开垦农田，减轻冲刷。","nursery":"范围内农田增产 4 份，同时引入病情风险。","station":"范围内农田增产 5 份，扩建后覆盖两格。","ditch":"改良已开垦农田，拦截本河段尾水。"}
const LAND = ["河岸低地","台地","高地"]
const HOME = 28
const WILD = [19,42,60]
const CRISIS = {
	"flood":["洪峰将至","上游水尺一夜涨了三格。下个季末，河水将从未封住的进水口漫上低田。",
		"抢修田堤","本季堤坝施工速度翻倍。选一块低田，沿来水方向落堤。",
		"转移粮种","调最多两人往高处转运。营地可护 6 份，有安全粮仓可护 14 份。"],
	"rain":["坡地告急","梅雨正在逼近。裸露的田面会流失表土，地力低的田块下一次秋收将减产。",
		"先稳坡脚","本季筑梯田速度翻倍，完工的阶坎挡住冲刷。",
		"保住表土","把秸秆覆盖田面，本次每块田额外减少 6 点地力损失。"],
	"runoff":["下游水色变了","农田尾水正在汇入河道。化肥带来的产量会反映在秋收，排放则逐季流向下游。",
		"留出缓冲带","划出岸边草带，每季截留下游 4 点污染，保留常规产量。",
		"集中保产","使用化肥的田块额外增产 4 份，每季多排放 3 点，净水沟可截流。"],
	"blight":["田间出现病斑","植物病害图鉴 · 叶穗斑病。受影响的作物出现斑点、结实减少。地图标出首发田块，本季可安排巡田并单独保留健康种粮。",
		"分田巡护","本次疫病减轻，已巡查的田保住大部分收成。",
		"保护种仓","优先保留良种，立刻封存最多 4 份口粮做种，田间承受较重损失。"],
	"birds":["晒场里的谷鸟","晾晒和集中储藏吸引了谷鸟，成熟田开始受食害。",
		"拨粮护田","耗 2 份口粮，组织持续守望，降低食害压力。","先顾口粮","保留现粮，成熟田承担较多食害。"],
	"weeds":["引水田里的杂草","共用灌渠开始给农田供水，田边出现争水的杂草。",
		"拨粮除草","耗 2 份口粮组织清理，受灌田的草害增长减缓。","维持供水","保留口粮与灌渠产出，轮作可以缓解草害。"]
}
const RESPONSES={"flood":["dike","move"],"rain":["slope","mulch"],"runoff":["buffer","intensive"],"blight":["inspect","seed"],"birds":["watch","keep"],"weeds":["clear","keep"]}

var s: Dictionary
var events: Array = []

func _init():
	reset()

func new_cell(id: int) -> Dictionary:
	var kind="wild" if WILD.has(id) else E.DEPOSITS.get(id,"")
	return {"kind":kind,"project":"","done":0,"soil":65+(id*7)%12,
		"crop":false,"care":0,"last":0,"harvests":0,"terrace":false,"rotation":false,
		"precise":false,"ditch":false,"patrol":-1,"compost":-1,"wildwork":0,"picked":0,"flood":false}

func reset(difficulty: int=1, region: int=0):
	region=randi_range(0,F.REGIONS.size()-1) if difficulty==2 else clampi(region,0,F.REGIONS.size()-1)
	V.biome=region
	var camp=F.HOMES.pick_random() if difficulty==2 else F.LOCAL_HOME[region]
	var profile=E.DIFFICULTIES[difficulty]
	var cells = []
	for id in V.COLS*V.ROWS:
		cells.append(new_cell(id))
	cells[camp].kind="camp"
	s = {"version":4,"turn":0,"clock":0,"time":0,"era":0,"age":0,"food":profile.food,"seed":0,
		"difficulty":difficulty,"wood":profile.wood,"stone":profile.stone,"budget":1,"efficiency":100,"districts":[0],"history":[],
		"pop":10,"science":0,"tech":[],"study":"","study_time":0,"cells":cells,"edges":{},
		"workers":[],"water":[0,0,0],"full":0,"empty":0,"pending":"","policy":{},
		"flood_at":-1,"flood_time":0,"flood_cells":[],"evacuated":0,"rescued":0,"lost":0,
		"winter":false,"first_crop":false,"resown":false,"rain":false,"after_blight":false,
		"blight_at":-1,"sick":false,"outcome":"","log":[],"last_report":"","rev":0,
		"ledger":book(profile.food,profile.wood,profile.stone),"last_ledger":{}}
	F.setup(s,region,camp)
	_extend_state()
	for i in 10:
		add_worker()
	events.clear()
	note("十人在%s扎营，带来了 %d 份口粮。" % [F.REGIONS[region],profile.food])

func book(opening: int,wood: int=0,stone: int=0) -> Dictionary:
	return {"opening":opening,"gather":0,"crop":0,"refund":0,"build":0,"maintenance":0,"advance":0,"eat":0,"loss":0,"sow":0,"spoil":0,"science":0,"ending":opening,
		"recruit":0,"hires":0,"operations":0,"due":0,"imports":0,"exports":0,"land":0,"husbandry":0,"livestock":0,"explore":0,"freight_in":0,"freight_out":0,"eggs":0,"milk":0,"dairy_loss":0,"wood_open":wood,"stone_open":stone,"wood_in":0,"stone_in":0,"wood_out":0,"stone_out":0}

func _extend_state():
	s.merge({"happiness":62,"organization":65,"shortage":0,"last_need":0,"last_served":0,"pop_change":0,
		"modern_harvest":false,"cause":{},"warnings":[],"end_reason":""})
	for c in s.cells:
		c.merge({"level":1,"condition":100,"notes":0,"lesson":0,"fertilized":false,"pollution":0,"sown_pollution":0,"birds":0,"weeds":0,"disease":0})
	for e in s.edges.values(): e.merge({"condition":100,"repairing":false})

func restore(state: Dictionary):
	s=state
	if s.version==1:
		_extend_state()
		var old=s.ledger
		var opening=s.food+s.seed-old.gather-old.crop+old.build+old.sow+old.loss+old.eat
		old.merge(book(opening))
		if not s.last_ledger.is_empty(): s.last_ledger.merge({"maintenance":0,"advance":0,"spoil":0,"science":0,"refund":0})
		s.modern_harvest=s.era==3 and s.after_blight
		if s.outcome=="lost": s.end_reason="连续两季完全断粮。"
		s.version=2
	if s.version==2:
		var profile=E.DIFFICULTIES[1]
		s.merge({"difficulty":1,"wood":profile.wood,"stone":profile.stone,"budget":1,"efficiency":100,"districts":[0],"history":[]})
		for id in range(s.cells.size(),V.COLS*V.ROWS): s.cells.append(new_cell(id))
		for id in E.DEPOSITS:
			if s.cells[id].kind=="" and s.cells[id].project=="": s.cells[id].kind=E.DEPOSITS[id]
		_extend_state()
		s.ledger.merge(book(s.food+s.seed,s.wood,s.stone))
		# Version-one migration may already have supplied these fields via book().
		s.ledger.wood_open=s.wood
		s.ledger.stone_open=s.stone
		if not s.last_ledger.is_empty():
			for key in ["recruit","hires","operations","due","imports","exports","land","wood_in","wood_out","stone_in","stone_out"]:
				if not s.last_ledger.has(key): s.last_ledger[key]=0
			s.history.append([s.turn-1]+E.flows(s.last_ledger))
		s.erase("growth")
		s.version=3
	if s.version==3:
		F.setup(s)
		for ledger in [s.ledger,s.last_ledger]:
			if ledger.is_empty(): continue
			for column in F.BOOK: ledger[column]=0
		if s.cause.has("blight"): record_disease(s.cause.blight.tile)
		s.version=4
	V.biome=s.frontier.region
	events.clear()

func add_worker():
	var base=rest_position(s.workers.size())
	s.workers.append({"job":"","from":base,"to":base,"path":[base,base],"length":0.0,"travel":0,"duration":1})

func recruit_reason() -> String:
	if s.pop+F.incoming(s)>=Town.beds(s): return "床位已满，先建设或扩建农舍"
	if s.food<E.HIRE_FOOD or s.wood<E.HIRE_WOOD: return "招募需要 %d 口粮、%d 木料" % [E.HIRE_FOOD,E.HIRE_WOOD]
	return ""

func recruit() -> String:
	var why=recruit_reason()
	if why!="": return why
	s.food-=E.HIRE_FOOD
	E.supply(s,"wood",-E.HIRE_WOOD)
	s.ledger.recruit+=E.HIRE_FOOD
	s.ledger.hires+=1
	add_worker()
	s.pop=s.workers.size()
	note("新招募的居民已到营地，可立即派工。")
	return ""

func rest_position(i: int) -> Vector2:
	var a = i*2.4
	return V.center(s.frontier.home) + Vector2(cos(a),sin(a))*(0.55+0.12*(i%3))

func note(message: String):
	s.log.push_front("%s　%s" % [date(),message])
	if s.log.size()>30: s.log.pop_back()
	events.append(message)

func date() -> String:
	return "第%d年 · %s" % [floori(float(s.turn)/4)+1,SEASONS[int(s.turn)%4]]

func farms() -> Array:
	var ids = []
	for i in s.cells.size():
		if s.cells[i].kind=="farm": ids.append(i)
	return ids

func mean_soil() -> int:
	var ids=farms()
	if ids.is_empty(): return 0
	var total=0
	for i in ids: total+=s.cells[i].soil
	return roundi(float(total)/ids.size())

func tagged(kind: String) -> bool:
	for i in farms():
		if Town.working(s.cells[i]) and s.cells[i][kind]: return true
	return false

func academy_id() -> int:
	for i in s.cells.size():
		if s.cells[i].kind=="academy" or s.cells[i].project=="academy": return i
	return -1

func collect(id: int) -> String:
	if id<0 or id>=s.cells.size() or s.cells[id].kind!="academy": return "请前往已建成的农专"
	var c=s.cells[id]
	if c.flood: return "等到退水后再来领点"
	if c.notes<=0: return "尚无可领取的科技点，先派人到岗研习"
	var amount=c.notes
	s.science+=amount
	c.notes=0
	note("在农专领取 %d 点科技。" % amount)
	return ""

func location_name(id: int) -> String:
	var c=s.cells[id]
	if V.tier(id)<0: return ["上游河道","中游河道","下游河道"][V.reach(id)]
	if c.project in ["upgrade","repair"]: return BUILD[c.kind][0]+" · "+BUILD[c.project][0]
	if c.project!="": return BUILD[c.project][0]+"工地"
	match c.kind:
		"camp": return "河谷营地"
		"wild": return "野粮采集地"
		"farm":
			var crop=F.Crops.title(F.Crops.field_species(s,id))
			return crop+("梯田" if c.terrace else ("轮作田" if c.rotation else "田"))
	if BUILD.has(c.kind): return BUILD[c.kind][0]
	if E.DEPOTS.has(c.kind): return E.DEPOTS[c.kind]
	return LAND[V.tier(id)]

func research_reason(id: String) -> String:
	if not TECH.has(id): return "未知农学"
	var t=TECH[id]
	if s.tech.has(id): return "已掌握"
	if s.study!="": return "正在研习"+TECH[s.study][0]
	if s.era<t[1]: return "在"+ERAS[t[1]]+"开放"
	var missing=[]
	for pre in t[3]:
		if not s.tech.has(pre): missing.append(TECH[pre][0])
	if not missing.is_empty(): return "先掌握"+"、".join(missing)
	if s.science<t[2]: return "科技点不足，请派人去农专并领取"
	if Town.facilities(s,"academy").is_empty(): return "需有一所正常运作的农专"
	return ""

func research(id: String) -> String:
	var why=research_reason(id)
	if why!="": return why
	s.science-=TECH[id][2]
	s.study=id
	s.study_time=8
	note("开始研习"+TECH[id][0]+"。")
	return ""

func reserve(release: bool=false,zone: int=0) -> String:
	var bin=E.warehouse(s,zone)
	if release:
		if bin.seed<=0: return "本地种仓已空"
		var n=mini(2,bin.seed)
		bin.seed-=n
		bin.food+=n
	else:
		if bin.food<2: return "当地需有两份口粮"
		bin.food-=2
		bin.seed+=2
	return ""

func edge_for(id: int,d: int) -> String:
	if id<0: return ""
	var b=V.nb(id,d)
	return V.edge_key(id,b) if b>=0 else ""

func flood_map(extra: String="") -> Array:
	var wet=[]
	for i in s.cells.size():
		if V.tier(i)<0: wet.append(i)
	for pass_id in 6:
		var count=wet.size()
		for i in s.cells.size():
			if V.tier(i)!=0 or wet.has(i): continue
			var d=V.intake(i)
			var inlet=V.nb(i,d)
			if not wet.has(inlet): continue
			var key=V.edge_key(i,inlet)
			if key==extra or (s.edges.has(key) and s.edges[key].built and s.edges[key].condition>=Town.WORKING_CONDITION): continue
			wet.append(i)
		if wet.size()==count: break
	var fields=[]
	for i in wet:
		if V.tier(i)==0: fields.append(i)
	return fields

func protected_by(id: int,d: int) -> Array:
	var after=flood_map(edge_for(id,d))
	var saved=[]
	for i in flood_map():
		if not after.has(i): saved.append(i)
	return saved

func build_reason(kind: String,id: int,d: int=0) -> String:
	if not BUILD.has(kind) or id<0 or id>=s.cells.size(): return "请选择地图内地块"
	var def=BUILD[kind]
	if not s.districts.has(V.sector(id)): return "请先在地块面板开通此区域"
	if def[1]!="" and not s.tech.has(def[1]): return "先研习「"+TECH[def[1]][0]+"」"
	if V.tier(id)<0: return "河道内不能施工"
	var c=s.cells[id]
	if c.flood: return "待洪水退去再施工"
	if kind=="levee":
		var k=edge_for(id,d)
		if k=="": return "超出河谷边界"
		if s.edges.has(k): return "这段堤岸已占用"
		if V.tier(id)!=0 or protected_by(id,d).is_empty(): return "这里不是来水口，请选临河低地"
	elif kind in ["upgrade","repair"]:
		if not c.kind in FACILITIES or c.project!="": return "请选择已完工且空闲的设施"
		if kind=="repair" and c.condition>=100: return "设施完好"
		if kind=="upgrade" and c.level>=2: return "已扩至二级"
		if kind=="upgrade" and c.condition<Town.WORKING_CONDITION: return "请先检修设施"
	elif kind in ["terrace","ditch"]:
		if c.kind!="farm": return "请选择一块已开垦的农田"
		if c[kind]: return "这块田已有"+def[0]
		if c.project!="": return "田上已有工程"
	elif c.kind!="" or c.project!="": return "这块地已占用"
	if kind=="academy" and academy_id()>=0: return "河谷已有农专，可前往派工或扩建"
	if kind=="canal" and V.tier(id)!=0: return "渠首须设在临河低地"
	var zone=V.sector(id)
	var bin=E.warehouse(s,zone)
	if bin.food<def[2]: return "%s本地口粮不足，需 %d 份" % [V.SECTORS[zone],def[2]]
	return E.inputs_reason(bin,E.MATERIALS[kind])

func construct(kind: String,id: int,d: int=0) -> String:
	var why=build_reason(kind,id,d)
	if why!="": return why
	var zone=V.sector(id)
	var inputs=E.MATERIALS[kind]
	E.book_stock(s,zone,"food",-BUILD[kind][2],"maintenance" if kind=="repair" else "build")
	E.book_stock(s,zone,"wood",-inputs[0])
	E.book_stock(s,zone,"stone",-inputs[1])
	var job="t"+str(id)
	if kind=="levee":
		var key=edge_for(id,d)
		s.edges[key]={"a":id,"dir":d,"built":false,"done":0,"condition":100,"repairing":false,"inputs":inputs,"payer":zone}
		job="e"+key
	else:
		s.cells[id].project=kind
		s.cells[id].inputs=inputs
		s.cells[id].payer=zone
		s.cells[id].done=0
	if free_workers()>0 and assigned(job)==0: assign(job,1)
	s.rev+=1
	note(V.address(id)+"动工修建"+BUILD[kind][0]+"。")
	return ""

func repair_edge(key: String) -> String:
	if not s.edges.has(key): return "找不到田堤"
	var e=s.edges[key]
	if not e.built or e.repairing or e.condition>=100: return "此段田堤暂时无需检修"
	var zone=V.sector(e.a)
	var bin=E.warehouse(s,zone)
	if bin.food<BUILD.repair[2]: return "当地检修需要两份口粮"
	var inputs=E.MATERIALS.repair
	var why=E.inputs_reason(bin,inputs)
	if why!="": return why
	E.book_stock(s,zone,"food",-BUILD.repair[2],"maintenance")
	E.book_stock(s,zone,"wood",-inputs[0])
	e.inputs=inputs
	e.payer=zone
	e.done=0
	e.repairing=true
	if free_workers()>0: assign("e"+key,1)
	s.rev+=1
	return ""

func project_refund(kind: String,completed: int) -> int:
	var spec=BUILD[kind]
	return floori(float(spec[2])*maxi(0,spec[3]-completed)/spec[3])

func cancel_project(job: String) -> String:
	var refund=0
	var zone=0
	var inputs=[]
	var remaining=0.0
	if job.begins_with("e"):
		var key=job.substr(1)
		if not s.edges.has(key): return "工地已结束"
		var e=s.edges[key]
		if e.built and not e.repairing: return "田堤已经合拢"
		refund=project_refund("repair" if e.repairing else "levee",e.done)
		remaining=1.0-float(e.done)/BUILD["repair" if e.repairing else "levee"][3]
		inputs=e.get("inputs",[])
		zone=e.get("payer",0)
		e.erase("payer")
		e.erase("inputs")
		release_job(job)
		if e.repairing: e.repairing=false;e.done=BUILD.levee[3]
		else: s.edges.erase(key)
	elif job.begins_with("t") and job.substr(1).is_valid_int():
		var id=int(job.substr(1))
		if id<0 or id>=s.cells.size(): return "找不到工地"
		var c=s.cells[id]
		if c.project=="": return "工地已结束"
		refund=project_refund(c.project,c.done)
		remaining=1.0-float(c.done)/BUILD[c.project][3]
		inputs=c.get("inputs",[])
		zone=c.get("payer",0)
		c.erase("payer")
		c.erase("inputs")
		c.project=""
		c.done=0
		while assigned(job)>capacity(job): assign(job,-1)
	else: return "找不到工地"
	E.book_stock(s,zone,"food",refund,"refund")
	if inputs.size()==2:
		E.book_stock(s,zone,"wood",floori(inputs[0]*remaining))
		E.book_stock(s,zone,"stone",floori(inputs[1]*remaining))
	s.rev+=1
	note("撤回工程，未用工粮 %d 份归仓。" % refund)
	return ""

func job_label(job: String) -> String:
	if job.begins_with("e"): return "田堤工地"
	if job.begins_with("t"): return location_name(int(job.substr(1)))
	return "待命"

func assigned(job: String,arrived: bool=false) -> int:
	var n=0
	for w in s.workers:
		if w.job==job and (not arrived or w.travel<=0): n+=1
	return n

func free_workers() -> int:
	return assigned("")

func capacity(job: String) -> int:
	if job.begins_with("e"):
		var k=job.substr(1)
		return 4 if s.edges.has(k) and (not s.edges[k].built or s.edges[k].repairing) else 0
	if not job.begins_with("t"): return 0
	var id=int(job.substr(1))
	if id<0 or id>=s.cells.size(): return 0
	var c=s.cells[id]
	if not s.districts.has(V.sector(id)) or c.flood: return 0
	if c.project!="" or c.kind in ["wild","farm"]: return 4
	if E.DEPOTS.has(c.kind): return 3
	if c.kind in Town.OPERATORS: return 1
	if c.kind=="academy": return 2 if c.level==1 else 4
	if id==s.frontier.home and s.policy.get("flood","")=="move" and s.flood_at<0: return 2
	return 0

func job_point(job: String,i: int) -> Vector2:
	if job=="": return rest_position(i)
	var offset=Vector2(cos(i*2.4),sin(i*2.4))*0.43
	if job.begins_with("e"):
		var e=s.edges[job.substr(1)]
		return (V.corner(e.a,e.dir)+V.corner(e.a,e.dir+1))*0.5+offset*0.5
	return V.center(int(job.substr(1)))+offset

func worker_point(i: int,alpha: float=0.0) -> Vector2:
	var w=s.workers[i]
	var ratio=clampf(1.0-(float(w.travel)-alpha)/float(w.duration),0.0,1.0)
	var left=ratio*w.length
	for j in w.path.size()-1:
		var a: Vector2=w.path[j]
		var b: Vector2=w.path[j+1]
		var segment=a.distance_to(b)
		if segment>0.0001 and left<segment: return a.lerp(b,left/segment)
		left-=segment
	return w.to

func dispatch(i: int,job: String):
	var w=s.workers[i]
	var origin=worker_point(i)
	w.job=job
	w.from=origin
	w.to=job_point(job,i)
	w.path=V.crossing(origin,w.to)
	w.length=0.0
	for j in w.path.size()-1: w.length+=w.path[j].distance_to(w.path[j+1])
	w.duration=maxi(1,ceili(w.length/1.8))
	w.travel=w.duration

func transfer(source: String,target: String) -> String:
	if target==source or (target!="" and capacity(target)<=assigned(target)): return "此岗位已满或无需派人"
	var nearest=INF
	var best=-1
	for i in s.workers.size():
		if s.workers[i].job!=source: continue
		var distance=worker_point(i).distance_squared_to(job_point(target,i))
		if distance<nearest: nearest=distance;best=i
	if best<0: return "没有可调人手"
	dispatch(best,target)
	return ""

func assign(job: String,delta: int) -> String:
	return transfer("",job) if delta>0 else transfer(job,"")

func job_tile(job: String) -> int:
	return s.edges[job.substr(1)].a if job.begins_with("e") else int(job.substr(1))

func jobs() -> Array:
	var result=[]
	for i in s.cells.size():
		if s.cells[i].kind=="" and s.cells[i].project=="": continue
		var job="t"+str(i)
		if capacity(job)>0 or assigned(job)>0: result.append(job)
	for k in s.edges:
		if capacity("e"+k)>0: result.append("e"+k)
	return result

func minimum_staff(job: String) -> int:
	if capacity(job)==0: return 0
	if job.begins_with("e"): return 1
	var c=s.cells[job_tile(job)]
	if c.kind=="camp": return 2
	if c.project!="": return 1
	if not Town.working(c): return 0
	if c.kind=="farm": return 1 if s.turn%4!=3 else 0
	if c.kind=="academy" or c.kind in Town.OPERATORS: return 1
	return 0

func vacancies() -> Array:
	var missing=[]
	for job in jobs():
		if assigned(job)<minimum_staff(job): missing.append(job)
	missing.sort_custom(func(a,b): return dispatch_priority(a)<dispatch_priority(b))
	return missing

func dispatch_priority(job: String) -> int:
	var site=s.cells[job_tile(job)]
	if job.begins_with("e"):
		return 0 if s.policy.has("flood") and s.flood_at<0 else 2
	if site.kind=="camp" or (site.project=="terrace" and s.policy.has("rain") and not s.rain): return 0
	if site.kind=="farm" and site.project=="": return 1
	return 2 if site.project!="" else 3

func fill_vacancies() -> int:
	var count=0
	for job in vacancies():
		while assigned(job)<minimum_staff(job) and free_workers()>0:
			if assign(job,1)!="": break
			count+=1
	return count

func release_job(job: String):
	for i in s.workers.size():
		if s.workers[i].job==job: dispatch(i,"")

func field_action(id: int,kind: String) -> String:
	if id<0 or id>=s.cells.size() or s.cells[id].kind!="farm": return "请选择一块农田"
	var c=s.cells[id]
	if not Town.working(c): return "田块正在施工、受淹或待检修"
	match kind:
		"fertilized":
			if not s.tech.has("fertilizer"): return "先研习化肥增产"
			if c.fertilized:
				c.fertilized=false
				s.rev+=1
				return ""
		"rotation":
			if not s.tech.has("rotate"): return "先研习谷豆轮作"
			if c.rotation: return "已实行轮作"
		"precise":
			if not s.tech.has("precise"): return "先研习测土配肥"
			if c.precise: return "已精准配肥"
		"patrol":
			if not s.tech.has("scout"): return "先研习田间巡查"
			if c.patrol>=s.turn: return "巡查保护仍生效"
		"compost":
			if s.era<2: return "传统农耕时代开放"
			if c.compost==s.turn: return "本季已施肥"
		_: return "未知农事"
	var zone=V.sector(id)
	if E.warehouse(s,zone).food<2: return "本地仓库需两份口粮"
	E.book_stock(s,zone,"food",-2,"build")
	match kind:
		"fertilized":
			c.fertilized=true
			s.water[V.reach(id)]=mini(100,s.water[V.reach(id)]+8)
			queue_warning("runoff",id,"化肥增产首次用于这块农田")
			next_warning()
		"rotation": c.rotation=true; c.soil=mini(95,c.soil+5)
		"precise": c.precise=true
		"patrol": c.patrol=s.turn+3
		"compost": c.soil=mini(95,c.soil+12); c.compost=s.turn
	s.rev+=1
	return ""

func response_cost(key: String,index: int) -> int:
	return 2 if key in ["birds","weeds"] and index==0 else 0

func record_disease(id: int):
	if not s.frontier.disease.is_empty(): return
	s.frontier.disease={"crop":F.Crops.field_species(s,id),"tile":id,"date":date()}

func queue_warning(key: String,id: int,why: String):
	if s.policy.has(key) or s.cause.has(key) or s.pending==key: return
	s.cause[key]={"tile":id,"why":why}
	if key=="blight": record_disease(id)
	s.warnings.append(key)

func next_warning():
	if s.pending=="" and not s.warnings.is_empty() and s.outcome=="":
		s.pending=s.warnings.pop_front()

func detect_crop_risk():
	for i in farms():
		var c=s.cells[i]
		if not c.crop or not Town.working(c): continue
		if not s.cause.has("birds") and s.tech.has("dry") and s.turn%4==2 and Town.total_level(s,"store")>0:
			queue_warning("birds",i,"谷物晾晒已投入使用，成熟田块与粮仓同时存在")
		if not s.cause.has("weeds") and s.tech.has("dike") and Town.covered(s,i,"canal"):
			queue_warning("weeds",i,"圩堤排水解锁的共渠开始灌溉在田作物")
		if not s.cause.has("blight") and s.tech.has("nursery") and Town.covered(s,i,"nursery"):
			queue_warning("blight",i,"集中育秧解锁的秧圃开始给在田作物供秧")
	next_warning()

func decide(index: int) -> String:
	var key=s.pending
	if key=="" or index<0 or index>1: return "没有待处理的预警"
	var fee=response_cost(key,index)
	if s.food<fee: return "口粮不足，可以选择保留现粮"
	s.food-=fee
	s.ledger.maintenance+=fee
	s.pending=""
	s.policy[key]=RESPONSES[key][index]
	if key=="flood" and index==1:
		var job="t"+str(s.frontier.home)
		for n in 2:
			if free_workers()==0:
				for i in s.workers.size():
					if s.workers[i].job!=job:
						dispatch(i,"")
						break
			assign(job,1)
	if key=="blight":
		s.sick=true
		s.after_blight=false
		s.blight_at=s.turn
		if index==1:
			for n in 2:
				if s.food>=2: reserve()
	note(CRISIS[key][0]+"，聚落决定"+CRISIS[key][2+2*index]+"。")
	s.rev+=1
	next_warning()
	return ""

func _finish_site(id: int):
	var c=s.cells[id]
	var kind=c.project
	c.project=""
	c.done=0
	if kind=="repair": c.condition=100
	elif kind=="upgrade": c.level=2; c.condition=100
	elif kind in ["terrace","ditch"]:
		c[kind]=true
		if kind=="terrace": c.soil=mini(96,c.soil+10)
	else:
		c.kind=kind
	c.erase("inputs")
	c.erase("payer")
	if not (c.kind in ["farm","academy"] or c.kind in Town.OPERATORS): release_job("t"+str(id))
	while assigned("t"+str(id))>capacity("t"+str(id)): assign("t"+str(id),-1)
	s.rev+=1
	note(V.address(id)+"的"+BUILD[kind][0]+"已完工。")

func forage_limit() -> int:
	return maxi(3,[12,13,10,5][int(s.turn)%4]+F.Crops.FORAGE[s.frontier.region][int(s.turn)%4]-s.era)

func work():
	for i in s.workers.size():
		if s.workers[i].travel>0: s.workers[i].travel-=1
	var season=int(s.turn)%4
	for i in s.cells.size():
		var c=s.cells[i]
		if c.kind=="" and c.project=="": continue
		var hands=assigned("t"+str(i),true)
		if hands==0 or c.flood: continue
		if c.project!="":
			var bonus=2 if c.project=="terrace" and s.policy.get("rain","")=="slope" and not s.rain else 1
			c.done+=hands*bonus
			if c.done>=BUILD[c.project][3]: _finish_site(i)
		elif c.kind=="academy" and Town.working(c):
			if s.study!="":
				s.study_time=maxi(0,s.study_time-hands)
				if s.study_time==0:
					s.tech.append(s.study)
					note("研习完成："+TECH[s.study][0]+"。")
					s.study=""
			else:
				c.lesson+=hands
				while c.lesson>=Town.LESSON:
					c.lesson-=Town.LESSON
					c.notes+=1
					s.ledger.science+=1
		elif E.DEPOTS.has(c.kind):
			var cost=E.extraction_time(c.kind,i)
			c.wildwork+=hands
			while c.wildwork>=cost:
				c.wildwork-=cost
				E.book_stock(s,V.sector(i),c.kind,1)
		elif c.kind=="wild":
			if c.picked>=forage_limit(): continue
			c.wildwork+=hands
			var need=[7,6,8,15][season]+mini(s.era,2)
			while c.wildwork>=need and c.picked<forage_limit():
				c.wildwork-=need
				c.picked+=1
				if c.picked%4==0:
					var crop=F.START[s.frontier.region] if i!=WILD[2] else "豆"
					F.Crops.add_sample(s.frontier,crop,1 if i==WILD[1] else 0,1)
					s.rev+=1
				s.food+=1
				s.ledger.gather+=1
		elif c.kind=="farm" and Town.working(c):
			var zone=V.sector(i)
			if not c.crop and season in [0,1] and E.warehouse(s,zone).seed>=2:
				c.crop=true
				c.care=0
				if c.has("next_species"):
					s.frontier.plots[i]=c.next_species
					c.erase("next_species")
				c.sown_line=s.frontier.lines[F.Crops.field_species(s,i)].duplicate()
				c.sown_pollution=c.pollution
				E.book_stock(s,zone,"seed",-2,"sow")
				if s.flood_at>=0 and s.turn>s.flood_at: s.resown=true
				s.rev+=1
			if c.crop: c.care=mini(160,c.care+hands)
		elif i==s.frontier.home and s.policy.get("flood","")=="move" and s.flood_at<0:
			s.evacuated+=hands
	for k in s.edges:
		var e=s.edges[k]
		if e.repairing:
			e.done+=assigned("e"+k,true)
			if e.done>=BUILD.repair[3]:
				e.repairing=false
				e.erase("inputs")
				e.erase("payer")
				e.condition=100
				release_job("e"+k)
				s.rev+=1
			continue
		if e.built: continue
		e.done+=assigned("e"+k,true)*(2 if s.policy.get("flood","")=="dike" and s.flood_at<0 else 1)
		if e.done>=BUILD.levee[3]:
			e.built=true
			e.erase("inputs")
			e.erase("payer")
			release_job("e"+k)
			s.rev+=1
			note(V.address(e.a)+"的田堤合拢。")

func tick():
	if s.outcome!="" or s.pending!="": return
	s.time+=1
	F.tick(self)
	s.clock+=1
	work()
	if s.flood_time>0:
		s.flood_time-=1
		if s.flood_time==0:
			for id in s.flood_cells: s.cells[id].flood=false
			s.rev+=1
			note("洪水退去，受淹田块可以重新耕种。")
	if s.clock>=SEASON_TIME: finish_season()
	if s.outcome=="": detect_crop_risk()

func hit_flood():
	s.flood_at=s.turn
	s.flood_time=34
	s.flood_cells=flood_map()
	var drowned=0
	for i in s.flood_cells:
		var c=s.cells[i]
		if c.crop: drowned+=1
		if c.kind in FACILITIES: c.condition=maxi(0,c.condition-18)
		c.flood=true
		c.crop=false
		c.care=0
	var high_store=false
	for i in s.cells.size():
		if s.cells[i].kind=="store" and Town.working(s.cells[i]) and not s.flood_cells.has(i): high_store=true
	var moved=mini(14 if high_store else 6,floori(float(s.evacuated)/4))
	var exposed_store=false
	var exposed_farms=0
	for i in s.flood_cells:
		if s.cells[i].kind=="store": exposed_store=true
		if s.cells[i].kind=="farm": exposed_farms+=1
	var threatened=6+2*exposed_farms+(4 if exposed_store else 0)
	s.rescued=mini(moved,threatened)
	var damage=maxi(0,threatened-moved)
	var seed_loss=mini(s.seed,mini(2,damage))
	var food_loss=mini(s.food,damage-seed_loss)
	s.seed-=seed_loss
	s.food-=food_loss
	s.lost=seed_loss+food_loss
	s.ledger.loss+=s.lost
	release_job("t"+str(s.frontier.home))
	s.rev+=1
	note("洪峰淹及 %d 块低地，%d 块在田作物需重播。抢回 %d 份粮种，仓储损失 %d 份。" % [s.flood_cells.size(),drowned,s.rescued,s.lost])

func expected_yield(id: int) -> int:
	var c=s.cells[id]
	if c.kind!="farm" or c.flood: return 0
	var gross=8+F.Crops.field_bonus(s,id)+E.ERA_YIELD[s.era]+floori(c.care/10.0)+floori(c.soil/10.0)+4*(c.level-1)
	if V.sector(id)==3 and V.tier(id)==0: gross+=5
	if Town.covered(s,id,"station"): gross+=5
	if Town.covered(s,id,"canal"): gross+=3
	if Town.covered(s,id,"nursery"): gross+=4
	if c.precise: gross+=3
	if c.fertilized: gross+=6+(4 if s.policy.get("runoff","")=="intensive" else 0)
	var land_factor=1.0-0.004*float(c.sown_pollution if c.crop else c.pollution)
	var pest_factor=1.0-minf(0.48,(c.birds+c.weeds+c.disease)/330.0)
	if has_blight(id):
		pest_factor*=0.90 if c.patrol>=s.turn else (0.70 if s.policy.get("blight","")=="inspect" else 0.53)
	var economy_factor=s.efficiency*E.DIFFICULTIES[s.difficulty].yield_pct/10000.0
	return maxi(1,roundi(gross*land_factor*pest_factor*economy_factor*(1.0 if c.condition>=Town.WORKING_CONDITION else 0.6)))

func has_blight(id: int) -> bool:
	return s.sick and (not s.cause.has("blight") or s.cause.blight.tile==id or Town.covered(s,id,"nursery"))

func harvest():
	var total=0
	var affected_harvest=false
	for i in farms():
		var c=s.cells[i]
		if not c.crop: continue
		var amount=expected_yield(i)
		if has_blight(i): affected_harvest=true
		if s.era==3 and Town.working(c) and (c.precise or c.ditch or c.fertilized or Town.covered(s,i,"station")):
			s.modern_harvest=true
		c.crop=false
		c.last=amount
		c.harvests+=1
		F.Crops.harvested(self,i)
		c.care=0
		var saved=mini(2,amount)
		var zone=V.sector(i)
		E.book_stock(s,zone,"food",amount-saved,"crop")
		E.book_stock(s,zone,"seed",saved,"crop")
		total+=amount
		s.first_crop=true
		s.rev+=1
	if total>0:
		if affected_harvest:
			s.after_blight=true
			s.sick=false
		note("秋收 %d 份，每块收获田已优先留种。" % total)

func water_step():
	var previous=s.water.duplicate()
	var load_by_reach=[0,0,0]
	for i in farms():
		var c=s.cells[i]
		var runoff=0
		if c.fertilized:
			runoff=(3 if c.precise else 7)+(3 if s.policy.get("runoff","")=="intensive" else 0)
		var removal=0
		if Town.working(c):
			removal=(5 if c.ditch else 0)+(2 if c.precise else 0)+(1 if c.rotation else 0)
		c.pollution=clampi(c.pollution+runoff-removal,0,100)
		load_by_reach[V.reach(i)]+=runoff-(8 if c.ditch and Town.working(c) else 0)
	for r in 3:
		var inflow=roundi(previous[r-1]*0.38) if r>0 else 0
		s.water[r]=clampi(roundi(previous[r]*0.55)+inflow+load_by_reach[r]-(4 if s.policy.get("runoff","")=="buffer" and r==2 else 0),0,100)

func seasonal_pressure():
	for i in farms():
		var c=s.cells[i]
		var birds=4 if s.policy.has("birds") and c.crop else -3
		var weeds=7 if s.policy.has("weeds") and Town.covered(s,i,"canal") else -3
		var disease=8 if has_blight(i) else -4
		c.birds=clampi(c.birds+birds-(3 if s.policy.get("birds","")=="watch" or c.patrol>=s.turn else 0),0,100)
		c.weeds=clampi(c.weeds+weeds-(5 if s.policy.get("weeds","")=="clear" or c.rotation else 0),0,100)
		c.disease=clampi(c.disease+disease-(5 if c.rotation or c.patrol>=s.turn else 0),0,100)

func _population(served: int):
	var change=Town.demographics(s,served)
	s.pop_change=s.ledger.hires+change
	if change<0:
		var index=s.workers.size()-1
		for i in range(index,-1,-1):
			if s.workers[i].job=="": index=i;break
		s.workers.remove_at(index)
		note("连续两季口粮不足，一名居民离开。")
	s.pop=s.workers.size()

func finish_season():
	var season=int(s.turn)%4
	if s.era==1 and s.policy.has("flood") and s.flood_at<0: hit_flood()
	if s.era==2 and s.policy.has("rain") and not s.rain:
		for i in farms():
			var c=s.cells[i]
			var erosion=4 if c.terrace or c.rotation else 20
			c.soil=maxi(10,c.soil-maxi(1,erosion-(6 if s.policy.rain=="mulch" else 0)))
		s.rain=true
		s.rev+=1
		note("梅雨已过，梯田与轮作田保留了更多表土。")
	seasonal_pressure()
	if season==2: harvest()
	if season==3: s.winter=true
	for i in farms():
		var c=s.cells[i]
		c.soil=clampi(c.soil+(3 if c.rotation else (-2 if c.crop else 0)),10,96)
	water_step()
	for c in s.cells:
		if c.kind in FACILITIES: c.condition=maxi(0,c.condition-1)
	for e in s.edges.values():
		if e.built: e.condition=maxi(0,e.condition-(5 if s.flood_at==s.turn else 1))
	F.season(self)
	var need=s.pop
	var rations=mini(s.food,s.pop)
	s.food-=rations
	s.ledger.eat=rations
	s.full=s.full+1 if rations==need else 0
	s.empty=s.empty+1 if rations==0 else 0
	_population(rations)
	E.settle(s)
	s.ledger.spoil=maxi(0,s.food-Town.storage(s))
	s.food-=s.ledger.spoil
	s.ledger.ending=s.food+s.seed
	s.history.append([s.turn]+E.flows(s.ledger))
	if s.history.size()>8: s.history.pop_front()
	s.last_ledger=s.ledger.duplicate()
	s.last_report="%s　采集 +%d　秋收 +%d　发粮 %d/%d　人口 %+d" % [date(),s.ledger.gather,s.ledger.crop,rations,need,s.pop_change]
	s.ledger=book(s.food+s.seed,s.wood,s.stone)
	s.clock=0
	s.turn+=1
	s.age+=1
	for i in WILD:
		s.cells[i].picked=0
		s.cells[i].wildwork=0
	if s.pop==0 or s.empty>=2 or s.organization==0:
		s.outcome="lost"
		s.end_reason="聚落人口降至零。" if s.pop==0 else ("连续两季完全断粮。" if s.empty>=2 else "组织度降至零，聚落解体。")
		note(s.end_reason)
		return
	if s.turn%4==1:
		var plots=farms()
		var target=s.frontier.home if plots.is_empty() else plots[0]
		if s.era==1 and s.flood_at<0:
			for id in plots:
				if V.tier(id)==0: target=id;break
			queue_warning("flood",target,"本年夏汛到来，上游水位预报超过警戒线")
		if s.era==2 and not s.rain:
			for id in plots:
				if V.tier(id)>0: target=id;break
			queue_warning("rain",target,"夏季梅雨带进入河谷，坡田将遭冲刷")
	next_warning()

func advance_reason() -> String:
	if s.outcome!="": return "战役已结束"
	if s.pending!="": return "请先处理农情急报"
	var groups=Town.requirements(self)
	for group in groups:
		for item in groups[group]:
			if not item[0]: return "尚需"+item[1]
	if s.food<Town.ERA_FOOD[s.era]: return "可用口粮不足"
	return ""

func advance(expected: int) -> String:
	if expected!=s.era: return "时代已经改变"
	var why=advance_reason()
	if why!="": return why
	var fee=Town.ERA_FOOD[s.era]
	s.food-=fee
	s.ledger.advance+=fee
	if s.era==3:
		s.outcome="won"
		note("现代秋收归仓，河谷建立了可持续的现代农业。")
	else:
		s.era+=1
		s.age=0
		s.full=0
		note("聚落拨付 %d 份口粮，进入%s时代。" % [fee,ERAS[s.era]])
	s.rev+=1
	return ""

func goals() -> Array:
	var summary=[]
	var groups=Town.requirements(self)
	for group in groups:
		var count=0
		for item in groups[group]:
			if item[0]: count+=1
		summary.append([count==groups[group].size(),"%s条件　%d / %d" % [group,count,groups[group].size()]])
	if s.era<3: summary.append([s.food>=Town.ERA_FOOD[s.era],"晋阶口粮　%d / %d" % [s.food,Town.ERA_FOOD[s.era]]])
	return summary
