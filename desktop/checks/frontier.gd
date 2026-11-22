extends SceneTree

const Model=preload("res://simulation.gd")
const F=preload("res://frontier.gd")
const C=preload("res://crop_book.gd")
const V=preload("res://valley.gd")
const Saves=preload("res://saves.gd")
var failures=0

func _initialize(): call_deferred("run")

func expect(ok: bool,label: String):
	if not ok:
		failures+=1
		printerr("FAIL "+label)

func act(m,cmd,arg=null):
	var msg=F.action(m,cmd,arg)
	expect(msg=="",cmd+" "+str(arg)+" "+msg)

func clock_ticks(m,n: int):
	for k in n:
		if m.s.pending!="": m.decide(1)
		m.tick()

func campaign(region: int=0):
	var m=Model.new()
	m.reset(1,region)
	m.s.cells[38].kind="academy"
	for id in [m.s.frontier.home,39]: F.Roads.inherit_path(m.s,38,id)
	F.Roads.rebuild(m.s)
	m.s.food=45
	m.s.ledger.opening=45
	m.s.wood=45
	m.s.ledger.wood_open=45
	m.s.stone=30
	m.s.ledger.stone_open=30
	return m

func habitats_and_lines():
	var m=Model.new()
	for region in C.REGIONS.size():
		m.reset(1,region)
		var f=m.s.frontier
		expect(f.region==region and m.s.cells[f.home].kind=="camp" and C.START[region] in f.lines,"normal start uses chosen biome, camp and landrace")
		expect(V.tier(f.home)>=0,"selected camp is on land")
		var found=[C.START[region]]
		for z in range(1,4):
			for crop in F.samples_at(m.s,z):
				if crop not in found: found.append(crop)
		expect(found.size()==C.NAMES.size(),"all crops attainable in each ecosystem")
		for z in 4: expect(V.tier(F.anchor(m.s,z))>=0,"all transport depots are on land")
	var regions={}
	var camps={}
	seed(37651)
	for n in 144:
		m.reset(2,0)
		regions[m.s.frontier.region]=true
		camps[m.s.frontier.home]=true
	expect(regions.size()==C.REGIONS.size() and camps.size()==F.HOMES.size(),"hard mode randomizes both habitat and camp")

	m=campaign()
	var f=m.s.frontier
	m.assign("t19",1)
	for k in 36: m.work()
	expect(f.samples.get("稻",[0,0])[0]>0,"real foragers collect seed at the local site")
	var crop="粟"
	C.add_sample(f,crop,0,2)
	act(m,"trial",[crop,0])
	expect(not f.lines.has(crop) and f.trials.has(crop) and f.samples[crop][0]==0,"domestication consumes wild stock and takes time")
	clock_ticks(m,40)
	expect(f.lines.has(crop) and not f.trials.has(crop),"trial becomes a plantable line")
	C.add_sample(f,crop,1,2)
	act(m,"trial",[crop,1])
	expect(F.action(m,"trial",[crop,1])!="","one active trial per crop")
	clock_ticks(m,40)
	expect(f.lines[crop].vigor==1 and f.lines[crop].yield_bonus==1,"cross keeps yield parent and inherits hardiness")
	m.s.cells[39].kind="farm"
	act(m,"sow",[39,crop])
	m.s.cells[39].crop=true
	m.s.cells[39].sown_line=f.lines[crop].duplicate()
	var first=m.expected_yield(39)
	f.lines[crop].yield_bonus+=4
	expect(m.expected_yield(39)==first,"standing crop keeps the planted traits")
	act(m,"sow",[39,"稻"])
	expect(C.field_species(m.s,39)==crop,"changing next sowing preserves a standing crop")
	m.harvest()
	m.s.turn=4
	m.s.seed=4
	m.assign("t39",1)
	for k in 24: m.work()
	expect(C.field_species(m.s,39)=="稻" and m.s.cells[39].crop,"new sowing uses queued species")

	var positive=[]
	var negative=[]
	for d in 3:
		m.reset(d)
		m.s.frontier.rng=87421
		var good=0
		var bad=0
		var local=C.START[m.s.frontier.region]
		for n in 600:
			m.s.turn=n
			m.s.frontier.lines[local]=C.line()
			C.harvested(m,39)
			var score=m.s.frontier.lines[local].yield_bonus
			if score>0: good+=1
			if score<0: bad+=1
			var before=m.s.frontier.rng
			C.harvested(m,37)
			expect(before==m.s.frontier.rng,"mutation rolls once per crop and season")
		positive.append(good);negative.append(bad)
	expect(positive[0]>positive[1] and positive[1]>positive[2] and negative[0]<negative[1] and negative[1]<negative[2],"observed favorable and adverse rates track difficulty")

func travel_and_storage():
	var m=campaign(4)
	var s=m.s
	var f=s.frontier
	act(m,"survey",[1,F.samples_at(s,1)[0]])
	expect(s.pop==8 and m.free_workers()==8 and F.people_total(s)==10 and F.incoming(s)==2 and m.recruit_reason()!="","scouts use people and reserve their own beds")
	expect(F.action(m,"survey",[1,F.samples_at(s,1)[0]])!="" and s.ledger.explore==4,"duplicate departure cannot spend twice")
	clock_ticks(m,12)
	var copy=Model.new()
	copy.restore(bytes_to_var(var_to_bytes(s)))
	clock_ticks(copy,19)
	expect(copy.s.frontier.posts.is_empty() and copy.s.frontier.missions.size()==1,"mid-journey save does not deliver early")
	clock_ticks(copy,1)
	expect(copy.s.frontier.posts.has(1) and copy.s.pop==10 and copy.s.frontier.samples[F.samples_at(copy.s,1)[0]]==[2,2],"explorers arrive once with both landraces")
	m=copy;s=m.s;f=s.frontier
	act(m,"survey",[2,F.samples_at(s,2)[0]])
	clock_ticks(m,32)
	for z in [1,2]:
		act(m,"road",[0,z])
		var route=F.route(s,0,z)
		expect(route.road and route.time<F.travel_time(route.path,false),"road changes actual delivery time")
	expect(F.route(s,1,2).road and F.Roads.path(s,F.anchor(s,1),F.anchor(s,2),true).size()>2,"two roads form a usable inter-colony trade route")
	var wood=s.wood
	act(m,"ship",[0,1,"wood",8])
	expect(s.wood==wood-8 and f.posts[1].wood==0,"consignment reserved on departure")
	var secs=F.route(s,0,1).time
	clock_ticks(m,secs)
	expect(f.posts[1].wood==8,"outpost receives all dispatched timber")
	act(m,"ship",[1,2,"wood",7])
	act(m,"ship",[0,2,"people",1])
	clock_ticks(m,maxi(F.route(s,1,2).time,F.route(s,0,2).time))
	expect(f.posts[1].wood==1 and f.posts[2].wood==7 and f.posts[2].people==1 and F.people_total(s)==10,"direct trade and migration conserve quantities")
	act(m,"ship",[2,0,"people",1])
	expect(F.incoming(s)==1 and m.recruit_reason()!="","homebound resident reserves a bed")
	clock_ticks(m,F.route(s,0,2).time)
	expect(s.pop==10 and f.posts[2].people==0,"return to the camp worker pool")
	f.posts[2].people=1
	F.season(m)
	expect(f.posts[2].short==1 and f.posts[2].stone==0,"isolated quarry stops production without rations")
	f.posts[2].food=1
	F.season(m)
	expect(f.posts[2].food==0 and f.posts[2].stone==2,"delivered food supports quarry workers")
	F.E.open_district(s,3)
	s.streets.clear()
	F.Roads.inherit_path(s,38,s.frontier.home)
	F.Roads.rebuild(s)
	for road in [[0,3],[3,1],[1,2]]: act(m,"road",road)
	var through=F.route(s,0,2)
	expect(through.road and s.cells[F.anchor(s,3)].connected and s.cells[F.anchor(s,1)].connected and s.cells[F.anchor(s,2)].connected,"a cart can traverse the entire four-settlement road network")

func local_production():
	var m=campaign()
	var s=m.s
	F.E.open_district(s,1)
	var post=s.frontier.posts[1]
	var site=-1
	for id in s.cells.size():
		if V.sector(id)==1 and V.tier(id)>=0 and s.cells[id].kind=="": site=id; break
	if site<0: expect(false,"outpost land available"); return
	var cash=s.food
	var wood=s.wood
	expect(m.construct("house",site)!="","remote construction requires materials on site")
	post.food=4; post.wood=4
	expect(m.construct("house",site)=="" and post.food==0 and post.wood==0,"construction draws from the local warehouse")
	expect(m.cancel_project("t"+str(site))=="" and post.food==4 and post.wood==4,"cancel returns unused stock to its original warehouse")
	expect(s.food==cash and s.wood==wood,"local projects leave central stock balanced")
	s.cells[site].kind="farm"
	post.seed=2
	s.frontier.lines["豆"]=C.line()
	C.profiles(s)
	for id in [site,73]: F.Roads.inherit_path(s,38,id)
	F.Roads.rebuild(s)
	s.cells[site].next_species="稻"
	act(m,"sow",[site,"豆"])
	m.assign("t"+str(site),1)
	m.assign("t73",1)
	for k in 40: m.work()
	expect(post.seed==1 and s.cells[site].crop and C.field_species(s,site)=="豆","empty field sows chosen crop using local seed")
	expect(post.wood>4 and s.wood==wood,"remote timber enters the outpost warehouse")
	m.harvest()
	expect(post.food>4 and post.seed==2 and s.food==cash,"harvest and seed return to the local warehouse")

func coast_and_animals():
	var m=campaign(4)
	var s=m.s
	var f=s.frontier
	act(m,"pen")
	act(m,"hens")
	act(m,"hens")
	act(m,"goats")
	expect(F.action(m,"hens",null)!="","livestock cannot exceed pen capacity")
	act(m,"feed")
	m.finish_season()
	expect(f.eggs==2 and f.milk==2 and f.manure==2 and f.feed==0,"feed turns into separate eggs, milk and manure")
	var stock=s.food
	act(m,"provision")
	expect(s.food==stock+4 and f.eggs==0 and f.milk==0 and s.ledger.livestock==4,"products enter food and ledger once")
	act(m,"pen")
	act(m,"feed")
	act(m,"brood","hens")
	s.time+=40
	F.tick(m)
	expect(f.hens==3 and f.broods.is_empty(),"paid brood reaches adulthood")
	s.cells[39].kind="farm"
	var soil=s.cells[39].soil
	act(m,"manure",39)
	expect(s.cells[39].soil==soil+10 and F.action(m,"manure",39)!="","manure feeds a real soil tile once per season")
	s.turn=3
	f.fresh=0
	var dry=F.Farm.spring_water(s)
	act(m,"well")
	var wet=F.Farm.spring_water(s)
	expect(wet.rain==dry.rain+6 and wet.short<dry.short,"coastal cistern changes the seasonal freshwater budget")
	F.season(m)
	expect(f.fresh==wet.balance and f.water_short==wet.short,"freshwater forecast matches settlement")
	f.fresh=0; f.water_short=0
	var balanced=C.field_bonus(s,39)
	f.water_short=1
	expect(C.field_bonus(s,39)==balanced-4,"only unmet water demand reduces the harvest")
	m.queue_warning("blight",39,"crop education")
	var first=f.disease.duplicate()
	m.queue_warning("blight",37,"repeat")
	expect(f.disease==first and first.tile==39 and first.crop=="稻","first plant disease creates one persistent field guide entry")

func run():
	habitats_and_lines()
	travel_and_storage()
	local_production()
	coast_and_animals()
	if failures==0: print("PASS six biomes, random birthplaces, crop discovery, breeding, mutations, saved expeditions, roads, colony migration, stocks, herds, freshwater and first disease")
	quit(0 if failures==0 else 1)
