extends SceneTree
const Verifier = preload("res://updater/verifier.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func _initialize() -> void:
	var folder := OS.get_environment("RED_VEIL_TEST_FIXTURES")
	if folder.is_empty():
		push_error("Run through scripts/test_updater.py to generate ephemeral signing fixtures")
		quit(1)
		return
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("cases.json")))
	for spec in cases:
		var manifest := FileAccess.get_file_as_bytes(folder.path_join(spec.name + ".json"))
		var signature := FileAccess.get_file_as_bytes(folder.path_join(spec.name + ".sig"))
		var result := Verifier.validate_manifest(manifest, signature, folder.path_join("public.pem"), "0.2.0-alpha.2")
		check(result.ok == spec.ok and (spec.ok or result.error == spec.error), "Signed manifest: " + spec.name)
	var valid := Verifier.validate_manifest(FileAccess.get_file_as_bytes(folder.path_join("valid.json")), FileAccess.get_file_as_bytes(folder.path_join("valid.sig")), folder.path_join("public.pem"))
	check(Verifier.validate_pack(folder.path_join("pack.pck"), valid.manifest).ok, "Exact pack hash and length accepted")
	check(not Verifier.validate_pack(folder.path_join("altered.pck"), valid.manifest).ok, "Same-size tampered pack rejected")
	check(not Verifier.validate_pack(folder.path_join("short.pck"), valid.manifest).ok, "Truncated pack rejected")
	check(Verifier.is_newer("0.2.0-alpha.10", "0.2.0-alpha.9"), "Numeric prerelease ordering")
	check(Verifier.is_newer("0.2.0", "0.2.0-alpha.10"), "Stable version follows prereleases")
	check(not Verifier.is_newer("0.2.0-alpha.10", "0.2.0"), "Stable version cannot downgrade to alpha")
	check(Verifier.version_parts("99999999999999999999.0.0").is_empty(), "Overflowing version rejected")
	check(Verifier.asset_url("../../escape", "red-veil-content.pck").is_empty(), "Version cannot escape release path")
	check(Verifier.asset_url("0.3.0", "evil.exe").is_empty(), "Only fixed asset names accepted")
	quit(1 if failures else 0)
