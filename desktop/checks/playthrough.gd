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

func ticks(count: int):
	for i in count:
		if failed or game.paused: return
		game.sim_step()
		if (i+1)%20==0: await frames(1)

func wait_event(event: String):
	for n in 28:
		if sim.s.pending!="": break
		await ticks(40)
	check(sim.s.pending==event,"expected crisis "+event+" received "+sim.s.pending)

func wait_era(era: int):
	for n in 30:
		if sim.s.era==era or failed: break
		if not check(sim.s.pending=="" and sim.s.outcome=="","blocked reaching era "+str(era)): return
		await ticks(S.SEASON_TIME-sim.s.clock)
	check(sim.s.era==era,"entered era "+str(era)+" date "+sim.date()+" goals "+str(sim.goals()))

func choose_cell(id: int):
	if failed: return
	await frames(2)
	var position=game.world.camera.unproject_position(V.v3(V.center(id)))
	if not check(game.world.pick(position)==id,"map picking "+str(id)): return
	click(position)
	await frames(2)

func build(type: String,id: int):
	await tap("panel","build")
	await tap("tool",type)
	await choose_cell(id)
	check(game.world.build_tool=="","placed "+type+" at "+str(id)+" / "+game.hud.toast)

func learn(id: String):
	await tap("panel","study")
	await tap("research",id)
	await tap("closepanel")
	await ticks(8)
	check(sim.s.tech.has(id),"researched "+id)

func first_seasons():
	await tap("new")
	if game.dialog_key=="restart": await tap("confirmed_new")
	if not check(game.playing and game.world.selected==S.WILD[0],"started game"): return
	await tap("assign",["t"+str(S.WILD[0]),1])
	await tap("assign",["t"+str(S.WILD[0]),1])
	await tap("assign",["t"+str(S.WILD[0]),1])
	check(sim.assigned("t"+str(S.WILD[0]),true)==0,"assigned workers first travel to gathering site")
	await tap("assign",["t"+str(S.WILD[0]),-1])
	check(sim.free_workers()==8,"removed worker returns to the available pool")
	await tap("assign",["t"+str(S.WILD[0]),1])
	await tap("panel","crew")
	for i in 3: await tap("reserve",false)
	await tap("closepanel")
	await learn("seed")
	check(sim.s.food>=24 and sim.s.seed==6,"opening grain reserve")
	var water_id=-1
	for i in sim.s.cells.size():
		if V.tier(i)<0 and absi(i-40)<12: water_id=i;break
	var inventory=sim.s.food
	await tap("panel","build");await tap("tool","farm");await choose_cell(water_id)
	check(game.world.build_tool=="farm" and sim.s.food==inventory,"rejected river construction spends nothing")
	await key(KEY_ESCAPE)
	await build("farm",low)
	await tap("assign",["t"+str(low),1])
	await build("farm",upland)
	await ticks(24)
	check(sim.s.cells[low].crop and sim.s.cells[upland].crop,"two planted fields")
	await key(KEY_SPACE)
	var frozen=sim.s.time
	game.sim_step()
	check(sim.s.time==frozen,"pause freezes production and seasonal clock")
	await key(KEY_3)
	check(not game.paused and game.speed==4,"keyboard four-times speed")
	game.testing=false
	game._process(0.25)
	game.testing=true
	check(sim.s.time==frozen+1,"4x advances a simulation second per quarter second")
	await key(KEY_1)
	await ticks(S.SEASON_TIME-sim.s.clock)
	await learn("dry")
	await build("store",40 if V.tier(40)>0 else 34)
	await ticks(20)
	await tap("pausemenu")
	await tap("save")
	var manual=game.saves.read("campaign")
	check(manual.time==sim.s.time and manual.workers==sim.s.workers,"manual save preserves workers in transit")
	await tap("pausemenu");await tap("settings");await tap("sound");await tap("sound");await tap("back");await tap("back")
	await tap("forecast")
	await frames(5)
	await capture("02-river-valley")
	await wait_era(1)
	await learn("dike")
	await wait_event("flood")
	var snapshot=game.saves.read("campaign")
	check(snapshot.pending=="flood" and snapshot.time==sim.s.time,"pending crisis autosaved at exact tick")
	game.saves.put("comparison",snapshot)
	await capture("03-flood-warning")
	game.show_title()
	await tap("continue")
	check(sim.s.pending=="flood" and game.paused,"continued into same pending flood")

func route(index: int):
	if failed: return
	if index==1: game.start_game(game.saves.read("comparison"))
	await tap("decision",index)
	check(game.paused and sim.s.pending=="","planning time after decision")
	var before=sim.s.time
	game.sim_step();check(sim.s.time==before,"decision does not advance time")
	if index==0: await build("levee",low)
	await key(KEY_SPACE)
	await ticks(S.SEASON_TIME)
	check(sim.s.flood_time>0 and sim.s.flood_cells.has(low)==(index==1),"levee changes flood reach")
	check(sim.s.cells[low].crop==(index==0),"protected crop survives while flooded crop needs resowing")
	results.append([sim.s.flood_cells.size(),sim.s.rescued,sim.s.lost])
	if index==0:
		await tap("panel","risk");await tap("overlay","")
		await ticks(4)
		await capture("04-high-water")
	var owned_seed=sim.s.seed
	if owned_seed<4:
		await tap("panel","crew")
		while sim.s.seed<4 and not failed: await tap("reserve",false)
		await tap("closepanel")
	await wait_era(2)
	if index==0:
		await learn("terrace");await build("terrace",low)
	else:
		await learn("rotate")
		await tap("panel","crew");await tap("jump",upland)
		await tap("field",[upland,"rotation"])
	await wait_event("rain")
	await tap("decision",index)
	await key(KEY_SPACE)
	await wait_era(3)
	if index==0:
		await learn("precise");await tap("panel","crew");await tap("jump",low);await tap("field",[low,"precise"])
	else:
		await learn("machine")
		var site=-1
		for i in [38,39,32,34,35,29,30]:
			if sim.build_reason("station",i)=="": site=i;break
		if not check(site>=0,"available machine station site"): return
		await build("station",site)
	await wait_event("runoff")
	await tap("decision",0)
	await key(KEY_SPACE)
	await wait_event("blight")
	await tap("decision",index)
	await key(KEY_SPACE)
	for n in 24:
		if sim.s.outcome!="" or failed: break
		await ticks(S.SEASON_TIME-sim.s.clock)
	check(sim.s.outcome=="won","won route "+str(index)+" goals "+str(sim.goals()))
	if failed: return
	report("PASS route %d, seasons %d, food %d, seed %d, downstream pollution %d, inundated/saved/lost %s" % [index+1,sim.s.turn,sim.s.food,sim.s.seed,sim.s.water[2],results.back()])
	if index==0: await capture("05-victory")

func run(main,out: String):
	game=main;sim=main.sim;folder=out
	picture=DisplayServer.get_name()!="headless"
	report("Native UI verification, display "+DisplayServer.get_name()+" viewport "+str(get_viewport().get_visible_rect().size))
	await frames(16)
	await capture("01-title")
	for i in [38,39,30,31,47,48,32,41]:
		if sim.flood_map().has(i) and sim.s.cells[i].kind=="": low=i;break
	for i in [37,46,34,29,35,28,36,43]:
		if V.tier(i)>0 and sim.s.cells[i].kind=="": upland=i;break
	if not check(low>=0 and upland>=0,"found lower and upper farmland"): return
	await first_seasons()
	if failed: return
	await route(0)
	if failed: return
	await route(1)
	if failed: return
	check(results[0][0]<results[1][0] and results[1][1]>results[0][1] and results[1][2]<results[0][2],"same checkpoint gives distinct land and seed outcomes")
	await tap("title")
	await tap("new");await tap("confirmed_new")
	await ticks(6*S.SEASON_TIME)
	check(sim.s.outcome=="lost","two seasons without food cause loss")
	await tap("retry")
	check(sim.s.turn==0 and sim.s.food==30 and sim.s.outcome=="","chapter retry restores starting stocks")
	if failed: return
	report("PASS comparison, pause/speed, crisis reload, famine, chapter retry and native mouse input")
	game.shutdown(0)
