extends RefCounted

const V=preload("res://valley.gd")
const WORKING_CONDITION=50
const CAMP_BEDS=10
const HOUSE_BEDS=4
const CAMP_STORAGE=48
const STORE_STORAGE=36
const LESSON=12
const ERA_FOOD=[12,20,32,0]
const CORE=[["seed","dry"],["dike","scout"],["terrace","rotate"],["machine","precise"]]

static func working(c: Dictionary) -> bool:
	return c.kind!="" and c.project=="" and not c.flood and c.condition>=WORKING_CONDITION

static func facilities(s: Dictionary,kind: String,active: bool=true) -> Array:
	var found=[]
	for id in s.cells.size():
		var c=s.cells[id]
		if c.kind==kind and (not active or working(c)): found.append(id)
	return found

static func total_level(s: Dictionary,kind: String) -> int:
	var levels=0
	for c in s.cells:
		if c.kind==kind and working(c): levels+=c.level
	return levels

static func beds(s: Dictionary) -> int:
	return CAMP_BEDS+HOUSE_BEDS*total_level(s,"house")

static func storage(s: Dictionary) -> int:
	return CAMP_STORAGE+STORE_STORAGE*total_level(s,"store")

static func covered(s: Dictionary,id: int,kind: String) -> bool:
	for other in facilities(s,kind):
		if V.distance(id,other)<=s.cells[other].level: return true
	return false

static func demographics(s: Dictionary,served: int) -> int:
	var need=s.pop
	var shortage=need-served
	s.last_need=need
	s.last_served=served
	s.happiness=clampi(s.happiness+(2 if shortage==0 else -ceili(12.0*shortage/maxi(need,1))),0,100)
	var maintained=true
	for c in s.cells:
		if c.kind!="" and c.condition<WORKING_CONDITION: maintained=false;break
	var morale=1 if shortage==0 and maintained else (-1 if shortage==0 else -3)
	s.organization=clampi(s.organization+morale,0,100)
	s.shortage=s.shortage+1 if shortage>0 else 0
	var ready=shortage==0 and s.pop<beds(s) and s.food>=s.pop and s.happiness>=55
	s.growth=s.growth+1 if ready else 0
	if s.growth>=2:
		s.growth=0
		return 1
	if s.shortage>=2:
		s.shortage=0
		return -1
	return 0

static func requirements(game) -> Dictionary:
	var s=game.s
	var structures=[]
	var survival=[]
	var farms=facilities(s,"farm")
	var safe_store=false
	var expanded_store=false
	for id in facilities(s,"store"):
		if V.tier(id)>0 or not game.flood_map().has(id): safe_store=true
		if s.cells[id].level>=2: expanded_store=true
	match s.era:
		0:
			structures=[[not facilities(s,"academy").is_empty(),"1 所农专"],[not farms.is_empty(),"1 块投产稻田"],[not facilities(s,"store").is_empty(),"1 座备荒粮仓"]]
			survival=[[s.first_crop and s.winter,"完成首收并越冬"],[s.seed>=2,"至少保留 2 份种粮"]]
		1:
			var wall=false
			for e in s.edges.values():
				if e.built and e.condition>=WORKING_CONDITION: wall=true;break
			structures=[[farms.size()>=2,"2 块投产稻田"],[not facilities(s,"house").is_empty(),"1 栋农舍"],[wall or safe_store,"有效田堤或安全粮仓"]]
			survival=[[s.flood_at>=0 and s.flood_time==0 and s.resown,"度过洪峰并完成复播"],[s.full>=1,"最近一季足额供粮"]]
		2:
			structures=[[game.tagged("terrace") or game.tagged("rotation"),"1 块梯田或轮作田"],[not facilities(s,"canal").is_empty() or expanded_store,"有效灌渠或二级粮仓"]]
			survival=[[s.rain and game.mean_soil()>=54,"经历梅雨且平均地力 ≥ 54"],[s.full>=2,"连续两季足额供粮"]]
		3:
			structures=[[farms.size()>=2,"2 块投产稻田"],[not facilities(s,"station").is_empty() or game.tagged("ditch"),"有效农机站或田间净水沟"]]
			survival=[[s.modern_harvest,"使用农机、配肥或净水沟完成一次秋收"],[not s.sick and (s.blight_at<0 or s.after_blight),"出现病情时，受影响稻田恢复收获"],[s.water[2]<=23,"下游污染 ≤ 23（当前 %d）" % s.water[2]],[s.full>=2 and s.seed>=maxi(2,game.farms().size()*2),"连续两季供足口粮，留足下次播种所需"]]
	var techs=[]
	for key in CORE[s.era]: techs.append([s.tech.has(key),game.TECH[key][0]])
	return {"建设":structures,"科技":techs,"生存":survival}
