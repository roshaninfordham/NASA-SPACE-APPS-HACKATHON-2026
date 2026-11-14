class_name VeilUpdateVerifier
extends RefCounted
## This module never executes downloaded code. The bootstrap mounts only verified packs.
const REPOSITORY := "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"
const ENGINE := "4.6.3"
const RUNTIME_CONTRACT := "red-veil-desktop-v1"
const MAX_PACK_BYTES := 128 * 1024 * 1024
const MAX_MANIFEST_BYTES := 32 * 1024
const SCHEMA := 1

static func version_parts(value: String) -> Array:
	var pattern := RegEx.new()
	pattern.compile("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(?:-alpha\\.(0|[1-9][0-9]*))?$")
	var match_result := pattern.search(value)
	if match_result == null or match_result.get_string(0) != value or value.length() > 64: return []
	var prerelease := match_result.get_string(4)
	for index in range(1, 5):
		if match_result.get_string(index).length() > 9: return []
	return [int(match_result.get_string(1)), int(match_result.get_string(2)), int(match_result.get_string(3)), 1 if prerelease.is_empty() else 0, 0 if prerelease.is_empty() else int(prerelease)]

static func is_newer(candidate: String, current: String) -> bool:
	var a := version_parts(candidate)
	var b := version_parts(current)
	if a.is_empty() or b.is_empty(): return false
	for index in range(a.size()):
		if a[index] != b[index]: return a[index] > b[index]
	return false

static func asset_url(version: String, filename: String) -> String:
	if version_parts(version).is_empty(): return ""
	if filename not in ["update-manifest.json", "update-manifest.sig", "red-veil-content.pck"]: return ""
	return "https://github.com/%s/releases/download/v%s/%s" % [REPOSITORY, version, filename]

static func validate_manifest(raw: PackedByteArray, signature: PackedByteArray, pinned_key: Variant, current_version: String = "") -> Dictionary:
	if raw.is_empty() or raw.size() > MAX_MANIFEST_BYTES: return {"ok": false, "error": "manifest_size"}
	if signature.size() < 256 or signature.size() > 1024: return {"ok": false, "error": "signature_size"}
	var key: CryptoKey
	if pinned_key is CryptoKey:
		key = pinned_key
	elif pinned_key is String and FileAccess.file_exists(pinned_key):
		key = CryptoKey.new()
		if key.load(pinned_key, true) != OK: return {"ok": false, "error": "signing_not_configured"}
	else: return {"ok": false, "error": "signing_not_configured"}
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(raw)
	if not Crypto.new().verify(HashingContext.HASH_SHA256, hash.finish(), signature, key):
		return {"ok": false, "error": "signature_invalid"}
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK: return {"ok": false, "error": "manifest_json"}
	var parsed: Variant = json.data
	if not parsed is Dictionary: return {"ok": false, "error": "manifest_json"}
	var manifest: Dictionary = parsed
	if manifest.get("schema") != SCHEMA: return {"ok": false, "error": "unsupported_schema"}
	if manifest.get("repository") != REPOSITORY: return {"ok": false, "error": "wrong_repository"}
	if manifest.get("engine") != ENGINE: return {"ok": false, "error": "engine_update_required"}
	if manifest.get("runtime_contract") != RUNTIME_CONTRACT: return {"ok": false, "error": "runtime_update_required"}
	var version: Variant = manifest.get("version")
	if not version is String or version_parts(version).is_empty(): return {"ok": false, "error": "version_invalid"}
	if not current_version.is_empty() and not is_newer(version, current_version): return {"ok": false, "error": "not_newer"}
	if manifest.get("pack_file") != "red-veil-content.pck": return {"ok": false, "error": "pack_name_invalid"}
	var size: Variant = manifest.get("pack_bytes")
	if not (size is float or size is int) or size <= 0 or size != floor(size) or size > MAX_PACK_BYTES: return {"ok": false, "error": "pack_size_invalid"}
	var digest: Variant = manifest.get("pack_sha256")
	if not digest is String or not matches_hex(digest, 64): return {"ok": false, "error": "digest_invalid"}
	var source: Variant = manifest.get("source_commit")
	if not source is String or not matches_hex(source, 40): return {"ok": false, "error": "source_invalid"}
	return {"ok": true, "manifest": manifest}

static func matches_hex(value: String, length: int) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[0-9a-f]{%d}$" % length)
	var found := pattern.search(value)
	return found != null and found.get_string(0) == value

static func validate_pack(path: String, manifest: Dictionary) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false, "error": "pack_missing"}
	var size := file.get_length()
	file.close()
	if size != int(manifest.pack_bytes): return {"ok": false, "error": "pack_size_mismatch"}
	if FileAccess.get_sha256(path) != manifest.pack_sha256: return {"ok": false, "error": "pack_hash_mismatch"}
	return {"ok": true}
