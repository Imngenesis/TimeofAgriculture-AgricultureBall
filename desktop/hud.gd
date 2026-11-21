extends Control

signal action(command: String,arg: Variant)
const U=preload("res://paper.gd")
const V=preload("res://valley.gd")
const S=preload("res://simulation.gd")
var game
var sim
var headline
var refs={}
var mode=""
var panel_key=""
var drawn=""
var side: Control
var drawer: Control
var modal: Control
var toast=""
var toast_time=0.0
var stage: Control
var toolbar_buttons={}

func setup(main):
	game=main
	sim=main.sim
	theme=U.theme()
	headline=U.font(true)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func call_action(cmd: String,arg=null):
	action.emit(cmd,arg)

func btn(title: String,cmd: String,arg=null,primary: bool=false) -> Button:
	var b=U.button(title,call_action.bind(cmd,arg),primary)
	b.set_meta("command",cmd)
	b.set_meta("arg",arg)
	return b

func title_label(value: String,px: int,col: Color=U.TEXT) -> Label:
	var l=U.label(value,px,col)
	l.add_theme_font_override("font",headline)
	return l

func reset_root():
	for child in get_children():
		remove_child(child)
		child.queue_free()
	refs.clear(); toolbar_buttons.clear()
	side=null; drawer=null; modal=null; drawn=""; panel_key=""
	stage=Control.new()
	stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func menu(has_save: bool):
	mode="menu"
	reset_root()
	var shade=TextureRect.new()
	var ramp=Gradient.new()
	ramp.offsets=PackedFloat32Array([0.0,0.28,0.63,1.0])
	ramp.colors=PackedColorArray([Color(0.035,0.075,0.06,0.95),Color(0.05,0.10,0.078,0.88),Color(0.07,0.11,0.09,0.19),Color(0.1,0.1,0.08,0.03)])
	var grad=GradientTexture2D.new()
	grad.gradient=ramp; grad.fill_from=Vector2(0.0,0.5);grad.fill_to=Vector2(1,0.5)
	shade.texture=grad
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack=U.box(true,11)
	stage.add_child(stack)
	U.rect(stack,0,0.5,0,0.5,Rect2i(79,-226,478,221))
	var loc=U.box(false,10);stack.add_child(loc)
	loc.add_child(U.icon("seal",35));loc.add_child(U.label("长江河谷  /  四时代生存战役",16,U.GOLD))
	stack.add_child(title_label("稻生江畔",72,U.TEXT))
	stack.add_child(U.label("带十个人在江边扎根，留住下一季的种子。",18,U.DIM))
	stack.add_child(U.rule())
	var controls=U.box(true,9); stack.add_child(controls)
	controls.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	if has_save:
		var cont=btn("继续战役","continue",null,true);cont.custom_minimum_size=Vector2(209,44);controls.add_child(cont)
	var start=btn("开始新战役","new",null,not has_save);start.custom_minimum_size=Vector2(209,44);controls.add_child(start)
	var settings=btn("游戏设置","settings");settings.custom_minimum_size=Vector2(209,38);controls.add_child(settings)
	var leave=btn("退出游戏","quit");leave.custom_minimum_size=Vector2(209,38);controls.add_child(leave)
	var signature=U.label("稻生江畔  ·  桌面试玩版  0.1",13,U.DIM)
	stage.add_child(signature);U.rect(signature,0,1,0,1,Rect2i(80,-53,412,-30))
	var river=U.box(false,7)
	stage.add_child(river);U.rect(river,1,1,1,1,Rect2i(-190,-56,-30,-28))
	river.add_child(U.icon("compass",27,U.TEXT));river.add_child(U.label("长江中下游",14,U.TEXT))

func game_view():
	mode="game"
	reset_root()
	var pins=preload("res://map_marks.gd").new()
	pins.game=game;pins.face=theme.default_font;pins.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(pins);pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top=U.panel(stage,0,0,1,0,Rect2i(0,0,0,64),Color(0.08,0.12,0.10,0.96))
	var strip=U.box(false,16);U.inset(top,9).add_child(strip)
	strip.add_child(U.icon("seal",40))
	var age=U.box(true,0);strip.add_child(age)
	refs.era=U.label("",13,U.GOLD);age.add_child(refs.era)
	refs.date=title_label("",21);age.add_child(refs.date)
	strip.add_child(U.rule())
	for item in [["food","grain","口粮"],["seed","seed","种粮"],["crew","crew","闲置人手"],["science","study","农学"]]:
		var item_box=U.box(false,5);strip.add_child(item_box)
		item_box.add_child(U.icon(item[1],23))
		var col=U.box(true,0);item_box.add_child(col)
		col.add_child(U.label(item[2],12,U.DIM))
		refs[item[0]]=U.label("",18,U.TEXT);col.add_child(refs[item[0]])
	strip.add_child(U.space())
	var forecast=btn("","forecast")
	forecast.custom_minimum_size=Vector2(218,44)
	forecast.tooltip_text="在地图上定位本季农情"
	forecast.flat=true
	strip.add_child(forecast)
	var dial=preload("res://dial.gd").new()
	forecast.add_child(dial);dial.mouse_filter=Control.MOUSE_FILTER_IGNORE
	U.rect(dial,0,0.5,0,0.5,Rect2i(4,-23,50,23))
	refs.dial=dial
	var face=U.label("农时预报",11,U.GOLD)
	forecast.add_child(face);U.rect(face,0,0,1,0,Rect2i(55,1,-4,19))
	refs.forecast=U.label("",14,U.TEXT)
	forecast.add_child(refs.forecast);U.rect(refs.forecast,0,0,1,1,Rect2i(55,16,-4,0))
	strip.add_child(U.space())
	var chron=U.box(true,1);strip.add_child(chron)
	refs.clock=U.label("",13,U.DIM);chron.add_child(refs.clock)
	var timebar=ProgressBar.new()
	timebar.show_percentage=false;timebar.max_value=S.SEASON_TIME;timebar.custom_minimum_size=Vector2(106,5)
	timebar.add_theme_stylebox_override("background",U.style(U.BG))
	timebar.add_theme_stylebox_override("fill",U.style(U.GOLD))
	chron.add_child(timebar);refs.timebar=timebar
	for entry in [["pause","Ⅱ","pause",null],["one","1×","speed",1],["two","2×","speed",2],["four","4×","speed",4],["pausemenu","菜单","pausemenu",null]]:
		var b=btn(entry[1],entry[2],entry[3])
		b.custom_minimum_size=Vector2(39,32);b.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		b.tooltip_text="空格 · 暂停或继续" if entry[0]=="pause" else entry[1]
		strip.add_child(b);refs[entry[0]]=b
	var mission=U.panel(stage,0,0,0,0,Rect2i(18,82,270,84))
	var m=U.box(true,6);U.inset(mission,13).add_child(m)
	refs.chapter=U.label("",13,U.GOLD);m.add_child(refs.chapter)
	refs.ch_name=title_label("",23);m.add_child(refs.ch_name);m.add_child(U.rule())
	refs.goals=U.label("",15,U.TEXT,true);m.add_child(refs.goals)
	refs.tip=U.label("",13,U.DIM,true);m.add_child(refs.tip)
	refs.hint=btn("查看下一步","hint");m.add_child(refs.hint)
	var tool_panel=U.panel(stage,0.5,1,0.5,1,Rect2i(-297,-69,297,-13),Color(0.08,0.12,0.10,0.97))
	var tool_row=U.box(false,5);U.inset(tool_panel,6).add_child(tool_row)
	for item in [["build","build","建设"],["study","study","农学"],["crew","crew","调度"],["risk","risk","灾情"],["log","log","农事簿"]]:
		var b=btn("       "+item[2],"panel",item[0])
		b.custom_minimum_size=Vector2(108,36);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var glyph=U.icon(item[1],22);b.add_child(glyph)
		U.rect(glyph,0,0.5,0,0.5,Rect2i(10,-11,32,11))
		tool_row.add_child(b);toolbar_buttons[item[0]]=b
	var message=U.panel(stage,0.5,1,0.5,1,Rect2i(-312,-113,312,-80),Color(0.09,0.13,0.11,0.91))
	var ml=U.label("",14,U.TEXT);ml.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	message.add_child(ml);refs.message=ml;refs.msgbox=message
	var guide=U.box(false,5);stage.add_child(guide);U.rect(guide,0,1,0,1,Rect2i(19,-50,260,-22))
	guide.add_child(U.icon("compass",24));guide.add_child(U.label("中键平移  ·  滚轮缩放",13,U.TEXT))
	var badge=U.label("",14,U.GOLD);stage.add_child(badge);U.rect(badge,1,1,1,1,Rect2i(-215,-48,-18,-22));badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;refs.badge=badge
	update_status()
	rebuild_details(true)

func hint_text() -> String:
	var s=sim.s
	match s.era:
		0:
			if sim.assigned("t"+str(S.WILD[0]))==0 and s.ledger.gather==0 and not s.first_crop: return "开局先给野粮采集地派两人。"
			if not s.tech.has("seed"): return "研习「留种试种」，解锁第一块稻田。"
			if sim.farms().is_empty(): return "封存两份种粮，选一块土地建田。"
			if not s.first_crop: return "让人留在田里。春夏播种，秋末入仓。"
			return "保持采集，留两份种粮过冬。"
		1:
			if s.flood_at>=0 and not s.resown and s.seed<2: return "洪后要重新播种。打开调度，从口粮里封存两份种子。"
			return "低地丰饶也易淹。洪后留种，春夏复耕。"
		2: return "给已有田块修梯田或轮作，保护地力。"
		_: return "启用现代农技，留意下游污染与病斑。"

func update_status():
	if mode!="game": return
	var s=sim.s
	refs.era.text=S.ROMAN[s.era]+"  "+S.ERAS[s.era]
	refs.date.text=sim.date()
	refs.food.text=str(s.food);refs.seed.text=str(s.seed);refs.crew.text="%d / %d" % [sim.free_workers(),s.pop];refs.science.text=str(s.science)
	refs.food.add_theme_color_override("font_color",U.WARN if s.food<10 else U.TEXT)
	refs.clock.text="季末还有 %d 秒" % (S.SEASON_TIME-s.clock)
	refs.timebar.value=s.clock
	refs.dial.season=int(s.turn)%4;refs.dial.fraction=float(s.clock)/S.SEASON_TIME
	refs.dial.alarm=s.pending!="" or s.flood_time>0 or s.sick
	refs.dial.queue_redraw()
	if s.flood_time>0: refs.forecast.text="洪水过境 · %d 秒后退水" % s.flood_time
	elif s.sick: refs.forecast.text="病斑已现 · 秋末验收"
	elif s.era==1 and s.flood_at<0: refs.forecast.text="察看洪峰前的风险低地"
	elif s.era==2 and not s.rain: refs.forecast.text="梅雨将至 · 察看坡田"
	elif s.era==3: refs.forecast.text="下游水质 · 污染 %d" % s.water[2]
	else: refs.forecast.text=["春播 · 检查种仓","长夏 · 抓紧补种","秋收 · 保住稻穗","冬藏 · 野粮减少"][s.turn%4]
	refs.pause.text="▶" if game.paused else "Ⅱ"
	for key in ["one","two","four"]:
		refs[key].modulate=U.GOLD if not game.paused and game.speed=={"one":1,"two":2,"four":4}[key] else Color.WHITE
	refs.chapter.text="第 %s 时代    /    %s" % [S.ROMAN[s.era],S.ERAS[s.era]]
	refs.ch_name.text=S.CHAPTERS[s.era]
	var lines=[]
	for g in sim.goals(): lines.append(("✓  " if g[0] else "◇  ")+g[1])
	refs.goals.text="\n".join(lines)
	refs.tip.text=hint_text()
	var place=game.world.build_tool
	var info=toast if toast_time>0 else ""
	if place!="":
		var target=game.world.hover
		info=S.BUILD[place][0]+"　·　点地图落址，右键取消"
		if target>=0:
			var why=sim.build_reason(place,target,game.world.edge_dir)
			if why!="": info=why+"　·　右键取消"
			elif place=="levee": info="此边可保护 %d 块低地　·　左键修堤，R 换边" % sim.protected_by(target,game.world.edge_dir).size()
			else: info="%s　%s　·　%d 份口粮　·　左键动工" % [V.address(target),("易淹低地" if V.tier(target)==0 else "安全高处"),S.BUILD[place][2]]
	elif info=="" and game.paused: info="时间已暂停　·　可继续派工，按空格恢复"
	refs.msgbox.visible=info!=""
	refs.message.text=info
	refs.badge.text={"":"", "flood":"橙色  ·  洪水预计可达", "soil":"橙色越深  ·  地力越低", "water":"橙色越深  ·  河水污染越高"}.get(game.world.risk,"")
	for key in toolbar_buttons: toolbar_buttons[key].modulate=U.GOLD if panel_key==key else Color.WHITE

func notify(value: String):
	toast=value;toast_time=4.5
	update_status()

func clear_detail(which: Control):
	if is_instance_valid(which):
		which.get_parent().remove_child(which)
		which.queue_free()

func rebuild_details(force: bool=false):
	if mode!="game": return
	var id=game.world.selected
	var s=sim.s
	var tag="%s:%d:%s:%s:%s:%s:%s:%s:%s:%s:%s" % [panel_key,id,game.edge_job,s.rev,s.turn,s.tech,s.study,s.science,s.food>=4,game.world.risk,sim.free_workers()]
	if force or tag!=drawn:
		drawn=tag
		clear_detail(side);side=null
		clear_detail(drawer);drawer=null
		if panel_key!="": make_drawer()
		if id>=0 and panel_key=="": make_inspector(id)
	if refs.has("inspection") and is_instance_valid(refs.inspection) and id>=0:
		refs.inspection.text=inspection(id)

func row_header(where: Control,value: String,cmd: String):
	var line=U.box(false,5);where.add_child(line)
	line.add_child(title_label(value,22));line.add_child(U.space())
	var close=btn("×",cmd);close.custom_minimum_size=Vector2(32,30);line.add_child(close)

func inspection(id: int) -> String:
	var s=sim.s
	var c=s.cells[id]
	var job=game.edge_job if game.edge_job!="" else "t"+str(id)
	if job.begins_with("e") and s.edges.has(job.substr(1)):
		var e=s.edges[job.substr(1)]
		return "田堤已合拢，可阻断来水。" if e.built else "筑堤进度  %d / %d\n到岗 %d 人，已派 %d 人" % [e.done,S.BUILD.levee[3],sim.assigned(job,true),sim.assigned(job)]
	if c.project!="": return "施工进度  %d / %d 人秒\n到岗 %d 人，已派 %d 人" % [c.done,S.BUILD[c.project][3],sim.assigned(job,true),sim.assigned(job)]
	if c.kind=="wild": return "到岗 %d 人，已派 %d 人\n此地本季还可采 %d 份\n本季全谷采集 %d 份" % [sim.assigned(job,true),sim.assigned(job),sim.forage_limit()-c.picked,s.ledger.gather]
	if c.kind=="farm":
		var status="正在生长" if c.crop else ("等待春夏播种" if s.seed>=2 else "等待两份种粮")
		if c.flood: status="受淹 · 等待退水"
		return "%s　·　地力 %d\n到岗 %d 人，已派 %d 人\n上次秋收 %d 份" % [status,c.soil,sim.assigned(job,true),sim.assigned(job),c.last]
	if id==S.HOME and sim.capacity(job)>0: return "转运队 %d 人已到岗\n粮种正在向高处转移。" % sim.assigned(job,true)
	if V.tier(id)<0: return "本河段污染  %d\n水向下游流动。" % s.water[V.reach(id)]
	if c.kind=="store": return "储藏粮种。位于高处或堤内的粮仓可在洪峰中保护更多库存。"
	if c.kind=="station": return "农机已投入使用，全谷稻田秋收增加 5 份。"
	return "临河易涝，田堤可截住来水。" if V.tier(id)==0 else "地势较高，适合建粮仓或开田。"

func make_inspector(id: int):
	side=U.panel(stage,1,0,1,0,Rect2i(-292,82,-18,84))
	var v=U.box(true,7);U.inset(side,13).add_child(v)
	v.add_child(U.label(V.address(id),13,U.GOLD))
	var job=game.edge_job if game.edge_job!="" else "t"+str(id)
	row_header(v,"田堤" if game.edge_job!="" else sim.location_name(id),"deselect")
	v.add_child(U.rule())
	var data=U.label(inspection(id),15,U.TEXT,true);v.add_child(data);refs.inspection=data
	if sim.capacity(job)>0:
		var row=U.box(false,7);v.add_child(row);row.add_child(U.label("岗位人手",14,U.DIM));row.add_child(U.space())
		var minus=btn("－","assign",[job,-1]);minus.disabled=sim.assigned(job)==0
		var plus=btn("＋","assign",[job,1],true);plus.disabled=sim.free_workers()==0 or sim.assigned(job)>=sim.capacity(job)
		row.add_child(minus);row.add_child(plus)
	var c=sim.s.cells[id]
	if c.kind=="farm" and c.project=="":
		for item in [["rotate","稻豆轮作","rotation"],["precise","精准配肥","precise"],["scout","巡田防病","patrol"]]:
			if sim.s.tech.has(item[0]) and (item[2]=="patrol" or not c.get(item[2],false)):
				v.add_child(btn(item[1]+"  ·  2 粮","field",[id,item[2]]))
		if sim.s.era>=2: v.add_child(btn("堆肥养地  ·  2 粮","field",[id,"compost"]))
	if id==S.HOME or c.kind=="store" or c.kind=="farm":
		v.add_child(btn("封存两份种粮","reserve",false))
	if c.kind=="" and c.project=="" and V.tier(id)>=0 and game.edge_job=="":
		v.add_child(btn("在此开田","place_here",["farm",id]))
		if V.tier(id)==0 and sim.s.tech.has("dike"): v.add_child(btn("在进水侧修堤","place_here",["levee",id]))
	for k in sim.s.edges:
		if game.edge_job=="" and sim.s.edges[k].a==id:
			v.add_child(btn("查看本段田堤","edge",k))

func make_drawer():
	var wide=panel_key in ["study","log"]
	var w=590 if wide else 432
	drawer=U.panel(stage,0.5,0.5,0.5,0.5,Rect2i(-w/2,-202,w/2,199),Color(0.095,0.14,0.11,0.98))
	var frame=U.box(true,8);U.inset(drawer,15).add_child(frame)
	var titles={"build":"农业建设","study":"农业科技树","crew":"人手与种仓","risk":"河谷灾情","log":"农事簿"}
	row_header(frame,titles[panel_key],"closepanel");frame.add_child(U.rule())
	var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;frame.add_child(scroll)
	var content=U.box(true,7);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	match panel_key:
		"build":
			content.add_child(U.label("选一项工程，再到河谷上选址。",14,U.DIM))
			for key in S.BUILD:
				var spec=S.BUILD[key]
				var b=btn("%s　 ·　 %d 口粮　 /　 %d 人秒" % [spec[0],spec[2],spec[3]],"tool",key)
				b.disabled=not sim.s.tech.has(spec[1])
				if b.disabled: b.text=spec[0]+"　·　需"+S.TECH[spec[1]][0]
				content.add_child(b)
		"study":
			content.add_child(U.label("现有 %d 农学点　·　每季获得 2 点　·　研习耗时 8 秒" % sim.s.science,14,U.GOLD))
			for i in 4:
				content.add_child(U.label(S.ROMAN[i]+"  "+S.ERAS[i],14,U.DIM))
				var pair=U.box(false,8);content.add_child(pair)
				for key in S.TECH:
					var t=S.TECH[key]
					if t[1]!=i: continue
					var why=sim.research_reason(key)
					var state="已掌握" if sim.s.tech.has(key) else ("研习中" if sim.s.study==key else ("%d 点" % t[2] if sim.s.era>=i else "未开放"))
					var b=btn(t[0]+"  ·  "+state,"research",key)
					b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.disabled=why!="";b.tooltip_text=t[4]+("  "+why if why!="" else "");pair.add_child(b)
		"crew":
			content.add_child(U.label("闲置 %d / %d 人　　口粮 %d　　种粮 %d" % [sim.free_workers(),sim.s.pop,sim.s.food,sim.s.seed],15,U.GOLD))
			var row=U.box(false,6);content.add_child(row)
			row.add_child(btn("封存 2 份种粮","reserve",false));row.add_child(btn("取 2 份作口粮","reserve",true))
			for id in sim.s.cells.size():
				var job="t"+str(id)
				if sim.capacity(job)>0: content.add_child(btn("%s　%s　·　%d 人" % [V.address(id),sim.location_name(id),sim.assigned(job)],"jump",id))
			for key in sim.s.edges:
				if not sim.s.edges[key].built: content.add_child(btn("田堤工地　·　"+V.address(sim.s.edges[key].a),"edge",key))
		"risk":
			content.add_child(U.label("上 / 中 / 下游污染　%d　/　%d　/　%d" % sim.s.water,16,U.GOLD))
			for item in [["flood","洪水可达低地"],["soil","田块地力"],["water","流域污染"],["","关闭图层"]]:
				content.add_child(btn(item[1],"overlay",item[0],item[0]==game.world.risk))
			content.add_child(U.label("点击图层后回到河谷，颜色对应右下角图例。",14,U.DIM,true))
		"log":
			content.add_child(U.label(sim.s.last_report if sim.s.last_report!="" else "第一季尚未结算。",15,U.GOLD,true))
			if not sim.s.last_ledger.is_empty():
				var previous=sim.s.last_ledger
				content.add_child(U.label("上季工程用粮 %d　·　播种 %d　·　灾损 %d" % [previous.build,previous.sow,previous.loss],14,U.DIM,true))
			for item in sim.s.log: content.add_child(U.label(item,14,U.TEXT,true))

func dialog(kind: String):
	clear_detail(modal);modal=null
	if kind=="": return
	modal=ColorRect.new()
	modal.color=Color(0.035,0.065,0.047,0.55)
	stage.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var card=U.panel(modal,0.5,0.5,0.5,0.5,Rect2i(-257,-179,257,176),Color(0.095,0.145,0.115,0.99))
	var body=U.box(true,9);U.inset(card,22).add_child(body)
	var s=sim.s
	match kind:
		"crisis":
			var event=S.CRISIS[s.pending]
			body.add_child(U.label("农情急报    /    "+sim.date()+"    /    时间已暂停",13,U.WARN))
			body.add_child(title_label(event[0],31));body.add_child(U.rule())
			body.add_child(U.label(event[1],16,U.TEXT,true))
			for j in 2:
				var b=btn(event[2+2*j],"decision",j,j==0);body.add_child(b)
				body.add_child(U.label(event[3+2*j],14,U.DIM,true))
		"end":
			var victory=s.outcome=="won"
			body.add_child(U.label(S.ROMAN[s.era]+"  "+S.ERAS[s.era]+"    /    "+sim.date(),14,U.GOLD))
			body.add_child(title_label("谷满江清" if victory else "江岸散炊",38))
			body.add_child(U.rule())
			body.add_child(U.label("疫后稻谷入仓，河水恢复到可承受的水平。聚落把下一季的种子留了下来。" if victory else "连续两季，无粮可发。最后一户人家收起炊具，离开了河谷。",17,U.TEXT,true))
			body.add_child(U.label("口粮 %d 份   ·   种粮 %d 份   ·   下游污染 %d" % [s.food,s.seed,s.water[2]],15,U.GOLD))
			if not victory: body.add_child(btn("从本时代起点重试","retry",null,true))
			body.add_child(btn("返回主菜单","title",null,victory))
		"pause":
			body.add_child(U.label("战役暂停    /    "+sim.date(),14,U.GOLD));body.add_child(title_label("河谷歇晌",30))
			body.add_child(btn("回到河谷","back",null,true))
			body.add_child(btn("保存进度","save"));body.add_child(btn("读取最近存档","load"))
			body.add_child(btn("游戏设置","settings"));body.add_child(btn("保存并返回主菜单","title"))
		"settings":
			body.add_child(title_label("游戏设置",29));body.add_child(U.rule())
			body.add_child(btn("环境与提示音　·　"+("开启" if game.audio.enabled else "关闭"),"sound"))
			body.add_child(btn("显示模式　·　"+("全屏" if game.fullscreen() else "窗口"),"fullscreen"))
			body.add_child(U.label("空格暂停　　1 / 2 / 3 调速　　Esc 返回\n中键拖拽或 WASD 平移　　滚轮缩放\n左键选址与确认　　右键取消　　R 切换堤边",15,U.DIM,true))
			body.add_child(btn("返回","back",null,true))
		"restart":
			body.add_child(title_label("从头开辟河谷？",28))
			body.add_child(U.label("开始新战役将替换这台电脑上的当前进度与时代检查点。",17,U.TEXT,true));body.add_child(U.rule())
			body.add_child(btn("开始新战役","confirmed_new",null,true));body.add_child(btn("继续保留当前进度","back"))

func find_button(command: String,arg=null) -> Button:
	for node in find_children("*","Button",true,false):
		var payload=node.get_meta("arg") if node.has_meta("arg") else null
		if node.is_visible_in_tree() and node.get_meta("command","")==command and payload==arg and not node.disabled:
			return node
	return null
