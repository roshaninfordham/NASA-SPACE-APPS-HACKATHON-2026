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
	check(store.settings == {"music_enabled": true, "effects_enabled": true, "music_volume": 0.35, "effects_volume": 0.55, "soundtrack": "supplied", "reduced_motion": false, "pace": 1.0, "mission_view": "science"}, "First-run settings use audible, standard-pace defaults with visible science")
	check(store.save_data(), "Initial settings save atomically")
	var initial_bytes := read_text(path)
	var initial: Dictionary = JSON.parse_string(initial_bytes)
	check(initial.kind == "komaku-journey-progress" and initial.schema_version == 3, "Progress has a dedicated version-three schema discriminator")
	check(initial.reviewed_ids.is_empty() and initial.runs.is_empty(), "Empty reviews and results round-trip")
	check(store.set_setting("music_enabled", false) and store.set_setting("effects_enabled", false) and store.set_setting("reduced_motion", true), "Boolean accessibility and audio settings save")
	check(store.set_setting("music_volume", 0.0) and store.set_setting("effects_volume", 1.0), "Volume endpoints are valid")
	check(store.set_setting("soundtrack", "original") and Progress.new(path).settings.soundtrack == "original", "Original soundtrack choice persists")
	check(store.set_setting("soundtrack", "supplied") and Progress.new(path).settings.soundtrack == "supplied", "Supplied soundtrack choice persists")
	for pace in [0.5, 1.0, 2.0]:
		check(store.set_setting("pace", pace) and Progress.new(path).settings.pace == pace, "Supported pace persists: " + str(pace))
	for view in ["focus", "science"]:
		check(store.set_setting("mission_view", view) and Progress.new(path).settings.mission_view == view, "Supported mission view persists: " + view)
		check(store.settings.pace == 2.0 and store.reviewed_ids.is_empty() and store.runs.is_empty(), "Changing presentation does not change pace, learning or results")
	var before: Dictionary = store.settings.duplicate(true)
	var before_file := read_text(path)
	for setting in [["unknown", true], ["music_enabled", 1], ["effects_enabled", "true"], ["reduced_motion", null], ["music_volume", -0.01], ["effects_volume", 1.01], ["music_volume", NAN], ["effects_volume", INF], ["pace", 1.5], ["pace", true], ["soundtrack", "unknown"], ["soundtrack", true], ["mission_view", "wide"], ["mission_view", "SCIENCE"], ["mission_view", " focus"], ["mission_view", true], ["mission_view", 1], ["mission_view", null], ["camera_view", "wide"], ["text_scale", 1.5]]:
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
	check(store.runs.size() == 1 and store.runs[0].size() == 11 and not store.runs[0].has("history") and not store.runs[0].has("personal_note"), "Only eleven bounded run-summary fields are retained")
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
	legacy_payload.schema_version = 2
	legacy_payload.erase("training")
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
	# A real schema-one profile must remain readable without a load-time write.
	# Its older quiz history retains meaning; the only new default is visual.
	var version_one: Dictionary = initial.duplicate(true)
	version_one.schema_version = 1
	version_one.erase("training")
	version_one.settings.erase("mission_view")
	version_one.settings.music_enabled = false
	version_one.settings.soundtrack = "original"
	version_one.settings.reduced_motion = true
	version_one.settings.pace = 0.5
	version_one.reviewed_ids = ["dust", "dose"]
	version_one.runs = [legacy_row.duplicate(true)]
	var version_one_text := JSON.stringify(version_one, "  ") + "\n"
	var migration_path := test_dir.path_join("schema-one.json")
	write_text(migration_path, version_one_text)
	var migrated = Progress.new(migration_path)
	check(migrated.storage_available and migrated.settings.mission_view == "science", "A valid schema-one profile gains the science view in memory")
	check(read_text(migration_path) == version_one_text, "Loading schema one leaves the original bytes untouched")
	for key: String in version_one.settings:
		check(migrated.settings[key] == version_one.settings[key], "Migration preserves existing preference: " + key)
	check(migrated.reviewed_ids == version_one.reviewed_ids and migrated.runs.size() == version_one.runs.size() and migrated.runs[0].quiz == version_one.runs[0].quiz, "Migration preserves reviewed ideas and historical quiz results")
	var stale_migration = Progress.new(migration_path)
	check(migrated.set_setting("mission_view", "focus"), "An ordinary view save publishes the migrated profile")
	var migrated_payload: Dictionary = JSON.parse_string(read_text(migration_path))
	check(migrated_payload.schema_version == 3 and migrated_payload.settings.mission_view == "focus", "The ordinary save writes the complete version-three format")
	var migrated_reopened = Progress.new(migration_path)
	check(migrated_reopened.storage_available and migrated_reopened.settings == migrated.settings and migrated_reopened.runs == migrated.runs and migrated_reopened.reviewed_ids == migrated.reviewed_ids, "Migrated preferences and historical learning round-trip together")
	var newer_migration_bytes := read_text(migration_path)
	check(not stale_migration.set_setting("mission_view", "science") and read_text(migration_path) == newer_migration_bytes, "A second migrating window cannot overwrite the newer version-three save")
	check(stale_migration.settings.mission_view == "science" and not stale_migration.storage_available, "A stale migrating window retains its view for this session only")
	check(stale_migration.load_data(migration_path) and stale_migration.settings.mission_view == "focus", "Explicit reload adopts the newer saved view after a migration conflict")
	var externally_edited_path := test_dir.path_join("schema-one-edited.json")
	write_text(externally_edited_path, version_one_text)
	var migration_conflict = Progress.new(externally_edited_path)
	var external_payload: Dictionary = version_one.duplicate(true)
	external_payload.settings.music_volume = 0.7
	var external_text := JSON.stringify(external_payload)
	write_text(externally_edited_path, external_text)
	check(not migration_conflict.record_reviewed(["time"]) and read_text(externally_edited_path) == external_text, "Migration retains the original fingerprint and protects an intervening schema-one edit")
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
	for index in range(35):
		check(store.record_result(sample_result(100.0 + index)), "History run " + str(index) + " saves")
	check(store.runs.size() == 30 and store.runs[0].elapsed_seconds == 105.0 and store.runs[-1].elapsed_seconds == 134.0, "Only the last thirty runs are kept in chronological order")
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
	for mutation in ["wrong-kind", "wrong-version", "boolean-version", "wrong-setting-type", "extra-setting", "missing-view", "invalid-view", "legacy-extra-view", "legacy-missing-setting", "duplicate-review", "unknown-review", "extra-root", "oversize-history", "bad-run", "extra-quiz"]:
		var payload: Dictionary = initial.duplicate(true)
		match mutation:
			"wrong-kind": payload.kind = "something-else"
			"wrong-version": payload.schema_version = 4
			"boolean-version": payload.schema_version = true
			"wrong-setting-type": payload.settings.music_enabled = 1
			"extra-setting": payload.settings["tracking"] = true
			"missing-view": payload.settings.erase("mission_view")
			"invalid-view": payload.settings.mission_view = "cinematic"
			"legacy-extra-view": payload.schema_version = 1
			"legacy-missing-setting":
				payload = version_one.duplicate(true)
				payload.settings.erase("soundtrack")
			"duplicate-review": payload.reviewed_ids = ["dose", "dose"]
			"unknown-review": payload.reviewed_ids = ["mystery"]
			"extra-root": payload["personal_data"] = {}
			"oversize-history":
				for index in range(31):
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

	test_training_journal(initial)

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

func detailed_result(index: int, outcome := "win") -> Dictionary:
	var row := sample_result(90.0)
	row.status = outcome
	row.sim_elapsed_seconds = 1800.0
	row.clean_fraction = 0.875 if outcome == "win" else (0.5 if outcome == "pass" else 0.25)
	row.sections_cleaned = int(floor(row.clean_fraction*4.0))
	row.battery_kwh = 1.0+float(index)*0.125
	row.max_fatigue = 0.16
	row.pace_changes = index%4
	row.ended_at = 1794700000+index*100
	return row

func test_training_journal(initial: Dictionary) -> void:
	var path := test_dir.path_join("training-journal.json")
	var store = Progress.new(path)
	var summary: Dictionary = store.training_summary()
	check(summary.attempts == 0 and summary.wins == 0 and summary.practice_attempts == 0 and not summary.practiced, "New journal has no invented missions or practice")
	check(summary.suggested_focus.id == "first_mission" and summary.recent_results.is_empty(), "A new journal suggests a first mission")
	check(summary.storage_available and summary.counters_cover_all_history, "Fresh-profile summary distinguishes available storage and complete recorded history")
	check(store.record_reviewed(Progress.CONCEPT_IDS), "All eight discoveries can be explored before any skill practice")
	summary = store.training_summary()
	check(summary.reviewed_count == 8 and not summary.practiced and summary.correct_first_unassisted == 0 and summary.attempts == 0, "Opening every bubble never creates a tested skill or completed mission")
	check(store.record_result(detailed_result(0)), "A completed run can skip the optional question")
	summary = store.training_summary()
	check(summary.attempts == 1 and summary.wins == 1 and summary.practice_attempts == 0 and summary.suggested_focus.id == "try_practice", "A skipped question adds no assessment attempt")
	check(store.record_result(detailed_result(1,"pass"),quiz(1)), "An incorrect first practice answer can be stored")
	summary = store.training_summary()
	check(summary.practice_attempts == 1 and not summary.practiced and summary.suggested_focus.id == "pace_and_fatigue", "An incorrect first answer suggests further pace practice without claiming success")
	var assisted := quiz(0)
	assisted.assisted = true
	check(store.record_result(detailed_result(2,"lose"),assisted), "A guided correct answer can be recorded honestly")
	summary = store.training_summary()
	check(summary.practice_attempts == 2 and summary.correct_first_unassisted == 0 and not summary.practiced, "An assisted answer is an attempt, not unassisted skill evidence")
	var row := detailed_result(3)
	check(store.record_result(row,quiz(0)), "A correct first unassisted answer is accepted")
	summary = store.training_summary()
	check(summary.attempts == 4 and summary.completed_runs == 4 and summary.wins == 2 and summary.practice_attempts == 3 and summary.correct_first_unassisted == 1 and summary.practiced, "Cumulative training counters distinguish outcomes and assessment evidence")
	check(summary.suggested_focus.id == "predict_then_test", "Successful current practice suggests prediction and comparison rather than invented mastery levels")
	check(summary.recent_results[0].clean_fraction == row.clean_fraction and summary.recent_results[0].battery_kwh == row.battery_kwh and summary.recent_results[0].max_fatigue == 0.16 and summary.recent_results[0].pace_changes == 3 and summary.recent_results[0].ended_at == row.ended_at, "New metrics and UTC completion seconds come directly from the provided result")
	check(summary.recent_results[0].ended_at > summary.recent_results[1].ended_at, "Recent results are newest first")
	summary.reviewed_ids.clear()
	summary.recent_results[0].quiz.correct = false
	summary.recent_results[0].battery_kwh = 99999
	summary.suggested_focus.title = "Caller mutation"
	summary = store.training_summary()
	check(summary.reviewed_count == 8 and summary.reviewed_ids.size() == 8 and summary.recent_results[0].quiz.correct and summary.recent_results[0].battery_kwh == row.battery_kwh and summary.suggested_focus.title != "Caller mutation", "Nested summary data is detached from stored preferences, quizzes and run metrics")
	var before := read_text(path)
	for invalid in [["clean_fraction",-0.1],["clean_fraction",1.01],["clean_fraction",true],["battery_kwh",NAN],["battery_kwh",-1],["max_fatigue",1.01],["max_fatigue",INF],["pace_changes",1.5],["pace_changes",true],["ended_at",-1],["ended_at",12.5],["ended_at","2026-11-15"]]:
		var bad := detailed_result(4)
		bad[invalid[0]] = invalid[1]
		check(not store.record_result(bad,quiz(0)), "Invalid optional run metric is rejected: "+str(invalid[0]))
	check(read_text(path) == before and store.training_summary().attempts == 4, "Rejected optional metrics cannot inflate counters or alter the existing file")
	for index in range(36):
		var current_quiz := quiz(-1 if index%4 == 3 else (1 if index%4 == 1 else 0))
		current_quiz.assisted = index%4 == 2
		check(store.record_result(detailed_result(index+4,["win","pass","lose"][index%3]),current_quiz), "Capped-history mission "+str(index)+" saves")
	var reopened = Progress.new(path)
	summary = reopened.training_summary()
	check(reopened.storage_available and summary.completed_runs == 40 and summary.wins == 14 and summary.practice_attempts == 30 and summary.correct_first_unassisted == 10, "Cumulative run and practice counters survive saving more than thirty missions")
	check(reopened.runs.size() == 30 and summary.history_available == 30 and summary.history_limit == 30 and reopened.runs[0].ended_at == detailed_result(10).ended_at, "Only the newest thirty detailed records are retained")
	check(summary.recent_results.size() == 5 and summary.recent_results[0].ended_at == detailed_result(39).ended_at and summary.recent_results[-1].ended_at == detailed_result(35).ended_at, "The public journal provides only the newest five detached detailed results")
	check(summary.counters_cover_all_history and summary.practiced and summary.storage_available, "History truncation does not erase lifetime practice or invent a storage failure")
	check(FileAccess.get_file_as_bytes(path).size() < Progress.MAX_BYTES, "Thirty enriched records remain within the existing bounded profile size")

	var old: Dictionary = initial.duplicate(true)
	old.schema_version = 2
	old.erase("training")
	old.settings.mission_view = "focus"
	old.reviewed_ids = ["dust","speed"]
	for index in range(10):
		var old_row := sample_result()
		old_row.quiz = quiz(0 if index in [0,1,3,5,6] else (1 if index in [4,9] else -1))
		if index == 0: old_row.quiz.question_id = Progress.LEGACY_QUIZ_ID
		elif index == 1: old_row.quiz.question_id = Progress.PREVIOUS_QUIZ_ID
		elif index == 3: old_row.quiz.assisted = true
		old.runs.append(old_row)
	var old_path := test_dir.path_join("training-schema-two.json")
	var old_bytes := JSON.stringify(old,"  ")+"\n"
	write_text(old_path,old_bytes)
	var migrated = Progress.new(old_path)
	summary = migrated.training_summary()
	check(migrated.storage_available and read_text(old_path) == old_bytes and migrated.settings.mission_view == "focus", "Schema-two training migration is readable and does not rewrite the original file")
	check(summary.completed_runs == 10 and summary.wins == 10 and summary.practice_attempts == 5 and summary.correct_first_unassisted == 2, "Only answered current-quiz records contribute to migrated practice counters")
	check(not summary.counters_cover_all_history and summary.reviewed_count == 2, "Migration honestly marks previously truncated activity as unknown")
	var unknown := true
	for old_row: Dictionary in migrated.runs:
		for field in ["clean_fraction","battery_kwh","max_fatigue","pace_changes","ended_at"]:
			unknown = unknown and old_row[field] == null
	check(unknown, "Legacy metrics and completion dates remain unknown rather than fabricated from section counts")
	check(migrated.set_setting("mission_view","science"), "An ordinary settings save persists the migrated training counters")
	var again = Progress.new(old_path)
	check(again.storage_available and again.training_summary() == migrated.training_summary() and JSON.parse_string(read_text(old_path)).schema_version == 3, "Migrated training summary round-trips in schema three with its lower-bound notice")
	check(again.record_result(sample_result()), "The older record_result API still accepts a result without richer metrics")
	var compatible: Dictionary = again.runs[-1]
	check(compatible.clean_fraction == null and compatible.battery_kwh == null and compatible.max_fatigue == null and compatible.pace_changes == null and compatible.ended_at is int and compatible.ended_at > 0, "Older callers get unknown optional metrics and a real UTC completion timestamp")

	var valid: Dictionary = JSON.parse_string(read_text(path))
	for issue in ["missing-training","extra-training","wrong-question","fractional-counter","negative-counter","too-few-runs","too-few-practice","forged-correct-count","invalid-history-flag","unknown-run-field","missing-run-field"]:
		var damaged: Dictionary = valid.duplicate(true)
		match issue:
			"missing-training": damaged.erase("training")
			"extra-training": damaged.training["xp"] = 9000
			"wrong-question": damaged.training.question_id = Progress.LEGACY_QUIZ_ID
			"fractional-counter": damaged.training.completed_runs = 40.5
			"negative-counter": damaged.training.wins = -1
			"too-few-runs": damaged.training.completed_runs = 29
			"too-few-practice": damaged.training.practice_attempts = 1
			"forged-correct-count": damaged.training.correct_first_unassisted = damaged.training.practice_attempts+1
			"invalid-history-flag": damaged.training.history_complete = "yes"
			"unknown-run-field": damaged.runs[0]["health"] = "not collected"
			"missing-run-field": damaged.runs[0].erase("clean_fraction")
		assert_rejected_file("training-"+issue,JSON.stringify(damaged))

	var stale = Progress.new(path)
	check(reopened.record_result(detailed_result(40),quiz(0)), "One journal window saves a further completed mission")
	var newer := read_text(path)
	check(not stale.record_result(detailed_result(41),quiz(0)) and read_text(path) == newer, "A stale training window cannot overwrite newer counters or results")
	check(not stale.training_summary().storage_available and stale.training_summary().attempts == 41, "Unsaved training remains explicitly session-only after a conflict")
	check(stale.load_data(path) and stale.training_summary().completed_runs == 41 and stale.runs[-1].ended_at == detailed_result(40).ended_at, "Reload adopts the actual saved training history instead of the stale session result")
