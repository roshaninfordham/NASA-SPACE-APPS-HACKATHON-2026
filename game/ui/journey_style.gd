extends RefCounted
## Shared native UI tokens adapted from the supplied KŌMAKU kit.
## Fonts are local, licensed assets; no network font or platform fallback dependency.
const FLOOR := Color("0b141b")
const GLASS := Color("0e1b24")
const RAISED := Color("14283a")
const PEARL := Color("fbf1ee")
const MUTED := Color("9cc3cc")
const CYAN := Color("4fe8f5")
const ROSE := Color("ff5c74")
const AMBER := Color("ffb547")
const CRIMSON := Color("b01030")
const DEEP_CRIMSON := Color("7d0a22")
const CORAL := Color("ff6b80")
const INK := Color("2a1218")
const BLUSH := Color("f3e1dd")
const DISPLAY_FONT = preload("res://assets/fonts/journey/Jost-Variable.ttf")
const BODY_FONT = preload("res://assets/fonts/journey/IBMPlexSans-Variable.ttf")
const MONO_FONT = preload("res://assets/fonts/journey/IBMPlexMono-Regular.ttf")
static var _bold_fonts: Dictionary = {}

static func color(token: String) -> Color:
	return {"floor":FLOOR,"glass":GLASS,"raised":RAISED,"pearl":PEARL,
		"muted":MUTED,"cyan":CYAN,"rose":ROSE,"amber":AMBER,
		"crimson":CRIMSON,"deep_crimson":DEEP_CRIMSON,"coral":CORAL,
		"ink":INK,"blush":BLUSH}.get(token, PEARL)

static func font(face: String = "body") -> Font:
	if face in ["display_bold", "body_bold"]:
		if not _bold_fonts.has(face):
			var bold := FontVariation.new()
			bold.base_font = DISPLAY_FONT if face == "display_bold" else BODY_FONT
			bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650.0}
			_bold_fonts[face] = bold
		return _bold_fonts[face]
	if face == "display": return DISPLAY_FONT
	if face == "mono": return MONO_FONT
	return BODY_FONT

static func panel(raised: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = RAISED if raised else GLASS
	style.border_color = Color(PEARL, 0.10)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

static func button_style(primary: bool, state: String) -> StyleBoxFlat:
	var style := panel()
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.bg_color = CRIMSON if primary else GLASS
	style.border_color = ROSE if primary else Color(PEARL, 0.18)
	if state == "hover":
		style.bg_color = DEEP_CRIMSON if primary else RAISED
		style.border_color = ROSE if primary else CYAN
	elif state == "pressed":
		style.bg_color = DEEP_CRIMSON if primary else Color("183a47")
		style.set_border_width_all(2)
	elif state == "disabled":
		style.bg_color = Color(GLASS, 0.85)
		style.border_color = Color(MUTED, 0.28)
	return style

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font = BODY_FONT
	result.default_font_size = 18
	result.set_color("font_color", "Label", PEARL)
	result.set_color("default_color", "RichTextLabel", PEARL)
	result.set_font("normal_font", "RichTextLabel", BODY_FONT)
	result.set_font("mono_font", "RichTextLabel", MONO_FONT)
	result.set_color("font_color", "Button", PEARL)
	result.set_color("font_hover_color", "Button", PEARL)
	result.set_color("font_pressed_color", "Button", PEARL)
	result.set_color("font_focus_color", "Button", PEARL)
	result.set_color("font_disabled_color", "Button", MUTED)
	result.set_font("font", "Button", font("display_bold"))
	result.set_font_size("font_size", "Button", 18)
	for state in ["normal", "hover", "pressed", "disabled"]:
		result.set_stylebox(state, "Button", button_style(false, state))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = CYAN
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(16)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("panel", "PanelContainer", panel())
	var progress_track := panel()
	progress_track.bg_color = RAISED
	progress_track.set_corner_radius_all(8)
	progress_track.set_border_width_all(0)
	progress_track.content_margin_left = 0
	progress_track.content_margin_right = 0
	progress_track.content_margin_top = 0
	progress_track.content_margin_bottom = 0
	var progress_fill := progress_track.duplicate() as StyleBoxFlat
	progress_fill.bg_color = CYAN
	result.set_stylebox("background", "ProgressBar", progress_track)
	result.set_stylebox("fill", "ProgressBar", progress_fill)
	var scroll_track := progress_track.duplicate() as StyleBoxFlat
	scroll_track.bg_color = Color(GLASS,0.72)
	scroll_track.content_margin_top = 4
	scroll_track.content_margin_bottom = 4
	var scroll_grab := scroll_track.duplicate() as StyleBoxFlat
	scroll_grab.bg_color = Color(CYAN,0.62)
	result.set_stylebox("scroll", "HScrollBar", scroll_track)
	for state in ["grabber","grabber_highlight","grabber_pressed"]:
		result.set_stylebox(state, "HScrollBar", scroll_grab)
	return result

static func label(value: String, text_size: int = 18, tint: Color = PEARL, face: String = "body") -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_override("font", font(face))
	result.add_theme_font_size_override("font_size", text_size)
	result.add_theme_color_override("font_color", tint)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func button(value: String, primary: bool = false) -> Button:
	var result := Button.new()
	result.theme = theme()
	result.text = value
	result.custom_minimum_size = Vector2(48, 48)
	result.focus_mode = Control.FOCUS_ALL
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled"]:
		result.add_theme_stylebox_override(state, button_style(primary, state))
	return result
