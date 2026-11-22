extends Control

var season = 0
var fraction = 0.0
var alarm = false

func _draw():
 var p = size * 0.5
 var r = minf(size.x, size.y) * 0.45
 var ink = Color("#e6cb89") if not alarm else Color("#efab75")
 draw_circle(p, r, Color("#2a352d"), true, -1, true)
 draw_arc(p, r, 0, TAU, 54, Color("#807c5c"), 0.85, true)
 for j in 24:
  var ray = Vector2.from_angle(j * TAU / 24 - PI / 2)
  draw_line(p + ray * (r - (4.1 if j % 6 == 0 else 2.2)), p + ray * (r - 0.9), ink if j % 6 == 0 else Color("#928d6d"), 0.9, true)
 var a = - PI / 2 + season * PI / 2
 draw_arc(p, r - 4.8, a, a + maxf(0.04, fraction) * PI / 2, 16, ink, 2.1, true)
 draw_arc(p, r * 0.25, 0, TAU, 22, ink, 1.25, true)
 for i in 8:
  var ray = Vector2.from_angle(TAU * i / 8)
  draw_line(p + ray * r * 0.34, p + ray * r * 0.49, ink, 1.05, true)
