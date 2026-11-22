extends SceneTree

const Model=preload("res://simulation.gd")
const Town=preload("res://settlement.gd")
const Saves=preload("res://saves.gd")
const E=preload("res://economy.gd")
const V=preload("res://valley.gd")

var failures=0

func _initialize():
	call_deferred("run")

func expect(value: bool, message: String) -> bool:
	if not value:
		printerr("FAIL "+message)
		failures+=1
	return value

func population():
	var m=Model.new()
	for season in 3:
		m.s.food=30
		m.finish_season()
	expect(m.s.pop==10 and m.recruit()!="","recruitment checks bed limit")
	m.s.cells[46].kind="house"
	m.s.happiness=35
	for season in 2:
		m.s.food=30
		m.finish_season()
	expect(m.s.pop==10,"waiting does not recruit")
	m.s.happiness=62
	for season in 2:
		m.s.food=30
		m.finish_season()
	expect(m.s.pop==10,"surplus and spare beds alone never create people")
	var food=m.s.food
	var wood=m.s.wood
	expect(m.recruit()=="" and m.s.food==food-E.HIRE_FOOD and m.s.wood==wood-E.HIRE_WOOD,"recruitment charges exactly once")
	expect(m.s.pop==11 and m.free_workers()==11,"recruited resident can work immediately")
	for season in 2:
		m.s.food=1
		m.finish_season()
	expect(m.s.pop==10 and m.s.outcome=="","two partial shortages lose a resident")
	m.s.food=0
	m.finish_season()
	m.s.food=1
	m.finish_season()
	expect(m.s.empty==0 and m.s.outcome=="","serving food interrupts a total famine")
	m.s.organization=1
	m.s.food=1
	m.finish_season()
	expect(m.s.outcome=="lost" and m.s.end_reason.contains("组织"),"loss records disbandment")
	m.reset()
	m.s.workers.resize(1)
	m.s.pop=1
	m.s.food=0
	m.finish_season()
	m.finish_season()
	expect(m.s.pop==0 and m.s.end_reason.contains("人口"),"last resident leaves")

func construction():
	var m=Model.new()
	expect(m.construct("house",46)=="","house project started")
	for tick in 12:
		if m.s.cells[46].done>=3: break
		m.tick()
	m.s.clock=Model.SEASON_TIME-1
	m.tick()
	var done=m.s.cells[46].done
	var refund=m.project_refund("house",done)
	expect(done>0 and refund>0 and refund<Model.BUILD.house[2],"partially worked project has a partial refund")
	var before=m.s.food
	expect(m.cancel_project("t46")=="" and m.s.food==before+refund,"cancel credits unused current-season grain")
	expect(m.s.last_ledger.build==4 and m.s.ledger.refund==refund,"refund balances across a season boundary")
	expect(m.cancel_project("t46")!="" and m.s.food==before+refund and m.free_workers()==10,"refund cannot be claimed twice")
	m.s.cells[40].kind="canal"
	expect(not Town.covered(m.s,39,"canal") and m.vacancies().has("t40"),"unattended canal raises a staffing alert and supplies no water")
	expect(m.fill_vacancies()==1 and not m.vacancies().has("t40"),"automatic assignment uses one idle worker")
	for tick in 10: m.work()
	expect(Town.covered(m.s,39,"canal") and not Town.covered(m.s,38,"canal"),"level-one canal covers one hex")
	m.s.cells[40].level=2
	expect(Town.covered(m.s,38,"canal"),"level-two canal reaches a second hex")
	m.s.cells[40].condition=49
	expect(not Town.covered(m.s,39,"canal") and m.construct("repair",40)=="","damaged canal needs repair")
	for tick in 20: m.tick()
	expect(m.s.cells[40].condition==100 and Town.covered(m.s,38,"canal"),"repair restores previous service range")

func advancement():
	var m=Model.new()
	m.s.first_crop=true
	m.s.winter=true
	m.s.seed=16
	m.s.food=12
	m.s.tech=["seed","dry"]
	m.s.cells[39].kind="farm"
	m.s.cells[38].kind="academy"
	expect(m.advance(0)!="" and m.s.food==12,"required warehouse blocks the transition")
	m.s.cells[34].kind="store"
	m.s.tech.erase("dry")
	expect(m.advance(0)!="" and m.s.era==0,"core research is required independently of construction")
	m.s.tech.append("dry")
	m.s.food=11
	expect(m.advance(0)!="" and m.s.seed==16 and m.s.food==11,"reserved seed cannot pay a food shortfall")
	m.s.food=12
	expect(m.advance_reason()=="" and m.s.era==0,"eligible settlement stays in its era")
	expect(m.advance(0)=="" and m.s.era==1 and m.s.food==0 and m.s.seed==16,"confirmation spends exactly twelve food")
	expect(m.advance(0)!="" and m.s.pending=="","stale confirmation cannot advance or create a hazard")

func modern_fields():
	var m=Model.new()
	m.s.era=3
	m.s.tech=["nursery","fertilizer"]
	var local_field=m.s.cells[39]
	var other_field=m.s.cells[37]
	local_field.kind="farm"
	other_field.kind="farm"
	other_field.crop=true
	m.s.sick=true
	m.s.cause.blight={"tile":39,"why":"test"}
	m.harvest()
	expect(m.s.sick and not m.s.modern_harvest,"a distant traditional harvest cannot resolve a local outbreak or count as modern")
	expect(m.field_action(39,"fertilized")=="" and m.s.pending=="runoff","fertilizing the first field issues a warning")
	m.decide(1)
	local_field.crop=true
	m.harvest()
	expect(m.s.after_blight and not m.s.sick and m.s.modern_harvest,"affected field returns to production using modern technology")
	for season in 4: m.water_step()
	expect(local_field.pollution>0 and other_field.pollution==0 and m.s.water[2]>0,"high inputs lower local land quality and reach downstream")
	m.field_action(39,"fertilized")
	local_field.ditch=true
	var previous=local_field.pollution
	m.water_step()
	expect(local_field.pollution<previous,"ending high inputs and filtering tailwater reduces field pollution")

func legacy(path: String, output: String):
	var source=Saves.new()
	source.folder=path.get_base_dir()+"/"
	var sha=FileAccess.get_sha256(path)
	var old=source.read(path.get_file().get_basename())
	if not expect(old.get("version",0) in [1,2,3],"read an earlier release save"): return
	var m=Model.new()
	m.restore(old.duplicate(true))
	for key in ["turn","era","clock","food","seed","tech","study","study_time","science","workers","pending","policy"]:
		expect(m.s[key]==old[key],"old save preserves "+key)
	expect(m.s.version==4 and m.s.difficulty==1 and m.s.cells.size()==180 and m.s.cells[0].has("condition"),"legacy campaign expands into the standard economy")
	for i in old.cells.size():
		if old.cells[i].kind!="" or old.cells[i].project!="":
			expect(old.cells[i].kind==m.s.cells[i].kind and old.cells[i].project==m.s.cells[i].project,"existing sites retain IDs")
	var target=Saves.new()
	target.folder=output.path_join("migrated")+"/"
	if not expect(DirAccess.make_dir_recursive_absolute(target.folder)==OK,"isolated migration output"): return
	expect(target.put("chapter",m.s) and target.put("campaign",m.s),"write upgraded save and checkpoint")
	var from_disk=Saves.new()
	from_disk.folder=target.folder
	expect(from_disk.read("campaign")==m.s and from_disk.read("chapter")==m.s,"upgraded save and checkpoint round-trip")
	if m.s.pending!="": m.decide(1)
	var turn=m.s.turn
	for tick in Model.SEASON_TIME:
		if m.s.outcome!="": break
		if m.s.pending!="": m.decide(1)
		m.tick()
	expect(old.outcome!="" or m.s.turn>turn,"restored campaign plays into the next season")
	expect(FileAccess.get_sha256(path)==sha,"original save file preserved")
	if failures==0: print("PASS version %d save round-trip, expanded map, checkpoint and continued play" % old.version)

func budget_and_land():
	var m=Model.new()
	var food=[]
	var fees=[]
	var yields=[]
	for i in E.DIFFICULTIES.size():
		m.reset(i)
		food.append(m.s.food)
		m.s.cells[39].kind="farm"
		m.s.era=3
		fees.append(E.budget(m.s).total)
		yields.append(m.expected_yield(39))
	expect(food[0]>food[1] and food[1]>food[2] and fees[0]<fees[1] and fees[1]<fees[2] and yields[0]>yields[1] and yields[1]>yields[2],"difficulty affects starting supplies, recurring costs and actual crop yields")
	m.reset()
	m.s.cells[39].kind="farm"
	var previous_yield=0
	var previous_fee=-1
	for era in 4:
		m.s.era=era
		expect(m.expected_yield(39)>previous_yield and E.budget(m.s).total>previous_fee,"each era increases production and operating obligations")
		previous_yield=m.expected_yield(39)
		previous_fee=E.budget(m.s).total
	m.s.budget=0
	var low=E.budget(m.s).total
	m.s.budget=2
	expect(E.budget(m.s).total>low and m.s.efficiency==100,"choosing a budget previews its cost without granting the benefit early")
	m.finish_season()
	expect(m.s.efficiency==115 and m.s.last_ledger.operations==m.s.last_ledger.due,"funded services improve next season")
	m.s.food=m.s.pop
	m.finish_season()
	expect(m.s.food==0 and m.s.last_ledger.eat==m.s.pop and m.s.last_ledger.operations==0 and m.s.efficiency<85,"rations take priority and underfunding reduces service")
	m.reset()
	var due=E.budget(m.s).total
	expect(E.claim(m.s,1)=="" and m.s.districts.has(1) and E.budget(m.s).total>due,"land joins the permanent operating budget")
	var balance=m.s.food
	expect(E.claim(m.s,1)!="" and m.s.food==balance,"duplicate land claims are free of side effects")
	var wood=m.s.wood
	E.trade(m.s,"wood",true)
	expect(m.s.wood==wood+4 and m.s.food==balance-5,"market purchases exchange stored goods")
	E.trade(m.s,"wood",false)
	expect(m.s.wood==wood and m.s.food==balance-3,"trade spread prevents creating food from a round trip")
	for i in V.COLS*V.ROWS:
		var pos=V.grid(i)
		expect(V.id_at(pos.x,pos.y)==i and V.cell_at(V.center(i))==i,"expanded map index and picking agree")
		for d in 6:
			var neighbour=V.nb(i,d)
			if neighbour>=0: expect(V.nb(neighbour,d+3)==i and V.distance(i,neighbour)==1,"district boundaries preserve hex adjacency")
	for i in E.DEPOSITS: expect(V.tier(i)>=0,"supply site is on land")

func run():
	population()
	construction()
	advancement()
	modern_fields()
	budget_and_land()
	var path=""
	var output=OS.get_cache_dir().path_join("RiceByTheRiver-checks")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy-file="): path=arg.trim_prefix("--legacy-file=")
		if arg.begins_with("--test-output="): output=arg.trim_prefix("--test-output=")
	if path!="": legacy(path,output)
	if failures==0: print("PASS recruitment, staffing, budgets, supplies, map adjacency, difficulty, era prerequisites and modern field outcomes")
	quit(0 if failures==0 else 1)
