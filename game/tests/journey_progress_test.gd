extends SceneTree
const Progress = preload("res://scripts/journey_progress.gd")
const Mission = preload("res://scripts/pace_mission.gd")
var failures := 0
var assertions := 0
var test_dir := ""

func check(value: bool, message: String) -> void:
	assertions += 1
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check(false, "Test fixture could be written: " + path)
		return
	file.store_string(text)
	file.close()

func read_text(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func sample_result(seconds := 210.0) -> Dictionary:
	return {"status": "success", "elapsed_seconds": seconds, "sim_elapsed_seconds": 1260.0, "sections_cleaned": 2, "dose_ugy": 3.0625}

func quiz(answer: int) -> Dictionary:
	return {"question_id": "pace-fatigue-transfer-1", "first_answer": answer, "answered": answer >= 0, "correct": answer == 0, "assisted": false}

func assert_rejected_file(name: String, contents: String) -> void:
	var path := test_dir.path_join(name + ".json")
	write_text(path, contents)
	var store = Progress.new(path)
	check(not store.storage_available and not store.last_error.is_empty(), name + ": corrupt or foreign file reports unavailable storage")
	check(store.settings.music_enabled and store.settings.pace == 1.0 and store.reviewed_ids.is_empty() and store.runs.is_empty(), name + ": safe defaults stay usable")
	check(not store.record_reviewed(["radiation"]) and store.reviewed_ids == ["radiation"], name + ": unsaved session learning remains usable")
	check(not store.set_setting("music_enabled", false) and not store.settings.music_enabled, name + ": in-memory settings remain usable")
	check(read_text(path) == contents, name + ": unrelated or damaged original remains byte-for-byte intact")

func _initialize() -> void:
	test_dir = "user://journey-progress-tests-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	check(DirAccess.make_dir_absolute(test_dir) == OK, "Isolated test directory is created")
	var path := test_dir.path_join("profile.json")
	var store = Progress.new(path)
	check(store.storage_available and store.last_error.is_empty() and not FileAccess.file_exists(path), "Missing progress loads defaults without eagerly creating a file")
	check(store.settings == {"music_enabled": true, "effects_enabled": true, "music_volume": 0.35, "effects_volume": 0.55, "soundtrack": "supplied", "reduced_motion": false, "pace": 1.0}, "First-run settings use audible, standard-pace defaults")
	check(store.save_data(), "Initial settings save atomically")
	var initial_bytes := read_text(path)
	var initial: Dictionary = JSON.parse_string(initial_bytes)
	check(initial.kind == "komaku-journey-progress" and initial.schema_version == 1, "Progress has a dedicated schema discriminator")
	check(initial.reviewed_ids.is_empty() and initial.runs.is_empty(), "Empty reviews and results round-trip")
	check(store.set_setting("music_enabled", false) and store.set_setting("effects_enabled", false) and store.set_setting("reduced_motion", true), "Boolean accessibility and audio settings save")
	check(store.set_setting("music_volume", 0.0) and store.set_setting("effects_volume", 1.0), "Volume endpoints are valid")
	check(store.set_setting("soundtrack", "original") and Progress.new(path).settings.soundtrack == "original", "Original soundtrack choice persists")
	check(store.set_setting("soundtrack", "supplied") and Progress.new(path).settings.soundtrack == "supplied", "Supplied soundtrack choice persists")
	for pace in [0.5, 1.0, 2.0]:
		check(store.set_setting("pace", pace) and Progress.new(path).settings.pace == pace, "Supported pace persists: " + str(pace))
	var before: Dictionary = store.settings.duplicate(true)
	var before_file := read_text(path)
	for setting in [["unknown", true], ["music_enabled", 1], ["effects_enabled", "true"], ["reduced_motion", null], ["music_volume", -0.01], ["effects_volume", 1.01], ["music_volume", NAN], ["effects_volume", INF], ["pace", 1.5], ["pace", true], ["soundtrack", "unknown"], ["soundtrack", true]]:
		check(not store.set_setting(setting[0], setting[1]), "Invalid setting is rejected: " + str(setting[0]) + " = " + str(setting[1]))
	check(store.settings == before and read_text(path) == before_file, "Rejected settings do not mutate memory or disk")
	check(store.record_reviewed(["radiation", "dose", "radiation"]) and store.reviewed_ids == ["radiation", "dose"], "Repeated review IDs are unioned once")
	check(not store.record_reviewed(["unknown"]) and not store.record_reviewed([4]), "Unknown and non-string concepts are rejected")
	check(not store.record_reviewed(["radiation", "radiation", "radiation", "radiation", "radiation", "radiation", "radiation", "radiation", "radiation"]), "Oversize review input is rejected before processing")
	check(store.record_reviewed(["sievert", "dust", "power", "time", "speed", "shelter"]), "All eight current concepts can be recorded")
	check(Progress.new(path).reviewed_ids.size() == 8, "Complete concept readiness survives reopening")

	var model = Mission.new()
	model.advance(300.0)
	var full_result: Dictionary = model.result()
	full_result["personal_note"] = "not allowed in the save"
	var answer := quiz(0)
	answer["untrusted_extra"] = {"identity": "must be discarded"}
	check(store.record_result(full_result, answer), "Actual mission result and quiz are accepted")
	check(store.runs.size() == 1 and store.runs[0].size() == 6 and not store.runs[0].has("history") and not store.runs[0].has("personal_note"), "Only six bounded run-summary fields are retained")
	check(store.runs[0].quiz.size() == 5 and not store.runs[0].quiz.has("untrusted_extra"), "Quiz drops arbitrary input fields")
	full_result.dose_ugy = 999
	answer.first_answer = 2
	check(is_equal_approx(store.runs[0].dose_ugy, 10.9375) and store.runs[0].quiz.first_answer == 0, "Stored summary is detached from caller dictionaries")
	check(not read_text(path).contains("personal_note") and not read_text(path).contains("identity"), "Unapproved data never reaches the save file")
	check(store.record_result(sample_result(), quiz(1)) and not store.runs[-1].quiz.correct, "Incorrect first answer is recorded honestly")
	check(store.record_result(sample_result()) and not store.runs[-1].quiz.answered and store.runs[-1].quiz.first_answer == -1, "Skipping practice preserves an unanswered state")
	var legacy_quiz := quiz(0)
	legacy_quiz.question_id = "return-time-transfer-1"
	check(not store.record_result(sample_result(), legacy_quiz), "New records cannot use the retired walking quiz")
	var legacy_payload: Dictionary = initial.duplicate(true)
	var legacy_row := sample_result()
	legacy_row.quiz = legacy_quiz
	legacy_payload.runs = [legacy_row]
	var legacy_path := test_dir.path_join("legacy.json")
	write_text(legacy_path, JSON.stringify(legacy_payload))
	var legacy = Progress.new(legacy_path)
	check(legacy.storage_available and legacy.runs[0].quiz.question_id == "return-time-transfer-1", "Historical quiz records retain their original meaning on load")
	check(legacy.record_result(sample_result(), quiz(0)) and Progress.new(legacy_path).runs.size() == 2, "Old and new quiz versions remain readable together")
	legacy_payload.runs[0].quiz.question_id = "cleaning-rate-transfer-1"
	var previous_path := test_dir.path_join("previous-cleaning.json")
	write_text(previous_path, JSON.stringify(legacy_payload))
	var previous = Progress.new(previous_path)
	check(previous.storage_available and previous.runs[0].quiz.question_id == "cleaning-rate-transfer-1", "Prior cleaning quiz retains its original meaning after the fatigue pivot")
	check(not previous.record_result(sample_result(), legacy_payload.runs[0].quiz), "New quiz records cannot pretend to answer a retired cleaning question")
	var bad_quiz := quiz(1)
	bad_quiz.correct = true
	check(not store.record_result(sample_result(), bad_quiz), "Forged correct flag is rejected")
	bad_quiz = quiz(0)
	bad_quiz.question_id = "other"
	check(not store.record_result(sample_result(), bad_quiz), "Unknown quiz question is rejected")
	bad_quiz = quiz(0)
	bad_quiz.assisted = "no"
	check(not store.record_result(sample_result(), bad_quiz), "Wrong quiz boolean type is rejected")
	for field in [["status", "running"], ["elapsed_seconds", -1], ["sim_elapsed_seconds", INF], ["sections_cleaned", 2.5], ["sections_cleaned", 13], ["dose_ugy", NAN], ["dose_ugy", "3.0"], ["elapsed_seconds", true]]:
		var invalid := sample_result()
		invalid[field[0]] = field[1]
		check(not store.record_result(invalid), "Invalid run field is rejected: " + str(field[0]) + " = " + str(field[1]))
	check(store.runs.size() == 3, "All invalid results leave prior run count intact")
	for index in range(12):
		check(store.record_result(sample_result(100.0 + index)), "History run " + str(index) + " saves")
	check(store.runs.size() == 10 and store.runs[0].elapsed_seconds == 102.0 and store.runs[-1].elapsed_seconds == 111.0, "Only the last ten runs are kept in chronological order")
	var reopened = Progress.new(path)
	check(reopened.storage_available and reopened.settings == store.settings and reopened.reviewed_ids == store.reviewed_ids and reopened.runs == store.runs, "Complete valid local state round-trips")
	var saved_file := read_text(path)
	store.settings["extra"] = "forbidden"
	check(not store.save_data() and read_text(path) == saved_file, "Direct invalid mutation cannot bypass payload validation")
	store.settings.erase("extra")
	store.runs[0]["dose_ugy"] = -1
	check(not store.save_data() and read_text(path) == saved_file, "Direct invalid nested run mutation cannot corrupt disk")

	assert_rejected_file("malformed", "{not JSON}")
	assert_rejected_file("empty", "")
	assert_rejected_file("oversize", "x".repeat(65537))
	assert_rejected_file("foreign", JSON.stringify({"name": "unrelated document"}))
	for mutation in ["wrong-kind", "wrong-version", "boolean-version", "wrong-setting-type", "extra-setting", "duplicate-review", "unknown-review", "extra-root", "oversize-history", "bad-run", "extra-quiz"]:
		var payload: Dictionary = initial.duplicate(true)
		match mutation:
			"wrong-kind": payload.kind = "something-else"
			"wrong-version": payload.schema_version = 2
			"boolean-version": payload.schema_version = true
			"wrong-setting-type": payload.settings.music_enabled = 1
			"extra-setting": payload.settings["tracking"] = true
			"duplicate-review": payload.reviewed_ids = ["dose", "dose"]
			"unknown-review": payload.reviewed_ids = ["mystery"]
			"extra-root": payload["personal_data"] = {}
			"oversize-history":
				for index in range(11):
					var row := sample_result()
					row.quiz = quiz(-1)
					payload.runs.append(row)
			"bad-run":
				var row := sample_result()
				row.quiz = quiz(-1)
				row.sections_cleaned = -1
				payload.runs = [row]
			"extra-quiz":
				var row := sample_result()
				row.quiz = quiz(-1)
				row.quiz["person"] = "unknown"
				payload.runs = [row]
		assert_rejected_file(mutation, JSON.stringify(payload))

	var stale_path := test_dir.path_join("stale.json")
	var first = Progress.new(stale_path)
	check(first.save_data(), "Stale-writer fixture is saved")
	var second = Progress.new(stale_path)
	check(first.record_reviewed(["dust"]), "First window saves new learning")
	var newer_bytes := read_text(stale_path)
	check(not second.record_reviewed(["time"]) and not second.storage_available and read_text(stale_path) == newer_bytes, "A stale window cannot overwrite newer saved progress")
	check(second.load_data(stale_path) and second.record_reviewed(["time"]), "Explicit reload restores saving without discarding newer reviews")
	check(second.reviewed_ids == ["dust", "time"], "Reload followed by save retains both concept reviews")
	var appeared_path := test_dir.path_join("appeared.json")
	var unaware = Progress.new(appeared_path)
	write_text(appeared_path, "new unrelated document")
	check(not unaware.save_data() and read_text(appeared_path) == "new unrelated document", "A file created after loading defaults is never overwritten")
	var deleted_path := test_dir.path_join("deleted.json")
	var deleted = Progress.new(deleted_path)
	deleted.save_data()
	DirAccess.remove_absolute(deleted_path)
	check(not deleted.save_data() and not FileAccess.file_exists(deleted_path), "External deletion is not silently undone by a stale writer")
	for invalid_path in ["res://journey-progress.json", "/tmp/journey-progress.json", "user://../outside.json", test_dir + "/../outside.json", test_dir + "/missing/profile.json", test_dir + "/not-json.txt", "user://", test_dir + "//profile.json"]:
		var invalid = Progress.new(invalid_path)
		check(not invalid.storage_available and not invalid.save_data(), "Unsafe or unrelated path is rejected: " + invalid_path)

	var target_path := test_dir.path_join("link-target.json")
	write_text(target_path, "do not replace")
	var linked_path := test_dir.path_join("linked.json")
	var directory := DirAccess.open(test_dir)
	var link_error := directory.create_link(ProjectSettings.globalize_path(target_path), "linked.json")
	check(link_error == OK, "Symbolic-link safety fixture is created")
	if link_error == OK:
		var linked = Progress.new(linked_path)
		check(not linked.storage_available and not linked.save_data() and read_text(target_path) == "do not replace", "A symbolic-link target is never overwritten")
	var directory_link_error := directory.create_link(ProjectSettings.globalize_path(test_dir), "linked-dir")
	check(directory_link_error == OK, "Linked-directory safety fixture is created")
	if directory_link_error == OK:
		var linked_directory = Progress.new(test_dir.path_join("linked-dir/profile.json"))
		check(not linked_directory.storage_available and not linked_directory.save_data(), "A symlinked parent cannot redirect local saves")
	var pending := false
	for filename in directory.get_files():
		if filename.begins_with(".journey-save-"): pending = true
	check(not pending, "Successful atomic saves leave no pending temporary files")
	# Clean only this process's dedicated temporary directory, never the real profile.
	for filename in directory.get_files(): DirAccess.remove_absolute(test_dir.path_join(filename))
	if directory.is_link("linked-dir"): DirAccess.remove_absolute(test_dir.path_join("linked-dir"))
	check(DirAccess.remove_absolute(test_dir) == OK, "Isolated test files are removed")
	print("Journey progress: ", assertions, " assertions, ", failures, " failures")
	quit(1 if failures else 0)
