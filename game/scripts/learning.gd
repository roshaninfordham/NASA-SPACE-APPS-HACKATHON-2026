class_name VeilLearning
extends RefCounted
## Small, inspectable local tutor. Estimates guide review; they are not ability grades.
const SCHEMA := 1
const DAY := 86400
const MAX_BYTES := 65536
const PRIOR := 0.2
const GUESS := 0.25
const SLIP := 0.1
const LEARN := 0.12
var lessons: Array = []
var skills: Dictionary = {}
var storage_path: String
var save_error := false

func _init(path: String = "user://learning-progress.json") -> void:
	storage_path = path
	lessons = JSON.parse_string(FileAccess.get_file_as_string("res://data/lessons.json"))
	load_progress()

func fresh_skill() -> Dictionary:
	return {"estimate": PRIOR, "attempts": 0, "correct": 0, "due": 0, "items": {}}

func load_progress() -> void:
	skills.clear()
	for lesson in lessons: skills[lesson.id] = fresh_skill()
	var saved := read_profile(storage_path)
	if saved.is_empty(): saved = read_profile(storage_path + ".backup")
	if saved.is_empty(): return
	for id in skills:
		if saved.skills.has(id): skills[id] = saved.skills[id]

func read_profile(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary or parsed.get("schema") != SCHEMA or not parsed.get("skills") is Dictionary: return {}
	for lesson in lessons:
		if not parsed.skills.has(lesson.id): continue
		var item: Variant = parsed.skills[lesson.id]
		if not item is Dictionary: return {}
		for field in ["estimate", "attempts", "correct", "due"]:
			if not item.get(field) is float and not item.get(field) is int: return {}
			if not is_finite(float(item[field])): return {}
		if item.estimate < 0 or item.estimate > 1 or item.attempts < 0 or item.correct < 0 or item.correct > item.attempts or item.due < 0: return {}
		if item.attempts > 1000000 or item.attempts != floor(item.attempts) or item.correct != floor(item.correct): return {}
		if not item.get("items") is Dictionary or item.items.size() > lesson.questions.size(): return {}
		for key in item.items:
			if not str(key).is_valid_int() or int(key) < 0 or int(key) >= lesson.questions.size(): return {}
			var timestamp: Variant = item.items[key]
			if not (timestamp is float or timestamp is int) or not is_finite(float(timestamp)) or timestamp < 0: return {}
	return parsed

func save_progress() -> bool:
	var pending := storage_path + ".pending"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		save_error = true
		return false
	file.store_string(JSON.stringify({"schema": SCHEMA, "skills": skills}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		save_error = true
		return false
	# Preserve the last valid profile, including after recovery from a corrupt primary.
	if not read_profile(storage_path).is_empty():
		if DirAccess.copy_absolute(storage_path, storage_path + ".backup") != OK:
			save_error = true
			return false
	save_error = DirAccess.rename_absolute(pending, storage_path) != OK
	return not save_error

func reset() -> bool:
	# Explicit user action. Remove backup as well so erased progress cannot reappear.
	var removed := true
	for suffix in ["", ".backup", ".pending"]:
		var path: String = storage_path + suffix
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK: removed = false
	skills.clear()
	for lesson in lessons: skills[lesson.id] = fresh_skill()
	save_error = not removed
	return removed

func recommend(now: int = int(Time.get_unix_time_from_system())) -> int:
	# Practise a new concept before optional review; then choose most overdue.
	for index in range(lessons.size()):
		if skills[lessons[index].id].attempts == 0: return index
	var best := 0
	for index in range(1, lessons.size()):
		var current: Dictionary = skills[lessons[index].id]
		var chosen: Dictionary = skills[lessons[best].id]
		if minf(current.due - now, DAY * 30) < minf(chosen.due - now, DAY * 30): best = index
	return best

func question_index(lesson_index: int) -> int:
	var lesson: Dictionary = lessons[lesson_index]
	var item: Dictionary = skills[lesson.id]
	var oldest := 0
	for index in range(lesson.questions.size()):
		if not item.items.has(str(index)): return index
		if item.items[str(index)] < item.items.get(str(oldest), 0): oldest = index
	return oldest

func mission_recommendation(status: String) -> int:
	# Gameplay outcomes select support, never infer mastery from winning or losing.
	var focus := {"suit-abort": "energy", "dose-abort": "shelter", "power-abort": "reserve", "partial": "dust"}
	if focus.has(status):
		for index in range(lessons.size()):
			if lessons[index].id == focus[status]: return index
	return recommend()

static func update_estimate(prior: float, correct: bool) -> float:
	var known := prior * ((1.0 - SLIP) if correct else SLIP)
	var unknown := (1.0 - prior) * (GUESS if correct else (1.0 - GUESS))
	var posterior := known / maxf(known + unknown, 0.000001)
	return clampf(posterior + (1.0 - posterior) * LEARN, 0.01, 0.99)

func answer(lesson_index: int, question: int, choice: int, hinted: bool, now: int = int(Time.get_unix_time_from_system())) -> Dictionary:
	if lesson_index < 0 or lesson_index >= lessons.size(): return {"accepted": false}
	var lesson: Dictionary = lessons[lesson_index]
	if question < 0 or question >= lesson.questions.size(): return {"accepted": false}
	var prompt: Dictionary = lesson.questions[question]
	if choice < 0 or choice >= prompt.options.size(): return {"accepted": false}
	var correct: bool = choice == int(prompt.answer)
	var skill: Dictionary = skills[lesson.id]
	var key := str(question)
	var repeated: bool = skill.items.has(key) and now - int(skill.items[key]) < DAY
	var evidence := not hinted and not repeated
	if evidence:
		skill.estimate = update_estimate(skill.estimate, correct)
		skill.attempts = mini(int(skill.attempts) + 1, 1000000)
		if correct: skill.correct = mini(int(skill.correct) + 1, int(skill.attempts))
		skill.items[key] = now
		var days := 1 if not correct or skill.estimate < 0.55 else (3 if skill.estimate < 0.8 else 7)
		skill.due = now + days * DAY
		save_progress()
	return {"accepted": true, "correct": correct, "evidence": evidence, "saved": not save_error, "explanation": prompt.explanation}
