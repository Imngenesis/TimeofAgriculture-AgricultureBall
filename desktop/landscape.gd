extends RefCounted

const V=preload("res://valley.gd")
const G=preload("res://geometry.gd")
const WOOD=Color("#604532")
const REED=Color("#b09a60")
const STONE=Color("#797866")
const LEAF=[Color("#47664e"),Color("#688559"),Color("#768857"),Color("#405e50"),Color("#86915c")]

static func _land_color(x: float,z: float) -> Color:
	var distance=absf(x-V.river(z))-V.breadth(z)
	var meadow=Color("#7d8c66").lerp(Color("#647b57"),0.5+0.47*sin(x*0.57+sin(z*0.49))*cos(z*0.35))
	var dry=Color("#a29873").lerp(Color("#79845c"),0.5+0.4*sin(z*0.58+x*0.37))
	var c=meadow.lerp(dry,smoothstep(3.0,10.0,distance))
	var bank=Color("#a39670").lerp(Color("#807d60"),0.4+0.4*cos(z*0.97))
	return bank.lerp(c,smoothstep(0.12,1.7,distance))

static func terrain():
	var mesh=G.new()
	var step=0.53
	var cols=115
	var rows=105
	var pts=PackedVector3Array()
	var norms=PackedVector3Array()
	var shades=PackedColorArray()
	for j in rows:
		for i in cols:
			var x=(i-cols*0.5)*step
			var z=(j-rows*0.5)*step
			pts.append(Vector3(x,V.ground(x,z),z))
			norms.append(Vector3(V.ground(x-0.12,z)-V.ground(x+0.12,z),0.24,V.ground(x,z-0.12)-V.ground(x,z+0.12)).normalized())
			shades.append(_land_color(x,z))
	for j in rows-1:
		for i in cols-1:
			var k=j*cols+i
			for t in [[k,k+1,k+cols],[k+1,k+1+cols,k+cols]]:
				mesh.gradient_triangle(pts[t[0]],pts[t[1]],pts[t[2]],shades[t[0]],shades[t[1]],shades[t[2]],norms[t[0]],norms[t[1]],norms[t[2]])
	return mesh

static func river_mesh():
	var g=G.new()
	var span=0.34
	for j in 164:
		var z=-28.0+j*span
		var z2=z+span
		for lane in 6:
			var l=-1.0+lane/3.0
			var r=l+1.0/3.0
			var a=Vector3(V.river(z)+l*(V.breadth(z)+0.75),0.005,z)
			var b=Vector3(V.river(z)+r*(V.breadth(z)+0.75),0.005,z)
			var c=Vector3(V.river(z2)+r*(V.breadth(z2)+0.75),0.005,z2)
			var d=Vector3(V.river(z2)+l*(V.breadth(z2)+0.75),0.005,z2)
			g.quad(a,b,c,d,Color(absf(l)*0.65+0.15,clampf((z+9)/18,0,1),0.65))
	return g

static func tree(g,p: Vector3,size: float,rng: RandomNumberGenerator,slender: bool):
	var lean=Vector3(rng.randf_range(-0.16,0.16),0,rng.randf_range(-0.13,0.13))*size
	var top=p+Vector3.UP*size*0.92+lean
	var bark=Color("#5b5842") if slender else Color("#655341")
	g.beam(p-Vector3.UP*0.08,top,0.105*size,0.024*size,bark)
	var base_color=LEAF[rng.randi_range(0,LEAF.size()-1)]
	if slender: base_color=base_color.lerp(Color("#85905b"),0.32)
	for k in (5 if slender else 7):
		var angle=k*2.4+rng.randf_range(-0.35,0.35)
		var rise=float(k)/(5 if slender else 7)
		var offset=Vector3(cos(angle),0,sin(angle))*(0.21 if slender else 0.37)*(1.0-0.55*rise)*size
		var hub=p+Vector3.UP*size*(0.48+rise*0.65)+lean*rise
		var tip=hub+offset+Vector3.UP*size*0.22
		g.beam(hub-Vector3.UP*0.12*size,tip,0.042*size,0.015*size,bark,5)
		var rad=(0.27 if slender else 0.39)*size*(1.0-0.31*rise)
		var tint=base_color.lerp(Color("#a3a36a"),rng.randf_range(0,0.19))
		var extent=Vector3(rad,rad*(1.40 if slender else 0.82),rad*0.90)
		g.crown(tip,extent,tint,angle)
		for outer in 6:
			var twig_dir=Vector3(rng.randf_range(-1,1),rng.randf_range(-0.55,0.9),rng.randf_range(-1,1)).normalized()
			var outer_tip=tip+twig_dir*extent*0.86
			var twig_size=rad*rng.randf_range(0.20,0.39)
			g.oval(outer_tip,Vector3(twig_size,twig_size*1.05,twig_size*0.83),tint.darkened(rng.randf_range(0.02,0.18)),outer*2.15,6,3)

static func tuft(g,p: Vector3,h: float,col: Color,rng: RandomNumberGenerator,heads: bool=false):
	for i in 5:
		var a=rng.randf()*TAU
		var foot=p+Vector3(cos(a),0,sin(a))*h*rng.randf_range(0.03,0.30)
		var bend=Vector3(cos(a),0,sin(a))*h*rng.randf_range(0.1,0.49)
		var tip=foot+Vector3.UP*h*rng.randf_range(0.55,1.1)+bend
		var across=Vector3(-sin(a),0,cos(a))*h*0.065
		g.tri(foot-across,foot+across,tip,col,Vector3.UP+across)
		if heads and i<3:
			g.beam(tip,tip+bend*0.33+Vector3.UP*h*0.10,h*0.047,h*0.016,Color("#bb9c5a"),4)

static func backdrop():
	var g=G.new()
	var rng=RandomNumberGenerator.new()
	rng.seed=70173
	for i in 1850:
		var p=Vector2(rng.randf_range(-26,26),rng.randf_range(-24,24))
		var bank=absf(p.x-V.river(p.y))-V.breadth(p.y)
		if bank < -0.2: continue
		var id=V.cell_at(p)
		if id>=0:
			var dist=p.distance_to(V.center(id))
			if dist<1.10 and bank>0.6: continue
		var h=rng.randf_range(0.14,0.38)*(1.25 if bank<0.6 else 1.0)
		tuft(g,V.v3(p),h,Color("#899058") if bank>0.6 else Color("#7f8250"),rng,bank<0.7)
	for i in 335:
		var p=Vector2(rng.randf_range(-26,26),rng.randf_range(-26,22))
		var id=V.cell_at(p)
		var bank=absf(p.x-V.river(p.y))-V.breadth(p.y)
		if bank<0.7: continue
		if id>=0 and (p.distance_to(V.center(id))<1.08 or i%3!=0): continue
		if id<0 and sin(p.x*0.38+p.y*0.28)>0.66: continue
		tree(g,V.v3(p),rng.randf_range(1.0,2.2)*(1.15 if id<0 else 0.72),rng,bank<2.1 or i%7==0)
	for i in 75:
		var z=rng.randf_range(-23,22)
		var side=1.0 if i%2==0 else -1.0
		var p=Vector2(V.river(z)+side*(V.breadth(z)+rng.randf_range(-0.17,0.75)),z)
		g.oval(V.v3(p,0.035),Vector3(0.18,0.11,0.15)*rng.randf_range(0.5,1.9),STONE,i,6,3)
	for j in 50:
		var z=rng.randf_range(-22,22)
		var side=1 if j%2 else -1
		var base=Vector2(V.river(z)+side*(V.breadth(z)+0.48),z)
		for k in rng.randi_range(7,15):
			var p=base+Vector2(rng.randf_range(-0.35,0.35),rng.randf_range(-0.7,0.7))
			tuft(g,V.v3(p),rng.randf_range(0.33,0.64),Color("#798853"),rng,k%3==0)
	# A towpath follows the west bank and remains recognizable at any zoom.
	for i in 155:
		var z=-25.0+i*0.31
		var zz=z+0.31
		var x=V.river(z)-V.breadth(z)-1.38-0.24*sin(z*0.95)
		var xx=V.river(zz)-V.breadth(zz)-1.38-0.24*sin(zz*0.95)
		g.quad(V.v3(Vector2(x-0.13,z),0.018),V.v3(Vector2(x+0.13,z),0.018),V.v3(Vector2(xx+0.13,zz),0.018),V.v3(Vector2(xx-0.13,zz),0.018),Color("#bbab80"))
	_wharf(g)
	for z in [-3.5,4.8]:
		var half=V.breadth(z)+1.75
		var x=V.river(z)
		for i in 31:
			var px=x-half+2.0*half*i/30.0
			g.box(Vector3(px,0.47,z),Vector3(half/15.0-0.012,0.08,0.54),WOOD.lightened(0.05+0.03*(i%3)))
			if i%5==0:
				g.beam(Vector3(px,-0.43,z-0.24),Vector3(px,0.85,z-0.24),0.043,0.035,WOOD)
		g.beam(Vector3(x-half,0.79,z-0.24),Vector3(x+half,0.79,z-0.24),0.024,0.024,REED,5)
	return g

static func _wharf(g):
	var z=-2.8
	var p=Vector3(V.river(z)-V.breadth(z)-0.30,0.40,z)
	for i in 13:
		g.box(p+Vector3(i*0.10,0,0),Vector3(0.091,0.08,0.63),WOOD.lightened(0.04*(i%3)))
	for dx in [0.0,1.12]:
		for dz in [-0.26,0.26]:
			var q=p+Vector3(dx,0,dz)
			g.beam(q-Vector3.UP*0.77,q+Vector3.UP*0.21,0.046,0.042,WOOD,6)
	var boat=p+Vector3(1.35,-0.31,0.14)
	var nose=boat+Vector3(0.09,0.13,-0.85)
	var stern=boat+Vector3(-0.09,0.12,0.85)
	for side in [-1,1]:
		var mid=boat+Vector3(0.22*side,0.01,0)
		g.tri(nose,mid,stern,Color("#64442e"))
		g.beam(nose,mid,0.035,0.045,WOOD,5)
		g.beam(mid,stern,0.045,0.03,WOOD,5)
	g.beam(boat+Vector3(-0.38,0.12,-0.16),boat+Vector3(0.38,0.18,0.45),0.022,0.033,REED,5)
	var gauge=p+Vector3(0.98,-0.42,-0.46)
	g.beam(gauge-Vector3.UP*0.35,gauge+Vector3.UP*1.47,0.066,0.054,Color("#655540"))
	for j in 9:
		g.box(gauge+Vector3(0.03,0.14+j*0.14,0.044),Vector3(0.092 if j%2==0 else 0.057,0.027,0.035),Color("#decda1"))

static func house(g,p: Vector3,scale_by: float,yaw: float,granary: bool=false):
	var x=Vector3(cos(yaw),0,sin(yaw))*scale_by
	var z=Vector3(-sin(yaw),0,cos(yaw))*scale_by
	var y=Vector3.UP*scale_by
	var floor_h=0.36 if granary else 0.08
	var base=p+y*floor_h
	for xx in [-0.45,0.45]:
		for zz in [-0.34,0.34]:
			var q=base+x*xx+z*zz
			g.beam(q-y*0.65,q+y*0.63,0.042*scale_by,0.034*scale_by,WOOD)
	g.box(base+y*0.27,Vector3(0.91,0.58,0.67)*scale_by,Color("#a88d64") if not granary else Color("#88704c"),yaw)
	for j in 8:
		var q=base+x*(-0.43+j*0.12)+z*0.343
		g.beam(q,q+y*0.53,0.012*scale_by,0.012*scale_by,WOOD.lightened(0.13),4)
	g.box(base+y*0.21+z*0.349,Vector3(0.20,0.42,0.025)*scale_by,Color("#4d4935"),yaw)
	for side in [-1,1]:
		var a=base-x*0.61+z*(side*0.48)+y*0.49
		var b=a+x*1.22
		var c=base+x*0.56+y*0.91
		var d=base-x*0.56+y*0.91
		g.quad(a,b,c,d,Color("#a28a54") if side==1 else Color("#8c764b"),y+z*side)
		g.tri(a,d,base-x*0.56+y*0.50,REED,-x)
		g.tri(b,c,base+x*0.56+y*0.50,REED,x)
		for k in 16:
			var f=(k+0.5)/16.0
			var e=a.lerp(b,f)
			var ridge=d.lerp(c,f)
			g.beam(e,ridge,0.022*scale_by,0.014*scale_by,REED.darkened(0.05*(k%4)),4)
	g.beam(base-x*0.66+y*0.92,base+x*0.66+y*0.92,0.045*scale_by,0.045*scale_by,WOOD)

static func field(g,id: int,c: Dictionary,season: int,sick: bool):
	var p=V.center(id)
	var size=0.82
	var soil=Color("#675d3d") if not c.crop else Color("#716e4b")
	if c.terrace: soil=Color("#7e774b")
	var local_rng=RandomNumberGenerator.new()
	local_rng.seed=id*53+20
	for j in 7:
		for k in 7:
			var x=-size+j*size*2/7
			var z=-size+k*size*2/7
			var h=0.057+(0.052*floori(k/2.0) if c.terrace else 0.0)
			var a=V.v3(p+Vector2(x,z),h)
			var b=V.v3(p+Vector2(x+size*2/7,z),h)
			var d=V.v3(p+Vector2(x,z+size*2/7),h)
			var e=V.v3(p+Vector2(x+size*2/7,z+size*2/7),h)
			g.quad(a,b,e,d,soil.lightened(0.018*(j%2)))
			if c.crop:
				var q=(a+e)*0.5
				var plant=Color("#a4944d") if season==2 else Color("#749546")
				if sick and (j+k)%4==0: plant=Color("#95774b")
				tuft(g,q,0.30 if season==2 else 0.23,plant,local_rng,season==2)
	for side in 4:
		var corners=[Vector2(-size,-size),Vector2(size,-size),Vector2(size,size),Vector2(-size,size)]
		for j in 6:
			var a=p+corners[side].lerp(corners[(side+1)%4],j/6.0)
			var b=p+corners[side].lerp(corners[(side+1)%4],(j+1)/6.0)
			g.beam(V.v3(a,0.09),V.v3(b,0.09),0.058,0.058,Color("#999264"),5)
	if c.ditch:
		var a=V.v3(p+Vector2(-0.92,-0.9),0.06)
		var b=V.v3(p+Vector2(-0.92,0.9),0.06)
		g.beam(a,b,0.09,0.09,Color("#538576"),6)

static func site(g,id: int,c: Dictionary,season: int,sick: bool):
	var xy=V.center(id)
	var p=V.v3(xy,0.04)
	var rng=RandomNumberGenerator.new()
	rng.seed=101+id*203
	match c.kind:
		"camp":
			house(g,V.v3(xy+Vector2(-0.31,-0.36)),1.03,0.21)
			house(g,V.v3(xy+Vector2(0.51,0.48)),0.72,-0.61)
			for i in 4:
				var q=V.v3(xy+Vector2(-0.60+i*0.17,0.50),0.15)
				g.oval(q,Vector3(0.12,0.15,0.13),REED,i,7,3)
		"wild":
			for j in 30:
				var offset=Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*0.92
				tuft(g,V.v3(xy+offset),rng.randf_range(0.31,0.60),Color("#98934d"),rng,true)
			var post=V.v3(xy+Vector2(0.75,0.12))
			g.beam(post,post+Vector3.UP*0.65,0.034,0.025,WOOD)
			g.box(post+Vector3(0,0.54,0),Vector3(0.29,0.14,0.055),REED,0.2)
		"farm": field(g,id,c,season,sick)
		"store":
			house(g,p,1.32,-0.22,true)
			for j in 3:
				g.oval(V.v3(xy+Vector2(-0.50+j*0.22,0.67),0.19),Vector3(0.13,0.19,0.13),REED,j,8,3)
		"station":
			g.box(p+Vector3.UP*0.36,Vector3(1.25,0.72,0.79),Color("#a89f82"))
			g.box(p+Vector3.UP*0.76,Vector3(1.40,0.12,0.95),Color("#63756a"))
			g.box(p+Vector3(0.12,0.28,0.403),Vector3(0.6,0.54,0.035),Color("#464d43"))
			var q=p+Vector3(-0.28,0.20,0.72)
			g.box(q,Vector3(0.57,0.17,0.26),Color("#9a7048"))
			for xx in [-0.18,0.20]:
				for zz in [-0.15,0.15]:
					g.oval(q+Vector3(xx,-0.07,zz),Vector3(0.12,0.12,0.055),Color("#484a3c"),0,7,3)
	if c.project!="":
		for a in [-0.66,0.66]:
			for b in [-0.62,0.62]:
				var q=V.v3(xy+Vector2(a,b))
				g.beam(q,q+Vector3.UP*0.62,0.032,0.024,WOOD)
		for i in 6:
			g.beam(p+Vector3(-0.45,0.07+i*0.023,-0.21+i*0.045),p+Vector3(0.40,0.08+i*0.023,-0.21+i*0.045),0.045,0.034,REED.darkened(0.18))

static func dike(g,e: Dictionary):
	var a=V.corner(e.a,e.dir)
	var b=V.corner(e.a,e.dir+1)
	for i in 9:
		var p=V.v3(a.lerp(b,i/8.0))
		g.beam(p-Vector3.UP*0.11,p+Vector3.UP*(0.50 if e.built else 0.30),0.045,0.03,WOOD)
		if i<8 and e.built:
			var q=V.v3(a.lerp(b,(i+1)/8.0))
			g.beam(p+Vector3.UP*0.10,q+Vector3.UP*0.10,0.28,0.28,Color("#877b58"),6)
			g.beam(p+Vector3.UP*0.33,q+Vector3.UP*0.33,0.15,0.15,Color("#8c895d"),6)
