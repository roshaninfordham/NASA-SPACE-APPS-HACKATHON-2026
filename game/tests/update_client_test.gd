extends SceneTree
const Client = preload("res://updater/client.gd")
const Verifier = preload("res://updater/verifier.gd")
const UpdatePanel = preload("res://updater/panel.gd")
const PACK := "VALID PACK BYTES"
const CURRENT := "0.4.0-alpha.1"
const NEXT := "0.4.0-alpha.2"
var failures := 0
var cases := 0
var clients: Array = []
var test_root := "user://update-client-test-%d" % OS.get_process_id()

class FakeStore extends RefCounted:
	var allowed := true
	var manifest_error := ""
	var manifest_version := "0.4.0-alpha.2"
	var reject_stage := false
	var reject_activation := false
	var stage_calls := 0
	var activation_calls := 0
	var storage_busy := false
	var repair_calls := 0
	func configured() -> bool: return allowed
	func needs_repair() -> bool: return storage_busy
	func validate_manifest(_raw: PackedByteArray, _signature: PackedByteArray, _current: String) -> Dictionary:
		if not manifest_error.is_empty(): return {"ok": false, "error": manifest_error}
		return {"ok": true, "manifest": {"version": manifest_version, "pack_bytes": 16}}
	func stage(_raw: PackedByteArray, _signature: PackedByteArray, path: String, _current: String) -> Dictionary:
		stage_calls += 1
		if storage_busy: return {"ok": false, "error": "storage_busy"}
		if reject_stage or FileAccess.get_file_as_string(path) != "VALID PACK BYTES": return {"ok": false, "error": "pack_hash_mismatch"}
		return {"ok": true, "version": manifest_version}
	func activate(_version: String) -> Dictionary:
		activation_calls += 1
		return {"ok": not reject_activation}
	func repair_incomplete_lock() -> Dictionary:
		repair_calls += 1
		storage_busy = false
		return {"ok": true}

class FakeClient extends "res://updater/client.gd":
	var responses: Dictionary = {}
	var requests: Array = []
	var desktop := true
	var delay_frames := 1
	var restart_calls := 0
	func _desktop_supported() -> bool: return desktop
	func restart_game() -> bool:
		restart_calls += 1
		message = "Close and reopen the game to finish the update."
		return false
	func _fetch(url: String, limit: int, download_path: String = "") -> Dictionary:
		requests.append({"url": url, "limit": limit, "path": download_path})
		for i in range(delay_frames): await get_tree().process_frame
		var response: Dictionary = responses.get(url, {"ok": false, "error": "missing_fixture"}).duplicate(true)
		if response.get("ok", false) and response.get("body", PackedByteArray()).size() > limit:
			return {"ok": false, "error": "body_limit"}
		if not download_path.is_empty() and response.get("ok", false):
			var file := FileAccess.open(download_path, FileAccess.WRITE)
			if file == null: return {"ok": false, "error": "write_failed"}
			file.store_buffer(response.body)
			file.close()
		return response

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func release(version: String, has_pack: bool = true, draft: bool = false, prerelease: bool = true) -> Dictionary:
	var assets: Array = []
	if has_pack:
		for name in ["update-manifest.json", "update-manifest.sig", "red-veil-content.pck"]:
			assets.append({"name": name, "browser_download_url": "https://attacker.invalid/ignored"})
	return {"tag_name": "v" + version, "draft": draft, "prerelease": prerelease, "assets": assets}

func encoded(value: Variant) -> PackedByteArray: return JSON.stringify(value).to_utf8_buffer()

func make_client() -> FakeClient:
	cases += 1
	var client := FakeClient.new()
	root.add_child(client)
	client.configure(FakeStore.new(), CURRENT, test_root.path_join(str(cases)))
	client.responses[Client.RELEASES_URL] = {"ok": true, "body": encoded([release(NEXT)])}
	client.responses[Verifier.asset_url(NEXT, "update-manifest.json")] = {"ok": true, "body": "manifest".to_utf8_buffer()}
	client.responses[Verifier.asset_url(NEXT, "update-manifest.sig")] = {"ok": true, "body": "signature".to_utf8_buffer()}
	client.responses[Verifier.asset_url(NEXT, "red-veil-content.pck")] = {"ok": true, "body": PACK.to_utf8_buffer()}
	clients.append(client)
	return client

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var selected := Client.select_release(encoded([release("0.4.0-alpha.9"), release("0.4.0-alpha.10")]), CURRENT)
	check(selected.ok and selected.version == "0.4.0-alpha.10", "Recent release selection uses numeric version ordering")
	selected = Client.select_release(encoded([release("0.5.0-alpha.1"), release("0.5.0", true, false, true), release("0.4.1", true, false, false)]), "0.4.0")
	check(selected.version == "0.4.1", "Stable channel ignores alpha tags and GitHub prereleases")
	selected = Client.select_release(encoded([release("../../escape"), release("0.5.0", true, true), release(CURRENT)]), CURRENT)
	check(selected.version.is_empty(), "Drafts, unsafe tags, and equal versions are not offered")
	var too_many: Array = []
	for i in range(21): too_many.append(release(NEXT))
	check(not Client.select_release(encoded(too_many), CURRENT).ok and not Client.select_release("broken".to_utf8_buffer(), CURRENT).ok, "Malformed or oversized release lists rejected")
	var client := make_client()
	await client.check_for_updates(true)
	check(client.status == "available" and client.can_install(), "Verified metadata enables desktop installation")
	var fixed_paths := client.requests.size() == 3
	for request in client.requests: fixed_paths = fixed_paths and not request.url.contains("attacker")
	check(fixed_paths, "Release metadata cannot redirect manifest requests to arbitrary asset URLs")
	await client.install_update()
	check(client.ready_to_restart and client.store.activation_calls == 1 and client.status == "ready", "Valid download stages and activates once, awaiting explicit restart")
	check(client.requests.back().limit == 16 and not FileAccess.file_exists(client.working_directory.path_join("pending-download.pck")), "Pack download is capped and temporary file removed")
	await client.install_update()
	check(client.store.activation_calls == 1, "Repeated install cannot activate twice")
	var panel := UpdatePanel.new()
	panel.client = client
	root.add_child(panel)
	await process_frame
	check(panel.restart_button.visible and client.restart_calls == 0, "Ready update panel never restarts automatically")
	panel.restart_button.pressed.emit()
	check(client.restart_calls == 0 and panel.restart_button.text.contains("YES"), "Restart requires a separate confirmation")
	panel.restart_button.pressed.emit()
	check(client.restart_calls == 1 and panel.description.text.contains("Close and reopen"), "Confirmed restart failure gives a manual reopen instruction")
	panel.close()
	await process_frame
	client = make_client()
	client.check_for_updates(true)
	await client.check_for_updates(true)
	for i in range(5): await process_frame
	check(client.requests.size() == 3 and client.status == "available", "Overlapping checks cannot issue duplicate requests")
	client.install_update()
	await client.install_update()
	for i in range(3): await process_frame
	check(client.requests.size() == 4 and client.store.activation_calls == 1, "Overlapping installs download and activate only once")
	client = make_client()
	client.store.allowed = false
	await client.check_for_updates(true)
	await client.install_update()
	check(client.manual_update_required and not client.can_install() and client.requests.size() == 1 and client.store.stage_calls == 0, "Missing signing configuration offers only a manual release notice")
	client = make_client()
	client.desktop = false
	await client.check_for_updates(true)
	await client.install_update()
	check(client.manual_update_required and client.store.activation_calls == 0, "Web/mobile/development path cannot activate content packs")
	client = make_client()
	client.responses[Client.RELEASES_URL].body = encoded([release(NEXT, false)])
	await client.check_for_updates(true)
	check(client.manual_update_required and not client.can_install(), "New release without signed pack uses full-download notice")
	client = make_client()
	client.responses[Client.RELEASES_URL] = {"ok": false, "code": 403}
	await client.check_for_updates(true)
	check(client.status == "error" and not client.busy and client.available_version.is_empty(), "HTTP failure stays playable and never reports an installed update")
	client = make_client()
	client.store.manifest_error = "signature_invalid"
	await client.check_for_updates(true)
	await client.install_update()
	check(client.status == "error" and client.requests.size() == 3 and client.store.stage_calls == 0, "Invalid signature prevents pack download and activation")
	client = make_client()
	client.store.manifest_error = "engine_update_required"
	await client.check_for_updates(true)
	check(client.manual_update_required and client.message.contains("engine"), "Incompatible engine explains full-installer requirement")
	client = make_client()
	client.store.manifest_error = "runtime_update_required"
	await client.check_for_updates(true)
	check(client.manual_update_required and not client.can_install(), "Incompatible runtime contract requires a full installer")
	client = make_client()
	client.store.manifest_version = "0.4.0-alpha.3"
	await client.check_for_updates(true)
	check(client.status == "error" and not client.can_install(), "Signed manifest must match the selected release tag")
	client = make_client()
	await client.check_for_updates(true)
	client.responses[Verifier.asset_url(NEXT, "red-veil-content.pck")].body = "CORRUPT".to_utf8_buffer()
	await client.install_update()
	check(client.status == "error" and not client.ready_to_restart and client.store.activation_calls == 0, "Corrupt or truncated pack cannot activate")
	client.responses[Verifier.asset_url(NEXT, "red-veil-content.pck")].body = PACK.to_utf8_buffer()
	await client.install_update()
	check(client.ready_to_restart, "Failed download can be retried successfully")
	client = make_client()
	await client.check_for_updates(true)
	client.store.reject_activation = true
	await client.install_update()
	check(client.status == "error" and not client.ready_to_restart, "Journal activation failure cannot claim installation success")
	client = make_client()
	await client.check_for_updates(true)
	client.store.storage_busy = true
	await client.install_update()
	check(client.repair_available and client.store.repair_calls == 0, "Busy update storage is never repaired automatically")
	panel = UpdatePanel.new()
	panel.client = client
	root.add_child(panel)
	await process_frame
	panel.repair_button.pressed.emit()
	check(client.store.repair_calls == 0 and panel.description.text.contains("every other"), "Repair asks the player to close other windows first")
	panel.repair_button.pressed.emit()
	check(client.store.repair_calls == 1 and not client.repair_available, "Only explicit repair confirmation calls storage recovery")
	panel.close()
	await process_frame
	await client.install_update()
	check(client.ready_to_restart, "A repaired interrupted update can be retried")
	client = make_client()
	client.store.storage_busy = true
	client.configure(client.store, CURRENT, client.working_directory)
	check(client.repair_available and client.available_version.is_empty(), "Interrupted startup exposes repair before any release discovery")
	client = make_client()
	await client.check_for_updates(true)
	client.delay_frames = 3
	client.install_update()
	await process_frame
	client.cancel_download()
	for i in range(5): await process_frame
	check(client.status == "cancelled" and not client.busy and client.store.stage_calls == 0, "Cancelling download leaves current version unchanged")
	await client.install_update()
	check(client.ready_to_restart, "Cancelled download can be retried")
	client = make_client()
	await client.check_for_updates(true)
	var requests_before := client.requests.size()
	await client.check_for_updates(false)
	check(client.requests.size() == requests_before, "Automatic checks run at most once in the current session")
	await client.check_for_updates(true)
	check(client.requests.size() == requests_before, "Repeated manual checks are briefly throttled")
	# A legacy timestamp must not hide a newly published release on a fresh launch.
	var shared_folder: String = client.working_directory
	DirAccess.make_dir_recursive_absolute(shared_folder)
	var legacy_check := FileAccess.open(shared_folder.path_join("last-check.json"), FileAccess.WRITE)
	legacy_check.store_string(JSON.stringify({"checked_at": int(Time.get_unix_time_from_system())}))
	legacy_check.close()
	var reopened := make_client()
	reopened.configure(reopened.store, CURRENT, shared_folder)
	await reopened.check_for_updates(false)
	check(reopened.status == "available" and reopened.requests.size() == 3, "Fresh launch checks despite an old install's recent persisted timestamp")
	client = make_client()
	client.responses[Client.RELEASES_URL] = {"ok": false, "error": "offline"}
	await client.check_for_updates(false)
	await client.check_for_updates(false)
	check(client.status == "error" and client.requests.size() == 1, "Failed automatic check does not retry repeatedly within one session")
	reopened = make_client()
	reopened.configure(reopened.store, CURRENT, client.working_directory)
	await reopened.check_for_updates(false)
	check(reopened.status == "available", "Next launch retries discovery after a previous offline launch")
	client.responses[Client.RELEASES_URL] = {"ok": true, "body": encoded([release(NEXT)])}
	client._last_request_ticks = -Client.MANUAL_COOLDOWN_MS
	await client.check_for_updates(true)
	check(client.status == "available", "Manual retry remains available after the short throttle expires")
	# Exercise the real completion handler with a stale request after a retry began.
	var real_client := Client.new()
	root.add_child(real_client)
	var old_request := HTTPRequest.new()
	var new_request := HTTPRequest.new()
	real_client.add_child(old_request)
	real_client.add_child(new_request)
	real_client._request = new_request
	real_client._request_generation = 2
	var completions: Array = []
	real_client.transport_finished.connect(func(result): completions.append(result))
	real_client._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), PackedByteArray(), old_request, 1)
	check(real_client._request == new_request and completions.is_empty(), "Late completion from a cancelled request cannot finish a retry")
	real_client.queue_free()
	for item in clients:
		for name in ["last-check.json", "last-check.json.pending", "pending-download.pck"]:
			var path: String = item.working_directory.path_join(name)
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(item.working_directory)
		item.queue_free()
	DirAccess.remove_absolute(test_root)
	await process_frame
	quit(1 if failures else 0)
