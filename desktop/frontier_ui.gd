extends RefCounted

const F=preload("res://frontier.gd")
const C=preload("res://crop_book.gd")
const U=preload("res://paper.gd")
const V=preload("res://valley.gd")
const HABITATS=preload("res://art/atlas-habitats.png")
const PLANTS=preload("res://art/atlas-crops.png")
const SYMPTOM=["叶片和稻穗出现褐斑，部分穗粒难以充实。","部分谷穗失色，成熟时能收下的籽粒减少。","叶片出现斑点，部分麦穗提前枯黄。","薯叶出现暗斑，受影响田块的块茎产量下降。","叶片与豆荚出现斑点，能留作种子的豆粒减少。","叶片出现条状斑痕，结实的籽粒减少。"]

static func plate(sheet: Texture2D,index: int) -> AtlasTexture:
	var t=AtlasTexture.new()
	t.atlas=sheet
	var tile=sheet.get_size()/Vector2(3,2)
	t.region=Rect2(Vector2(index%3,floori(index/3.0))*tile+Vector2.ONE,tile-Vector2(2,2))
	t.filter_clip=true
	return t

static func picture(sheet: Texture2D,index: int,extent: Vector2) -> TextureRect:
	var thumb=TextureRect.new()
	thumb.texture=plate(sheet,index)
	thumb.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.custom_minimum_size=extent
	thumb.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return thumb

static func choice(h,v,title,cmd,arg,selected=false):
	var button=h.btn(title,cmd,arg,selected)
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	v.add_child(button)
	return button

static func action(h,v,title,cmd,arg=null):
	var button=choice(h,v,title,"frontier_action",[cmd,arg])
	var why=F.reason(h.sim,cmd,arg)
	button.disabled=why!=""
	button.tooltip_text=why
	return button

static func countdown(h,v,message: String,due: int,color: Color):
	var label=U.label(message % maxi(0,due-h.sim.s.time),14,color,true)
	label.set_meta("message",message)
	label.set_meta("due",due)
	v.add_child(label)
	h.countdowns.append(label)

static func habitats(h,body):
	body.add_child(h.title_label("选择起始地",27))
	var grid=GridContainer.new()
	grid.columns=3;grid.add_theme_constant_override("h_separation",6);grid.add_theme_constant_override("v_separation",6)
	body.add_child(grid)
	for i in F.REGIONS.size():
		var button=choice(h,grid,F.REGIONS[i],"region",i,h.game.start_region==i)
		button.icon=plate(HABITATS,i)
		button.add_theme_constant_override("icon_max_width",42)
		button.custom_minimum_size=Vector2(0,48)
	var selected=h.game.start_region
	var row=U.box(false,13);body.add_child(row)
	row.add_child(picture(HABITATS,selected,Vector2(165,96)))
	var details=U.box(true,4);details.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(details)
	details.add_child(U.label("%s　·　本地作物 %s" % [F.REGIONS[selected],C.title(C.START[selected])],18,U.GOLD))
	details.add_child(U.label(C.ECOLOGY[selected],15,U.TEXT,true))
	body.add_child(U.rule())
	body.add_child(U.label("选择年景，启程扎营",16,U.TEXT))
	var levels=U.box(false,8);body.add_child(levels)
	for i in h.E.DIFFICULTIES.size():
		var d=h.E.DIFFICULTIES[i]
		var col=U.box(true,3);col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;levels.add_child(col)
		choice(h,col,d.name+(" · 随机出生" if i==2 else ""),"difficulty",i,i==1)
		col.add_child(U.label("%d 粮 · 秋收 %d%%" % [d.food,d.yield_pct],13,U.DIM))
	body.add_child(U.label("荒年会从六种生态与四个营址中随机抽取。",13,U.GOLD))
	body.add_child(h.btn("返回主菜单","back"))

static func tabs(h,v):
	var group=U.box(false,5);v.add_child(group)
	for tab in ["种圃","探险","牧场","运输"]:
		choice(h,group,tab,"frontier_tab",tab,h.frontier_tab==tab)

static func draw(h,v):
	match h.frontier_tab:
		"种圃": crops(h,v)
		"探险": survey(h,v)
		"牧场": livestock(h,v)
		"运输": freight(h,v)
	v.add_child(U.rule())
	v.add_child(U.label(h.sim.s.frontier.last,13,U.GOLD,true))

static func crops(h,v):
	var s=h.sim.s
	var f=s.frontier
	var crop=h.atlas_crop
	var index=C.NAMES.find(crop)
	var row=U.box(false,4);v.add_child(row)
	for i in C.NAMES.size():
		choice(h,row,C.TITLES[i],"atlas_crop",C.NAMES[i],i==index)
	var sheet=U.box(false,14);v.add_child(sheet)
	sheet.add_child(picture(PLANTS,index,Vector2(142,142)))
	var info=U.box(true,5);info.size_flags_horizontal=Control.SIZE_EXPAND_FILL;sheet.add_child(info)
	info.add_child(h.title_label(C.title(crop),23))
	info.add_child(U.label(C.DESCRIPTIONS[index],15,U.TEXT,true))
	var cultivated=f.lines.has(crop)
	if cultivated:
		var line=f.lines[crop]
		info.add_child(U.label("栽培品系　丰产 %+d　耐逆 %d" % [line.yield_bonus,line.vigor],15,U.GREEN))
	else: info.add_child(U.label("尚待驯化 · 探险可带回地方种源",14,U.GOLD))
	info.add_child(U.label("基础粮 %d · 原种用种 %d · 饲料 %d · 地力 %+d" % [C.BASE[crop],C.SEED[crop],C.fodder(s,crop),C.SOIL[crop]],14,U.GOLD,true))
	if cultivated:
		for name in f.varieties[crop]:
			var stats=f.varieties[crop][name]
			info.add_child(U.label("%s　丰产 %+d · 耐逆 %d · 用种 %d" % [name,stats.yield_bonus,stats.vigor,C.seed_cost(s,crop,name)],12,U.DIM,true))
	var samples=f.samples.get(crop,[0,0])
	info.add_child(U.label("地方种源　丰穗 %d　/　耐逆 %d" % samples,14,U.DIM))
	var trial=U.box(false,6);v.add_child(trial)
	for k in 2:
		action(h,trial,("与%s杂交" if cultivated else "驯化%s") % C.SOURCES[k],"trial",[crop,k])
	if f.trials.has(crop):
		countdown(h,v,"试验田剩余 %d 秒",f.trials[crop].due,U.GOLD)
	else:
		v.add_child(U.label("投入同系种源 2 份、工粮 2 份，试种 40 秒。丰穗亲本提高产量，耐逆亲本缓解低地力、病情及缺水减产。",14,U.DIM,true))
	v.add_child(U.label("在农田面板可指定下茬。采集地每采 4 粮留一份种源，栽培收获也能留种。",14,U.TEXT,true))
	var odds=C.MUTATION[s.difficulty]
	v.add_child(U.label("本年景每种作物每季首次收获　有利变异 %d%%　不利变异 %d%%" % odds,13,U.GOLD,true))
	if h.sim.Study.discovered(s,crop): choice(h,v,"查看"+C.title(crop)+"农学分支","open_crop_study",crop)
	var stockrow=U.box(false,6);v.add_child(stockrow)
	stockrow.add_child(U.label("营地种仓 %d / %d" % [s.seed,h.T.seed_space(s,0)],14,U.DIM))
	stockrow.add_child(h.btn("封存 2 粮","reserve",false));stockrow.add_child(h.btn("解封种粮","reserve",true))
	if not f.disease.is_empty(): disease(v,f.disease)

static func disease(v,entry):
	v.add_child(U.label("田间病害记录　·　"+C.title(entry.crop),17,U.WARN))
	v.add_child(U.label(SYMPTOM[C.NAMES.find(entry.crop)]+" "+entry.date+"在"+V.address(entry.tile)+"首次发现。共用秧圃覆盖的在田作物受影响，巡田能保住更多收成。",14,U.TEXT,true))

static func survey(h,v):
	var s=h.sim.s
	v.add_child(U.label("出行需两名空闲居民、4 粮、1 木。32 秒后队员返回，营地为他们保留床位。",15,U.TEXT,true))
	for z in range(1,4):
		v.add_child(U.rule())
		var top=U.box(false,6);v.add_child(top)
		top.add_child(U.label(V.SECTORS[z],18,U.GOLD));top.add_child(U.space())
		top.add_child(U.label("已开放" if z in s.districts else "待开拓",14,U.DIM))
		v.add_child(U.label(F.LOCAL[z],13,U.DIM))
		var options=U.box(false,5);v.add_child(options)
		for crop in F.samples_at(s,z):
			action(h,options,"寻找"+C.title(crop)+"种源","survey",[z,crop])
	for j in s.frontier.missions:
		if j.kind=="survey": countdown(h,v,V.SECTORS[j.to]+"队 · 带回"+C.title(j.crop)+"　剩余 %d 秒",j.due,U.GREEN)

static func livestock(h,v):
	var f=h.sim.s.frontier
	if not h.sim.s.cells[f.home].connected:
		v.add_child(U.label("畜栏需由营地通路到农专，接入后季末才会产蛋奶。",14,U.WARN,true))
		if F.Roads.root(h.sim.s)>=0: choice(h,v,"为营地规划道路","street_to",f.home)
	var row=U.box(false,6);v.add_child(row)
	U.metric(row,"已用 / 栏位","%d / %d" % [f.hens+f.goats+f.broods.size(),f.pens*3])
	U.metric(row,"鸡群",str(f.hens));U.metric(row,"羊群",str(f.goats));U.metric(row,"饲料",str(f.feed))
	var buildings=U.box(false,5);v.add_child(buildings)
	action(h,buildings,"搭畜栏 · 3 木 2 石","pen")
	action(h,buildings,"备 4 饲料 · 2 粮","feed")
	v.add_child(U.rule())
	for entry in [["hens","鸡",f.hens,1],["goats","羊",f.goats,2]]:
		var pair=U.box(false,5);v.add_child(pair)
		action(h,pair,"引入"+entry[1]+"群 · 3 粮 2 木",entry[0])
		action(h,pair,"繁育"+entry[1]+"群 · 3 饲料","brood",entry[0])
		if f.broods.has(entry[0]): countdown(h,v,"幼"+entry[1]+"长成还需 %d 秒",f.broods[entry[0]],U.GREEN)
	v.add_child(U.label("两群同种成畜可以繁育。季末逐群喂养，先鸡后羊，每群鸡吃 1 料产 1 蛋，每群羊吃 2 料产 2 奶。",14,U.TEXT,true))
	action(h,v,"配给 %d 份蛋、%d 份奶，共增 %d 粮" % [f.eggs,f.milk,f.eggs+f.milk],"provision")
	v.add_child(U.label("鲜奶保留到下次季末。现有 %d 份厩肥，可在农田施用。" % f.manure,13,U.DIM,true))

static func freight(h,v):
	var s=h.sim.s
	var f=s.frontier
	if s.districts.size()==1:
		v.add_child(U.label("营地尚无外圩。先派探险队，或选地图上的外圩支付拓地费用。",16,U.TEXT,true))
		choice(h,v,"前往探险","frontier_tab","探险")
		return
	var a=h.freight_from
	var b=h.freight_to
	if a not in s.districts or b not in s.districts or a==b:
		a=0;b=s.districts[1]
		h.freight_from=a;h.freight_to=b
	for is_origin in [true,false]:
		var row=U.box(false,4);v.add_child(row)
		row.add_child(U.label("发自" if is_origin else "运至",14,U.DIM))
		for z in s.districts:
			choice(h,row,V.SECTORS[z],"freight_place",[is_origin,z],z==(a if is_origin else b))
	var lane=F.route(s,a,b)
	var count=8 if lane.road else 4
	var name="直达道路" if lane.road else "山间小径"
	if not lane.stops.is_empty():
		var places=PackedStringArray()
		for stop in lane.stops: places.append(V.SECTORS[stop])
		name="经"+"、".join(places)+"转运"
	v.add_child(U.label("%s　·　%d 秒　·　每批最多 %d 份" % [name,lane.time,count],17,U.GOLD))
	choice(h,v,"在地图上规划两地道路","street_between",[a,b])
	v.add_child(U.rule())
	var modes=U.box(false,5);v.add_child(modes)
	modes.add_child(U.label("发运数量",14,U.DIM))
	choice(h,modes,"单份","load_size",false,not h.full_load)
	choice(h,modes,"尽量装满","load_size",true,h.full_load)
	var goods=U.box(false,4);v.add_child(goods)
	for k in ["food","seed","wood","stone","feed","people"]:
		var avail=F.stock(s,a,k)
		var space=F.free_space(s,b,k) if k in ["wood","stone","seed","feed"] else count
		var units=1 if not h.full_load or k=="people" else maxi(1,mini(space,mini(count,avail)))
		action(h,goods,"%s ×%d" % [F.LABEL[k],units],"ship",[a,b,k,units])
	for place in [a,b]:
		v.add_child(U.label("%s　%d 人　%d 粮　%d 种　%d 木　%d 石" % [V.SECTORS[place],F.stock(s,place,"people"),F.stock(s,place,"food"),F.stock(s,place,"seed"),F.stock(s,place,"wood"),F.stock(s,place,"stone")],14,U.TEXT,true))
		if not s.cells[F.anchor(s,place)].connected: v.add_child(U.label("尚未通往农专 · 仅可徒步运送，常规生产暂停",13,U.WARN,true))
		if place>0:
			v.add_child(U.label("口粮仓容 %d　" % h.T.storage(s,place)+F.LOCAL[place]+("　上季缺 %d 粮" % f.posts[place].short if f.posts[place].short else ""),13,U.DIM))
	for j in f.missions:
		if j.kind=="ship": countdown(h,v,"%s → %s　%d %s　" % [V.SECTORS[j.from],V.SECTORS[j.to],j.amount,F.LABEL[j.key]]+"剩余 %d 秒",j.due,U.GREEN)

static func inventory(h,v):
	var s=h.sim.s
	var f=s.frontier
	v.add_child(U.label("物资分布　·　营地 / 拓殖地 / 在途",17,U.GOLD))
	for k in F.GOODS:
		var away=0
		var transit=0
		for p in f.posts.values(): away+=p[k]
		for j in f.missions:
			if j.key==k: transit+=j.amount
		v.add_child(U.label("%s　　%d　/　%d　/　%d" % [F.LABEL[k],F.stock(s,0,k),away,transit],15,U.TEXT))
	v.add_child(U.label("畜产　蛋 %d　奶 %d　饲料 %d　厩肥 %d" % [f.eggs,f.milk,f.feed,f.manure],14,U.DIM))
	if f.region==4:
		var w=F.Farm.spring_water(s)
		v.add_child(U.rule());v.add_child(U.label("河口淡水　%d / %d" % [f.fresh,w.capacity],19,U.GOLD))
		var bar=ProgressBar.new();bar.show_percentage=false;bar.max_value=w.capacity;bar.value=f.fresh
		bar.custom_minimum_size.y=10;v.add_child(bar)
		v.add_child(U.label("本季集雨 +%d　居民与田块需 %d　预计结余 %d　缺口 %d" % [w.rain,w.need,w.balance,w.short],14,U.WARN if w.short>0 else U.TEXT,true))
		action(h,v,"建集雨池 · 3 木 2 石，每季多蓄 6 水","well")
