extends RefCounted

const U = preload("res://paper.gd")
const R = preload("res://agronomy.gd")
const CUR = preload("res://curriculum.gd")
const GAP = Vector2(228, 108)
const CHOICE = Color("#80bfca")

static func visible_topic(m, key: String) -> bool:
	var crop = R.subject(key)
	return CUR.eligible_region(m.s, key) and (crop == "" or R.discovered(m.s, crop))

static func children(m, key: String) -> Array:
	var result = []
	for child in m.techs:
		if visible_topic(m, child) and key in CUR.parents(child, m.techs[child]): result.append(child)
	return result

static func state_label(m, key: String) -> Array:
	var label = m.research_check(key)[0]
	var color = U.DIM
	match label:
		"已掌握": color = U.GREEN
		"在研", "待备料", "待领札记": color = U.WARN
		"可研习": color = U.GOLD
		"待择径", "待实践": color = CHOICE
	return [label, color]

static func node_for(h, graph, key: String, pos: Vector2, current: String):
	var m = h.sim
	var info = state_label(m, key)
	var node = GraphNode.new()
	node.name = key
	node.title = "%s · %s · %s" % [m.ROMAN[m.techs[key][1]], R.chapter(key), info[0]]
	node.draggable = false
	node.position_offset = pos
	node.custom_minimum_size.x = 194
	graph.add_child(node)
	var button = h.btn(m.tech_name(key), "goto_tech", key, key == current)
	button.custom_minimum_size = Vector2(168, 29)
	var reason = m.research_reason(key)
	button.tooltip_text = reason if reason != "" else "可开题 · 点击查看"
	node.add_child(button)
	node.set_slot(0, true, 0, U.GOLD, true, 0, info[1])
	if not CUR.paths(key).is_empty():
		node.add_child(U.label("任选一路", 12, CHOICE))
		node.set_slot(1, true, 0, CHOICE, false, 0, CHOICE)

static func route_node(h, graph, key: String, i: int, pos: Vector2) -> String:
	var path = CUR.paths(key)[i]
	var met = CUR.path_met(h.sim, path)
	var junction = GraphNode.new()
	junction.name = "route_" + str(i)
	junction.title = ("✓ " if met else "◇ ") + path.name
	junction.draggable = false
	junction.position_offset = pos
	junction.custom_minimum_size.x = 176
	graph.add_child(junction)
	var detail = CUR.field_label(h.sim, path.field) if path.has("field") else "完成相连课题"
	junction.add_child(U.label(detail, 13, U.GREEN if met else U.DIM))
	junction.set_slot(0, true, 0, CHOICE, true, 0, CHOICE)
	junction.tooltip_text = CUR.requirements_text(h.sim, path)
	return str(junction.name)

static func depth(key: String, table: Dictionary, memo: Dictionary) -> int:
	if memo.has(key): return memo[key]
	var result = 0
	for pre in CUR.parents(key, table[key]):
		if table[pre][1] == table[key][1]: result = maxi(result, 1 + depth(pre, table, memo))
	memo[key] = result
	return result

static func layout_all(m) -> Dictionary:
	var pos = {}
	var memo = {}
	var offset = 0
	for era in 4:
		var counts = {}
		var width = 0
		for chapter in CUR.TRACKS:
			for id in m.techs:
				if m.techs[id][1] != era or R.chapter(id) != chapter or not visible_topic(m, id): continue
				var column = depth(id, m.techs, memo)
				pos[id] = Vector2(offset + column, counts.get(column, 0)) * GAP
				counts[column] = counts.get(column, 0) + 1
				width = maxi(width, column + 1)
		offset += width
	return pos

static func link(graph, m, parent: String, child: String):
	var port = 0 if parent in m.techs[child][3] else 1
	graph.connect_node(parent, 0, child, port)

static func overview(h, graph, key: String) -> Vector2:
	var pos = layout_all(h.sim)
	for id in pos: node_for(h, graph, id, pos[id], key)
	for child in pos:
		for parent in CUR.parents(child, h.sim.techs[child]):
			if pos.has(parent): link(graph, h.sim, parent, child)
	return pos[key]

static func vertical(i: int, count: int) -> float:
	return (i - (count-1) / 2.0) * GAP.y

static func local_map(h, graph, key: String) -> Vector2:
	var m = h.sim
	var spec = m.techs[key]
	var routes = CUR.paths(key)
	var next = children(m, key)
	var rows = spec[3].size()
	for path in routes: rows += maxi(1, path.tech.size())
	var mid = GAP.y * maxf(rows - 1, 0) * 0.5
	var pos = Vector2(GAP.x * (1 if routes.is_empty() else 2), mid)
	node_for(h, graph, key, pos, key)
	var common_x = 0.0 if routes.is_empty() else GAP.x
	for i in spec[3].size():
		var parent = spec[3][i]
		node_for(h, graph, parent, Vector2(common_x, i * GAP.y), key)
		link(graph, m, parent, key)
	var row = spec[3].size()
	for i in routes.size():
		var path = routes[i]
		var height = maxi(1, path.tech.size())
		var route = route_node(h, graph, key, i, Vector2(GAP.x, (row + (height-1)*0.5) * GAP.y))
		for j in path.tech.size():
			var parent = path.tech[j]
			if not graph.has_node(NodePath(parent)): node_for(h, graph, parent, Vector2(0,(row+j)*GAP.y), key)
			graph.connect_node(parent, 0, route, 0)
		graph.connect_node(route, 0, key, 1)
		row += height
	for i in next.size():
		node_for(h, graph, next[i], pos + Vector2(GAP.x, vertical(i, next.size())), key)
		link(graph, m, key, next[i])
	return pos - Vector2(50, 0) if not routes.is_empty() else pos

static func center_at(graph: GraphEdit, pos: Vector2):
	if is_instance_valid(graph) and graph.is_inside_tree():
		graph.scroll_offset = (pos + Vector2(98, 40)) * graph.zoom - graph.size * 0.5

static func show(h, overlay):
	var card = U.panel(overlay, 0.5, 0.5, 0.5, 0.5, Rect2i(-560,-285,560,285))
	var page = U.box(true, 8); U.inset(card, 15).add_child(page)
	var row = U.box(false, 8); page.add_child(row)
	row.add_child(h.title_label("农学课题图", 24))
	row.add_child(U.space())
	row.add_child(h.btn("本课脉络", "map_mode", false, not h.map_overview))
	row.add_child(h.btn("全树", "map_mode", true, h.map_overview))
	row.add_child(h.btn("返回手册", "back"))
	page.add_child(U.label("金色入口为共同前置，青色入口任选一路。点课题查看投入与条件。", 14, U.TEXT))
	var graph = GraphEdit.new()
	graph.show_grid = false
	graph.show_grid_buttons = false
	graph.show_arrange_button = false
	graph.minimap_enabled = h.map_overview
	graph.zoom_min = 0.3
	graph.zoom = 0.85 if h.map_overview else 1.0
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size.y = 350
	page.add_child(graph)
	var key = h.tech_key
	var pos = overview(h, graph, key) if h.map_overview else local_map(h, graph, key)
	var guide = U.box(false, 15); page.add_child(guide)
	guide.add_child(U.label("● 共同前置", 13, U.GOLD))
	guide.add_child(U.label("● 备选路线", 13, CHOICE))
	guide.add_child(U.space())
	guide.add_child(U.label("中键拖动 · 图上按钮缩放", 13, U.DIM))
	center_at.call_deferred(graph, pos)
