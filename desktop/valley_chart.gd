extends Control

const V=preload("res://valley.gd")
const U=preload("res://paper.gd")
const F=preload("res://frontier.gd")
var game
var last_focus=Vector2.INF

func _ready():
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	tooltip_text="点击舆图定位地块。暗色为待开通圩区，金色为聚落设施。"

func _process(_dt):
	if game and last_focus.distance_squared_to(game.world.camera_point)>0.015:
		last_focus=game.world.camera_point
		queue_redraw()

func field() -> Rect2:
	return Rect2(7,22,size.x-14,size.y-29)

func chart_point(p: Vector2) -> Vector2:
	return field().position+(p+Vector2(21,14))/Vector2(42,28)*field().size

func _draw():
	if not game: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("#172b2c"))
	draw_rect(Rect2(Vector2.ZERO,size),U.LINE,false,1)
	draw_string(get_theme_default_font(),Vector2(8,16),"河谷舆图",HORIZONTAL_ALIGNMENT_LEFT,-1,12,U.GOLD)
	draw_string(get_theme_default_font(),Vector2(size.x-46,16),"%d / 4" % game.sim.s.districts.size(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,U.DIM)
	for id in game.sim.s.cells.size():
		var hue=[Color("#759688"),Color("#8caa89"),Color("#b5b591"),Color("#a69d79")][V.tier(id)+1]
		if not game.sim.s.districts.has(V.sector(id)): hue=hue.darkened(0.45)
		var corners=PackedVector2Array()
		for k in 6: corners.append(chart_point(V.corner(id,k,1.025)))
		draw_colored_polygon(corners,hue)
	var water=PackedVector2Array()
	for direction in [1,-1]:
		for j in 33:
			var z=(-14.0+j*28.0/32.0)*direction
			water.append(chart_point(Vector2(V.river(z)+direction*V.breadth(z),z)))
	draw_colored_polygon(water,Color("#507e81"))
	for id in game.sim.s.cells.size():
		var c=game.sim.s.cells[id]
		var point=chart_point(V.center(id))
		if c.kind in ["wood","stone"]:
			draw_circle(point,1.8,Color("#355d48") if c.kind=="wood" else Color("#d9d0b7"),true,-1,true)
		elif c.project!="" or (c.kind!="" and c.kind!="wild"):
			draw_rect(Rect2(point-Vector2(2,1.6),Vector2(4,3.2)),U.GOLD)
	var s=game.sim.s
	for pair in s.frontier.roads.values():
		var points=PackedVector2Array()
		for p in F.route_points(s,pair[0],pair[1]): points.append(chart_point(p))
		draw_polyline(points,Color("#e6c78c"),1.25,true)
	for z in s.frontier.posts:
		var base=chart_point(V.center(F.anchor(s,z)))
		draw_circle(base,3,Color("#d48c68"))
	for j in s.frontier.missions:
		var point=chart_point(F.journey_point(j,s.time))
		draw_circle(point,2.7,Color("#f8edac") if j.kind=="survey" else Color("#91dbe6"))
	draw_arc(chart_point(game.world.camera_point),6,0,TAU,24,Color.WHITE,1.6,true)

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var f=field()
		if not f.has_point(event.position): return
		var uv=(event.position-f.position)/f.size
		var id=V.cell_at(uv*Vector2(42,28)-Vector2(21,14))
		if id>=0:
			game.command("jump",id)
			accept_event()
