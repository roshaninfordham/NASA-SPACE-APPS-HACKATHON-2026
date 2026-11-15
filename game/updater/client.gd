class_name VeilUpdateClient
extends Node
## Public release discovery and verified desktop content updates. No account tokens.
signal changed
signal transport_finished(result: Dictionary)
const Verifier = preload("res://updater/verifier.gd")
const RELEASES_URL := "https://api.github.com/repos/" + Verifier.REPOSITORY + "/releases?per_page=20"
const RELEASE_PAGE := "https://github.com/" + Verifier.REPOSITORY + "/releases"
const MAX_RELEASE_BYTES := 1024 * 1024
const MANUAL_COOLDOWN_MS := 15000

var network_enabled := true
var store: Object
var current_version := ""
var available_version := ""
var status := "idle"
var message := "Check for a new adventure."
var progress := 0.0
var busy := false
var ready_to_restart := false
var manual_update_required := false
var repair_available := false
var working_directory := "user://updates/incoming"
var _manifest: Dictionary = {}
var _raw := PackedByteArray()
var _signature := PackedByteArray()
var _request: HTTPRequest
var _request_generation := 0
var _last_request_ticks := -MANUAL_COOLDOWN_MS
var _checked_this_session := false
var _download_cancelled := false

func configure(update_store: Object, version: String, directory: String = "user://updates/incoming") -> void:
	store = update_store
	current_version = version
	working_directory = directory
	repair_available = _needs_repair()
	if not _desktop_supported():
		message = "This build shows update notices, but installing updates inside the game is not available here. You can view current download options."
	elif not _configured():
		message = "This preview uses manual downloads. You can still check for a newer release."
	if repair_available: message = "An update may have been interrupted. Close other game windows before using the repair option below."
	changed.emit()

func _configured() -> bool:
	return is_instance_valid(store) and store.configured()

func _needs_repair() -> bool:
	return is_instance_valid(store) and store.has_method("needs_repair") and store.needs_repair()

func _desktop_supported() -> bool:
	return OS.get_name() in ["Windows", "macOS", "Linux"] and not OS.has_feature("editor")

func can_install() -> bool:
	return network_enabled and not busy and not ready_to_restart and not repair_available and not _manifest.is_empty() and _configured() and _desktop_supported()

func release_url() -> String:
	return RELEASE_PAGE if available_version.is_empty() else RELEASE_PAGE + "/tag/v" + available_version

static func select_release(raw: PackedByteArray, version: String) -> Dictionary:
	if raw.is_empty() or raw.size() > MAX_RELEASE_BYTES: return {"ok": false, "error": "release_size"}
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK or not json.data is Array or json.data.size() > 20:
		return {"ok": false, "error": "release_format"}
	var newest := ""
	var has_pack := false
	for entry in json.data:
		if not entry is Dictionary or entry.get("draft", true) != false: continue
		var tag: Variant = entry.get("tag_name")
		if not tag is String or not tag.begins_with("v"): continue
		var candidate: String = tag.substr(1)
		if not Verifier.is_newer(candidate, version): continue
		if not version.contains("-alpha.") and (candidate.contains("-alpha.") or entry.get("prerelease", false) != false): continue
		if not newest.is_empty() and not Verifier.is_newer(candidate, newest): continue
		newest = candidate
		var names: Array[String] = []
		var assets: Variant = entry.get("assets", [])
		if assets is Array and assets.size() <= 128:
			for asset in assets:
				if asset is Dictionary and asset.get("name") is String: names.append(asset.name)
		has_pack = "update-manifest.json" in names and "update-manifest.sig" in names and "red-veil-content.pck" in names
	return {"ok": true, "version": newest, "has_pack": has_pack}

func set_network_enabled(enabled: bool) -> void:
	network_enabled = enabled
	if not enabled:
		if is_instance_valid(_request):
			var callback := _on_request_completed.bind(_request, _request_generation)
			if _request.request_completed.is_connected(callback): _request.request_completed.disconnect(callback)
			_request.cancel_request()
			_request.queue_free()
			_request = null
			_request_generation += 1
			_download_cancelled = true
			transport_finished.emit({"ok": false, "error": "offline"})
		busy = false
		message = "Offline mode · enable online sources in Settings to check or download updates."
		changed.emit()

func check_for_updates(force: bool = false) -> void:
	if not network_enabled:
		set_network_enabled(false)
		return
	if busy or ready_to_restart: return
	# Each fresh launch checks once. A failed/offline launch must not suppress
	# discovery on tomorrow's (or the next minute's) launch via persisted state.
	if not force and _checked_this_session: return
	if Time.get_ticks_msec() - _last_request_ticks < MANUAL_COOLDOWN_MS:
		message = "Please wait a moment before checking again."
		changed.emit()
		return
	_last_request_ticks = Time.get_ticks_msec()
	_checked_this_session = true
	busy = true
	status = "checking"
	message = "Checking GitHub for a new adventure…"
	available_version = ""
	manual_update_required = false
	repair_available = false
	_manifest.clear()
	_raw.clear()
	_signature.clear()
	changed.emit()
	var response: Dictionary = await _fetch(RELEASES_URL, MAX_RELEASE_BYTES)
	if not response.ok:
		_fail("We couldn’t check for updates. You can keep playing and try again later.")
		return
	var selected := select_release(response.body, current_version)
	if not selected.ok:
		_fail("The update list could not be read. Your game has not changed.")
		return
	available_version = selected.version
	if available_version.is_empty():
		busy = false
		status = "current"
		message = "No newer release was found in the recent releases for this version channel."
		repair_available = _needs_repair()
		changed.emit()
		return
	if not selected.has_pack or not _configured() or not _desktop_supported():
		var reason := "This release needs a new download."
		if not _desktop_supported(): reason = "Installing updates inside the game is not available in this build. View the current download options."
		elif not _configured(): reason = "This preview supports update notices, but it needs a manual download to upgrade."
		_manual_release(reason)
		return
	response = await _fetch(Verifier.asset_url(available_version, "update-manifest.json"), Verifier.MAX_MANIFEST_BYTES)
	if not response.ok:
		_fail("The update details could not be downloaded. Your game has not changed.")
		return
	_raw = response.body
	response = await _fetch(Verifier.asset_url(available_version, "update-manifest.sig"), 1024)
	if not response.ok:
		_fail("We couldn’t check this update’s signature. Your game has not changed.")
		return
	_signature = response.body
	var verified: Dictionary = store.validate_manifest(_raw, _signature, current_version)
	if not verified.ok:
		if verified.get("error") in ["engine_update_required", "runtime_update_required"]:
			_manual_release("This release updates the game engine or built-in systems and needs a new installer.")
		else: _fail("We couldn’t verify this update. Your game has not changed. Please try again later.")
		return
	if verified.manifest.version != available_version:
		_fail("The update details do not match this release. Your game has not changed.")
		return
	_manifest = verified.manifest
	busy = false
	status = "available"
	message = "Version %s is ready to download. You choose when to install and restart." % available_version
	repair_available = _needs_repair()
	changed.emit()

func _manual_release(reason: String) -> void:
	busy = false
	status = "manual"
	manual_update_required = true
	repair_available = _needs_repair()
	message = "Version %s is available. %s" % [available_version, reason]
	changed.emit()

func _fail(reason: String, may_repair: bool = false) -> void:
	busy = false
	status = "error"
	message = reason
	repair_available = may_repair or _needs_repair()
	changed.emit()

func _storage_failure(result: Dictionary, reason: String) -> void:
	var may_repair: bool = result.get("error") == "storage_busy" and store.has_method("repair_incomplete_lock")
	if may_repair:
		reason = "Another game window may be using the update files. Close other game windows before trying to repair an interrupted update."
	elif result.get("error") == "update_starting":
		reason = "An update is still starting in another game window. Let it finish, or close the other window and reopen this game."
	_fail(reason, may_repair)

func repair_interrupted_update() -> void:
	if busy or ready_to_restart or not repair_available or not store.has_method("repair_incomplete_lock"): return
	var result: Dictionary = store.repair_incomplete_lock()
	if not result.ok:
		_fail("The update files are still in use or could not be repaired. Close other game windows and try again.", true)
		return
	repair_available = false
	status = "available" if not _manifest.is_empty() else "idle"
	message = "The interrupted update is cleared. You can try installing again."
	changed.emit()

func install_update() -> void:
	if not network_enabled: return
	if not can_install(): return
	if DirAccess.make_dir_recursive_absolute(working_directory) != OK:
		_fail("There isn’t a writable place to save the update. Your game has not changed.")
		return
	var path := working_directory.path_join("pending-download.pck")
	_remove_download(path)
	busy = true
	progress = 0.0
	_download_cancelled = false
	status = "downloading"
	message = "Downloading the adventure… You can cancel or keep playing while it finishes."
	changed.emit()
	var response: Dictionary = await _fetch(Verifier.asset_url(available_version, "red-veil-content.pck"), int(_manifest.pack_bytes), path)
	if _download_cancelled:
		_remove_download(path)
		busy = false
		status = "cancelled"
		message = "Download cancelled. Your game has not changed."
		changed.emit()
		return
	if not response.ok:
		_remove_download(path)
		_fail("The download did not finish. Your game has not changed. You can try again.")
		return
	status = "verifying"
	message = "Checking the complete download before installing…"
	changed.emit()
	var staged: Dictionary = store.stage(_raw, _signature, path, current_version)
	_remove_download(path)
	if not staged.ok or staged.get("version") != available_version:
		_storage_failure(staged, "The download could not be verified or saved. Your game has not changed.")
		return
	var activated: Dictionary = store.activate(available_version)
	if not activated.ok:
		_storage_failure(activated, "The update could not be prepared for restart. Your current game is still running.")
		return
	busy = false
	progress = 1.0
	status = "ready"
	ready_to_restart = true
	message = "The update is installed and ready. Restart when you’re ready to play the new version."
	changed.emit()

func cancel_download() -> void:
	if not busy or status != "downloading": return
	_download_cancelled = true
	if is_instance_valid(_request):
		var callback := _on_request_completed.bind(_request, _request_generation)
		if _request.request_completed.is_connected(callback): _request.request_completed.disconnect(callback)
		_request.cancel_request()
		_request.queue_free()
		_request = null
		_request_generation += 1
		transport_finished.emit({"ok": false, "error": "cancelled"})

func restart_game() -> bool:
	if not ready_to_restart or busy: return false
	if OS.has_feature("editor") or OS.has_feature("web") or not _desktop_supported():
		message = "Close and reopen the game to finish the update."
		changed.emit()
		return false
	var process_id := OS.create_instance([])
	if process_id < 0:
		message = "The game could not reopen automatically. Close and reopen the game to finish the update."
		changed.emit()
		return false
	get_tree().quit()
	return true

func _remove_download(path: String) -> void:
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)

func _fetch(url: String, limit: int, download_path: String = "") -> Dictionary:
	if not network_enabled: return {"ok": false, "error": "offline"}
	_request_generation += 1
	_request = HTTPRequest.new()
	_request.timeout = 30.0 if download_path.is_empty() else 300.0
	_request.body_size_limit = limit
	_request.max_redirects = 4
	_request.accept_gzip = false
	_request.download_file = download_path
	add_child(_request)
	_request.request_completed.connect(_on_request_completed.bind(_request, _request_generation))
	var error := _request.request(url, PackedStringArray(["Accept: application/vnd.github+json" if url == RELEASES_URL else "Accept: application/octet-stream", "User-Agent: Red-Veil-Updater"]))
	if error != OK:
		_request.queue_free()
		_request = null
		return {"ok": false, "error": "request_start"}
	var result: Dictionary = await transport_finished
	return result

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, completed_request: HTTPRequest, generation: int) -> void:
	# A cancelled request may already have queued its completion. It cannot finish a retry.
	if generation != _request_generation or completed_request != _request: return
	if is_instance_valid(_request): _request.queue_free()
	_request = null
	transport_finished.emit({"ok": result == HTTPRequest.RESULT_SUCCESS and code == 200, "code": code, "body": body})

func _process(_delta: float) -> void:
	if busy and status == "downloading" and is_instance_valid(_request) and not _manifest.is_empty():
		var next_progress := clampf(float(_request.get_downloaded_bytes()) / float(_manifest.pack_bytes), 0.0, 1.0)
		if absf(next_progress - progress) >= 0.01:
			progress = next_progress
			changed.emit()
