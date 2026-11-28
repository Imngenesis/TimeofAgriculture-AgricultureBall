extends RefCounted

const U = preload("res://paper.gd")
const PAPER = Color("#eee4ca")
const INK = Color("#233b33")
const MUTED = Color("#4b6254")
const OCHRE = Color("#80521f")
const JADE = Color("#24655b")
const NIGHT = Color("#142c2a")
const TRACKS = {"育种":Color("#b8d094"),"耕作":Color("#e4bd7b"),"防灾":Color("#8bc8c9"),"经济":Color("#d6aa92")}

static func block(parent: Control, fill: Color, pad: int, gap: int = 6) -> VBoxContainer:
 var panel = PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var surface = U.style(fill,fill.darkened(0.12),1,4)
 surface.content_margin_left = pad; surface.content_margin_right = pad
 surface.content_margin_top = pad; surface.content_margin_bottom = pad
 panel.add_theme_stylebox_override("panel",surface)
 parent.add_child(panel)
 var stack = U.box(true,gap)
 panel.add_child(stack)
 return stack

static func tab(h, title: String, cmd: String, arg, active: bool, accent: Color) -> Button:
 var b = h.btn(title,cmd,arg)
 var face = U.style(Color("#354b40") if active else NIGHT, Color.TRANSPARENT,0,2)
 face.content_margin_left = 12; face.content_margin_right = 12
 face.content_margin_top = 4; face.content_margin_bottom = 5
 if active:
  face.border_width_bottom = 3; face.border_color = accent
 b.add_theme_stylebox_override("normal",face)
 b.add_theme_color_override("font_color",accent if active else U.DIM)
 return b

static func stamp(value: String, fill: Color, ink: Color) -> Label:
 var word = U.label(value,13,ink)
 var surface = U.style(fill,Color.TRANSPARENT,0,3)
 surface.content_margin_left = 7; surface.content_margin_right = 7
 surface.content_margin_top = 3; surface.content_margin_bottom = 3
 word.add_theme_stylebox_override("normal",surface)
 word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 return word
