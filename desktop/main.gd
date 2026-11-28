extends Node

const Model = preload("res://simulation.gd")
const Valley = preload("res://valley.gd")
const World = preload("res://world.gd")
const Hud = preload("res://hud.gd")
const Audio = preload("res://sound.gd")
const Saves = preload("res://saves.gd")
const DebugCommands = preload("res://debug_commands.gd")
var sim = Model.new()
var world = World.new()
var hud = Hud.new()
var audio = Audio.new()
var saves = Saves.new()
var playing = false
var practicing = false
var paused = false
var speed = 1
var acc = 0.0
var edge_job = ""
var dialog_key = ""
var before_dialog = false
var start_region = 0
var difficulty = 1
var transfer_target = ""
var drag = false
var testing = false
var save_warning = ""
var qa_directory = ""
var user_settings = ConfigFile.new()

func _ready():
	get_tree().auto_accept_quit = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-output="):
			testing = true
			qa_directory = arg.trim_prefix("--test-output=")
			saves.folder = qa_directory.path_join("saves") + "/"
			DirAccess.make_dir_recursive_absolute(saves.folder)
	if not testing: saves.use_version_folder()
	add_child(world)
	world.setup(sim)
	add_child(audio)
	audio.setup()
	if not testing and user_settings.load("user://settings.cfg") == OK:
		audio.enabled = user_settings.get_value("ui", "sound", true)
		if user_settings.get_value("ui", "fullscreen", false): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var layer = CanvasLayer.new()
	add_child(layer);layer.add_child(hud)
	hud.setup(self)
	hud.action.connect(command)
	show_title()
	if testing:
		var driver = load("res://checks/playthrough.gd")
		if driver:
			var agent = driver.new()
			add_child(agent)
			agent.call_deferred("run", self, qa_directory)

func fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func show_title():
	practicing = false
	playing = false;paused = false;dialog_key = "";edge_job = "";acc = 0
	world.set_menu(true)
	hud.menu( not saves.read("campaign").is_empty())

func start_game(restored: Dictionary = {}, practice: bool = false):
	practicing = practice
	if practicing:
		sim.reset(0, 0)
		Model.Guide.setup(sim.s, true)
	elif restored.is_empty():
		sim.reset(difficulty, start_region)
	else:
		sim.restore(restored)
		difficulty = sim.s.difficulty
	if world.terrain_region != sim.s.frontier.region:
		remove_child(world);world.queue_free();world = World.new();add_child(world);world.setup(sim)
	world.road_start = -1;world.road_end = -1;world.build_tool = ""
	transfer_target = ""
	paused = false;playing = true;speed = 1;acc = 0;edge_job = "";dialog_key = ""
	world.set_menu(false)
	hud.game_view()
	if practicing:
		select(Model.WILD[0], false)
		modal("practice_intro")
	elif restored.is_empty():
		write_save("chapter");write_save("campaign")
		select(Model.WILD[0], false)
		hud.notify(Model.F.REGIONS[sim.s.frontier.region] + "已扎营。先派人去野粮采集地。")
	else: hud.notify("已恢复到" + sim.date() + "。")
	present_events()

func present_events():
	if not playing or dialog_key != "": return
	if not sim.s.incidents.is_empty():
		modal("incident")
	elif sim.s.outcome != "":
		modal("end")
	elif sim.s.pending != "":
		open_crisis()
	elif not sim.s.guide.queue.is_empty():
		modal("guide")
	elif practicing and sim.s.lesson_step >= Model.Lesson.STEPS.size():
		modal("practice_done")
	else: return
	write_save("campaign")

func write_save(slot: String) -> bool:
	if practicing: return true
	var ok = saves.put(slot, sim.s)
	if not ok:
		save_warning = "写入存档失败，可在菜单中重试。"
		hud.notify(save_warning)
	return ok

func modal(key: String):
	if dialog_key == "": before_dialog = paused
	dialog_key = key
	if playing: paused = true
	hud.dialog(key);hud.update_status()

func close_modal():
	dialog_key = ""
	hud.dialog("")
	paused = before_dialog if playing else false
	hud.update_status()

func open_crisis():
	hud.panel_key = ""
	world.build_tool = ""
	var target = sim.s.frontier.home
	if sim.s.cause.has(sim.s.pending):
		target = sim.s.cause[sim.s.pending].tile
	elif sim.s.pending in ["flood", "rain"]:
		for id in sim.farms():
			target = id
			if Valley.tier(id) == 0: break
	world.focus(target)
	world.risk = {"flood": "flood", "rain": "soil", "runoff": "water"}.get(sim.s.pending, "crop")
	world.refresh()
	audio.effect("alert")
	modal("crisis")

func select(id: int, focus: bool = false):
	world.selected = id
	edge_job = ""
	hud.panel_key = ""
	if focus: world.focus(id)
	world.refresh();hud.rebuild_details(true)

func road_begin(a: int = -1, b: int = -1):
	hud.panel_key = ""
	world.selected = -1
	world.build_tool = "street"
	world.road_start = a
	world.road_end = b
	world.removing = false
	if b >= 0: world.focus(b)

func join_site(id: int):
	var source = Model.Roads.root(sim.s)
	if source < 0:
		hud.notify("先建成农专，才有可接入的路网。")
		return
	var trail = Model.Roads.path(sim.s, source, id)
	for i in trail:
		if sim.s.cells[i].connected: source = i
	road_begin(source, id)

func road_click(id: int, confirmed: bool = false):
	if not Model.Roads.passable(sim.s, id):
		hud.notify("请选择已开通圩区的陆地。");return
	if world.road_start < 0:
		world.road_start = id
		world.road_end = -1
	else:
		if world.removing and not confirmed:
			world.road_end = id;refresh(true);return
		var why = Model.Roads.dismantle(sim.s, world.road_start, id) if world.removing else Model.Roads.build(sim.s, world.road_start, id)
		if why != "": hud.notify(why, true);return
		var preset = world.road_end >= 0
		world.road_start = id;world.road_end = -1
		if preset:
			world.build_tool = "";select(id)
		audio.effect("finish")
		hud.notify("道路已拆除，沿线岗位状态已更新。" if world.removing else "道路已铺至" + Valley.address(id) + "。")
	Model.Lesson.update(sim)
	refresh(true)

func teach():
	var s = sim.s
	match s.lesson_step:
		0: select(Model.WILD[0], true)
		1, 3: command("academy")
		2: join_site(s.frontier.home)
		4: hud.open_study("seed")
		5, 6, 7:
			var id = Model.Lesson.field(sim)
			if id < 0: command("tool", "farm")
			else: select(id, true)

func place(id: int, direction: int):
	var kind = world.build_tool
	if kind == "university" and sim.build_reason(kind, id, direction) == "":
		world.build_tool = ""
		modal("advance")
		return
	var why = sim.construct(kind, id, direction)
	if why != "":
		hud.notify(why, true);return
	world.build_tool = ""
	world.edge_shift = 0
	select(id)
	if kind == "levee": edge_job = "e" + sim.edge_for(id, direction)
	audio.effect("finish")
	hud.notify("已动工。可在右侧增派人手。")
	refresh(true)

func command(cmd: String, arg = null):
	if not playing and cmd not in ["new", "region", "difficulty", "confirmed_new", "continue", "quit", "settings", "back", "sound", "fullscreen", "practice"]: return
	if practicing and cmd in ["save", "continue", "load", "retry", "lesson_toggle", "lesson_open", "review_era", "advance"]: return
	if dialog_key == "practice_intro" and cmd not in ["practice_begin", "title"]: return
	if dialog_key == "practice_done" and cmd != "title": return
	if dialog_key == "debug_console" and cmd not in ["debug_run", "back"]: return
	if dialog_key == "incident":
		if cmd not in ["incident_confirm", "incident_defend"]: return
	elif playing:
		if sim.s.pending != "" and cmd != "decision": return
		if sim.s.outcome != "" and cmd not in ["retry", "title", "quit", "practice", "back", "debug_run"]: return
		if dialog_key == "guide" and cmd not in ["guide_next", "guide_crop"]: return
	var result = ""
	match cmd:
		"practice":
			if not playing or (practicing and dialog_key == "end"): start_game({}, true)
		"practice_begin":
			if dialog_key == "practice_intro": close_modal()
		"debug_console":
			if dialog_key in ["", "pause"]: modal("debug_console")
		"debug_run":
			if dialog_key != "debug_console": return
			var report = DebugCommands.execute(sim, str(arg), world.selected, edge_job)
			hud.record_debug(str(arg), report)
			if report.ok:
				Model.Guide.discover(sim.s)
				if sim.s.pending != "" or not sim.s.incidents.is_empty() or not sim.s.guide.queue.is_empty() or sim.s.outcome != "":
					close_modal()
		"incident_confirm", "incident_defend":
			if dialog_key != "incident": return
			if cmd == "incident_defend":
				if sim.s.incidents.front().kind != "weather": return
				result = Model.Weather.prepare(sim)
			if result == "":
				sim.s.incidents.pop_front()
				close_modal()
				write_save("campaign")
		"guide_next", "guide_crop":
			if dialog_key != "guide": return
			if cmd == "guide_crop" and sim.s.guide.queue.front() != "crop/" + str(arg): return
			Model.Guide.acknowledge(sim.s)
			close_modal()
			write_save("campaign")
			if cmd == "guide_crop": hud.open_study(Model.Study.id(arg, 0), arg)
		"read_entry":
			hud.reading_key = arg
			modal("reading")
		"archive_tab": hud.archive_tab = arg
		"archive_era": hud.archive_era = int(arg)
		"build_category": hud.build_category = arg
		"weather_prepare":
			result = Model.Weather.prepare(sim)
			if result == "": hud.notify(sim.events.back());write_save("campaign")
		"new": modal("difficulty")
		"region":
			if dialog_key != "difficulty" or int(arg) < 0 or int(arg) >= Model.F.REGIONS.size(): return
			start_region = int(arg);modal("difficulty")
		"street_start": road_begin(int(arg))
		"street_mode": world.removing = not world.removing;world.road_end = -1;world.road_start = -1
		"street_to": join_site(int(arg))
		"street_between": road_begin(Model.F.anchor(sim.s, arg[0]), Model.F.anchor(sim.s, arg[1]))
		"street_confirm": road_click(world.road_end if world.road_end >= 0 else world.hover, true)
		"street_end": world.build_tool = "";world.road_start = -1;world.road_end = -1
		"lesson_toggle": sim.s.lesson_hidden = true;hud.notify("已收起田课。按 J 可再次打开。")
		"lesson_open":
			if dialog_key != "": close_modal()
			sim.s.lesson_hidden = false;sim.s.lesson_step = 0;Model.Lesson.update(sim)
			if sim.s.lesson_step >= Model.Lesson.STEPS.size(): modal("lesson_book")
		"map_era":
			if hud.panel_key == "study" and is_instance_valid(hud.research_view):
				hud.research_view.jump_era(clampi(int(arg), 0, 3))
		"goto_tech":
			if hud.Research.MapView.visible_topic(sim, arg): hud.open_study(arg)
		"locate_study":
			if hud.Research.MapView.visible_topic(sim, sim.s.study): hud.open_study(sim.s.study)
		"study_focus":
			hud.proposed_focus = sim.s.research_record.focus
			modal("study_focus")
		"focus_preview":
			if dialog_key != "study_focus" or arg not in Model.Study.Curriculum.TRACKS: return
			hud.proposed_focus = arg
			modal("study_focus")
		"focus_confirm":
			if dialog_key != "study_focus" or arg != hud.proposed_focus: return
			result = sim.change_focus(arg)
			if result == "":
				close_modal();write_save("campaign");hud.notify(sim.events.back())
		"withdraw_study":
			if sim.s.study == arg and Model.Study.Curriculum.terms(arg) > 0: modal("withdraw_study")
		"withdraw_confirm":
			if dialog_key != "withdraw_study": return
			result = sim.cancel_trial(arg)
			if result == "": close_modal();write_save("campaign");hud.notify(sim.events.back())
		"open_crop_study":
			if arg in Model.F.Crops.NAMES and Model.Study.discovered(sim.s, arg):
				hud.open_study(Model.Study.id(arg, 0), arg)
		"frontier_tab": hud.frontier_tab = arg
		"atlas_crop": hud.atlas_crop = arg
		"load_size": hud.full_load = arg
		"freight_place":
			if arg[0]:
				if arg[1] == hud.freight_to: hud.freight_to = hud.freight_from
				hud.freight_from = arg[1]
			else:
				if arg[1] == hud.freight_from: hud.freight_from = hud.freight_to
				hud.freight_to = arg[1]
		"resource":
			world.build_tool = ""
			match arg:
				"food": hud.panel_key = "economy";hud.economy_tab = "budget"
				"seed": hud.panel_key = "frontier";hud.frontier_tab = "种圃"
				"materials": hud.panel_key = "economy";hud.economy_tab = "stocks"
				"crew": hud.panel_key = "crew"
				"science": hud.panel_key = "study"
		"inventory": hud.panel_key = "economy";hud.economy_tab = "stocks"
		"survey_map": hud.panel_key = "frontier";hud.frontier_tab = "探险"
		"shipping_map": hud.panel_key = "frontier";hud.frontier_tab = "运输";hud.freight_from = 0;hud.freight_to = arg
		"site_reserve": result = sim.reserve(false, arg)
		"field_seed":
			result = sim.field_seed(int(arg))
			if result == "": hud.notify("已按本田下茬用量封存种粮。")
		"frontier_action":
			result = Model.F.action(sim, arg[0], arg[1])
			if result == "": hud.notify(sim.s.frontier.last)
		"difficulty":
			if dialog_key != "difficulty" or int(arg) not in [0, 1, 2]: return
			difficulty = int(arg)
			if saves.read("campaign").is_empty(): start_game()
			else: modal("restart")
		"confirmed_new": start_game()
		"continue", "load", "retry":
			var saved = saves.read("chapter" if cmd == "retry" else "campaign")
			if saved.is_empty(): hud.notify("未找到可恢复的存档。")
			else:
				start_game(saved)
				if cmd == "retry": write_save("campaign")
		"quit":
			if playing: write_save("campaign")
			shutdown()
		"title":
			write_save("campaign");show_title()
		"pausemenu": modal("pause")
		"settings": modal("settings")
		"back":
			if dialog_key == "settings" and playing: modal("pause")
			else: close_modal()
		"sound", "fullscreen":
			if cmd == "sound": audio.enabled = not audio.enabled
			else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)
			if not testing:
				user_settings.set_value("ui", "sound", audio.enabled)
				user_settings.set_value("ui", "fullscreen", fullscreen())
				user_settings.save("user://settings.cfg")
			modal("settings")
		"save":
			if write_save("campaign"):
				close_modal();hud.notify("发展进度已保存。")
		"pause":
			if dialog_key == "": paused = not paused
		"speed":
			if dialog_key == "": speed = int(arg);paused = false
		"panel":
			world.build_tool = "";hud.panel_key = "" if hud.panel_key == arg else arg
			if hud.panel_key == "economy": hud.economy_tab = "budget"
		"economy_tab": hud.economy_tab = arg
		"closepanel": hud.panel_key = ""
		"staff_alert": hud.panel_key = "crew";world.build_tool = ""
		"fold_goals": hud.goals_collapsed = not hud.goals_collapsed
		"deselect": select(-1)
		"jump":
			world.build_tool = ""
			select(int(arg), true)
		"edge":
			select(sim.s.edges[arg].a, true);edge_job = "e" + arg
		"research":
			result = sim.research(arg)
			if result == "":
				hud.notify("开始研习「%s」，%s。" % [sim.tech_name(arg), sim.study_status()])
				write_save("campaign")
		"academy":
			if sim.academy_id() >= 0: select(sim.academy_id(), true)
			else:
				hud.panel_key = "";world.selected = -1;world.edge_shift = 0;world.build_tool = "academy"
		"collect":
			var before = sim.s.science
			result = sim.collect(int(arg))
			if result == "": hud.notify("在农专领取了 %d 点科技。" % (sim.s.science - before))
		"repair_edge": result = sim.repair_edge(arg)
		"cancel_project":
			result = sim.cancel_project(arg)
			if result == "":
				if edge_job != "" and not sim.s.edges.has(edge_job.substr(1)): edge_job = ""
				hud.notify(sim.events.back())
		"site_work":
			result = sim.construct(arg[0], arg[1])
			if result == "": hud.notify("施工已开始，可在此增派人员。")
		"review_era":
			result = sim.advance_reason()
			if result == "": modal("advance")
		"advance":
			if dialog_key != "advance": return
			result = sim.advance(int(arg))
			if result == "":
				close_modal()
				hud.panel_key = ""
				if sim.s.outcome == "won": modal("end")
				elif int(arg) < 3: write_save("chapter")
				else: select(sim.academy_id(), true);hud.notify("合校工程开工，派遣工人完成 96 人秒建设。")
				write_save("campaign")
				audio.effect("finish")
		"reserve":
			result = sim.reserve(arg)
			if result == "": hud.notify("口粮 %d · 种粮 %d" % [sim.s.food, sim.s.seed])
		"assign":
			result = sim.assign(arg[0], arg[1])
			var site = sim.job_tile(arg[0])
			if result == "" and arg[1] > 0 and sim.s.cells[site].kind in Model.Roads.WORKS and not sim.s.cells[site].connected: hud.notify("已派人待命，接入农专后开工。", true)
		"enroll_farmer":
			result = sim.enroll_farmer()
			if result == "": hud.notify(sim.events.back())
		"fill": hud.notify("已向缺工岗位派出 %d 人。" % sim.fill_vacancies())
		"transfer_to":
			transfer_target = arg
			hud.panel_key = "transfer"
		"transfer_from":
			result = sim.transfer(arg, transfer_target)
			if result == "":
				hud.notify("已调派 1 人前往" + sim.job_label(transfer_target) + "。")
				hud.panel_key = "crew"
		"budget":
			if int(arg) in [0, 1, 2]:
				sim.s.budget = int(arg)
				hud.notify("将在季末按新预算拨粮，供下一季使用。")
		"trade":
			result = Model.E.trade(sim.s, arg[0], arg[1])
			if result == "": hud.notify("码头换货完成，已登记收支。")
		"claim":
			result = Model.E.claim(sim.s, int(arg))
			if result == "":
				hud.notify(Valley.SECTORS[int(arg)] + "已开放。")
		"field":
			result = sim.field_action(arg[0], arg[1])
			if result == "": hud.notify("农事安排已生效。")
		"tool":
			hud.panel_key = "";edge_job = "";world.selected = -1;world.edge_shift = 0;world.build_tool = arg
		"place_here":
			world.build_tool = arg[0];place(arg[1], Valley.intake(arg[1]))
			if world.build_tool != "": world.build_tool = ""
		"overlay": world.risk = arg;hud.panel_key = ""
		"forecast":
			hud.panel_key = "weather";world.build_tool = ""
		"decision":
			if dialog_key != "crisis": return
			result = sim.decide(arg)
			if result == "":
				close_modal()
				write_save("campaign")
		"hint":
			if not sim.s.lesson_hidden and sim.s.lesson_step < Model.Lesson.STEPS.size(): teach()
			elif sim.s.era == 0:
				if sim.assigned("t" + str(Model.WILD[0])) < 2 and not sim.s.first_crop: select(Model.WILD[0], true)
				elif sim.academy_id() < 0: command("academy")
				elif not sim.s.tech.has("seed") and sim.s.science < 2: select(sim.academy_id(), true)
				elif not sim.s.tech.has("seed"): hud.open_study("seed")
				elif sim.s.seed < 2 and sim.farms().is_empty(): hud.panel_key = "crew"
				elif sim.farms().is_empty(): hud.panel_key = "build"
				else: hud.panel_key = "era"
			else: hud.panel_key = "era"
	if result != "": hud.notify(result, true)
	if playing:
		Model.Lesson.update(sim)
		present_events()
		refresh(true)
	if cmd not in ["sound", "quit", "decision"]: audio.effect("click")

func refresh(force: bool = false):
	world.refresh()
	hud.update_status()
	hud.rebuild_details(force)

func sim_step():
	if not playing or paused or dialog_key != "": return
	var turn = sim.s.turn
	sim.tick()
	if practicing: Model.Lesson.update(sim)
	if not sim.events.is_empty():
		hud.notify(sim.events.back())
		sim.events.clear()
	if turn != sim.s.turn:
		sim.s.rev += 1
		write_save("campaign")
	if sim.s.outcome != "": audio.effect("finish")
	present_events()
	refresh()

func _process(dt: float):
	if not is_instance_valid(hud.stage): return
	if hud.toast_time > 0:
		hud.toast_time -= dt
		if hud.toast_time <= 0: hud.update_status()
	if playing and not paused and dialog_key == "" and not testing:
		acc += minf(dt, 0.5) * speed
		while acc >= 1.0 and not paused:
			acc -= 1.0
			sim_step()
		if paused: acc = minf(acc, 0.99)
	if playing and dialog_key == "" and not testing:
		var move = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		pan_view(move, dt)
	world.advance_frame(dt, acc)
	audio.update_weather(playing and world.target_atmosphere > 0.5)

func pan_view(direction: Vector2, dt: float):
	if direction == Vector2.ZERO: return
	if hud.panel_key == "study":
		if is_instance_valid(hud.research_view): hud.research_view.pan_keyboard(direction, dt)
		return
	world.pan(direction * dt * world.zoom * 0.64)

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed: drag = false
	if not playing or not event is InputEventKey or not event.pressed: return
	if dialog_key not in ["", "pause", "debug_console"]: return
	var toggle_console = event.physical_keycode == KEY_QUOTELEFT or event.keycode in [KEY_QUOTELEFT, KEY_ASCIITILDE]
	var close_console = dialog_key == "debug_console" and event.keycode == KEY_ESCAPE
	if not toggle_console and not close_console: return
	get_viewport().set_input_as_handled()
	if event.echo: return
	command("back" if dialog_key == "debug_console" else "debug_console")

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if dialog_key in ["crisis", "end", "incident", "guide", "practice_intro", "practice_done"]: return
			if dialog_key != "": command("back")
			elif playing:
				if world.build_tool != "": world.build_tool = "";refresh(true)
				elif hud.panel_key != "": command("closepanel")
				else: command("pausemenu")
		elif playing and dialog_key == "":
			match event.keycode:
				KEY_SPACE: command("pause")
				KEY_G: command("street_start", -1)
				KEY_T: command("panel", "study")
				KEY_B: command("panel", "build")
				KEY_J: command("lesson_open")
				KEY_1: command("speed", 1)
				KEY_2: command("speed", 2)
				KEY_3: command("speed", 4)
				KEY_R:
					if world.build_tool == "levee":
						world.edge_shift = (world.edge_shift + 1) % 6;refresh()
		return
	if not playing or dialog_key != "" or hud.panel_key == "study": return
	if event is InputEventMouseMotion:
		if drag: world.pan( - event.relative * world.zoom / get_viewport().get_visible_rect().size.y)
		var id = world.pick(event.position)
		if id != world.hover:
			world.hover = id;world.refresh();hud.update_status()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE: drag = true
			MOUSE_BUTTON_WHEEL_UP: world.wheel(-1)
			MOUSE_BUTTON_WHEEL_DOWN: world.wheel(1)
			MOUSE_BUTTON_RIGHT:
				world.build_tool = "";hud.panel_key = "";select(-1);refresh(true)
			MOUSE_BUTTON_LEFT:
				var id = world.pick(event.position)
				if id < 0: return
				if world.build_tool == "street": road_click(id)
				elif world.build_tool != "": place(id, posmod(Valley.intake(id) + world.edge_shift, 6))
				else: select(id)

func _notification(what: int):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if playing: write_save("campaign")
		shutdown()

func shutdown(code: int = 0):
	set_process(false)
	audio.silence()
	await get_tree().create_timer(0.22).timeout
	get_tree().quit(code)
