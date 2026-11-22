extends RefCounted

const U = preload("res://paper.gd")
const A = preload("res://frontier_ui.gd")
const R = preload("res://agronomy.gd")
const C = preload("res://crop_book.gd")
const TOOLS = preload("res://art/heritage-implements.png")

static func keys_for(m, section: String) -> Array:
 var keys = []
 if section == "农政":
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
 var tabs = U.box(false, 4); v.add_child(tabs)
 for crop in C.NAMES:
  if R.discovered(s, crop): tabs.add_child(h.btn(C.title(crop), "tech_branch", crop, h.tech_branch == crop))
 for key in["农政", "农具"]: tabs.add_child(h.btn("公共农政" if key == "农政" else "中国农技", "tech_branch", key, h.tech_branch == key))
 var keys = keys_for(m, h.tech_branch)
 if h.tech_key not in keys: h.tech_key = keys[0]
 v.add_child(U.rule())
 var cols = U.box(false, 13); v.add_child(cols)
 var index = U.box(true, 4); index.custom_minimum_size.x = 202; cols.add_child(index)
 for key in keys:
  var status = "✓" if key in s.tech else("◈" if s.study == key else m.ROMAN[m.techs[key] [1]])
  var b = h.btn(status + "　" + m.tech_name(key), "tech_view", key, key == h.tech_key)
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
 lead.add_child(A.picture(plate, tile, Vector2(100, 91)))
 var titles = U.box(true, 4); titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lead.add_child(titles)
 titles.add_child(U.label(m.ROMAN[t[1]] + "　" + m.ERAS[t[1]], 13, U.GOLD))
 titles.add_child(h.title_label(m.tech_name(key), 24))
 var parents = []
 for parent in t[3]: parents.append(m.tech_name(parent))
 titles.add_child(U.label("前置 · " + ("无" if parents.is_empty() else "、".join(parents)), 13, U.DIM, true))
 pane.add_child(U.label(R.description(s, key, m.techs), 15, U.TEXT, true))
 var topic = preload("res://chronicle.gd").research_source(s, key)
 if topic != "": pane.add_child(h.btn("阅读原文 · " + topic, "read_entry", "tech/" + topic))
 else: pane.add_child(U.label("【待补文案 · " + m.tech_name(key) + " · 科技介绍】", 12, U.DIM, true))
 pane.add_child(U.rule())
 var inputs = ["%d 科技点" % t[2]]
 var cost = R.bill(s, key, t)
 for i in 4:
  if cost[i] > 0: inputs.append("%d %s" % [cost[i], ["口粮", "种粮", "木", "石"] [i]])
 pane.add_child(U.label("投入　" + " · ".join(inputs), 15, U.GOLD, true))
 var why = m.research_reason(key)
 var label = "研习 · %d 人秒" % R.timing(t)
 if key in s.tech: label = "已掌握"
 elif s.study == key: label = "研习中 · 余 %d 人秒" % s.study_time
 var accept = h.btn(label, "research", key, why == "")
 accept.disabled = why != ""; accept.tooltip_text = why; pane.add_child(accept)
 if why != "" and key not in s.tech and s.study != key: pane.add_child(U.label(why, 14, U.WARN, true))
 if s.study != "" and s.study != key: pane.add_child(U.label("当前研习　%s · 余 %d 人秒" % [m.tech_name(s.study), s.study_time], 13, U.DIM, true))
