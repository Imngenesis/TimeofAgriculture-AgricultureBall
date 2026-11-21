extends RefCounted

const V = preload("res://valley.gd")
const Town = preload("res://settlement.gd")
const SEASONS = ["春","夏","秋","冬"]
const ERAS = ["原始采集","早期农耕","传统农耕","工业与现代农业"]
const CHAPTERS = ["在江边扎根","与洪水争田","留住坡上的土","让河水重归清澈"]
const ROMAN = ["Ⅰ","Ⅱ","Ⅲ","Ⅳ"]
const SEASON_TIME = 40
const TECH = {
	"seed": ["留种试种",0,2,[],"解锁稻田。春夏从种仓播种，秋季收粮。"],
	"dry": ["谷物晾晒",0,2,[],"解锁粮仓。建仓后的第一个成熟稻季会引来谷鸟。"],
	"dike": ["圩堤排水",1,3,["seed"],"解锁田堤与灌渠。新渠第一次灌到在田作物时会出现草害。"],
	"scout": ["田间巡查",1,2,["seed"],"解锁巡田。提前护住下一次可能染病的作物。"],
	"terrace": ["等高筑田",2,4,["dike"],"解锁梯田。阶坎减缓冲刷，完工时补充地力。"],
	"rotate": ["稻豆轮作",2,4,["seed"],"解锁轮作。每季恢复地力，梅雨时保护表土。"],
	"nursery": ["集中育秧",2,3,["seed"],"选修。公共秧圃覆盖田增产 4 份，首次在田使用会出现作物病情预警。"],
	"machine": ["机械稻作",3,5,["seed"],"解锁农机站。服务范围内的稻田增产 5 份。"],
	"precise": ["测土配肥",3,5,["terrace","rotate"],"解锁精准配肥与净水沟，控制尾水排放。"],
	"fertilizer": ["化肥增产",3,3,["rotate","terrace"],"选修。田块首次启用高投入施肥会触发尾水预警，每茬增产 6 份，也会积累污染。"]
}
# 名称、所需科技、口粮成本、完工所需人秒
const BUILD = {
	"academy":["农专","",3,8], "house":["农舍","",4,10],
	"farm":["试种稻田","seed",2,9], "store":["备荒粮仓","dry",4,14],
	"levee":["田堤","dike",4,16], "canal":["共用灌渠","dike",5,13], "terrace":["等高梯田","terrace",4,14],
	"nursery":["公共秧圃","nursery",5,14], "station":["农机服务站","machine",6,18], "ditch":["农田净水沟","precise",3,12],
	"upgrade":["扩建二级","",6,16], "repair":["修复设施","",2,8]
}
const FACILITIES=["academy","house","farm","store","canal","nursery","station"]
const SERVICE={"academy":"到岗人员每合计 12 人秒编成 1 点，点农专领取。","house":"每级提供 4 个安居名额。","farm":"春夏使用 2 份种粮播种，秋收后留种。二级田增产 4 份。","store":"每级增加 36 份口粮仓容，高处可避洪。","levee":"封住进水边，保护连通低地。","canal":"建在河岸低地。范围内稻田增产 3 份，扩建后覆盖两格。","terrace":"改良已开垦稻田，减轻冲刷。","nursery":"范围内稻田增产 4 份，同时引入病情风险。","station":"范围内稻田增产 5 份，扩建后覆盖两格。","ditch":"改良已开垦稻田，拦截本河段尾水。"}
const LAND = ["河岸低地","台地","高地"]
const HOME = 28
const WILD = [19,42,60]
const CRISIS = {
	"flood":["洪峰将至","上游水尺一夜涨了三格。下个季末，河水将从未封住的进水口漫上低田。",
		"抢修田堤","本季堤坝施工速度翻倍。选一块低田，沿来水方向落堤。",
		"转移粮种","调最多两人往高处转运。营地可护 6 份，有安全粮仓可护 14 份。"],
	"rain":["坡地告急","梅雨正在逼近。裸露的田面会流失表土，地力低的稻田下一次秋收将减产。",
		"先稳坡脚","本季筑梯田速度翻倍，完工的阶坎挡住冲刷。",
		"保住表土","把秸秆覆盖田面，本次每块田额外减少 6 点地力损失。"],
	"runoff":["下游水色变了","稻田尾水正在汇入河道。化肥带来的产量会反映在秋收，排放则逐季流向下游。",
		"留出缓冲带","划出岸边草带，每季截留下游 4 点污染，保留常规产量。",
		"集中保产","使用化肥的田块额外增产 4 份，每季多排放 3 点，净水沟可截流。"],
	"blight":["穗上出现病斑","巡田人从几块田带回有斑点的稻穗。下一次秋收会检验这片河谷的防病能力。",
		"分田巡护","本次疫病减轻，已巡查的田保住大部分收成。",
		"保护种仓","优先保留良种，立刻封存最多 4 份口粮做种，田间承受较重损失。"],
	"birds":["晒场里的谷鸟","晾晒和集中储藏吸引了谷鸟，成熟田开始受食害。",
		"拨粮护田","耗 2 份口粮，组织持续守望，降低食害压力。","先顾口粮","保留现粮，成熟田承担较多食害。"],
	"weeds":["引水田里的杂草","共用灌渠开始给稻田供水，田边出现争水的杂草。",
		"拨粮除草","耗 2 份口粮组织清理，受灌田的草害增长减缓。","维持供水","保留口粮与灌渠产出，轮作可以缓解草害。"]
}
const RESPONSES={"flood":["dike","move"],"rain":["slope","mulch"],"runoff":["buffer","intensive"],"blight":["inspect","seed"],"birds":["watch","keep"],"weeds":["clear","keep"]}

var s: Dictionary
var events: Array = []

func _init():
	reset()

func reset():
	var cells = []
	for id in V.COLS*V.ROWS:
		var kind = "camp" if id == HOME else ("wild" if WILD.has(id) else "")
		cells.append({"kind":kind,"project":"","done":0,"soil":65 + (id*7)%12,
			"crop":false,"care":0,"last":0,"harvests":0,"terrace":false,"rotation":false,
			"precise":false,"ditch":false,"patrol":-1,"compost":-1,"wildwork":0,"picked":0,"flood":false})
	s = {"version":2,"turn":0,"clock":0,"time":0,"era":0,"age":0,"food":30,"seed":0,
		"pop":10,"science":0,"tech":[],"study":"","study_time":0,"cells":cells,"edges":{},
		"workers":[],"water":[0,0,0],"full":0,"empty":0,"pending":"","policy":{},
		"flood_at":-1,"flood_time":0,"flood_cells":[],"evacuated":0,"rescued":0,"lost":0,
		"winter":false,"first_crop":false,"resown":false,"rain":false,"after_blight":false,
		"blight_at":-1,"sick":false,"outcome":"","log":[],"last_report":"","rev":0,
		"ledger":book(30),"last_ledger":{}}
	_extend_state()
	for i in 10:
		add_worker()
	events.clear()
	note("十人在江边扎营，带来了三十份口粮。")

func book(opening: int) -> Dictionary:
	return {"opening":opening,"gather":0,"crop":0,"refund":0,"build":0,"maintenance":0,"advance":0,"eat":0,"loss":0,"sow":0,"spoil":0,"science":0,"ending":opening}

func _extend_state():
	s.merge({"happiness":62,"organization":65,"shortage":0,"growth":0,"last_need":0,"last_served":0,"pop_change":0,
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
	events.clear()

func add_worker():
	var base=rest_position(s.workers.size())
	s.workers.append({"job":"","from":base,"to":base,"path":[base,base],"length":0.0,"travel":0,"duration":1})

func rest_position(i: int) -> Vector2:
	var a = i*2.4
	return V.center(HOME) + Vector2(cos(a),sin(a))*(0.55+0.12*(i%3))

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
		"farm": return "等高梯田" if c.terrace else ("稻豆轮作田" if c.rotation else "稻田")
	if BUILD.has(c.kind): return BUILD[c.kind][0]
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

func reserve(release: bool=false) -> String:
	if release:
		if s.seed<=0: return "种仓已空"
		var n=mini(2,s.seed)
		s.seed-=n
		s.food+=n
	else:
		if s.food<2: return "需有两份口粮"
		s.food-=2
		s.seed+=2
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
		if c.kind!="farm": return "请选择一块已开垦的稻田"
		if c[kind]: return "这块田已有"+def[0]
		if c.project!="": return "田上已有工程"
	elif c.kind!="" or c.project!="": return "这块地已占用"
	if kind=="academy" and academy_id()>=0: return "河谷已有农专，可前往派工或扩建"
	if kind=="canal" and V.tier(id)!=0: return "渠首须设在临河低地"
	if s.food<def[2]: return "口粮不足，需 %d 份" % def[2]
	return ""

func construct(kind: String,id: int,d: int=0) -> String:
	var why=build_reason(kind,id,d)
	if why!="": return why
	s.food-=BUILD[kind][2]
	if kind=="repair": s.ledger.maintenance+=BUILD[kind][2]
	else: s.ledger.build+=BUILD[kind][2]
	var job="t"+str(id)
	if kind=="levee":
		var key=edge_for(id,d)
		s.edges[key]={"a":id,"dir":d,"built":false,"done":0,"condition":100,"repairing":false}
		job="e"+key
	else:
		s.cells[id].project=kind
		s.cells[id].done=0
	if free_workers()>0 and assigned(job)==0: assign(job,1)
	s.rev+=1
	note(V.address(id)+"动工修建"+BUILD[kind][0]+"。")
	return ""

func repair_edge(key: String) -> String:
	if not s.edges.has(key): return "找不到田堤"
	var e=s.edges[key]
	if not e.built or e.repairing or e.condition>=100: return "此段田堤暂时无需检修"
	if s.food<BUILD.repair[2]: return "检修需要两份口粮"
	s.food-=BUILD.repair[2]
	s.ledger.maintenance+=BUILD.repair[2]
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
	if job.begins_with("e"):
		var key=job.substr(1)
		if not s.edges.has(key): return "工地已结束"
		var e=s.edges[key]
		if e.built and not e.repairing: return "田堤已经合拢"
		refund=project_refund("repair" if e.repairing else "levee",e.done)
		release_job(job)
		if e.repairing: e.repairing=false;e.done=BUILD.levee[3]
		else: s.edges.erase(key)
	elif job.begins_with("t") and job.substr(1).is_valid_int():
		var id=int(job.substr(1))
		if id<0 or id>=s.cells.size(): return "找不到工地"
		var c=s.cells[id]
		if c.project=="": return "工地已结束"
		refund=project_refund(c.project,c.done)
		c.project=""
		c.done=0
		while assigned(job)>capacity(job): assign(job,-1)
	else: return "找不到工地"
	s.food+=refund
	s.ledger.refund+=refund
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
	if c.project!="" or c.kind in ["wild","farm"]: return 4
	if c.kind=="academy": return 2 if c.level==1 else 4
	if id==HOME and s.policy.get("flood","")=="move" and s.flood_at<0: return 2
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

func assign(job: String,delta: int) -> String:
	if delta>0:
		if capacity(job)<=assigned(job): return "此岗位已满或无需派人"
		if free_workers()==0: return "没有闲人，请先从其他岗位调回"
		var best=-1
		var nearest=INF
		for i in s.workers.size():
			if s.workers[i].job!="": continue
			var dist=worker_point(i).distance_squared_to(job_point(job,i))
			if dist<nearest:
				nearest=dist
				best=i
		dispatch(best,job)
	else:
		for i in range(s.workers.size()-1,-1,-1):
			if s.workers[i].job==job:
				dispatch(i,"")
				return ""
		return "此处还没有人手"
	return ""

func release_job(job: String):
	for i in s.workers.size():
		if s.workers[i].job==job: dispatch(i,"")

func field_action(id: int,kind: String) -> String:
	if id<0 or id>=s.cells.size() or s.cells[id].kind!="farm": return "请选择一块稻田"
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
			if not s.tech.has("rotate"): return "先研习稻豆轮作"
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
	if s.food<2: return "需要两份口粮"
	s.food-=2
	s.ledger.build+=2
	match kind:
		"fertilized":
			c.fertilized=true
			s.water[V.reach(id)]=mini(100,s.water[V.reach(id)]+8)
			queue_warning("runoff",id,"化肥增产首次用于这块稻田")
			next_warning()
		"rotation": c.rotation=true; c.soil=mini(95,c.soil+5)
		"precise": c.precise=true
		"patrol": c.patrol=s.turn+3
		"compost": c.soil=mini(95,c.soil+12); c.compost=s.turn
	s.rev+=1
	return ""

func response_cost(key: String,index: int) -> int:
	return 2 if key in ["birds","weeds"] and index==0 else 0

func queue_warning(key: String,id: int,why: String):
	if s.policy.has(key) or s.cause.has(key) or s.pending==key: return
	s.cause[key]={"tile":id,"why":why}
	s.warnings.append(key)

func next_warning():
	if s.pending=="" and not s.warnings.is_empty() and s.outcome=="":
		s.pending=s.warnings.pop_front()

func detect_crop_risk():
	for i in farms():
		var c=s.cells[i]
		if not c.crop or not Town.working(c): continue
		if not s.cause.has("birds") and s.tech.has("dry") and s.turn%4==2 and Town.total_level(s,"store")>0:
			queue_warning("birds",i,"谷物晾晒已投入使用，成熟稻田与粮仓同时存在")
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
		var job="t"+str(HOME)
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
	if not c.kind in ["farm","academy"]: release_job("t"+str(id))
	while assigned("t"+str(id))>capacity("t"+str(id)): assign("t"+str(id),-1)
	s.rev+=1
	note(V.address(id)+"的"+BUILD[kind][0]+"已完工。")

func forage_limit() -> int:
	return maxi(3,[12,13,10,5][int(s.turn)%4]-s.era)

func work():
	for i in s.workers.size():
		if s.workers[i].travel>0: s.workers[i].travel-=1
	var season=int(s.turn)%4
	for i in s.cells.size():
		var c=s.cells[i]
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
		elif c.kind=="wild":
			if c.picked>=forage_limit(): continue
			c.wildwork+=hands
			var need=[7,6,8,15][season]+mini(s.era,2)
			while c.wildwork>=need and c.picked<forage_limit():
				c.wildwork-=need
				c.picked+=1
				s.food+=1
				s.ledger.gather+=1
		elif c.kind=="farm" and Town.working(c):
			if not c.crop and season in [0,1] and s.seed>=2:
				c.crop=true
				c.care=0
				c.sown_pollution=c.pollution
				s.seed-=2
				s.ledger.sow+=2
				if s.flood_at>=0 and s.turn>s.flood_at: s.resown=true
				s.rev+=1
			if c.crop: c.care=mini(160,c.care+hands)
		elif i==HOME and s.policy.get("flood","")=="move" and s.flood_at<0:
			s.evacuated+=hands
	for k in s.edges:
		var e=s.edges[k]
		if e.repairing:
			e.done+=assigned("e"+k,true)
			if e.done>=BUILD.repair[3]:
				e.repairing=false
				e.condition=100
				release_job("e"+k)
				s.rev+=1
			continue
		if e.built: continue
		e.done+=assigned("e"+k,true)*(2 if s.policy.get("flood","")=="dike" and s.flood_at<0 else 1)
		if e.done>=BUILD.levee[3]:
			e.built=true
			release_job("e"+k)
			s.rev+=1
			note(V.address(e.a)+"的田堤合拢。")

func tick():
	if s.outcome!="" or s.pending!="": return
	s.time+=1
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
	release_job("t"+str(HOME))
	s.rev+=1
	note("洪峰淹及 %d 块低地，%d 块在田作物需重播。抢回 %d 份粮种，仓储损失 %d 份。" % [s.flood_cells.size(),drowned,s.rescued,s.lost])

func expected_yield(id: int) -> int:
	var c=s.cells[id]
	if c.kind!="farm" or c.flood: return 0
	var gross=8+floori(c.care/10.0)+floori(c.soil/10.0)+4*(c.level-1)
	if Town.covered(s,id,"station"): gross+=5
	if Town.covered(s,id,"canal"): gross+=3
	if Town.covered(s,id,"nursery"): gross+=4
	if c.precise: gross+=3
	if c.fertilized: gross+=6+(4 if s.policy.get("runoff","")=="intensive" else 0)
	var land_factor=1.0-0.004*float(c.sown_pollution if c.crop else c.pollution)
	var pest_factor=1.0-minf(0.48,(c.birds+c.weeds+c.disease)/330.0)
	if has_blight(id):
		pest_factor*=0.90 if c.patrol>=s.turn else (0.70 if s.policy.get("blight","")=="inspect" else 0.53)
	return maxi(1,roundi(gross*land_factor*pest_factor*(1.0 if c.condition>=Town.WORKING_CONDITION else 0.6)))

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
		c.care=0
		var saved=mini(2,amount)
		s.food+=amount-saved
		s.seed+=saved
		total+=amount
		s.ledger.crop+=amount
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
	s.pop_change=change
	if change>0:
		add_worker()
		note("连续两季粮足、有空床位，一名新居民加入，已可派工。")
	elif change<0:
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
	var need=s.pop
	var rations=mini(s.food,s.pop)
	s.food-=rations
	s.ledger.eat=rations
	s.full=s.full+1 if rations==need else 0
	s.empty=s.empty+1 if rations==0 else 0
	s.ledger.spoil=maxi(0,s.food-Town.storage(s))
	s.food-=s.ledger.spoil
	_population(rations)
	s.ledger.ending=s.food+s.seed
	s.last_ledger=s.ledger.duplicate()
	s.last_report="%s　采集 +%d　秋收 +%d　发粮 %d/%d　人口 %+d" % [date(),s.ledger.gather,s.ledger.crop,rations,need,s.pop_change]
	s.ledger=book(s.food+s.seed)
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
		var target=HOME if plots.is_empty() else plots[0]
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
