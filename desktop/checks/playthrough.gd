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
	if label_text in ["12-harvest-detail","11-modern-valley"] and image:
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
			var spent=b.build+b.maintenance+b.advance+b.eat+b.loss+b.sow+b.spoil+b.operations+b.imports+b.recruit+b.land
			if not check(b.opening+b.gather+b.crop+b.refund+b.exports-spent==b.ending,"seasonal food ledger reconciles"): return
			var recent=sim.s.history
			if not check(recent.size()==mini(sim.s.turn,8) and recent.back()==[sim.s.turn-1,b.gather+b.crop+b.refund+b.exports,spent],"eight-season chart matches settled accounts"): return
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

func build(kind: String,id: int):
	var inputs=S.E.MATERIALS[kind]
	if sim.s.wood<inputs[0] or sim.s.stone<inputs[1]:
		await tap("panel","economy")
		await tap("economy_tab","market")
		for k in ["wood","stone"]:
			var need=inputs[0 if k=="wood" else 1]
			while sim.s[k]<need and not failed: await tap("trade",[k,true])
		await tap("closepanel")
	await tap("panel","build")
	await tap("tool",kind)
	await choose_cell(id)
	check(game.world.build_tool=="" and game.world.selected==id,"placed "+kind+" at "+str(id)+" "+game.hud.toast)

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
			await tap("transfer_from","t"+str(S.WILD[1]))
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

func learn(id: String):
	if failed: return
	await bank_notes(S.TECH[id][2])
	await tap("panel","study");await tap("research",id);await tap("closepanel")
	for i in 12:
		if sim.s.tech.has(id) or failed: break
		await ticks(1)
	check(sim.s.tech.has(id),"staff completed research "+id)

func wait_ready():
	for n in 16:
		if failed or sim.advance_reason()=="": return
		if not check(sim.s.pending=="" and sim.s.outcome=="","waiting for prerequisites "+str(sim.s.pending)): return
		if sim.s.era==2 and sim.mean_soil()<58:
			for id in sim.farms():
				var c=sim.s.cells[id]
				if c.soil<64 and c.compost!=sim.s.turn and S.Town.working(c) and sim.s.food>=2:
					await visit(id);await tap("field",[id,"compost"])
			if sim.advance_reason()=="": return
		await ticks(S.SEASON_TIME-sim.s.clock)
	check(sim.advance_reason()=="","stage prerequisites "+str([sim.s.era,sim.advance_reason(),sim.s.food,sim.s.seed,sim.s.rain,sim.mean_soil()]))

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
	await tap("difficulty",difficulty)
	if game.dialog_key=="restart": await tap("confirmed_new")
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
	await ticks(12)
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
	await tap("panel","economy");await tap("budget",0);await tap("budget",1);await capture("10-budget")
	await tap("economy_tab","market")
	var stock=sim.s.stone
	await tap("trade",["stone",true]);await tap("trade",["stone",false])
	check(sim.s.stone==stock,"dock trades are reachable in the resource overview")
	await tap("economy_tab","history");await capture("13-season-accounts");await tap("closepanel")
	await ticks(2)
	await bank_notes()
	await pay_to_advance(0)
	await learn("dike");await learn("scout")
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
	check(sim.s.cells[low].crop==(index==0),"field behind dyke keeps standing crop")
	results.append([sim.s.flood_cells.size(),sim.s.rescued,sim.s.lost])
	if index==0:
		await tap("panel","risk");await tap("overlay","")
		await ticks(4);await capture("04-high-water")
	await tap("panel","crew")
	for i in 3:
		if sim.s.seed<4: await tap("reserve",false)
	await tap("closepanel")
	await visit(34)
	await tap("site_work",["repair",34]);await finish_site(34)
	check(sim.s.cells[34].condition>=99,"paid repair restores condition")
	await pay_to_advance(1)
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
		await visit(34);await tap("site_work",["upgrade",34]);await finish_site(34)
		check(sim.s.cells[34].level==2 and S.Town.storage(sim.s)==120,"level-two warehouse increases usable capacity")
	await pay_to_advance(2)
	await ticks(S.SEASON_TIME*2)
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

func run(main,out: String):
	game=main;sim=main.sim;folder=out
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--difficulty-test="): difficulty=int(arg.trim_prefix("--difficulty-test="))
	picture=DisplayServer.get_name()!="headless"
	report("Native replay on "+DisplayServer.get_name()+" at "+str(DisplayServer.window_get_size()))
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
	await tap("claim",V.sector(outer));await tap("assign",["t73",1])
	await ticks(20)
	check(sim.s.districts.has(V.sector(outer)) and sim.s.ledger.wood_in>0,"outer sector is staffed and productive")
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
