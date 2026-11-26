extends RefCounted

const Ink = preload("res://ink.gd")
const BG = Color("#202b26")
const DEEP = Color("#19231f")
const PANEL = Color(0.051, 0.113, 0.105, 0.985)
const LINE = Color("#627b70")
const GOLD = Color("#ebc78a")
const TEXT = Color("#f0e9d6")
const DIM = Color("#c1cabc")
const GREEN = Color("#a7c89a")
const WARN = Color("#f1a477")

static func style(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 1) -> StyleBoxFlat:
 var s = StyleBoxFlat.new()
 s.bg_color = bg
 s.set_border_width_all(width)
 s.border_color = border
 s.set_corner_radius_all(radius)
 return s

static func font(heading: bool = false) -> Font:
 if OS.has_feature("web"): return preload("res://art/fonts/NotoSansSC-Medium.otf")
 var f = SystemFont.new()
 f.font_names = PackedStringArray(["STZhongsong", "SimSun", "Microsoft YaHei", "Noto Serif CJK SC"]) if heading else PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "DengXian", "Noto Sans CJK SC"])
 f.font_weight = 500 if heading else 400
 return f

static func theme() -> Theme:
 var t = Theme.new()
 t.default_font = font()
 t.default_font_size = 16
 t.set_color("font_color", "Label", TEXT)
 t.set_color("font_color", "Button", TEXT)
 t.set_color("font_hover_color", "Button", Color.WHITE)
 t.set_color("font_disabled_color", "Button", Color("#949681"))
 for pair in[["normal", style(Color("#303c31"), Color("#696b53"), 1, 2)], ["hover", style(Color("#465244"), GOLD, 1, 2)], ["pressed", style(Color("#505643"), GOLD, 1, 2)], ["disabled", style(Color("#293329"), Color("#505646"), 1, 2)], ["focus", style(Color.TRANSPARENT, Color("#f3d59d"), 2, 3)]]:
  var st = pair[1]
  if st is StyleBoxFlat:
   st.content_margin_left = 9; st.content_margin_right = 9; st.content_margin_top = 4; st.content_margin_bottom = 4
  t.set_stylebox(pair[0], "Button", st)
 return t

# Keep numbers and their units in the same line of wrapped prose.
static var quantity_span: RegEx = RegEx.create_from_string(
 r"(?:(?:距今|公元前?)[ \t]*)?(?:大?约[ \t]*)?[0-9]+(?:\.[0-9]+)?[ \t]*(?:[万千亿][ \t]*)?(?:[至到–—～~-][ \t]*[0-9]+(?:\.[0-9]+)?[ \t]*(?:[万千亿][ \t]*)?)?(?:世纪[初末]?|年前后|年前|年|月|日|人秒|秒|分钟|小时|季|天|份|亩|公顷|公里|格|点|人|粮|种|木|石)"
)

static func wrap_text(value: String) -> String:
 var quantities := quantity_span.search_all(value)
 # Work right to left so each match keeps its original offsets.
 for i in range(quantities.size() - 1, -1, -1):
  var quantity := quantities[i]
  var words := quantity.get_string().replace(" ", "\u00a0").replace("\t", "\u00a0")
  var joined := "\u2060".join(words.split(""))
  value = value.substr(0, quantity.get_start()) + joined + value.substr(quantity.get_end())
 return value

static func label(value: String, px: int = 16, color: Color = TEXT, wrap: bool = false) -> Label:
 var l = Label.new()
 l.text = wrap_text(value) if wrap else value
 if wrap: l.language = "zh"
 l.add_theme_color_override("font_color", color)
 l.add_theme_font_size_override("font_size", px)
 l.add_theme_constant_override("line_spacing", 3)
 if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 l.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return l

static func box(vertical: bool = true, gap: int = 6) -> BoxContainer:
 var b: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
 b.add_theme_constant_override("separation", gap)
 return b

static func panel(parent: Control, l: float, t: float, r: float, b: float, m: Rect2i, bg: Color = PANEL) -> PanelContainer:
 var p = PanelContainer.new()
 var surface = style(bg, LINE, 1, 5)
 surface.shadow_color = Color(0.02, 0.06, 0.06, 0.34)
 surface.shadow_size = 4
 surface.shadow_offset = Vector2(0, 2)
 p.add_theme_stylebox_override("panel", surface)
 parent.add_child(p)
 rect(p, l, t, r, b, m)
 return p

static func metric(row: Control, caption: String, number: String, tone: Color = GOLD):
 var tile = PanelContainer.new()
 var surface = style(Color("#233c39"), tone.darkened(0.48), 0, 3)
 surface.border_width_left = 3
 tile.add_theme_stylebox_override("panel", surface)
 tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(tile)
 var words = box(true, 0)
 inset(tile, 7).add_child(words)
 words.add_child(label(caption, 12, DIM)); words.add_child(label(number, 20, tone))

static func rect(c: Control, l: float, t: float, r: float, b: float, offsets: Rect2i):
 c.set_anchor(SIDE_LEFT, l); c.set_anchor(SIDE_TOP, t)
 c.set_anchor(SIDE_RIGHT, r); c.set_anchor(SIDE_BOTTOM, b)
 c.offset_left = offsets.position.x; c.offset_top = offsets.position.y
 c.offset_right = offsets.size.x; c.offset_bottom = offsets.size.y

static func inset(p: Control, pad: int = 14) -> MarginContainer:
 var m = MarginContainer.new()
 for side in["left", "top", "right", "bottom"]: m.add_theme_constant_override("margin_" + side, pad)
 p.add_child(m)
 return m

static func icon(symbol: String, px: int = 23, col: Color = GOLD) -> Control:
 var g = Ink.new()
 g.symbol = symbol; g.tint = col
 g.mouse_filter = Control.MOUSE_FILTER_IGNORE
 g.custom_minimum_size = Vector2(px, px)
 g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 return g

static func rule() -> ColorRect:
 var bar = ColorRect.new()
 bar.color = Color(0.71, 0.67, 0.47, 0.34)
 bar.custom_minimum_size = Vector2(1, 1)
 bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return bar

static func space() -> Control:
 var spacer = Control.new()
 spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return spacer

static func button(value: String, fn: Callable, primary: bool = false) -> Button:
 var b = Button.new()
 b.text = value
 b.focus_mode = Control.FOCUS_NONE
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.custom_minimum_size.y = 32
 if primary:
  var normal = style(Color("#d8be81"), Color("#ead6a2"), 1, 2)
  normal.content_margin_left = 13; normal.content_margin_right = 13; normal.content_margin_top = 3; normal.content_margin_bottom = 3
  b.add_theme_stylebox_override("normal", normal)
  var hi = normal.duplicate()
  hi.bg_color = Color("#ecdaaa")
  b.add_theme_stylebox_override("hover", hi)
  b.add_theme_stylebox_override("pressed", hi)
  for key in["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(key, DEEP)
 b.pressed.connect(fn)
 return b
