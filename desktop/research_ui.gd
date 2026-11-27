extends RefCounted

const U = preload("res://paper.gd")
const A = preload("res://frontier_ui.gd")
const R = preload("res://agronomy.gd")
const C = preload("res://crop_book.gd")
const CUR = preload("res://curriculum.gd")
const MapView = preload("res://research_map.gd")
const TOOLS = preload("res://art/heritage-implements.png")

const CHAPTERS = {"全部": "总览", "育种": "种源育种", "耕作": "田间耕作", "防灾": "水土防灾", "经济": "仓储流通"}

static func branch(_m, key: String) -> String:
 return R.chapter(key)

static func keys_for(m, section: String, era: int, source: String, ready_only: bool) -> Array:
 var by_era = [[], [], [], []]
 for key in m.techs:
  if not MapView.visible_topic(m, key): continue
  if section != "全部" and R.chapter(key) != section: continue
  if era >= 0 and m.techs[key][1] != era: continue
  if source == "地域" and not CUR.TOPICS.data.get(key, {}).has("region"): continue
  if source == "农具" and key not in R.HERITAGE and key != "rice_3": continue
  if source in C.NAMES and R.subject(key) != source and not (key in ["seed","dry"] and C.START[m.s.frontier.region] == source): continue
  if ready_only and m.research_reason(key) != "": continue
  by_era[m.techs[key][1]].append(key)
 var keys = []
 for group in by_era: keys.append_array(group)
 return keys

static func source_title(source: String) -> String:
 if source in C.NAMES: return C.title(source)
 return {"": "全部来源", "地域": "本地农法", "农具": "中国农技"}.get(source, source)

static func source_sheet(h, overlay):
 var card = U.panel(overlay, 0.5, 0.5, 0.5, 0.5, Rect2i(-270,-135,270,135))
 var page = U.box(true, 12); U.inset(card, 18).add_child(page)
 page.add_child(h.title_label("按来源查看课题", 23))
 var flow = HFlowContainer.new(); page.add_child(flow)
 for source in ["","农具","地域"] + C.NAMES:
  if source in C.NAMES and not R.discovered(h.sim.s, source): continue
  flow.add_child(h.btn(source_title(source), "tech_context", source, h.tech_source == source))
 page.add_child(h.btn("返回手册", "back"))

static func prereq_link(h, key: String) -> Button:
 var link = h.btn(("✓ " if key in h.sim.s.tech else "") + h.sim.tech_name(key), "goto_tech", key)
 link.add_theme_font_size_override("font_size", 13)
 link.custom_minimum_size.y = 25
 return link

static func routes_for(h, pane, key: String):
 var m = h.sim
 var required = m.techs[key][3]
 var routes = CUR.paths(key)
 if not required.is_empty():
  var common = HFlowContainer.new(); pane.add_child(common)
  common.add_child(U.label("共同前置" if not routes.is_empty() else "前置课题", 14, U.DIM))
  for parent in required: common.add_child(prereq_link(h, parent))
 if routes.is_empty(): return
 pane.add_child(U.label("以下路线完成任意一条", 15, U.GOLD))
 for route in routes:
  var line = HFlowContainer.new(); pane.add_child(line)
  var met = CUR.path_met(m, route)
  line.add_child(U.label(("✓ " if met else "◇ ") + route.name, 14, U.GREEN if met else U.TEXT))
  for parent in route.tech: line.add_child(prereq_link(h, parent))
  if route.has("field"):
   var field = route.field
   var ok = CUR.field_count(m, field) >= CUR.FIELDWORK[field][1]
   line.add_child(U.label(CUR.field_label(m, field), 13, U.GREEN if ok else U.WARN))

static func draw(h, v):
 var m = h.sim
 var s = m.s
 var ac = m.academy_id()
 var pending = s.cells[ac].notes if ac >= 0 else 0
 var level = s.cells[ac].level if ac >= 0 else 1
 var keys = keys_for(m, h.tech_branch, h.tech_era, h.tech_source, h.tech_ready)
 if not keys.is_empty() and h.tech_key not in keys: h.tech_key = keys[0]
 var head = U.box(false, 8); v.add_child(head)
 var bank = U.label("案藏 %d / %d　·　已领 %d　待领 %d" % [s.science + pending, R.limit(s, level), s.science, pending], 15, U.GOLD)
 bank.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(bank)
 head.add_child(h.btn("前往农专 · 领点与派工" if ac >= 0 else "选址建设农专", "academy", null, ac < 0 or pending > 0))
 var map_button = h.btn("课题图", "tech_map"); map_button.disabled = keys.is_empty(); head.add_child(map_button)
 var focus = s.research_record.focus
 head.add_child(h.btn("确立专精" if focus == "" else focus + "专精", "study_focus", null, focus == "" and s.era >= 1))
 var tabs = U.box(false, 5); v.add_child(tabs)
 for track in CHAPTERS:
  tabs.add_child(h.btn(CHAPTERS[track], "tech_branch", track, h.tech_branch == track))
 tabs.add_child(U.space())
 tabs.add_child(h.btn(source_title(h.tech_source) + " ▾", "tech_context_menu", null, h.tech_source != ""))
 var periods = U.box(false, 5); v.add_child(periods)
 for age in [-1,0,1,2,3]:
  var title = "全时代" if age < 0 else m.ROMAN[age] + " " + ["采集","农耕","传统","现代"][age]
  periods.add_child(h.btn(title, "tech_era", age, h.tech_era == age))
 periods.add_child(U.space())
 periods.add_child(h.btn("仅看可研", "tech_ready", null, h.tech_ready))
 if keys.is_empty():
  v.add_child(U.label("当前条件下没有可开题的课题。" if h.tech_ready else "当前筛选没有对应的课题。", 15, U.DIM))
  v.add_child(h.btn("查看全部课题", "tech_reset"))
  return
 v.add_child(U.rule())
 var cols = U.box(false, 16); cols.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(cols)
 var list = ScrollContainer.new(); list.name = "IndexScroll"; list.custom_minimum_size.x = 248
 list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; cols.add_child(list)
 var index = U.box(true, 4); index.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_child(index)
 for id in keys:
  var status = MapView.state_label(m, id)
  var prefix = m.ROMAN[m.techs[id][1]] + " " if h.tech_era < 0 else ""
  var button = h.btn(prefix + m.tech_name(id) + "　·　" + status[0], "tech_view", id, id == h.tech_key)
  if id != h.tech_key: button.add_theme_color_override("font_color", status[1])
  button.alignment = HORIZONTAL_ALIGNMENT_LEFT; index.add_child(button)
  if id == h.tech_key: list.ensure_control_visible.call_deferred(button)
 var right = U.box(true, 5); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cols.add_child(right)
 var scroll = ScrollContainer.new(); scroll.name = "ContentScroll"; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; right.add_child(scroll)
 var pane = U.box(true, 5); pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(pane)
 var key = h.tech_key
 var t = m.techs[key]
 var lead = U.box(false, 10); pane.add_child(lead)
 var crop = R.subject(key)
 var tile = C.NAMES.find(crop if crop != "" else C.START[s.frontier.region])
 var plate = A.PLANTS
 if key in R.HERITAGE: plate = TOOLS; tile = R.HERITAGE[key] [5]
 elif key == "rice_3": plate = TOOLS; tile = 3
 elif key in["terrace", "dike", "rotate", "precise"]: plate = TOOLS; tile = 5
 elif crop == "" and R.chapter(key) in ["经济", "防灾", "耕作"]:
  plate = TOOLS
  tile = {"经济":4, "防灾":2, "耕作":0}[R.chapter(key)]
 lead.add_child(A.picture(plate, tile, Vector2(88, 70)))
 var titles = U.box(true, 4); titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lead.add_child(titles)
 var location = CUR.TOPICS.data.get(key, {}).get("region", -1)
 var region_label = "　·　" + C.REGIONS[int(location)] if location >= 0 else ""
 titles.add_child(U.label(m.ROMAN[t[1]] + "　" + m.ERAS[t[1]] + "　·　" + R.discipline(key) + region_label, 13, U.GOLD))
 titles.add_child(h.title_label(m.tech_name(key), 24))
 pane.add_child(U.label(R.description(s, key, m.techs), 15, U.TEXT, true))
 routes_for(h, pane, key)
 var topic = preload("res://chronicle.gd").research_source(s, key)
 if topic != "": pane.add_child(h.btn("阅读原文 · " + topic, "read_entry", "tech/" + topic))
 elif not CUR.TOPICS.data.has(key): pane.add_child(U.label("【待补文案 · " + m.tech_name(key) + " · 科技介绍】", 12, U.DIM, true))
 pane.add_child(U.rule())
 var fee = R.notes(s, key, t)
 var inputs = ["%d 札记" % fee + ("（原 %d）" % t[2] if fee != t[2] else "")]
 var cost = R.bill(s, key, t)
 for i in 4:
  if cost[i] > 0: inputs.append("%d %s" % [cost[i], ["口粮", "种粮", "木", "石"] [i]])
 right.add_child(U.rule())
 right.add_child(U.label("投入　" + " · ".join(inputs), 15, U.GOLD, true))
 var terms = CUR.terms(key)
 if terms > 0:
  right.add_child(U.label("季末验收 %d 次 · 每个有效季农专教师与通路农田劳力须同时到岗累计 %d 秒" % [terms, CUR.OBSERVATIONS], 14, U.GREEN, true))
 var why = m.research_reason(key)
 var label = "研习 · %d 人秒" % R.timing(t)
 if key in s.tech: label = "已掌握"
 elif s.study == key: label = m.study_status()
 var accept = h.btn(label, "research", key, why == "")
 accept.disabled = why != ""; accept.tooltip_text = why; right.add_child(accept)
 if why != "" and key not in s.tech and s.study != key: right.add_child(U.label(why, 14, U.WARN, true))
 if s.study == key and terms > 0: pane.add_child(h.btn("撤回验证项目…", "withdraw_study", key))
 if s.study != "" and s.study != key: pane.add_child(h.btn("查看在研 · " + m.tech_name(s.study), "goto_tech", s.study))

static func focus_sheet(h, overlay):
 var s = h.sim.s
 var card = U.panel(overlay, 0.5, 0.5, 0.5, 0.5, Rect2i(-324,-198,324,198))
 var page = U.box(true, 10); U.inset(card, 20).add_child(page)
 page.add_child(h.title_label("农专研习方向", 27))
 page.add_child(U.label("本门课题的札记按七折四舍五入，外门增加 15% 向上取整。公共农政按原价。", 15, U.TEXT, true))
 var chosen = s.research_record.focus
 var selected = chosen if chosen != "" else h.proposed_focus
 var row = U.box(false, 6); page.add_child(row)
 for track in CUR.TRACKS:
  var item = h.btn(track, "focus_preview", track, selected == track)
  item.disabled = chosen != ""
  item.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(item)
 page.add_child(U.rule())
 if selected != "":
  page.add_child(h.title_label(selected + "专精", 22, U.GOLD))
  page.add_child(U.label(CUR.PERKS[selected], 16, U.TEXT, true))
 else: page.add_child(U.label("点选一个方向查看专长。", 16, U.DIM))
 page.add_child(U.space())
 if chosen != "": page.add_child(U.label("本场战役已确立" + chosen + "专精。", 14, U.GREEN))
 elif s.era < 1: page.add_child(U.label("进入第二时代「早期农耕」后可确立专精。", 15, U.WARN, true))
 else:
  page.add_child(U.label("每场战役限选一次，可稍后再定。", 14, U.DIM))
  var apply = h.btn("确立" + selected + "专精" if selected != "" else "请选择方向", "focus_confirm", selected, true)
  apply.disabled = selected == ""; page.add_child(apply)
 page.add_child(h.btn("返回手册", "back"))
