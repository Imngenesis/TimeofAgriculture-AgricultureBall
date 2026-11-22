extends Control

var symbol = "grain"
var tint = Color("#e2cc91")

func _draw():
 var side = minf(size.x, size.y)
 var p = (size - Vector2.ONE * side) / 2.0
 draw_set_transform(p, 0, Vector2.ONE * side / 32.0)
 var c = tint
 match symbol:
  "materials":
   for k in 3:
    var a = Vector2(6 + k * 3, 23 - k * 5)
    draw_line(a, a + Vector2(12, -5), c, 2, true)
    draw_arc(a, 2.5, 0, TAU, 12, c, 1.2, true)
   stroke([Vector2(18, 21), Vector2(22, 16), Vector2(28, 18), Vector2(30, 25), Vector2(20, 26), Vector2(18, 21)], c)
  "balance":
   stroke([Vector2(4, 26), Vector2(28, 26)], c)
   for k in 3:
    var h = 7 + k * 5
    draw_rect(Rect2(6 + k * 7, 24 - h, 4, h), c, false, 1.5)
  "seal":
   draw_arc(Vector2(16, 16), 14, 0, TAU, 56, c, 0.9, true)
   draw_arc(Vector2(16, 16), 11.7, 0.13, 3.01, 26, c, 0.7, true)
   stroke([Vector2(7, 20), Vector2(15, 11), Vector2(20, 16), Vector2(25, 13)], c, 1.35)
   stroke([Vector2(8, 23), Vector2(15, 20), Vector2(19, 21), Vector2(25, 18)], c, 1.15)
   draw_circle(Vector2(21, 9), 2, c)
  "grain", "seed":
   stroke([Vector2(8, 27), Vector2(20, 11), Vector2(23, 5)], c, 1.4)
   for k in 3:
    var o = Vector2(12 + k * 3, 21 - k * 4)
    draw_colored_polygon(PackedVector2Array([o, o + Vector2(-4, -2), o + Vector2(-4, -6), o + Vector2(-1, -4)]), c)
    draw_colored_polygon(PackedVector2Array([o + Vector2(1, 0), o + Vector2(6, -1), o + Vector2(8, -5), o + Vector2(3, -4)]), c)
  "crew":
   draw_arc(Vector2(15, 10), 3.8, 0, TAU, 22, c, 1.4, true)
   stroke([Vector2(6, 25), Vector2(8, 19), Vector2(12, 16), Vector2(18, 16), Vector2(22, 19), Vector2(24, 25)], c)
   draw_arc(Vector2(23, 12), 3.2, -1.6, 1.7, 12, c, 1.2, true)
   stroke([Vector2(24, 18), Vector2(27, 20), Vector2(28, 25)], c, 1.2)
  "build":
   stroke([Vector2(3, 16), Vector2(15, 6), Vector2(28, 16)], c, 1.8)
   stroke([Vector2(7, 14), Vector2(7, 26), Vector2(24, 26), Vector2(24, 14)], c)
   stroke([Vector2(13, 26), Vector2(13, 18), Vector2(18, 18), Vector2(18, 26)], c)
  "study":
   stroke([Vector2(3, 7), Vector2(9, 7), Vector2(16, 10), Vector2(23, 7), Vector2(29, 7), Vector2(29, 24), Vector2(23, 24), Vector2(16, 27), Vector2(9, 24), Vector2(3, 24), Vector2(3, 7)], c)
   stroke([Vector2(16, 10), Vector2(16, 26)], c)
  "risk":
   for j in 3:
    var a = PackedVector2Array()
    for x in 13: a.append(Vector2(3 + x * 2.15, 10 + j * 6 + 2 * sin(x * 0.65)))
    draw_polyline(a, c, 1.4, true)
  "log":
   stroke([Vector2(7, 4), Vector2(25, 4), Vector2(25, 28), Vector2(7, 28), Vector2(7, 4)], c)
   for j in 3: draw_line(Vector2(11, 11 + j * 5), Vector2(21, 11 + j * 5), c, 1, true)
  "sun":
   draw_arc(Vector2(16, 16), 5.1, 0, TAU, 26, c, 1.45, true)
   for j in 8:
    var u = Vector2.from_angle(j * TAU / 8)
    draw_line(Vector2(16, 16) + u * 8, Vector2(16, 16) + u * 11, c, 1.3, true)
  "compass":
   draw_arc(Vector2(16, 17), 11, 0, TAU, 40, c, 0.8, true)
   draw_colored_polygon(PackedVector2Array([Vector2(16, 3), Vector2(12.5, 20), Vector2(16, 17), Vector2(19.5, 20)]), c)
  "pin":
   draw_arc(Vector2(16, 12), 6, 0, TAU, 32, c, 1.6, true)
   stroke([Vector2(11, 16), Vector2(16, 25), Vector2(21, 16)], c)

func stroke(points: Array, c: Color, weight: float = 1.5):
 draw_polyline(PackedVector2Array(points), c, weight, true)
