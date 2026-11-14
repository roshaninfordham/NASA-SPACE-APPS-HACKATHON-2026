extends Node
## This autoload must be first. Load trusted code/key before mounting signed content.
const Store = preload("res://updater/store.gd")
var store: Store
var running_version := ""
var startup_notice := ""

func _init() -> void:
	var baseline := str(ProjectSettings.get_setting("application/config/version", ""))
	var pinned: CryptoKey
	if FileAccess.file_exists("res://updater/public_key.pem"):
		pinned = CryptoKey.new()
		if pinned.load("res://updater/public_key.pem", true) != OK: pinned = null
	# Source previews must never mount production cache over the checked-out code.
	var storage := "user://development-updates" if OS.has_feature("editor") else "user://updates"
	store = Store.new(storage, baseline, pinned)
	running_version = baseline
	# Editor imports and command-line test scripts must not mutate a player's profile.
	if Engine.is_editor_hint() or "--script" in OS.get_cmdline_args() or "-s" in OS.get_cmdline_args(): return
	# Web and mobile distributions require their own platform update mechanism.
	if OS.has_feature("web") or OS.has_feature("Android") or OS.has_feature("iOS"): return
	var selected := store.prepare_boot()
	startup_notice = selected.notice
	running_version = selected.version
	if selected.pack_path.is_empty(): return
	if not ProjectSettings.load_resource_pack(selected.pack_path, true):
		selected = store.mount_failed()
		startup_notice = selected.notice
		running_version = selected.version
		if not selected.pack_path.is_empty() and not ProjectSettings.load_resource_pack(selected.pack_path, true):
			running_version = baseline
			startup_notice = "The saved updates could not open. The bundled game is running."

func mark_healthy() -> void:
	var result := store.mark_healthy()
	if not result.ok: startup_notice = "The update started, but its recovery record could not be saved. Your earlier version may return next time."
