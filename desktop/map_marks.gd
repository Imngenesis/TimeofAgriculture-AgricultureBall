extends Control

const V=preload("res://valley.gd")
const S=preload("res://simulation.gd")
var game
var face: Font
var anim=0.0

func _process(dt):
	if not game or not game.playing: return
	if not game.paused: anim+=dt*game.speed
	queue_redraw()

func _draw():
	if not game or not game.playing: return
	var w=game.world
	var s=game.sim.s
	if w.atmosphere>0.15:
		var clock=anim+0.1
		for i in 80:
			var x=fposmod(i*61.7+sin(i*1.3)*117.0-clock*74,size.x)
			var y=fposmod(i*83.9+clock*(189+i%5*23),size.y)
			draw_line(Vector2(x,y),Vector2(x-2.8,y+8.3),Color(0.83,0.88,0.84,0.17*w.atmosphere),0.9,true)
	if w.build_tool!="" or game.dialog_key!="": return
	var marked=[s.frontier.home,S.WILD[0]]
	if s.era>0: marked=[s.frontier.home]
	if w.selected>=0 and not marked.has(w.selected): marked.append(w.selected)
	for id in game.hud.staff_alerts:
		if not marked.has(id): marked.append(id)
	for id in marked:
		var p=w.camera.unproject_position(V.v3(V.center(id),1.12 if id==s.frontier.home else 0.79))
		if not Rect2(12,74,size.x-24,size.y-155).has_point(p): continue
		var name=game.sim.location_name(id)
		if w.selected==id and game.edge_job!="": name="田堤"
		var short_hands=game.hud.staff_alerts.has(id)
		if short_hands: name=game.sim.job_label(game.hud.staff_alerts[id])+" · 缺工"
		var width=face.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+17
		var box=Rect2(Vector2(p.x-width/2,p.y-24),Vector2(width,20))
		draw_line(Vector2(p.x,p.y-4),p+Vector2(0,3),Color("#cfbc82"),1,true)
		draw_rect(box,Color("#743f2e") if short_hands else Color(0.055,0.12,0.12,0.89))
		draw_line(box.position,box.position+Vector2(width,0),Color(0.83,0.73,0.48,0.74),1)
		draw_string(face,box.position+Vector2(8,15),name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("#efe4c9"))
