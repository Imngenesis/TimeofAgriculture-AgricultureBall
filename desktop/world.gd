extends Node3D

const V=preload("res://valley.gd")
const G=preload("res://geometry.gd")
const L=preload("res://landscape.gd")
const Sim=preload("res://simulation.gd")
var sim
var camera=Camera3D.new()
var sun=DirectionalLight3D.new()
var env=Environment.new()
var solid=StandardMaterial3D.new()
var overlay_material=StandardMaterial3D.new()
var water_material=ShaderMaterial.new()
var earth=ShaderMaterial.new()
var flood_material=ShaderMaterial.new()
var flood_surface: Node3D
var flood_key=""
var dynamic_sites: Node3D
var cover: Node3D
var marks: Node3D
var ghost: Node3D
var grid_node: Node3D
var menu_farms: Node3D
var people=[]
var camera_point=Vector2(-0.1,0.4)
var destination=Vector2(-0.1,0.4)
var zoom=19.5
var target_zoom=19.5
var menu_mode=true
var selected=-1
var hover=-1
var build_tool=""
var edge_dir=0
var edge_shift=0
var risk=""
var rev=-1
var stamp=""
var overlay_stamp=""
var target_atmosphere=0.0
var atmosphere=0.0

func setup(model):
	sim=model
	solid.vertex_color_use_as_albedo=true
	solid.roughness=0.92
	solid.cull_mode=BaseMaterial3D.CULL_DISABLED
	overlay_material.vertex_color_use_as_albedo=true
	overlay_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	overlay_material.render_priority=3
	earth.shader=preload("res://ground.gdshader")
	add_child(L.terrain().bake(earth))
	water_material.shader=preload("res://water.gdshader")
	add_child(L.river_mesh().bake(water_material))
	flood_material.shader=preload("res://flood.gdshader")
	var scenery=L.backdrop().bake(solid)
	add_child(scenery)
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("#b7b5a0")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("#d0dcd6")
	env.ambient_light_energy=0.58
	env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	env.fog_enabled=true
	env.fog_mode=Environment.FOG_MODE_DEPTH
	env.fog_depth_begin=32.0
	env.fog_depth_end=83.0
	env.fog_light_color=Color("#b6b59d")
	env.fog_density=0.44
	var we=WorldEnvironment.new()
	we.environment=env
	add_child(we)
	sun.rotation_degrees=Vector3(-42,-38,0)
	sun.light_color=Color("#fff0d8")
	sun.light_energy=0.83
	sun.shadow_opacity=0.70
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=57
	sun.shadow_bias=0.045
	add_child(sun)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.near=0.1
	camera.far=150
	add_child(camera)
	camera.current=true
	camera.size=zoom
	_update_camera()
	var gg=G.new()
	for i in V.COLS*V.ROWS:
		if V.tier(i)<0: continue
		for d in 6:
			var other=V.nb(i,d)
			if other>=0 and other<i and V.tier(other)>=0: continue
			_line(gg,V.corner(i,d),V.corner(i,d+1),0.022,Color(0.9,0.87,0.65,0.46),0.11)
	grid_node=gg.bake(overlay_material)
	add_child(grid_node)
	grid_node.visible=false
	var demo=G.new()
	for id in [11,12,16,24,25,30,31,37,38,39,46,47,49,52,55,56,57,64,66]:
		if V.tier(id)<0 or Sim.WILD.has(id) or id==Sim.HOME: continue
		var c=sim.s.cells[id].duplicate()
		c.kind="store" if id in [11,37,52] else "farm"
		c.terrace=id%3==0
		c.crop=true
		L.site(demo,id,c,2,false)
	menu_farms=demo.bake(solid)
	add_child(menu_farms)
	_make_people()
	refresh(true)

func _make_people():
	var coats=[Color("#6b8077"),Color("#a66b43"),Color("#ab9165"),Color("#626e7a"),Color("#6f7955")]
	for i in sim.s.pop:
		var g=G.new()
		var q=Vector3.ZERO
		g.beam(q+Vector3(-0.048,0.03,0),q+Vector3(-0.042,0.19,0),0.029,0.035,Color("#55483c"),5)
		g.beam(q+Vector3(0.048,0.03,0.026),q+Vector3(0.041,0.19,0.012),0.029,0.034,Color("#57483a"),5)
		g.beam(q+Vector3.UP*0.16,q+Vector3.UP*0.37,0.10,0.068,coats[i%5],7)
		g.oval(q+Vector3.UP*0.415,Vector3(0.061,0.075,0.062),Color("#b59572"),0,7,3)
		g.beam(q+Vector3.UP*0.46,q+Vector3.UP*0.55,0.157,0.013,Color("#beaa6f"),9)
		g.beam(q+Vector3(0.075,0.32,0),q+Vector3(0.13,0.21,0.06),0.029,0.02,coats[i%5],5)
		var node=g.bake(solid)
		node.scale=Vector3.ONE*1.12
		people.append(node)
		add_child(node)

func _line(g,a: Vector2,b: Vector2,width: float,col: Color,lift: float):
	var cross_axis=(b-a).normalized().orthogonal()*width*0.5
	for k in 3:
		var p=a.lerp(b,k/3.0)
		var q=a.lerp(b,(k+1)/3.0)
		g.quad(V.v3(p-cross_axis,lift),V.v3(p+cross_axis,lift),V.v3(q+cross_axis,lift),V.v3(q-cross_axis,lift),col)

func _tile(g,id: int,col: Color,h: float):
	var p=V.center(id)
	for j in 6:
		var a=V.corner(id,j,0.98)
		var b=V.corner(id,j+1,0.98)
		for k in 3:
			g.tri(V.v3(p,h),V.v3(a.lerp(b,k/3.0),h),V.v3(a.lerp(b,(k+1)/3.0),h),col)

func _ring(g,id: int,col: Color,width: float):
	for i in 6: _line(g,V.corner(id,i,0.96),V.corner(id,i+1,0.96),width,col,0.18)

func _replace(old: Node3D,g,material: Material) -> Node3D:
	if is_instance_valid(old):
		old.visible=false
		old.queue_free()
	var node=g.bake(material)
	add_child(node)
	return node

func _flood_surface():
	var wet={}
	for i in sim.s.flood_cells: wet[i]=true
	var geo=G.new()
	var stride=0.32
	var points=PackedVector3Array()
	var masks=PackedColorArray()
	var width=52
	var rows=84
	for j in rows:
		var z=(j-rows*0.5)*stride
		var stream=V.river(z)
		for k in width:
			var x=stream+(k-width*0.5)*stride
			var p=Vector2(x,z)
			var bank=absf(x-stream)
			var id=V.cell_at(p)
			var weight=0.0
			var sum=0.0
			if id>=0:
				for d in range(-1,6):
					var n=id if d<0 else V.nb(id,d)
					if n<0: continue
					var factor=pow(maxf(0.0,1.0-V.center(n).distance_to(p)/3.10),2)
					sum+=factor
					if wet.has(n) or V.tier(n)<0: weight+=factor
			var mask=weight/maxf(sum,0.0001)
			if id>=0 and V.tier(id)>=0 and not wet.has(id):
				mask*=smoothstep(0.82,1.40,V.center(id).distance_to(p))
			mask=maxf(mask,1.0-smoothstep(V.breadth(z),V.breadth(z)+1.05,bank))
			points.append(Vector3(x,0,z))
			masks.append(Color(mask,0,0))
	for j in rows-1:
		for i in width-1:
			var index=j*width+i
			for face in [[index,index+1,index+width],[index+1,index+width+1,index+width]]:
				var a=face[0];var b=face[1];var c=face[2]
				geo.gradient_triangle(points[a],points[b],points[c],masks[a],masks[b],masks[c],Vector3.UP,Vector3.UP,Vector3.UP)
	flood_surface=_replace(flood_surface,geo,flood_material)
	flood_surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func refresh(force: bool=false):
	if force or rev!=sim.s.rev:
		var g=G.new()
		for id in sim.s.cells.size(): L.site(g,id,sim.s.cells[id],sim.s.turn%4,sim.s.sick)
		for edge in sim.s.edges.values(): L.dike(g,edge)
		dynamic_sites=_replace(dynamic_sites,g,solid)
		rev=sim.s.rev
	var state="%s/%s/%d/%d/%s" % [risk,sim.s.water,sim.s.rev,sim.s.turn,menu_mode]
	if sim.s.flood_time>0 and (flood_key!=str(sim.s.flood_cells) or not is_instance_valid(flood_surface)):
		_flood_surface()
		flood_key=str(sim.s.flood_cells)
	if is_instance_valid(flood_surface): flood_surface.visible=not menu_mode and sim.s.flood_time>0
	if force or overlay_stamp!=state:
		overlay_stamp=state
		var g=G.new()
		if not menu_mode:
			var predicted=sim.flood_map() if risk=="flood" else []
			for i in sim.s.cells.size():
				var c=sim.s.cells[i]
				if risk=="flood" and sim.s.flood_time==0 and predicted.has(i): _tile(g,i,Color(0.87,0.56,0.25,0.40),0.12)
				elif risk=="soil" and c.kind=="farm": _tile(g,i,Color(0.84,0.43,0.19,clampf((95-c.soil)/88.0,0.16,0.79)),0.15)
				elif risk=="water" and (V.tier(i)<1 or c.kind=="farm"):
					var amount=sim.s.water[V.reach(i)]/40.0
					_tile(g,i,Color(0.82,0.49,0.22,clampf(amount,0.12,0.68)),0.45 if V.tier(i)<0 else 0.14)
		cover=_replace(cover,g,overlay_material)
	var mark_state="%d/%d/%s/%d/%d/%s/%d/%s" % [hover,selected,build_tool,edge_shift,sim.s.rev,menu_mode,sim.s.food,sim.s.tech]
	if force or stamp!=mark_state:
		stamp=mark_state
		update_mark()
	menu_farms.visible=menu_mode
	grid_node.visible=not menu_mode and build_tool!=""
	target_atmosphere=1.0 if sim.s.flood_time>0 or sim.s.pending in ["flood","rain"] else (0.28 if sim.s.sick else 0.0)
	if not menu_mode and sim.s.flood_at<0 and sim.s.policy.has("flood"):
		target_atmosphere=0.53+0.43*float(sim.s.clock)/Sim.SEASON_TIME
	if not menu_mode and not sim.s.rain and sim.s.policy.has("rain"):
		target_atmosphere=0.67

func update_mark():
	var g=G.new()
	var preview=G.new()
	if not menu_mode:
		if selected>=0: _ring(g,selected,Color("#fff0ab"),0.078)
		if hover>=0:
			edge_dir=posmod(V.intake(hover)+edge_shift,6)
			var valid=build_tool=="" or sim.build_reason(build_tool,hover,edge_dir)==""
			var col=Color("#f0d68a") if build_tool=="" else (Color("#b8e0ad") if valid else Color("#ed9271"))
			_ring(g,hover,col,0.052)
			if build_tool!="":
				_tile(g,hover,Color(col.r,col.g,col.b,0.31),0.10)
				if build_tool=="levee" and V.tier(hover)==0:
					_line(g,V.corner(hover,edge_dir),V.corner(hover,edge_dir+1),0.20,col,0.24)
					if valid:
						for id in sim.protected_by(hover,edge_dir): _tile(g,id,Color(0.44,0.82,0.71,0.34),0.135)
						L.dike(preview,{"a":hover,"dir":edge_dir,"built":true})
				elif valid:
					var c=sim.s.cells[hover].duplicate()
					if build_tool in ["terrace","ditch"]: c[build_tool]=true
					else: c.kind=build_tool
					L.site(preview,hover,c,0,false)
	marks=_replace(marks,g,overlay_material)
	for i in preview.colors.size(): preview.colors[i]=Color(0.67,0.96,0.72,0.56)
	ghost=_replace(ghost,preview,overlay_material)

func _update_camera():
	var target=Vector3(camera_point.x,0.55,camera_point.y)
	camera.position=target+Vector3(10.8,21.4,25.8)
	camera.look_at(target)
	camera.size=zoom

func advance_frame(dt: float,alpha: float):
	camera_point=camera_point.lerp(destination,1.0-exp(-dt*7))
	zoom=lerpf(zoom,target_zoom,1.0-exp(-dt*8))
	_update_camera()
	atmosphere=lerpf(atmosphere,target_atmosphere,1.0-exp(-dt*1.9))
	sun.light_color=Color("#fff0d8").lerp(Color("#b5c9ce"),atmosphere)
	sun.light_energy=lerpf(0.83,0.57,atmosphere)
	env.fog_light_color=Color("#b6b59d").lerp(Color("#92a49e"),atmosphere)
	water_material.set_shader_parameter("alarm",atmosphere)
	var level=0.0
	if not menu_mode and sim.s.flood_at<0 and sim.s.policy.has("flood"):
		level=0.24*(float(sim.s.clock)+alpha)/Sim.SEASON_TIME
	elif not menu_mode and sim.s.flood_time>0:
		level=0.24*clampf((float(sim.s.flood_time)-alpha)/8.0,0,1)
	water_material.set_shader_parameter("river_level",level)
	earth.set_shader_parameter("season_tint",[Vector3(0.95,1.03,0.95),Vector3(0.94,1.02,0.92),Vector3(1.045,0.99,0.90),Vector3(0.97,0.93,0.90)][sim.s.turn%4])
	water_material.set_shader_parameter("reach_pollution",Vector3(sim.s.water[0],sim.s.water[1],sim.s.water[2])/50.0)
	var t=float(sim.s.time)+alpha
	if menu_mode: t=Time.get_ticks_msec()/1000.0
	water_material.set_shader_parameter("sim_time",t)
	if sim.s.flood_time>0:
		var remaining=float(sim.s.flood_time)-alpha
		flood_material.set_shader_parameter("stage",minf(clampf((37.0-remaining)/6.0,0.02,1.0),clampf(remaining/8,0.02,1.0)))
		flood_material.set_shader_parameter("river_time",t)
	for i in people.size():
		var w=sim.s.workers[i]
		var p=sim.worker_point(i,alpha)
		var walk=w.travel>0
		var step=t*(7.0 if walk else 2.4)+i
		if not walk:
			var drift=0.23 if w.job!="" else 0.11
			p+=Vector2(cos(step*0.35),sin(step*0.35))*drift
		var ground=V.ground(p.x,p.y)
		for z in [-3.5,4.8]:
			if absf(p.y-z)<0.29 and absf(p.x-V.river(z))<V.breadth(z)+1.80: ground=maxf(0.515,ground)
		var node=people[i]
		node.position=Vector3(p.x,ground+absf(sin(step))*(0.06 if walk else 0.014),p.y)
		node.rotation.z=0.065*sin(step)
		if walk: node.rotation.y=atan2(w.to.x-w.from.x,w.to.y-w.from.y)

func pick(screen_pos: Vector2) -> int:
	var origin=camera.project_ray_origin(screen_pos)
	var dir=camera.project_ray_normal(screen_pos)
	if absf(dir.y)<0.01: return -1
	var y=0.4
	var pos=origin
	for k in 5:
		pos=origin+dir*((y-origin.y)/dir.y)
		y=V.ground(pos.x,pos.z)
	return V.cell_at(Vector2(pos.x,pos.z))

func focus(id: int):
	if id<0: return
	destination=V.center(id)*0.74
	target_zoom=clampf(target_zoom,12.0,18.0)

func pan(delta: Vector2):
	var right=Vector2(camera.global_basis.x.x,camera.global_basis.x.z)
	var down=Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
	destination+=right*delta.x+down*delta.y
	destination=destination.clamp(Vector2(-13,-10),Vector2(13,10))

func wheel(direction: int):
	target_zoom=clampf(target_zoom+direction*1.55,9.0,28.0)

func set_menu(value: bool):
	menu_mode=value
	hover=-1
	selected=-1
	risk=""
	build_tool=""
	destination=Vector2(0.3,0.4) if value else Vector2(-1.4,0)
	target_zoom=15.2 if value else 19.5
	refresh(true)
