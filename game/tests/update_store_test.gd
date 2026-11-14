extends SceneTree
const Store = preload("res://updater/store.gd")
var failures := 0
var fixture: String
var key: CryptoKey

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func new_store(name: String, baseline: String = "0.3.0-alpha.1"):
	return Store.new(fixture.path_join("stores").path_join(name), baseline, key)

func stage(store, name: String, current: String = "0.3.0-alpha.1") -> Dictionary:
	var folder := fixture.path_join(name)
	return store.stage(FileAccess.get_file_as_bytes(folder.path_join("update-manifest.json")), FileAccess.get_file_as_bytes(folder.path_join("update-manifest.sig")), folder.path_join("red-veil-content.pck"), current)

func _initialize() -> void:
	fixture = OS.get_environment("RED_VEIL_UPDATE_TEST_DIR")
	if fixture.is_empty():
		push_error("Run scripts/test_update_bootstrap.py")
		quit(1)
		return
	key = CryptoKey.new()
	if key.load(fixture.path_join("public.pem"), true) != OK: quit(1); return
	var store = new_store("normal")
	check(store.prepare_boot().version == "0.3.0-alpha.1", "Fresh installation uses bundled version")
	check(stage(store, "a").ok, "Verified content copies into a fixed version slot")
	check(FileAccess.file_exists(fixture.path_join("a/red-veil-content.pck")), "Staging preserves the downloaded source")
	check(store.activate("0.3.1-alpha.1").ok, "Activation records a ready candidate")
	check(store.mark_healthy().ok, "Old running process cannot acknowledge an unstarted candidate")
	var journal: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.root_dir.path_join("state.json")))
	check(journal.status == "ready", "Pre-restart health acknowledgment leaves ready journal unchanged")
	var boot := store.prepare_boot()
	check(boot.version == "0.3.1-alpha.1" and not boot.pack_path.is_empty(), "Next startup selects verified candidate")
	check(store.mark_healthy().ok and store.mark_healthy().ok, "Health acknowledgment is idempotent")
	check(not store.activate("0.3.1-alpha.1").ok, "Same-version activation cannot overwrite recovery state")
	check(not stage(store, "a").ok, "An in-use content slot cannot be overwritten")
	check(stage(store, "b", "0.3.1-alpha.1").ok and store.activate("0.3.2-alpha.1").ok, "A newer update retains the last healthy slot")
	var next = new_store("normal")
	check(next.prepare_boot().version == "0.3.2-alpha.1", "Subsequent ready candidate starts its own trial")
	var second = new_store("normal")
	check(second.prepare_boot().version == "0.3.1-alpha.1", "Second instance does not roll back a still-live trial owner")
	check(next.mark_healthy().ok, "Original trial owner can still acknowledge health")
	var corrupt := FileAccess.open(store.slot_path("0.3.2-alpha.1").path_join("red-veil-content.pck"), FileAccess.WRITE)
	corrupt.store_buffer("tampered".to_utf8_buffer())
	corrupt.close()
	check(new_store("normal").prepare_boot().version == "0.3.1-alpha.1", "Corrupted active content rolls back to verified previous slot")
	check(new_store("normal", "0.4.0-alpha.1").prepare_boot().version == "0.4.0-alpha.1", "New installer cannot be downgraded by old cached content")
	var absent := Store.new(fixture.path_join("stores/no-key"), "0.3.0-alpha.1", null)
	check(not absent.configured() and not stage(absent, "a").ok, "Missing signing key disables content activation")
	check(store.slot_path("../../outside").is_empty(), "Version paths cannot escape update storage")
	check(store.slot_path("0.3.1-alpha.1\n").is_empty(), "Trailing-newline versions cannot name slots")
	check(store._tasklist_reports_alive('"Red,Veil.exe","123","Console","1","100 K"', 123), "Windows liveness handles commas in executable names")
	check(store._tasklist_reports_alive('"unexpected CSV"', 123), "Malformed Windows liveness output fails closed")
	var recovery = new_store("journal-recovery")
	check(stage(recovery, "a").ok and recovery.activate("0.3.1-alpha.1").ok, "Journal recovery fixture activates")
	var interrupted := FileAccess.open(recovery.root_dir.path_join("state.json"), FileAccess.WRITE)
	interrupted.store_string("{truncated")
	interrupted.close()
	check(recovery.prepare_boot().version == "0.3.0-alpha.1", "Incomplete initial journal safely uses bundled content")
	var first_claim := fixture.path_join("first-claim")
	var second_claim := fixture.path_join("second-claim")
	DirAccess.make_dir_recursive_absolute(first_claim)
	DirAccess.make_dir_recursive_absolute(second_claim)
	var ownership := FileAccess.open(second_claim.path_join("owner"), FileAccess.WRITE)
	ownership.store_string("claimed")
	ownership.close()
	check(DirAccess.rename_absolute(first_claim, second_claim) != OK, "Atomic directory rename cannot replace an existing nonempty lock")
	var locked = new_store("locked")
	var lock: String = locked.root_dir.path_join("mutation.lock")
	DirAccess.make_dir_recursive_absolute(lock)
	check(not stage(locked, "a").ok, "Incomplete owner lock fails closed")
	check(locked.repair_incomplete_lock().ok and stage(locked, "a").ok, "Explicit incomplete-lock repair restores installation")
	DirAccess.make_dir_recursive_absolute(lock)
	var owner := FileAccess.open(lock.path_join("owner"), FileAccess.WRITE)
	owner.store_string(str(OS.get_process_id()))
	owner.close()
	check(not locked.repair_incomplete_lock().ok, "Repair cannot break a known live process lock")
	quit(1 if failures else 0)
