extends RefCounted

const U = preload("res://paper.gd")
const A = preload("res://frontier_ui.gd")
const R = preload("res://agronomy.gd")
const C = preload("res://crop_book.gd")
const CUR = preload("res://curriculum.gd")
const MapView = preload("res://research_map.gd")
const TOOLS = preload("res://art/heritage-implements.png")

static func draw_detail(h, pane, key: String, requirements: Array):
	var m = h.sim
	var s = m.s
	var t = m.techs[key]
	var crop = R.subject(key)
	var lead = U.box(false, 10);pane.add_child(lead)
	var plate = A.PLANTS
	var tile = C.NAMES.find(crop if crop != "" else C.START[s.frontier.region])
	if key in R.HERITAGE:
		plate = TOOLS;tile = R.HERITAGE[key][5]
	elif key == "rice_3":
		plate = TOOLS;tile = 3
	elif crop == "" and key not in ["seed", "dry"]:
		plate = TOOLS
		tile = {"经济": 4, "防灾": 2, "耕作": 0}.get(R.discipline(key), 5)
	var thumb = A.picture(plate, tile, Vector2(66, 68))
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lead.add_child(thumb)
	var heading = U.box(true, 3)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL;lead.add_child(heading)
	heading.add_child(U.label(m.ROMAN[t[1]] + " · " + m.ERAS[t[1]], 13, U.GOLD, true))
	var title = h.title_label(m.tech_name(key), 23)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_child(title)
	var state = MapView.state_label(m, key)
	heading.add_child(U.label(state[0] + "  ·  " + MapView.lane_for(key), 13, state[1], true))
	pane.add_child(U.rule())

	var fee = R.notes(s, key, t)
	var inputs = ["%d 札记" % fee, "%d 人秒" % R.research_time(s, key, t)]
	if fee != t[2]: inputs[0] += "（原 %d）" % t[2]
	var cost = R.bill(s, key, t)
	for i in 4:
		if cost[i] > 0: inputs.append("%d %s" % [cost[i], ["口粮", "种粮", "木", "石"][i]])
	pane.add_child(U.label("研习投入", 15, U.GOLD))
	pane.add_child(U.label(" · ".join(inputs), 14, U.TEXT, true))
	var terms = CUR.terms(key)
	if terms > 0:
		pane.add_child(U.label("田间验证 %d 季。每个有效季内，农专教师和通路农田的农户需同时到岗至少 %d 秒。" % [terms, CUR.OBSERVATIONS], 14, U.DIM, true))
	if key == "rice_2":
		pane.add_child(U.label("实作须有一块通路农田，且农户已经到岗。", 14, U.DIM, true))
	if key == "rice_3":
		pane.add_child(U.label("增产在接通农专且受有效灌渠覆盖的稻田生效。", 14, U.DIM, true))

	for group in R.prerequisites(m.techs, key):
		var met = R.group_met(group, s.tech)
		pane.add_child(U.label(("前置 · 任选一项" if group.mode == "any" else "前置 · 全部掌握") + ("　✓" if met else ""), 14, MapView.ALTERNATIVE if group.mode == "any" else U.GOLD))
		topic_links(h, pane, group.keys, true)

	var aids = R.aids(key)
	if not aids.is_empty():
		pane.add_child(U.label("辅助科技 · 可选", 14, MapView.SUPPORT))
		topic_links(h, pane, aids, true)
		if key != s.study and key not in s.tech:
			var discount_status = "已计入上方报价。" if R.assisted(s, key) else "掌握其中任一项即可享受。"
			pane.add_child(U.label("札记、物资和工时各减 %d%%。折后下取整，非零投入至少为 1。%s" % [R.ASSIST_PERCENT, discount_status], 13, U.DIM, true))
	if key == s.study and terms > 0:
		pane.add_child(h.btn("撤回验证项目…", "withdraw_study", key))
	elif key not in s.tech and key != s.study:
		if s.study != "":
			pane.add_child(U.label("正在研习" + m.tech_name(s.study), 14, U.WARN, true))
		for requirement in requirements:
			var gate: String = requirement[1]
			if not requirement[0] and not gate.begins_with("须先掌握") and not gate.begins_with("任选一项前置"):
				pane.add_child(U.label(gate, 14, U.WARN, true))
	pane.add_child(U.rule())
	pane.add_child(U.label("效果与说明", 15, U.GOLD))
	pane.add_child(U.label(R.description(s, key, m.techs), 15, U.TEXT, true))
	var topic = preload("res://chronicle.gd").research_source(s, key)
	if topic != "": pane.add_child(h.btn("阅读农技文献", "read_entry", "tech/" + topic))
	var next = MapView.children(m, key)
	if not next.is_empty():
		pane.add_child(U.rule())
		pane.add_child(U.label("衍生课题", 14, U.GOLD))
		topic_links(h, pane, next, false)

static func topic_links(h, pane, keys: Array, show_status: bool):
	var links = HFlowContainer.new()
	links.add_theme_constant_override("h_separation", 5)
	links.add_theme_constant_override("v_separation", 5)
	pane.add_child(links)
	for key in keys:
		if not MapView.visible_topic(h.sim, key): continue
		var marker = ("✓ " if key in h.sim.s.tech else "◇ ") if show_status else ""
		var link = h.btn(marker + h.sim.tech_name(key), "goto_tech", key)
		link.add_theme_font_size_override("font_size", 13)
		links.add_child(link)

static func focus_sheet(h, overlay):
	var s = h.sim.s
	var card = U.panel(overlay, 0.5, 0.5, 0.5, 0.5, Rect2i(-324, -198, 324, 198))
	var page = U.box(true, 10);U.inset(card, 20).add_child(page)
	page.add_child(h.title_label("农专研习方向", 27))
	page.add_child(U.label("本门课题的札记按七折四舍五入，外门增加 15% 向上取整。公共农政按原价。", 15, U.TEXT, true))
	var chosen = s.research_record.focus
	var selected = chosen if chosen != "" else h.proposed_focus
	var row = U.box(false, 6);page.add_child(row)
	for track in CUR.TRACKS:
		var item = h.btn(track, "focus_preview", track, selected == track)
		item.disabled = chosen != ""
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL;row.add_child(item)
	page.add_child(U.rule())
	if selected != "":
		page.add_child(h.title_label(selected + "专精", 22, U.GOLD))
		page.add_child(U.label(CUR.PERKS[selected], 16, U.TEXT, true))
	else: page.add_child(U.label("点选一个方向查看专长。", 16, U.DIM))
	page.add_child(U.space())
	if chosen != "": page.add_child(U.label("本次发展已确立" + chosen + "专精。", 14, U.GREEN))
	elif s.era < 1: page.add_child(U.label("进入第二时代「早期农耕」后可确立专精。", 15, U.WARN, true))
	else:
		page.add_child(U.label("每次发展限选一次，可稍后再定。", 14, U.DIM))
		var apply = h.btn("确立" + selected + "专精" if selected != "" else "请选择方向", "focus_confirm", selected, true)
		apply.disabled = selected == "";page.add_child(apply)
	page.add_child(h.btn("返回手册", "back"))
