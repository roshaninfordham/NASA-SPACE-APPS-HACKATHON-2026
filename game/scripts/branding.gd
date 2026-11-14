extends RefCounted
## Canonical presentation identity. Legacy storage, repository and updater identifiers
## intentionally remain separate so a presentation rename never strands saved games.
const BRAND_PATH := "res://data/brand.json"
const REQUIRED_FIELDS := ["display_name", "title", "subtitle", "package_stem", "package_slug", "legacy_product_name"]
static var _cache: Dictionary = {}

static func _data() -> Dictionary:
	if not _cache.is_empty(): return _cache
	var file := FileAccess.open(BRAND_PATH, FileAccess.READ)
	if file == null:
		push_error("Required canonical brand file is unavailable: " + BRAND_PATH)
		return {}
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK or not json.data is Dictionary:
		push_error("Canonical brand must be a valid JSON object: " + BRAND_PATH)
		return {}
	var candidate: Dictionary = json.data
	if candidate.size() != REQUIRED_FIELDS.size():
		push_error("Canonical brand has unexpected or missing fields")
		return {}
	for key in REQUIRED_FIELDS:
		if not candidate.has(key) or not candidate[key] is String or candidate[key].strip_edges().is_empty():
			push_error("Canonical brand field must be a nonempty string: " + key)
			return {}
	_cache = candidate.duplicate(true)
	return _cache

static func display_name() -> String:
	return String(_data().get("display_name", ""))

static func title() -> String:
	return String(_data().get("title", ""))

static func subtitle() -> String:
	return String(_data().get("subtitle", ""))

static func package_stem() -> String:
	return String(_data().get("package_stem", ""))
