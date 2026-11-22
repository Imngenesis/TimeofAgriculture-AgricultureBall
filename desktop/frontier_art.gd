extends RefCounted

const V=preload("res://valley.gd")
const F=preload("res://frontier.gd")

static func cart(g):
	var wood=Color("#805b41")
	var rim=Color("#584c3e")
	g.box(Vector3(0,0.19,0),Vector3(0.36,0.09,0.57),wood)
	for x in [-0.21,0.21]:
		var hub=Vector3(x,0.17,-0.02)
		for k in 10:
			var a=Vector3(0,cos(k*TAU/10),sin(k*TAU/10))*0.15
			var b=Vector3(0,cos((k+1)*TAU/10),sin((k+1)*TAU/10))*0.15
			g.beam(hub+a,hub+b,0.023,0.023,rim,5)
			if k%2==0: g.beam(hub,hub+a,0.012,0.012,wood,4)
		g.beam(hub+Vector3(0,0.10,0.10),hub+Vector3(0,0.12,0.44),0.018,0.014,wood)
	for i in 3:
		g.oval(Vector3((i%2-0.5)*0.15,0.30+i*0.012,(i-1)*0.14),Vector3(0.13,0.12,0.14),Color("#baa77c"),i*0.7)

static func crop_rows(g,id,species,autumn):
	var rng=RandomNumberGenerator.new()
	rng.seed=151+id
	for row in 7:
		for col in 7:
			var p=V.v3(V.center(id)+Vector2(-0.8+row*0.26,-0.8+col*0.26),0.10)
			var h=rng.randf_range(0.21,0.36)
			if species in ["薯","豆"]:
				for i in 3:
					var angle=i*TAU/3+col
					g.oval(p+Vector3(cos(angle)*0.065,h*0.4,sin(angle)*0.065),Vector3(0.09,0.055,0.08),Color("#597643") if species=="薯" else Color("#739853"),angle,6,3)
				if species=="豆": g.beam(p,p+Vector3(0,h,0),0.013,0.008,Color("#435b38"))
			elif species=="玉米":
				var stem=p+Vector3.UP*h*1.8
				var leaf=Color("#73924a") if not autumn else Color("#958250")
				g.beam(p,stem,0.018,0.009,leaf,5)
				for side in [-1,1]:
					var node=p.lerp(stem,0.47+side*0.10)
					g.tri(node,node+Vector3(side*0.09,0.11,0.03),node+Vector3(side*0.16,0.08,0.02),leaf)
				g.oval(p.lerp(stem,0.64)+Vector3(0.025,0,0),Vector3(0.034,0.071,0.03),Color("#d2a74d") if autumn else leaf)
			else:
				var tip=p+Vector3(0.04,h,0)
				var shade=Color("#c9ad64") if autumn else Color("#819451")
				g.beam(p,tip,0.012,0.008,shade,5)
				g.oval(tip,Vector3(0.041,0.087,0.037) if species=="粟" else Vector3(0.025,0.084,0.025),shade.lightened(0.16),0,6,3)

static func stockyard(g,s):
	var f=s.frontier
	for i in mini(7,f.hens+f.goats):
		var hen=i<mini(f.hens,4) or f.goats==0
		var p=V.v3(V.center(f.home)+Vector2(-0.91+0.31*(i%4),0.76+floori(i/4.0)*0.27))
		var coat=Color("#c39561") if hen else Color("#d9cbb2")
		var h=0.13 if hen else 0.24
		g.oval(p+Vector3.UP*h,Vector3(h*0.77,h*0.56,h),coat)
		var head=p+Vector3(0,h*1.55,h*0.85)
		g.oval(head,Vector3.ONE*h*0.43,coat)
		if hen: g.oval(head+Vector3.UP*0.052,Vector3(0.021,0.032,0.04),Color("#ac5037"))
		else:
			for side in [-1,1]:
				g.beam(head+Vector3(side*0.04,0.05,0),head+Vector3(side*0.065,0.14,-0.04),0.02,0.005,Color("#6c5d48"))
		for side in [-1,1]:
			for end in [-1,1]:
				var foot=p+Vector3(side*h*0.42,0,end*h*0.5)
				g.beam(foot,foot+Vector3.UP*h,0.013,0.02,coat)
	if f.pens>0:
		var origin=V.center(f.home)+Vector2(-0.35,0.91)
		for k in 5:
			var q=V.v3(origin+Vector2(-0.72+0.36*k,0.36),0.02)
			g.beam(q,q+Vector3.UP*0.31,0.026,0.023,Color("#815f47"))
			if k<4:
				for h in [0.13,0.23]: g.beam(q+Vector3.UP*h,q+Vector3(0.36,h,0),0.018,0.018,Color("#9c805b"))
	if f.wells>0:
		var basin=V.v3(V.center(f.home)+Vector2(0.73,-0.79),0.04)
		g.beam(basin,basin+Vector3.UP*0.21,0.31,0.34,Color("#82795f"),16)
		g.beam(basin+Vector3.UP*0.21,basin+Vector3.UP*0.216,0.29,0.29,Color("#648e8b"),16)
		g.beam(basin+Vector3(-0.29,0.18,0),basin+Vector3(-0.29,0.51,0),0.024,0.024,Color("#785f45"))

static func network(g,s):
	for z in s.frontier.posts:
		var p=V.v3(V.center(F.anchor(s,z))+Vector2(0.50,-0.74),0.05)
		g.box(p+Vector3.UP*0.23,Vector3(0.69,0.46,0.54),Color("#aa9067"))
		for sign_x in [-1,1]:
			var edge=p+Vector3(sign_x*0.42,0.43,0)
			var peak=p+Vector3.UP*0.68
			g.quad(edge+Vector3.BACK*0.35,edge+Vector3.FORWARD*0.35,peak+Vector3.FORWARD*0.35,peak+Vector3.BACK*0.35,Color("#765c46"))
		g.beam(p+Vector3(0.5,0,0),p+Vector3(0.5,1.05,0),0.024,0.016,Color("#66513e"))
		g.tri(p+Vector3(0.5,1.04,0),p+Vector3(0.84,0.99,0),p+Vector3(0.5,0.79,0),Color("#bc805c"),Vector3.BACK)
	for pair in s.frontier.roads.values():
		var path=F.route_points(s,pair[0],pair[1])
		for i in path.size()-1:
			var a=Vector2(path[i]);var b=Vector2(path[i+1])
			var count=maxi(1,ceili(a.distance_to(b)*3))
			if absf(a.y-b.y)<0.001 and absf(a.x-V.river(a.y))<V.breadth(a.y)+1.67: continue
			var side=(b-a).normalized().orthogonal()*0.12
			for j in count:
				var x=a.lerp(b,float(j)/count);var y=a.lerp(b,float(j+1)/count)
				g.quad(V.v3(x-side,0.06),V.v3(x+side,0.06),V.v3(y+side,0.06),V.v3(y-side,0.06),Color("#a58c63"))
