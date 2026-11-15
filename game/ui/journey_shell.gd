extends Control
## Story, preparation and reflective debrief. No mission clock or health inference.
signal story_finished
signal ready_requested
signal retry_requested
signal home_requested
signal audio_cue(kind: String)
signal source_requested(url: String)
signal live_data_requested
signal preferences_requested
signal concept_visibility_changed(open: bool)
signal quiz_answered(record: Dictionary)

const Style = preload("res://ui/journey_style.gd")
const Branding = preload("res://scripts/branding.gd")
const Orb = preload("res://ui/concept_orb.gd")
const STORY_BACKGROUNDS := [
	"res://assets/art/journey/story-exterior.png",
	"res://assets/art/journey/story-astronaut.png",
	"res://assets/art/journey/story-interior.png",
]
const STORY := [
	{"eyebrow": "YEAR 2059", "title": "Planet Mars.", "body": "Your crew’s home needs power."},
	{"eyebrow": "A MESSAGE FROM OUTSIDE", "title": "Ren needs you.", "body": "Help Ren clear dust before the storm."},
	{"eyebrow": "YOUR FIRST MISSION", "title": "You set the pace.", "body": "Balance her effort. She steps inside at zero."},
]
var state := "story"
var catalog: Array = []
var reviewed_ids: Array[String] = []
var readiness := 0.0
var concept_open := false
var reduced_motion := false
var quiz_first_answer := -1
var _result: Dictionary = {}
var _built := false
var _body: Control
var _header: Control
var _footer: Control
var _title: Label
var _subtitle: Label
var _brand: Label
var _home: Button
var _settings: Button
var _ready_button: Button
var _live_sun_button: Button
var _progress: ProgressBar
var _progress_label: Label
var _orb_area: Control
var _orbs: Array[Button] = []
var _scroll: ScrollContainer
var _story_index := 0
var _story_brand: Label
var _story_brand_subtitle: Label
var _story_background: Texture2D
var _result_background: Texture2D
var _story_head: Label
var _story_words: Label
var _story_kicker: Label
var _story_step: StepDots
var _story_tween: Tween
var _story_next: Button
var _story_skip: Button
var _type_count := 0.0
var _cue_elapsed := 0.0
var _time := 0.0
var _dialog_layer: Control
var _dialog: PanelContainer
var _dialog_scroll: ScrollContainer
var _dialog_extra: Control
var _dialog_data: Control
var _dialog_more_button: Button
var _dialog_data_button: Button
var _dialog_done: Button
var _dialog_id := ""
var _previous_focus: WeakRef
var _debrief_content: VBoxContainer
var _debrief_summary: GridContainer
var _debrief_charts: GridContainer
var _debrief_quiz_feedback: Label
var _result_content: VBoxContainer
var _science_content: VBoxContainer
var _result_media: GridContainer
var _science_details: VBoxContainer
var _debrief_view := "results"
var _science_button: Button
var _equation_cards: Array[Control] = []
var _equation_grid: GridContainer
var _merge_time := 0.0
var _merge_done := false
var _merge_skip: Button
var _merge_note: Label
var _layout_queued := false
var _live_mode := false
var _live_return_label := "Back to mission"
var _previous_state := "preparation"
var _live_snapshot: Dictionary = {}

class StepDots extends Control:
	var step := 0
	func _draw() -> void:
		for index in range(3):
			var center := Vector2(7 + index * 25, size.y * 0.5)
			draw_circle(center, 5, Style.CYAN if index == step else Color(Style.PEARL, 0.20), true, -1.0, true)

class IdeaIcon extends Orb:
	## Reuse the same eight glyphs as the mission controls and science library.
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2.ZERO
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	func _draw() -> void:
		_draw_glyph(size * 0.5, minf(size.x, size.y) * 0.38, Style.CYAN)

class ConceptVisual extends Control:
	## Original teaching diagrams: qualitative relationships, not measured NASA plots.
	var concept_id := ""
	var motion_reduced := false
	var motion_phase := 0.0
	func set_reduced_motion(enabled: bool) -> void:
		motion_reduced = enabled
		if enabled: motion_phase = 0.0
		queue_redraw()
	func _process(delta: float) -> void:
		if motion_reduced or not is_visible_in_tree(): return
		motion_phase = fposmod(motion_phase + minf(delta, 0.1) * 0.28, 1.0)
		queue_redraw()
	static func caption(id: String) -> String:
		match id:
			"radiation": return "Particles carry energy. A detector measures what is absorbed."
			"dose": return "At the same rate, more time means more absorbed energy."
			"sievert": return "Health context needs more than the absorbed-energy number."
			"dust": return "Clearer panels let more sunlight reach the solar cells."
			"power": return "Power is the rate. Energy is what the battery stores."
			"time": return "Thirty mission minutes of cleaning, then an automatic step inside."
			"speed": return "Pace and tiredness together set the effective cleaning rate."
			"shelter": return "Shielding can reduce exposure. It does not erase radiation."
		return "A picture of how this idea works."
	func _arrow(a: Vector2, b: Vector2, tint: Color) -> void:
		draw_line(a, b, tint, 2, true)
		var direction := (b-a).normalized()
		var sideways := Vector2(-direction.y, direction.x)
		draw_polyline(PackedVector2Array([b-direction*7+sideways*4,b,b-direction*7-sideways*4]), tint, 2, true)
	func _word(value: String, center: Vector2, tint: Color, pixels := 14) -> void:
		var face := Style.font("mono")
		var width := face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
		draw_string(face, center-Vector2(width*0.5,0), value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, tint)
	func _panel(center: Vector2, dusty: bool) -> void:
		var box := Rect2(center-Vector2(43,26),Vector2(86,52))
		draw_rect(box, Color(Style.CYAN,0.08))
		draw_rect(box, Style.CYAN, false, 1.4)
		for index in range(1,4): draw_line(box.position+Vector2(index*21.5,0),box.position+Vector2(index*21.5,52),Color(Style.CYAN,0.35),1)
		draw_line(box.position+Vector2(0,26),box.position+Vector2(86,26),Color(Style.CYAN,0.35),1)
		if dusty:
			for index in range(22): draw_circle(box.position+Vector2(6+fposmod(index*17.3,74),5+fposmod(index*11.7,42)),2.5,Style.AMBER)
	func _draw() -> void:
		var left := Vector2(size.x*0.2,42)
		var right := Vector2(size.x*0.8,42)
		var center := Vector2(size.x*0.5,42)
		var cyan := Style.CYAN
		var amber := Style.AMBER
		if not motion_reduced and concept_id in ["radiation", "dust", "power", "time", "speed", "dose"]:
			var moving := Vector2(lerpf(size.x * 0.36, size.x * 0.64, motion_phase), 6)
			draw_line(Vector2(size.x * 0.36, 6), Vector2(size.x * 0.64, 6), Color(cyan, 0.16), 2, true)
			draw_circle(moving, 3.5, Color(cyan, 0.9), true, -1.0, true)
		match concept_id:
			"radiation":
				for index in range(7):
					var point := left+Vector2(fposmod(index*17.2,38)-19,index*8-24)
					draw_circle(point,3,amber)
				_arrow(left+Vector2(35,0),right-Vector2(35,0),cyan)
				draw_rect(Rect2(right-Vector2(23,30),Vector2(46,60)),Color(cyan,0.12))
				draw_rect(Rect2(right-Vector2(23,30),Vector2(46,60)),cyan,false,2)
				_word("PARTICLES",left+Vector2(0,47),Style.MUTED)
				_word("DETECTOR",right+Vector2(0,47),Style.MUTED)
			"dose":
				for index in range(3):
					var x := size.x*(0.22+index*0.28)
					var level := 14.0+index*17.0
					draw_rect(Rect2(x-18,64-level,36,level),Color(cyan,0.5))
					draw_line(Vector2(x-22,64),Vector2(x+22,64),cyan,2)
					_word(["LESS TIME","MORE TIME","MORE DOSE"][index],Vector2(x,89),Style.MUTED,14)
			"sievert":
				for index in range(3):
					var point := Vector2(size.x*(0.18+index*0.32),42)
					draw_circle(point,27,Color(cyan,0.08))
					draw_arc(point,27,0,TAU,40,cyan,1.5,true)
					_word(["ENERGY","TYPE","TISSUE"][index],point+Vector2(0,4),cyan,12)
					if index<2: _word("+",point+Vector2(size.x*0.16,4),Style.MUTED,16)
			"power":
				_panel(left,false)
				_arrow(center-Vector2(17,0),center+Vector2(17,0),cyan)
				var battery := Rect2(right-Vector2(32,22),Vector2(64,44))
				draw_rect(battery,cyan,false,2)
				draw_rect(Rect2(battery.position+Vector2(4,4),Vector2(35,36)),Color(cyan,0.45))
				draw_rect(Rect2(battery.end+Vector2(0,-29),Vector2(5,14)),cyan)
				_word("kW · RATE",left+Vector2(0,47),Style.MUTED,12)
				_word("kWh · STORED",right+Vector2(0,47),Style.MUTED,12)
			"dust":
				_panel(left,true)
				_panel(right,false)
				_arrow(center-Vector2(17,0),center+Vector2(17,0),cyan)
				_word("DUSTY",left+Vector2(0,47),Style.MUTED)
				_word("CLEARER",right+Vector2(0,47),Style.MUTED)
			"time":
				for index in range(3):
					var point := Vector2(size.x*(0.18+index*0.32),42)
					draw_circle(point,20,Color(cyan,0.10))
					draw_arc(point,20,0,TAU,40,cyan,1.5,true)
					_word(str(index+1),point+Vector2(0,6),cyan,18)
					_word(["START","CLEAN","INSIDE"][index],point+Vector2(0,47),Style.MUTED)
					if index<2: _arrow(point+Vector2(27,0),point+Vector2(size.x*0.32-27,0),cyan)
			"speed":
				var start := size.x * 0.26
				var span := size.x * 0.66
				_word("FRESH",Vector2(size.x * 0.12,29),Style.MUTED,12)
				_word("TIRED",Vector2(size.x * 0.12,64),Style.MUTED,12)
				draw_rect(Rect2(start,14,span,20),Color(cyan,0.68))
				draw_rect(Rect2(start,49,span * 0.35,20),Color(cyan,0.32))
				_word("SAME COMMAND · DIFFERENT RATE",center+Vector2(0,47),cyan,12)
			"shelter":
				draw_polyline(PackedVector2Array([center+Vector2(-38,-5),center+Vector2(0,-32),center+Vector2(38,-5),center+Vector2(27,-5),center+Vector2(27,28),center+Vector2(-27,28),center+Vector2(-27,-5),center+Vector2(-38,-5)]),cyan,2,true)
				for index in range(5):
					draw_circle(left+Vector2(index%2*12-6,index*10-20),3,amber)
				draw_circle(center+Vector2(5,8),2,Color(amber,0.5))
				_word("SHIELDING",center+Vector2(0,47),Style.MUTED)

class ResultVisual extends Control:
	## Original vector portrait and result diagram, not a screenshot of gameplay.
	## The dust area uses the completed run's exact fraction; art adds no score.
	var clean_fraction := 0.0
	var outcome := ""
	func _ready() -> void:
		clip_contents = true
		resized.connect(queue_redraw)
	func _ellipse(center: Vector2, radii: Vector2, ink: Color) -> void:
		var points := PackedVector2Array()
		for index in range(48):
			var angle := float(index) * TAU / 48.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radii)
		draw_colored_polygon(points, ink)
	func _shape(points: Array, ink: Color) -> void:
		draw_colored_polygon(PackedVector2Array(points), ink)
	func _spark(center: Vector2, radius: float, ink: Color) -> void:
		_shape([center + Vector2(0, -radius), center + Vector2(radius * 0.25, -radius * 0.25), center + Vector2(radius, 0), center + Vector2(radius * 0.25, radius * 0.25), center + Vector2(0, radius), center + Vector2(-radius * 0.25, radius * 0.25), center + Vector2(-radius, 0), center + Vector2(-radius * 0.25, -radius * 0.25)], ink)
	func _portrait(origin: Vector2, scale_value: float) -> void:
		draw_set_transform(origin, 0.0, Vector2.ONE * scale_value)
		var skin := Color("dba783")
		var hair := Color("312930")
		# Soft halo and a broad shoulder silhouette make a person readable before
		# decorative suit details. Nothing here denotes radiation or health.
		draw_circle(Vector2(0, -10), 77, Color(Style.CYAN, 0.045), true, -1, true)
		draw_arc(Vector2(0, -10), 72, PI * 0.83, PI * 2.18, 64, Color(Style.CYAN, 0.18), 1.2, true)
		_ellipse(Vector2(0, 79), Vector2(75, 15), Color("030b14", 0.55))
		_shape([Vector2(-66, 79), Vector2(-64, 54), Vector2(-52, 41), Vector2(-25, 34), Vector2(25, 34), Vector2(52, 41), Vector2(64, 54), Vector2(66, 79)], Style.PEARL.darkened(0.16))
		_ellipse(Vector2(-49, 55), Vector2(18, 23), Style.PEARL)
		_ellipse(Vector2(49, 55), Vector2(18, 23), Style.PEARL.darkened(0.08))
		_shape([Vector2(-30, 39), Vector2(30, 39), Vector2(38, 81), Vector2(-38, 81)], Color("efe2de"))
		_shape([Vector2(-30, 44), Vector2(-18, 46), Vector2(-11, 81), Vector2(-26, 81)], Style.DEEP_CRIMSON)
		_shape([Vector2(30, 44), Vector2(18, 46), Vector2(11, 81), Vector2(26, 81)], Style.DEEP_CRIMSON)
		for x in [-51.0, 51.0]:
			draw_line(Vector2(x - 8, 62), Vector2(x + 8, 62), Color("bca7a9"), 2.0, true)
		# Transparent-looking helmet keeps the face, hair and expression visible.
		draw_circle(Vector2(0, -17), 61, Color("506774"), true, -1, true)
		draw_circle(Vector2(0, -17), 58, Style.PEARL, true, -1, true)
		draw_circle(Vector2(0, -17), 54, Color("263b4b"), true, -1, true)
		draw_circle(Vector2(0, -17), 51, Color("345565"), true, -1, true)
		_ellipse(Vector2(0, -22), Vector2(34, 44), hair)
		_ellipse(Vector2(-28, -11), Vector2(6, 9), skin.darkened(0.10))
		_ellipse(Vector2(28, -11), Vector2(6, 9), skin.darkened(0.10))
		_ellipse(Vector2(0, -14), Vector2(28, 36), skin)
		_ellipse(Vector2(5, -10), Vector2(22, 29), Color("efc3a0"))
		_ellipse(Vector2(-16, -4), Vector2(7, 4), Color("c97573", 0.28))
		_ellipse(Vector2(17, -4), Vector2(7, 4), Color("c97573", 0.25))
		# A swept fringe, rather than a dark visor, gives Ren an identifiable face.
		_shape([Vector2(-32, -24), Vector2(-31, -46), Vector2(-16, -61), Vector2(11, -60), Vector2(31, -43), Vector2(30, -13), Vector2(22, -31), Vector2(16, -41), Vector2(7, -30), Vector2(-8, -32), Vector2(-18, -22), Vector2(-17, -38), Vector2(-25, -27), Vector2(-25, 4), Vector2(-31, -4)], hair)
		for x in [-10.0, 11.0]:
			draw_line(Vector2(x - 5, -25), Vector2(x + 4, -26), hair.lightened(0.10), 2.0, true)
			_ellipse(Vector2(x, -17), Vector2(4, 5), Color("302a32"))
			draw_circle(Vector2(x + 1, -19), 1.5, Style.PEARL, true, -1, true)
		draw_polyline(PackedVector2Array([Vector2(0, -13), Vector2(-2, -5), Vector2(2, -4)]), Color("bb806a"), 1.4, true)
		draw_arc(Vector2(0, 1), 9, PI * 0.13, PI * 0.87, 20, Color("8b4c51"), 2.0, true)
		draw_line(Vector2(-4, 7), Vector2(4, 7), Color("fbe8d4"), 1.2, true)
		# One small blossom echoes the suit's authored botanical motif.
		for index in range(5):
			var angle := float(index) * TAU / 5.0
			draw_circle(Vector2(26, -36) + Vector2(cos(angle), sin(angle)) * 4.0, 3.0, Color("f0b2b2"), true, -1, true)
		draw_circle(Vector2(26, -36), 1.8, Style.AMBER, true, -1, true)
		draw_arc(Vector2(0, -17), 50, PI * 1.07, PI * 1.61, 36, Color(Style.PEARL, 0.72), 2.8, true)
		draw_arc(Vector2(0, -17), 51, -0.53, 0.72, 28, Color(Style.CYAN, 0.45), 1.8, true)
		_shape([Vector2(15, -62), Vector2(26, -56), Vector2(-26, 16), Vector2(-32, 7)], Color(Style.PEARL, 0.07))
		for x in [-56.0, 56.0]:
			draw_circle(Vector2(x, -13), 10, Style.DEEP_CRIMSON, true, -1, true)
			draw_arc(Vector2(x, -13), 7, 0, TAU, 24, Color("e5b2aa"), 1.3, true)
		_ellipse(Vector2(0, 37), Vector2(37, 12), Color("27303d"))
		_ellipse(Vector2(0, 34), Vector2(36, 10), Style.PEARL)
		_ellipse(Vector2(0, 33), Vector2(29, 6), Style.DEEP_CRIMSON)
		draw_arc(Vector2(0, 32), 32, 0.10, PI - 0.10, 28, Style.ROSE, 2.0, true)
		draw_circle(Vector2(0, 63), 12, Color("d6c6c7"), true, -1, true)
		draw_circle(Vector2(0, 63), 9, Style.DEEP_CRIMSON, true, -1, true)
		draw_arc(Vector2(0, 63), 6, -PI * 0.5, PI * 1.3, 28, Style.CYAN, 2.0, true)
		if outcome == "win":
			_spark(Vector2(-67, -54), 8, Color("efd6a2"))
			_spark(Vector2(62, -63), 5, Color(Style.CYAN, 0.8))
		draw_set_transform(Vector2.ZERO)
	func _array(bounds: Rect2) -> void:
		var top := bounds.position
		var width := bounds.size.x
		var height := bounds.size.y
		var skew := minf(16, width * 0.07)
		var corners := PackedVector2Array([top, top + Vector2(width, 0), top + Vector2(width - skew, height), top + Vector2(-skew, height)])
		draw_colored_polygon(corners, Color("162f49"))
		for row in range(3):
			for column in range(8):
				var cell := Rect2(float(column) / 8.0, float(row) / 3.0, 1.0 / 8.0, 1.0 / 3.0)
				var a := top + Vector2(width * cell.position.x - skew * cell.position.y, height * cell.position.y)
				var b := top + Vector2(width * cell.end.x - skew * cell.position.y, height * cell.position.y)
				var c := top + Vector2(width * cell.end.x - skew * cell.end.y, height * cell.end.y)
				var d := top + Vector2(width * cell.position.x - skew * cell.end.y, height * cell.end.y)
				draw_polygon(PackedVector2Array([a,b,c,d]), PackedColorArray([Color("234765"),Color("1c3e5a"),Color("102d49"),Color("183751")]))
				draw_polyline(PackedVector2Array([a,b,c,d,a]), Color(Style.CYAN, 0.38), 1.0, true)
		var fraction := clampf(clean_fraction, 0.0, 1.0)
		if fraction < 1.0:
			var start := top + Vector2(width * fraction, 0)
			draw_colored_polygon(PackedVector2Array([start, corners[1], corners[2], start + Vector2(-skew, height)]), Color("a77b56"))
			for index in range(60):
				var u := fposmod(index * 0.618034 + 0.11, 1.0)
				var v := fposmod(index * 0.381966 + 0.17, 1.0)
				if u > fraction + 0.01:
					draw_circle(top + Vector2(width * u - skew * v, height * v), 0.7 + float(index % 3) * 0.4, Color("e7b685", 0.8), true, -1, true)
		draw_polyline(PackedVector2Array([corners[0],corners[1],corners[2],corners[3],corners[0]]), Color("b8c7cc"), 3.0, true)
		if fraction > 0.02:
			draw_line(top + Vector2(5, 4), top + Vector2(width * fraction - 3, 4), Color(Style.CYAN, 0.75), 2, true)
	func _draw() -> void:
		var panel_style := Style.panel(true)
		panel_style.bg_color = Color("102735")
		panel_style.border_color = Color(Style.CYAN, 0.24)
		draw_style_box(panel_style, Rect2(Vector2.ZERO, size))
		var portrait_scale := minf((size.y - 18.0) / 160.0, size.x * 0.38 / 150.0)
		var portrait_x := size.x * 0.205
		_portrait(Vector2(portrait_x, size.y * 0.5 + 1.0), portrait_scale)
		var content_x := size.x * 0.43
		var content_width := size.x - content_x - 22.0
		var font_size := 15 if size.x < 380 else 18
		draw_circle(Vector2(content_x + 5, 28), 4, Style.CYAN, true, -1, true)
		draw_string(Style.font("display_bold"), Vector2(content_x + 17, 34), "CREW INSIDE", HORIZONTAL_ALIGNMENT_LEFT, content_width - 17, font_size, Style.PEARL)
		_array(Rect2(content_x + 8, 52, content_width - 8, size.y - 94))
		draw_string(Style.font("body_bold"), Vector2(content_x, size.y - 17), "%.1f%% clear" % (clampf(clean_fraction, 0.0, 1.0) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, content_width, font_size, Style.CYAN)

class RunChart extends Control:
	var samples: Array = []
	var channel := "dose_ugy"
	var heading := "Model exposure"
	var unit := "µGy"
	var tint := Color.WHITE
	func _draw() -> void:
		var panel := Style.panel(true)
		draw_style_box(panel, Rect2(Vector2.ZERO, size))
		var font := get_theme_default_font()
		var ink := Style.color("pearl")
		var muted := Style.color("muted")
		draw_string(font, Vector2(16, 28), heading + " · " + unit, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 16, ink)
		var bounds := Rect2(42, 52, maxf(1, size.x - 62), maxf(1, size.y - 83))
		var maximum := 0.0
		var duration := 0.0
		for sample: Dictionary in samples:
			maximum = maxf(maximum, float(sample.get(channel, 0.0)))
			duration = maxf(duration, float(sample.get("sim_elapsed_seconds", sample.get("sim_seconds", sample.get("time", 0.0)))))
		maximum = maxf(maximum, 0.001)
		duration = maxf(duration, 1.0)
		for fraction in [0.0, 0.5, 1.0]:
			var y: float = bounds.end.y - bounds.size.y * float(fraction)
			draw_line(Vector2(bounds.position.x, y), Vector2(bounds.end.x, y), Color(muted, 0.18), 1)
		draw_string(font, Vector2(10, bounds.position.y + 5), "%.1f" % maximum, HORIZONTAL_ALIGNMENT_LEFT, 32, 12, muted)
		draw_string(font, Vector2(23, bounds.end.y + 4), "0", HORIZONTAL_ALIGNMENT_LEFT, 18, 12, muted)
		var points := PackedVector2Array()
		for sample: Dictionary in samples:
			var seconds := float(sample.get("sim_elapsed_seconds", sample.get("sim_seconds", sample.get("time", 0.0))))
			points.append(bounds.position + Vector2(clampf(seconds / duration, 0, 1) * bounds.size.x, (1.0 - clampf(float(sample.get(channel, 0.0)) / maximum, 0, 1)) * bounds.size.y))
		if points.size() > 1: draw_polyline(points, tint, 2.5, true)
		elif points.size() == 1: draw_circle(points[0], 3, tint)
		draw_string(font, Vector2(bounds.position.x, size.y - 12), "Start", HORIZONTAL_ALIGNMENT_LEFT, 90, 12, muted)
		draw_string(font, Vector2(bounds.end.x - 110, size.y - 12), "%.1f mission min" % (duration / 60.0), HORIZONTAL_ALIGNMENT_RIGHT, 110, 12, muted)

func _ready() -> void:
	name = "JourneyShell"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.theme()
	_header = Control.new()
	add_child(_header)
	_brand = Style.label(Branding.title() + "  /  " + Branding.subtitle().to_upper(), 15, Style.color("pearl"), "display")
	_header.add_child(_brand)
	_home = Style.button("Home")
	_home.pressed.connect(func(): home_requested.emit())
	_header.add_child(_home)
	_settings = Style.button("Settings")
	_settings.pressed.connect(func(): preferences_requested.emit())
	_header.add_child(_settings)
	_body = Control.new()
	add_child(_body)
	_footer = Control.new()
	add_child(_footer)
	_built = true
	resized.connect(_schedule_layout)
	if state == "preparation": show_preparation(catalog, reviewed_ids)
	elif state == "debrief": show_debrief(_result, catalog)
	else: show_story(reduced_motion)

func _clear_screen() -> void:
	if is_instance_valid(_story_tween): _story_tween.kill()
	_body.modulate.a = 1.0
	_close_dialog(false)
	_header.show()
	_body.show()
	_footer.show()
	for parent in [_body, _footer]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	_orbs.clear()
	_scroll = null
	_orb_area = null
	_title = null
	_subtitle = null
	_merge_skip = null
	_merge_note = null
	_progress = null
	_progress_label = null
	_ready_button = null
	_live_sun_button = null
	_debrief_content = null
	_debrief_summary = null
	_debrief_charts = null
	_result_content = null
	_science_content = null
	_result_media = null
	_science_details = null
	_science_button = null
	_equation_cards.clear()

func show_story(motion_reduced := false) -> void:
	state = "story"
	reduced_motion = motion_reduced
	show()
	if not _built: return
	_clear_screen()
	_story_index = 0
	_story_brand = Style.label(Branding.title(), 88, Style.color("pearl"), "display_bold")
	_story_brand_subtitle = Style.label(Branding.subtitle(), 28, Style.color("cyan"), "display_bold")
	_story_kicker = Style.label("", 20, Style.color("cyan"), "mono")
	_story_head = Style.label("", 38, Style.color("pearl"), "display_bold")
	_story_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_words = Style.label("", 28, Style.color("pearl"), "body_bold")
	_story_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_step = StepDots.new()
	for label in [_story_brand, _story_brand_subtitle, _story_kicker, _story_head, _story_words]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.minimum_size_changed.connect(_schedule_layout)
		_body.add_child(label)
	_story_step.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_story_step)
	_story_skip = Style.button("Skip intro")
	_story_skip.pressed.connect(_finish_story)
	_footer.add_child(_story_skip)
	_story_next = Style.button("Continue  →", true)
	_story_next.pressed.connect(advance_story)
	_footer.add_child(_story_next)
	_set_story_beat()
	_focus_later(_story_next)
	_schedule_layout()

func _set_story_beat() -> void:
	var beat: Dictionary = STORY[_story_index]
	_story_background = load(STORY_BACKGROUNDS[_story_index]) as Texture2D if ResourceLoader.exists(STORY_BACKGROUNDS[_story_index]) else null
	_story_kicker.text = beat.eyebrow
	_story_head.text = beat.title
	_story_words.text = beat.body
	_story_step.step = _story_index
	_story_step.accessibility_name = "Story step %d of 3" % (_story_index + 1)
	_story_step.queue_redraw()
	if is_instance_valid(_story_tween): _story_tween.kill()
	_body.modulate.a = 1.0 if reduced_motion else 0.65
	if not reduced_motion:
		_story_tween = create_tween()
		_story_tween.tween_property(_body, "modulate:a", 1.0, 0.24)
	_schedule_layout()
	_type_count = float(_story_words.text.length()) if reduced_motion else 0.0
	_story_words.visible_characters = -1 if reduced_motion else 0
	_cue_elapsed = 0
	audio_cue.emit("open")
	_story_next.text = "Enter control room  →" if _story_index == STORY.size() - 1 else "Continue  →"

func advance_story() -> void:
	if state != "story": return
	if _story_words.visible_characters >= 0 and _story_words.visible_characters < _story_words.text.length():
		_story_words.visible_characters = -1
		_type_count = _story_words.text.length()
		return
	if _story_index < STORY.size() - 1:
		_story_index += 1
		_set_story_beat()
	else: _finish_story()

func _finish_story() -> void:
	audio_cue.emit("confirm")
	var has_story_host := not story_finished.get_connections().is_empty()
	story_finished.emit()
	# Hosts own the next screen. Standalone users may
	# set it before story playback; never manufacture an empty 100% preparation.
	if not has_story_host and state == "story" and not catalog.is_empty(): show_preparation(catalog, reviewed_ids)

func show_preparation(concepts: Array, already_reviewed: Array = []) -> void:
	state = "preparation"
	catalog = concepts.duplicate(true)
	var accepted_reviewed := already_reviewed.duplicate()
	reviewed_ids.clear()
	for id in accepted_reviewed:
		if _find_concept(str(id)).is_empty() or str(id) in reviewed_ids: continue
		reviewed_ids.append(str(id))
	show()
	if not _built: return
	_clear_screen()
	_title = Style.label("Explore science", 34, Style.color("pearl"), "display")
	_subtitle = Style.label("Eight optional ideas. Pick one to explore.", 18, Style.color("muted"), "body")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.minimum_size_changed.connect(_schedule_layout)
	_subtitle.minimum_size_changed.connect(_schedule_layout)
	_body.add_child(_title)
	_body.add_child(_subtitle)
	_live_sun_button = Style.button("Live Sun · NASA")
	_live_sun_button.name = "PreparationLiveSun"
	_live_sun_button.tooltip_text = "Explore the latest Sun image from NASA's Solar Dynamics Observatory."
	_live_sun_button.pressed.connect(func(): live_data_requested.emit())
	_body.add_child(_live_sun_button)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.minimum_size_changed.connect(_schedule_layout)
	_body.add_child(_scroll)
	_orb_area = Control.new()
	_scroll.add_child(_orb_area)
	for concept: Dictionary in catalog:
		var orb := Orb.new()
		_orb_area.add_child(orb)
		orb.configure(str(concept.get("id", "")), Orb.short_title(str(concept.get("id", "")), str(concept.get("title", "Idea"))), "Explore")
		orb.set_reviewed(str(concept.get("id", "")) in reviewed_ids)
		orb.set_reduced_motion(reduced_motion)
		orb.pressed.connect(open_concept.bind(str(concept.get("id", ""))))
		_orbs.append(orb)
	_progress_label = Style.label("", 15, Style.color("muted"), "body")
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_label.minimum_size_changed.connect(_schedule_layout)
	_footer.add_child(_progress_label)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.max_value = 100
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := Style.panel(true)
	for side in ["left", "right", "top", "bottom"]: track.set("content_margin_" + side, 0)
	track.set_corner_radius_all(4)
	_progress.add_theme_stylebox_override("background", track)
	var fill := Style.panel(false)
	fill.bg_color = Style.color("cyan")
	fill.set_border_width_all(0)
	for side in ["left", "right", "top", "bottom"]: fill.set("content_margin_" + side, 0)
	fill.set_corner_radius_all(4)
	_progress.add_theme_stylebox_override("fill", fill)
	_footer.add_child(_progress)
	_ready_button = Style.button("Ready", true)
	_ready_button.name = "Ready"
	_ready_button.pressed.connect(_request_ready)
	_footer.add_child(_ready_button)
	_update_readiness()
	_schedule_layout()
	if not _orbs.is_empty(): _focus_later(_orbs[0])

func _update_readiness() -> void:
	readiness = float(reviewed_ids.size()) / catalog.size() if not catalog.is_empty() else 0.0
	if not is_instance_valid(_ready_button): return
	_ready_button.disabled = concept_open
	_ready_button.text = "Enter mission"
	_progress.value = readiness * 100
	_progress_label.text = "Reopen any idea during your mission."
	_progress.hide()
	if catalog.is_empty(): _progress_label.text = "Science ideas are unavailable. You can still enter the mission."
	for orb in _orbs: orb.set_reviewed(str(orb.concept_id) in reviewed_ids)
	queue_redraw()

func _request_ready() -> void:
	if state != "preparation" or concept_open: return
	audio_cue.emit("ready")
	ready_requested.emit()

func _find_concept(id: String) -> Dictionary:
	for item: Dictionary in catalog:
		if str(item.get("id", "")) == id: return item
	return {}

func show_live_concept(id: String, snapshot: Dictionary, return_label := "Back to mission") -> void:
	if _find_concept(id).is_empty() or not _built: return
	if concept_open: _close_dialog(false)
	_previous_state = state
	_live_mode = true
	_live_return_label = return_label if not return_label.strip_edges().is_empty() else "Back to mission"
	_live_snapshot = snapshot.duplicate(true)
	state = "live"
	_header.hide()
	_body.hide()
	_footer.hide()
	show()
	open_concept(id)
	queue_redraw()

func close_live_concept() -> void:
	if _live_mode: _close_dialog(false)

func _live_readout(id: String) -> String:
	match id:
		"radiation": return "Authored story rate now: %.1f µGy per Earth day. It rises with mission time. NASA’s Sun image is separate and does not set this curve." % float(_live_snapshot.get("radiation_rate_ugy_per_day", 210.0))
		"dose": return "Accumulated so far: %.2f µGy of modeled absorbed dose." % float(_live_snapshot.get("dose_ugy", 0.0))
		"sievert": return "Needs radiation/tissue weighting. This model measures absorbed dose in µGy and cannot calculate a personal Sv value."
		"dust": return "Cleaned so far: %.2f of %.0f panel sections. Every bit of cleaning improves the modeled output." % [float(_live_snapshot.get("cleaned_work", 0)), float(_live_snapshot.get("max_sections", 4))]
		"power": return "Stored now: %.3f kWh.\n\nPanels make %.2f kW; the dome uses %.2f kW. Net charging power is %+.2f kW.\n\nPower is the rate. Battery energy accumulates over mission time, up to the %.2f kWh capacity." % [float(_live_snapshot.get("battery_kwh", 0)), float(_live_snapshot.get("solar_power_kw", 0)), float(_live_snapshot.get("habitat_load_kw", 0)), float(_live_snapshot.get("net_power_kw", 0)), float(_live_snapshot.get("battery_capacity_kwh", 6))]
		"time":
			var left := maxi(0, ceili(float(_live_snapshot.get("sim_remaining_seconds", 0.0))))
			var play_left := maxi(0, ceili(float(_live_snapshot.get("remaining_seconds", 0.0))))
			return "Play time left: %02d:%02d. Mission time left: %02d:%02d. One second of play represents %.0f mission seconds at this setting. Both clocks pause while you read." % [play_left / 60, play_left % 60, left / 60, left % 60, float(_live_snapshot.get("effective_time_scale", 20))]
		"speed": return "Pace command: ×%.2f. Modeled tiredness: %.0f%%. Effective rate: %.3f sections per mission minute.\n\nAbove 1×, tiredness builds. Below1×, tiredness recovers. Ren stays beside the panel." % [float(_live_snapshot.get("selected_multiplier", 1)), float(_live_snapshot.get("fatigue", 0)) * 100, float(_live_snapshot.get("effective_rate_sections_per_minute", 0.125))]
		"shelter": return "Ren's current stage: " + str(_live_snapshot.get("phase", "outside")).capitalize() + ". At zero on the countdown, she steps straight inside. There is no walk or recall control."
	return "The mission is paused while you explore this idea."

func _live_summary(id: String) -> String:
	match id:
		"radiation": return "Story rate now · %.0f µGy/day" % float(_live_snapshot.get("radiation_rate_ugy_per_day", 210))
		"dose": return "Absorbed model dose · %.2f µGy" % float(_live_snapshot.get("dose_ugy", 0))
		"sievert": return "Sv needs more information than this model has."
		"dust": return "Panel cleaned · %.0f%%" % (float(_live_snapshot.get("clean_fraction", 0)) * 100)
		"power": return "Stored · %.2f kWh  |  Solar · %.2f kW" % [float(_live_snapshot.get("battery_kwh", 0)), float(_live_snapshot.get("solar_power_kw", 0))]
		"time":
			var play_left := maxi(0, ceili(float(_live_snapshot.get("remaining_seconds", 0.0))))
			return "Play left · %02d:%02d  |  Clock paused" % [play_left / 60, play_left % 60]
		"speed": return "Cleaning pace · ×%.2f  |  Tiredness · %.0f%%" % [float(_live_snapshot.get("selected_multiplier", 1)), float(_live_snapshot.get("fatigue", 0)) * 100]
		"shelter": return "Ren is inside." if bool(_live_snapshot.get("crew_sheltered", false)) else "Ren steps inside at zero."
	return "The mission is paused."

func open_concept(id: String) -> void:
	var concept := _find_concept(id)
	if concept.is_empty() or not _built: return
	_close_dialog(false)
	_dialog_id = id
	var focused := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focused) if focused else null
	concept_open = true
	if is_instance_valid(_ready_button): _ready_button.disabled = true
	concept_visibility_changed.emit(true)
	audio_cue.emit("open")
	_dialog_layer = Control.new()
	_dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dialog_layer)
	var shade := ColorRect.new()
	shade.color = Color(Style.color("floor"), 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.add_child(shade)
	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", Style.panel(true))
	_dialog.minimum_size_changed.connect(_schedule_layout)
	_dialog_layer.add_child(_dialog)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	_dialog.add_child(outer)
	var eyebrow := Style.label("MISSION IDEA  /  " + str(catalog.find(concept) + 1).pad_zeros(2), 13, Style.color("cyan"), "mono")
	outer.add_child(eyebrow)
	var heading := Style.label(str(concept.get("title", "Mission idea")), 32, Style.color("pearl"), "display")
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(heading)
	_dialog_scroll = ScrollContainer.new()
	_dialog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_dialog_scroll.follow_focus = true
	_dialog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_dialog_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	_dialog_scroll.add_child(content)
	_add_reading(content, str(concept.get("lead", "")), 23, "pearl", "body_bold")
	var diagram := ConceptVisual.new()
	diagram.name = "ConceptDiagram"
	diagram.concept_id = id
	diagram.custom_minimum_size = Vector2(0, 112)
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagram.accessibility_name = ConceptVisual.caption(id)
	diagram.set_reduced_motion(reduced_motion)
	content.add_child(diagram)
	_add_reading(content, str(concept.get("analogy", "")), 20)
	if _live_mode:
		var readout := _add_reading(content, _live_summary(id), 18, "cyan", "body_bold")
		readout.name = "CurrentMissionReading"
	_dialog_more_button = Style.button("Learn more  +")
	_dialog_more_button.name = "LearnMore"
	content.add_child(_dialog_more_button)
	_dialog_extra = VBoxContainer.new()
	_dialog_extra.name = "ConceptDetails"
	_dialog_extra.add_theme_constant_override("separation", 14)
	content.add_child(_dialog_extra)
	for key in ["detail_lead", "detail_analogy", "explanation"]:
		var detail := str(concept.get(key, ""))
		if not detail.is_empty(): _add_reading(_dialog_extra, detail, 19)
	_add_reading(_dialog_extra, ConceptVisual.caption(id), 18, "muted")
	var equation := str(concept.get("equation", ""))
	if not equation.is_empty():
		var equation_card := PanelContainer.new()
		equation_card.add_theme_stylebox_override("panel", Style.panel(false))
		_dialog_extra.add_child(equation_card)
		_add_reading(equation_card, equation, 19, "cyan", "mono")
	if _live_mode:
		_add_reading(_dialog_extra, "Your mission, right now", 18, "cyan", "display_bold")
		_add_reading(_dialog_extra, _live_readout(id), 19)
		_add_reading(_dialog_extra, str(concept.get("dynamic_hint", "")), 18, "muted")
	_dialog_extra.hide()
	_dialog_more_button.pressed.connect(func():
		_dialog_extra.visible = not _dialog_extra.visible
		_dialog_more_button.text = "Less detail  −" if _dialog_extra.visible else "Learn more  +"
	)
	_dialog_data_button = Style.button("Data & sources  +")
	_dialog_data_button.name = "DataAndSources"
	content.add_child(_dialog_data_button)
	_dialog_data = VBoxContainer.new()
	_dialog_data.name = "ConceptData"
	_dialog_data.add_theme_constant_override("separation", 14)
	content.add_child(_dialog_data)
	_add_reading(_dialog_data, "From the evidence", 18, "cyan", "display_bold")
	_add_reading(_dialog_data, str(concept.get("real_fact", "")), 19)
	_add_reading(_dialog_data, "Our game settings", 18, "amber", "display_bold")
	_add_reading(_dialog_data, str(concept.get("assumption", "")), 19)
	var source := Style.button(str(concept.get("source_label", "Read the source")) + "  ↗")
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_data.add_child(source)
	var url := str(concept.get("source_url", ""))
	source.disabled = url.is_empty()
	source.pressed.connect(func(): source_requested.emit(url))
	if id == "radiation":
		var live_sun := Style.button("Live Sun · NASA")
		live_sun.name = "RadiationLiveSun"
		live_sun.tooltip_text = "Explore the latest Sun image from NASA's Solar Dynamics Observatory."
		live_sun.pressed.connect(func(): live_data_requested.emit())
		_dialog_data.add_child(live_sun)
	_dialog_data.hide()
	_dialog_data_button.pressed.connect(func():
		_dialog_data.visible = not _dialog_data.visible
		_dialog_data_button.text = "Hide data & sources  −" if _dialog_data.visible else "Data & sources  +"
	)
	_dialog_done = Style.button(_live_return_label if _live_mode else "I've explored this  ✓", true)
	_dialog_done.name = "ConceptDone"
	_dialog_done.pressed.connect(close_concept)
	outer.add_child(_dialog_done)
	_dialog_done.tooltip_text = "Mark this idea as explored. Exploring is not a test of mastery."
	_layout_dialog()
	_focus_later(_dialog_done)

func close_concept() -> void:
	_close_dialog(true)

func _close_dialog(mark_reviewed: bool) -> void:
	if not concept_open: return
	if mark_reviewed and not _live_mode and not _dialog_id in reviewed_ids and not _find_concept(_dialog_id).is_empty():
		reviewed_ids.append(_dialog_id)
		audio_cue.emit("confirm")
	concept_open = false
	if is_instance_valid(_dialog_layer):
		remove_child(_dialog_layer)
		_dialog_layer.queue_free()
	_dialog_layer = null
	_dialog = null
	_dialog_id = ""
	_update_readiness()
	if _live_mode and state == "live":
		state = _previous_state
		_header.show()
		_body.show()
		_footer.show()
		hide()
	_live_mode = false
	_live_snapshot.clear()
	concept_visibility_changed.emit(false)
	if _previous_focus != null:
		var previous: Variant = _previous_focus.get_ref()
		if is_instance_valid(previous) and previous is Control and previous.is_visible_in_tree(): _focus_later(previous)
	_previous_focus = null

func show_debrief(result: Dictionary, concepts: Array) -> void:
	state = "debrief"
	if not is_instance_valid(_result_background): _result_background = load(STORY_BACKGROUNDS[2]) as Texture2D
	_result = result.duplicate(true)
	catalog = concepts.duplicate(true)
	quiz_first_answer = -1
	_debrief_view = "results"
	show()
	if not _built: return
	_clear_screen()
	_title = Style.label(_outcome_heading(), 40, Style.color("pearl"), "display_bold")
	_subtitle = Style.label(_outcome_message(), 22, Style.color("pearl"), "body_bold")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.minimum_size_changed.connect(_schedule_layout)
	_subtitle.minimum_size_changed.connect(_schedule_layout)
	_body.add_child(_title)
	_body.add_child(_subtitle)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.minimum_size_changed.connect(_schedule_layout)
	_body.add_child(_scroll)
	_debrief_content = VBoxContainer.new()
	_debrief_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debrief_content.add_theme_constant_override("separation", 18)
	_scroll.add_child(_debrief_content)
	_build_debrief_content()
	_merge_skip = Style.button("Show equations  →")
	_merge_skip.pressed.connect(_finish_merge)
	_body.add_child(_merge_skip)
	_merge_note = Style.label("Eight ideas. One connected mission.", 25, Style.color("cyan"), "display_bold")
	_merge_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(_merge_note)
	_science_button = Style.button("See how science connects", true)
	_science_button.name = "ScienceConnections"
	_science_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_science_button.pressed.connect(func():
		if _debrief_view == "results": show_science_connections()
		else: show_results()
	)
	_footer.add_child(_science_button)
	var retry := Style.button("Try another plan")
	retry.name = "Retry"
	retry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	retry.pressed.connect(func(): retry_requested.emit())
	_footer.add_child(retry)
	var finish := Style.button("Home")
	finish.name = "Finish"
	finish.pressed.connect(func(): home_requested.emit())
	_footer.add_child(finish)
	# The player always sees their result immediately. The merge is an optional,
	# replayable transition into the science page, never a gate to the ending.
	_merge_done = true
	_merge_skip.hide()
	_merge_note.hide()
	_science_content.hide()
	_scroll.show()
	_schedule_layout()
	_focus_later(_science_button)

func show_science_connections() -> void:
	if state != "debrief" or concept_open or not _built: return
	_debrief_view = "science"
	_title.text = "How the science connects"
	_subtitle.text = "Your actions changed the results. Here is how."
	_result_content.hide()
	_science_content.show()
	_science_button.text = "← Back to results"
	_merge_time = 0.0
	_merge_done = false
	_merge_skip.show()
	_merge_note.show()
	_scroll.hide()
	_schedule_layout()
	audio_cue.emit("open")
	if reduced_motion: _finish_merge()
	else: _focus_later(_merge_skip)

func show_results() -> void:
	if state != "debrief" or not _built: return
	_debrief_view = "results"
	_title.text = _outcome_heading()
	_subtitle.text = _outcome_message()
	_result_content.show()
	_science_content.hide()
	_science_button.text = "See how science connects"
	_merge_done = true
	_merge_skip.hide()
	_merge_note.hide()
	_scroll.show()
	_scroll.scroll_vertical = 0
	_schedule_layout()
	_focus_later(_science_button)
	queue_redraw()

func _add_reading(parent: Node, value: String, pixels: int, color_key := "pearl", face := "body") -> Label:
	var label := Style.label(value, pixels, Style.color(color_key), face)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _value(key: String, fallback: float) -> float:
	if _result.has(key): return float(_result[key])
	var assumptions: Dictionary = _result.get("assumptions", {})
	return float(assumptions.get(key, fallback))

func _cleaning_work_equation() -> String:
	# Integrated command × (1-fatigue) time preserves every pace change; final
	# tiredness or final command is never applied retroactively to the whole run.
	var effective_minutes := _value("fatigue_weighted_work_seconds", 0.0) / 60.0
	return "%.3f × %.3f effective minutes = %.2f sections" % [_value("base_cleaning_rate_sections_per_minute", 0.125), effective_minutes, _value("cleaned_work", 0)]

func _fatigue_equation() -> String:
	return "dF/min = %.2f × max(u−1, 0) − %.2f × max(1−u, 0); final F = %.3f" % [_value("fatigue_growth_per_minute", 0.08), _value("fatigue_recovery_per_minute", 0.12), _value("fatigue", 0)]

func _rate_equation() -> String:
	return "%.3f × %.2f × (1 − %.3f) = %.3f sections/min" % [_value("base_cleaning_rate_sections_per_minute", 0.125), _value("selected_multiplier", 1), _value("fatigue", 0), _value("effective_rate_sections_per_minute", 0.125)]

func _solar_equation() -> String:
	return "%.2f kW × %.3f transmission = %.2f kW now" % [_value("clear_solar_power_kw", 8), _value("solar_transmission", 0), _value("solar_power_kw", 0)]

func _energy_equation() -> String:
	# The model tracks energy actually supplied separately from unmet demand;
	# rejected solar energy at capacity never becomes stored battery energy.
	var supplied := maxf(0.0, _value("habitat_energy_used_kwh", 0) - _value("unserved_energy_kwh", 0))
	var terms := "%.3f initial + %.3f generated − %.3f supplied" % [_value("initial_battery_kwh", 0.5), _value("solar_energy_generated_kwh", 0), supplied]
	var overflow := _value("curtailed_energy_kwh", 0)
	if overflow > 0.0000001: terms += " − %.3f overflow" % overflow
	return terms + " = %.3f kWh stored" % _value("battery_kwh", 0)

func _dose_equation() -> String:
	var elapsed := _value("sim_elapsed_seconds", 0)
	var duration := maxf(1, _value("warning_seconds", 1800))
	return "(%.0f ÷ 86400) × [%.0f + %.1f × %.0f² ÷ (2 × %.0f)] = %.4f µGy" % [_value("background_dose_ugy_per_day", 210), elapsed, _value("radiation_ramp_multiplier", 3), elapsed, duration, _value("dose_ugy", 0)]

func _outcome_heading() -> String:
	match str(_result.get("status", "")):
		"win": return "You powered up the outpost!"
		"pass": return "Good progress, astronaut!"
		_: return "Try a new cleaning plan!"

func _outcome_message() -> String:
	match str(_result.get("status", "")):
		"win": return "Ren is inside. The panel is mostly clear."
		"pass": return "Ren is inside. You cleared part of the panel."
		_: return "Ren is inside. There is more dust to clear."

func _outcome_science() -> String:
	match str(_result.get("status", "")):
		"win": return "Less dust → more sunlight → more solar power."
		"pass": return "Dust left on the panel still blocked some sunlight."
		_: return "A balanced pace can remove more dust before the storm."

func _word_equations() -> Array:
	return [
		["01  PANEL CLEANED", "Panel cleaned = average effective cleaning rate × cleaning time", "More effective cleaning over time → less dust. Tiredness reduces the rate.", "speed"],
		["02  SOLAR POWER", "Solar power = clear-panel power × sunlight getting through dust", "Less dust → a larger fraction of sunlight reaches the solar cells → more power.", "dust"],
		["03  ENERGY STORED", "Energy stored = starting energy + energy collected − energy used", "Power collected over time changes the battery, up to its capacity.", "power"],
		["04  ABSORBED DOSE", "Absorbed dose = average radiation rate × outside time", "Radiation rate changes in this story. Its average × outside time gives the dose.", "dose"],
	]

func _idea_token(parent: Node, id: String, words: String) -> Button:
	var button := Style.button(words)
	button.name = "IdeaToken_" + id
	button.add_theme_font_size_override("font_size", 17)
	button.custom_minimum_size = Vector2(118, 56)
	for state_name in ["normal", "hover", "pressed", "disabled"]:
		var token_style := Style.button_style(false, state_name)
		token_style.content_margin_left = 46
		token_style.content_margin_right = 10
		token_style.content_margin_top = 6
		token_style.content_margin_bottom = 6
		button.add_theme_stylebox_override(state_name, token_style)
	button.accessibility_name = Orb.short_title(id)
	button.accessibility_description = words.replace("\n", " ") + ". Open this science idea."
	button.tooltip_text = "Explore " + Orb.short_title(id)
	button.pressed.connect(open_concept.bind(id))
	parent.add_child(button)
	var glyph := IdeaIcon.new()
	glyph.concept_id = id
	glyph.position = Vector2(8, 12)
	glyph.size = Vector2(27, 30)
	button.add_child(glyph)
	return button

func _build_debrief_content() -> void:
	_result_content = VBoxContainer.new()
	_result_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_content.add_theme_constant_override("separation", 16)
	_debrief_content.add_child(_result_content)
	_result_media = GridContainer.new()
	_result_media.columns = 2
	_result_media.add_theme_constant_override("h_separation", 18)
	_result_media.add_theme_constant_override("v_separation", 14)
	_result_content.add_child(_result_media)
	var picture := ResultVisual.new()
	picture.name = "ResultIllustration"
	picture.clean_fraction = _value("clean_fraction", 0)
	picture.outcome = str(_result.get("status", ""))
	picture.custom_minimum_size = Vector2(0, 170)
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.accessibility_name = "Ren is inside. The panel illustration shows the same cleaned fraction as the result."
	picture.accessibility_description = "Original crew portrait and result diagram. Panel %.1f percent clear." % (100 * picture.clean_fraction)
	_result_media.add_child(picture)
	var science_card := PanelContainer.new()
	science_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	science_card.add_theme_stylebox_override("panel", Style.panel(true))
	_result_media.add_child(science_card)
	var science_note := VBoxContainer.new()
	science_note.add_theme_constant_override("separation", 8)
	science_card.add_child(science_note)
	_add_reading(science_note, "SCIENCE CONNECTION", 18, "cyan", "display_bold")
	_add_reading(science_note, _outcome_science(), 22, "pearl", "body_bold")
	_debrief_summary = GridContainer.new()
	_debrief_summary.columns = 3
	_debrief_summary.add_theme_constant_override("h_separation", 12)
	_debrief_summary.add_theme_constant_override("v_separation", 12)
	_result_content.add_child(_debrief_summary)
	for item in [
		["Panel cleaned", "%.1f%%" % (100 * _value("clean_fraction", 0)), _value("clean_fraction", 0)],
		["Energy stored", "%.2f kWh" % _value("battery_kwh", 0), _value("battery_kwh", 0) / maxf(0.001, _value("battery_capacity_kwh", 6))],
		["Absorbed model dose", "%.2f µGy" % _value("dose_ugy", 0), -1.0],
	]:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", Style.panel(true))
		_debrief_summary.add_child(card)
		var column := VBoxContainer.new()
		card.add_child(column)
		_add_reading(column, item[0], 19, "pearl", "body_bold")
		_add_reading(column, item[1], 32, "cyan", "display_bold")
		if float(item[2]) >= 0:
			var meter := ProgressBar.new()
			meter.name = "ActualLevel"
			meter.show_percentage = false
			meter.max_value = 1.0
			meter.step = 0.0
			meter.value = clampf(float(item[2]), 0, 1)
			meter.custom_minimum_size.y = 8
			meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
			meter.accessibility_name = item[0] + " level"
			column.add_child(meter)
	_add_reading(_result_content, "%s · Cleaning goal: %.0f%%" % [str(_result.get("status", "")).to_upper(), 100 * _value("win_clean_fraction", 0.8)], 17, "muted")
	_add_reading(_result_content, "Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC", 15, "muted")

	_science_content = VBoxContainer.new()
	_science_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_science_content.add_theme_constant_override("separation", 14)
	_debrief_content.add_child(_science_content)
	_equation_grid = GridContainer.new()
	_equation_grid.columns = 2
	_equation_grid.add_theme_constant_override("h_separation", 14)
	_equation_grid.add_theme_constant_override("v_separation", 14)
	_science_content.add_child(_equation_grid)
	var relationships := [
		["Clear the panel", [["speed", "Average\ncleaning rate"], "×", ["time", "Cleaning\ntime"], "→", ["dust", "Panel\ncleaned"]], "Tiredness changes the effective rate."],
		["Let the light in", [["dust", "Less\ndust"], "→", ["power", "More solar\npower"]], "More sunlight reaches the solar cells."],
		["Charge the battery", [["power", "Energy\ncollected"], "−", ["power", "Energy\nused"], "→", ["power", "Battery\nchange"]], "Start + change, up to the battery’s capacity."],
		["Count the dose", [["radiation", "Average\nradiation rate"], "×", ["time", "Outside\ntime"], "→", ["dose", "Absorbed\ndose"]], "The average includes the changing story rate."],
	]
	for relation in relationships:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", Style.panel(true))
		_equation_grid.add_child(card)
		_equation_cards.append(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		card.add_child(column)
		_add_reading(column, relation[0], 23, "pearl", "display_bold")
		var links := HFlowContainer.new()
		links.add_theme_constant_override("h_separation", 6)
		links.add_theme_constant_override("v_separation", 8)
		column.add_child(links)
		for token in relation[1]:
			if token is String:
				var symbol := Style.label(token, 25, Style.CYAN, "display_bold")
				symbol.custom_minimum_size = Vector2(22, 56)
				symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				links.add_child(symbol)
			else: _idea_token(links, str(token[0]), str(token[1]))
		_add_reading(column, relation[2], 18, "muted")
	var context := HFlowContainer.new()
	context.add_theme_constant_override("h_separation", 12)
	context.add_theme_constant_override("v_separation", 8)
	_science_content.add_child(context)
	_idea_token(context, "shelter", "Ren is\ninside")
	_idea_token(context, "sievert", "Why µGy\nis not Sv")
	var details_toggle := Style.button("Explore my numbers and graphs  +")
	details_toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_toggle.name = "ScienceDetails"
	_science_content.add_child(details_toggle)
	_science_details = VBoxContainer.new()
	_science_details.add_theme_constant_override("separation", 16)
	_science_content.add_child(_science_details)
	details_toggle.pressed.connect(func():
		_science_details.visible = not _science_details.visible
		details_toggle.text = "Hide my numbers and graphs  −" if _science_details.visible else "Explore my numbers and graphs  +"
	)
	_add_reading(_science_details, "Your actual mission", 26, "pearl", "display_bold")
	for equation in _word_equations():
		_add_reading(_science_details, equation[1], 21, "cyan", "display_bold")
		_add_reading(_science_details, equation[2], 18)
	_add_reading(_science_details, "WIN needs at least %.0f%% clean; PASS needs at least %.0f%%. Ren enters at zero in every full round. The energy and dose readings explain the run; they do not decide the result." % [100 * _value("win_clean_fraction", 0.8), 100 * _value("pass_clean_fraction", 0.4)], 18)
	_add_reading(_science_details, "Sievert (Sv) also needs radiation-type and tissue information. This game does not calculate a personal health risk.", 18, "muted")
	for item in [
		["Pace and tiredness", _fatigue_equation() + "\n" + _rate_equation(), "These authored lesson rules describe the final rate. Changing pace never rewrites the earlier work."],
		["Panel cleaned over time", _cleaning_work_equation(), "Effective minutes add each pace × (1−tiredness) time step. Work is capped at %.0f sections." % _value("max_sections", 4)],
		["Solar output now", _solar_equation(), "Light transmission is %.2f + %.2f × clean fraction." % [_value("minimum_solar_transmission", 0.25), 1 - _value("minimum_solar_transmission", 0.25)]],
		["Battery energy balance", _energy_equation(), "Capacity is %.2f kWh. Unmet demand was %.3f kWh; overflow and unsupplied demand are kept separate." % [_value("battery_capacity_kwh", 6), _value("unserved_energy_kwh", 0)]],
		["Accumulated model dose", _dose_equation(), "Every full round has the same %.0f mission-minute outside time and authored radiation curve. There is no lower-dose bonus." % (_value("warning_seconds", 1800) / 60)],
	]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", Style.panel(true))
		_science_details.add_child(card)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 8)
		card.add_child(column)
		_add_reading(column, item[0], 20, "pearl", "display_bold")
		_add_reading(column, item[1], 18, "cyan", "mono")
		_add_reading(column, item[2], 18)
	_debrief_charts = GridContainer.new()
	_debrief_charts.columns = 2
	_debrief_charts.add_theme_constant_override("h_separation", 14)
	_debrief_charts.add_theme_constant_override("v_separation", 14)
	_science_details.add_child(_debrief_charts)
	var history: Array = _result.get("history", [])
	for config in [["battery_kwh", "Energy actually stored", "kWh", "cyan"], ["dose_ugy", "Your accumulated exposure", "µGy", "amber"]]:
		var chart := RunChart.new()
		chart.custom_minimum_size = Vector2(180, 210)
		chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chart.samples = history.duplicate(true)
		chart.channel = config[0]
		chart.heading = config[1]
		chart.unit = config[2]
		chart.tint = Style.color(config[3])
		_debrief_charts.add_child(chart)
	_add_reading(_science_details, "These lines show your actual simulated run. Hardware, fatigue and storm settings are authored for this lesson; they are not live NASA predictions.", 17, "muted")
	var quiz_card := PanelContainer.new()
	quiz_card.add_theme_stylebox_override("panel", Style.panel(true))
	_science_details.add_child(quiz_card)
	var quiz := VBoxContainer.new()
	quiz.add_theme_constant_override("separation", 12)
	quiz_card.add_child(quiz)
	_add_reading(quiz, "Try the idea somewhere new", 25, "pearl", "display_bold")
	_add_reading(quiz, "What can happen if Ren stays at the fastest pace for the whole mission?", 21)
	for index in range(3):
		var answer := Style.button(["Tiredness can reduce her later cleaning rate", "The fastest command always cleans the most", "The faster pace blocks radiation"][index])
		answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		answer.custom_minimum_size.y = 60
		answer.name = "TransferAnswer" + str(index)
		answer.pressed.connect(answer_quiz.bind(index))
		quiz.add_child(answer)
	_debrief_quiz_feedback = _add_reading(quiz, "Optional practice. Your first answer is recorded before the explanation.", 17, "muted")
	_add_reading(_science_details, "Explore any mission idea again", 23, "pearl", "display_bold")
	var review := HFlowContainer.new()
	review.add_theme_constant_override("h_separation", 10)
	review.add_theme_constant_override("v_separation", 10)
	_science_details.add_child(review)
	for concept: Dictionary in catalog:
		var button := Style.button(str(concept.get("title", "Idea")))
		button.pressed.connect(open_concept.bind(str(concept.get("id", ""))))
		review.add_child(button)
	_add_reading(_science_details, "Mission targets are practice goals, not medical limits or a NASA safety rating. You can finish here and come back another day.", 17, "muted")
	_science_details.hide()

func answer_quiz(index: int) -> void:
	if state != "debrief" or index < 0 or index > 2: return
	if quiz_first_answer == -1:
		quiz_first_answer = index
		quiz_answered.emit(quiz_record())
	_debrief_quiz_feedback.text = ("Yes. " if index == 0 else "Think about tiredness: ") + "A high pace builds modeled tiredness. Effective rate is base rate × pace × (1−tiredness), so sustained rushing can reduce later work. Slower commands allow recovery. Every full round has the same dose."
	audio_cue.emit("confirm")

func quiz_record() -> Dictionary:
	return {"question_id": "pace-fatigue-transfer-1", "first_answer": quiz_first_answer, "answered": quiz_first_answer >= 0, "correct": quiz_first_answer == 0, "assisted": false}

func _finish_merge() -> void:
	if state != "debrief" or _debrief_view != "science" or _merge_done: return
	_merge_done = true
	_scroll.show()
	_merge_skip.hide()
	_merge_note.hide()
	audio_cue.emit("success" if str(_result.get("status", "")) == "win" else "confirm")
	# Keep the actual run summary at the top instead of scrolling straight to the quiz.
	_scroll.scroll_vertical = 0
	_focus_later(_science_button)
	queue_redraw()

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	for orb in _orbs: orb.set_reduced_motion(enabled)
	if is_instance_valid(_dialog):
		var diagram := _dialog.find_child("ConceptDiagram", true, false)
		if diagram: diagram.set_reduced_motion(enabled)
	if enabled:
		if is_instance_valid(_story_tween): _story_tween.kill()
		if is_instance_valid(_body): _body.modulate.a = 1.0
		if state == "story" and is_instance_valid(_story_words): _story_words.visible_characters = -1
		if state == "debrief" and _built: _finish_merge()
	queue_redraw()

func _focus_later(control: Control) -> void:
	if not is_instance_valid(control): return
	var target: WeakRef = weakref(control)
	(func():
		var candidate: Variant = target.get_ref()
		if is_instance_valid(candidate) and candidate is Control and candidate.is_inside_tree() and candidate.is_visible_in_tree():
			candidate.grab_focus()
	).call_deferred()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not concept_open: return
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_TAB: return
	# Keep keyboard navigation inside the reading card until it is closed.
	var targets: Array[Control] = []
	for candidate in _dialog.find_children("*", "Button", true, false):
		if candidate.is_visible_in_tree() and not candidate.disabled: targets.append(candidate)
	if targets.is_empty(): return
	var current := targets.find(get_viewport().gui_get_focus_owner())
	var step := -1 if event.shift_pressed else 1
	targets[posmod(current + step, targets.size())].grab_focus()
	get_viewport().set_input_as_handled()

func handle_back() -> bool:
	if not is_visible_in_tree(): return false
	if concept_open:
		_close_dialog(false)
		return true
	if state == "story":
		_finish_story()
		return true
	if state == "debrief" and _debrief_view == "science":
		show_results()
		return true
	home_requested.emit()
	return true

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo: return
	# Fullscreen handling belongs to the host, which calls handle_back afterward.
	if event.keycode == KEY_ESCAPE:
		if handle_back(): get_viewport().set_input_as_handled()
	elif state == "story" and event.keycode in [KEY_ENTER, KEY_SPACE]:
		advance_story()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	if not reduced_motion: _time += minf(delta, 0.1)
	if state == "story" and is_instance_valid(_story_words) and _story_words.visible_characters >= 0:
		_type_count = minf(float(_story_words.text.length()), _type_count + delta * 32.0)
		_story_words.visible_characters = int(_type_count)
		_cue_elapsed += delta
		if _cue_elapsed >= 0.09 and _type_count < _story_words.text.length():
			_cue_elapsed = 0.0
			audio_cue.emit("typewriter")
		if _type_count >= _story_words.text.length(): _story_words.visible_characters = -1
	if state == "debrief" and not _merge_done:
		_merge_time += delta
		if _merge_time >= 2.0: _finish_merge()
	queue_redraw()

func _schedule_layout() -> void:
	if _layout_queued: return
	_layout_queued = true
	_layout.call_deferred()

func _layout() -> void:
	_layout_queued = false
	if not _built or size.x <= 0: return
	var narrow := size.x < 600
	var short := size.y < 470
	var margin := 20.0 if narrow else 32.0
	var header_h := 64.0 if short else 80.0
	var footer_h := (148.0 if narrow else 88.0) if state == "debrief" else (142.0 if state == "preparation" and size.x < 360 else (92.0 if narrow else 82.0))
	_header.position = Vector2(margin, 8)
	_header.size = Vector2(size.x - margin * 2, header_h - 8)
	_brand.visible = state != "story" or _story_index > 0
	_brand.position = Vector2(0, 12)
	_brand.size = Vector2(maxf(90, _header.size.x - 228), 34)
	_brand.add_theme_font_size_override("font_size", 21 if narrow else 24)
	_brand.text = Branding.title() if size.x < 1000 else Branding.title() + "  /  " + Branding.subtitle()
	_home.position = Vector2(_header.size.x - 202, 4)
	_home.size = Vector2(88, 48)
	_settings.position = Vector2(_header.size.x - 106, 4)
	_settings.size = Vector2(106, 48)
	_body.position = Vector2(margin, header_h)
	_body.size = Vector2(size.x - margin * 2, size.y - header_h - footer_h)
	_footer.position = Vector2(margin, size.y - footer_h + 8)
	_footer.size = Vector2(size.x - margin * 2, footer_h - 16)
	if state == "story": _layout_story(narrow, short)
	elif state == "preparation": _layout_preparation(narrow, short)
	elif state == "debrief": _layout_debrief(narrow, short)
	_layout_dialog()
	queue_redraw()

func _layout_story(narrow: bool, short: bool) -> void:
	var left := 4.0 if narrow else minf(70, _body.size.x * 0.06)
	var top := 0.0 if short else maxf(8, _body.size.y * 0.08)
	var width := _body.size.x - left * 2
	_story_brand.position = Vector2(left, top)
	_story_brand.add_theme_font_size_override("font_size", 48 if short else (53 if narrow else 88))
	_story_brand.size = Vector2(width, 1)
	_story_brand_subtitle.position = Vector2(left, _story_brand.position.y + _story_brand.size.y - (4 if short else 7))
	_story_brand_subtitle.add_theme_font_size_override("font_size", 20 if short else (23 if narrow else 28))
	_story_brand_subtitle.size = Vector2(width, 1)
	_story_brand.visible = _story_index == 0
	_story_brand_subtitle.visible = _story_index == 0
	var beat_y := _story_brand_subtitle.position.y + _story_brand_subtitle.size.y + (12 if short else 38)
	if _story_index > 0: beat_y = maxf(12, _body.size.y * (0.22 if short else 0.28))
	_story_kicker.position = Vector2(left, beat_y)
	_story_kicker.add_theme_font_size_override("font_size", 15 if short else 19)
	_story_kicker.size = Vector2(width, 1)
	_story_head.position = Vector2(left, _story_kicker.position.y + _story_kicker.size.y + (2 if short else 8))
	_story_head.add_theme_font_size_override("font_size", (32 if short else (38 if narrow else 62)) if _story_index > 0 else (26 if short else (32 if narrow else 40)))
	_story_head.size = Vector2(width, 1)
	_story_words.position = Vector2(left, _story_head.position.y + _story_head.size.y + (4 if short else 14))
	_story_words.add_theme_font_size_override("font_size", 20 if short else (23 if narrow else 28))
	_story_words.size = Vector2(width, 1)
	_story_step.position = Vector2(left, _story_words.position.y + _story_words.size.y + 24)
	_story_step.size = Vector2(70, 22)
	_story_step.visible = _story_step.position.y + 22 < _body.size.y
	_story_skip.position = Vector2(0, 8)
	_story_skip.size = Vector2(112, 52)
	_story_next.add_theme_font_size_override("font_size", 16 if narrow else 21)
	_story_next.text = ("Enter room  →" if narrow else "Enter control room  →") if _story_index == STORY.size() - 1 else "Continue  →"
	_story_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_next.size = Vector2(minf(280, _footer.size.x - 124), 52)
	_story_next.position = Vector2(_footer.size.x - _story_next.size.x, 8)

func _layout_preparation(narrow: bool, short: bool) -> void:
	var header_action := short and _body.size.x >= 680
	var wide_action := not short and _body.size.x >= 750
	_title.position = Vector2(0, 0)
	_title.size = Vector2(_body.size.x - (202 if header_action else 0), 48 if not narrow else 64)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 25 if narrow or short else 34)
	_subtitle.position = Vector2(0, maxf(50 if not narrow else 67, _title.size.y + 6))
	_subtitle.size = Vector2(_body.size.x - (202 if wide_action else 0), 1)
	_subtitle.add_theme_font_size_override("font_size", 15 if short or narrow else 18)
	_subtitle.visible = not short
	_live_sun_button.size = Vector2(minf(186, _body.size.x), 48)
	var top := 168.0 if narrow else 148.0
	if header_action:
		_live_sun_button.position = Vector2(_body.size.x - 186, 0)
		top = 60.0
	elif wide_action:
		_live_sun_button.position = Vector2(_body.size.x - 186, 52)
		top = 110.0
	else:
		_live_sun_button.position = Vector2(0, maxf(110 if narrow else 90, _subtitle.position.y + _subtitle.size.y + 12))
		top = _live_sun_button.position.y + 60
	_scroll.position = Vector2(0, top)
	_scroll.size = Vector2(_body.size.x, maxf(60, _body.size.y - top))
	var ellipse := not narrow and not short and _scroll.size.y >= 220
	var diameter := 120.0 if _body.size.x > 1050 else 104.0
	_orb_area.custom_minimum_size = Vector2(_scroll.size.x - 8, _scroll.size.y)
	_orb_area.size = _orb_area.custom_minimum_size
	if ellipse:
		var center := _orb_area.size * 0.5
		var radii := Vector2(maxf(1, center.x - diameter * 0.7), maxf(1, center.y - diameter * 0.55))
		for index in range(_orbs.size()):
			var angle := -PI * 0.5 + TAU * index / maxi(1, _orbs.size())
			_orbs[index].position = center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) - Vector2.ONE * diameter * 0.5
			_orbs[index].size = Vector2.ONE * diameter
	else:
		var columns := 2 if narrow else 4
		var rows := ceili(float(_orbs.size()) / columns)
		var cell_h := diameter + (22 if narrow else 10)
		_orb_area.custom_minimum_size.y = maxf(_scroll.size.y, rows * cell_h)
		_orb_area.size = _orb_area.custom_minimum_size
		var cell_w := _orb_area.size.x / columns
		for index in range(_orbs.size()):
			_orbs[index].position = Vector2((index % columns) * cell_w + (cell_w - diameter) * 0.5, floorf(float(index) / columns) * cell_h + 4)
			_orbs[index].size = Vector2.ONE * diameter
	_progress_label.position = Vector2(0, 0)
	_progress_label.size = Vector2(maxf(120, _footer.size.x - 205), 44)
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_label.add_theme_font_size_override("font_size", 13 if narrow else 15)
	_progress.position = Vector2(0, 49)
	_progress.size = Vector2(maxf(100, _footer.size.x - 205), 7)
	_ready_button.add_theme_font_size_override("font_size", 16)
	_ready_button.position = Vector2(_footer.size.x - 190, 4)
	_ready_button.size = Vector2(190, 56)
	if size.x < 360:
		_progress_label.size.x = _footer.size.x
		_progress.size.x = _footer.size.x
		_ready_button.position = Vector2(0, 65)
		_ready_button.size = Vector2(_footer.size.x, 56)

func _layout_debrief(narrow: bool, short: bool) -> void:
	_title.position = Vector2.ZERO
	_title.add_theme_font_size_override("font_size", 28 if narrow or short else 40)
	_title.size = Vector2(_body.size.x, 1)
	_subtitle.position = Vector2(0, _title.size.y + 6)
	_subtitle.add_theme_font_size_override("font_size", 19 if narrow or short else 22)
	_subtitle.size = Vector2(_body.size.x, 1)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.visible = not short
	var top := (_subtitle.position.y + _subtitle.size.y + 16) if not short else (_title.size.y + 10)
	_scroll.position = Vector2(0, top)
	_scroll.size = Vector2(_body.size.x, maxf(40, _body.size.y - top))
	_debrief_content.custom_minimum_size.x = maxf(120, _scroll.size.x - 20)
	_debrief_summary.columns = 1 if narrow else 3
	# Small screens put the three actual readings first; illustration stays below.
	_result_content.move_child(_debrief_summary, 0 if narrow else 1)
	_result_media.columns = 1 if narrow else 2
	_result_media.get_node("ResultIllustration").custom_minimum_size.y = 166 if narrow else 170
	_debrief_charts.columns = 1 if _body.size.x < 720 else 2
	_equation_grid.columns = 2 if _body.size.x >= 1000 else 1
	_merge_skip.size = Vector2(minf(252, _body.size.x), 52)
	_merge_skip.position = Vector2((_body.size.x - _merge_skip.size.x) * 0.5, _body.size.y - 56)
	_merge_note.position = Vector2(0, maxf(top, _body.size.y - 122))
	_merge_note.size = Vector2(_body.size.x, 60)
	_merge_note.add_theme_font_size_override("font_size", 18 if short or narrow else 25)
	_merge_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var retry := _footer.get_node("Retry") as Button
	var finish := _footer.get_node("Finish") as Button
	if narrow:
		_science_button.position = Vector2(0, 0)
		_science_button.size = Vector2(_footer.size.x, 58)
		retry.position = Vector2(0, 68)
		retry.size = Vector2((_footer.size.x - 10) * 0.66, 52)
		finish.position = Vector2(retry.size.x + 10, 68)
		finish.size = Vector2(_footer.size.x - retry.size.x - 10, 52)
	else:
		var gap := 14.0
		var available := _footer.size.x - gap * 2
		_science_button.position = Vector2.ZERO
		_science_button.size = Vector2(available * 0.45, 60)
		retry.position = Vector2(_science_button.size.x + gap, 0)
		retry.size = Vector2(available * 0.35, 60)
		finish.position = Vector2(retry.position.x + retry.size.x + gap, 0)
		finish.size = Vector2(available * 0.20, 60)
	for button in [_science_button, retry, finish]:
		button.add_theme_font_size_override("font_size", 18 if narrow or short else 22)

func _layout_dialog() -> void:
	if not is_instance_valid(_dialog): return
	var margin := 16.0
	_dialog.position = Vector2(maxf(margin, (size.x - 610) * 0.5), margin)
	_dialog.size = Vector2(minf(610, size.x - margin * 2), size.y - margin * 2)
	_dialog_scroll.custom_minimum_size.y = 50
	_dialog_done.custom_minimum_size.y = 52

func _draw() -> void:
	if not _built or state == "live": return
	draw_rect(Rect2(Vector2.ZERO, size), Style.color("floor"))
	if state == "story" and is_instance_valid(_story_background):
		var image_size := _story_background.get_size()
		var scale_factor := maxf(size.x / image_size.x, size.y / image_size.y)
		var region_size := size / scale_factor
		draw_texture_rect_region(_story_background, Rect2(Vector2.ZERO, size), Rect2((image_size - region_size) * 0.5, region_size))
		# Keep the artwork luminous at the right while giving the short story a
		# quiet, high-contrast reading area. A uniform veil flattened the scene.
		for strip in range(64):
			var t := float(strip) / 63.0
			var shade := lerpf(0.86, 0.12, smoothstep(0.15, 0.85, t))
			if size.x < 600: shade = lerpf(0.77, 0.43, t)
			draw_rect(Rect2(size.x * strip / 64.0, 0, size.x / 64.0 + 1, size.y), Color(Style.FLOOR, shade))
	elif state == "debrief":
		# Reflections of the same outpost connect results to the mission. The
		# scientific readings stay on solid, accessible cards above this artwork.
		if is_instance_valid(_result_background):
			var image_size := _result_background.get_size()
			var region_size := size / maxf(size.x / image_size.x, size.y / image_size.y)
			draw_texture_rect_region(_result_background, Rect2(Vector2.ZERO, size), Rect2((image_size-region_size)*0.5, region_size), Color(1,1,1,0.18))
	var glow_center := size * Vector2(0.74, 0.58)
	for index in range(22, 0, -1):
		var radius := float(index) * maxf(size.x, size.y) * 0.024
		draw_circle(glow_center, radius, Color(Style.color("cyan"), 0.0028))
	# Stars belong to the discovery backdrop, not in front of the habitat.
	for index in range(0 if state in ["story", "debrief"] else 72):
		var point := Vector2(fposmod(index * 137.37 + 31.0, 997.0) / 997.0, fposmod(index * 71.73 + 19.0, 631.0) / 631.0) * size
		var alpha := 0.19 + float(index % 4) * 0.1
		if not reduced_motion: alpha *= 0.86 + 0.14 * sin(_time * 0.35 + index)
		draw_circle(point, 0.7 + float(index % 3) * 0.35, Color(Style.color("pearl"), alpha))
	var orbit_center := size * Vector2(0.74, 0.58)
	if state == "story" and size.x > 700:
		var radius := minf(size.x * 0.22, size.y * 0.37)
		draw_arc(orbit_center, radius, -0.4, PI * 1.35, 90, Color(Style.color("rose"), 0.18), 1.0, true)
		draw_arc(orbit_center, radius * 1.16, -1.2, PI * 0.8, 90, Color(Style.color("cyan"), 0.12), 1.0, true)
		draw_circle(orbit_center + Vector2(cos(_time * 0.025), sin(_time * 0.025)) * radius, 3.0, Style.color("rose"))
	if state == "preparation" and is_instance_valid(_orb_area):
		for index in range(_orbs.size()):
			var a := _orbs[index].get_global_rect().get_center() - global_position
			var b := _orbs[(index + 1) % _orbs.size()].get_global_rect().get_center() - global_position
			# Draw only within the scroll window; the orbs own their readable labels.
			var clip := _scroll.get_global_rect()
			if clip.has_point(a + global_position) and clip.has_point(b + global_position):
				draw_line(a, b, Color(Style.color("cyan"), 0.11), 1.0, true)
	if state == "debrief" and _debrief_view == "science" and not _merge_done:
		var center := _body.position + _body.size * Vector2(0.5, 0.48)
		var progress := smoothstep(0.25, 1.65, _merge_time)
		var short := size.y < 470
		var narrow := size.x < 600
		var columns := 2 if narrow else 4
		var cell := Vector2(minf(200, (_body.size.x - 12) / columns), 56 if short else 68)
		var rows := ceili(float(catalog.size()) / columns)
		var origin := center - Vector2(cell.x * columns, cell.y * rows) * 0.5
		for index in range(catalog.size()):
			var id := str(catalog[index].get("id", ""))
			var title := Orb.short_title(id, str(catalog[index].get("title", "Idea")))
			var start := origin + Vector2(index % columns + 0.5, floorf(float(index) / columns) + 0.5) * cell
			var point := start.lerp(center, progress)
			var alpha := 1.0 - progress
			var pill := Style.panel(true)
			pill.bg_color = Color(Style.GLASS, alpha)
			pill.border_color = Color(Style.CYAN, alpha)
			pill.set_border_width_all(2)
			pill.set_corner_radius_all(25)
			var dimensions := Vector2(cell.x - 12, cell.y - 12) * (1.0 - progress * 0.55)
			draw_style_box(pill, Rect2(point - dimensions * 0.5, dimensions))
			var font := Style.font("display_bold")
			var pixels := 17 if narrow or short else 22
			var text_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
			draw_string(font, point + Vector2(-text_width * 0.5, pixels * 0.32), title, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, Color(Style.PEARL, alpha))
		if progress > 0.55:
			var spread := (progress - 0.55) / 0.45
			draw_circle(center, 10 + spread * 55, Color(Style.CYAN, (1 - spread) * 0.26))
			draw_arc(center, 12 + spread * 85, 0, TAU, 64, Color(Style.CYAN, 1 - spread), 3, true)
