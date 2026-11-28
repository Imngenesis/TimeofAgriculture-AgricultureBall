extends RefCounted

const U = preload("res://paper.gd")
const A = preload("res://frontier_ui.gd")
const Book = preload("res://chronicle.gd")
const Weather = preload("res://weather.gd")
const ERA_ART = preload("res://art/era-chronicle.png")
const INK = Color("#263d35")
const MUTED = Color("#526453")
const PAPER = Color("#f1e4c8")

static func art(data: Dictionary) -> Texture2D:
	if data.plate == "habitat": return A.plate(A.HABITATS, data.index)
	if data.plate == "crop": return A.plate(A.PLANTS, data.index)
	var section = AtlasTexture.new()
	section.atlas = ERA_ART
	var tile = ERA_ART.get_size() / 2.0
	section.region = Rect2(Vector2(int(data.index) % 2, floori(data.index / 2.0)) * tile + Vector2.ONE, tile - Vector2(2, 2))
	section.filter_clip = true
	return section

static func illustration(texture: Texture2D, extent: Vector2) -> TextureRect:
	var painting = TextureRect.new()
	painting.texture = texture
	painting.custom_minimum_size = extent
	painting.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	painting.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	painting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return painting

static func folio(h, overlay: Control, key: String, inbox: bool):
	var data = Book.entry(key)
	var card = U.panel(overlay, 0.5, 0.5, 0.5, 0.5, Rect2i(-416, -214, 416, 214), PAPER)
	var spread = U.box(false, 0);card.add_child(spread)
	spread.add_child(illustration(art(data), Vector2(298, 418)))
	var page = U.box(true, 12)
	var margins = U.inset(spread, 22);margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL;margins.add_child(page)
	page.add_child(U.label("百谷长青    /    " + data.category, 14, MUTED))
	var title = h.title_label(data.name, 28, INK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;page.add_child(title)
	page.add_child(U.rule())
	var flow = ScrollContainer.new();flow.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	flow.size_flags_vertical = Control.SIZE_EXPAND_FILL;page.add_child(flow)
	var words = U.label(data.body, 18, INK, true)
	words.add_theme_constant_override("line_spacing", 7)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL;flow.add_child(words)
	if data.name in Book.Crops.CAU_CULTIVARS: page.add_child(U.label("育种单位　中国农业大学参与选育", 13, MUTED))
	if key == "era/1" and h.sim.s.research_record.focus == "":
		page.add_child(U.label("早期农耕已开放农专专精，按 T 打开科技树可选择方向。", 13, MUTED, true))
	var count = h.sim.s.guide.queue.size()
	var label = "确认发现" if inbox and key.begins_with("crop/") else ("下一页" if inbox and count > 1 else "返回发展")
	if inbox:
		page.add_child(U.label("待阅 %d 页　 ·　 时间已暂停" % count, 13, MUTED))
		if key.begins_with("crop/"): page.add_child(h.btn("确认并查看作物科技", "guide_crop", key.substr(5)))
	page.add_child(h.btn(label if inbox else "返回", "guide_next" if inbox else "back", null, true))

static func archive(h, v):
	var s = h.sim.s
	var tabs = U.box(false, 5);v.add_child(tabs)
	for item in ["发现记录", "时代农技"]:
		A.choice(h, tabs, item, "archive_tab", item, h.archive_tab == item)
	if h.archive_tab == "发现记录":
		for i in range(s.guide.read.size() - 1, -1, -1):
			var key = s.guide.read[i]
			var item = Book.entry(key)
			v.add_child(h.btn(item.category + "　·　" + item.name, "read_entry", key))
	else:
		var eras = U.box(false, 4);v.add_child(eras)
		for era in range(s.era + 1): A.choice(h, eras, h.S.ERAS[era], "archive_era", era, h.archive_era == era)
		var index = clampi(h.archive_era, 0, s.era)
		v.add_child(h.btn(str(Book.COPY.data.eras[index].title), "read_entry", "era/" + str(index), true))
		for topic in Book.COPY.data.technologies:
			if int(Book.COPY.data.technologies[topic].era) == index: v.add_child(h.btn(topic, "read_entry", "tech/" + topic))

static func forecast(h, v):
	var s = h.sim.s
	var w = s.weather
	var headline = U.box(false, 9);v.add_child(headline)
	U.metric(headline, h.sim.date(), w.now, U.GOLD)
	var effect = Weather.FORECAST[w.now]
	v.add_child(U.label(effect, 16, U.TEXT, true))
	if w.threat != "":
		v.add_child(U.rule())
		v.add_child(U.label("本季灾害　" + w.threat, 19, U.WARN))
		v.add_child(U.label(Weather.IMPACT[w.threat] + "季末结算。", 15, U.TEXT, true))
		var why = Weather.prepare_reason(s)
		var b = h.btn("已部署防护" if w.prepared else Weather.DEFENSE[w.threat] + ("　·　2 粮 1 木" if Weather.defense_wood(s) else "　·　2 粮"), "weather_prepare", null, why == "")
		b.tooltip_text = why;b.disabled = why != "";v.add_child(b)
		if why != "" and not w.prepared: v.add_child(U.label(why, 13, U.WARN, true))
	else: v.add_child(U.label("本季暂无天气灾害", 14, U.GREEN))
	if not w.history.is_empty():
		v.add_child(U.rule());v.add_child(U.label("近年天灾", 16, U.GOLD))
		for entry in w.history: v.add_child(U.label(entry, 14, U.DIM, true))

static func projects(h, v):
	var s = h.sim.s
	var sections = {"种养": ["farm", "pasture", "nursery", "store"], "水土": ["levee", "canal", "terrace", "ditch"], "聚落与院校": ["house", "academy", "agcollege", "engineering", "station", "university"]}
	var tabs = U.box(false, 5);v.add_child(tabs)
	for name in ["全部"] + sections.keys(): A.choice(h, tabs, name, "build_category", name, h.build_category == name)
	v.add_child(h.btn("铺田间道路　·　G", "street_start", -1))
	for group in sections:
		if h.build_category != "全部" and h.build_category != group: continue
		v.add_child(U.label(group, 15, U.GOLD))
		var grid = GridContainer.new();grid.columns = 2;v.add_child(grid)
		for key in sections[group]:
			var spec = h.S.BUILD[key]
			var label = spec[0] + "　·　%d 粮" % spec[2]
			var why = ""
			if spec[1] != "" and spec[1] not in s.tech: why = "需" + h.sim.tech_name(spec[1])
			if key == "agcollege" and not h.T.knows_land_management(s): why = "需等高筑田或谷豆轮作"
			if key == "academy" and h.sim.academy_id() >= 0: why = "已设址"
			var button = h.btn(label + (" · " + why if why != "" else ""), "tool", key)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.tooltip_text = h.S.SERVICE[key] + "　" + h.E.input_text(key) + "，施工 %d 人秒。" % spec[3]
			button.disabled = why != "";grid.add_child(button)
