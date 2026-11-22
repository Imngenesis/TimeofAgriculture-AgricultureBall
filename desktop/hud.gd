extends Control

signal action(command: String,arg: Variant)
const U=preload("res://paper.gd")
const V=preload("res://valley.gd")
const S=preload("res://simulation.gd")
const T=preload("res://settlement.gd")
const E=preload("res://economy.gd")
const Management=preload("res://management_ui.gd")
const Atlas=preload("res://frontier_ui.gd")
const Research=preload("res://research_ui.gd")
var tech_branch="稻"
var tech_key="seed"
var frontier_tab="种圃"
var atlas_crop="稻"
var freight_from=0
var freight_to=1
var full_load=true
var countdowns=[]
var staff_alerts={}
var road_alerts=[]
var toast_issue=false
var economy_tab="budget"
var goals_collapsed=false
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
	refs.clear(); toolbar_buttons.clear(); countdowns.clear()
	side=null; drawer=null; modal=null; drawn=""; panel_key=""
	stage=Control.new()
	stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func menu(has_save: bool):
	mode="menu"
	reset_root()
	var painting=TextureRect.new()
	painting.texture=preload("res://art/river-dawn.png")
	painting.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	painting.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	painting.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(painting);painting.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade=TextureRect.new()
	var ramp=Gradient.new()
	ramp.offsets=PackedFloat32Array([0.0,0.28,0.63,1.0])
	ramp.colors=PackedColorArray([Color(0.025,0.075,0.08,0.91),Color(0.03,0.09,0.095,0.72),Color(0.07,0.11,0.09,0.09),Color(0.1,0.1,0.08,0.01)])
	var grad=GradientTexture2D.new()
	grad.gradient=ramp; grad.fill_from=Vector2(0.0,0.5);grad.fill_to=Vector2(1,0.5)
	shade.texture=grad
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stack=U.box(true,11)
	stage.add_child(stack)
	U.rect(stack,0,0.5,0,0.5,Rect2i(79,-226,478,221))
	var loc=U.box(false,10);stack.add_child(loc)
	loc.add_child(U.icon("seal",35));loc.add_child(U.label("六方水土  /  四时代农业战役",16,U.GOLD))
	stack.add_child(title_label("稻生江畔",72,U.TEXT))
	stack.add_child(U.label("带十个人落脚，从第一把种子经营出一片家园。",18,U.DIM))
	stack.add_child(U.rule())
	var controls=U.box(true,9); stack.add_child(controls)
	controls.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	if has_save:
		var cont=btn("继续战役","continue",null,true);cont.custom_minimum_size=Vector2(209,44);controls.add_child(cont)
	var start=btn("开始新战役","new",null,not has_save);start.custom_minimum_size=Vector2(209,44);controls.add_child(start)
	var settings=btn("游戏设置","settings");settings.custom_minimum_size=Vector2(209,38);controls.add_child(settings)
	var leave=btn("退出游戏","quit");leave.custom_minimum_size=Vector2(209,38);controls.add_child(leave)
	var signature=U.label("稻生江畔  ·  V1.00 正式版",13,U.DIM)
	stage.add_child(signature);U.rect(signature,0,1,0,1,Rect2i(80,-53,412,-30))
	var river=U.box(false,7)
	stage.add_child(river);U.rect(river,1,1,1,1,Rect2i(-190,-56,-30,-28))
	river.add_child(U.icon("compass",27,U.TEXT));river.add_child(U.label("六地农耕图志",14,U.TEXT))

func game_view():
	mode="game"
	atlas_crop=S.F.START[sim.s.frontier.region]
	tech_branch=atlas_crop; tech_key="seed"
	frontier_tab="种圃"
	freight_from=0
	freight_to=1
	reset_root()
	var pins=preload("res://map_marks.gd").new()
	pins.game=game;pins.face=theme.default_font;pins.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stage.add_child(pins);pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top=U.panel(stage,0,0,1,0,Rect2i(0,0,0,64),Color(0.08,0.12,0.10,0.96))
	var strip=U.box(false,6);U.inset(top,8).add_child(strip)
	strip.add_child(U.icon("seal",35))
	var age=U.box(true,0);strip.add_child(age)
	refs.era=U.label("",13,U.GOLD);age.add_child(refs.era)
	refs.date=title_label("",21);age.add_child(refs.date)
	strip.add_child(U.rule())
	for item in [["food","grain","口粮 / 季需"],["seed","seed","种粮"],["materials","materials","木料 / 石料"],["crew","crew","人口 / 闲置"],["science","study","科技 / 待领"]]:
		var chip=btn("","resource",item[0])
		chip.custom_minimum_size=Vector2(92 if item[0]!="seed" else 70,45)
		chip.tooltip_text={"food":"查看本季口粮预算","seed":"打开种仓与种圃","materials":"查看各地现货与在途物资","crew":"查看人员去向与停工原因","science":"查看作物分支与农专札记"}[item[0]]
		strip.add_child(chip)
		var item_box=U.box(false,4);chip.add_child(item_box);U.rect(item_box,0,0,1,1,Rect2i(4,2,-3,-2));item_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
		item_box.add_child(U.icon(item[1],20))
		var col=U.box(true,0);col.mouse_filter=Control.MOUSE_FILTER_IGNORE;item_box.add_child(col)
		col.add_child(U.label(item[2],12,U.DIM))
		refs[item[0]]=U.label("",18,U.TEXT);col.add_child(refs[item[0]])
	strip.add_child(U.space())
	var forecast=btn("","forecast")
	forecast.custom_minimum_size=Vector2(192,44)
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
	var chapter_row=U.box(false,4);m.add_child(chapter_row)
	refs.chapter=U.label("",13,U.GOLD);chapter_row.add_child(refs.chapter);chapter_row.add_child(U.space())
	refs.fold=btn("收起","fold_goals");refs.fold.custom_minimum_size=Vector2(40,26);chapter_row.add_child(refs.fold)
	refs.ch_name=title_label("",23);m.add_child(refs.ch_name);m.add_child(U.rule())
	refs.goals=U.label("",15,U.TEXT,true);m.add_child(refs.goals)
	refs.tip=U.label("",13,U.DIM,true);m.add_child(refs.tip)
	refs.hint=btn("查看下一步","hint");m.add_child(refs.hint)
	refs.skip_lesson=btn("收起入门田课","lesson_toggle");m.add_child(refs.skip_lesson)
	refs.develop=btn("查看晋阶条件","panel","era");m.add_child(refs.develop)
	refs.water_stock=btn("","inventory");m.add_child(refs.water_stock)
	refs.vacancies=btn("缺工岗位","staff_alert");m.add_child(refs.vacancies)
	var tool_panel=U.panel(stage,0.5,1,0.5,1,Rect2i(-381,-69,381,-13))
	var tool_row=U.box(false,5);U.inset(tool_panel,6).add_child(tool_row)
	for item in [["build","build","建设"],["study","study","农学"],["crew","crew","调度"],["economy","balance","收支"],["frontier","seed","农庄"],["risk","risk","灾情"],["log","log","农事簿"]]:
		var b=btn("       "+item[2],"panel",item[0])
		b.tooltip_text={"build":"建设与逐段铺路（B）","study":"作物课题与中国农技（T）","crew":"调人、招募与停工原因","economy":"仓储、材料与各季收支","frontier":"种圃、探险、牧场和运输","risk":"灾情与地图覆盖","log":"近期农事记录"}[item[0]]
		b.custom_minimum_size=Vector2(100,36);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var glyph=U.icon(item[1],22);b.add_child(glyph)
		U.rect(glyph,0,0.5,0,0.5,Rect2i(10,-11,32,11))
		tool_row.add_child(b);toolbar_buttons[item[0]]=b
	var roadbar=U.panel(stage,0.5,1,0.5,1,Rect2i(-318,-171,318,-118));refs.roadbar=roadbar
	var streetrow=U.box(false,8);U.inset(roadbar,8).add_child(streetrow)
	refs.roadinfo=U.label("",14,U.GOLD,true);refs.roadinfo.size_flags_horizontal=Control.SIZE_EXPAND_FILL;streetrow.add_child(refs.roadinfo)
	refs.roadmode=btn("改为拆路","street_mode");streetrow.add_child(refs.roadmode)
	refs.roadpay=btn("确认铺路","street_confirm",null,true);streetrow.add_child(refs.roadpay)
	streetrow.add_child(btn("结束","street_end"))
	var message=U.panel(stage,0.5,1,0.5,1,Rect2i(-312,-113,312,-80),Color(0.09,0.13,0.11,0.91))
	var ml=U.label("",14,U.TEXT);ml.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	message.add_child(ml);refs.message=ml;refs.msgbox=message
	var guide=U.box(false,5);stage.add_child(guide);U.rect(guide,0,1,0,1,Rect2i(19,-50,260,-22))
	guide.add_child(U.icon("compass",24));guide.add_child(U.label("中键平移  ·  滚轮缩放",13,U.TEXT))
	var map=preload("res://valley_chart.gd").new()
	map.game=game;stage.add_child(map);U.rect(map,1,1,1,1,Rect2i(-171,-119,-18,-13));refs.map=map
	refs.legend=U.panel(stage,1,1,1,1,Rect2i(-200,-148,-18,-123))
	var badge=U.label("",12,U.GOLD);refs.legend.add_child(badge);badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;refs.badge=badge
	update_status()
	rebuild_details(true)

func hint_text() -> String:
	var s=sim.s
	match s.era:
		0:
			if sim.assigned("t"+str(S.WILD[0]))==0 and s.ledger.gather==0 and not s.first_crop: return "开局先给野粮采集地派两人。"
			if sim.academy_id()<0: return "在建设栏选址建农专，派人试验才能产出科技点。"
			if not s.tech.has("seed"): return "到农专领 2 点，在农学手册研习「"+sim.tech_name("seed")+"」。"
			if sim.farms().is_empty(): return "点建设选址开田，接入农专后按品种备种。"
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
	var ac=sim.academy_id()
	refs.food.text="%d / %d" % [s.food,s.pop];refs.seed.text=str(s.seed)
	refs.materials.text="%d / %d" % [s.wood,s.stone]
	staff_alerts.clear()
	for job in sim.vacancies(): staff_alerts[sim.job_tile(job)]=job
	road_alerts.clear()
	for id in s.cells.size():
		var c=s.cells[id]
		if c.connected or V.sector(id) not in s.districts: continue
		if c.kind in ["farm","house","store","nursery","station","canal"] or (c.kind in ["wood","stone"] and sim.assigned("t"+str(id))>0): road_alerts.append(id)
	refs.vacancies.visible=not staff_alerts.is_empty() or not road_alerts.is_empty()
	refs.vacancies.text="断路 %d　·　缺工 %d　→ 调度" % [road_alerts.size(),staff_alerts.size()]
	refs.vacancies.modulate=U.WARN
	refs.map.queue_redraw()
	refs.water_stock.visible=s.frontier.region==4
	if refs.water_stock.visible:
		var water=S.F.Farm.spring_water(s)
		refs.water_stock.text="淡水 %d　·　%s" % [s.frontier.fresh,"预计短缺 %d" % water.short if water.short else "查看水务"]
		refs.water_stock.modulate=U.WARN if water.short else U.TEXT
	refs.crew.text="%d / %d" % [S.F.people_total(s),sim.free_workers()]
	refs.crew.tooltip_text="总人口（含外派）。营地 %d，营外 %d。" % [s.pop,S.F.people_total(s)-s.pop]
	refs.science.text="%d / %d" % [s.science,s.cells[ac].notes if ac>=0 else 0]
	refs.food.add_theme_color_override("font_color",U.WARN if s.food<s.pop else U.TEXT)
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
	else: refs.forecast.text=["春播 · 检查种仓","长夏 · 抓紧补种","秋收 · 照料田块","冬藏 · 野粮减少"][s.turn%4]
	refs.pause.text="▶" if game.paused else "Ⅱ"
	for key in ["one","two","four"]:
		refs[key].modulate=U.GOLD if not game.paused and game.speed=={"one":1,"two":2,"four":4}[key] else Color.WHITE
	refs.chapter.text="%s　/　%s　/　%s" % [S.ROMAN[s.era],S.ERAS[s.era],E.DIFFICULTIES[s.difficulty].name]
	refs.ch_name.text=S.CHAPTERS[s.era]
	var lines=[]
	for g in sim.goals(): lines.append(("✓  " if g[0] else "◇  ")+g[1])
	refs.goals.text="\n".join(lines)
	refs.fold.text="展开" if goals_collapsed else "收起"
	for section in [refs.goals,refs.tip,refs.hint]: section.visible=not goals_collapsed
	var ready=sim.advance_reason()==""
	refs.develop.text=("确认达成现代农业" if s.era==3 else "已备齐 · 前往晋阶") if ready else ("查看终局条件" if s.era==3 else "查看晋阶条件")
	refs.develop.modulate=U.GOLD if ready else Color.WHITE
	refs.tip.text=hint_text()
	var teaching=not s.lesson_hidden and s.lesson_step<S.Lesson.STEPS.size()
	refs.skip_lesson.visible=teaching and not goals_collapsed
	refs.hint.text="查看下一步"
	if teaching:
		var step=S.Lesson.STEPS[s.lesson_step]
		refs.chapter.text="入门田课　%d / %d" % [s.lesson_step+1,S.Lesson.STEPS.size()]
		refs.ch_name.text=step[0]
		refs.goals.visible=false
		refs.tip.text=step[1]
		refs.hint.text=step[2]
	var place=game.world.build_tool
	var info=toast if toast_time>0 else ""
	refs.roadbar.visible=place=="street"
	if place=="street":
		var end=game.world.road_end if game.world.road_end>=0 else game.world.hover
		var plan=S.Roads.removal(s,game.world.road_start,end) if game.world.removing else S.Roads.quote(s,game.world.road_start,end)
		refs.roadmode.text="改为铺路" if game.world.removing else "改为拆路"
		refs.roadpay.text="确认拆除" if game.world.removing else "确认铺路"
		refs.roadinfo.text="点击道路起点，可从农专出发" if game.world.road_start<0 else ("移动鼠标预览，点击终点铺设" if end<0 or end==game.world.road_start else ("%d 段新路 · %d 木 · %d 石" % [plan.extra.size(),plan.wood,plan.stone] if plan.reason=="" else plan.reason))
		if game.world.removing:
			refs.roadinfo.text="选择已有道路的两端，确认拆除" if plan.reason!="" else "将拆除 %d 段 · 断开的设施停工" % plan.extra.size()
		refs.roadpay.disabled=plan.reason!=""
		info=""
	elif place!="":
		var target=game.world.hover
		info=S.BUILD[place][0]+"　·　点地图落址，右键取消"
		if target>=0:
			var why=sim.build_reason(place,target,game.world.edge_dir)
			if why!="": info=why+"　·　右键取消"
			elif place=="levee": info="此边可保护 %d 块低地　·　左键修堤，R 换边" % sim.protected_by(target,game.world.edge_dir).size()
			else: info="%s　·　%d 粮 · %s　·　%s" % [V.address(target),S.BUILD[place][2],E.input_text(place),"完工后需接路" if place in S.Roads.WORKS and not s.cells[target].connected else "左键动工"]
	elif info=="" and game.paused: info="时间已暂停　·　可继续派工，按空格恢复"
	refs.msgbox.visible=info!=""
	refs.message.text=info
	refs.message.add_theme_color_override("font_color",U.WARN if toast_issue and info==toast else U.TEXT)
	refs.badge.text={"":"", "flood":"橙色  ·  洪水预计可达", "soil":"橙色越深  ·  地力越低", "water":"橙色越深  ·  河水污染越高","crop":"红色越深  ·  田间压力越高"}.get(game.world.risk,"")
	refs.legend.visible=refs.badge.text!=""
	for key in toolbar_buttons: toolbar_buttons[key].modulate=U.GOLD if panel_key==key else Color.WHITE

func notify(value: String,issue: bool=false):
	toast_issue=issue
	toast=value;toast_time=6.0 if issue else 4.5
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
	var ac=sim.academy_id()
	if ac>=0: tag+=":%d" % s.cells[ac].notes
	if panel_key=="study": tag+=":%s:%s:%d" % [tech_branch,tech_key,s.study_time]
	if panel_key in ["era","crew","build","economy","transfer","frontier","study"] or id>=0: tag+=":%d:%d:%d:%d" % [s.food,s.seed,s.wood,s.stone]
	if panel_key in ["crew","transfer"] or id>=0:
		var walking=0
		for worker in s.workers:
			if worker.job!="" and worker.travel>0: walking+=1
		tag+=":%d" % walking
	if force or tag!=drawn:
		var old_scroll=0
		var site_scroll=0
		if is_instance_valid(drawer) and drawer.get_meta("section","")==panel_key and drawer.get_meta("tab","")==detail_tab():
			var last=drawer.find_child("ContentScroll",true,false)
			if last: old_scroll=last.scroll_vertical
		if is_instance_valid(side) and side.get_meta("tile",-1)==id and side.get_meta("job","")==game.edge_job:
			site_scroll=side.find_child("SiteScroll",true,false).scroll_vertical
		drawn=tag
		countdowns.clear()
		refs.erase("cancel_work");refs.erase("inspection")
		clear_detail(side);side=null
		clear_detail(drawer);drawer=null
		if panel_key!="":
			make_drawer()
			if old_scroll>0: drawer.find_child("ContentScroll",true,false).set_deferred("scroll_vertical",old_scroll)
		if id>=0 and panel_key=="":
			make_inspector(id)
			if site_scroll>0: side.find_child("SiteScroll",true,false).set_deferred("scroll_vertical",site_scroll)
		if is_instance_valid(modal): stage.move_child(modal,-1)
	for clock_label in countdowns:
		clock_label.text=clock_label.get_meta("message") % maxi(0,int(clock_label.get_meta("due"))-s.time)
	if refs.has("inspection") and is_instance_valid(refs.inspection) and id>=0:
		refs.inspection.text=inspection(id)
		if refs.has("cancel_work") and is_instance_valid(refs.cancel_work):
			var project=s.cells[id].project
			var done=s.cells[id].done
			if game.edge_job!="":
				var edge=s.edges[game.edge_job.substr(1)]
				project="repair" if edge.repairing else "levee"
				done=edge.done
			if project!="": refs.cancel_work.text="撤工 · 退回 %d 粮" % sim.project_refund(project,done)

func row_header(where: Control,value: String,cmd: String):
	var line=U.box(false,5);where.add_child(line)
	line.add_child(title_label(value,22));line.add_child(U.space())
	var close=btn("×",cmd);close.custom_minimum_size=Vector2(32,30);line.add_child(close)

func inspection(id: int) -> String:
	var s=sim.s
	var c=s.cells[id]
	var job=game.edge_job if game.edge_job!="" else "t"+str(id)
	if not s.districts.has(V.sector(id)):
		var zone=V.sector(id)
		return "%s · %s　基础地租每季 %d 粮，随难度结算。" % [V.SECTORS[zone],E.LAND_FEATURE[zone],E.LAND_FEE[zone]]
	if job.begins_with("e") and s.edges.has(job.substr(1)):
		var e=s.edges[job.substr(1)]
		if e.repairing: return "检修 %d / 8 人秒　·　到岗 %d 人" % [e.done,sim.assigned(job,true)]
		if e.built: return "完好度 %d / 100　·　%s" % [e.condition,"已阻断来水" if e.condition>=T.WORKING_CONDITION else "失修，防洪失效"]
		return "筑堤进度  %d / %d\n到岗 %d 人，已派 %d 人" % [e.done,S.BUILD.levee[3],sim.assigned(job,true),sim.assigned(job)]
	if c.project!="": return "施工进度  %d / %d 人秒\n到岗 %d 人，已派 %d 人" % [c.done,S.BUILD[c.project][3],sim.assigned(job,true),sim.assigned(job)]
	if c.kind=="wild": return "到岗 %d 人，已派 %d 人\n此地本季还可采 %d 份\n本季全谷采集 %d 份" % [sim.assigned(job,true),sim.assigned(job),sim.forage_limit()-c.picked,s.ledger.gather]
	if E.DEPOTS.has(c.kind): return "到岗 %d 人，已派 %d 人\n每 %d 人秒入库 1 份%s。" % [sim.assigned(job,true),sim.assigned(job),E.extraction_time(c.kind,id),"木料" if c.kind=="wood" else "石料"]
	var condition="%d 级　·　完好度 %d / 100\n" % [c.level,c.condition]
	if c.kind=="academy":
		var activity="研习「%s」还需 %d 人秒" % [sim.tech_name(s.study),s.study_time] if s.study!="" else "下一点科技　%d / %d 人秒" % [c.lesson,T.LESSON]
		if s.study=="" and s.science+c.notes>=S.Study.limit(s,c.level): activity="案藏已满 · 投入研究或扩建农专可继续编点"
		return condition+"到岗 %d 人　·　待领 %d 点\n%s" % [sim.assigned(job,true),c.notes,activity]
	if c.kind=="farm":
		var next=S.F.Crops.for_sowing(s,id)
		var seeds=S.F.Crops.seed_cost(s,next[0],next[1])
		var status="正在生长" if c.crop else ("等待春夏播种" if E.warehouse(s,V.sector(id)).seed>=seeds else "等待 %d 份种粮" % seeds)
		if not c.connected: status="断路 · 尚未投产"
		if c.flood: status="受淹 · 等待退水"
		var coverage=[]
		for kind in ["canal","nursery","station"]:
			if T.covered(s,id,kind): coverage.append(S.BUILD[kind][0])
		return condition+"%s　·　地力 %d / 污染 %d\n到岗 %d 人　上茬 %d 份\n按现况估产 %d 份\n食害 %d　草害 %d　病害 %d\n覆盖设施　%s" % [status,c.soil,c.pollution,sim.assigned(job,true),c.last,sim.expected_yield(id),c.birds,c.weeds,c.disease,"、".join(coverage) if coverage else "暂无"]
	if id==s.frontier.home and sim.capacity(job)>0: return "转运队 %d 人已到岗\n粮种正在向高处转移。" % sim.assigned(job,true)
	if V.tier(id)<0: return "本河段污染  %d\n水向下游流动。" % s.water[V.reach(id)]
	if c.kind in S.FACILITIES:
		var status=""
		if c.kind in S.Roads.WORKS and not c.connected: status="道路中断 · 服务暂停"
		elif c.condition<T.WORKING_CONDITION: status="完好度过低，服务已暂停。"
		elif c.kind in T.OPERATORS:
			status="操作员已到岗 · 设施运行中" if sim.assigned(job,true)>0 else ("操作员赴任中" if sim.assigned(job)>0 else "操作员空缺 · 服务暂停")
		return condition+S.SERVICE[c.kind]+("\n"+status if status!="" else "")
	return "临河易涝，田堤可截住来水。" if V.tier(id)==0 else "地势较高，适合建粮仓或开田。"

func make_inspector(id: int):
	var s=sim.s
	var c=sim.s.cells[id]
	var height=448 if c.kind=="farm" else (310 if c.kind in S.FACILITIES else 220)
	side=U.panel(stage,1,0,1,0,Rect2i(-302,82,-18,82+height))
	side.set_meta("tile",id);side.set_meta("job",game.edge_job)
	var sc=ScrollContainer.new();sc.name="SiteScroll"
	sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	U.inset(side,12).add_child(sc)
	var v=U.box(true,7);v.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sc.add_child(v)
	v.add_child(U.label(V.address(id),13,U.GOLD))
	var job=game.edge_job if game.edge_job!="" else "t"+str(id)
	row_header(v,"田堤" if game.edge_job!="" else sim.location_name(id),"deselect")
	v.add_child(U.rule())
	var data=U.label(inspection(id),15,U.TEXT,true);v.add_child(data);refs.inspection=data
	if not sim.s.districts.has(V.sector(id)):
		var zone=V.sector(id)
		var open=btn("开通区域 · %d 粮 / 2 木" % E.LAND_PRICE[zone],"claim",zone,true)
		open.disabled=sim.s.food<E.LAND_PRICE[zone] or sim.s.wood<2;v.add_child(open)
		v.add_child(btn("派探险队并带回种源","survey_map",zone))
		return
	if V.sector(id)>0:
		var bin=E.warehouse(s,V.sector(id))
		v.add_child(U.label("当地仓　%d 粮　%d 种　%d 木　%d 石" % [bin.food,bin.seed,bin.wood,bin.stone],13,U.GOLD,true))
		v.add_child(btn("打开运输","shipping_map",V.sector(id)))
	if c.kind in S.Roads.WORKS or id==s.frontier.home:
		if c.connected: v.add_child(U.label("道路已接入农专",14,U.GREEN))
		else:
			v.add_child(U.label("断路 · "+("畜栏与拓殖运输待接入" if id==s.frontier.home else "此处暂停生产与服务"),15,U.WARN,true))
			var connector=btn("接入农专 · 预览道路","street_to",id,true)
			connector.disabled=S.Roads.root(s)<0;connector.tooltip_text="先建成农专，再从农专延伸道路。";v.add_child(connector)
	if sim.assigned(job)<sim.minimum_staff(job):
		v.add_child(U.label("缺工 · 至少需要 1 人到岗",15,U.WARN))
	if sim.capacity(job)>0 or sim.assigned(job)>0:
		var row=U.box(false,7);v.add_child(row);row.add_child(U.label("岗位人手",14,U.DIM));row.add_child(U.space())
		var minus=btn("－","assign",[job,-1]);minus.disabled=sim.assigned(job)==0
		var plus=btn("＋","assign",[job,1],true);plus.disabled=sim.free_workers()==0 or sim.assigned(job)>=sim.capacity(job)
		row.add_child(minus);row.add_child(plus)
		if sim.capacity(job)>sim.assigned(job) and sim.free_workers()==0:
			v.add_child(btn("从其他岗位调入","transfer_to",job))
	if game.edge_job!="":
		var key=job.substr(1)
		var e=sim.s.edges[key]
		if e.built and e.condition<100 and not e.repairing: v.add_child(btn("检修田堤 · 2 粮 / 1 木","repair_edge",key))
		if not e.built or e.repairing:
			refs.cancel_work=btn("撤工","cancel_project",job);v.add_child(refs.cancel_work)
		return
	if c.project!="":
		refs.cancel_work=btn("撤工","cancel_project",job);v.add_child(refs.cancel_work)
	if c.kind=="farm":
		var crop=S.F.Crops.field_species(s,id)
		v.add_child(U.label("本田 · "+S.F.Crops.title(crop)+"　下茬 · "+S.F.Crops.title(c.get("next_species",crop)),15,U.GOLD,true))
		for available in s.frontier.lines:
			if available!=c.get("next_species",crop): v.add_child(btn("下茬种"+S.F.Crops.title(available),"frontier_action",["sow",[id,available]]))
		var next=S.F.Crops.for_sowing(s,id)
		v.add_child(U.label("下茬%s · %s　用种 %d　预计饲料 %d" % [S.F.Crops.title(next[0]),next[1],S.F.Crops.seed_cost(s,next[0],next[1]),S.F.Crops.fodder(s,next[0])],14,U.GREEN,true))
		var shortfall=maxi(0,S.F.Crops.seed_cost(s,next[0],next[1])-E.warehouse(s,V.sector(id)).seed)
		if shortfall>0: v.add_child(btn("封存本田缺少的 %d 份种粮" % shortfall,"field_seed",id,true))
		for variant in s.frontier.varieties.get(next[0],{}):
			if variant!=next[1]: v.add_child(btn("改种"+variant,"frontier_action",["sow",[id,next[0],variant]]))
		if s.frontier.manure>0: Atlas.action(self,v,"施 1 厩肥 · 地力 +10","manure",id)
	if (id==s.frontier.home or c.kind=="house") and c.project=="": Management.recruit_button(self,v)
	if c.kind=="academy" and c.project=="":
		var claim=btn("领取 %d 点科技" % c.notes,"collect",id,c.notes>0)
		claim.disabled=c.notes<=0 or c.flood;v.add_child(claim)
		v.add_child(btn("查看科技树","panel","study"))
	if c.kind=="farm" and c.project=="":
		for item in [["rotate","谷豆轮作","rotation"],["precise","精准配肥","precise"],["scout","巡田防病","patrol"]]:
			if sim.s.tech.has(item[0]) and (item[2]=="patrol" or not c.get(item[2],false)):
				v.add_child(btn(item[1]+"  ·  2 粮","field",[id,item[2]]))
		if sim.s.era>=2: v.add_child(btn("堆肥养地  ·  2 粮","field",[id,"compost"]))
		if sim.s.tech.has("fertilizer"):
			v.add_child(btn("停用高投入 · 免费" if c.fertilized else "启用化肥 · 2 粮 · 尾水风险","field",[id,"fertilized"]))
	if id==s.frontier.home or c.kind=="store" or c.kind=="farm":
		v.add_child(btn("在本地封存两份种粮","site_reserve",V.sector(id)))
	if c.kind=="" and c.project=="" and V.tier(id)>=0 and game.edge_job=="":
		v.add_child(btn("在此开田","place_here",["farm",id]))
		if sim.academy_id()<0: v.add_child(btn("建农专 · 3 粮 / 3 木 / 1 石","place_here",["academy",id]))
		if V.tier(id)==0 and sim.s.tech.has("dike"): v.add_child(btn("在进水侧修堤","place_here",["levee",id]))
	for k in sim.s.edges:
		if game.edge_job=="" and sim.s.edges[k].a==id:
			v.add_child(btn("查看本段田堤","edge",k))
	if c.kind in S.FACILITIES and c.project=="":
		for key in ["upgrade","repair"]:
			if key=="upgrade" and c.level>=2: continue
			if key=="repair" and c.condition==100: continue
			var spec=S.BUILD[key]
			var b=btn("%s · %d 粮 · %s" % [spec[0],spec[2],E.input_text(key)],"site_work",[key,id])
			var why=sim.build_reason(key,id)
			b.disabled=why!="";b.tooltip_text=why;v.add_child(b)

func detail_tab() -> String:
	if panel_key=="study": return tech_branch
	if panel_key=="frontier": return frontier_tab
	if panel_key=="economy": return economy_tab
	return ""

func make_drawer():
	var w=840 if panel_key=="study" else 728 if panel_key=="frontier" else (632 if panel_key in ["crew","economy","transfer"] else 594)
	drawer=U.panel(stage,0.5,0.5,0.5,0.5,Rect2i(-w/2,-245,w/2,231),U.PANEL)
	drawer.set_meta("section",panel_key)
	drawer.set_meta("tab",detail_tab())
	var frame=U.box(true,8);U.inset(drawer,15).add_child(frame)
	var titles={"frontier":"农庄与拓殖地","build":"农业建设","study":"农学手册","crew":"人力总览","economy":"资源与收支","transfer":"跨岗调配","risk":"河谷灾情","log":"农事簿","era":"时代建设与晋阶"}
	row_header(frame,titles[panel_key]+("　·　"+S.F.REGIONS[sim.s.frontier.region] if panel_key=="frontier" else ""),"closepanel");frame.add_child(U.rule())
	if panel_key=="frontier": Atlas.tabs(self,frame)
	var scroll=ScrollContainer.new();scroll.name="ContentScroll";scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;frame.add_child(scroll)
	var content=U.box(true,7);content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
	match panel_key:
		"frontier": Atlas.draw(self,content)
		"build":
			content.add_child(btn("铺田间道路　·　G　·　选择起点与终点","street_start",-1,true))
			content.add_child(U.label("点工程选址，点已建成的设施可扩建、检修。完好度低于 50 会停用服务。",14,U.DIM,true))
			for key in S.BUILD:
				if key in ["repair","upgrade"]: continue
				var spec=S.BUILD[key]
				var b=btn("%s　 ·　 %d 粮 · %s　 /　 %d 人秒" % [spec[0],spec[2],E.input_text(key),spec[3]],"tool",key)
				b.disabled=spec[1]!="" and not sim.s.tech.has(spec[1])
				if b.disabled: b.text=spec[0]+"　·　需"+sim.tech_name(spec[1])
				if key=="academy" and sim.academy_id()>=0: b.disabled=true;b.text="农专　·　已设址"
				b.tooltip_text=S.SERVICE[key]
				content.add_child(b)
		"study": Research.draw(self,content)
		"crew": Management.workforce(self,content)
		"transfer": Management.transfers(self,content)
		"economy": Management.balance(self,content)
		"risk":
			content.add_child(U.label("上 / 中 / 下游污染　%d　/　%d　/　%d" % sim.s.water,16,U.GOLD))
			for item in [["flood","洪水可达低地"],["soil","田块地力"],["water","流域污染"],["crop","食害、草害与病害"],["","关闭图层"]]:
				content.add_child(btn(item[1],"overlay",item[0],item[0]==game.world.risk))
			content.add_child(U.label("夏汛和梅雨按农时预警。留意晾晒入仓、共渠引水、集中育秧与化肥投用带来的新风险。",14,U.DIM,true))
			for key in sim.s.cause:
				var entry=sim.s.cause[key]
				content.add_child(btn(S.CRISIS[key][0]+"　·　"+V.address(entry.tile),"jump",entry.tile))
		"era":
			var s=sim.s
			if s.era<3: content.add_child(U.label(era_forecast(),15,U.GOLD,true))
			var groups=T.requirements(sim)
			for group in groups:
				content.add_child(U.label(group+"条件",15,U.GOLD))
				for goal in groups[group]:
					content.add_child(U.label(("✓  " if goal[0] else "◇  ")+goal[1],14,U.GREEN if goal[0] else U.TEXT,true))
			var fee=T.ERA_FOOD[s.era]
			var summary="可用口粮 %d　·　拨付 %d　·　种粮 %d 单独留存" % [s.food,fee,s.seed]
			frame.add_child(U.label(summary,14,U.GOLD))
			var why=sim.advance_reason()
			var advance=btn("确认现代农业成果" if s.era==3 else "筹备进入"+S.ERAS[s.era+1],"review_era",null,why=="")
			advance.disabled=why!="";advance.tooltip_text=why;frame.add_child(advance)
		"log":
			content.add_child(U.label(sim.s.last_report if sim.s.last_report!="" else "第一季尚未结算。",15,U.GOLD,true))
			if not sim.s.last_ledger.is_empty():
				var previous=sim.s.last_ledger
				content.add_child(U.label("工程与农事 %d　·　检修与防御 %d　·　晋阶 %d　·　撤工退粮 %d\n播种 %d　·　灾损 %d　·　溢仓 %d　·　农专编成 %d 点" % [previous.build,previous.maintenance,previous.advance,previous.refund,previous.sow,previous.loss,previous.spoil,previous.science],14,U.DIM,true))
				if previous.has("ending"): content.add_child(U.label("粮种合计　期初 %d → 期末 %d" % [previous.opening,previous.ending],14,U.GOLD))
			for item in sim.s.log: content.add_child(U.label(item,14,U.TEXT,true))

func era_forecast() -> String:
	var s=sim.s
	return "晋阶后每田基础秋收 +%d 份，按当前设施和预算，每季公共支出从 %d 增至 %d 粮。" % [E.ERA_YIELD[s.era+1]-E.ERA_YIELD[s.era],E.budget(s).total,E.budget(s,s.era+1).total]

func dialog(kind: String):
	clear_detail(modal);modal=null
	if kind=="": return
	modal=ColorRect.new()
	modal.color=Color(0.035,0.065,0.047,0.55)
	stage.add_child(modal);modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter=Control.MOUSE_FILTER_STOP
	var bounds=Rect2i(-349,-249,349,249) if kind=="difficulty" else (Rect2i(-300,-212,300,212) if kind=="crisis" else Rect2i(-257,-179,257,176))
	var card=U.panel(modal,0.5,0.5,0.5,0.5,bounds,Color(0.095,0.145,0.115,0.99))
	var body=U.box(true,9);U.inset(card,22).add_child(body)
	var s=sim.s
	match kind:
		"difficulty":
			Atlas.habitats(self,body)
		"crisis":
			var event=S.CRISIS[s.pending]
			body.add_child(U.label("农情急报    /    "+sim.date()+"    /    时间已暂停",13,U.WARN))
			body.add_child(title_label(event[0],31));body.add_child(U.rule())
			if s.pending=="blight" and not s.frontier.disease.is_empty(): Atlas.disease(body,s.frontier.disease)
			else: body.add_child(U.label(event[1],16,U.TEXT,true))
			if s.cause.has(s.pending):
				var source=s.cause[s.pending]
				body.add_child(U.label(V.address(source.tile)+"　·　"+source.why,14,U.GOLD,true))
			for j in 2:
				var b=btn(event[2+2*j],"decision",j,j==0);b.disabled=s.food<sim.response_cost(s.pending,j);body.add_child(b)
				body.add_child(U.label(event[3+2*j],14,U.DIM,true))
		"advance":
			var fee=T.ERA_FOOD[s.era]
			body.add_child(U.label(sim.date()+"　/　聚落议事",14,U.GOLD))
			body.add_child(title_label("确认现代农业成果" if s.era==3 else "进入"+S.ERAS[s.era+1],29))
			body.add_child(U.rule())
			body.add_child(U.label("建设、科技和生存条件已满足。现有 %d 份口粮，拨付 %d 份后余 %d 份，下季需 %d 份。%d 份种粮单独留存。" % [s.food,fee,s.food-fee,s.pop,s.seed],17,U.TEXT,true))
			if s.era<3: body.add_child(U.label(era_forecast(),15,U.GOLD,true))
			body.add_child(btn("确认完成战役" if s.era==3 else "拨付 %d 份口粮，启程" % fee,"advance",s.era,true))
			body.add_child(btn("继续在本时代经营","back"))
		"end":
			var victory=s.outcome=="won"
			body.add_child(U.label(S.ROMAN[s.era]+"  "+S.ERAS[s.era]+"    /    "+sim.date(),14,U.GOLD))
			body.add_child(title_label("谷满江清" if victory else "江岸散炊",38))
			body.add_child(U.rule())
			body.add_child(U.label(("疫后秋粮入仓。河谷留住了种粮与清水。" if s.after_blight else "分散育秧的田块迎来了现代秋收，河谷留住了种粮与清水。") if victory else s.end_reason+" 最近一次供粮 %d / %d 份。" % [s.last_served,s.last_need],17,U.TEXT,true))
			body.add_child(U.label("口粮 %d 份   ·   种粮 %d 份   ·   下游污染 %d" % [s.food,s.seed,s.water[2]],15,U.GOLD))
			if not victory: body.add_child(btn("从本时代起点重试","retry",null,true))
			body.add_child(btn("返回主菜单","title",null,victory))
		"lesson_book":
			body.add_child(title_label("入门田课",28));body.add_child(U.rule())
			for i in S.Lesson.STEPS.size(): body.add_child(U.label("✓　"+S.Lesson.STEPS[i][0],16,U.GREEN))
			body.add_child(btn("回到战役","back",null,true))
		"pause":
			body.add_child(U.label("战役暂停    /    "+sim.date(),14,U.GOLD));body.add_child(title_label("河谷歇晌",30))
			body.add_child(btn("回到河谷","back",null,true))
			body.add_child(btn("重新打开入门田课","lesson_open"))
			body.add_child(btn("保存进度","save"));body.add_child(btn("读取最近存档","load"))
			body.add_child(btn("游戏设置","settings"));body.add_child(btn("保存并返回主菜单","title"))
		"settings":
			body.add_child(title_label("游戏设置",29));body.add_child(U.rule())
			body.add_child(btn("环境与提示音　·　"+("开启" if game.audio.enabled else "关闭"),"sound"))
			body.add_child(btn("显示模式　·　"+("全屏" if game.fullscreen() else "窗口"),"fullscreen"))
			body.add_child(U.label("空格暂停　　1 / 2 / 3 调速　　Esc 返回\nB 建设　T 农学　G 道路　J 入门田课\n中键拖拽或 WASD 平移　　滚轮缩放\n左键选址与确认　　右键取消　　R 切换堤边",15,U.DIM,true))
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
