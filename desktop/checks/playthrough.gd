extends Node

# Replays ordinary game commands through the native viewport, with an isolated save directory.
const V=preload("res://valley.gd")
const S=preload("res://simulation.gd")
var game
var sim
var folder=""
var failed=false
var low=-1
var upland=-1
var messages=[]
var picture=true
var results=[]
var difficulty=1

func check(condition: bool,description: String) -> bool:
	if failed: return false
	if not condition:
		failed=true
		report("FAIL "+description)
		get_tree().quit(2)
		return false
	return true

func report(line: String):
	print(line)
	messages.append(line)
	var output=FileAccess.open(folder.path_join("verification.txt"),FileAccess.WRITE)
	if output: output.store_string("\n".join(messages)+"\n")

func frames(count: int=2):
	for i in count: await get_tree().process_frame

func capture(label_text: String):
	if not picture or failed: return
	await frames(3)
	await RenderingServer.frame_post_draw
	var image=get_viewport().get_texture().get_image()
	check(image!=null and image.save_png(folder.path_join(label_text+".png"))==OK,"screenshot "+label_text)
	if label_text=="02-river-valley" and image:
		image.save_jpg(folder.path_join("river-valley.jpg"),0.88)
	if (label_text in ["12-harvest-detail","11-modern-valley"] or label_text.begins_with("beta-") or label_text.begins_with("formal-")) and image:
		image.save_jpg(folder.path_join(label_text+".jpg"),0.93)

func zoom_view(button: MouseButton,count: int):
	var viewport=get_viewport()
	var position=viewport.get_visible_rect().size*Vector2(0.53,0.48)
	for n in count:
		var event=InputEventMouseButton.new()
		event.button_index=button
		event.position=position
		event.global_position=position
		event.pressed=true
		viewport.push_input(event,true)
	await frames(34)

func click(pos: Vector2):
	var vp=get_viewport()
	var move=InputEventMouseMotion.new()
	move.position=pos; move.global_position=pos
	vp.push_input(move,true)
	for pressed in [true,false]:
		var event=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed; event.position=pos;event.global_position=pos
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		vp.push_input(event,true)

func tap(cmd: String,arg=null):
	if failed: return
	await frames()
	var button=game.hud.find_button(cmd,arg)
	if not check(is_instance_valid(button),"control "+cmd+" "+str(arg)+" state "+str([game.hud.panel_key,game.dialog_key,game.world.selected])): return
	var parent=button.get_parent()
	while parent and not parent is ScrollContainer: parent=parent.get_parent()
	if parent is ScrollContainer:
		parent.ensure_control_visible(button)
		await frames()
	var p=button.get_global_rect().get_center()
	if not check(get_viewport().get_visible_rect().has_point(p),"button within viewport "+cmd): return
	click(p)
	await frames()

func key(code: Key):
	for pressed in [true,false]:
		var event=InputEventKey.new()
		event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		get_viewport().push_input(event,true)
	await frames()

var route_num=0

func ticks(count: int):
	for i in count:
		if failed or game.paused: return
		var prior_turn=sim.s.turn
		game.sim_step()
		if sim.s.turn!=prior_turn:
			var b=sim.s.last_ledger
			var spent=b.build+b.maintenance+b.advance+b.eat+b.loss+b.sow+b.spoil+b.operations+b.imports+b.recruit+b.land+b.husbandry+b.explore+b.freight_out+b.research
			if not check(b.opening+b.gather+b.crop+b.refund+b.exports+b.freight_in+b.livestock-spent==b.ending,"seasonal food ledger reconciles"): return
			var recent=sim.s.history
			if not check(recent.size()==mini(sim.s.turn,8) and recent.back()==[sim.s.turn-1,b.gather+b.crop+b.refund+b.exports+b.freight_in+b.livestock,spent],"eight-season chart matches settled accounts"): return
			for k in ["wood","stone"]:
				if not check(b[k+"_open"]+b[k+"_in"]-b[k+"_out"]==sim.s[k],"seasonal "+k+" ledger reconciles"): return
			if not check(sim.s.pop==sim.s.workers.size(),"population matches available worker records"): return
		while sim.s.pending in ["birds","weeds","rain","blight"] and not failed:
			var event=sim.s.pending
			var which=route_num if event=="rain" else 0
			if sim.s.food<sim.response_cost(event,which): which=1
			if not check(sim.s.cause.has(event),"warning records its cause"): return
			await tap("decision",which)
			if sim.s.pending=="":
				await key(KEY_SPACE)
		if (i+1)%20==0: await frames(1)

func choose_cell(id: int):
	if failed: return
	game.world.focus(id)
	await frames(18)
	var position=game.world.camera.unproject_position(V.v3(V.center(id)))
	if not check(game.world.pick(position)==id,"map picking "+str(id)): return
	click(position)
	await frames(2)

func raise_food(amount: int,wood_keep: int=0,stone_keep: int=0):
	if sim.s.food>=amount or failed: return
	if game.hud.panel_key!="": await tap("closepanel")
	await tap("panel","economy");await tap("economy_tab","market")
	for n in 120:
		if sim.s.food>=amount or failed or sim.s.outcome!="" or sim.s.pending!="": break
		if sim.s.stone>=S.E.LOT.stone+stone_keep: await tap("trade",["stone",false])
		elif sim.s.wood>=S.E.LOT.wood+wood_keep: await tap("trade",["wood",false])
		elif not game.paused: await ticks(1)
		else: break
	await tap("closepanel")

func supplies(wood: int,stone: int):
	if failed or (sim.s.wood>=wood and sim.s.stone>=stone): return
	if game.hud.panel_key!="": await tap("closepanel")
	await tap("panel","economy");await tap("economy_tab","market")
	for kind in ["wood","stone"]:
		var need=wood if kind=="wood" else stone
		for attempt in 20:
			if failed or sim.s[kind]>=need: break
			if sim.s.food<5: await ticks(8)
			else: await tap("trade",[kind,true])
		if not check(sim.s[kind]>=need,"supplies available for "+kind+" "+str([sim.s.food,sim.s[kind],need])): return
	await tap("closepanel")

func pave_to(id: int):
	if failed or sim.s.cells[id].connected: return
	var start=S.Roads.root(sim.s)
	if not check(start>=0,"a road begins from a completed academy"): return
	for tile in S.Roads.path(sim.s,start,id):
		if sim.s.cells[tile].connected: start=tile
	var plan=S.Roads.quote(sim.s,start,id)
	await supplies(plan.wood,plan.stone)
	if game.hud.panel_key!="": await tap("closepanel")
	await key(KEY_G)
	await choose_cell(start);await choose_cell(id)
	if not check(sim.s.cells[id].connected,"road is connected to school at "+str(id)+" "+game.hud.toast): return
	await tap("street_end")

func build(kind: String,id: int):
	if kind!="academy" and kind!="levee" and S.Roads.root(sim.s)>=0: await pave_to(id)
	var inputs=S.E.MATERIALS[kind]
	await supplies(inputs[0],inputs[1])
	await raise_food(S.BUILD[kind][2],inputs[0],inputs[1])
	await tap("panel","build")
	await tap("tool",kind)
	await choose_cell(id)
	check(game.world.build_tool=="" and game.world.selected==id,"placed "+kind+" at "+str(id)+" "+game.hud.toast)

func maintain(kind: String,id: int):
	var inputs=S.E.MATERIALS[kind]
	await supplies(inputs[0],inputs[1])
	await raise_food(S.BUILD[kind][2],inputs[0],inputs[1])
	await visit(id)
	if not check(sim.build_reason(kind,id)=="","can "+kind+" at "+str(id)+" "+sim.build_reason(kind,id)): return
	await tap("site_work",[kind,id]);await finish_site(id)

func visit(id: int):
	await tap("panel","crew")
	await tap("jump",id)

func finish_site(id: int):
	var job="t"+str(id)
	if sim.s.cells[id].project!="" and sim.assigned(job)==0:
		await tap("panel","crew")
		if sim.free_workers()>0: await tap("fill")
		if sim.assigned(job)==0:
			await tap("transfer_to",job)
			var donor="t35" if sim.assigned("t35")>0 and difficulty==2 else "t"+str(S.WILD[1])
			await tap("transfer_from",donor)
		await tap("closepanel")
	for i in 85:
		if failed or sim.s.cells[id].project=="": break
		await ticks(1)
	check(sim.s.cells[id].project=="","completed site "+str(id)+" state "+str([sim.s.cells[id].project,sim.assigned("t"+str(id)),sim.s.pending]))

func bank_notes(required: int=0):
	if failed: return
	var ac=sim.academy_id()
	for i in 160:
		if sim.s.science+sim.s.cells[ac].notes>=required or failed: break
		await ticks(1)
	if not check(sim.s.science+sim.s.cells[ac].notes>=required,"academy produced requested knowledge"): return
	if sim.s.cells[ac].notes>0:
		await tap("panel","study");await tap("academy")
		var before=sim.s.science
		var local=sim.s.cells[ac].notes
		await tap("collect",ac)
		check(sim.s.science==before+local and sim.s.cells[ac].notes==0,"collection transfers points exactly once")

func seed_target() -> int:
	var needed=0
	for plot in sim.farms():
		var next=S.F.Crops.for_sowing(sim.s,plot)
		needed+=S.F.Crops.seed_cost(sim.s,next[0],next[1])
	return needed

func stock_seed(amount: int):
	if failed or sim.s.seed>=amount or sim.s.pending!="" or sim.s.food<2: return
	if game.hud.panel_key!="": await tap("closepanel")
	await tap("panel","crew")
	for n in 12:
		if sim.s.seed>=amount or sim.s.food<2 or failed: break
		await tap("reserve",false)
	await tap("closepanel")

func learn(id: String):
	if failed: return
	var spec=sim.techs[id]
	var price=S.Study.bill(sim.s,id,spec)
	await bank_notes(spec[2])
	await supplies(price[2],price[3])
	var desired=price[1]+seed_target()
	var missing=maxi(0,desired-sim.s.seed)
	await raise_food(price[0]+2*ceili(missing/2.0),price[2],price[3])
	await stock_seed(desired)
	await tap("panel","study")
	await tap("tech_branch",game.hud.Research.branch(sim,id))
	await tap("tech_view",id)
	if not check(sim.research_reason(id)=="","can begin research "+id+" "+sim.research_reason(id)): return
	await tap("research",id);await tap("closepanel")
	for i in 75:
		if sim.s.tech.has(id) or failed: break
		await ticks(1)
	check(sim.s.tech.has(id),"staff completed research "+id+" "+str([sim.s.pending,sim.s.outcome,sim.s.study_time]))

func install_cistern():
	await supplies(3,2)
	await tap("inventory")
	await tap("frontier_action",["well",null])
	await tap("closepanel")

func food_for_season():
	var target=sim.s.pop+S.E.budget(sim.s).total
	if failed or sim.s.pending!="" or sim.s.outcome!="" or sim.s.food>=target: return
	var seed_floor=seed_target() if sim.s.turn%4==3 else 2
	if sim.s.seed>seed_floor+1:
		await tap("panel","crew")
		while sim.s.food<target and sim.s.seed>seed_floor+1 and not failed: await tap("reserve",true)
		await tap("closepanel")
	if sim.s.food>=target: return
	await tap("panel","economy");await tap("economy_tab","market")
	for n in 12:
		if failed or sim.s.food>=target: break
		if sim.s.stone>=5: await tap("trade",["stone",false])
		elif sim.s.wood>=6: await tap("trade",["wood",false])
		else: break
	await tap("closepanel")

func extra_plot() -> int:
	var best=-1
	var score=INF
	for id in 72:
		if V.tier(id)<0 or sim.s.cells[id].kind!="" or id in [34,37,38,39,40,46,47,48]: continue
		var distance=V.distance(38,id)+(1 if V.tier(id)==0 else 0)
		if distance<score: best=id;score=distance
	return best

func wait_ready():
	for n in 20:
		if sim.s.pending=="" and sim.s.food>=sim.s.pop+3 and sim.s.turn%4 in [0,1]:
			var needed=0
			for id in sim.farms():
				var next=S.F.Crops.for_sowing(sim.s,id)
				if not sim.s.cells[id].crop: needed+=S.F.Crops.seed_cost(sim.s,next[0],next[1])
			await stock_seed(needed)
		if sim.s.era==3 and sim.s.modern_harvest and not S.Town.seed_ready(sim): await stock_seed(seed_target())
		if difficulty==2 and sim.advance_reason()=="可用口粮不足":
			await raise_food(S.Town.ERA_FOOD[sim.s.era])
		if failed or sim.advance_reason()=="": return
		if not check(sim.s.pending=="" and sim.s.outcome=="","waiting for prerequisites "+str([sim.s.pending,sim.s.end_reason,sim.s.turn,sim.s.frontier.region,sim.s.last_report])): return
		if sim.s.era==2 and sim.mean_soil()<58:
			for id in sim.farms():
				var c=sim.s.cells[id]
				if c.soil<64 and c.compost!=sim.s.turn and S.Town.working(c) and sim.s.food>=2:
					await visit(id);await tap("field",[id,"compost"])
			if sim.advance_reason()=="": return
		await ticks(maxi(0,S.SEASON_TIME-sim.s.clock-1))
		if difficulty==2: await food_for_season()
		await ticks(1)
	check(sim.advance_reason()=="","stage prerequisites "+str([sim.s.era,sim.advance_reason(),sim.s.food,sim.s.seed,sim.s.turn,sim.mean_soil(),sim.s.outcome,sim.s.last_report,sim.s.policy,sim.s.frontier.region]))

func pay_to_advance(era: int):
	if failed: return
	await wait_ready()
	if not check(sim.s.era==era and sim.s.outcome=="","stage stays under player control"): return
	await tap("panel","era");await tap("review_era")
	if era==0: await capture("07-era")
	var stock=sim.s.food
	var seeds=sim.s.seed
	await tap("back")
	if not check(sim.s.food==stock and sim.s.era==era,"cancel leaves stocks and era intact"): return
	await tap("review_era");await tap("advance",era)
	if not check(sim.s.food==stock-S.Town.ERA_FOOD[era] and sim.s.seed==seeds,"era %d payment: food %d to %d, seeds %d to %d, current era %d, dialog %s" % [era,stock,sim.s.food,seeds,sim.s.seed,sim.s.era,game.dialog_key]): return
	if era<3:
		check(sim.s.era==era+1 and sim.s.pending=="","new era does not dispatch a disaster")
		var checkpoint=game.saves.read("chapter")
		check(checkpoint.era==sim.s.era and checkpoint.food==sim.s.food,"chapter checkpoint contains paid inventory")
		check(sim.advance(era)!="" and sim.s.food==stock-S.Town.ERA_FOOD[era],"stale transition cannot debit twice")
	else: check(sim.s.outcome=="won","player confirmed modern harvest")

func first_seasons():
	await tap("new")
	await capture("08-difficulty")
	for option in OS.get_cmdline_user_args():
		if option.begins_with("--random-test-seed="): seed(int(option.trim_prefix("--random-test-seed=")))
	await tap("difficulty",difficulty)
	if game.dialog_key=="restart": await tap("confirmed_new")
	report("Campaign start: %s, camp %d" % [S.F.REGIONS[sim.s.frontier.region],sim.s.frontier.home])
	if not check(game.playing and sim.s.science==0 and game.world.selected==S.WILD[0],"new camp starts with zero technology points"): return
	for i in 3: await tap("assign",["t"+str(S.WILD[0]),1])
	check(sim.assigned("t"+str(S.WILD[0]),true)==0,"workers must travel before working")
	await tap("assign",["t"+str(S.WILD[0]),-1])
	check(sim.free_workers()==8,"unassigned worker becomes available")
	await visit(S.WILD[1])
	for i in 2: await tap("assign",["t"+str(S.WILD[1]),1])
	await tap("panel","crew")
	for i in 3: await tap("reserve",false)
	await tap("closepanel")
	await visit(18)
	await tap("assign",["t18",1])
	var food_before=sim.s.food
	var free_before=sim.free_workers()
	await build("house",46)
	await tap("cancel_project","t46")
	if not check(sim.s.cells[46].project=="" and sim.free_workers()==free_before and sim.s.food==food_before,"cancelling untouched construction returns grain and workers"): return
	await build("academy",38)
	await tap("assign",["t38",1])
	await finish_site(38)
	await pave_to(sim.s.frontier.home);await pave_to(18);await pave_to(35)
	await ticks(20)
	check(sim.s.science==0 and sim.s.cells[38].notes>=2,"notes stay at school until a player claims them")
	await capture("06-academy")
	await learn("seed")
	var inventory=sim.s.food
	await tap("panel","build");await tap("tool","farm");await choose_cell(41)
	check(game.world.build_tool=="farm" and sim.s.food==inventory,"river placement rejected without spending")
	await key(KEY_ESCAPE)
	await build("farm",low);await build("farm",upland)
	await finish_site(upland)
	await learn("dry")
	if sim.s.frontier.region==4: await install_cistern()
	await build("store",34);await build("house",46)
	await finish_site(34);await finish_site(46)
	await key(KEY_SPACE)
	var frozen=sim.s.time
	game.sim_step();check(sim.s.time==frozen,"paused clock freezes work")
	await key(KEY_3)
	check(not game.paused and game.speed==4,"4x keyboard input")
	game.testing=false;game._process(0.25);game.testing=true
	check(sim.s.time==frozen+1,"one quarter second advances a tick at 4x")
	await key(KEY_1)
	await tap("pausemenu");await tap("save")
	var manual=game.saves.read("campaign")
	check(manual.workers==sim.s.workers and manual.cells[38].lesson==sim.s.cells[38].lesson,"workers and partial lessons saved")
	await tap("pausemenu");await tap("settings");await tap("sound");await tap("sound");await tap("back");await tap("back")
	await tap("forecast")
	await capture("02-river-valley")
	await tap("deselect");await tap("fold_goals")
	await zoom_view(MOUSE_BUTTON_WHEEL_UP,6)
	check(game.world.target_zoom<11,"wheel zoom reaches individual fields")
	await capture("12-harvest-detail")
	await zoom_view(MOUSE_BUTTON_WHEEL_DOWN,6)
	await tap("fold_goals")
	await wait_ready()
	if not check(sim.s.era==0 and sim.s.pop==10,"full rations and housing do not create residents"): return
	await tap("panel","crew")
	var food=sim.s.food
	var wood=sim.s.wood
	await tap("recruit");await tap("recruit")
	if not check(sim.s.pop==12 and sim.s.food==food-12 and sim.s.wood==wood-4,"two deliberate hires cost food and timber"): return
	await tap("assign",["t35",1])
	await capture("09-workforce")
	await tap("closepanel")
	await raise_food(5)
	await tap("panel","economy");await tap("budget",0);await tap("budget",1);await capture("10-budget")
	await tap("economy_tab","market")
	var stock=sim.s.stone
	await tap("trade",["stone",true]);await tap("trade",["stone",false])
	check(sim.s.stone==stock,"dock trades are reachable in the resource overview")
	await tap("economy_tab","history");await capture("13-season-accounts");await tap("closepanel")
	await ticks(2)
	await bank_notes()
	for n in 160:
		if sim.s.turn%4==1 and sim.s.clock<6: break
		await ticks(1)
	await pay_to_advance(0)
	await learn("dike");await learn("scout")
	await stock_seed(seed_target()*2)
	for i in 240:
		if failed or sim.s.pending=="flood": break
		await ticks(1)
	if not check(sim.s.pending=="flood","seasonal summer flood warning"): return
	var common=game.saves.read("campaign")
	check(common.pending=="flood" and common.time==sim.s.time,"warning auto-saved on its own tick")
	game.saves.put("comparison",common)
	await capture("03-flood-warning")
	game.show_title();await tap("continue")
	check(sim.s.pending=="flood" and game.paused,"reload preserves unresolved event")

func route(index: int):
	if failed: return
	route_num=index
	if index==1: game.start_game(game.saves.read("comparison"))
	await tap("decision",index)
	check(game.paused and sim.s.pending=="","decision leaves time for deployment")
	if index==0: await build("levee",low)
	await key(KEY_SPACE)
	await ticks(S.SEASON_TIME-sim.s.clock)
	check(sim.s.flood_time>0 and sim.s.flood_cells.has(low)==(index==1),"placement changes flood reach")
	check(sim.s.cells[low].crop==(index==0),"field behind dyke keeps standing crop "+str([sim.s.seed,sim.s.turn,sim.s.cells[low].care,sim.s.cells[low].harvests,sim.s.frontier.region]))
	results.append([sim.s.flood_cells.size(),sim.s.rescued,sim.s.lost])
	if index==0:
		await tap("panel","risk");await tap("overlay","")
		await ticks(4);await capture("04-high-water")
	await tap("panel","crew")
	for i in 3:
		if sim.s.seed<4: await tap("reserve",false)
	await tap("closepanel")
	await maintain("repair",34)
	check(sim.s.cells[34].condition>=99,"paid repair restores condition")
	await pay_to_advance(1)
	if sim.s.frontier.region==4: await install_cistern()
	if difficulty==2:
		await tap("panel","economy");await tap("budget",0);await tap("closepanel")
	var new_field=extra_plot();await build("farm",new_field);await finish_site(new_field)
	if difficulty==2:
		var fourth=extra_plot();await build("farm",fourth);await finish_site(fourth)
	await stock_seed(seed_target())
	await learn("terrace");await learn("rotate")
	if index==0:
		await build("terrace",low);await finish_site(low)
		await build("canal",40);await finish_site(40)
		await learn("nursery")
		await build("nursery",48);await finish_site(48)
		for i in 280:
			if failed or (sim.s.policy.has("blight") and sim.s.policy.has("weeds")): break
			await ticks(1)
		check(sim.s.policy.has("blight") and sim.s.policy.has("weeds") and sim.s.era==2,"irrigation and shared nursery cause distinct crises before modern age")
	else:
		await visit(upland);await tap("field",[upland,"rotation"])
		await maintain("upgrade",34)
		check(sim.s.cells[34].level==2 and S.Town.storage(sim.s)==120,"level-two warehouse increases usable capacity")
	await pay_to_advance(2)
	for season in 2:
		await ticks(S.SEASON_TIME-sim.s.clock-1)
		if difficulty==2: await food_for_season()
		await ticks(1)
	check(not sim.s.policy.has("runoff") and sim.s.water==[0,0,0],"two modern seasons without fertilizer do not produce runoff")
	await learn("machine");await learn("precise")
	if index==0:
		await build("ditch",low);await finish_site(low)
		await learn("fertilizer")
		await visit(low);await tap("field",[low,"fertilized"])
		check(sim.s.pending=="runoff" and sim.s.cause.runoff.tile==low,"first fertilizer application raises warning at its actual site")
		game.show_title();await tap("continue")
		check(sim.s.pending=="runoff","technology warning survives restart")
		await tap("decision",0);await key(KEY_SPACE)
		await visit(low);await tap("field",[low,"precise"])
	else:
		await build("station",47);await finish_site(47)
		check(not sim.s.policy.has("blight") and not sim.s.policy.has("weeds"),"low-input route avoids undeployed technologies' hazards")
		await tap("panel","risk");await tap("overlay","")
		await visit(47)
		await zoom_view(MOUSE_BUTTON_WHEEL_UP,5)
		await capture("11-modern-valley")
		await tap("assign",["t47",-1])
		check(game.hud.staff_alerts.has(47) and game.hud.refs.vacancies.visible,"unattended machine station appears in settlement alerts")
		await tap("staff_alert");await tap("assign",["t47",1])
		check(not game.hud.staff_alerts.has(47),"assigning a replacement clears the station alert")
		await tap("closepanel")
	await pay_to_advance(3)
	if failed: return
	report("PASS route %d: %d seasons, population %d, food %d, seeds %d, downstream pollution %d, warnings %s, flooded/rescued/lost %s" % [index+1,sim.s.turn,sim.s.pop,sim.s.food,sim.s.seed,sim.s.water[2],sim.s.policy.keys(),results.back()])
	if index==0: await capture("05-victory")

func frontier_campaign():
	await tap("new");await tap("region",4);await capture("beta-start")
	await tap("difficulty",0)
	if game.dialog_key=="restart": await tap("confirmed_new")
	var s=sim.s
	if not check(s.frontier.region==4 and s.frontier.fresh==22 and V.biome==4,"chosen coastal ecosystem loads its estuary"): return
	for id in [S.WILD[0],S.WILD[1]]:
		await visit(id)
		for n in 2: await tap("assign",["t"+str(id),1])
	await build("academy",38);await finish_site(38)
	await pave_to(s.frontier.home)
	await tap("inventory")
	await tap("frontier_action",["well",null])
	await capture("beta-coast-water")
	await tap("panel","frontier");await tap("frontier_tab","探险")
	await tap("frontier_action",["survey",[1,"粟"]])
	if not check(s.pop==8 and S.F.people_total(s)==10 and sim.recruit_reason()!="","departing scouts reserve two beds"): return
	await ticks(7)
	await tap("pausemenu");await tap("save")
	game.show_title();await tap("continue")
	s=sim.s
	if not check(s.frontier.missions.size()==1 and s.frontier.region==4,"coastal voyage survives saving and loading"): return
	await ticks(25)
	if not check(s.pop==10 and s.frontier.samples["粟"]==[2,2] and 1 in s.districts,"scouts return once with two millet parents"): return
	await tap("panel","frontier");await tap("frontier_tab","种圃");await tap("atlas_crop","粟")
	await tap("frontier_action",["trial",["粟",0]])
	await tap("frontier_tab","牧场")
	for cmd in ["pen","hens","goats","feed"]: await tap("frontier_action",[cmd,null])
	await ticks(S.SEASON_TIME-s.clock)
	if not check(s.frontier.eggs==1 and s.frontier.milk==2,"coastal herd produces food"): return
	await capture("beta-herds")
	var before=s.food
	await tap("frontier_action",["provision",null])
	check(s.food==before+3,"fresh dairy and eggs turn into rations on demand")
	await tap("frontier_tab","运输")
	await tap("street_between",[0,1]);await tap("street_confirm")
	await tap("panel","frontier");await tap("frontier_tab","运输")
	await tap("load_size",false)
	await tap("frontier_action",["ship",[0,1,"people",1]])
	await tap("frontier_action",["ship",[0,1,"food",1]])
	await capture("beta-roads")
	await ticks(32)
	if not check(s.frontier.lines.has("粟") and s.frontier.posts[1].people==1 and s.frontier.posts[1].food>=1,"delivered cargo, resident and domesticated crop are usable"): return
	await tap("frontier_tab","种圃");await tap("atlas_crop","粟")
	await tap("frontier_action",["trial",["粟",1]])
	await capture("beta-crops")
	await tap("closepanel")
	await learn("seed")
	await tap("panel","crew");await tap("reserve",false);await tap("closepanel")
	await build("farm",37);await finish_site(37)
	await visit(37);await tap("frontier_action",["sow",[37,"粟"]])
	for n in 220:
		if failed or (s.cells[37].crop and S.F.Crops.field_species(s,37)=="粟"): break
		if s.seed<2 and s.food>=2 and not s.cells[37].crop: await tap("site_reserve",0)
		await ticks(1)
	if not check(s.cells[37].crop and S.F.Crops.field_species(s,37)=="粟" and s.frontier.lines["粟"].vigor==1,"bred millet is growing in a player-operated field"): return
	await visit(37);await zoom_view(MOUSE_BUTTON_WHEEL_UP,5);await capture("beta-millet-field")
	report("PASS coastal UI: region art, freshwater, scouts and saved return, two parents, milk and eggs, road, freight, migration and actual millet crop")
	game.shutdown(0)

func lesson_campaign():
	await tap("new");await tap("region",2);await tap("difficulty",0)
	if game.dialog_key=="restart": await tap("confirmed_new")
	var s=sim.s
	if not check(s.lesson_step==0 and game.hud.tech_branch=="麦","Danube starts with the wheat notebook and first task"): return
	await tap("hint")
	for n in 2: await tap("assign",["t19",1])
	await visit(42)
	for n in 2: await tap("assign",["t42",1])
	await tap("hint");await choose_cell(38);await finish_site(38)
	await tap("hint")
	if not check(game.world.build_tool=="street" and game.world.road_end==s.frontier.home,"tutorial previews a funded road to the camp"): return
	await capture("formal-street")
	await tap("street_confirm")
	await tap("hint");await tap("assign",["t38",1])
	await ticks(20);await tap("collect",38)
	await tap("hint");await tap("research","seed");await tap("closepanel");await ticks(10)
	await tap("hint");await choose_cell(39);await finish_site(39)
	await visit(39)
	if not check(not s.cells[39].connected and sim.expected_yield(39)==0,"new disconnected farm shows an operational warning"): return
	await capture("formal-offline");await tap("street_to",39);await tap("street_confirm")
	await tap("hint");await tap("site_reserve",0)
	await ticks(2)
	if not check(s.cells[39].crop and s.lesson_step==7,"live tutorial follows actual first sowing"): return
	await capture("formal-lesson")
	for n in 180:
		if s.first_crop or failed: break
		await ticks(1)
	if not check(s.lesson_step==8 or (s.first_crop and s.lesson_step==7),"first harvest reached"): return
	await ticks(1)
	if not check(s.lesson_step==8,"eight lessons completed by play"): return
	await tap("panel","study");await tap("tech_branch","农具");await tap("tech_view","drill")
	await capture("formal-almanac")
	await tap("closepanel");await tap("panel","frontier");await tap("frontier_tab","探险")
	await tap("frontier_action",["survey",[1,"稻"]]);await ticks(32)
	await tap("closepanel");await tap("panel","study");await tap("tech_branch","稻");await tap("tech_view","rice_1")
	if not check(S.Study.discovered(s,"稻") and not s.frontier.lines.has("稻"),"new crop research opens when the sample arrives"): return
	await capture("formal-new-crop");await tap("closepanel")
	await key(KEY_G);await tap("street_mode");await choose_cell(38);await choose_cell(39)
	if not check(s.cells[39].connected,"demolition waits for confirmation"): return
	await tap("street_confirm")
	if not check(not s.cells[39].connected,"removing the physical path suspends the farm"): return
	await tap("pausemenu");await tap("save");game.show_title();await tap("continue")
	if not check(sim.s.lesson_step==8 and not sim.s.cells[39].connected and S.Study.discovered(sim.s,"稻"),"tutorial, roads and curricula survive a restart"): return
	report("PASS formal tutorial, interactive paving, demolition preview, wheat research, sample discovery and persistent field state")
	game.shutdown(0)

func run(main,out: String):
	game=main;sim=main.sim;folder=out
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--difficulty-test="): difficulty=int(arg.trim_prefix("--difficulty-test="))
	picture=DisplayServer.get_name()!="headless"
	report("Native replay on "+DisplayServer.get_name()+" at "+str(DisplayServer.window_get_size()))
	if "--formal-test" in OS.get_cmdline_user_args():
		await frames(10);await lesson_campaign();return
	if "--frontier-test" in OS.get_cmdline_user_args():
		await frames(10)
		await frontier_campaign()
		return
	await frames(12);await capture("01-title")
	low=39;upland=37
	await first_seasons()
	if failed: return
	await route(0)
	if failed: return
	await route(1)
	if failed: return
	check(results[0][0]<results[1][0] and results[1][1]>results[0][1] and results[0][2]>results[1][2],"shared checkpoint gives distinct flood and transport outcomes")
	await tap("title");await tap("new");await tap("difficulty",0);await tap("confirmed_new")
	var chart=game.hud.refs.map
	var outer=73
	var position=chart.get_global_rect().position+chart.chart_point(V.center(outer))
	click(position);await frames()
	check(game.world.selected==outer and sim.capacity("t73")==0,"unclaimed map sector can be surveyed")
	await tap("claim",V.sector(outer))
	await build("academy",38);await finish_site(38);await pave_to(outer)
	await visit(outer);await tap("assign",["t73",1])
	await ticks(20)
	check(sim.s.districts.has(V.sector(outer)) and sim.s.frontier.posts[V.sector(outer)].wood>0,"outer sector is staffed and productive")
	await tap("panel","crew");await tap("transfer_to","t18");await tap("transfer_from","t73")
	check(sim.assigned("t18")==1 and sim.assigned("t73")==0,"one worker transfers directly between sites")
	await tap("closepanel")
	await ticks(6*S.SEASON_TIME)
	check(sim.s.outcome=="lost" and sim.s.science==0 and sim.s.pop<10,"shortage reduces population, famine ends game, time grants no knowledge")
	await tap("retry")
	check(sim.s.turn==0 and sim.s.food==S.E.DIFFICULTIES[0].food and sim.s.pop==10 and sim.s.outcome=="" and sim.s.districts==[0],"chapter retry restores difficulty, regions and stocks")
	if failed: return
	report("PASS comparison, difficulty %s, recruitment, workforce transfers, service budgets, expanded map, school, paid era gates, causal risks, seasonal ledgers and saves" % S.E.DIFFICULTIES[difficulty].name)
	game.shutdown(0)
