extends RefCounted
## Presentation only. No mission parameters or automatic content downloads.
const PATH := "user://graphics-settings.cfg"
const MODES := ["auto", "low", "balanced", "high"]
const TITLES := ["Auto", "Battery saver", "Balanced", "High"]

static func load_mode() -> String:
	var settings := ConfigFile.new()
	if settings.load(PATH) != OK: return "auto"
	var value: Variant = settings.get_value("graphics", "mode", "auto")
	return value if value is String and value in MODES else "auto"

static func save_mode(mode: String) -> Error:
	if not mode in MODES: return ERR_INVALID_PARAMETER
	var settings := ConfigFile.new()
	settings.set_value("graphics", "mode", mode)
	return settings.save(PATH)

static func device_hints() -> Dictionary:
	return {
		"compact": OS.has_feature("mobile") or OS.has_feature("web"),
		"memory_bytes": OS.get_memory_info().get("physical", 0),
		"adapter": RenderingServer.get_video_adapter_name().to_lower(),
	}

static func resolve(mode: String, hints: Dictionary) -> String:
	if mode in ["low", "balanced", "high"]: return mode
	# RAM is only a conservative starting hint, not a GPU benchmark. Unknown
	# capability and software rendering select the smallest presentation budget.
	var memory := int(hints.get("memory_bytes", 0))
	var adapter := str(hints.get("adapter", "")).to_lower()
	if bool(hints.get("compact", false)) or memory <= 8 * 1024 * 1024 * 1024: return "low"
	if adapter.is_empty() or "llvmpipe" in adapter or "lavapipe" in adapter or "software" in adapter: return "low"
	return "balanced"

static func budget(resolved: String) -> Dictionary:
	match resolved:
		"high": return {"fps": 60, "msaa": Viewport.MSAA_4X, "shadows": true, "dust_fraction": 1.0}
		"balanced": return {"fps": 60, "msaa": Viewport.MSAA_2X, "shadows": true, "dust_fraction": 0.5}
		_: return {"fps": 30, "msaa": Viewport.MSAA_DISABLED, "shadows": false, "dust_fraction": 0.0}

static func apply(viewport: Viewport, world: Node3D, resolved: String, reduced_motion: bool) -> void:
	var selected := budget(resolved)
	Engine.max_fps = selected.fps
	viewport.msaa_3d = selected.msaa
	if not is_instance_valid(world): return
	if is_instance_valid(world.sun): world.sun.shadow_enabled = world.art.shadows_enabled and selected.shadows
	if is_instance_valid(world.dust_particles):
		var count := int(world.art.dust_particle_count * selected.dust_fraction)
		world.dust_particles.amount = maxi(1, count)
		world.dust_particles.emitting = count > 0 and not reduced_motion

static func description(mode: String, hints: Dictionary) -> String:
	var selected := resolve(mode, hints)
	var title: String = TITLES[MODES.find(selected)]
	return ("Auto starts with " + title + ". " if mode == "auto" else title + ". ") + "Only graphics change; your mission stays the same."
