extends RefCounted
## Small local preferences/review record. No identity, medical data or telemetry.
const DEFAULT_PATH := "user://journey-progress.json"
const PROFILE_KIND := "komaku-journey-progress"
const SCHEMA_VERSION := 3
const MAX_BYTES := 65536
const MAX_RUNS := 30
const LEGACY_MAX_RUNS := 10
const MAX_TRAINING_COUNT := 1000000000
const CONCEPT_IDS := ["radiation", "dose", "sievert", "dust", "power", "time", "speed", "shelter"]
const LEGACY_SETTING_KEYS := ["music_enabled", "effects_enabled", "music_volume", "effects_volume", "soundtrack", "reduced_motion", "pace"]
const DEFAULT_SETTINGS := {
	"music_enabled": true,
	"effects_enabled": true,
	"music_volume": 0.35,
	"effects_volume": 0.55,
	"soundtrack": "supplied",
	"reduced_motion": false,
	"pace": 1.0,
	"mission_view": "science",
}
const QUIZ_ID := "pace-fatigue-transfer-1"
const PREVIOUS_QUIZ_ID := "cleaning-rate-transfer-1"
const LEGACY_QUIZ_ID := "return-time-transfer-1"
const RUN_FIELDS := ["status", "elapsed_seconds", "sim_elapsed_seconds", "sections_cleaned", "dose_ugy", "quiz", "clean_fraction", "battery_kwh", "max_fatigue", "pace_changes", "ended_at"]
const LEGACY_RUN_FIELDS := ["status", "elapsed_seconds", "sim_elapsed_seconds", "sections_cleaned", "dose_ugy", "quiz"]
const TRAINING_FIELDS := ["completed_runs", "wins", "question_id", "practice_attempts", "correct_first_unassisted", "history_complete"]

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var reviewed_ids: Array[String] = []
var runs: Array[Dictionary] = []
var _training: Dictionary = _empty_training()
var last_error := ""
var storage_available := true
var _path := DEFAULT_PATH
var _loaded_existed := false
var _expected_hash := ""
var _write_allowed := true

func _init(path_override: String = "") -> void:
	load_data(path_override)

func load_data(path_override: String = "") -> bool:
	settings = DEFAULT_SETTINGS.duplicate(true)
	reviewed_ids.clear()
	runs.clear()
	_training = _empty_training()
	last_error = ""
	storage_available = true
	_write_allowed = true
	_loaded_existed = false
	_expected_hash = ""
	_path = DEFAULT_PATH if path_override.is_empty() else path_override
	if not _safe_path(_path): return _block("The local progress path is unavailable.")
	if not FileAccess.file_exists(_path): return true
	_loaded_existed = true
	var read := _read_file(_path)
	if not read.get("ok", false): return _block("Local progress could not be read safely. The existing file was kept.")
	var parser := JSON.new()
	if parser.parse(read.bytes.get_string_from_utf8()) != OK:
		return _block("Local progress was not recognized. Defaults are active and the existing file was kept.")
	var value: Variant = parser.data
	if not _valid_payload(value, true): return _block("Local progress was not recognized. Defaults are active and the existing file was kept.")
	# Older profiles migrate in memory only. Their retained ten-run history is
	# a lower bound: activity already dropped by old versions is unknowable.
	# Keep the original file fingerprint until an ordinary save writes schema 3.
	settings.merge(value.settings.duplicate(true), true)
	for id: String in value.reviewed_ids: reviewed_ids.append(id)
	var legacy := int(value.schema_version) < SCHEMA_VERSION
	for item: Dictionary in value.runs: runs.append(_normalize_run(item, true, legacy))
	if legacy:
		_training.history_complete = false
		for item: Dictionary in runs: _count_run(_training, item)
	else:
		_training = value.training.duplicate(true)
	_expected_hash = _hash(read.bytes)
	return true

func set_setting(key: String, value: Variant) -> bool:
	if not DEFAULT_SETTINGS.has(key) or not _valid_setting(key, value):
		last_error = "That setting is not supported."
		return false
	settings[key] = value
	return save_data()

func record_reviewed(ids: Array) -> bool:
	if ids.size() > CONCEPT_IDS.size():
		last_error = "The reviewed-concept list is invalid."
		return false
	for id in ids:
		if not id is String or not id in CONCEPT_IDS:
			last_error = "The reviewed-concept list is invalid."
			return false
	for id: String in ids:
		if not reviewed_ids.has(id): reviewed_ids.append(id)
	return save_data()

func record_result(result: Dictionary, quiz: Dictionary = {}) -> bool:
	var item := _normalize_run(result, false)
	if item.is_empty():
		last_error = "Only a completed, valid mission summary can be saved."
		return false
	var checked_quiz := _normalize_quiz(quiz)
	if checked_quiz.is_empty():
		last_error = "The practice answer could not be saved."
		return false
	item.quiz = checked_quiz
	if int(_training.completed_runs) >= MAX_TRAINING_COUNT:
		last_error = "The local training counter is full; existing progress was kept."
		return false
	_count_run(_training, item)
	runs.append(item)
	while runs.size() > MAX_RUNS: runs.pop_front()
	return save_data()

func save_data() -> bool:
	if not _write_allowed or not _safe_path(_path):
		return _block("Progress is kept in memory only; the existing local file was not changed.")
	var payload := {"kind": PROFILE_KIND, "schema_version": SCHEMA_VERSION, "settings": settings.duplicate(true), "reviewed_ids": reviewed_ids.duplicate(), "runs": runs.duplicate(true), "training": _training.duplicate(true)}
	if not _valid_payload(payload):
		last_error = "Invalid local data was not written."
		return false
	# A second game window or an external editor must not be silently overwritten.
	if not _disk_matches_loaded_file(): return _block("Local progress changed in another window. The newer file was kept.")
	# Preserve exact finite model measurements through JSON round trips.
	var bytes := (JSON.stringify(payload, "  ", true, true) + "\n").to_utf8_buffer()
	if bytes.size() > MAX_BYTES:
		last_error = "Local progress is too large to save."
		return false
	var temporary := _new_temporary_path()
	if temporary.is_empty(): return _block("A temporary progress file could not be created.")
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _block("Progress cannot be saved here; this session can continue in memory.")
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return _block("The progress write did not complete; the previous file was kept.")
	var staged := _read_file(temporary)
	if not staged.get("ok", false) or staged.bytes != bytes or not _disk_matches_loaded_file():
		DirAccess.remove_absolute(temporary)
		return _block("Progress could not be verified; the previous file was kept.")
	# Same-directory rename publishes only the fully written document. It is not
	# a promise of durable storage after physical power loss on every filesystem.
	if DirAccess.rename_absolute(temporary, _path) != OK:
		DirAccess.remove_absolute(temporary)
		return _block("Progress could not be replaced; the previous file was kept.")
	_loaded_existed = true
	_expected_hash = _hash(bytes)
	last_error = ""
	storage_available = true
	return true

func training_summary() -> Dictionary:
	# Callers receive detached values, never references that can edit history.
	# Opening a concept is exploration, not evidence of a tested skill.
	var recent: Array[Dictionary] = []
	for index in range(runs.size()-1, maxi(-1,runs.size()-6), -1):
		recent.append(runs[index].duplicate(true))
	var summary := {
		"attempts": int(_training.completed_runs), "completed_runs": int(_training.completed_runs),
		"wins": int(_training.wins), "reviewed_count": reviewed_ids.size(), "reviewed_ids": reviewed_ids.duplicate(),
		"practiced": int(_training.correct_first_unassisted) > 0,
		"practice_attempts": int(_training.practice_attempts), "correct_first_unassisted": int(_training.correct_first_unassisted),
		"question_id": QUIZ_ID, "recent_results": recent, "history_available": runs.size(), "history_limit": MAX_RUNS,
		"counters_cover_all_history": bool(_training.history_complete), "storage_available": storage_available,
		"suggested_focus": _suggested_focus(),
	}
	return summary

func _suggested_focus() -> Dictionary:
	if int(_training.completed_runs) == 0:
		return {"id":"first_mission","title":"Try your first mission","detail":"Start with a steady cleaning pace. Watch how clearing dust changes the energy stored."}
	if int(_training.practice_attempts) == 0:
		return {"id":"try_practice","title":"Connect what changed","detail":"After a mission, try the optional question about cleaning pace and tiredness."}
	if int(_training.correct_first_unassisted) == 0:
		return {"id":"pace_and_fatigue","title":"Explore pace and tiredness","detail":"Try a steady pace, then compare it with a faster plan. Faster cleaning can build tiredness in this game."}
	return {"id":"predict_then_test","title":"Make a prediction","detail":"Predict what a different cleaning pace will change. Play again, then compare panel cleaning and stored energy."}

static func _empty_training() -> Dictionary:
	return {"completed_runs":0,"wins":0,"question_id":QUIZ_ID,"practice_attempts":0,"correct_first_unassisted":0,"history_complete":true}

static func _count_run(training: Dictionary, item: Dictionary) -> void:
	training.completed_runs += 1
	# "success" preserves the historical mission's successful outcome; it is
	# not regraded against the newer cleaning mission's threshold.
	if item.status in ["win", "success"]: training.wins += 1
	if item.quiz.question_id == QUIZ_ID and item.quiz.answered:
		training.practice_attempts += 1
		if item.quiz.correct and not item.quiz.assisted: training.correct_first_unassisted += 1

func _block(message: String) -> bool:
	last_error = message
	storage_available = false
	_write_allowed = false
	return false

func _disk_matches_loaded_file() -> bool:
	if not _safe_path(_path): return false
	var exists := FileAccess.file_exists(_path)
	if exists != _loaded_existed: return false
	if not exists: return true
	var read := _read_file(_path)
	return read.get("ok", false) and _hash(read.bytes) == _expected_hash

func _new_temporary_path() -> String:
	var folder := _path.get_base_dir()
	for attempt in range(4):
		var suffix := Crypto.new().generate_random_bytes(12).hex_encode()
		if suffix.length() != 24: return ""
		var path := folder.path_join(".journey-save-" + suffix + ".tmp")
		var directory := DirAccess.open(folder)
		if directory != null and not directory.file_exists(path) and not directory.dir_exists(path) and not directory.is_link(path): return path
	return ""

static func _safe_path(path: String) -> bool:
	if not path.begins_with("user://") or path.length() > 240 or "\\" in path or path.to_utf8_buffer().has(0): return false
	var relative := path.trim_prefix("user://")
	if relative.is_empty() or not relative.ends_with(".json"): return false
	var parts := relative.split("/", true)
	var current := "user://"
	for index in range(parts.size()):
		var part: String = parts[index]
		if part.is_empty() or part in [".", ".."] or ":" in part: return false
		var directory := DirAccess.open(current)
		if directory == null or directory.is_link(part): return false
		current = current.path_join(part)
		if index < parts.size() - 1:
			if not DirAccess.dir_exists_absolute(current): return false
		elif DirAccess.dir_exists_absolute(current): return false
	return true

static func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false}
	var length := file.get_length()
	if length <= 0 or length > MAX_BYTES:
		file.close()
		return {"ok": false}
	var bytes := file.get_buffer(length)
	file.close()
	return {"ok": bytes.size() == length, "bytes": bytes}

static func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK: return ""
	return context.finish().hex_encode()

static func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key in value:
		if not key in expected: return false
	return true

static func _number(value: Variant, minimum: float, maximum: float, integer := false) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)): return false
	if float(value) < minimum or float(value) > maximum: return false
	return not integer or float(value) == floor(float(value))

static func _valid_setting(key: String, value: Variant) -> bool:
	match key:
		"music_enabled", "effects_enabled", "reduced_motion": return value is bool
		"music_volume", "effects_volume": return _number(value, 0.0, 1.0)
		"pace": return _number(value, 0.5, 2.0) and float(value) in [0.5, 1.0, 2.0]
		"soundtrack": return value is String and value in ["supplied", "original"]
		"mission_view": return value is String and value in ["science", "focus"]
	return false

static func _normalize_quiz(value: Dictionary, allow_legacy := false) -> Dictionary:
	if value.is_empty(): return {"question_id": QUIZ_ID, "first_answer": -1, "answered": false, "correct": false, "assisted": false}
	var question: Variant = value.get("question_id")
	if question != QUIZ_ID and not (allow_legacy and question in [LEGACY_QUIZ_ID, PREVIOUS_QUIZ_ID]): return {}
	if not _number(value.get("first_answer"), -1, 2, true): return {}
	var answer := int(value.first_answer)
	if not value.get("answered") is bool or not value.get("correct") is bool or not value.get("assisted") is bool: return {}
	if value.answered != (answer >= 0) or value.correct != (answer == 0): return {}
	return {"question_id": question, "first_answer": answer, "answered": answer >= 0, "correct": answer == 0, "assisted": value.assisted}

static func _normalize_run(value: Dictionary, from_disk: bool, legacy := false) -> Dictionary:
	if from_disk and not _exact_keys(value, LEGACY_RUN_FIELDS if legacy else RUN_FIELDS): return {}
	if value.get("status") not in ["success", "power-shortfall", "late", "win", "pass", "lose"]: return {}
	if not _number(value.get("elapsed_seconds"), 0.0, 1728000.0): return {}
	if not _number(value.get("sim_elapsed_seconds"), 0.0, 86400.0): return {}
	if not _number(value.get("sections_cleaned"), 0, 12, true): return {}
	if not _number(value.get("dose_ugy"), 0.0, 1000000.0): return {}
	var quiz: Dictionary = {}
	if from_disk:
		if not value.get("quiz") is Dictionary: return {}
		if not _exact_keys(value.quiz, ["question_id", "first_answer", "answered", "correct", "assisted"]): return {}
		quiz = _normalize_quiz(value.quiz, true)
		if quiz.is_empty(): return {}
	else:
		quiz = _normalize_quiz({})
	var item := {"status": value.status, "elapsed_seconds": float(value.elapsed_seconds), "sim_elapsed_seconds": float(value.sim_elapsed_seconds), "sections_cleaned": int(value.sections_cleaned), "dose_ugy": float(value.dose_ugy), "quiz": quiz}
	for field in ["clean_fraction", "battery_kwh", "max_fatigue", "pace_changes", "ended_at"]:
		var metric: Variant = value.get(field)
		if metric != null:
			var upper := 1.0
			if field in ["battery_kwh", "pace_changes"]: upper = 1000000.0
			elif field == "ended_at": upper = 32503680000.0
			if not _number(metric, 0.0, upper, field in ["pace_changes", "ended_at"]): return {}
			item[field] = int(metric) if field in ["pace_changes", "ended_at"] else float(metric)
		else:
			item[field] = null
	if not from_disk and not value.has("ended_at"):
		var now := int(Time.get_unix_time_from_system())
		item.ended_at = now if now >= 0 and now <= 32503680000 else null
	return item

static func _valid_training(value: Variant, history: Array) -> bool:
	if not value is Dictionary or not _exact_keys(value, TRAINING_FIELDS): return false
	if value.question_id != QUIZ_ID or not value.history_complete is bool: return false
	for field in ["completed_runs", "wins", "practice_attempts", "correct_first_unassisted"]:
		if not _number(value[field], 0, MAX_TRAINING_COUNT, true): return false
	if value.wins > value.completed_runs or value.practice_attempts > value.completed_runs or value.correct_first_unassisted > value.practice_attempts: return false
	var observed := _empty_training()
	for item: Dictionary in history: _count_run(observed, item)
	for field in ["completed_runs", "wins", "practice_attempts", "correct_first_unassisted"]:
		if value[field] < observed[field]: return false
	return true

static func _valid_payload(value: Variant, allow_legacy := false) -> bool:
	if not value is Dictionary or not _number(value.get("schema_version"), 1 if allow_legacy else SCHEMA_VERSION, SCHEMA_VERSION, true): return false
	var legacy := int(value.schema_version) < SCHEMA_VERSION
	var root_fields := ["kind", "schema_version", "settings", "reviewed_ids", "runs"]
	if not legacy: root_fields.append("training")
	if not _exact_keys(value, root_fields) or value.kind != PROFILE_KIND: return false
	var expected_keys: Array = LEGACY_SETTING_KEYS if value.schema_version == 1 else DEFAULT_SETTINGS.keys()
	if not value.settings is Dictionary or not _exact_keys(value.settings, expected_keys): return false
	for key: String in expected_keys:
		if not _valid_setting(key, value.settings[key]): return false
	if not value.reviewed_ids is Array or value.reviewed_ids.size() > CONCEPT_IDS.size(): return false
	var seen: Array[String] = []
	for id in value.reviewed_ids:
		if not id is String or not id in CONCEPT_IDS or seen.has(id): return false
		seen.append(id)
	if not value.runs is Array or value.runs.size() > (LEGACY_MAX_RUNS if legacy else MAX_RUNS): return false
	for item in value.runs:
		if not item is Dictionary or _normalize_run(item, true, legacy).is_empty(): return false
	if not legacy and not _valid_training(value.training, value.runs): return false
	return true
