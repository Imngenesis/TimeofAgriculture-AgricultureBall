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
	s.food = 75; s.seed = 12; s.wood = 32; s.stone = 22
	s.cells[38].kind = "academy"
	s.cells[39].kind = "farm"
	s.cells[34].kind = "store"
	m.Roads.inherit_path(s, 38, 39)
	m.Roads.inherit_path(s, 38, 34)
	m.Roads.rebuild(s)
	m.assign("t38", 1); m.assign("t39", 1)
	for w in s.workers: w.travel = 0
	return m

func catalog():
	var m = campus()
	var done = []
	for pass_index in m.techs.size():
		for id in m.techs:
			if id in done: continue
			var eligible = true
			for pre in CUR.parents(id,m.techs[id]):
				if not pre in done: eligible = false; break
			if eligible: done.append(id)
	expect(done.size() == m.techs.size(), "no missing dependencies or cycles")
	expect(m.techs.size() == 73 and CUR.TOPICS.data.size() == 41 and CUR.ROUTES.data.topics.size() == 27, "canonical catalog and branching count")
	var count = [0,0,0,0]
	var regions = []
	for key in CUR.TOPICS.data:
		var row = CUR.TOPICS.data[key]
		var era = int(row.era)
		count[era] += 1
		for pre in CUR.parents(key,m.techs[key]): expect(m.techs.has(pre) and m.techs[pre][1] <= era, "no future prerequisite for " + key)
		var place = int(row.get("region", 0))
		if row.has("region"): regions.append(place)
		m = campus(place)
		var s = m.s
		s.era = era
		s.tech = row.requires.duplicate()
		if not CUR.paths(key).is_empty(): s.tech.append_array(CUR.paths(key)[0].tech)
		if row.has("event"):
			expect(m.research_reason(key).contains("旱灾"), "drought history gates only its trial")
			s.research_record.hazards.append(row.event)
		for track in CUR.TRACKS:
			s.research_record.focus = track
			expect(R.notes(s,key,m.techs[key]) <= R.limit(s, 1), "attainable note cap " + key + track)
		s.research_record.focus = ""
		s.science = int(row.notes)
		var stocks = [s.food,s.seed,s.wood,s.stone]
		var bill = R.bill(s,key,m.techs[key])
		expect(m.research(key) == "", "research accepts eligible " + key)
		expect(s.science == 0 and s.study == key, "single note debit " + key)
		expect(m.research(key) != "" and s.science == 0, "duplicate research rejected " + key)
		expect([s.food,s.seed,s.wood,s.stone] == [stocks[0]-bill[0],stocks[1]-bill[1],stocks[2]-bill[2],stocks[3]-bill[3]], "exact materials " + key)
		for i in R.timing(m.techs[key]): m.work()
		if CUR.terms(key) > 0:
			expect(key not in s.tech and s.study_time == 0, "labour alone cannot finish " + key)
			for term in CUR.terms(key):
				if term > 0:
					for i in CUR.OBSERVATIONS: m.work()
				m.finish_season()
		expect(key in s.tech and s.study == "", "earned topic " + key)
	expect(count == [6,9,13,13], "era distribution")
	regions.sort(); expect(regions == [0,1,2,3,4,5], "each starting region has a local technique")
	m = campus(4)
	m.s.tech = ["water_management"]; m.s.science = 10
	expect(m.research_reason("polder_drain").contains("长江湿地"), "regional curriculum enforced by model")
	expect(m.research("coastal_cistern") == "", "coastal option can be studied")

func specialization_and_project(folder: String):
	var m = campus()
	var s = m.s
	s.era = 0
	expect(m.change_focus("经济") != "" and s.research_record.focus == "", "too early for specialization")
	s.era = 1
	expect(m.change_focus("经济") == "" and m.change_focus("耕作") != "", "one irreversible focus")
	expect(R.notes(s,"market_trade",m.techs.market_trade) == 4 and R.notes(s,"deep_plowing",m.techs.deep_plowing) == 10 and R.notes(s,"dike",m.techs.dike) == 3, "focused, outside, and public prices")
	s.tech = ["dry"]; s.science = 4
	s.frontier.feed = 4
	expect(m.E.trade(s,"feed",false) != "", "feed market locked before studying the integrated market")
	expect(m.research("market_trade") == "" and s.science == 0, "displayed discount is used for payment")
	for i in 25: m.work()
	var opening = s.food
	m.E.trade(s,"wood",true); m.E.trade(s,"wood",false)
	expect(s.food == opening-1, "discount and market premium keep a buy/sell spread")
	s.frontier.feed = 4
	expect(m.E.trade(s,"feed",false) == "" and s.frontier.feed == 0 and s.food == opening+1, "fodder sold and booked")
	m = campus(); s = m.s
	s.tech = ["tractor","winnow"]; s.science = 15
	expect(m.research("combine") == "", "start two-season research project")
	for i in 8: m.work()
	m.finish_season()
	expect(s.research_record.terms == 1, "first observed season accepted")
	var files = Saves.new(); files.use_version_folder(folder)
	expect(files.put("campaign",s), "save research mid-trial")
	var other = M.new(); other.restore(files.read("campaign"))
	expect(other.s.study == "combine" and other.s.study_time == s.study_time and other.s.research_record.terms == 1, "research progress loaded")
	other.assign("t39",-1)
	for i in 50: other.work()
	other.finish_season()
	expect(other.s.study == "combine" and other.s.research_record.terms == 1, "a vacant field cannot certify a season")
	other.assign("t39",1)
	for w in other.s.workers: w.travel = 0
	for i in 7: other.work()
	expect(other.s.research_record.observations == 7, "counts seconds of simultaneous attendance")
	other.finish_season()
	expect(other.s.research_record.terms == 1 and other.s.research_record.observations == 0, "partial season does not roll into the next")
	for i in 8: other.work()
	other.finish_season()
	expect(other.s.study == "" and "combine" in other.s.tech, "returning farmer finishes the trial")
	var balance = [s.food,s.seed,s.science]
	expect(m.cancel_trial("variable_rate") != "" and m.cancel_trial("combine") == "" and m.cancel_trial("combine") != "", "only active trial may be withdrawn once")
	expect(s.study == "" and s.research_record.terms == 0 and [s.food,s.seed,s.science] == balance, "withdrawal clears progress without refund")
	var fresh = Saves.new(); fresh.folder = folder
	var old = m.s.duplicate(true);old.version = 6;old.erase("research_record")
	old.study = "precise";old.study_time = 11;old.weather.history = ["第4年 · 秋 · 旱灾 · 2 处受影响"]
	fresh.put("chapter",old);fresh.put("campaign",old)
	var alt = folder.path_join("legacy-test") + "/"
	DirAccess.make_dir_recursive_absolute(alt)
	var legacy = Saves.new();legacy.folder = alt
	legacy.put("chapter",old);legacy.put("campaign",old)
	var hash_before = FileAccess.get_sha256(alt + "campaign.bin")
	var v115 = Saves.new();v115.use_version_folder(alt)
	m.restore(v115.read("campaign"))
	expect(m.s.version == 8 and m.s.research_record.focus == "" and m.s.study_time == 11 and m.s.science == old.science, "V1.10 campaign imports without charging active study")
	expect("旱灾" in m.s.research_record.hazards, "old hazard history restored")
	expect(v115.put("campaign", m.s) and FileAccess.get_sha256(alt+"campaign.bin") == hash_before and legacy.read("campaign").version == 6, "new save leaves V1.10 original byte-identical")
	expect(v115.read("campaign").version == 8, "continue prefers local preview save")

func forecasts_and_hazards():
	var m = campus(4)
	var s = m.s
	s.tech = ["phenology"]
	expect(m.Weather.outlook(s).size() == 2, "phenology gives two seasons")
	s.tech.append("weather_station")
	var before = s.weather.duplicate(true)
	var forecast = m.Weather.outlook(s)
	expect(forecast.size() == 3 and s.weather == before and forecast == m.Weather.outlook(s), "forecast never changes weather RNG")
	for expected in forecast:
		s.turn += 1; m.Weather.next_season(s)
		expect(s.weather.now == expected, "published forecast verifies with actual weather")
	s.weather.threat = "旱灾";s.weather.prepared = false
	s.tech.append_array(["met_network","water_management"])
	m.change_focus("防灾");s.wood = 0
	var land = s.cells[39].soil;var food = s.food
	expect(m.Weather.prepare(m) == "" and s.food == food-2 and s.wood == 0, "weather network mobilizes with no wood")
	expect(m.Weather.prepare(m) != "", "no double mobilization")
	m.Weather.settle(m)
	expect(s.cells[39].soil == land and "旱灾" in s.research_record.hazards, "disaster focus and waterworks prevent prepared drought loss")
	s.frontier.wells = 2
	var intake = m.F.Farm.spring_water(s)
	s.tech.append_array(["coastal_cistern","precision_irrigation"])
	s.cells[37].kind = "farm"
	var water = m.F.Farm.spring_water(s)
	expect(water.rain == intake.rain + 6 and water.need == intake.need, "two cisterns and two efficient plots change regional water account")

func advances_in_the_field():
	var m = campus();var s = m.s;var c = s.cells[39]
	s.frontier.plots[39] = "稻";s.frontier.cultivars[39] = "耐逆系"
	s.frontier.varieties["稻"]["耐逆系"] = C.line(0,1)
	c.care = 45;c.soil = 70
	var baseline = C.field_bonus(s,39)
	s.tech = ["deep_plowing","intensive_planting","slash_burn","regional_trials","drought_breeding"]
	s.weather.now = "暑热"
	expect(C.field_bonus(s,39) == baseline + 2+3+3+3+3, "opening a fertile dense field and growing a named hardy variety")
	s.tech = ["crossbreeding","pedigree","seed_bank"]
	expect(C.trial_time(s,"稻") == 30 and C.trial_time(s,"麦") == 40, "crossing and domesticating have different clocks")
	s.tech.append("foreign_introduction");C.add_sample(s.frontier,"麦",0,2)
	C.start_trial(s,"麦",0)
	expect(s.frontier.trials["麦"].due == s.time+32 and s.frontier.trials["麦"].line.vigor == 1, "introduction and pedigree affect actual new trial")
	for difficulty in 3:
		s.difficulty = difficulty
		var odds = C.mutation_odds(s)
		expect(odds == [C.MUTATION[difficulty][0],maxi(0,C.MUTATION[difficulty][1]-8)], "seed bank reduces only the unfavorable band")
	s.tech = ["seed_selection"]
	expect(m.seed_saved(39,12,6) == C.seed_cost(s,"稻","耐逆系")+1 and m.seed_saved(39,12,1) == 1, "seed selection transfers a bounded extra grain")
	s.tech = [];var seed_cap = m.Town.seed_space(s,0);var store_cap = m.Town.storage(s)
	s.tech = ["seed_vault"]
	expect(m.Town.seed_space(s,0) == seed_cap+6 and m.Town.storage(s) == store_cap+8, "local store receives exact extra bins")
	c.crop = true;c.sown_variety = "原种"; c.sown_line = C.line()
	s.cells[37].kind = "farm";s.cells[37].crop = true;s.cells[37].connected = true
	s.frontier.plots[37] = "麦"
	s.tech = ["crop_diversity","basic_protection","pest_control","intensive_planting"]
	c.rotation = true;c.birds = 12;c.weeds = 12;c.disease = 25
	m.seasonal_pressure()
	expect(c.birds == 7 and c.weeds == 0 and c.disease == 10, "diversity, density and protection settle on real field pressure")
	s.tech = ["field_trials","slash_burn","straw_return"]
	s.science = 0;var soil = c.soil
	m.change_focus("育种")
	m.harvest()
	expect(s.cells[38].notes == 1 and s.science == 0 and s.frontier.samples["稻"][0] == 2, "field records await collection and breeding focus saves a sample")
	expect(c.soil == soil + C.SOIL["稻"] - 5 + 3 and m.Town.lesson_time(s) == 15, "first-harvest land cost, straw return and apprenticeship")
	c.precise = true;c.fertilized = true;c.ditch = true;c.pollution = 35
	s.tech = ["variable_rate","slow_release","buffer_wetland"];m.water_step()
	expect(c.pollution == 25, "variable dosing and wetland applied to plot without negative runoff")
	s.tech = ["market_trade","trade_routes","harvest_network"]
	m.E.open_district(s,1)
	m.Roads.inherit_path(s,38,m.F.anchor(s,0));m.Roads.inherit_path(s,38,m.F.anchor(s,1));m.Roads.rebuild(s)
	var lane = m.F.route(s,0,1)
	expect(lane.road and lane.capacity == 14 and lane.time == ceili(m.F.travel_time(lane.path,true)*0.75), "modern logistics changes capacity and travel time")
	s.cells[47].kind = "station";s.cells[47].connected = true;m.assign("t47",1)
	for w in s.workers: w.travel = 0
	var prior = m.E.budget(s).total
	s.tech.append_array(["cooperative","machine_pool"])
	expect(m.E.budget(s).total == prior-3, "working store and staffed machinery reduce operations")

func fieldwork_fixture(m):
	var s = m.s
	for pair in [[48,"farm"],[40,"canal"],[36,"pasture"]]:
		s.cells[pair[0]].kind = pair[1]
		m.Roads.inherit_path(s,38,pair[0])
	s.cells[39].harvests = 1; s.cells[48].harvests = 1
	s.frontier.yards[36] = m.F.Farm.Yards.herd()
	s.frontier.yards[36].hens = 1
	s.cells[34].level = 2
	m.E.open_district(s,1)
	m.Roads.inherit_path(s,38,m.F.anchor(s,0))
	m.Roads.inherit_path(s,38,m.F.anchor(s,1))
	m.Roads.rebuild(s)
	m.assign("t40",1); m.assign("t36",1)
	for w in s.workers: w.travel = 0
	for crop in C.NAMES: s.frontier.lines[crop] = C.line()
	C.profiles(s)

func alternative_routes():
	var h = campus()
	fieldwork_fixture(h)
	for field in CUR.FIELDWORK:
		expect(CUR.field_count(h,field) >= CUR.FIELDWORK[field][1], "real settlement can produce evidence " + field)
	for key in CUR.ROUTES.data.topics:
		var spec = h.techs[key]
		var choices = CUR.paths(key)
		expect(choices.size() >= 2, "genuine alternatives " + key)
		for path in choices:
			h.s.tech = spec[3].duplicate()
			h.s.science = 18
			expect(h.research_check(key)[0] == "待择径", "common prerequisites alone are insufficient for " + key)
			for id in path.tech:
				expect(h.techs.has(id) and h.techs[id][1] <= spec[1] and id not in spec[3], "valid optional edge " + key + "/" + id)
				h.s.tech.append(id)
			expect(h.research_reason(key) == "", "independent access via " + key + "/" + path.name)
			if not spec[3].is_empty():
				h.s.tech.erase(spec[3][0])
				expect(h.research_check(key)[0] == "缺前置", "optional branch does not skip common base " + key)
	var m = campus()
	var s = m.s
	s.tech = ["tractor","intensive_planting"]; s.science = 16
	var balance = [s.science,s.food,s.seed,s.wood,s.stone]
	expect(m.research("combine") != "" and [s.science,s.food,s.seed,s.wood,s.stone] == balance, "one field does not pay for or unlock combine")
	s.cells[39].harvests = 1
	s.cells[37].kind = "farm"; s.cells[37].harvests = 1
	m.Roads.inherit_path(s,38,37); m.Roads.rebuild(s)
	expect(m.research_check("combine")[0] == "待择径", "separated fields do not qualify as contiguous planting")
	s.cells[48].kind = "farm"; s.cells[48].harvests = 1
	for edge in s.streets.keys():
		if 48 in s.streets[edge]: s.streets.erase(edge)
	m.Roads.rebuild(s)
	expect(m.research_check("combine")[0] == "待择径", "a disconnected adjacent field does not count")
	m.Roads.inherit_path(s,38,48); m.Roads.rebuild(s)
	s.cells[48].harvests = 0
	expect(m.research_check("combine")[0] == "待择径", "empty adjacent land has no field evidence")
	s.cells[48].harvests = 1
	expect(m.research("combine") == "" and s.science == 5 and "winnow" not in s.tech, "field route paid once without granting the other branch")
	s.cells[48].connected = false
	for season in 2:
		for tick in 40: m.work()
		m.finish_season()
	expect(s.study == "" and "combine" in s.tech, "enrolment retains its accepted route when conditions change")
	m = campus(); s = m.s; s.tech = ["tractor","winnow"]; s.science = 16
	expect(m.research("combine") == "" and s.science == 5 and "intensive_planting" not in s.tech, "grain-yard route costs the same without a second field")
	for season in 2:
		for tick in 40: m.work()
		m.finish_season()
	expect(s.study == "" and "combine" in s.tech, "both independent routes complete the same technology")
	m = campus(); fieldwork_fixture(m); s = m.s
	for era in [1,2]:
		s.era = era
		for path in CUR.ROUTES.data.eras[era]:
			s.tech = path.tech.duplicate()
			expect(m.Town.requirements(m)["科技"][0][0], "era gate accepts " + path.name)
	s.era = 2; s.tech = ["rotate","seed_vault"]; s.cells[34].level = 1
	expect(not m.Town.requirements(m)["科技"][0][0], "a normal store cannot satisfy the storage era path")
	s.cells[34].level = 2
	expect(m.Town.requirements(m)["科技"][0][0] and m.advance_reason() != "", "era technology never bypasses survival and construction")

func integrated_saves(folder: String):
	var m = campus()
	var old = m.s.duplicate(true); old.version = 7
	old.tech = ["deep_plowing","large_field_management","apprentice","granary_vent","manure_cycle"]
	old.study = "long_distance_trade"; old.study_time = 9; old.research_record.focus = "经济"
	var previous = Saves.new()
	var root = folder.path_join("official-import") + "/"
	previous.folder = root.path_join("v1.15") + "/"
	DirAccess.make_dir_recursive_absolute(previous.folder)
	previous.put("chapter",old); previous.put("campaign",old)
	var original = FileAccess.get_sha256(previous.folder+"campaign.bin")
	var preview = Saves.new(); preview.use_version_folder(root)
	# First import reads the official campaign explicitly even if this test path was used before.
	var snapshot = previous.read("campaign")
	if not FileAccess.file_exists(preview.folder+"campaign.bin"): snapshot = preview.read("campaign")
	m.restore(snapshot)
	expect(m.s.version == 8 and m.s.tech == ["deep_plowing","field_trials","seed_vault","straw_return"], "old overlapping rewards merge once, preserving stable order")
	expect(m.s.study == "trade_routes" and m.s.study_time == 9 and m.s.science == old.science and m.s.research_record.focus == "经济", "paid pending old course retains work, price and specialty")
	for tick in 9: m.work()
	expect("trade_routes" in m.s.tech and m.s.study == "", "legacy paid course finishes normally")
	expect(preview.put("campaign",m.s) and FileAccess.get_sha256(previous.folder+"campaign.bin") == original and preview.read("campaign").version == 8, "preview writes to an independent slot")
	old.study = "large_field_management"; old.study_time = 5
	m.restore(old)
	expect(m.s.study == "" and m.s.study_time == 0 and m.s.tech.count("deep_plowing") == 1, "overlapping paid project closes when its combined topic was already earned")

func run():
	var folder = OS.get_cache_dir().path_join("baigu-curriculum-check") + "/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--test-output="): folder = arg.trim_prefix("--test-output=").path_join("fixtures") + "/"
	DirAccess.make_dir_recursive_absolute(folder)
	catalog()
	alternative_routes()
	integrated_saves(folder)
	specialization_and_project(folder)
	forecasts_and_hazards()
	advances_in_the_field()
	if errors == 0: print("PASS ",checks," curriculum checks, 73 topics, 27 branching topics, 6 regions, costs, projects, save isolation, economics and weather")
	quit(1 if errors else 0)

func _initialize(): call_deferred("run")
