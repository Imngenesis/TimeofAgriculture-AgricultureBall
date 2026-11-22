extends RefCounted

const E=preload("res://economy.gd")
const RAIN=[7,13,6,4]
const CAPACITY=3

static func spring_water(s: Dictionary) -> Dictionary:
	var f=s.frontier
	var intake=RAIN[s.turn%4]+6*f.wells
	var need=ceili(s.pop*0.75)
	for c in s.cells:
		if c.kind=="farm": need+=1
	var capacity=40+8*f.wells
	var available=mini(capacity,f.fresh+intake)
	return {"rain":intake,"need":need,"capacity":capacity,"balance":maxi(0,available-need),"short":maxi(0,need-available)}

static func reason(s: Dictionary,cmd: String,arg) -> String:
	var f=s.frontier
	match cmd:
		"well","pen":
			if cmd=="well" and f.region!=4: return "集雨池适用于滨海河口"
			if s.wood<3 or s.stone<2: return "需 3 木和 2 石"
		"hens","goats":
			if f.hens+f.goats+f.broods.size()>=CAPACITY*f.pens: return "先搭畜栏或扩栏，每栏容纳三群"
			if s.food<3 or s.wood<2: return "需 3 粮和 2 木"
		"brood":
			if arg not in ["hens","goats"] or f[arg]<2: return "繁育需同种两群成畜"
			if f.broods.has(arg): return "同一畜群已有幼畜在养"
			if f.hens+f.goats+f.broods.size()>=CAPACITY*f.pens: return "需要一个空栏位"
			if f.feed<3: return "哺育幼畜需 3 份饲料"
		"feed":
			if s.food<2: return "制备饲料需 2 粮"
		"provision":
			if f.eggs+f.milk==0: return "等待畜群产蛋或产奶"
		"manure":
			if typeof(arg)!=TYPE_INT or arg<0 or arg>=s.cells.size() or s.cells[arg].kind!="farm": return "请选择农田"
			if f.manure==0 or s.cells[arg].compost==s.turn: return "需 1 份厩肥，同一块田每季施用一次"
		_: return "未知农庄事务"
	return ""

static func act(s: Dictionary,cmd: String,arg):
	var f=s.frontier
	match cmd:
		"well","pen":
			E.supply(s,"wood",-3)
			E.supply(s,"stone",-2)
			if cmd=="well": f.wells+=1
			else: f.pens+=1
		"hens","goats":
			E.supply(s,"wood",-2)
			s.food-=3
			s.ledger.husbandry+=3
			f[cmd]+=1
		"brood":
			f.feed-=3
			f.broods[arg]=s.time+40
		"feed":
			s.food-=2
			s.ledger.husbandry+=2
			f.feed+=4
		"provision":
			var total=f.eggs+f.milk
			s.food+=total
			s.ledger.livestock+=total
			f.eggs=0
			f.milk=0
		"manure":
			f.manure-=1
			s.cells[arg].soil=mini(96,s.cells[arg].soil+10)
			s.cells[arg].compost=s.turn

static func tick(m):
	var f=m.s.frontier
	for species in f.broods.keys():
		if m.s.time>=f.broods[species]:
			f[species]+=1
			f.broods.erase(species)
			m.note("畜栏里一群幼%s已经长成。" % ("鸡" if species=="hens" else "羊"))
			m.s.rev+=1

static func settle(m):
	var s=m.s
	var f=s.frontier
	var eggs=mini(f.feed,f.hens)
	f.feed-=eggs
	var milk=mini(f.goats,floori(f.feed/2.0))*2
	f.feed-=milk
	s.ledger.dairy_loss=f.milk
	f.milk=milk
	f.eggs+=eggs
	f.manure+=floori((eggs+milk+f.bedding)/2.0)
	f.bedding=(eggs+milk+f.bedding)%2
	s.ledger.eggs=eggs
	s.ledger.milk=milk
	if f.region==4:
		var water=spring_water(s)
		f.fresh=water.balance
		f.water_short=water.short
		if water.short>0:
			s.organization=maxi(0,s.organization-3)
			m.note("本季淡水短缺 %d 份，组织度降低 3。可搭集雨池补水。" % water.short)
