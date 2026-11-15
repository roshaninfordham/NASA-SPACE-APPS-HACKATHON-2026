extends VBoxContainer
## Read-only local learning journal. Counts come from JourneyProgress; opening
## this view never writes progress, changes the mission, or infers mastery.
const Style = preload("res://ui/journey_style.gd")
signal practice_requested
signal play_requested

var summary: Dictionary = {}
var practice_button: Button
var play_button: Button
var details_button: Button
var _stats: GridContainer
var _recent: VBoxContainer
var _details: VBoxContainer
var _built := false
var _stat_values: Dictionary = {}
var _stat_rows: Array[BoxContainer] = []
var _stat_captions: Array[Label] = []
var _mission_caption: Label
var _challenge_title: Label
var _challenge_detail: Label
var _history_note: Label
var _storage_note: Label
var _headline: Label

func _init(initial_summary: Dictionary = {}) -> void:
	summary = initial_summary.duplicate(true)

func configure(value: Dictionary) -> void:
	summary = value.duplicate(true)
	if _built: _refresh()

func _ready() -> void:
	name = "TrainingLog"
	theme = Style.theme()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",18)
	_headline = _text(self,"Your astronaut training",32,Style.PEARL,"display_bold")
	_headline.name = "TrainingHeading"
	_text(self,"Explore. Try a plan. Notice what changes.",20,Style.MUTED)
	_stats = GridContainer.new()
	_stats.name = "TrainingStats"
	_stats.add_theme_constant_override("h_separation",12)
	_stats.add_theme_constant_override("v_separation",10)
	add_child(_stats)
	for item in [["missions","Missions completed"],["ideas","Ideas explored"],["practice","First-try practice"]]:
		var card := _card(_stats)
		var row := BoxContainer.new()
		_stat_rows.append(row)
		row.add_theme_constant_override("separation",12)
		card.add_child(row)
		var value := _text(row,"0",34,Style.CYAN,"display_bold")
		value.name = "TrainingValue_"+item[0]
		value.custom_minimum_size.x = 88
		value.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_stat_values[item[0]] = value
		var caption := _text(row,item[1],19,Style.PEARL,"body_bold")
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_stat_captions.append(caption)
		if item[0] == "missions": _mission_caption = caption
	_text(self,"Exploring an idea isn’t a skill test.",18,Style.MUTED)
	var challenge := _card(self,true)
	challenge.name = "TrainingNextChallenge"
	var challenge_content := VBoxContainer.new()
	challenge_content.add_theme_constant_override("separation",6)
	challenge.add_child(challenge_content)
	_text(challenge_content,"YOUR NEXT CHALLENGE",15,Style.CYAN,"body_bold")
	_challenge_title = _text(challenge_content,"Try your first mission",25,Style.PEARL,"display_bold")
	_challenge_detail = _text(challenge_content,"Pick a cleaning pace and watch the panel change.",20,Style.PEARL)
	# A wrapping flow preserves 48px actions without narrow-phone overflow.
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation",10)
	actions.add_theme_constant_override("v_separation",10)
	add_child(actions)
	play_button = _button(actions,"Start a mission","TrainingPlay",true)
	practice_button = _button(actions,"Explore science","TrainingPractice")
	play_button.pressed.connect(func(): play_requested.emit())
	practice_button.pressed.connect(func(): practice_requested.emit())
	_text(self,"Your recent missions",25,Style.PEARL,"display_bold")
	_recent = VBoxContainer.new()
	_recent.name = "TrainingRecentMissions"
	_recent.add_theme_constant_override("separation",10)
	add_child(_recent)
	details_button = _button(self,"How this journal works","TrainingDetails")
	details_button.toggle_mode = true
	details_button.toggled.connect(_toggle_details)
	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation",10)
	_details.visible = false
	add_child(_details)
	_text(_details,"Ideas explored counts the science cards you opened and finished reading. It does not measure what you know.",19,Style.MUTED)
	_text(_details,"First-try practice counts correct first answers without help, out of the practice questions you answered. A retry helps you learn, but does not change that first answer.",19,Style.MUTED)
	_text(_details,"Try different plans, then compare panel cleaning and stored energy. These are game results, not a test of real astronaut readiness.",19,Style.MUTED)
	_history_note = _text(_details,"",19,Style.MUTED)
	_storage_note = _text(self,"",17,Style.MUTED)
	_storage_note.name = "TrainingStorageNote"
	resized.connect(_layout)
	_built = true
	_refresh()
	_layout()

func _text(parent: Node, value: String, text_size: int, tint: Color, face := "body") -> Label:
	var label := Style.label(value,text_size,tint,face)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _card(parent: Node, emphasis := false) -> PanelContainer:
	var panel := PanelContainer.new()
	var surface := Style.panel()
	surface.content_margin_left = 14
	surface.content_margin_right = 14
	surface.content_margin_top = 13
	surface.content_margin_bottom = 13
	if emphasis:
		surface.bg_color = Color("142a34")
		surface.border_color = Color(Style.CYAN,0.48)
	panel.add_theme_stylebox_override("panel",surface)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return panel

func _button(parent: Node, value: String, node_name: String, primary := false) -> Button:
	var button := Style.button(value,primary)
	button.name = node_name
	button.add_theme_font_size_override("font_size",20)
	button.custom_minimum_size.y = 50
	parent.add_child(button)
	return button

func _count(key: String, fallback := 0) -> int:
	var value: Variant = summary.get(key,fallback)
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return fallback
	return clampi(int(value),0,1000000)

func _metric(value: Variant, minimum: float, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

func _refresh() -> void:
	var missions := _count("completed_runs",_count("attempts"))
	var explored := mini(8,_count("reviewed_count"))
	var attempts := _count("practice_attempts")
	var correct := mini(attempts,_count("correct_first_unassisted"))
	_stat_values.missions.text = str(missions)
	_stat_values.ideas.text = "%d / 8" % explored
	_stat_values.practice.text = ("%d / %d" % [correct,attempts]) if attempts > 0 else "Not yet"
	_stat_values.practice.add_theme_font_size_override("font_size",34 if attempts > 0 else 25)
	_stat_values.missions.accessibility_description = "%d recorded completed missions" % missions
	_stat_values.ideas.accessibility_description = "%d of eight ideas explored, not a skill assessment" % explored
	_stat_values.practice.accessibility_description = "%d correct first answers without help out of %d answered practice questions" % [correct,attempts]
	var complete_history := bool(summary.get("counters_cover_all_history",true))
	_mission_caption.text = "Missions completed" if complete_history else "Missions recorded"
	_history_note.text = "This journal shows the five most recent results. The counters include your recorded mission history." if complete_history else "This profile came from an older version. Its counts cover the history still available; earlier missions may be missing. Unrecorded details stay blank."
	_storage_note.text = "Saved on this device. No account needed." if bool(summary.get("storage_available",false)) else "This session only — saving is unavailable."
	play_button.text = "Start a mission" if missions == 0 else "Try a new plan"
	var focus: Variant = summary.get("suggested_focus",{})
	if focus is Dictionary:
		_challenge_title.text = str(focus.get("title","Try your first mission")).strip_edges().left(120)
		_challenge_detail.text = str(focus.get("detail","Pick a cleaning pace and watch the panel change.")).strip_edges().left(400)
	else:
		_challenge_title.text = "Try your first mission"
		_challenge_detail.text = "Pick a cleaning pace and watch the panel change."
	_challenge_detail.visible = not _challenge_detail.text.is_empty()
	for child in _recent.get_children():
		_recent.remove_child(child)
		child.queue_free()
	var recent: Variant = summary.get("recent_results",[])
	var shown := 0
	if recent is Array:
		for item in recent:
			if not item is Dictionary: continue
			_recent_card(item,shown)
			shown += 1
			if shown == 5: break
	if shown == 0:
		var empty := _card(_recent)
		_text(empty,"Your first completed mission will appear here.",20,Style.MUTED)
	_layout()

func _recent_card(result: Dictionary, index: int) -> void:
	var card := _card(_recent)
	card.name = "TrainingAttempt_"+str(index)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	card.add_child(content)
	var status := str(result.get("status",""))
	var outcome: String = {"win":"WIN","pass":"PASS","lose":"TRY AGAIN"}.get(status,"PREVIOUS MISSION")
	var position_text := "Latest mission" if index == 0 else ("1 mission ago" if index == 1 else "%d missions ago" % index)
	_text(content,position_text+" · "+outcome,21,Style.PEARL,"display_bold")
	var clean: Variant = result.get("clean_fraction")
	var energy: Variant = result.get("battery_kwh")
	var cleaning_known := _metric(clean,0.0,1.0)
	var metrics := HFlowContainer.new()
	metrics.add_theme_constant_override("h_separation",24)
	metrics.add_theme_constant_override("v_separation",4)
	content.add_child(metrics)
	var clean_label := _text(metrics,("Panel clean  %.1f%%" % (floorf(float(clean)*1000.0+0.000001)/10.0)) if cleaning_known else "Panel clean  Not recorded",19,Style.CYAN,"body_bold")
	clean_label.name = "AttemptClean_"+str(index)
	clean_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	var energy_label := _text(metrics,("Energy  %.2f kWh" % float(energy)) if _metric(energy,0.0,1000000.0) else "Energy  Not recorded",19,Style.PEARL,"body_bold")
	energy_label.name = "AttemptEnergy_"+str(index)
	energy_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if cleaning_known:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.value = float(clean)
		bar.custom_minimum_size.y = 8
		bar.accessibility_name = "Panel cleaned"
		bar.accessibility_description = "%.1f percent" % (float(clean)*100.0)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(bar)

func _toggle_details(expanded: bool) -> void:
	_details.visible = expanded
	details_button.text = "Hide journal details" if expanded else "How this journal works"
	details_button.accessibility_description = "Journal explanation expanded" if expanded else "Expand the journal explanation"

func _layout() -> void:
	if not _built: return
	var wide := size.x >= 580.0
	_stats.columns = 3 if wide else 1
	for row in _stat_rows: row.vertical = wide
	for caption in _stat_captions: caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if wide else HORIZONTAL_ALIGNMENT_LEFT
	_headline.add_theme_font_size_override("font_size",28 if size.x < 360.0 else 32)
