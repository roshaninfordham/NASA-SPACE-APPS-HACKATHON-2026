class_name VeilUpdateStore
extends RefCounted
## Pinned-key content slots and a recoverable startup journal. No network access.
const Verifier = preload("res://updater/verifier.gd")
const JOURNAL_LIMIT := 8192
const SLOT_FILES := ["update-manifest.json", "update-manifest.sig", "red-veil-content.pck"]
var root_dir: String
var baseline_version: String
var pinned_key: CryptoKey
var _trial_token := ""
var _boot_version := ""

func _init(folder: String = "user://updates", baseline: String = "", key: CryptoKey = null) -> void:
	root_dir = folder
	baseline_version = baseline if not baseline.is_empty() else str(ProjectSettings.get_setting("application/config/version", ""))
	pinned_key = key
	_boot_version = baseline_version

func configured() -> bool:
	return pinned_key != null and not Verifier.version_parts(baseline_version).is_empty()

func needs_repair() -> bool:
	return DirAccess.dir_exists_absolute(root_dir.path_join("mutation.lock"))

func slot_path(version: String) -> String:
	if Verifier.version_parts(version).is_empty(): return ""
	return root_dir.path_join("slots").path_join(version)

func validate_manifest(raw: PackedByteArray, signature: PackedByteArray, current_version: String = "") -> Dictionary:
	if not configured(): return fail("signing_not_configured")
	return Verifier.validate_manifest(raw, signature, pinned_key, current_version)

func fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

func _bounded_bytes(path: String, maximum: int) -> PackedByteArray:
	if not FileAccess.file_exists(path): return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > maximum: return PackedByteArray()
	return file.get_buffer(file.get_length())

func _verified_slot(version: String) -> Dictionary:
	if not Verifier.is_newer(version, baseline_version): return fail("not_newer")
	var folder := slot_path(version)
	if folder.is_empty(): return fail("version_invalid")
	var result := validate_manifest(_bounded_bytes(folder.path_join(SLOT_FILES[0]), Verifier.MAX_MANIFEST_BYTES), _bounded_bytes(folder.path_join(SLOT_FILES[1]), 1024))
	if not result.ok: return result
	if result.manifest.version != version: return fail("slot_version_mismatch")
	var pack := folder.path_join(SLOT_FILES[2])
	var checked := Verifier.validate_pack(pack, result.manifest)
	if not checked.ok: return checked
	return {"ok": true, "version": version, "pack_path": pack}

func stage(raw: PackedByteArray, signature: PackedByteArray, downloaded_pack_path: String, current_version: String) -> Dictionary:
	var result := validate_manifest(raw, signature, current_version)
	if not result.ok: return result
	if not Verifier.is_newer(result.manifest.version, baseline_version): return fail("not_newer")
	var checked := Verifier.validate_pack(downloaded_pack_path, result.manifest)
	if not checked.ok: return checked
	return _locked(func(): return _stage_verified(raw, signature, downloaded_pack_path, result.manifest.version))

func _stage_verified(raw: PackedByteArray, signature: PackedByteArray, source: String, version: String) -> Dictionary:
	var journal := _load_state()
	# Never replace the files backing a running, pending, or recovery version.
	if version in [journal.active, journal.previous]: return fail("slot_in_use")
	var destination := slot_path(version)
	var pending := root_dir.path_join("staging")
	if ProjectSettings.globalize_path(source).simplify_path().begins_with(ProjectSettings.globalize_path(pending).simplify_path() + "/"): return fail("download_path_invalid")
	_remove_known_files(pending)
	if DirAccess.make_dir_recursive_absolute(pending) != OK: return fail("storage_unavailable")
	if not _write_bytes(pending.path_join(SLOT_FILES[0]), raw) or not _write_bytes(pending.path_join(SLOT_FILES[1]), signature): return fail("storage_write_failed")
	if DirAccess.copy_absolute(source, pending.path_join(SLOT_FILES[2])) != OK: return fail("storage_write_failed")
	# Verify the staged copy, including copy errors/corruption, before publishing the slot.
	var manifest := validate_manifest(raw, signature)
	if not manifest.ok: return manifest
	var copied := Verifier.validate_pack(pending.path_join(SLOT_FILES[2]), manifest.manifest)
	if not copied.ok: return copied
	if DirAccess.make_dir_recursive_absolute(root_dir.path_join("slots")) != OK: return fail("storage_unavailable")
	_remove_known_files(destination)
	if DirAccess.rename_absolute(pending, destination) != OK: return fail("storage_write_failed")
	_cleanup_slots([journal.active, journal.previous, version])
	return {"ok": true, "version": version}

func activate(version: String) -> Dictionary:
	return _locked(func():
		var candidate := _verified_slot(version)
		if not candidate.ok: return candidate
		var journal := _load_state()
		var latest: String = journal.active if Verifier.is_newer(journal.active, baseline_version) else baseline_version
		if not Verifier.is_newer(version, latest): return fail("not_newer")
		if journal.status == "trial": return fail("update_starting")
		# Replacing an unstarted candidate must preserve the last healthy version.
		var previous: String = journal.previous if journal.status == "ready" else journal.active
		if not previous.is_empty() and not _verified_slot(previous).ok: previous = ""
		var next := {"schema": 1, "active": version, "previous": previous, "status": "ready", "pid": 0, "token": ""}
		if not _write_state(next): return fail("journal_write_failed")
		return {"ok": true, "version": version}
	)

func prepare_boot() -> Dictionary:
	_trial_token = ""
	_boot_version = baseline_version
	if not configured() or not DirAccess.dir_exists_absolute(root_dir): return _baseline()
	var result := _locked(_prepare_locked)
	if not result.ok: return _baseline("Update storage is busy or unavailable. The bundled game is running.")
	_boot_version = result.version
	return result

func _prepare_locked() -> Dictionary:
	var journal := _load_state()
	if journal.active.is_empty(): return _baseline()
	if not Verifier.is_newer(journal.active, baseline_version):
		if not _write_state(_empty_state()): return fail("journal_write_failed")
		return _baseline()
	if journal.status == "trial":
		if journal.pid > 0 and _process_alive(int(journal.pid)):
			# A second instance must not declare a still-starting first instance crashed.
			return _fallback_result(journal.previous, "Another game window is starting the update. This window uses the previous version.")
		return _rollback_locked(journal, "The previous update did not finish starting. Your earlier version was restored.")
	var candidate := _verified_slot(journal.active)
	if not candidate.ok: return _rollback_locked(journal, "The saved update could not be verified. Your earlier version was restored.")
	if journal.status == "ready":
		journal.status = "trial"
		journal.pid = OS.get_process_id()
		journal.token = "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
		if not _write_state(journal): return fail("journal_write_failed")
		_trial_token = journal.token
	return {"ok": true, "version": candidate.version, "pack_path": candidate.pack_path, "notice": ""}

func _fallback_result(previous: String, notice: String) -> Dictionary:
	var fallback := _verified_slot(previous)
	if fallback.ok: return {"ok": true, "version": previous, "pack_path": fallback.pack_path, "notice": notice}
	return _baseline(notice)

func _rollback_locked(journal: Dictionary, notice: String) -> Dictionary:
	var result := _fallback_result(journal.previous, notice)
	var next := _empty_state()
	if not result.pack_path.is_empty(): next.active = result.version
	if not _write_state(next): return fail("journal_write_failed")
	return result

func mount_failed() -> Dictionary:
	# Bootstrap uses this only after the selected resource pack fails to mount.
	_trial_token = ""
	var result := _locked(func(): return _rollback_locked(_load_state(), "The update could not open. Your earlier version was restored."))
	if not result.ok: return _baseline("The update could not open. The bundled game is running.")
	_boot_version = result.version
	return result

func mark_healthy() -> Dictionary:
	if _trial_token.is_empty(): return {"ok": true}
	return _locked(func():
		var journal := _load_state()
		if journal.status != "trial" or journal.token != _trial_token or journal.active != _boot_version: return fail("trial_changed")
		journal.status = "healthy"
		journal.pid = 0
		journal.token = ""
		if not _write_state(journal): return fail("journal_write_failed")
		_trial_token = ""
		_cleanup_slots([journal.active, journal.previous])
		return {"ok": true}
	)

func _baseline(notice: String = "") -> Dictionary:
	return {"ok": true, "version": baseline_version, "pack_path": "", "notice": notice}

func _empty_state() -> Dictionary:
	return {"schema": 1, "active": "", "previous": "", "status": "healthy", "pid": 0, "token": ""}

func _read_state(path: String) -> Dictionary:
	var raw := _bounded_bytes(path, JOURNAL_LIMIT)
	if raw.is_empty(): return {}
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK or not json.data is Dictionary: return {}
	var state: Dictionary = json.data
	if state.get("schema") != 1 or state.size() != 6: return {}
	for name in ["active", "previous"]:
		var value: Variant = state.get(name)
		if not value is String or (not value.is_empty() and Verifier.version_parts(value).is_empty()): return {}
	if state.get("status") not in ["healthy", "ready", "trial"]: return {}
	var pid: Variant = state.get("pid")
	if not (pid is int or pid is float) or not is_finite(float(pid)) or pid < 0 or pid > 2147483647 or pid != floor(pid): return {}
	if not state.get("token") is String or state.token.length() > 80: return {}
	if state.status in ["ready", "trial"] and state.active.is_empty(): return {}
	return state

func _load_state() -> Dictionary:
	var primary := _read_state(root_dir.path_join("state.json"))
	if not primary.is_empty(): return primary
	var backup := _read_state(root_dir.path_join("state.backup.json"))
	return backup if not backup.is_empty() else _empty_state()

func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	file.flush()
	var success := file.get_error() == OK
	file.close()
	return success

func _write_state(state: Dictionary) -> bool:
	var primary := root_dir.path_join("state.json")
	var temporary := root_dir.path_join("state.pending.json")
	if not _write_bytes(temporary, JSON.stringify(state).to_utf8_buffer()): return false
	if not _read_state(primary).is_empty():
		if DirAccess.copy_absolute(primary, root_dir.path_join("state.backup.json")) != OK: return false
	return DirAccess.rename_absolute(temporary, primary) == OK

func _remove_known_files(folder: String) -> void:
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder): return
	for name in SLOT_FILES:
		var file: String = folder.path_join(name)
		if FileAccess.file_exists(file): DirAccess.remove_absolute(file)
	# Unknown files are deliberately preserved; removal then fails harmlessly.
	DirAccess.remove_absolute(folder)

func _cleanup_slots(keep: Array) -> void:
	var folder := DirAccess.open(root_dir.path_join("slots"))
	if folder == null: return
	for name in folder.get_directories():
		if not Verifier.version_parts(name).is_empty() and name not in keep: _remove_known_files(slot_path(name))

func _locked(operation: Callable) -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(root_dir) != OK: return fail("storage_unavailable")
	var lock := root_dir.path_join("mutation.lock")
	var owner_path := lock.path_join("owner")
	# Build a complete owner claim before publishing it. Directory rename cannot
	# replace an existing nonempty lock, so no published ownerless window exists.
	var claim := root_dir.path_join("claim-%d-%s" % [OS.get_process_id(), Crypto.new().generate_random_bytes(8).hex_encode()])
	if DirAccess.make_dir_absolute(claim) != OK: return fail("storage_write_failed")
	var claim_owner := claim.path_join("owner")
	if not _write_bytes(claim_owner, str(OS.get_process_id()).to_utf8_buffer()):
		DirAccess.remove_absolute(claim_owner)
		DirAccess.remove_absolute(claim)
		return fail("storage_write_failed")
	# Never unlink a stale lock automatically: simultaneous reclaimers can otherwise
	# delete a newly acquired live lock (an ABA race). Explicit repair closes that gap.
	if DirAccess.dir_exists_absolute(lock) or DirAccess.rename_absolute(claim, lock) != OK:
		DirAccess.remove_absolute(claim_owner)
		DirAccess.remove_absolute(claim)
		return fail("storage_busy")
	var result: Dictionary = operation.call()
	DirAccess.remove_absolute(owner_path)
	DirAccess.remove_absolute(lock)
	return result

func repair_incomplete_lock() -> Dictionary:
	# Explicit recovery only, after the UI asks the player to close other game windows.
	# Unknown owners are never silently declared dead during normal startup.
	var lock := root_dir.path_join("mutation.lock")
	if not DirAccess.dir_exists_absolute(lock): return {"ok": true}
	var owner_path := lock.path_join("owner")
	var owner := _bounded_bytes(owner_path, 32).get_string_from_utf8()
	if owner.is_valid_int() and int(owner) > 0 and _process_alive(int(owner)): return fail("storage_busy")
	if FileAccess.file_exists(owner_path) and DirAccess.remove_absolute(owner_path) != OK: return fail("storage_write_failed")
	if DirAccess.remove_absolute(lock) != OK: return fail("storage_busy")
	return {"ok": true}

func _process_alive(pid: int) -> bool:
	# Godot's is_process_running only tracks managed children on some Unix builds.
	# Unknown liveness remains busy rather than risking another instance's journal.
	if pid == OS.get_process_id(): return true
	if pid <= 0 or pid > 2147483647: return true
	if OS.get_name() == "Linux" or OS.get_name() == "FreeBSD":
		if not DirAccess.dir_exists_absolute("/proc"): return true
		return DirAccess.dir_exists_absolute("/proc/%d" % pid)
	var output: Array = []
	if OS.get_name() == "macOS":
		if not FileAccess.file_exists("/bin/ps"): return true
		var result := OS.execute("/bin/ps", ["-p", str(pid), "-o", "pid="], output, true)
		if result == 1 and str(output[0] if not output.is_empty() else "").strip_edges().is_empty(): return false
		return true
	if OS.get_name() == "Windows":
		var executable := OS.get_environment("SystemRoot").path_join("System32/tasklist.exe")
		if not FileAccess.file_exists(executable): return true
		var result := OS.execute(executable, ["/FI", "PID eq %d" % pid, "/FO", "CSV", "/NH"], output, true)
		if result != 0: return true
		return _tasklist_reports_alive("\n".join(output), pid)
	return true

func _tasklist_reports_alive(output: String, pid: int) -> bool:
	if output.strip_edges().is_empty(): return true
	var pattern := RegEx.new()
	pattern.compile('^"[^"]*","([0-9]+)",')
	for row in output.split("\n"):
		if not row.begins_with('"'): continue
		var found := pattern.search(row)
		if found == null: return true
		if int(found.get_string(1)) == pid: return true
	return false
