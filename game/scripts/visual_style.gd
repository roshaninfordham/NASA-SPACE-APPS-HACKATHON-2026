extends RefCounted
## Shared presentation tokens. Motifs never alter science, equipment ratings or
## learning rewards. Brand identity remains exclusively in branding.gd.
const STYLE_PATH := "res://data/visual_style.json"
const PALETTE_KEYS := ["pearl", "pearl_pink", "crimson", "rose_gold", "coral", "cyan", "amber", "wine", "teal_panel", "white", "lacquer_shadow", "steel"]
const SURFACE_KEYS := ["pearl_roughness", "lacquer_roughness", "gold_roughness", "gold_metallic", "floor_roughness", "glass_roughness"]
const MOTIF_KEYS := ["seigaiha", "sakura", "kumiko", "obi", "hakama", "crane", "endless_knot"]
static var _cache: Dictionary = {}

static func validation_errors(candidate: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not candidate is Dictionary:
		errors.append("Visual style must be a JSON object")
		return errors
	if candidate.size() != 4 or candidate.get("schema_version") != 1:
		errors.append("Visual style requires schema_version 1 and three token groups")
	for group in ["palette", "surface", "motifs"]:
		if not candidate.get(group) is Dictionary:
			errors.append("Missing token group: " + group)
	if not errors.is_empty(): return errors
	var palette: Dictionary = candidate.palette
	var surface: Dictionary = candidate.surface
	var motifs: Dictionary = candidate.motifs
	if palette.size() != PALETTE_KEYS.size(): errors.append("Unexpected palette keys")
	for key in PALETTE_KEYS:
		var value: Variant = palette.get(key)
		if not value is String:
			errors.append("Missing palette string: " + key)
		elif value.length() != 7 or not value.begins_with("#") or not value.substr(1).is_valid_hex_number():
			errors.append("Palette must use six-digit hex RGB: " + key)
	if surface.size() != SURFACE_KEYS.size(): errors.append("Unexpected surface keys")
	for key in SURFACE_KEYS:
		var value: Variant = surface.get(key)
		if not (value is float or value is int):
			errors.append("Missing surface number: " + key)
		elif not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1.0:
			errors.append("Surface value must be finite and between zero and one: " + key)
	if motifs.size() != MOTIF_KEYS.size(): errors.append("Unexpected motif keys")
	for key in MOTIF_KEYS:
		if not motifs.get(key) is String or String(motifs.get(key, "")).strip_edges().is_empty():
			errors.append("Missing motif description: " + key)
	return errors

static func _data() -> Dictionary:
	if not _cache.is_empty(): return _cache
	var file := FileAccess.open(STYLE_PATH, FileAccess.READ)
	if file == null:
		push_error("Required visual style file is unavailable: " + STYLE_PATH)
		return {}
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK:
		push_error("Visual style is not valid JSON: " + json.get_error_message())
		return {}
	var errors := validation_errors(json.data)
	if not errors.is_empty():
		push_error("Invalid visual style: " + "; ".join(errors))
		return {}
	_cache = json.data.duplicate(true)
	return _cache

static func color(key: String) -> Color:
	var palette: Dictionary = _data().get("palette", {})
	if not palette.has(key):
		push_error("Unknown visual palette token: " + key)
		return Color.MAGENTA
	return Color.html(palette[key])

static func number(key: String) -> float:
	var surface: Dictionary = _data().get("surface", {})
	if not surface.has(key):
		push_error("Unknown visual surface token: " + key)
		return 0.5
	return float(surface[key])

static func motif(key: String) -> String:
	var motifs: Dictionary = _data().get("motifs", {})
	if not motifs.has(key):
		push_error("Unknown visual motif token: " + key)
		return ""
	return String(motifs[key])
