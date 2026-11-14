extends SceneTree
const VisualStyle = preload("res://scripts/visual_style.gd")

func _initialize() -> void:
	var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VisualStyle.STYLE_PATH))
	assert(VisualStyle.validation_errors(candidate).is_empty())
	assert(VisualStyle.color("crimson").is_equal_approx(Color("a8102a")))
	assert(is_equal_approx(VisualStyle.number("lacquer_roughness"), 0.12))
	assert(VisualStyle.motif("seigaiha").begins_with("Japanese"))
	assert(VisualStyle.motif("endless_knot").begins_with("Chinese"))
	var invalid := candidate.duplicate(true)
	invalid.palette.crimson = "#XYZ123"
	assert(not VisualStyle.validation_errors(invalid).is_empty())
	invalid = candidate.duplicate(true)
	invalid.surface.lacquer_roughness = -0.1
	assert(not VisualStyle.validation_errors(invalid).is_empty())
	invalid = candidate.duplicate(true)
	invalid.surface.gold_metallic = NAN
	assert(not VisualStyle.validation_errors(invalid).is_empty())
	invalid = candidate.duplicate(true)
	invalid.motifs.erase("sakura")
	assert(not VisualStyle.validation_errors(invalid).is_empty())
	invalid = candidate.duplicate(true)
	invalid["radiation_bonus"] = 0.6
	assert(not VisualStyle.validation_errors(invalid).is_empty())
	# Reading or changing an independently parsed document cannot mutate the cache.
	candidate.palette.crimson = "#FFFFFF"
	assert(VisualStyle.color("crimson").is_equal_approx(Color("a8102a")))
	print("PASS: shared visual tokens validate colors, surface ranges and motif provenance; presentation excludes gameplay stats")
	quit()
