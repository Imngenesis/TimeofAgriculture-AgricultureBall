extends RefCounted

const MAX_GRANT = 1000000
const MAX_POPULATION = 1000
const COMMANDS = {"帮助": "help", "口粮": "food", "人口": "pop", "农户": "farmers", 
	"札记": "notes", "科技": "tech", "建成": "build", "事件": "event", "发现": "discover"}
const WEATHER_EVENTS = {"drought": "暑热", "storm": "暴雨", "wind": "风", "frost": "冷霜"}
const CRISIS_NAMES = {"夏汛": "flood", "洪水": "flood", "梅雨": "rain", "尾水": "runoff", 
	"病害": "blight", "鸟害": "birds", "草害": "weeds"}
const HELP = "food 100     补给 100 份口粮\r\npop 5        增加 5 名居民\r\nfarmers 3    增加 3 名农户，优先编入现有居民\r\nnotes 10     增加 10 点已领札记\r\ntech seed    按课题名或 ID 完成科技。省略名称时完成在研课题\r\nbuild        完成选中的在建工程。可用 build E5 或 build all\r\nevent drought  触发旱灾。输入 event 查看事件名称\r\ndiscover 小麦  取得作物原种并解锁农学分支\r\n指令也接受对应的中文名称。例如 口粮 100、科技 seed。"









static func reply(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}

static func execute(m, line: String, cell: int = -1, edge: String = "") -> Dictionary:
	var words = line.strip_edges().trim_prefix("/").replace("\t", " ").replace("　", " ").split(" ", false)
	if words.is_empty(): return reply(false, "请输入指令。输入 help 查看用法。")
	var command = words[0].to_lower()
	command = COMMANDS.get(command, command)
	var argument = " ".join(words.slice(1))
	match command:
		"help": return reply(true, HELP)
		"food", "pop", "farmers", "notes": return grant(m, command, argument)
		"tech": return technology(m, argument)
		"build": return projects(m, argument, cell, edge)
		"event": return incident(m, argument, cell)
		"discover": return discover(m, argument)
	return reply(false, "未知指令「%s」。输入 help 查看用法。" % words[0])

static func grant(m, command: String, argument: String) -> Dictionary:
	if not argument.is_valid_int(): return reply(false, "请填写正整数，例如 %s 5。" % command)
	var quantity = int(argument)
	if quantity <= 0 or quantity > MAX_GRANT: return reply(false, "输入范围为 1 到 %d。" % MAX_GRANT)
	var s = m.s
	var message = ""
	match command:
		"food":
			m.E.book_stock(s, 0, "food", quantity, "debug_supply")
			message = "已补给 %d 份口粮，现有 %d 份。" % [quantity, s.food]
		"notes":
			s.science += quantity
			message = "已增加 %d 点札记，现有 %d 点。" % [quantity, s.science]
		"pop", "farmers":
			var enroll = mini(quantity, s.pop - m.farmer_count()) if command == "farmers" else 0
			var new_people = quantity - enroll
			if s.pop + new_people > MAX_POPULATION:
				return reply(false, "营地调试人口上限为 %d。" % MAX_POPULATION)
			if enroll > 0:
				var pending = enroll
				for idle in [true, false]:
					for person in s.workers:
						if pending == 0: break
						if person.farmer or (person.job == "") != idle: continue
						person.farmer = true
						pending -= 1
			for i in new_people: m.add_worker(command == "farmers")
			s.pop = s.workers.size()
			message = "现有 %d 名居民，%d 名农户。" % [s.pop, m.farmer_count()]
			message = ("已增加 %d 名农户。" if command == "farmers" else "已增加 %d 名居民。") % quantity + message
	s.rev += 1
	m.note("调试 · " + message)
	return reply(true, message)

static func technology(m, argument: String) -> Dictionary:
	var key = m.s.study if argument == "" else argument.to_lower()
	if key not in m.techs and argument != "":
		for id in m.techs:
			if m.tech_name(id) == argument:
				key = id
				break
	if key not in m.techs:
		return reply(false, "请填写课题名或 ID，例如 tech seed。" if argument != "" else "当前没有在研课题。")
	if key in m.s.tech: return reply(true, "已掌握「%s」。" % m.tech_name(key))
	var crop = m.Study.subject(key)
	if crop != "" and not m.Study.discovered(m.s, crop): m.F.unlock_crop(m.s, crop)
	m.finish_research(key)
	return reply(true, "已完成科技「%s」。" % m.tech_name(key))

static func locate_cell(m, address: String) -> int:
	if address.is_valid_int():
		var id = int(address)
		return id if id >= 0 and id < m.s.cells.size() else -1
	for id in m.s.cells.size():
		var label = m.V.address(id)
		if label == address or label.get_slice(" · ", 1) == address.to_upper(): return id
	return -1

static func projects(m, argument: String, cell: int, edge: String) -> Dictionary:
	if argument.to_lower() == "all" or argument == "全部":
		var count = 0
		for id in m.s.cells.size():
			count += int(m.finish_project("t" + str(id)))
		for key in m.s.edges:
			count += int(m.finish_project("e" + key))
		return reply(count > 0, "已完成 %d 项工程。" % count if count > 0 else "当前没有在建工程。")
	var id = cell if argument == "" else locate_cell(m, argument)
	var job = edge if argument == "" and edge != "" else "t" + str(id) if id >= 0 else ""
	if job == "": return reply(false, "请选中在建工程，或填写地块编号，例如 build E5。")
	if not m.finish_project(job): return reply(false, "指定位置没有在建工程。")
	return reply(true, "已完成%s的工程。" % m.V.address(m.job_tile(job)))

static func incident(m, argument: String, cell: int) -> Dictionary:
	var s = m.s
	if argument == "":
		return reply(true, "灾害 · drought 旱灾 / storm 暴雨冲刷 / wind 风灾 / frost 霜冻\n农情 · flood 夏汛 / rain 梅雨 / runoff 尾水 / blight 病害 / birds 鸟害 / weeds 草害\n农事议决 · E01 芦滩火耕 / E02 无芒早稻 / E03 河湾浮藻\n用 event 晴 等当前天气名模拟气候变化，或用 event shortage 演练缺粮弹窗。")
	var key = argument.to_lower()
	if key.to_upper() in m.FieldEvents.IDS:
		var why = m.FieldEvents.offer(m,key.to_upper())
		return reply(why == "", "已发起农事议决演练。" if why == "" else why)
	if key in ["shortage", "缺粮", "口粮不足"]:
		m.queue_incident("当季口粮供应不足", "本次为调试演练。请确认这一条缺粮事件。", "food")
		return reply(true, "已触发缺粮事件演练。")
	var weather = WEATHER_EVENTS.get(key, m.Weather.THREATS.find_key(argument))
	if weather != null:
		m.Weather.announce_disaster(m, weather)
		return reply(true, "已触发%s。" % m.Weather.THREATS[weather])
	if argument in m.Weather.FORECAST:
		s.weather.now = argument
		s.weather.threat = ""
		s.weather.prepared = false
		m.queue_incident("气候变化 · " + argument, m.Weather.FORECAST[argument], "climate")
		return reply(true, "已设置本季天气为%s。" % argument)
	key = CRISIS_NAMES.get(argument, key)
	if key not in m.CRISIS: return reply(false, "未知事件。输入 event 查看事件列表。")
	var pending = s.get("forced_disasters", [])
	if s.pending == key or key in s.warnings or key in pending:
		return reply(false, "该事件已经安排。")
	if key == "flood" and s.flood_time > 0: return reply(false, "洪水仍在过境。")
	if key in ["flood", "rain"]:
		pending.append(key)
		s.forced_disasters = pending
		if key == "flood":
			s.flood_at = -1
			s.resown = false
		else: s.rain = false
	var target = cell if cell >= 0 and cell < s.cells.size() else s.frontier.home
	if key == "blight" and s.cells[target].kind != "farm":
		var farms = m.farms()
		target = farms[0] if not farms.is_empty() else s.frontier.home
	m.queue_warning(key, target, "控制台触发的农情事件", true)
	m.next_warning()
	return reply(true, "已触发「%s」。" % m.CRISIS[key][0])

static func discover(m, argument: String) -> Dictionary:
	var crops = m.F.Crops
	for crop in crops.NAMES:
		if argument not in [crop, crops.title(crop), crops.CODES[crop]]: continue
		if not m.F.unlock_crop(m.s, crop):
			return reply(true, "已取得%s原种。" % crops.title(crop))
		m.s.rev += 1
		m.note("调试发现 · " + crops.title(crop))
		return reply(true, "已发现%s，可以安排种植。" % crops.title(crop))
	return reply(false, "可发现的作物 · " + "、".join(crops.TITLES))
