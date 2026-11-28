extends RefCounted

const U = preload("res://paper.gd")
const H = preload("res://handbook_style.gd")
const Events = preload("res://field_events.gd")
const Season = preload("res://season_ui.gd")

static func show(h, overlay: Control, key: String, archived: bool):
 var data = Events.COPY.data[key]
 var s = h.sim.s
 var turn = s.field_events.records[key].turn if archived else s.turn
 var era = Events.IDS.find(key) + 1
 var card = U.panel(overlay,0.5,0.5,0.5,0.5,Rect2i(-506,-274,506,274),H.PAPER)
 var page = U.box(true,10); U.inset(card,20).add_child(page)
 var mast = U.box(false,10); page.add_child(mast)
 mast.add_child(U.icon("seal",29,H.OCHRE))
 mast.add_child(U.label("农事簿  /  " + h.sim.ERAS[era],16,H.MUTED))
 mast.add_child(U.space())
 mast.add_child(H.stamp("第 %d 年 · %s" % [floori(turn/4.0)+1,h.sim.SEASONS[turn%4]],Color("#ded1ae"),H.INK))
 var scroll = ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; page.add_child(scroll)
 var body = U.box(true,12); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(body)
 var lead = U.box(false,18); body.add_child(lead)
 lead.add_child(Season.illustration(Season.art({"plate":"era","index":era}),Vector2(174,128)))
 var story = U.box(true,7); story.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lead.add_child(story)
 story.add_child(h.title_label(data.title,29,H.INK))
 story.add_child(U.label(data.story,17,H.INK,true))
 var history = H.block(body,Color("#e4d9bd"),9,4)
 history.add_child(U.label("农史记载",14,H.OCHRE))
 history.add_child(U.label(data.history,14,H.MUTED,true))
 var columns = U.box(false,12); body.add_child(columns)
 for index in 2:
  var option = data.choices[index]
  var choice = H.block(columns,H.NIGHT,12,7)
  var label = U.box(false,6); choice.add_child(label)
  label.add_child(U.icon("grain" if index==0 else "risk",20,U.GOLD if index==0 else U.GREEN))
  label.add_child(h.title_label(option.name,18))
  var effect = U.label(option.effect,15,U.TEXT,true); effect.size_flags_vertical = Control.SIZE_EXPAND_FILL; choice.add_child(effect)
  if archived:
   if s.field_events.records[key].choice == index: choice.add_child(U.label("当时采纳的方案",14,U.GOLD))
  else:
   var why = Events.shortfall(s,key,index)
   if index == 1 and key in ["E01","E03"]:
    var promised = 1 if key == "E01" else 2
    if Events.note_room(h.sim) < promised:
     choice.add_child(U.label("当前案藏可收 %d 份札记" % mini(Events.note_room(h.sim),promised),13,U.WARN))
   if key == "E02" and index == 0:
    choice.add_child(U.label("本次获得占城稻种源" if s.frontier.trials.is_empty() else "本次加快已在进行的试种",13,U.GOLD))
   var verbs = {"E01":["火耕抢种","筑埂养地"],"E02":["高坡试种","浚渠保田"],"E03":["追肥增产","控肥净水"]}
   var take = h.btn(verbs[key][index] if why == "" else why,"field_choice",[key,index],why == "")
   take.disabled = why != ""; choice.add_child(take)
 var foot = U.box(false,8); page.add_child(foot)
 foot.add_child(U.label("事件条件　" + data.trigger,13,H.MUTED,true))
 foot.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
 if archived: foot.add_child(h.btn("合上记录","back",null,true))
 else: foot.add_child(H.stamp("待议 · 农时已暂停",Color("#ded1ae"),H.INK))
