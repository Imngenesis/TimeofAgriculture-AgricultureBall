extends Node

const Model=preload("res://simulation.gd")
const Valley=preload("res://valley.gd")
const World=preload("res://world.gd")
const Hud=preload("res://hud.gd")
const Audio=preload("res://sound.gd")
const Saves=preload("res://saves.gd")
var sim=Model.new()
var world=World.new()
var hud=Hud.new()
var audio=Audio.new()
var saves=Saves.new()
var playing=false
var paused=false
var speed=1
var acc=0.0
var edge_job=""
var dialog_key=""
var before_dialog=false
var drag=false
var testing=false
var save_warning=""
var qa_directory=""
var user_settings=ConfigFile.new()

func _ready():
	get_tree().auto_accept_quit=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-output="):
			testing=true
			qa_directory=arg.trim_prefix("--test-output=")
			saves.folder=qa_directory.path_join("saves")+"/"
			DirAccess.make_dir_recursive_absolute(saves.folder)
	add_child(world)
	world.setup(sim)
	add_child(audio)
	audio.setup()
	if not testing and user_settings.load("user://settings.cfg")==OK:
		audio.enabled=user_settings.get_value("ui","sound",true)
		if user_settings.get_value("ui","fullscreen",false): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var layer=CanvasLayer.new()
	add_child(layer);layer.add_child(hud)
	hud.setup(self)
	hud.action.connect(command)
	show_title()
	if testing:
		var driver=load("res://checks/playthrough.gd")
		if driver:
			var agent=driver.new()
			add_child(agent)
			agent.call_deferred("run",self,qa_directory)

func fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func show_title():
	playing=false;paused=false;dialog_key="";edge_job="";acc=0
	world.set_menu(true)
	hud.menu(not saves.read("campaign").is_empty())

func start_game(restored: Dictionary={}):
	if restored.is_empty(): sim.reset()
	else: sim.s=restored;sim.events.clear()
	paused=false;playing=true;speed=1;acc=0;edge_job="";dialog_key=""
	world.set_menu(false)
	hud.game_view()
	if restored.is_empty():
		write_save("chapter");write_save("campaign")
		select( Model.WILD[0],false)
		hud.notify("点击右侧「＋」，先派两人采集野粮。")
	elif sim.s.pending!="": open_crisis()
	elif sim.s.outcome!="": modal("end")
	else: hud.notify("已恢复到"+sim.date()+"。")

func write_save(slot: String) -> bool:
	var ok=saves.put(slot,sim.s)
	if not ok:
		save_warning="写入存档失败，可在菜单中重试。"
		hud.notify(save_warning)
	return ok

func modal(key: String):
	if dialog_key=="": before_dialog=paused
	dialog_key=key
	if playing: paused=true
	hud.dialog(key);hud.update_status()

func close_modal():
	dialog_key=""
	hud.dialog("")
	paused=before_dialog if playing else false
	hud.update_status()

func open_crisis():
	hud.panel_key=""
	world.build_tool=""
	var target=Model.HOME
	for id in sim.farms():
		target=id
		if Valley.tier(id)==0: break
	world.focus(target)
	world.risk={"flood":"flood","rain":"soil","runoff":"water","blight":""}.get(sim.s.pending,"")
	world.refresh()
	audio.effect("alert")
	modal("crisis")

func select(id: int,focus: bool=false):
	world.selected=id
	edge_job=""
	hud.panel_key=""
	if focus: world.focus(id)
	world.refresh();hud.rebuild_details(true)

func place(id: int,direction: int):
	var kind=world.build_tool
	var why=sim.construct(kind,id,direction)
	if why!="":
		hud.notify(why);return
	world.build_tool=""
	world.edge_shift=0
	select(id)
	if kind=="levee": edge_job="e"+sim.edge_for(id,direction)
	audio.effect("finish")
	hud.notify("已动工。可在右侧增派人手。")
	refresh(true)

func command(cmd: String,arg=null):
	if cmd not in ["new","confirmed_new","continue","quit","settings","back","sound","fullscreen"] and not playing: return
	if playing and sim.s.pending!="" and cmd!="decision": return
	if playing and sim.s.outcome!="" and cmd not in ["retry","title","quit"]: return
	var result=""
	match cmd:
		"new":
			if saves.read("campaign").is_empty(): start_game()
			else: modal("restart")
		"confirmed_new": start_game()
		"continue","load","retry":
			var saved=saves.read("chapter" if cmd=="retry" else "campaign")
			if saved.is_empty(): hud.notify("未找到可恢复的存档。")
			else:
				start_game(saved)
				if cmd=="retry": write_save("campaign")
		"quit":
			if playing: write_save("campaign")
			shutdown()
		"title":
			write_save("campaign");show_title()
		"pausemenu": modal("pause")
		"settings": modal("settings")
		"back":
			if dialog_key=="settings" and playing: modal("pause")
			else: close_modal()
		"sound","fullscreen":
			if cmd=="sound": audio.enabled=not audio.enabled
			else: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)
			if not testing:
				user_settings.set_value("ui","sound",audio.enabled)
				user_settings.set_value("ui","fullscreen",fullscreen())
				user_settings.save("user://settings.cfg")
			modal("settings")
		"save":
			if write_save("campaign"):
				close_modal();hud.notify("战役进度已保存。")
		"pause":
			if dialog_key=="": paused=not paused
		"speed":
			if dialog_key=="": speed=int(arg);paused=false
		"panel":
			world.build_tool="";hud.panel_key="" if hud.panel_key==arg else arg
		"closepanel": hud.panel_key=""
		"deselect": select(-1)
		"jump": select(int(arg),true)
		"edge":
			select(sim.s.edges[arg].a,true);edge_job="e"+arg
		"research":
			result=sim.research(arg)
			if result=="": hud.notify("开始研习「"+Model.TECH[arg][0]+"」，需要 8 秒。")
		"reserve":
			result=sim.reserve(arg)
			if result=="": hud.notify("口粮 %d · 种粮 %d" % [sim.s.food,sim.s.seed])
		"assign": result=sim.assign(arg[0],arg[1])
		"field":
			result=sim.field_action(arg[0],arg[1])
			if result=="": hud.notify("农事安排已生效。")
		"tool":
			hud.panel_key="";edge_job="";world.selected=-1;world.edge_shift=0;world.build_tool=arg
		"place_here":
			world.build_tool=arg[0];place(arg[1],Valley.intake(arg[1]))
			if world.build_tool!="": world.build_tool=""
		"overlay": world.risk=arg;hud.panel_key=""
		"forecast":
			var at_risk=sim.farms()
			var target=Model.WILD[0] if at_risk.is_empty() else at_risk[0]
			if sim.s.era==1:
				world.risk="flood"
				for id in sim.flood_map():
					if at_risk.has(id) or at_risk.is_empty():
						target=id;break
			elif sim.s.era==2: world.risk="soil"
			elif sim.s.era==3:
				world.risk="water"
				for id in sim.s.cells.size():
					if Valley.reach(id)==2 and Valley.tier(id)<0: target=id;break
			select(target,true)
		"decision":
			result=sim.decide(arg)
			if result=="":
				dialog_key="";hud.dialog("");paused=true
				write_save("campaign")
				hud.notify("部署完毕后，按空格让时间继续。")
		"hint":
			if sim.s.era==0:
				if sim.assigned("t"+str(Model.WILD[0]))<2 and not sim.s.first_crop: select(Model.WILD[0],true)
				elif not sim.s.tech.has("seed"): hud.panel_key="study"
				elif sim.s.seed<2 and sim.farms().is_empty(): hud.panel_key="crew"
				elif sim.farms().is_empty(): hud.panel_key="build"
				else: select(sim.farms()[0],true)
			elif sim.s.era==1: world.risk="flood";hud.panel_key="build" if sim.s.tech.has("dike") else "study"
			elif sim.s.era in [2,3]: hud.panel_key="study"
	if result!="": hud.notify(result)
	if playing: refresh(true)
	if cmd not in ["sound","quit","decision"]: audio.effect("click")

func refresh(force: bool=false):
	world.refresh()
	hud.update_status()
	hud.rebuild_details(force)

func sim_step():
	if not playing or paused or dialog_key!="": return
	var era=sim.s.era
	var turn=sim.s.turn
	sim.tick()
	if not sim.events.is_empty():
		hud.notify(sim.events.back())
		sim.events.clear()
	if turn!=sim.s.turn:
		sim.s.rev+=1
		if era!=sim.s.era:
			write_save("chapter");audio.effect("finish")
		write_save("campaign")
	if sim.s.pending!="": open_crisis()
	elif sim.s.outcome!="": audio.effect("finish");modal("end")
	refresh()

func _process(dt: float):
	if not is_instance_valid(hud.stage): return
	if hud.toast_time>0:
		hud.toast_time-=dt
		if hud.toast_time<=0: hud.update_status()
	if playing and not paused and dialog_key=="" and not testing:
		acc+=minf(dt,0.5)*speed
		while acc>=1.0 and not paused:
			acc-=1.0;sim_step()
	if playing and dialog_key=="" and not testing:
		var move=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if move!=Vector2.ZERO: world.pan(move*dt*world.zoom*0.64)
	world.advance_frame(dt,acc)
	audio.update_weather(playing and world.target_atmosphere>0.5)

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE and not event.pressed: drag=false

func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if dialog_key=="crisis" or dialog_key=="end": return
			if dialog_key!="": command("back")
			elif playing:
				if world.build_tool!="": world.build_tool="";refresh(true)
				elif hud.panel_key!="": command("closepanel")
				else: command("pausemenu")
		elif playing and dialog_key=="":
			match event.keycode:
				KEY_SPACE: command("pause")
				KEY_1: command("speed",1)
				KEY_2: command("speed",2)
				KEY_3: command("speed",4)
				KEY_R:
					if world.build_tool=="levee":
						world.edge_shift=(world.edge_shift+1)%6;refresh()
		return
	if not playing or dialog_key!="": return
	if event is InputEventMouseMotion:
		if drag: world.pan(-event.relative*world.zoom/get_viewport().get_visible_rect().size.y)
		var id=world.pick(event.position)
		if id!=world.hover:
			world.hover=id;world.refresh();hud.update_status()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE: drag=true
			MOUSE_BUTTON_WHEEL_UP: world.wheel(-1)
			MOUSE_BUTTON_WHEEL_DOWN: world.wheel(1)
			MOUSE_BUTTON_RIGHT:
				world.build_tool="";hud.panel_key="";select(-1);refresh(true)
			MOUSE_BUTTON_LEFT:
				var id=world.pick(event.position)
				if id<0: return
				if world.build_tool!="": place(id,posmod(Valley.intake(id)+world.edge_shift,6))
				else: select(id)

func _notification(what: int):
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if playing: write_save("campaign")
		shutdown()

func shutdown(code: int=0):
	set_process(false)
	audio.silence()
	await get_tree().create_timer(0.22).timeout
	get_tree().quit(code)
