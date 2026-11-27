extends Node


const V = preload("res://valley.gd")
const S = preload("res://simulation.gd")
var game
var sim
var folder = ""
var failed = false
var low = -1
var upland = -1
var messages = []
var picture = true
var results = []
var difficulty = 1

func check(condition: bool, description: String) -> bool:
 if failed: return false
 if not condition:
  failed = true
  report("FAIL " + description)
  get_tree().quit(2)
  return false
 return true

func report(line: String):
 print(line)
 messages.append(line)
 var output = FileAccess.open(folder.path_join("verification.txt"), FileAccess.WRITE)
 if output: output.store_string("\n".join(messages) + "\n")

func frames(count: int = 2):
 for i in count: await get_tree().process_frame

func capture(label_text: String):
 if not picture or failed: return
 await frames(3)
 await RenderingServer.frame_post_draw
 var image = get_viewport().get_texture().get_image()
 check(image != null and image.save_png(folder.path_join(label_text + ".png")) == OK, "screenshot " + label_text)
 if label_text == "02-river-valley" and image:
  image.save_jpg(folder.path_join("river-valley.jpg"), 0.88)
 if(label_text in["12-harvest-detail", "11-modern-valley"] or label_text.begins_with("beta-") or label_text.begins_with("formal-")) and image:
  image.save_jpg(folder.path_join(label_text + ".jpg"), 0.93)

func zoom_view(button: MouseButton, count: int):
 var viewport = get_viewport()
 var position = viewport.get_visible_rect().size * Vector2(0.53, 0.48)
 for n in count:
  var event = InputEventMouseButton.new()
  event.button_index = button
  event.position = position
  event.global_position = position
  event.pressed = true
  viewport.push_input(event, true)
 await frames(34)

func click(pos: Vector2):
 var vp = get_viewport()
 var move = InputEventMouseMotion.new()
 move.position = pos; move.global_position = pos
 vp.push_input(move, true)
 for pressed in[true, false]:
  var event = InputEventMouseButton.new()
  event.button_index = MOUSE_BUTTON_LEFT
  event.pressed = pressed; event.position = pos; event.global_position = pos
  event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
  vp.push_input(event, true)

func tap(cmd: String, arg = null):
 if cmd != "guide_next": await read_discoveries()
 await press_control(cmd, arg)

func read_discoveries():
 while game.dialog_key == "guide" and not failed:
  var entry = sim.s.guide.queue.front()
  if not check(game.paused, "discovery pauses the campaign"): return
  await press_control("guide_next")
  if not check(entry in sim.s.guide.read and entry not in sim.s.guide.queue, "discovery records " + entry): return

func press_control(cmd: String, arg = null):
 if failed: return
 await frames()
 var button = game.hud.find_button(cmd, arg)
 if not check(is_instance_valid(button), "control " + cmd + " " + str(arg) + " state " + str([game.hud.panel_key, game.dialog_key, game.world.selected])): return
 var parent = button.get_parent()
 while parent and not parent is ScrollContainer: parent = parent.get_parent()
 if parent is ScrollContainer:
  parent.ensure_control_visible(button)
  await frames()
 var p = button.get_global_rect().get_center()
 if not check(get_viewport().get_visible_rect().has_point(p), "button within viewport " + cmd): return
 click(p)
 await frames()

func key(code: Key):
 await read_discoveries()
 if failed: return
 for pressed in[true, false]:
  var event = InputEventKey.new()
  event.keycode = code; event.physical_keycode = code; event.pressed = pressed
  get_viewport().push_input(event, true)
 await frames()

var route_num = 0

func ticks(count: int):
 for i in count:
  await read_discoveries()
  if failed or game.paused: return
  var prior_turn = sim.s.turn
  game.sim_step()
  if sim.s.turn != prior_turn:
   var b = sim.s.last_ledger
   var spent = b.build + b.maintenance + b.advance + b.eat + b.loss + b.sow + b.spoil + b.operations + b.imports + b.recruit + b.land + b.husbandry + b.explore + b.freight_out + b.research
   if not check(b.opening + b.gather + b.crop + b.refund + b.exports + b.freight_in + b.livestock - spent == b.ending, "seasonal food ledger reconciles"): return
   var recent = sim.s.history
   if not check(recent.size() == mini(sim.s.turn, 8) and recent.back() == [sim.s.turn - 1, b.gather + b.crop + b.refund + b.exports + b.freight_in + b.livestock, spent], "eight-season chart matches settled accounts"): return
   for k in["wood", "stone"]:
    if not check(b[k + "_open"] + b[k + "_in"] - b[k + "_out"] == sim.s[k], "seasonal " + k + " ledger reconciles"): return
   if not check(sim.s.pop == sim.s.workers.size(), "population matches available worker records"): return
  while sim.s.pending in["birds", "weeds", "rain", "blight"] and not failed:
   var event = sim.s.pending
   var which = route_num if event == "rain" else 0
   if sim.s.food < sim.response_cost(event, which): which = 1
   if not check(sim.s.cause.has(event), "warning records its cause"): return
   await tap("decision", which)
   if sim.s.pending == "":
    await key(KEY_SPACE)
  if(i + 1) % 20 == 0: await frames(1)
 await read_discoveries()

func choose_cell(id: int):
 if failed: return
 game.world.focus(id)

 while game.world.camera_point.distance_to(game.world.destination) > 0.2: await frames(1)
 var position = game.world.camera.unproject_position(V.v3(V.center(id)))
 if not check(game.world.pick(position) == id, "map picking " + str(id)): return
 click(position)
 await frames(2)

func raise_food(amount: int, wood_keep: int = 0, stone_keep: int = 0):
 if sim.s.food >= amount or failed: return
 if game.hud.panel_key != "": await tap("closepanel")
 await tap("panel", "economy"); await tap("economy_tab", "market")
 for n in 120:
  if sim.s.food >= amount or failed or sim.s.outcome != "" or sim.s.pending != "": break
  if sim.s.stone >= S.E.LOT.stone + stone_keep: await tap("trade", ["stone", false])
  elif sim.s.wood >= S.E.LOT.wood + wood_keep: await tap("trade", ["wood", false])
  elif not game.paused: await ticks(1)
  else: break
 await tap("closepanel")

func supplies(wood: int, stone: int):
 if failed or(sim.s.wood >= wood and sim.s.stone >= stone): return
 if game.hud.panel_key != "": await tap("closepanel")
 await tap("panel", "economy"); await tap("economy_tab", "market")
 for kind in["wood", "stone"]:
  var need = wood if kind == "wood" else stone
  for attempt in 20:
   if failed or sim.s[kind] >= need: break
   if sim.s.food < 5: await ticks(8)
   else: await tap("trade", [kind, true])
  if not check(sim.s[kind] >= need, "supplies available for " + kind + " " + str([sim.s.food, sim.s[kind], need])): return
 await tap("closepanel")

func pave_to(id: int):
 if failed or sim.s.cells[id].connected: return
 var start = S.Roads.root(sim.s)
 if not check(start >= 0, "a road begins from a completed academy"): return
 for tile in S.Roads.path(sim.s, start, id):
  if sim.s.cells[tile].connected: start = tile
 var plan = S.Roads.quote(sim.s, start, id)
 await supplies(plan.wood, plan.stone)
 if game.hud.panel_key != "": await tap("closepanel")
 await key(KEY_G)
 await choose_cell(start); await choose_cell(id)
 if not check(sim.s.cells[id].connected, "road is connected to school at " + str(id) + " " + game.hud.toast): return
 await tap("street_end")

func build(kind: String, id: int):
 if kind != "academy" and kind != "levee" and S.Roads.root(sim.s) >= 0: await pave_to(id)
 var inputs = S.E.MATERIALS[kind]
 await supplies(inputs[0], inputs[1])
 await raise_food(S.BUILD[kind] [2], inputs[0], inputs[1])
 await tap("panel", "build")
 await tap("tool", kind)
 if not check(game.world.build_tool == kind, "selected construction tool " + kind + " in " + game.hud.panel_key): return
 await choose_cell(id)
 check(game.world.build_tool == "" and game.world.selected == id, "placed " + kind + " at " + str(id) + " " + game.hud.toast)

func maintain(kind: String, id: int):
 var inputs = S.E.MATERIALS[kind]
 await supplies(inputs[0], inputs[1])
 await raise_food(S.BUILD[kind] [2], inputs[0], inputs[1])
 await visit(id)
 if not check(sim.build_reason(kind, id) == "", "can " + kind + " at " + str(id) + " " + sim.build_reason(kind, id)): return
 await tap("site_work", [kind, id]); await finish_site(id)

func visit(id: int):
 await tap("panel", "crew")
 await tap("jump", id)

func finish_site(id: int):
 var job = "t" + str(id)
 var temporary_donor = ""
 if sim.s.cells[id].project != "" and sim.assigned(job) == 0:
  await tap("panel", "crew")
  if sim.free_workers() > 0: await tap("assign", [job, 1])
  else:
   var donors = ["t" + str(S.WILD[1]), "t" + str(S.WILD[0]), "t35", "t18"]
   var donor = ""
   for candidate in donors:
    if candidate != job and sim.assigned(candidate) > 0:
     donor = candidate
     break
   if donor == "":
    for plot in sim.farms():
     var candidate = "t" + str(plot)
     if candidate != job and sim.assigned(candidate) > 0 and not sim.s.cells[plot].crop:
      donor = candidate
      temporary_donor = candidate
      break
   if not check(donor != "", "available worker for site " + str(id)): return
   await tap("transfer_to", job)
   await tap("transfer_from", donor)
  await tap("closepanel")
 for i in 170:
  if failed or sim.s.cells[id].project == "": break
  await ticks(1)
 check(sim.s.cells[id].project == "", "completed site " + str(id) + " state " + str([sim.s.cells[id].project, sim.assigned("t" + str(id)), sim.s.pending]))
 if temporary_donor != "" and sim.free_workers() > 0 and sim.capacity(temporary_donor) > sim.assigned(temporary_donor):
  await tap("panel", "crew")
  await tap("assign", [temporary_donor, 1])
  await tap("closepanel")

func bank_notes(required: int = 0):
 if failed: return
 var ac = sim.academy_id()
 for i in 160:
  if sim.s.science + sim.s.cells[ac].notes >= required or failed: break
  await ticks(1)
 if not check(sim.s.science + sim.s.cells[ac].notes >= required, "academy produced requested knowledge"): return
 if sim.s.cells[ac].notes > 0:
  await tap("panel", "study"); await tap("academy")
  var before = sim.s.science
  var local = sim.s.cells[ac].notes
  await tap("collect", ac)
  check(sim.s.science == before + local and sim.s.cells[ac].notes == 0, "collection transfers points exactly once")

func seed_target() -> int:
 var needed = 0
 for plot in sim.farms():
  var next = S.F.Crops.for_sowing(sim.s, plot)
  needed += S.F.Crops.seed_cost(sim.s, next[0], next[1])
 return needed

func stock_seed(amount: int):
 if failed or sim.s.seed >= amount or sim.s.pending != "" or sim.s.food < 2: return
 if game.hud.panel_key != "": await tap("closepanel")
 await tap("panel", "crew")
 for n in 12:
  if sim.s.seed >= amount or sim.s.food < 2 or failed: break
  await tap("reserve", false)
 await tap("closepanel")

func learn(id: String):
 if failed: return
 var spec = sim.techs[id]
 var price = S.Study.bill(sim.s, id, spec)
 await bank_notes(S.Study.notes(sim.s, id, spec))
 await supplies(price[2], price[3])
 var desired = price[1] + seed_target()
 var missing = maxi(0, desired - sim.s.seed)
 await raise_food(price[0] + 2 * ceili(missing / 2.0), price[2], price[3])
 await stock_seed(desired)
 await tap("panel", "study")
 await tap("tech_branch", game.hud.Research.branch(sim, id))
 await tap("tech_era", spec[1])
 await tap("tech_view", id)
 if not check(sim.research_reason(id) == "", "can begin research " + id + " " + sim.research_reason(id)): return
 await tap("research", id); await tap("closepanel")
 for i in 75:
  if sim.s.tech.has(id) or failed: break
  await ticks(1)
 check(sim.s.tech.has(id), "staff completed research " + id + " " + str([sim.s.pending, sim.s.outcome, sim.s.study_time]))

func install_cistern():
 await supplies(3, 2)
 await tap("inventory")
 await tap("frontier_action", ["well", null])
 await tap("closepanel")

func food_for_season():
 var target = sim.s.pop + S.E.budget(sim.s).total
 if failed or sim.s.pending != "" or sim.s.outcome != "" or sim.s.food >= target: return
 var seed_floor = seed_target() if sim.s.turn % 4 == 3 else 2
 if sim.s.seed > seed_floor + 1:
  await tap("panel", "crew")
  while sim.s.food < target and sim.s.seed > seed_floor + 1 and not failed: await tap("reserve", true)
  await tap("closepanel")
 if sim.s.food >= target: return
 await tap("panel", "economy"); await tap("economy_tab", "market")
 for n in 12:
  if failed or sim.s.food >= target: break
  if sim.s.stone >= 5: await tap("trade", ["stone", false])
  elif sim.s.wood >= 6: await tap("trade", ["wood", false])
  else: break
 await tap("closepanel")

func extra_plot() -> int:
 var best = -1
 var score = INF
 for id in 72:
  if V.tier(id) < 0 or sim.s.cells[id].kind != "" or id in[34, 37, 38, 39, 40, 46, 47, 48]: continue
  var distance = V.distance(38, id) + (1 if V.tier(id) == 0 else 0)
  if distance < score: best = id; score = distance
 return best

func wait_ready():
 for n in 32:
  if sim.s.pending == "" and sim.s.food >= sim.s.pop + 3 and sim.s.turn % 4 in[0, 1]:
   var needed = 0
   for id in sim.farms():
    var next = S.F.Crops.for_sowing(sim.s, id)
    if not sim.s.cells[id].crop: needed += S.F.Crops.seed_cost(sim.s, next[0], next[1])
   await stock_seed(needed)
  if sim.s.era == 3 and sim.s.modern_harvest and not S.Town.seed_ready(sim): await stock_seed(seed_target())
  if sim.s.era == 3:
   if sim.s.pop < 12 and sim.recruit_reason() == "" and sim.s.food >= sim.s.pop + S.E.HIRE_FOOD:
    await tap("panel", "crew")
    await tap("recruit")
    await tap("closepanel")
   for site in sim.farms() + [34]:
    if sim.s.cells[site].condition <= S.Town.WORKING_CONDITION + 8 and sim.build_reason("repair", site) == "":
     await maintain("repair", site)
   var wonder = S.BUILD.university[2]
   var inputs = S.E.MATERIALS.university
   if sim.s.food < wonder and sim.s.food >= sim.s.pop:
    await raise_food(wonder, inputs[0], inputs[1])
   if sim.s.food >= wonder and (sim.s.wood < inputs[0] or sim.s.stone < inputs[1]):
    await supplies(inputs[0], inputs[1])
   if "--trace-campaign" in OS.get_cmdline_user_args():
    var working = sim.farms().map(func(site): return [site, sim.assigned("t" + str(site)), sim.s.cells[site].crop, sim.s.cells[site].condition])
    report("Planning %s: %s" % [sim.date(), [sim.advance_reason(), sim.s.food, sim.s.seed, sim.s.pop, sim.s.full, working]])
  if sim.advance_reason() == "可用口粮不足":
   await raise_food(S.Town.ERA_FOOD[sim.s.era])
  if failed or sim.advance_reason() == "": return
  if not check(sim.s.pending == "" and sim.s.outcome == "", "waiting for prerequisites " + str([sim.s.pending, sim.s.end_reason, sim.s.turn, sim.s.frontier.region, sim.s.last_report])): return
  if sim.s.era == 2 and sim.mean_soil() < 58:
   for id in sim.farms():
    var c = sim.s.cells[id]
    if c.soil < 64 and c.compost != sim.s.turn and S.Town.working(c) and sim.s.food >= 2:
     await visit(id); await tap("field", [id, "compost"])
   if sim.advance_reason() == "": return
  await ticks(maxi(0, S.SEASON_TIME - sim.s.clock - 1))
  if sim.s.era == 3 or difficulty == 2: await food_for_season()
  await ticks(1)
 check(sim.advance_reason() == "", "stage prerequisites " + str([sim.s.era, sim.advance_reason(), sim.s.food, sim.s.seed, sim.s.turn, sim.mean_soil(), sim.s.outcome, sim.s.last_report, sim.s.policy, sim.s.frontier.region]))

func pay_to_advance(era: int):
 if failed: return
 await wait_ready()
 if not check(sim.s.era == era and sim.s.outcome == "", "stage stays under player control"): return
 await tap("panel", "era"); await tap("review_era")
 if era == 0: await capture("07-era")
 var stock = sim.s.food
 var seeds = sim.s.seed
 var notes = sim.s.science
 await tap("back")
 if not check(sim.s.food == stock and sim.s.era == era, "cancel leaves stocks and era intact"): return
 await tap("review_era"); await tap("advance", era)
 var cost = S.Town.ERA_FOOD[era] if era < 3 else S.BUILD.university[2]
 if not check(sim.s.food == stock - cost and sim.s.seed == seeds, "era %d payment: food %d to %d, seeds %d to %d, current era %d, dialog %s" % [era, stock, sim.s.food, seeds, sim.s.seed, sim.s.era, game.dialog_key]): return
 if era < 3:
  check(sim.s.era == era + 1 and sim.s.pending == "", "new era does not dispatch a disaster")
  var checkpoint = game.saves.read("chapter")
  check(checkpoint.era == sim.s.era and checkpoint.food == sim.s.food, "chapter checkpoint contains paid inventory")
  check(sim.advance(era) != "" and sim.s.food == stock - S.Town.ERA_FOOD[era], "stale transition cannot debit twice")
  await read_discoveries()
  check("era/" + str(era + 1) in sim.s.guide.read, "first entry into era shows its cultural folio")
 else:
  var campus = sim.academy_id()
  if not check(sim.s.cells[campus].project == "university" and sim.s.outcome == "" and sim.s.science == notes - S.UNIVERSITY_NOTES, "funding starts construction and debits notes"): return
  await finish_site(campus)
  check(sim.s.outcome == "won" and sim.s.cells[campus].campus == "university", "victory follows completion of China Agricultural University")

func first_seasons():
 await tap("new")
 await capture("08-difficulty")
 for option in OS.get_cmdline_user_args():
  if option.begins_with("--random-test-seed="): seed(int(option.trim_prefix("--random-test-seed=")))
 await tap("difficulty", difficulty)
 if game.dialog_key == "restart": await tap("confirmed_new")
 report("Campaign start: %s, camp %d" % [S.F.REGIONS[sim.s.frontier.region], sim.s.frontier.home])
 if not check(game.playing and sim.s.science == 0 and game.world.selected == S.WILD[0], "new camp starts with zero technology points"): return
 if not check(game.dialog_key == "guide" and sim.s.guide.queue.front().begins_with("env/"), "opening presents the chosen environment"): return
 await capture("v110-opening")
 await read_discoveries()
 for i in 3: await tap("assign", ["t" + str(S.WILD[0]), 1])
 check(sim.assigned("t" + str(S.WILD[0]), true) == 0, "workers must travel before working")
 await tap("assign", ["t" + str(S.WILD[0]), -1])
 check(sim.free_workers() == 8, "unassigned worker becomes available")
 await visit(S.WILD[1])
 for i in 2: await tap("assign", ["t" + str(S.WILD[1]), 1])
 await tap("panel", "crew")
 for i in 3: await tap("reserve", false)
 await tap("closepanel")
 await visit(18)
 await tap("assign", ["t18", 1])
 var food_before = sim.s.food
 var free_before = sim.free_workers()
 await build("house", 46)
 await tap("cancel_project", "t46")
 if not check(sim.s.cells[46].project == "" and sim.free_workers() == free_before and sim.s.food == food_before, "cancelling untouched construction returns grain and workers"): return
 await build("academy", 38)
 await tap("assign", ["t38", 1])
 await finish_site(38)
 await pave_to(sim.s.frontier.home); await pave_to(18); await pave_to(35)
 await ticks(20)
 check(sim.s.science == 0 and sim.s.cells[38].notes >= 2, "notes stay at school until a player claims them")
 await capture("06-academy")
 await learn("seed")
 var inventory = sim.s.food
 await tap("panel", "build"); await tap("tool", "farm"); await choose_cell(41)
 check(game.world.build_tool == "farm" and sim.s.food == inventory, "river placement rejected without spending")
 await key(KEY_ESCAPE)
 await build("farm", low); await build("farm", upland)
 await finish_site(upland)
 await learn("dry")
 if sim.s.frontier.region == 4: await install_cistern()
 await build("store", 34); await build("house", 46)
 await finish_site(34); await finish_site(46)
 await key(KEY_SPACE)
 var frozen = sim.s.time
 game.sim_step(); check(sim.s.time == frozen, "paused clock freezes work")
 await key(KEY_3)
 check(not game.paused and game.speed == 4, "4x keyboard input")
 game.testing = false; game._process(0.25); game.testing = true
 check(sim.s.time == frozen + 1, "one quarter second advances a tick at 4x")
 await key(KEY_1)
 await tap("pausemenu"); await tap("save")
 var manual = game.saves.read("campaign")
 check(manual.workers == sim.s.workers and manual.cells[38].lesson == sim.s.cells[38].lesson, "workers and partial lessons saved")
 await tap("pausemenu"); await tap("settings"); await tap("sound"); await tap("sound"); await tap("back"); await tap("back")
 await tap("forecast")
 await capture("v110-weather")
 await tap("closepanel")
 await capture("02-river-valley")
 await tap("deselect"); await tap("fold_goals")
 await zoom_view(MOUSE_BUTTON_WHEEL_UP, 6)
 check(game.world.target_zoom < 11, "wheel zoom reaches individual fields")
 await capture("12-harvest-detail")
 await zoom_view(MOUSE_BUTTON_WHEEL_DOWN, 6)
 await tap("fold_goals")
 await wait_ready()
 if not check(sim.s.era == 0 and sim.s.pop == 10, "full rations and housing do not create residents"): return
 await tap("panel", "crew")
 var food = sim.s.food
 var wood = sim.s.wood
 await tap("recruit"); await tap("recruit")
 if not check(sim.s.pop == 12 and sim.s.food == food - 12 and sim.s.wood == wood - 4, "two deliberate hires cost food and timber"): return
 await tap("assign", ["t35", 1])
 await capture("09-workforce")
 await tap("closepanel")
 await raise_food(5)
 await tap("panel", "economy"); await tap("budget", 0); await tap("budget", 1); await capture("10-budget")
 await tap("economy_tab", "market")
 var stock = sim.s.stone
 await tap("trade", ["stone", true]); await tap("trade", ["stone", false])
 check(sim.s.stone == stock, "dock trades are reachable in the resource overview")
 await tap("economy_tab", "history"); await capture("13-season-accounts"); await tap("closepanel")
 await ticks(2)
 await bank_notes()
 for n in 160:
  if sim.s.turn % 4 == 1 and sim.s.clock < 6: break
  await ticks(1)
 await pay_to_advance(0)
 await learn("dike"); await learn("scout")
 await stock_seed(seed_target() * 2)
 for i in 240:
  if failed or sim.s.pending == "flood": break
  await ticks(1)
 if not check(sim.s.pending == "flood", "seasonal summer flood warning"): return
 var common = game.saves.read("campaign")
 check(common.pending == "flood" and common.time == sim.s.time, "warning auto-saved on its own tick")
 game.saves.put("comparison", common)
 await capture("03-flood-warning")
 game.show_title(); await tap("continue")
 check(sim.s.pending == "flood" and game.paused, "reload preserves unresolved event")

func route(index: int):
 if failed: return
 route_num = index
 if index == 1: game.start_game(game.saves.read("comparison"))
 await tap("decision", index)
 check(game.paused and sim.s.pending == "", "decision leaves time for deployment")
 if index == 0: await build("levee", low)
 await key(KEY_SPACE)
 await ticks(S.SEASON_TIME - sim.s.clock)
 check(sim.s.flood_time > 0 and sim.s.flood_cells.has(low) == (index == 1), "placement changes flood reach")
 check(sim.s.cells[low].crop == (index == 0), "field behind dyke keeps standing crop " + str([sim.s.seed, sim.s.turn, sim.s.cells[low].care, sim.s.cells[low].harvests, sim.s.frontier.region]))
 results.append([sim.s.flood_cells.size(), sim.s.rescued, sim.s.lost])
 if index == 0:
  await tap("panel", "risk"); await tap("overlay", "")
  await ticks(4); await capture("04-high-water")
 await tap("panel", "crew")
 for i in 3:
  if sim.s.seed < 4: await tap("reserve", false)
 await tap("closepanel")
 await maintain("repair", 34)
 check(sim.s.cells[34].condition >= 99, "paid repair restores condition")
 await pay_to_advance(1)
 if sim.s.frontier.region == 4: await install_cistern()
 if difficulty == 2:
  await tap("panel", "economy"); await tap("budget", 0); await tap("closepanel")
 if difficulty > 0 and sim.free_workers() > 0:
  await visit(S.WILD[2])
  await tap("assign", ["t" + str(S.WILD[2]), 1])
 var new_field = extra_plot(); await build("farm", new_field); await finish_site(new_field)
 if difficulty > 0:
  var fourth = extra_plot(); await build("farm", fourth); await finish_site(fourth)
 await stock_seed(seed_target())
 await learn("terrace"); await learn("rotate")
 if index == 0:
  await build("terrace", low); await finish_site(low)
  await build("canal", 40); await finish_site(40)
  await learn("nursery")
  await build("nursery", 48); await finish_site(48)
  for i in 280:
   if failed or(sim.s.policy.has("blight") and sim.s.policy.has("weeds")): break
   await ticks(1)
  check(sim.s.policy.has("blight") and sim.s.policy.has("weeds") and sim.s.era == 2, "irrigation and shared nursery cause distinct crises before modern age")
 else:
  await visit(upland); await tap("field", [upland, "rotation"])
  await maintain("upgrade", 34)
  check(sim.s.cells[34].level == 2 and S.Town.storage(sim.s) == 120, "level-two warehouse increases usable capacity")
 if difficulty > 0:
  for id in sim.farms():
   if not sim.s.cells[id].rotation and sim.s.food >= 2:
    await visit(id); await tap("field", [id, "rotation"])
  if difficulty == 2 or sim.free_workers() > 0:
   var extra = extra_plot(); await build("farm", extra); await finish_site(extra)
 await pay_to_advance(2)
 for season in 2:
  await ticks(S.SEASON_TIME - sim.s.clock - 1)
  await food_for_season()
  await ticks(1)
 check(not sim.s.policy.has("runoff") and sim.s.water == [0, 0, 0], "two modern seasons without fertilizer do not produce runoff")
 await learn("machine"); await learn("precise")
 if index == 0:
  await build("ditch", low); await finish_site(low)
  await learn("fertilizer")
  await visit(low); await tap("field", [low, "fertilized"])
  check(sim.s.pending == "runoff" and sim.s.cause.runoff.tile == low, "first fertilizer application raises warning at its actual site")
  game.show_title(); await tap("continue")
  check(sim.s.pending == "runoff", "technology warning survives restart")
  await tap("decision", 0); await key(KEY_SPACE)
  await visit(low); await tap("field", [low, "precise"])
 else:
  await build("station", 47); await finish_site(47)
  check(not sim.s.policy.has("blight") and not sim.s.policy.has("weeds"), "low-input route avoids undeployed technologies' hazards")
  await tap("panel", "risk"); await tap("overlay", "")
  await visit(47)
  await zoom_view(MOUSE_BUTTON_WHEEL_UP, 5)
  await capture("11-modern-valley")
  await tap("assign", ["t47", -1])
  check(game.hud.staff_alerts.has(47) and game.hud.refs.vacancies.visible, "unattended machine station appears in settlement alerts")
  await tap("staff_alert"); await tap("assign", ["t47", 1])
  check(not game.hud.staff_alerts.has(47), "assigning a replacement clears the station alert")
  await tap("closepanel")
 if difficulty == 2:
  var extra = extra_plot(); await build("farm", extra); await finish_site(extra)
  await stock_seed(seed_target())
 for id in sim.farms():
  if not sim.s.cells[id].rotation:
   await visit(id)
   await tap("field", [id, "rotation"])
  if difficulty == 2 and sim.s.food >= 2 + sim.s.pop and not sim.s.cells[id].precise:
   await visit(id)
   await tap("field", [id, "precise"])
 await build("engineering", extra_plot())
 await finish_site(game.world.selected)
 await maintain("agcollege", sim.academy_id())
 await bank_notes(S.UNIVERSITY_NOTES)
 if difficulty < 2:
  var university_inputs = S.E.MATERIALS.university
  await supplies(university_inputs[0], university_inputs[1])
  await raise_food(S.BUILD.university[2], university_inputs[0], university_inputs[1])
 else:
  var academy_job = "t" + str(sim.academy_id())
  for site in [35, 18, S.WILD[0], S.WILD[1]]:
   var job = "t" + str(site)
   if sim.assigned(job) > 0: continue
   await tap("panel", "crew")
   if sim.free_workers() > 0:
    await tap("assign", [job, 1])
   elif sim.assigned(academy_job) > 0:
    await tap("transfer_to", job)
    await tap("transfer_from", academy_job)
   await tap("closepanel")
 await pay_to_advance(3)
 if failed: return
 report("PASS route %d: %d seasons, population %d, food %d, seeds %d, downstream pollution %d, warnings %s, flooded/rescued/lost %s" % [index + 1, sim.s.turn, sim.s.pop, sim.s.food, sim.s.seed, sim.s.water[2], sim.s.policy.keys(), results.back()])
 if index == 0: await capture("05-victory")

func frontier_campaign():
 await tap("new"); await tap("region", 4); await capture("beta-start")
 await tap("difficulty", 0)
 if game.dialog_key == "restart": await tap("confirmed_new")
 var s = sim.s
 if not check(s.frontier.region == 4 and s.frontier.fresh == 22 and V.biome == 4, "chosen coastal ecosystem loads its estuary"): return
 for id in[S.WILD[0], S.WILD[1]]:
  await visit(id)
  for n in 2: await tap("assign", ["t" + str(id), 1])
 await build("academy", 38); await finish_site(38)
 await pave_to(s.frontier.home)
 await tap("inventory")
 await tap("frontier_action", ["well", null])
 await capture("beta-coast-water")
 await tap("panel", "frontier"); await tap("frontier_tab", "探险")
 await tap("frontier_action", ["survey", [1, "粟"]])
 if not check(s.pop == 8 and S.F.people_total(s) == 10 and sim.recruit_reason() != "", "departing scouts reserve two beds"): return
 await ticks(7)
 await tap("pausemenu"); await tap("save")
 game.show_title(); await tap("continue")
 s = sim.s
 if not check(s.frontier.missions.size() == 1 and s.frontier.region == 4, "coastal voyage survives saving and loading"): return
 await ticks(25)
 if not check(s.pop == 10 and s.frontier.samples["粟"] == [2, 2] and 1 in s.districts, "scouts return once with two millet parents"): return
 await tap("panel", "frontier"); await tap("frontier_tab", "种圃"); await tap("atlas_crop", "粟")
 await tap("frontier_action", ["trial", ["粟", 0]])
 await learn("seed")
 var yard = 36
 await build("pasture", yard); await finish_site(yard)
 await visit(yard)
 for cmd in ["hens", "goats", "feed"]: await tap("frontier_action", [cmd, [yard]])
 await ticks(S.SEASON_TIME - s.clock)
 if not check(s.frontier.yards[yard].eggs == 1 and s.frontier.yards[yard].milk == 2, "road-connected coastal pasture produces food"): return
 await capture("beta-herds")
 var before = s.food
 await tap("frontier_action", ["provision", [yard]])
 check(s.food == before + 3, "fresh dairy and eggs turn into rations on demand")
 await tap("panel", "frontier")
 await tap("frontier_tab", "运输")
 await tap("street_between", [0, 1]); await tap("street_confirm")
 await tap("panel", "frontier"); await tap("frontier_tab", "运输")
 await tap("load_size", false)
 await tap("frontier_action", ["ship", [0, 1, "people", 1]])
 await tap("frontier_action", ["ship", [0, 1, "food", 1]])
 await capture("beta-roads")
 await ticks(32)
 if not check(s.frontier.lines.has("粟") and s.frontier.posts[1].people == 1 and s.frontier.posts[1].food >= 1, "delivered cargo, resident and domesticated crop are usable"): return
 await tap("frontier_tab", "种圃"); await tap("atlas_crop", "粟")
 await tap("frontier_action", ["trial", ["粟", 1]])
 await capture("beta-crops")
 await tap("closepanel")
 await tap("panel", "crew"); await tap("reserve", false); await tap("closepanel")
 await build("farm", 37); await finish_site(37)
 await visit(37); await tap("frontier_action", ["sow", [37, "粟"]])
 for n in 220:
  if failed or(s.cells[37].crop and S.F.Crops.field_species(s, 37) == "粟"): break
  if s.seed < 2 and s.food >= 2 and not s.cells[37].crop: await tap("site_reserve", 0)
  await ticks(1)
 if not check(s.cells[37].crop and S.F.Crops.field_species(s, 37) == "粟" and s.frontier.lines["粟"].vigor == 1, "bred millet is growing in a player-operated field"): return
 await visit(37); await zoom_view(MOUSE_BUTTON_WHEEL_UP, 5); await capture("beta-millet-field")
 report("PASS coastal UI: region art, freshwater, scouts and saved return, two parents, milk and eggs, road, freight, migration and actual millet crop")
 game.shutdown(0)

func lesson_campaign():
 await tap("new"); await tap("region", 2); await tap("difficulty", 0)
 if game.dialog_key == "restart": await tap("confirmed_new")
 var s = sim.s
 if not check(s.lesson_step == 0 and game.hud.tech_key == "seed" and sim.tech_name("seed") == "麦穗选种", "Danube starts with the wheat notebook and first task"): return
 await tap("hint")
 for n in 2: await tap("assign", ["t19", 1])
 await visit(42)
 for n in 2: await tap("assign", ["t42", 1])
 await tap("hint"); await choose_cell(38); await finish_site(38)
 await tap("hint")
 if not check(game.world.build_tool == "street" and game.world.road_end == s.frontier.home, "tutorial previews a funded road to the camp"): return
 await capture("formal-street")
 await tap("street_confirm")
 await tap("hint"); await tap("assign", ["t38", 1])
 await ticks(20); await tap("collect", 38)
 await tap("hint"); await tap("research", "seed"); await tap("closepanel"); await ticks(10)
 await tap("hint"); await choose_cell(39); await finish_site(39)
 await visit(39)
 if not check(not s.cells[39].connected and sim.expected_yield(39) == 0, "new disconnected farm shows an operational warning"): return
 await capture("formal-offline"); await tap("street_to", 39); await tap("street_confirm")
 await tap("hint"); await tap("site_reserve", 0)
 await ticks(2)
 if not check(s.cells[39].crop and s.lesson_step == 7, "live tutorial follows actual first sowing"): return
 await capture("formal-lesson")
 for n in 180:
  if s.first_crop or failed: break
  await ticks(1)
 if not check(s.lesson_step == 8 or(s.first_crop and s.lesson_step == 7), "first harvest reached"): return
 await ticks(1)
 if not check(s.lesson_step == 8, "eight lessons completed by play"): return
 await tap("panel", "study"); await tap("tech_branch", "全部"); await tap("tech_context_menu"); await tap("tech_context", "农具"); await tap("tech_era", 1); await tap("tech_view", "drill")
 await capture("formal-almanac")
 await tap("closepanel"); await tap("panel", "frontier"); await tap("frontier_tab", "探险")
 await tap("frontier_action", ["survey", [1, "稻"]]); await ticks(32)
 await tap("closepanel"); await tap("panel", "study"); await tap("tech_context_menu"); await tap("tech_context", "稻"); await tap("tech_era", 0); await tap("tech_view", "rice_1")
 if not check(S.Study.discovered(s, "稻") and not s.frontier.lines.has("稻"), "new crop research opens when the sample arrives"): return
 await capture("formal-new-crop"); await tap("closepanel")
 await key(KEY_G); await tap("street_mode"); await choose_cell(38); await choose_cell(39)
 if not check(s.cells[39].connected, "demolition waits for confirmation"): return
 await tap("street_confirm")
 if not check(not s.cells[39].connected, "removing the physical path suspends the farm"): return
 await tap("pausemenu"); await tap("save"); game.show_title(); await tap("continue")
 if not check(sim.s.lesson_step == 8 and not sim.s.cells[39].connected and S.Study.discovered(sim.s, "稻"), "tutorial, roads and curricula survive a restart"): return
 report("PASS formal tutorial, interactive paving, demolition preview, wheat research, sample discovery and persistent field state")
 game.shutdown(0)

func v110_rules():
 var model = S.new()
 var state = model.s
 if not check(state.guide.queue.front() == "env/长江湿地" and "crop/稻" in state.guide.queue, "new game queues its environment and local crop"): return
 var initial = S.Guide.entry("era/0")
 if not check(initial.body == S.Guide.COPY.data.eras[0].body and S.Guide.entry("env/长江湿地").body == S.Guide.COPY.data.environments["长江湿地"], "author copy and missing-copy placeholders survive export"): return
 var yard_rules = S.F.Farm.Yards
 state.cells[38].kind = "academy"
 state.cells[39].kind = "farm"
 state.cells[36].kind = "pasture"
 for plot in [36, 39]: S.Roads.inherit_path(state, 38, plot)
 S.Roads.rebuild(state)
 state.frontier.yards[36] = yard_rules.herd()
 model.assign("t36", 1)
 for step in 15: model.work()
 if not check(yard_rules.status(state, 36) == "", "pasture requires a connected and staffed plot"): return
 for action in ["hens", "goats", "feed"]:
  if not check(yard_rules.reason(state, action, [36]) == "", "pasture can " + action): return
  yard_rules.action(state, action, [36])
 yard_rules.settle(model)
 if not check(state.frontier.yards[36].eggs == 1 and state.frontier.yards[36].milk == 2, "local feed produces eggs and milk"): return
 state.weather.threat = "旱灾"
 var stock = state.food
 var timber = state.wood
 var soil = state.cells[39].soil
 if not check(S.Weather.prepare(model) == "" and state.food == stock - 2 and state.wood == timber - 1, "weather defense books its cost"): return
 if not check(S.Weather.prepare(model) != "" and state.food == stock - 2, "weather defense cannot charge twice"): return
 S.Weather.settle(model)
 if not check(state.cells[39].soil == soil - 3 and state.weather.history.size() == 1, "prepared drought limits damage and is recorded"): return
 var old = state.duplicate(true)
 old.version = 5
 old.frontier.merge({"pens": 1, "hens": 1, "goats": 1, "eggs": 1, "milk": 2, "manure": 0, "bedding": 0, "broods": {}}, true)
 old.frontier.erase("yards")
 old.erase("weather")
 old.erase("guide")
 var migrated = S.new()
 migrated.restore(old)
 if not check(migrated.s.version == 8 and yard_rules.total(migrated.s, "hens") == 1 and yard_rules.total(migrated.s, "milk") == 2, "old livestock and milk survive save migration"): return
 report("PASS authored culture, first discoveries, weather defense and damage, pasture production, and legacy herd migration")
 game.shutdown(0)

func curriculum_campaign():
 game.start_game()
 await read_discoveries()
 await tap("panel", "study")
 await tap("tech_branch", "育种")
 await tap("tech_view", "seed_selection")
 await tap("study_focus")
 await tap("focus_preview", "育种")
 if not check(game.hud.find_button("focus_confirm","育种") == null, "an early camp can inspect but cannot commit to a focus"): return
 await tap("back")
 # A modern checkpoint isolates the new controls from the independent complete campaign replays.
 var s = sim.s
 s.era = 3; s.food = 75; s.seed = 12; s.wood = 30; s.stone = 22; s.science = 12
 s.cells[38].kind = "academy"; s.cells[39].kind = "farm"
 S.Roads.inherit_path(s,38,39); S.Roads.rebuild(s)
 sim.assign("t38",1); sim.assign("t39",1)
 for w in s.workers: w.travel = 0
 s.cells[48].kind = "farm"; s.cells[39].harvests = 1; s.cells[48].harvests = 1
 S.Roads.inherit_path(s,38,48); S.Roads.rebuild(s)
 s.tech = ["seed","dry","stone_tools","plough","deep_plowing","machine","tractor","intensive_planting"]
 s.ledger = sim.book(s.food + s.seed,s.wood,s.stone)
 S.Guide.discover(s)
 game.start_game(s.duplicate(true))
 await read_discoveries()
 await tap("panel","study");await tap("study_focus");await tap("focus_preview","耕作")
 await capture("v115-specialization")
 await tap("focus_confirm","耕作")
 if not check(sim.s.research_record.focus == "耕作" and game.dialog_key == "", "specialization chosen from confirmation"): return
 await tap("tech_branch","耕作");await tap("tech_era",3);await tap("tech_view","combine")
 if not check("winnow" not in s.tech and sim.research_reason("combine") == "", "two connected fields open alternative combine research without winnowing"): return
 await capture("research-handbook")
 await tap("tech_map")
 var graph = game.hud.modal.find_children("*","GraphEdit",true,false)[0]
 if not check(graph.has_node("route_0") and graph.has_node("route_1"), "two named routes visible on the diagram"): return
 await capture("research-routes")
 await tap("map_mode",true)
 var graphs = game.hud.modal.find_children("*","GraphEdit",true,false)
 if not check(graphs.size() == 1 and graphs[0].get_connection_list().size() > 50, "connected research graph can be opened"): return
 await capture("research-network")
 await tap("map_mode",false);await tap("goto_tech","tractor")
 if not check(game.hud.tech_key == "tractor" and game.dialog_key == "", "graph opens the selected prerequisite"): return
 await tap("tech_view","combine");await tap("research","combine")
 if not check(sim.s.study == "combine" and sim.s.science == 4, "UI charged the eight-note specialty price"): return
 await ticks(S.SEASON_TIME)
 if not check(sim.s.research_record.terms == 1 and sim.s.study == "combine", "the first observed term was saved at season end"): return
 game.show_title();await tap("continue");await read_discoveries()
 if not check(sim.s.research_record.terms == 1 and sim.s.research_record.focus == "耕作", "resume keeps evidence and specialty"): return
 await tap("panel","study");await tap("tech_branch","耕作");await tap("tech_view","combine")
 await tap("withdraw_study","combine");await tap("back")
 await capture("farm-evidence")
 await ticks(S.SEASON_TIME)
 if not check("combine" in sim.s.tech and sim.s.study == "", "project completes in an operating settlement"): return
 await alternative_era_controls()
 if failed: return
 report("PASS native research handbook, alternative route without winnowing, diagram navigation, specialization cost, two seasons and save/resume")
 game.shutdown(0)

func alternative_era_controls():
 # Prepare a flood survivor with a safe store. Advance via grain storage in both eras.
 sim.reset(0,0)
 var s = sim.s
 s.era = 1; s.food = 85; s.seed = 9; s.full = 2
 s.flood_at = 0; s.flood_time = 0; s.resown = true
 s.tech = ["seed","dry","basic_protection","market_trade"]
 for entry in [[38,"academy"],[39,"farm"],[37,"farm"],[34,"store"],[35,"house"]]:
  s.cells[entry[0]].kind = entry[1]
  S.Roads.inherit_path(s,38,entry[0])
 S.Roads.rebuild(s); S.Guide.setup(s,true)
 game.start_game(s.duplicate(true)); await read_discoveries()
 if not check(sim.advance_reason() == "", "high-store route can advance after the real flood requirements"): return
 await tap("panel","era"); await capture("era-choice"); await tap("review_era"); await tap("advance",1)
 if not check(sim.s.era == 2 and sim.s.food == 65 and "scout" not in sim.s.tech, "high-store route pays the normal era fee"): return
 await read_discoveries()
 s = sim.s
 s.tech.append_array(["rotate","seed_vault"]); s.cells[34].level = 2; s.cells[39].rotation = true
 s.rain = true; s.full = 2; s.rev += 1; game.refresh(true)
 await tap("panel","era"); await tap("review_era"); await tap("advance",2)
 if not check(sim.s.era == 3 and sim.s.food == 33 and "terrace" not in sim.s.tech, "crop rotation and storage reach modern era without terraces"): return
 report("PASS two alternative era gates with real controls, food debits, and historical prerequisites absent")

func run(main, out: String):
 game = main; sim = main.sim; folder = out
 seed(20261122)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--difficulty-test="): difficulty = int(arg.trim_prefix("--difficulty-test="))
 picture = DisplayServer.get_name() != "headless"
 report("Native replay on " + DisplayServer.get_name() + " at " + str(DisplayServer.window_get_size()))
 if "--research-routes" in OS.get_cmdline_user_args() or "--v115-ui" in OS.get_cmdline_user_args():
  await frames(10); await curriculum_campaign(); return
 if "--v110-rules" in OS.get_cmdline_user_args():
  v110_rules()
  return
 if "--formal-test" in OS.get_cmdline_user_args():
  await frames(10); await lesson_campaign(); return
 if "--frontier-test" in OS.get_cmdline_user_args():
  await frames(10)
  await frontier_campaign()
  return
 await frames(12); await capture("01-title")
 low = 39; upland = 37
 await first_seasons()
 if failed: return
 await route(0)
 if failed: return
 await route(1)
 if failed: return
 check(results[0] [0] < results[1] [0] and results[1] [1] > results[0] [1] and results[0] [2] > results[1] [2], "shared checkpoint gives distinct flood and transport outcomes")
 await tap("title"); await tap("new"); await tap("difficulty", 0); await tap("confirmed_new")
 await read_discoveries()
 var chart = game.hud.refs.map
 var outer = 73
 var position = chart.get_global_rect().position + chart.chart_point(V.center(outer))
 click(position); await frames()
 check(game.world.selected == outer and sim.capacity("t73") == 0, "unclaimed map sector can be surveyed")
 await tap("claim", V.sector(outer))
 await build("academy", 38); await finish_site(38); await pave_to(outer)
 await visit(outer); await tap("assign", ["t73", 1])
 await ticks(20)
 check(sim.s.districts.has(V.sector(outer)) and sim.s.frontier.posts[V.sector(outer)].wood > 0, "outer sector is staffed and productive")
 await tap("panel", "crew"); await tap("transfer_to", "t18"); await tap("transfer_from", "t73")
 check(sim.assigned("t18") == 1 and sim.assigned("t73") == 0, "one worker transfers directly between sites")
 await tap("closepanel")
 await ticks(6 * S.SEASON_TIME)
 check(sim.s.outcome == "lost" and sim.s.science == 0 and sim.s.pop < 10, "shortage reduces population, famine ends game, time grants no knowledge")
 await tap("retry")
 await read_discoveries()
 check(sim.s.turn == 0 and sim.s.food == S.E.DIFFICULTIES[0].food and sim.s.pop == 10 and sim.s.outcome == "" and sim.s.districts == [0], "chapter retry restores difficulty, regions and stocks")
 if failed: return
 report("PASS comparison, difficulty %s, recruitment, workforce transfers, service budgets, expanded map, school, paid era gates, causal risks, seasonal ledgers and saves" % S.E.DIFFICULTIES[difficulty].name)
 game.shutdown(0)
