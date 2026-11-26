extends RefCounted

const U = preload("res://paper.gd")
const A = preload("res://frontier_ui.gd")
const R = preload("res://agronomy.gd")
const C = preload("res://crop_book.gd")
const CUR = preload("res://curriculum.gd")
const MapView = preload("res://research_map.gd")
const TOOLS = preload("res://art/heritage-implements.png")

static func keys_for(m, section: String, era: int = -1) -> Array:
 var keys = []
 if section in CUR.TRACKS:
  for key in CUR.TOPICS.data:
   if R.discipline(key) == section and (era < 0 or m.techs[key][1] == era) and CUR.eligible_region(m.s, key): keys.append(key)
 elif section == "农政":
  for key in m.TECH:
   if key not in["seed", "dry"]: keys.append(key)
 elif section == "农具":
  keys = R.HERITAGE.keys()
  if R.discovered(m.s, "稻"): keys.append("rice_3")
 else:
  if section == C.START[m.s.frontier.region]: keys = ["seed", "dry"]
  for stage in 3: keys.append(R.id(section, stage))
 return keys

static func branch(m, key: String) -> String:
 if CUR.TOPICS.data.has(key): return R.discipline(key)
 if key in["seed", "dry"]: return C.START[m.s.frontier.region]
 if key in R.HERITAGE: return "农具"
 var crop = R.subject(key)
 return "农政" if crop == "" else crop

static func draw(h, v):
 var m = h.sim
 var s = m.s
 var ac = m.academy_id()
 var pending = s.cells[ac].notes if ac >= 0 else 0
 var level = s.cells[ac].level if ac >= 0 else 1
 var head = U.box(false, 8); v.add_child(head)
 var bank = U.label("案藏 %d / %d　·　已领 %d　待领 %d" % [s.science + pending, R.limit(s, level), s.science, pending], 15, U.GOLD)
 bank.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(bank)
 head.add_child(h.btn("前往农专 · 领点与派工" if ac >= 0 else "选址建设农专", "academy", null, ac < 0 or pending > 0))
 head.add_child(h.btn("课题图", "tech_map"))
 var focus = s.research_record.focus
 head.add_child(h.btn("确立专精" if focus == "" else focus + "专精", "study_focus", null, focus == "" and s.era >= 1))
 var tabs = U.box(false, 4); v.add_child(tabs)
 for crop in C.NAMES:
  if R.discovered(s, crop): tabs.add_child(h.btn(C.title(crop), "tech_branch", crop, h.tech_branch == crop))
 for key in["农政", "农具"]: tabs.add_child(h.btn("公共农政" if key == "农政" else "中国农技", "tech_branch", key, h.tech_branch == key))
 var schools = U.box(false, 5); v.add_child(schools)
 for track in CUR.TRACKS:
  schools.add_child(h.btn(track, "tech_branch", track, h.tech_branch == track))
 if h.tech_branch in CUR.TRACKS:
  schools.add_child(U.space())
  for age in 4: schools.add_child(h.btn(m.ROMAN[age] + " " + ["采集","农耕","传统","现代"][age], "tech_era", age, h.tech_era == age))
 var keys = keys_for(m, h.tech_branch, h.tech_era)
 if keys.is_empty():
  v.add_child(U.label("此时代尚无本地" + h.tech_branch + "选修课。可切换时代或学科。", 15, U.DIM, true))
  return
 if h.tech_key not in keys: h.tech_key = keys[0]
 v.add_child(U.rule())
 var cols = U.box(false, 13); v.add_child(cols)
 var index = U.box(true, 4); index.custom_minimum_size.x = 202; cols.add_child(index)
 for key in keys:
  var status = MapView.state_label(m, key)
  var b = h.btn(m.tech_name(key) + "　·　" + status[0], "tech_view", key, key == h.tech_key)
  if key != h.tech_key: b.add_theme_color_override("font_color", status[1])
  b.alignment = HORIZONTAL_ALIGNMENT_LEFT; index.add_child(b)
 var key = h.tech_key
 var t = m.techs[key]
 var pane = U.box(true, 5); pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cols.add_child(pane)
 var lead = U.box(false, 10); pane.add_child(lead)
 var crop = R.subject(key)
 var tile = C.NAMES.find(crop if crop != "" else C.START[s.frontier.region])
 var plate = A.PLANTS
 if key in R.HERITAGE: plate = TOOLS; tile = R.HERITAGE[key] [5]
 elif key == "rice_3": plate = TOOLS; tile = 3
 elif key in["terrace", "dike", "rotate", "precise"]: plate = TOOLS; tile = 5
 elif h.tech_branch == "农政": plate = TOOLS; tile = 0 if key == "machine" else 4
 elif h.tech_branch in ["经济", "防灾", "耕作"]:
  plate = TOOLS
  tile = {"经济":4, "防灾":2, "耕作":0}[h.tech_branch]
 lead.add_child(A.picture(plate, tile, Vector2(100, 91)))
 var titles = U.box(true, 4); titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lead.add_child(titles)
 var location = CUR.TOPICS.data.get(key, {}).get("region", -1)
 var region_label = "　·　" + C.REGIONS[int(location)] if location >= 0 else ""
 titles.add_child(U.label(m.ROMAN[t[1]] + "　" + m.ERAS[t[1]] + "　·　" + R.discipline(key) + region_label, 13, U.GOLD))
 titles.add_child(h.title_label(m.tech_name(key), 24))
 if not t[3].is_empty():
  var links = HFlowContainer.new(); titles.add_child(links)
  links.add_child(U.label("前置", 13, U.DIM))
  for parent in t[3]:
   var link = h.btn(("✓ " if parent in s.tech else "") + m.tech_name(parent), "goto_tech", parent)
   link.add_theme_font_size_override("font_size", 13)
   links.add_child(link)
 pane.add_child(U.label(R.description(s, key, m.techs), 15, U.TEXT, true))
 var topic = preload("res://chronicle.gd").research_source(s, key)
 if topic != "": pane.add_child(h.btn("阅读原文 · " + topic, "read_entry", "tech/" + topic))
 elif not CUR.TOPICS.data.has(key): pane.add_child(U.label("【待补文案 · " + m.tech_name(key) + " · 科技介绍】", 12, U.DIM, true))
 pane.add_child(U.rule())
 var fee = R.notes(s, key, t)
 var inputs = ["%d 札记" % fee + ("（原 %d）" % t[2] if fee != t[2] else "")]
 var cost = R.bill(s, key, t)
 for i in 4:
  if cost[i] > 0: inputs.append("%d %s" % [cost[i], ["口粮", "种粮", "木", "石"] [i]])
 pane.add_child(U.label("投入　" + " · ".join(inputs), 15, U.GOLD, true))
 var terms = CUR.terms(key)
 if terms > 0:
  pane.add_child(U.label("田间验证 · %d 个季末验收。每季须有至少 %d 秒同时有农专教师和通路农田的农人到岗。" % [terms, CUR.OBSERVATIONS], 14, U.GREEN, true))
 var why = m.research_reason(key)
 var label = "研习 · %d 人秒" % R.timing(t)
 if key in s.tech: label = "已掌握"
 elif s.study == key: label = m.study_status()
 var accept = h.btn(label, "research", key, why == "")
 accept.disabled = why != ""; accept.tooltip_text = why; pane.add_child(accept)
 if why != "" and key not in s.tech and s.study != key: pane.add_child(U.label(why, 14, U.WARN, true))
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
