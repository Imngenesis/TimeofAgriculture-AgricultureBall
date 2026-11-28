extends RefCounted

const STEPS = [
	["派两人采集野粮", "选择野粮采集地，在岗位人手旁点两次「＋」。每位居民每季需要一份口粮。", "定位采集地"], 
	["建成第一所农专", "在空地放置农专，工人会自动动工。农专是整条生产路网的起点。", "选址建农专"], 
	["修通第一条路", "从农专向营地铺路。移动鼠标查看路线与材料报价，左键落定，右键结束。", "从农专铺向营地"], 
	["领取两点农学札记", "在农专派一到两人。每 18 人秒编成一点，点领取后才可用于研究。", "定位农专"], 
	["研习本地留种法", "在农学科技树上查看本地作物的第一课，备齐科技点和口粮后开始研习。", "打开本地课题"], 
	["让一块农田通路", "建设试验农田。若田边有断路标记，点田内「接入农专」预览连接，再确认铺路。", "查看农田或选址"], 
	["在春夏播下第一茬", "到农田封存种粮并派人。每种作物、品系用种量不同，春夏有种有人就会播种。", "定位待播农田"], 
	["等到第一次秋收", "查看田块的预计口粮、下茬留种与饲料。留一人照料，秋季结束时收获入库。", "查看在田作物"]]

static func field(m) -> int:
	for id in m.farms():
		if m.s.cells[id].connected: return id
	var plots = m.farms()
	return -1 if plots.is_empty() else plots[0]

static func done(m, step: int) -> bool:
	var s = m.s
	match step:
		0: return m.assigned("t19") + m.assigned("t42") + m.assigned("t60") >= 2 or s.first_crop
		1: return m.Roads.root(s) >= 0
		2: return s.cells[s.frontier.home].connected
		3: return s.science >= 2 or "seed" in s.tech or s.study != ""
		4: return "seed" in s.tech
		5: return field(m) >= 0 and s.cells[field(m)].connected
		6:
			for id in m.farms():
				if s.cells[id].crop or s.cells[id].harvests > 0: return true
		7: return s.first_crop
	return false

static func update(m):
	if m.s.lesson_hidden: return
	while m.s.lesson_step < STEPS.size() and done(m, m.s.lesson_step):
		m.s.lesson_step += 1
		m.s.rev += 1
		if m.s.lesson_step == STEPS.size(): m.note("入门田课完成。现在可用余粮开拓外圩、驯化新作物。")
