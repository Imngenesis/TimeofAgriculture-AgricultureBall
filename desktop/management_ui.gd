extends RefCounted

const U=preload("res://paper.gd")
const V=preload("res://valley.gd")
const E=preload("res://economy.gd")
const T=preload("res://settlement.gd")

static func recruit_button(h,v):
	var why=h.sim.recruit_reason()
	var b=h.btn("招募 1 人 · %d 粮 / %d 木" % [E.HIRE_FOOD,E.HIRE_WOOD],"recruit",null,why=="")
	b.disabled=why!=""
	b.tooltip_text=why if why!="" else "入住后可派工，每季多消耗 1 份口粮"
	v.add_child(b)
	if why!="": v.add_child(U.label(why,13,U.DIM,true))

static func workforce(h,v):
	var m=h.sim
	var s=m.s
	var walking=0
	for w in s.workers:
		if w.job!="" and w.travel>0: walking+=1
	var row=U.box(false,6);v.add_child(row)
	U.metric(row,"人口 / 床位","%d / %d" % [s.pop,T.beds(s)])
	U.metric(row,"空闲",str(m.free_workers()),U.GREEN)
	U.metric(row,"在岗",str(s.pop-m.free_workers()-walking))
	U.metric(row,"赴任",str(walking))
	v.add_child(U.label("幸福 %d　组织 %d　上季人口 %+d　每季口粮 %d" % [s.happiness,s.organization,s.pop_change,s.pop],14,U.DIM))
	recruit_button(h,v)
	var vacancies=m.vacancies()
	var fill=h.btn("向 %d 个缺工岗位补派人手" % vacancies.size(),"fill")
	fill.tooltip_text="优先抢险与田间农时，仅调用空闲居民。"
	fill.disabled=vacancies.is_empty() or m.free_workers()==0
	v.add_child(fill)
	var seed_row=U.box(false,6);v.add_child(seed_row)
	seed_row.add_child(h.btn("封存 2 份种粮","reserve",false));seed_row.add_child(h.btn("取 2 份作口粮","reserve",true))
	v.add_child(U.rule())
	for job in vacancies+_other_jobs(m.jobs(),vacancies):
		var id=m.job_tile(job)
		var occupied=m.assigned(job)
		var line=U.box(false,5);v.add_child(line)
		var location=V.address(id)+"　"+m.job_label(job)
		var jump=h.btn(location,"edge" if job.begins_with("e") else "jump",job.substr(1) if job.begins_with("e") else id)
		jump.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(jump)
		var status="缺工" if vacancies.has(job) else ("赴任" if occupied>m.assigned(job,true) else "已派")
		line.add_child(U.label("%s %d/%d" % [status,occupied,m.capacity(job)],14,U.WARN if vacancies.has(job) else U.DIM))
		var minus=h.btn("−","assign",[job,-1]);minus.disabled=occupied==0;line.add_child(minus)
		var plus=h.btn("＋","assign",[job,1]);plus.disabled=m.free_workers()==0 or occupied>=m.capacity(job);line.add_child(plus)
		var shift=h.btn("调入","transfer_to",job);shift.disabled=occupied>=m.capacity(job);line.add_child(shift)
	for id in s.cells.size():
		if s.cells[id].kind in ["house","store"] and s.cells[id].project=="":
			v.add_child(h.btn(V.address(id)+"　"+m.location_name(id),"jump",id))

static func _other_jobs(all: Array,missing: Array) -> Array:
	return all.filter(func(job): return not missing.has(job))

static func transfers(h,v):
	var m=h.sim
	v.add_child(U.label("调往 "+V.address(m.job_tile(h.game.transfer_target))+"　"+m.job_label(h.game.transfer_target),17,U.GOLD))
	v.add_child(U.label("选择从哪处调出一人",14,U.DIM))
	for job in [""]+m.jobs():
		if job==h.game.transfer_target or m.assigned(job)==0: continue
		var source="营地待命" if job=="" else V.address(m.job_tile(job))+"　"+m.job_label(job)
		v.add_child(h.btn("%s　·　可调 %d 人" % [source,m.assigned(job)],"transfer_from",job))
	v.add_child(h.btn("返回人力总览","panel","crew"))

static func balance(h,v):
	var m=h.sim
	var s=m.s
	var row=U.box(false,6);v.add_child(row)
	U.metric(row,"口粮 / 仓容","%d / %d" % [s.food,T.storage(s)])
	U.metric(row,"种粮",str(s.seed),U.GREEN)
	U.metric(row,"木料",str(s.wood))
	U.metric(row,"石料",str(s.stone))
	var tabs=U.box(false,5);v.add_child(tabs)
	for item in [["budget","本季预算"],["market","料场与换货"],["history","历季账簿"]]:
		var tab=h.btn(item[1],"economy_tab",item[0],h.economy_tab==item[0])
		tab.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tabs.add_child(tab)
	match h.economy_tab:
		"budget": budget(h,v)
		"market": market(h,v)
		"history": history(h,v)

static func budget(h,v):
	var m=h.sim
	var s=m.s
	var costs=E.budget(s)
	var crop=0
	if s.turn%4==2:
		for id in m.farms():
			if s.cells[id].crop: crop+=maxi(0,m.expected_yield(id)-2)
	var net=s.food+crop-s.pop-costs.total
	var balance_text="预计缺口 %d 粮" % -net if net<0 else "预计季末口粮 %d" % mini(net,T.storage(s))
	v.add_child(U.label("%s　·　居民需 %d / 公共支出 %d" % [balance_text,s.pop,costs.total],17,U.WARN if net<0 else U.GREEN,true))
	v.add_child(U.label("计入在田秋粮 %d 份，预计溢仓 %d 份。后续采集、交易和建设会改变结余。" % [crop,maxi(0,net-T.storage(s))],13,U.DIM,true))
	v.add_child(U.rule())
	v.add_child(U.label("公共预算　·　本季农务效率 %d%%" % s.efficiency,17,U.GOLD))
	v.add_child(U.label("时代事务 %d　设施运转 %d　外圩地租 %d　·　%s难度" % [costs.era,costs.services,costs.land,E.DIFFICULTIES[s.difficulty].name],14,U.TEXT))
	var budgets=U.box(false,5);v.add_child(budgets)
	for i in E.BUDGETS.size():
		var b=h.btn("%s · %d 粮/季" % [E.BUDGETS[i],E.budget(s,-1,i).total],"budget",i,s.budget==i)
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;budgets.add_child(b)
	v.add_child(U.label("季末先发口粮，再拨付预算。足额拨付后下季效率 %d%%，欠拨会降低效率和组织度。" % E.FUND_YIELD[s.budget],13,U.DIM,true))
	if s.era<3:
		v.add_child(U.rule());v.add_child(U.label(h.era_forecast(),14,U.GOLD,true))

static func market(h,v):
	var s=h.sim.s
	v.add_child(U.label("码头换货",17,U.GOLD))
	for k in ["wood","stone"]:
		var amount=E.LOT[k]
		var name="木" if k=="wood" else "石"
		var trades=U.box(false,6);v.add_child(trades)
		var buy=h.btn("5 粮换 %d %s" % [amount,name],"trade",[k,true]);buy.disabled=s.food<5
		var sell=h.btn("%d %s换 2 粮" % [amount,name],"trade",[k,false]);sell.disabled=s[k]<amount
		for b in [buy,sell]: b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;trades.add_child(b)
	v.add_child(U.rule())
	v.add_child(U.label("料场生产",17,U.GOLD))
	for id in E.DEPOSITS:
		var kind=s.cells[id].kind
		if not E.DEPOTS.has(kind): continue
		var details="每份 %d 人秒　·　到岗 %d 人" % [E.extraction_time(kind,id),h.sim.assigned("t"+str(id),true)]
		if not s.districts.has(V.sector(id)): details="待开通圩区"
		v.add_child(h.btn("%s　%s　·　%s" % [V.address(id),E.DEPOTS[kind],details],"jump",id))

static func history(h,v):
	var s=h.sim.s
	if s.last_ledger.is_empty():
		v.add_child(U.label("第一季结束后将登记粮种和材料收支。",15,U.DIM));return
	v.add_child(U.label("近八季粮种收支　　绿柱 收入　/　金柱 支出",15,U.TEXT))
	var chart=preload("res://harvest_chart.gd").new()
	chart.entries=s.history
	chart.custom_minimum_size.y=98
	chart.mouse_filter=Control.MOUSE_FILTER_IGNORE;v.add_child(chart)
	var b=s.last_ledger
	v.add_child(U.rule())
	v.add_child(U.label("上季结算",17,U.GOLD))
	v.add_child(U.label("野粮 +%d　秋收 +%d　售料 +%d　撤工 +%d\n发粮 −%d　公共拨付 −%d / 应付 %d　买料 −%d\n招募 −%d　拓地 −%d　工程农事 −%d　检修防御 −%d　晋阶 −%d\n播种 −%d　灾损 −%d　溢仓 −%d\n木料 +%d / −%d　石料 +%d / −%d" % [b.gather,b.crop,b.exports,b.refund,b.eat,b.operations,b.due,b.imports,b.recruit,b.land,b.build,b.maintenance,b.advance,b.sow,b.loss,b.spoil,b.wood_in,b.wood_out,b.stone_in,b.stone_out],14,U.TEXT,true))
