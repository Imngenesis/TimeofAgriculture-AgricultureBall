extends RefCounted

const U = preload("res://paper.gd")
const R = preload("res://agronomy.gd")
const CUR = preload("res://curriculum.gd")
const GAP = Vector2(220, 94)

static func visible_topic(m, key: String) -> bool:
	var crop = R.subject(key)
	return CUR.eligible_region(m.s, key) and (crop == "" or R.discovered(m.s, crop))

static func children(m, key: String) -> Array:
	var result = []
	for child in m.techs:
		if key in m.techs[child][3] and visible_topic(m, child): result.append(child)
	return result

static func state_label(m, key: String) -> Array:
	if key in m.s.tech: return ["已掌握", U.GREEN]
	if key == m.s.study: return ["在研", U.WARN]
	if m.research_reason(key) == "": return ["可研习", U.GOLD]
	return ["待解锁", U.DIM]

static func node_for(h, graph: GraphEdit, key: String, pos: Vector2, current: String):
	var m = h.sim
	var info = state_label(m, key)
	var node = GraphNode.new()
	node.name = key
	node.title = "%s · %s · %s" % [m.ROMAN[m.techs[key][1]], R.discipline(key), info[0]]
	node.draggable = false
	node.resizable = false
	node.position_offset = pos
	node.custom_minimum_size.x = 196
	graph.add_child(node)
	var button = h.btn(m.tech_name(key), "goto_tech", key, key == current)
	button.custom_minimum_size = Vector2(170, 31)
	button.tooltip_text = m.research_reason(key) if info[0] == "待解锁" else "打开课题详情"
	node.add_child(button)
	node.set_slot(0, true, 0, info[1], true, 0, info[1])
	return node

# Cross-era links always point right. Within an era, calculate the depth from actual dependencies.
static func depth(key: String, table: Dictionary, memo: Dictionary) -> int:
	if memo.has(key): return memo[key]
	var result = 0
	for pre in table[key][3]:
		if table[pre][1] == table[key][1]:
			result = maxi(result, 1 + depth(pre, table, memo))
	memo[key] = result
	return result

static func layout(m, key: String, overview: bool) -> Dictionary:
	var pos = {}
	if not overview:
		var parents = m.techs[key][3]
		var next = children(m, key)
		var center = ceilf(maxi(parents.size(), next.size()) / 2.0) * GAP.y
		pos[key] = Vector2(GAP.x, center)
		for i in parents.size(): pos[parents[i]] = Vector2(0, center + (i - (parents.size()-1)/2.0)*GAP.y)
		for i in next.size(): pos[next[i]] = Vector2(2*GAP.x, center + (i - (next.size()-1)/2.0)*GAP.y)
		return pos
	var memo = {}
	var offset = 0
	for era in 4:
		var counts = {}
		var width = 0
		for track in ["公共"] + CUR.TRACKS:
			for id in m.techs:
				if m.techs[id][1] != era or R.discipline(id) != track or not visible_topic(m, id): continue
				var col = depth(id, m.techs, memo)
				pos[id] = Vector2(offset + col, counts.get(col, 0)) * GAP
				counts[col] = counts.get(col, 0) + 1
				width = maxi(width, col + 1)
		offset += width
	return pos

static func center_at(graph: GraphEdit, pos: Vector2):
	if not is_instance_valid(graph) or not graph.is_inside_tree(): return
	graph.scroll_offset = (pos + Vector2(98, 40)) * graph.zoom - graph.size * 0.5

static func show(h, overlay):
	var card = U.panel(overlay, 0.5, 0.5, 0.5, 0.5, Rect2i(-508,-283,508,283))
	var page = U.box(true, 8)
	U.inset(card, 15).add_child(page)
	var row = U.box(false, 8)
	page.add_child(row)
	row.add_child(h.title_label("农学课题图", 24))
	row.add_child(U.space())
	row.add_child(h.btn("本课脉络", "map_mode", false, not h.map_overview))
	row.add_child(h.btn("全树", "map_mode", true, h.map_overview))
	row.add_child(h.btn("返回手册", "back"))
	var hint = "本地已发现作物及四个时代的课题" if h.map_overview else "当前课题及其直接前置、后续课题"
	page.add_child(U.label(hint + "　·　由左向右阅读，点课题可查看条件和投入", 14, U.DIM))
	var graph = GraphEdit.new()
	graph.show_grid = false
	graph.minimap_enabled = h.map_overview
	graph.zoom_min = 0.3
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.custom_minimum_size.y = 360
	page.add_child(graph)
	var key = h.tech_key
	var positions = layout(h.sim, key, h.map_overview)
	for id in positions: node_for(h, graph, id, positions[id], key)
	for id in positions:
		for parent in h.sim.techs[id][3]:
			if positions.has(parent): graph.connect_node(parent, 0, id, 0)
	var guide = U.box(false, 15)
	page.add_child(guide)
	for state in [["已掌握",U.GREEN],["可研习",U.GOLD],["在研",U.WARN],["待解锁",U.DIM]]:
		guide.add_child(U.label("● " + state[0], 13, state[1]))
	guide.add_child(U.space())
	guide.add_child(U.label("中键拖动 · 使用图上缩放按钮", 13, U.DIM))
	center_at.call_deferred(graph, positions[key])
