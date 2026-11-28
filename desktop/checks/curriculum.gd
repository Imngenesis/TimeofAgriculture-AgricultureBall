extends SceneTree

const M = preload("res://simulation.gd")
const R = preload("res://agronomy.gd")
const CUR = preload("res://curriculum.gd")
const C = preload("res://crop_book.gd")
const Saves = preload("res://saves.gd")
var errors = 0
var checks = 0

func expect(ok: bool, label: String):
	checks += 1
	if not ok:
		errors += 1
		printerr("FAIL " + label)

func campus(region: int = 0):
	var m = M.new()
	m.reset(0, region)
	var s = m.s
	s.era = 3
	s.food = 75;s.seed = 12;s.wood = 32;s.stone = 22
	s.cells[38].kind = "academy"
	s.cells[39].kind = "farm"
	s.cells[34].kind = "store"
	m.Roads.inherit_path(s, 38, 39)
	m.Roads.inherit_path(s, 38, 34)
	m.Roads.rebuild(s)
	m.assign("t38", 1);m.assign("t39", 1)
	for w in s.workers: w.travel = 0
	return m

func catalog():
	var m = campus()
	var done = []
	for pass_index in m.techs.size():
		for id in m.techs:
			if id in done: continue
			var groups = R.prerequisites(m.techs, id)
			if groups.all( func(group): return group.keys.all( func(pre): return pre in done)): done.append(id)
	expect(done.size() == m.techs.size(), "no missing dependencies or cycles")
	expect(m.techs.size() == 79 and CUR.TOPICS.data.size() == 47, "published topic count")
	for key in m.techs:
		for group in R.prerequisites(m.techs, key):
			for pre in group.keys: expect(m.techs.has(pre) and m.techs[pre][1] <= m.techs[key][1], "reachable prerequisite for " + key)
	var count = [0, 0, 0, 0]
	var regions = []
	for key in CUR.TOPICS.data:
		var row = CUR.TOPICS.data[key]
		var era = int(row.era)
		count[era] += 1
		var place = int(row.get("region", 0))
		if row.has("region"): regions.append(place)
		m = campus(place)
		var s = m.s
		s.era = era
		s.tech = row.requires.duplicate()
		for group in row.get("requires_any", []): s.tech.append(group[0])
		if row.has("event"):
			expect(m.research_reason(key).contains("旱灾"), "drought history gates only its trial")
			s.research_record.hazards.append(row.event)
		for track in CUR.TRACKS:
			s.research_record.focus = track
			expect(R.notes(s, key, m.techs[key]) <= R.limit(s, 1), "attainable note cap " + key + track)
		s.research_record.focus = ""
		s.science = int(row.notes)
		var stocks = [s.food, s.seed, s.wood, s.stone]
		var bill = R.bill(s, key, m.techs[key])
		expect(m.research(key) == "", "research accepts eligible " + key)
		expect(s.science == 0 and s.study == key, "single note debit " + key)
		expect(m.research(key) != "" and s.science == 0, "duplicate research rejected " + key)
		expect([s.food, s.seed, s.wood, s.stone] == [stocks[0] - bill[0], stocks[1] - bill[1], stocks[2] - bill[2], stocks[3] - bill[3]], "exact materials " + key)
		for i in R.timing(m.techs[key]): m.work()
		if CUR.terms(key) > 0:
			expect(key not in s.tech and s.study_time == 0, "labour alone cannot finish " + key)
			for term in CUR.terms(key):
				if term > 0:
					for i in CUR.OBSERVATIONS: m.work()
				m.finish_season()
		expect(key in s.tech and s.study == "", "earned topic " + key)
	expect(count == [6, 12, 16, 13], "era distribution")
	regions.sort();expect(regions == [0, 1, 2, 3, 4, 5], "each starting region has a local technique")
	m = campus(4)
	m.s.tech = ["water_management"];m.s.science = 10
	expect(m.research_reason("polder_drain").contains("长江湿地"), "regional curriculum enforced by model")
	expect(m.research("coastal_cistern") == "", "coastal option can be studied")

func optional_research():
	var m = campus()
	var s = m.s
	var spec = m.techs.machine
	s.tech = ["plough"]
	s.science = 18
	expect(m.research_reason("machine").contains("留种"), "an aid cannot replace a required prerequisite")
	s.tech = ["seed"]
	var full = [R.notes(s, "machine", spec), R.bill(s, "machine", spec), R.research_time(s, "machine", spec)]
	expect(m.research_reason("machine") == "", "machine research is available without any assistance")
	s.tech.append("plough")
	var discounted = [R.notes(s, "machine", spec), R.bill(s, "machine", spec), R.research_time(s, "machine", spec)]
	expect(full == [5, [5, 2, 3, 2], 40] and discounted == [4, [4, 1, 2, 1], 32], "optional research reduces notes, materials and labour")
	s.tech.append("large_field_management")
	expect(R.notes(s, "machine", spec) == 4 and R.research_time(s, "machine", spec) == 32, "multiple aids do not stack")
	var materials = [s.food, s.seed, s.wood, s.stone]
	expect(m.research("machine") == "" and s.science == 14 and s.study_time == 32 and s.research_record.study_total == 32, "actual research charges the discounted quote")
	expect([s.food, s.seed, s.wood, s.stone] == [materials[0] - 4, materials[1] - 1, materials[2] - 2, materials[3] - 1], "actual material debit uses the discounted quote")
	var loaded = M.new()
	loaded.restore(s.duplicate(true))
	expect(loaded.s.study_time == 32 and loaded.s.research_record.study_total == 32, "discounted research duration persists")

func nonlinear_routes():
	var m = campus()
	var s = m.s
	s.science = 20
	s.era = 0
	s.tech = ["seed"]
	expect(m.research_reason("rice_1").contains("晒稻入仓"), "rice starts with both seeding and storage")
	s.tech.append("dry")
	expect(m.research_reason("rice_1") == "", "both rice prerequisites unlock ear selection")
	expect(m.research_reason("seed_selection").contains("任选"), "public seed selection needs a crop technique")
	for crop in C.NAMES:
		s.tech = ["seed", "dry", R.id(crop, 0)]
		expect(m.research_reason("seed_selection") == "", "seed selection accepts any crop path " + crop)
	s.era = 1
	s.tech = ["seed", "dry", "rice_1", "dike"]
	m.assign("t39", -1)
	expect(m.research_reason("rice_2").contains("农户到岗"), "transplanting needs active farm labour")
	m.assign("t39", 1)
	for w in s.workers: w.travel = 0
	expect(m.research_reason("rice_2") == "", "connected staffed farmland satisfies the practical requirement")
	s.era = 2
	s.rain = true
	s.full = 2
	s.cells[34].level = 2
	s.cells[39].terrace = true
	s.cells[39].rotation = false
	s.tech = ["seed", "dry"]
	expect(m.advance_reason() != "", "an unauthorised field tag cannot satisfy a route")
	s.tech.append("rotate")
	expect(m.advance_reason() != "", "the built terrace and rotation research must belong to the same route")
	s.cells[39].rotation = true
	expect(m.advance_reason() == "", "rotation route does not need terrace research")
	s.tech = ["seed", "dry", "terrace"]
	s.cells[39].rotation = false
	expect(m.advance_reason() == "", "terrace route does not need rotation research")
	s.era = 3
	for option in R.LAND_OPTIONS:
		s.tech = [option]
		expect(m.research_reason("precise") == "" and m.build_reason("agcollege", 38) == "", "both modern unlocks accept " + option)
	s.tech.clear()
	expect(m.research_reason("precise").contains("任选") and m.build_reason("agcollege", 38) != "", "either qualifying technology is required")

func specialization_and_project(folder: String):
	var m = campus()
	var s = m.s
	s.era = 0
	expect(m.change_focus("经济") != "" and s.research_record.focus == "", "too early for specialization")
	s.era = 1
	expect(m.change_focus("经济") == "" and m.change_focus("耕作") != "", "one irreversible focus")
	expect(R.notes(s, "market_trade", m.techs.market_trade) == 3 and R.notes(s, "deep_plowing", m.techs.deep_plowing) == 7 and R.notes(s, "dike", m.techs.dike) == 3, "focused, outside, and public prices")
	s.tech = ["dry"];s.science = 3
	expect(m.research("market_trade") == "" and s.science == 0, "displayed discount is used for payment")
	for i in 25: m.work()
	var opening = s.food
	m.E.trade(s, "wood", true);m.E.trade(s, "wood", false)
	expect(s.food == opening - 1, "discount and market premium keep a buy/sell spread")
	expect(m.E.trade(s, "feed", false) != "", "feed market locked before research")
	s.tech.append("cash_crops");s.frontier.feed = 4
	expect(m.E.trade(s, "feed", false) == "" and s.frontier.feed == 0 and s.food == opening + 1, "fodder sold and booked")
	m = campus();s = m.s
	s.tech = ["tractor", "winnow"];s.science = 15
	expect(m.research("combine") == "", "start two-season research project")
	for i in 8: m.work()
	m.finish_season()
	expect(s.research_record.terms == 1, "first observed season accepted")
	var files = Saves.new();files.use_version_folder(folder)
	expect(files.put("campaign", s), "save research mid-trial")
	var other = M.new();other.restore(files.read("campaign"))
	expect(other.s.study == "combine" and other.s.study_time == s.study_time and other.s.research_record.terms == 1, "research progress loaded")
	other.assign("t39", -1)
	for i in 50: other.work()
	other.finish_season()
	expect(other.s.study == "combine" and other.s.research_record.terms == 1, "a vacant field cannot certify a season")
	other.assign("t39", 1)
	for w in other.s.workers: w.travel = 0
	for i in 7: other.work()
	expect(other.s.research_record.observations == 7, "counts seconds of simultaneous attendance")
	other.finish_season()
	expect(other.s.research_record.terms == 1 and other.s.research_record.observations == 0, "partial season does not roll into the next")
	for i in 8: other.work()
	other.finish_season()
	expect(other.s.study == "" and "combine" in other.s.tech, "returning farmer finishes the trial")
	var balance = [s.food, s.seed, s.science]
	expect(m.cancel_trial("variable_rate") != "" and m.cancel_trial("combine") == "" and m.cancel_trial("combine") != "", "only active trial may be withdrawn once")
	expect(s.study == "" and s.research_record.terms == 0 and [s.food, s.seed, s.science] == balance, "withdrawal clears progress without refund")
	var fresh = Saves.new();fresh.folder = folder
	var old = m.s.duplicate(true);old.version = 6;old.erase("research_record")
	old.study = "precise";old.study_time = 11;old.weather.history = ["第4年 · 秋 · 旱灾 · 2 处受影响"]
	fresh.put("chapter", old);fresh.put("campaign", old)
	var alt = folder.path_join("legacy-test-%s" % Time.get_unix_time_from_system()) + "/"
	DirAccess.make_dir_recursive_absolute(alt)
	var legacy = Saves.new();legacy.folder = alt
	legacy.put("chapter", old);legacy.put("campaign", old)
	var hash_before = FileAccess.get_sha256(alt + "campaign.bin")
	var previous = Saves.new();previous.folder = alt.path_join("v1.15") + "/"
	DirAccess.make_dir_recursive_absolute(previous.folder)
	var v115 = s.duplicate(true);v115.version = 7
	v115.birth_progress = 0
	for w in v115.workers: w.erase("farmer")
	v115.frontier.erase("envoy_rng")
	previous.put("campaign", v115)
	var v116_files = Saves.new();v116_files.folder = alt.path_join("v1.16") + "/"
	DirAccess.make_dir_recursive_absolute(v116_files.folder)
	var v116_state = s.duplicate(true)
	v116_state.study = "combine";v116_state.study_time = 11
	v116_state.research_record.terms = 1
	v116_files.put("campaign", v116_state)
	var old_hash = FileAccess.get_sha256(v116_files.folder + "campaign.bin")
	var v117 = Saves.new();v117.use_version_folder(alt)
	m.restore(v117.read("campaign"))
	expect(m.s.study == "combine" and m.s.study_time == 11 and m.s.research_record.terms == 1, "V1.17 preserves the V1.16 project and evidence")
	expect(v117.folder != v116_files.folder and FileAccess.get_sha256(v116_files.folder + "campaign.bin") == old_hash, "V1.16 save is read from its original folder")
	DirAccess.remove_absolute(v116_files.folder + "campaign.bin")
	expect(v117.read("campaign").version == 7, "V1.17 prefers the latest previous campaign")
	m.restore(v117.read("campaign"))
	expect(m.s.version == 8 and m.farmer_count() == m.s.pop and m.assigned("t39") == 1, "V1.15 farm staffing is preserved during migration")
	DirAccess.remove_absolute(previous.folder + "campaign.bin")
	m.restore(v117.read("campaign"))
	expect(m.s.version == 8 and m.s.research_record.focus == "" and m.s.study_time == 11 and m.s.science == old.science, "V1.10 campaign imports without charging active study")
	expect("旱灾" in m.s.research_record.hazards, "old hazard history restored")
	expect(v117.put("campaign", m.s) and FileAccess.get_sha256(alt + "campaign.bin") == hash_before and legacy.read("campaign").version == 6, "new save leaves V1.10 original byte-identical")
	expect(v117.read("campaign").version == 8, "continue prefers local V1.17 save")

func forecasts_and_hazards():
	var m = campus(4)
	var s = m.s
	var saw_disaster = false
	var saw_change = false
	var summer_hits = 0
	for region in C.REGIONS.size():
		m = campus(region)
		s = m.s
		for turn in range(1, 41):
			s.turn = turn
			s.incidents.clear()
			var previous = s.weather.now
			m.Weather.next_season(m)
			expect(s.weather.now in m.Weather.POOLS[region][turn % 4] and not s.weather.has("next"), "weather uses the current region and season only")
			if s.weather.threat != "":
				saw_disaster = true
				expect(m.Weather.THREATS[s.weather.now] == s.weather.threat and s.incidents.front().kind == "weather", "disaster announces at season start")
				s.weather.last_hit = turn
			elif s.weather.now != previous and m.Weather.THREATS.has(s.weather.now):
				saw_change = true
				expect(s.incidents.front().kind == "climate", "unusual weather changes announce at season start")
		expect(s.weather.rng > 0, "weather generator retains a valid state")
	expect(saw_disaster and saw_change, "test seasons exercise both outcomes")
	for sequence in range(1, 30):
		m = campus()
		s = m.s
		s.era = 1
		s.turn = 0
		s.food = 2
		s.weather.rng = sequence
		m.finish_season()
		expect(s.incidents.front().kind == "food" and s.incidents.front().description.contains("缺少 8 份"), "shortage event reports actual rations")
		summer_hits += int(s.pending == "flood")
	expect(summer_hits > 0 and summer_hits < 29, "summer flood is possible but not guaranteed")
	m = campus(4)
	s = m.s
	s.tech = ["phenology", "weather_station"]
	s.weather.threat = "旱灾";s.weather.prepared = false
	s.tech.append_array(["met_network", "water_management"])
	m.change_focus("防灾");s.wood = 0
	var land = s.cells[39].soil; var food = s.food
	expect(m.Weather.prepare(m) == "" and s.food == food - 2 and s.wood == 0, "weather network mobilizes with no wood")
	expect(m.Weather.prepare(m) != "", "no double mobilization")
	m.Weather.settle(m)
	expect(s.cells[39].soil == land and "旱灾" in s.research_record.hazards, "disaster focus and waterworks prevent prepared drought loss")
	s.frontier.wells = 2
	var intake = m.F.Farm.spring_water(s)
	s.tech.append_array(["coastal_cistern", "precision_irrigation"])
	s.cells[37].kind = "farm"
	var water = m.F.Farm.spring_water(s)
	expect(water.rain == intake.rain + 6 and water.need == intake.need, "two cisterns and two efficient plots change regional water account")

func advances_in_the_field():
	var m = campus(); var s = m.s; var c = s.cells[39]
	s.frontier.plots[39] = "稻";s.frontier.cultivars[39] = "耐逆系"
	s.frontier.varieties["稻"]["耐逆系"] = C.line(0, 1)
	c.care = 45;c.soil = 70
	var baseline = C.field_bonus(s, 39)
	s.tech = ["deep_plowing", "intensive_planting", "slash_burn", "regional_trials", "drought_breeding"]
	s.weather.now = "暑热"
	expect(C.field_bonus(s, 39) == baseline + 2 + 3 + 3 + 3 + 3, "opening a fertile dense field and growing a named hardy variety")
	s.tech = ["crossbreeding", "pedigree", "seed_bank"]
	expect(C.trial_time(s, "稻") == 30 and C.trial_time(s, "麦") == 40, "crossing and domesticating have different clocks")
	s.tech.append("foreign_introduction");C.add_sample(s.frontier, "麦", 0, 2)
	C.start_trial(s, "麦", 0)
	expect(s.frontier.trials["麦"].due == s.time + 32 and s.frontier.trials["麦"].line.vigor == 1, "introduction and pedigree affect actual new trial")
	for difficulty in 3:
		s.difficulty = difficulty
		var odds = C.mutation_odds(s)
		expect(odds == [C.MUTATION[difficulty][0], maxi(0, C.MUTATION[difficulty][1] - 8)], "seed bank reduces only the unfavorable band")
	s.tech = ["seed_selection"]
	expect(m.seed_saved(39, 12, 6) == C.seed_cost(s, "稻", "耐逆系") + 1 and m.seed_saved(39, 12, 1) == 1, "seed selection transfers a bounded extra grain")
	s.tech = []; var seed_cap = m.Town.seed_space(s, 0); var store_cap = m.Town.storage(s)
	s.tech = ["seed_vault", "granary_vent"]
	expect(m.Town.seed_space(s, 0) == seed_cap + 6 and m.Town.storage(s) == store_cap + 8, "local store receives exact extra bins")
	c.crop = true;c.sown_variety = "原种";c.sown_line = C.line()
	s.cells[37].kind = "farm";s.cells[37].crop = true;s.cells[37].connected = true
	s.frontier.plots[37] = "麦"
	s.tech = ["crop_diversity", "basic_protection", "pest_control", "intensive_planting"]
	c.rotation = true;c.birds = 12;c.weeds = 12;c.disease = 25
	m.seasonal_pressure()
	expect(c.birds == 7 and c.weeds == 0 and c.disease == 10, "diversity, density and protection settle on real field pressure")
	s.tech = ["field_trials", "apprentice", "slash_burn", "straw_return"]
	s.science = 0; var soil = c.soil
	m.change_focus("育种")
	m.harvest()
	expect(s.cells[38].notes == 1 and s.science == 0 and s.frontier.samples["稻"][0] == 2, "field records await collection and breeding focus saves a sample")
	expect(c.soil == soil + C.SOIL["稻"] - 5 + 3 and m.Town.lesson_time(s) == 15, "first-harvest land cost, straw return and apprenticeship")
	c.precise = true;c.fertilized = true;c.ditch = true;c.pollution = 35
	s.tech = ["variable_rate", "slow_release", "buffer_wetland"];m.water_step()
	expect(c.pollution == 25, "variable dosing and wetland applied to plot without negative runoff")
	s.tech = ["market_trade", "trade_routes", "harvest_network", "long_distance_trade"]
	m.E.open_district(s, 1)
	m.Roads.inherit_path(s, 38, m.F.anchor(s, 0));m.Roads.inherit_path(s, 38, m.F.anchor(s, 1));m.Roads.rebuild(s)
	var lane = m.F.route(s, 0, 1)
	expect(lane.road and lane.capacity == 14 and lane.time == ceili(m.F.travel_time(lane.path, true) * 0.75), "modern logistics changes capacity and travel time")
	s.cells[47].kind = "station";s.cells[47].connected = true;m.assign("t47", 1)
	for w in s.workers: w.travel = 0
	var prior = m.E.budget(s).total
	s.tech.append_array(["cooperative", "machine_pool"])
	expect(m.E.budget(s).total == prior - 3, "working store and staffed machinery reduce operations")

func run():
	var folder = OS.get_cache_dir().path_join("baigu-curriculum-check") + "/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-output="): folder = arg.trim_prefix("--test-output=").path_join("fixtures") + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	catalog()
	nonlinear_routes()
	optional_research()
	specialization_and_project(folder)
	forecasts_and_hazards()
	advances_in_the_field()
	if errors == 0: print("PASS ", checks, " curriculum checks, 79 topics, 6 regions, costs, projects, save isolation, economics and weather")
	quit(1 if errors else 0)

func _initialize(): call_deferred("run")
