class_name VeilAcademy
extends CanvasLayer
## Replaceable learning interface. It never writes to the mission simulation.
signal closed
var learning: VeilLearning
var art: VeilArtProfile
var interface_theme: Theme
var content: VBoxContainer
var heading: Label
var selected := 0
var question := 0
var hinted := false
var answered := false
var suggested_index := -1

func _ready() -> void:
	layer = 10
	var background := ColorRect.new()
	background.color = art.structure_color.darkened(0.55) if art else Color("101f2c")
	if interface_theme: background.theme = interface_theme
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]: margin.add_theme_constant_override("margin_" + side, 28)
	background.add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	show_map()

func clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func label(value: String, size: int = 22) -> Label:
	var item := Label.new()
	item.text = value
	item.add_theme_font_size_override("font_size", size)
	if art:
		item.add_theme_color_override("font_color", art.interface_text)
		if art.interface_font: item.add_theme_font_override("font", art.interface_font)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(item)
	return item

func action(value: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = value
	item.custom_minimum_size.y = 52
	item.add_theme_font_size_override("font_size", 21)
	if art:
		item.add_theme_color_override("font_color", art.interface_text)
		if art.interface_font: item.add_theme_font_override("font", art.interface_font)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.pressed.connect(callback)
	content.add_child(item)
	return item

func show_map() -> void:
	clear()
	label("MIRA’S FIELD ACADEMY", 34)
	label("Five small science lessons. Try a prediction, discover why, then use it on Mars.")
	label("Practice stays on this device. There are no scores to lose, timers, or daily streaks.", 18)
	var recommended := suggested_index if suggested_index >= 0 else learning.recommend()
	for index in range(learning.lessons.size()):
		var lesson: Dictionary = learning.lessons[index]
		var state: Dictionary = learning.skills[lesson.id]
		var status := "NEW" if state.attempts == 0 else ("REVIEW READY" if state.due <= Time.get_unix_time_from_system() else "PRACTISED")
		var prefix := "MIRA SUGGESTS  •  " if index == recommended else ""
		action("%s%d. %s  /  %s" % [prefix, index + 1, lesson.title, status], start_lesson.bind(index))
	if learning.save_error: label("Your progress could not be saved. You can still play and practise.", 18)
	action("BACK TO THE OUTPOST", close)
	action("RESET LOCAL PRACTICE…", confirm_reset)

func start_lesson(index: int) -> void:
	selected = index
	question = learning.question_index(index)
	hinted = false
	answered = false
	clear()
	var lesson: Dictionary = learning.lessons[index]
	var prompt: Dictionary = lesson.questions[question]
	label("FIELD LESSON %d / 5  •  %s" % [index + 1, lesson.title], 32)
	label(prompt.question, 26)
	var choices := range(prompt.options.size())
	choices.shuffle()
	for choice in choices:
		action(prompt.options[choice], submit.bind(choice))
	action("MIRA, GIVE ME A HINT", show_hint)
	action("BACK TO LESSONS", show_map)
	content.get_child(2).grab_focus()

func show_hint() -> void:
	if hinted or answered: return
	hinted = true
	label("MIRA: " + learning.lessons[selected].questions[question].hint, 21)
	label("Hints are welcome. This answer will be practice, not evidence for your review estimate.", 18)

func submit(choice: int) -> void:
	if answered: return
	answered = true
	var result := learning.answer(selected, question, choice, hinted)
	suggested_index = -1
	clear()
	label("YOU FOUND THE CONNECTION" if result.correct else "LET’S EXPLORE WHY", 32)
	label(result.explanation, 25)
	label("TRY IT ON MARS\n" + learning.lessons[selected].mission_tip, 22)
	if not result.evidence: label("Practice only: hints or repeating this question today do not increase the review estimate.", 18)
	if not result.saved: label("Progress could not be saved on this device. You can still continue.", 18)
	action("CONTINUE EXPLORING", show_map).grab_focus()
	action("BACK TO THE OUTPOST", close)

func confirm_reset() -> void:
	clear()
	label("START A FRESH PRACTICE LOG?", 30)
	label("This erases the academy answers and review plan on this device. It cannot be undone. Your mission report stays separate.")
	action("KEEP MY PRACTICE", show_map).grab_focus()
	action("ERASE LOCAL PRACTICE", func(): learning.reset(); show_map())

func close() -> void:
	closed.emit()
	queue_free()
