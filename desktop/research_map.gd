extends VBoxContainer

const U = preload("res://paper.gd")
const R = preload("res://agronomy.gd")
const C = preload("res://crop_book.gd")
const CUR = preload("res://curriculum.gd")
const LANES = ["作物与育种", "耕作与农具", "水土与防灾", "仓储与贸易", "农业组织"]
const AGES = ["原始采集", "早期农耕", "传统农耕", "现代农业"]
const H = preload("res://handbook_style.gd")
const LANE_COLORS = [Color("#bed29a"),Color("#dec18b"),Color("#90c7c5"),Color("#dcae92"),Color("#abb6db")]
const GAP = Vector2(263, 77)
const REQUIRED = Color("#668274")
const ALTERNATIVE = Color("#92adcb")
const SUPPORT = Color("#89cfc6")

class AssistLines extends Control:
	var graph: GraphEdit
	var nodes: Dictionary
	var links: Array
	var selected = ""
	var last_zoom = -1.0
	var last_scroll = Vector2.INF

	func _process(_dt):
		if is_equal_approx(graph.zoom, last_zoom) and graph.scroll_offset == last_scroll: return
		last_zoom = graph.zoom
		last_scroll = graph.scroll_offset
		queue_redraw()

	func _draw():
		for edge in links:
			var source: GraphNode = nodes[edge[0]]
			var target: GraphNode = nodes[edge[1]]
			var start = (source.position_offset + Vector2(source.size.x, source.size.y * 0.7)) * graph.zoom - graph.scroll_offset
			var finish = (target.position_offset + Vector2(0, target.size.y * 0.7)) * graph.zoom - graph.scroll_offset
			if (start.x < 0 and finish.x < 0) or (start.x > size.x and finish.x > size.x): continue
			if (start.y < 0 and finish.y < 0) or (start.y > size.y and finish.y > size.y): continue
			var highlighted = selected in edge
			var tone = SUPPORT if highlighted else Color(SUPPORT, 0.42)
			var reach = minf(140.0 * graph.zoom, (finish.x - start.x) * 0.5)
			var curve = Curve2D.new()
			curve.bake_interval = 6.0
			curve.add_point(start, Vector2.ZERO, Vector2(reach, 0))
			curve.add_point(finish, Vector2( - reach, 0), Vector2.ZERO)
			var length = curve.get_baked_length()
			for step in range(0, ceili(length), 13):
				draw_line(curve.sample_baked(step), curve.sample_baked(minf(step + 7.0, length)), tone, 2.2 if highlighted else 1.25, true)


var hud
var model
var graph: GraphEdit
var assist_lines: AssistLines
var assists = []
var topic_scroll: ScrollContainer
var topic_details: VBoxContainer
var bank: Label
var study_status: Label
var study_progress: ProgressBar
var academy: Button
var focus_button: Button
var selected_action: Button
var active: Button
var scope: Button
var search: LineEdit
var locate: Button
var filter_menu: OptionButton
var search_result: Label
var filters: Array = []
var branch = ""
var local_view = false
var nodes = {}
var connections = []
var era_lefts = []
var displayed = []
var rendered_key = ""
var detail_signature = []
var focus_key = ""

static func visible_topic(m, key: String) -> bool:
	if not m.techs.has(key) or not CUR.eligible_region(m.s, key): return false
	var crop = R.subject(key)
	return crop == "" or R.discovered(m.s, crop)

static func lane_for(key: String) -> String:
	if R.subject(key) != "" or key == "seed": return LANES[0]
	if key in ["cooperative", "large_field_management", "apprentice", "machine_pool"]: return LANES[4]
	if key in ["dry", "winnow", "harvest_network"] or R.discipline(key) == "经济": return LANES[3]
	if key in ["dike", "scout", "terrace", "fertilizer", "precise"] or R.discipline(key) == "防灾": return LANES[2]
	if R.discipline(key) == "育种": return LANES[0]
	return LANES[1]

static func parents(m, key: String) -> Array:
	var result = []
	for group in R.prerequisites(m.techs, key): result.append_array(group.keys)
	return result

static func children(m, key: String) -> Array:
	var result = []
	for id in m.techs:
		if visible_topic(m, id) and key in parents(m, id): result.append(id)
	return result

static func category(m, key: String) -> Array:
	if key in R.LAND_OPTIONS: return ["择一路", Color("#293e58"), ALTERNATIVE]
	for required in m.Town.CORE:
		if key in required: return ["必修", Color("#463823"), U.GOLD]
	return ["选修", Color("#182f28"), Color("#689681")]

static func state_label(m, key: String) -> Array:
	if key in m.s.tech: return ["已掌握", U.GREEN, Color("#213c32")]
	if key == m.s.study: return ["在研", ALTERNATIVE, Color("#203943")]
	if m.s.era >= m.techs[key][1] and m.research_reason(key) == "":
		return ["可研究", U.GOLD, Color("#343b2c")]
	return ["待解锁", U.DIM, Color("#162823")]

static func depth(key: String, table: Dictionary, included: Array, memo: Dictionary) -> int:
	if memo.has(key): return memo[key]
	var column = 0
	var links = R.aids(key).duplicate()
	for group in R.prerequisites(table, key): links.append_array(group.keys)
	for pre in links:
		if pre in included and table[pre][1] == table[key][1]:
			column = maxi(column, 1 + depth(pre, table, included, memo))
	memo[key] = column
	return column

func setup(h, target: String = "", crop: String = ""):
	hud = h
	model = h.sim
	add_theme_constant_override("separation", 10)
	branch = h.research_camera.get("branch", "")
	local_view = h.research_camera.get("local", false)

	var head = U.box(false, 10);add_child(head)
	head.add_child(U.icon("study",34,U.GOLD))
	head.add_child(h.title_label("农学科技树",29))
	head.add_child(U.label(C.REGIONS[model.s.frontier.region] + "　/　" + model.ERAS[model.s.era],14,U.DIM))
	head.add_child(U.space())
	bank = U.label("", 14, U.GOLD);head.add_child(bank)
	academy = h.btn("前往农专", "academy");head.add_child(academy)
	focus_button = h.btn("确立专精", "study_focus");head.add_child(focus_button)
	head.add_child(h.btn("返回河谷", "closepanel"))
	add_child(U.rule())

	var body = U.box(false, 13)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL;add_child(body)
	var sheet = PanelContainer.new()
	sheet.custom_minimum_size.x = 326
	sheet.add_theme_stylebox_override("panel", U.style(H.PAPER,Color("#aa986c"),1,5))
	body.add_child(sheet)
	var left = U.box(true, 8);U.inset(sheet, 12).add_child(left)
	topic_scroll = ScrollContainer.new()
	topic_scroll.name = "TopicScroll"
	topic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	topic_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL;left.add_child(topic_scroll)
	selected_action = U.button("", func(): hud.call_action("research", hud.tech_key), true)
	selected_action.set_meta("command", "research")
	left.add_child(selected_action)
	left.add_child(U.rule())
	var footer = U.box(false, 6);left.add_child(footer)
	footer.add_child(U.label("当前研习", 14,H.MUTED));footer.add_child(U.space())
	active = h.btn("定位在研", "locate_study");active.disabled = true;footer.add_child(active)
	study_status = U.label("",14,H.JADE,true);left.add_child(study_status)
	study_progress = ProgressBar.new()
	study_progress.show_percentage = false
	study_progress.custom_minimum_size.y = 5
	study_progress.add_theme_stylebox_override("background", U.style(Color("#233732"), Color.TRANSPARENT, 0, 2))
	study_progress.add_theme_stylebox_override("fill", U.style(U.GREEN, Color.TRANSPARENT, 0, 2))
	left.add_child(study_progress)

	var right = U.box(true, 7)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL;body.add_child(right)
	var ages = U.box(false, 6);right.add_child(ages)
	for era in AGES.size():
		var b = H.tab(h,model.ROMAN[era] + "　" + AGES[era],"map_era",era,era == model.s.era,U.GOLD)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = model.ERAS[era];ages.add_child(b)
	var tools = U.box(false, 6);right.add_child(tools)
	filter_menu = OptionButton.new()
	filter_menu.name = "ResearchBranch"
	filter_menu.tooltip_text = "按分支或作物筛选"
	filter_menu.custom_minimum_size.x = 150
	update_filters()
	filter_menu.item_selected.connect(change_branch)
	tools.add_child(filter_menu)
	scope = U.button("", toggle_scope); scope.set_meta("command","map_scope"); tools.add_child(scope)
	search = LineEdit.new()
	search.name = "ResearchSearch"
	search.placeholder_text = "搜索课题"
	search.clear_button_enabled = true
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.custom_minimum_size.x = 130
	search.text = h.research_camera.get("query", "")
	search.text_changed.connect( func(_value): update_page())
	search.text_submitted.connect( func(_value): locate_match())
	tools.add_child(search)
	locate = U.button("定位", locate_match)
	locate.set_meta("command", "map_search")
	tools.add_child(locate)
	for delta in [-1, 1]:
		tools.add_child(U.button("缩小" if delta < 0 else "放大", scale_view.bind(delta)))

	graph = GraphEdit.new()
	graph.name = "ResearchGraph"
	graph.show_grid = false
	graph.clip_contents = true
	graph.show_menu = false
	graph.minimap_enabled = false
	graph.snapping_enabled = false
	graph.connection_lines_thickness = 2.0
	graph.connection_lines_curvature = 0.36
	graph.connection_lines_antialiased = true
	graph.zoom_min = 0.5
	graph.zoom_max = 1.3
	graph.zoom = h.research_camera.get("zoom", 1.0)
	graph.add_theme_stylebox_override("panel", U.style(H.NIGHT,Color("#576d5f"),1,4))
	graph.add_theme_color_override("activity", U.GOLD)
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL;right.add_child(graph)
	assist_lines = AssistLines.new()
	assist_lines.graph = graph
	assist_lines.nodes = nodes
	assist_lines.links = assists
	assist_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	assist_lines.z_index = 1
	graph.add_child(assist_lines)
	assist_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var legend = U.box(false, 11)
	right.add_child(legend)
	legend.add_child(U.label("━ 必须", 13, U.GREEN))
	legend.add_child(U.label("━ 择一必需", 13, ALTERNATIVE))
	legend.add_child(U.label("┄ 辅助科技", 13, SUPPORT))
	legend.add_child(U.label("WASD / 中键平移", 13, U.DIM))
	legend.add_child(U.space())
	search_result = U.label("", 13, U.DIM)
	legend.add_child(search_result)

	if crop in C.NAMES and R.discovered(model.s, crop):
		open_crop(crop)
	elif visible_topic(model, target):
		select_topic(target, true)
	else:
		update_page()
		if h.research_camera.has("scroll"): restore_scroll.call_deferred(h.research_camera.scroll)
		else: jump_era(model.s.era)

func remember():
	hud.research_camera = {"zoom": graph.zoom, "scroll": graph.scroll_offset, "branch": branch, "local": local_view, "query": search.text}

func restore_scroll(value: Vector2):
	if is_inside_tree(): graph.scroll_offset = value

func pan_keyboard(direction: Vector2, dt: float):
	if search.has_focus() or filter_menu.get_popup().visible: return
	graph.scroll_offset += direction.normalized() * dt * 550.0

func scale_view(direction: int):
	graph.zoom = clampf(graph.zoom * pow(1.16, direction), graph.zoom_min, graph.zoom_max)

func update_filters():
	var choices = [""] + LANES + C.NAMES.filter( func(crop): return R.discovered(model.s, crop))
	if choices == filters: return
	filters = choices
	if branch not in filters: branch = ""
	filter_menu.clear()
	for item in filters:
		var title = "全部分支" if item == "" else C.title(item) if item in C.NAMES else item
		filter_menu.add_item(title)
	filter_menu.select(filters.find(branch))

func matches(key: String) -> bool:
	var query = search.text.strip_edges().to_lower()
	if query == "": return false
	if query in model.tech_name(key).to_lower(): return true
	var crop = R.subject(key)
	return crop != "" and query in C.title(crop)

func shown_topics() -> Array:
	if local_view:
		var current = hud.tech_key
		var topics = [current] + parents(model, current) + children(model, current)
		for key in R.aids(current):
			if key not in topics: topics.append(key)
		for key in R.ASSISTS:
			if current in R.aids(key) and key not in topics: topics.append(key)
		return topics.filter( func(key): return visible_topic(model, key))
	var result = []
	for key in model.techs:
		if not visible_topic(model, key): continue
		if branch in C.NAMES:
			if R.subject(key) == branch or (key in ["seed", "dry"] and branch == C.START[model.s.frontier.region]): result.append(key)
		elif branch == "" or lane_for(key) == branch:
			result.append(key)
	return result

func change_branch(index: int):
	branch = filters[index]
	local_view = false
	redraw()
	if hud.tech_key in nodes: center_at.call_deferred(hud.tech_key)
	elif not displayed.is_empty(): select_topic(displayed[0], true)

func toggle_scope():
	local_view = not local_view
	redraw()
	center_at.call_deferred(hud.tech_key)

func locate_match():
	for key in model.techs:
		if visible_topic(model, key) and matches(key):
			select_topic(key, true)
			return

func select_topic(key: String, center: bool):
	if not visible_topic(model, key): return
	hud.tech_key = key
	if center and not local_view and key not in shown_topics():
		branch = ""
		filter_menu.select(filters.find(branch))
	update_page()
	if center or local_view: center_at.call_deferred(key)

func open_crop(crop: String):
	if crop not in C.NAMES or not R.discovered(model.s, crop): return
	update_filters()
	branch = crop
	local_view = false
	filter_menu.select(filters.find(branch))
	select_topic(R.id(crop, 0), true)

func jump_era(era: int):
	if local_view:
		local_view = false
		redraw()
	scroll_to_era.call_deferred(era)

func scroll_to_era(era: int):
	if is_inside_tree() and era < era_lefts.size():
		graph.scroll_offset = Vector2(era_lefts[era] * graph.zoom - 14.0, -9.0)

func center_at(key: String):
	if not is_inside_tree() or not nodes.has(key): return
	var node = nodes[key]
	var center = node.position_offset + node.size * 0.5
	if local_view:
		var bounds = Rect2(node.position_offset,node.size)
		for card in nodes.values(): bounds = bounds.merge(Rect2(card.position_offset,card.size))
		if bounds.size.x * graph.zoom < graph.size.x - 24: center.x = bounds.get_center().x
		if bounds.size.y * graph.zoom < graph.size.y - 50: center.y = bounds.get_center().y - 12
	graph.scroll_offset = center * graph.zoom - graph.size * 0.5

func redraw():
	displayed = []
	update_page()

func update_page():
	if not is_instance_valid(graph): return
	update_filters()
	if not visible_topic(model, hud.tech_key): hud.tech_key = "seed"
	var s = model.s
	var id = model.academy_id()
	var pending = s.cells[id].notes if id >= 0 else 0
	var level = s.cells[id].level if id >= 0 else 1
	bank.text = "札记　%d 已领 · %d 待领   /   %d 案藏" % [s.science, pending, R.limit(s, level)]
	academy.text = "前往农专" if id >= 0 else "选址建农专"
	focus_button.text = "确立专精" if s.research_record.focus == "" else s.research_record.focus + "专精"
	var studying = visible_topic(model, s.study)
	active.disabled = not studying
	study_progress.visible = studying
	if studying:
		study_progress.max_value = s.research_record.get("study_total", R.timing(model.techs[s.study]))
		study_progress.value = study_progress.max_value - s.study_time
	study_status.text = "暂无在研课题" if not studying else U.wrap_text(model.tech_name(s.study) + "　" + model.study_status())
	scope.text = "返回全树" if local_view else "本课脉络"
	var keys = shown_topics()
	if displayed != keys or (not local_view and era_lefts.is_empty()): draw_graph(keys)
	var found = 0
	for key in model.techs:
		if visible_topic(model, key) and matches(key): found += 1
	locate.disabled = found == 0
	if search.text.strip_edges() != "":
		search_result.text = "找到 %d 项" % found if found > 0 else "未找到课题"
	else:
		search_result.text = "当前显示 %d 项课题" % displayed.size()
	update_cards()
	update_detail()

func update_detail():
	var key = hud.tech_key
	var s = model.s
	var why = model.research_reason(key)
	var requirements = [] if key in s.tech or key == s.study else model.research_requirements(key)
	var signature = [key, s.tech.duplicate(), s.study, s.research_record.focus, requirements]
	if detail_signature != signature:
		var scroll = topic_scroll.scroll_vertical if rendered_key == key else 0
		detail_signature = signature
		rendered_key = key
		if is_instance_valid(topic_details):
			topic_scroll.remove_child(topic_details);topic_details.queue_free()
		topic_details = U.box(true, 9)
		topic_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		topic_scroll.add_child(topic_details)
		hud.Research.draw_detail(hud, topic_details, key, requirements)
		topic_scroll.set_deferred("scroll_vertical", scroll)
	selected_action.set_meta("arg", key)
	selected_action.disabled = why != ""
	selected_action.tooltip_text = why
	if key in s.tech: selected_action.text = "已掌握"
	elif key == s.study: selected_action.text = "研习进行中"
	elif why != "": selected_action.text = "研习条件未齐"
	else: selected_action.text = "开始研习 · %d 人秒" % R.research_time(s, key, model.techs[key])

func draw_graph(keys: Array):
	var offset = graph.scroll_offset
	graph.clear_connections()
	for child in graph.get_children():
		if child is GraphElement:
			graph.remove_child(child);child.queue_free()
	displayed = keys
	nodes.clear()
	connections.clear()
	era_lefts.clear()
	assists.clear()
	focus_key = ""
	if local_view:
		draw_neighborhood(keys)
	else:
		draw_lanes(keys)
	connect_topics(keys)
	graph.scroll_offset = offset
	assist_lines.queue_redraw()

func draw_lanes(keys: Array):
	var rank = {}
	var widths = [1, 1, 1, 1]
	var rows = {}
	var heights = [0, 0, 0, 0, 0]
	for key in keys:
		var era = model.techs[key][1]
		var lane = LANES.find(lane_for(key))
		var col = depth(key, model.techs, keys, rank)
		var slot = Vector3i(era, lane, col)
		rows[key] = rows.get(slot, 0)
		rows[slot] = rows[key] + 1
		heights[lane] = maxi(heights[lane], rows[slot])
		widths[era] = maxi(widths[era], col + 1)
	var lane_top = []
	var bottom = 52.0
	for height in heights:
		lane_top.append(bottom)
		if height > 0: bottom += 32.0 + height * GAP.y
	var start = 0.0
	for era in AGES.size():
		era_lefts.append(start)
		add_era_frame(era, start, widths[era] * GAP.x + 18, bottom)
		for lane in LANES.size():
			if keys.any( func(key): return model.techs[key][1] == era and lane_for(key) == LANES[lane]):
				add_lane_heading(LANES[lane], Vector2(start + 13, lane_top[lane]))
		start += widths[era] * GAP.x + 68
	for key in keys:
		var era = model.techs[key][1]
		var lane = LANES.find(lane_for(key))
		add_topic(key, Vector2(era_lefts[era] + 13 + rank[key] * GAP.x, lane_top[lane] + 26 + rows[key] * GAP.y))

func connect_topics(keys: Array):
	for key in keys:
		for group in R.prerequisites(model.techs, key):
			var port = 1 if group.mode == "any" else 0
			for pre in group.keys:
				if not nodes.has(pre) or (local_view and hud.tech_key not in [pre,key]): continue
				graph.connect_node(pre, 0, key, port)
				connections.append([pre, key, port])
		for pre in R.aids(key):
			if nodes.has(pre) and (not local_view or hud.tech_key in [pre,key]): assists.append([pre,key])

func draw_neighborhood(keys: Array):
	var target = hud.tech_key
	var before = parents(model,target) + R.aids(target)
	var columns = [[],[target],[]]
	for key in keys:
		if key == target: continue
		var column = 0 if key in before else 2
		if key not in columns[column]: columns[column].append(key)
	var height = maxi(columns[0].size(),maxi(1,columns[2].size()))
	for i in 3:
		if columns[i].is_empty(): continue
		var x = (i-1)*GAP.x
		var y = (height-columns[i].size()) * GAP.y / 2.0
		add_lane_heading(["先修与辅助","当前课题","后续应用"][i],Vector2(x,y-31))
		for j in columns[i].size(): add_topic(columns[i][j],Vector2(x,y+j*GAP.y))

func add_era_frame(era: int, x: float, width: float, height: float):
	var frame = GraphFrame.new()
	frame.name = "Era" + str(era)
	frame.title = model.ROMAN[era] + "　" + model.ERAS[era]
	frame.position_offset = Vector2(x, 0)
	frame.size = Vector2(width, height)
	frame.autoshrink_enabled = false
	frame.draggable = false
	frame.resizable = false
	frame.selectable = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill = Color("#182b25") if era % 2 == 0 else Color("#142621")
	frame.add_theme_stylebox_override("panel", U.style(fill, Color("#39564d"), 1, 4))
	frame.add_theme_stylebox_override("titlebar", U.style(Color("#263e34"), Color("#466354"), 1, 4))
	frame.add_theme_color_override("title_color", U.GOLD if era == model.s.era else U.DIM)
	graph.add_child(frame)

func plain_node(pos: Vector2) -> GraphNode:
	var node = GraphNode.new()
	node.position_offset = pos
	node.draggable = false
	node.resizable = false
	node.selectable = false
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for style_name in ["panel", "panel_selected", "titlebar", "titlebar_selected"]:
		node.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	node.add_theme_constant_override("separation", 0)
	graph.add_child(node)
	node.get_titlebar_hbox().hide()
	return node

func add_lane_heading(title: String, pos: Vector2):
	var node = plain_node(pos)
	var tint = LANE_COLORS[LANES.find(title)] if title in LANES else U.GOLD
	var label = H.stamp(title,Color("#2b443a"),tint); node.add_child(label)

func add_topic(key: String, pos: Vector2):
	var node = plain_node(pos)
	node.name = key
	node.z_index = 2
	var button = U.button("", func(): select_topic(key, false))
	button.set_meta("command", "tech_node")
	button.set_meta("arg", key)
	button.custom_minimum_size = Vector2(214,58)
	button.add_theme_font_size_override("font_size", 15)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.add_child(button)
	var title = U.label(model.tech_name(key),17,U.TEXT)
	title.name = "TopicTitle"; button.add_child(title)
	U.rect(title,0,0,1,0,Rect2i(12,4,-8,32))
	var caption = U.label("",12,U.DIM); caption.name = "Caption"; button.add_child(caption)
	U.rect(caption,0,0,1,1,Rect2i(12,31,-8,-2))
	button.tooltip_text = model.tech_name(key)
	node.set_slot(0, true, 0, REQUIRED, true, 0, REQUIRED)
	if R.prerequisites(model.techs, key).any( func(group): return group.mode == "any"):
		var anchor = Control.new()
		anchor.custom_minimum_size.y = 2
		anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(anchor)
		node.set_slot(1, true, 0, ALTERNATIVE, false, 0, REQUIRED)
	nodes[key] = node

func update_cards():
	for key in nodes:
		var node = nodes[key]
		var button = node.get_child(0)
		var state = state_label(model, key)
		var fee = R.notes(model.s, key, model.techs[key])
		var selected = key == hud.tech_key
		var match_found = matches(key)
		var signature = [state[0], fee, selected, match_found]
		if node.get_meta("display", []) == signature: continue
		node.set_meta("display", signature)
		var kind = category(model, key)
		button.accessibility_name = model.tech_name(key) + "，" + state[0]
		button.get_node("TopicTitle").add_theme_color_override("font_color",U.GOLD if selected else U.TEXT)
		var caption = button.get_node("Caption")
		caption.text = "%s　·　%s　·　%d 札记" % [kind[0],state[0],fee]
		caption.add_theme_color_override("font_color",state[1])
		var border = U.GOLD if selected or match_found else kind[2]
		var surface = U.style(Color("#4e4933") if selected else state[2],border,2 if (selected or match_found) else 1,4)
		surface.border_width_left = 4
		if not selected and not match_found: surface.border_color = LANE_COLORS[LANES.find(lane_for(key))].darkened(0.18)
		surface.content_margin_left = 10
		surface.content_margin_right = 8
		button.add_theme_stylebox_override("normal", surface)
	if focus_key != hud.tech_key:
		focus_key = hud.tech_key
		assist_lines.selected = focus_key
		assist_lines.queue_redraw()
		for edge in connections:
			graph.set_connection_activity(edge[0], 0, edge[1], edge[2], 1.0 if focus_key in [edge[0], edge[1]] else 0.0)
