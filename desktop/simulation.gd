extends RefCounted

const V = preload("res://valley.gd")
const SEASONS = ["春","夏","秋","冬"]
const ERAS = ["原始采集","早期农耕","传统农耕","工业与现代农业"]
const CHAPTERS = ["在江边扎根","与洪水争田","留住坡上的土","让河水重归清澈"]
const ROMAN = ["Ⅰ","Ⅱ","Ⅲ","Ⅳ"]
const SEASON_TIME = 40
const TECH = {
	"seed": ["留种试种",0,2,[],"解锁稻田。春夏从种仓播种，秋季收粮。"],
	"dry": ["谷物晾晒",0,2,[],"解锁备荒粮仓。高地粮仓可扩大洪时转运量。"],
	"dike": ["圩堤排水",1,3,["seed"],"解锁田堤。沿进水边修堤，阻断连通低地的洪水。"],
	"scout": ["田间巡查",1,2,["seed"],"解锁巡田。提前护住下一次可能染病的作物。"],
	"terrace": ["等高筑田",2,3,["dike"],"解锁梯田。阶坎减缓冲刷，完工时补充地力。"],
	"rotate": ["稻豆轮作",2,3,["seed"],"解锁轮作。每季恢复地力，梅雨时保护表土。"],
	"machine": ["机械稻作",3,3,["seed"],"解锁农机站。全谷稻田增产，减轻人手压力。"],
	"precise": ["测土配肥",3,3,["terrace","rotate"],"解锁精准配肥与净水沟。减少农田向下游的排放。"]
}
# 名称、所需科技、口粮成本、完工所需人秒
const BUILD = {
	"farm":["试种稻田","seed",2,9], "store":["备荒粮仓","dry",4,14],
	"levee":["田堤","dike",4,16], "terrace":["等高梯田","terrace",4,14],
	"station":["农机服务站","machine",5,18], "ditch":["农田净水沟","precise",3,12]
}
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
		"集中保产","本时代每田额外增产 4 份，每季增加污染；净水沟可截流。"],
	"blight":["穗上出现病斑","巡田人从几块田带回有斑点的稻穗。下一次秋收会检验这片河谷的防病能力。",
		"分田巡护","本次疫病减轻，已巡查的田保住大部分收成。",
		"保护种仓","优先保留良种，立刻封存最多 4 份口粮做种，田间承受较重损失。"]
}

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
	s = {"version":1,"turn":0,"clock":0,"time":0,"era":0,"age":0,"food":30,"seed":0,
		"pop":10,"science":3,"tech":[],"study":"","study_time":0,"cells":cells,"edges":{},
		"workers":[],"water":[0,0,0],"full":0,"empty":0,"pending":"","policy":{},
		"flood_at":-1,"flood_time":0,"flood_cells":[],"evacuated":0,"rescued":0,"lost":0,
		"winter":false,"first_crop":false,"resown":false,"rain":false,"after_blight":false,
		"blight_at":-1,"sick":false,"outcome":"","log":[],"last_report":"","rev":0,
		"ledger":book(),"last_ledger":{}}
	for i in 10:
		var base = rest_position(i)
		s.workers.append({"job":"","from":base,"to":base,"path":[base,base],"length":0.0,"travel":0,"duration":1})
	events.clear()
	note("十人在江边扎营，带来了三十份口粮。")

func book() -> Dictionary:
	return {"gather":0,"crop":0,"build":0,"eat":0,"loss":0,"sow":0}

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

func has_build(kind: String) -> bool:
	for c in s.cells:
		if c.kind==kind: return true
	return false

func mean_soil() -> int:
	var ids=farms()
	if ids.is_empty(): return 0
	var total=0
	for i in ids: total+=s.cells[i].soil
	return roundi(float(total)/ids.size())

func tagged(kind: String) -> bool:
	for i in farms():
		if s.cells[i][kind]: return true
	return false

func location_name(id: int) -> String:
	var c=s.cells[id]
	if V.tier(id)<0: return ["上游河道","中游河道","下游河道"][V.reach(id)]
	if c.project!="": return BUILD[c.project][0]+"工地"
	match c.kind:
		"camp": return "河谷营地"
		"wild": return "野粮采集地"
		"farm": return "等高梯田" if c.terrace else ("稻豆轮作田" if c.rotation else "稻田")
		"store": return "备荒粮仓"
		"station": return "农机服务站"
	return LAND[V.tier(id)]

func research_reason(id: String) -> String:
	if not TECH.has(id): return "未知农学"
	var t=TECH[id]
	if s.tech.has(id): return "已掌握"
	if s.study!="": return "正在研习"+TECH[s.study][0]
	if s.era<t[1]: return "在"+ERAS[t[1]]+"开放"
	if not t[3].is_empty():
		var qualified=false
		for pre in t[3]:
			if s.tech.has(pre): qualified=true
		if not qualified: return "先掌握"+TECH[t[3][0]][0]
	if s.science<t[2]: return "农学点不足"
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
			if key==extra or (s.edges.has(key) and s.edges[key].built): continue
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
	if not s.tech.has(def[1]): return "先研习「"+TECH[def[1]][0]+"」"
	if V.tier(id)<0: return "河道内不能施工"
	var c=s.cells[id]
	if c.flood: return "待洪水退去再施工"
	if kind=="levee":
		var k=edge_for(id,d)
		if k=="": return "超出河谷边界"
		if s.edges.has(k): return "这段堤岸已占用"
		if V.tier(id)!=0 or protected_by(id,d).is_empty(): return "这里不是来水口，请选临河低地"
	elif kind in ["terrace","ditch"]:
		if c.kind!="farm": return "请选择一块已开垦的稻田"
		if c[kind]: return "这块田已有"+def[0]
		if c.project!="": return "田上已有工程"
	elif c.kind!="" or c.project!="": return "这块地已占用"
	if s.food<def[2]: return "口粮不足，需 %d 份" % def[2]
	return ""

func construct(kind: String,id: int,d: int=0) -> String:
	var why=build_reason(kind,id,d)
	if why!="": return why
	s.food-=BUILD[kind][2]
	s.ledger.build+=BUILD[kind][2]
	var job="t"+str(id)
	if kind=="levee":
		var key=edge_for(id,d)
		s.edges[key]={"a":id,"dir":d,"built":false,"done":0}
		job="e"+key
	else:
		s.cells[id].project=kind
		s.cells[id].done=0
	if free_workers()>0 and assigned(job)==0: assign(job,1)
	s.rev+=1
	note(V.address(id)+"动工修建"+BUILD[kind][0]+"。")
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
		return 4 if s.edges.has(k) and not s.edges[k].built else 0
	if not job.begins_with("t"): return 0
	var id=int(job.substr(1))
	if id<0 or id>=s.cells.size(): return 0
	var c=s.cells[id]
	if c.project!="" or c.kind in ["wild","farm"]: return 4
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
	match kind:
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
		"rotation": c.rotation=true; c.soil=mini(95,c.soil+5)
		"precise": c.precise=true
		"patrol": c.patrol=s.turn+3
		"compost": c.soil=mini(95,c.soil+12); c.compost=s.turn
	s.rev+=1
	return ""

func decide(index: int) -> String:
	var key=s.pending
	if key=="" or index<0 or index>1: return "没有待处理的预警"
	s.pending=""
	s.policy[key]=[["dike","move"],["slope","mulch"],["buffer","intensive"],["inspect","seed"]][["flood","rain","runoff","blight"].find(key)][index]
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
		s.blight_at=s.turn
		if index==1:
			for n in 2:
				if s.food>=2: reserve()
	note(CRISIS[key][0]+"，聚落决定"+CRISIS[key][2+2*index]+"。")
	return ""

func _finish_site(id: int):
	var c=s.cells[id]
	var kind=c.project
	c.project=""
	c.done=0
	if kind in ["terrace","ditch"]:
		c[kind]=true
		if kind=="terrace": c.soil=mini(96,c.soil+10)
	else:
		c.kind=kind
	if c.kind!="farm": release_job("t"+str(id))
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
		elif c.kind=="wild":
			if c.picked>=forage_limit(): continue
			c.wildwork+=hands
			var need=[7,6,8,15][season]+mini(s.era,2)
			while c.wildwork>=need and c.picked<forage_limit():
				c.wildwork-=need
				c.picked+=1
				s.food+=1
				s.ledger.gather+=1
		elif c.kind=="farm":
			if not c.crop and season in [0,1] and s.seed>=2:
				c.crop=true
				c.care=0
				s.seed-=2
				s.ledger.sow+=2
				if s.flood_at>=0 and s.turn>s.flood_at: s.resown=true
				s.rev+=1
			if c.crop: c.care=mini(160,c.care+hands)
		elif i==HOME and s.policy.get("flood","")=="move" and s.flood_at<0:
			s.evacuated+=hands
	for k in s.edges:
		var e=s.edges[k]
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
	if s.study!="":
		s.study_time-=1
		if s.study_time<=0:
			s.tech.append(s.study)
			note("研习完成："+TECH[s.study][0]+"。")
			s.study=""
	work()
	if s.flood_time>0:
		s.flood_time-=1
		if s.flood_time==0:
			for id in s.flood_cells: s.cells[id].flood=false
			s.rev+=1
			note("洪水退去，受淹田块可以重新耕种。")
	if s.clock>=SEASON_TIME: finish_season()

func hit_flood():
	s.flood_at=s.turn
	s.flood_time=34
	s.flood_cells=flood_map()
	var drowned=0
	for i in s.flood_cells:
		var c=s.cells[i]
		if c.crop: drowned+=1
		c.flood=true
		c.crop=false
		c.care=0
	var high_store=false
	for i in s.cells.size():
		if s.cells[i].kind=="store" and not s.flood_cells.has(i): high_store=true
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

func harvest():
	var total=0
	for i in farms():
		var c=s.cells[i]
		if not c.crop: continue
		var amount=8+floori(c.care/10.0)+floori(c.soil/10.0)+(5 if has_build("station") else 0)+(3 if c.precise else 0)
		if s.policy.get("runoff","")=="intensive": amount+=4
		if s.sick:
			var factor=0.88 if c.patrol>=s.turn else (0.65 if s.policy.get("blight","")=="inspect" else 0.48)
			amount=maxi(1,roundi(amount*factor))
		c.crop=false
		c.last=amount
		c.harvests+=1
		c.care=0
		s.food+=amount-2
		s.seed+=2
		total+=amount
		s.ledger.crop+=amount
		s.first_crop=true
		s.rev+=1
	if total>0:
		if s.sick:
			s.after_blight=true
			s.sick=false
		note("秋收 %d 份，各收获田已各留两份种粮。" % total)

func water_step():
	var previous=s.water.duplicate()
	var load_by_reach=[0,0,0]
	if s.era==3:
		for i in farms():
			var c=s.cells[i]
			load_by_reach[V.reach(i)]+= (1 if c.precise else 4)+(3 if s.policy.get("runoff","")=="intensive" else 0)-(8 if c.ditch else 0)
	for r in 3:
		var inflow=roundi(previous[r-1]*0.38) if r>0 else 0
		var baseline=4 if s.era==3 and r==2 else 0
		s.water[r]=clampi(roundi(previous[r]*0.55)+inflow+load_by_reach[r]+baseline-(4 if s.policy.get("runoff","")=="buffer" else 0),0,100)

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
	if season==2: harvest()
	if season==3: s.winter=true
	for i in farms():
		var c=s.cells[i]
		c.soil=clampi(c.soil+(3 if c.rotation else (-2 if c.crop else 0)),10,96)
	water_step()
	var rations=mini(s.food,s.pop)
	s.food-=rations
	s.ledger.eat=rations
	s.full=s.full+1 if rations==s.pop else 0
	s.empty=s.empty+1 if rations==0 else 0
	s.last_ledger=s.ledger.duplicate()
	s.last_report="%s　采集 +%d　秋收 +%d　发粮 %d/%d" % [date(),s.ledger.gather,s.ledger.crop,rations,s.pop]
	s.ledger=book()
	s.clock=0
	s.turn+=1
	s.age+=1
	for i in WILD:
		s.cells[i].picked=0
		s.cells[i].wildwork=0
	s.science+=2
	if s.empty>=2:
		s.outcome="lost"
		note("连续两季完全断粮，聚落离开了江岸。")
		return
	if chapter_complete():
		if s.era==3:
			s.outcome="won"
			note("疫后秋收归仓，河谷建立了可持续的现代农业。")
			return
		s.era+=1
		s.age=0
		s.full=0
		if s.era==3: s.water=[12,17,24]
		note("进入"+ERAS[s.era]+"时代。")
	match s.era:
		1:
			if s.age>=1 and not s.policy.has("flood"): s.pending="flood"
		2:
			if s.age>=1 and not s.policy.has("rain"): s.pending="rain"
		3:
			if s.age>=1 and not s.policy.has("runoff"): s.pending="runoff"
			elif s.age>=2 and not s.policy.has("blight"): s.pending="blight"

func chapter_complete() -> bool:
	match s.era:
		0: return s.first_crop and s.winter and s.seed>=2
		1: return s.flood_at>=0 and s.flood_time==0 and s.resown and s.full>=1
		2: return s.rain and (tagged("terrace") or tagged("rotation")) and mean_soil()>=54 and s.full>=2
		3: return (has_build("station") or tagged("precise")) and s.after_blight and s.water[2]<=23 and s.full>=2 and s.seed>=maxi(2,farms().size()*2)
	return false

func goals() -> Array:
	match s.era:
		0: return [[s.first_crop,"完成第一次稻谷秋收"],[s.winter,"度过一个冬季"],[s.seed>=2,"种仓保有 2 份良种"]]
		1: return [[s.flood_at>=0 and s.flood_time==0,"经历洪峰并等到退水"],[s.resown,"洪后重新播种一块田"],[s.full>=1,"本季足额供粮"]]
		2: return [[s.rain,"经过一次梅雨冲刷"],[tagged("terrace") or tagged("rotation"),"有一块梯田或轮作田"],[mean_soil()>=54,"平均地力 %d / 54" % mean_soil()],[s.full>=2,"连续足额供粮 %d / 2 季" % mini(2,s.full)]]
		_: return [[has_build("station") or tagged("precise"),"农机或精准配肥已投产"],[s.after_blight,"完成一次疫后秋收"],[s.water[2]<=23,"下游污染 %d / 上限 23" % s.water[2]],[s.full>=2 and s.seed>=maxi(2,farms().size()*2),"连续两季吃饱，留足下季种粮"]]
