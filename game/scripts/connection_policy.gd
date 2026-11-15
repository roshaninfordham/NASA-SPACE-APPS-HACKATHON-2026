extends RefCounted
## Optional connectivity only; core play, coaching and saves stay local.
const PATH := "user://connection-settings.cfg"
static func load_enabled() -> bool:
	if "--offline" in OS.get_cmdline_user_args(): return false
	var settings := ConfigFile.new()
	if settings.load(PATH) != OK: return false
	var value: Variant = settings.get_value("network", "enabled", false)
	return value is bool and value
static func save_enabled(enabled: bool) -> Error:
	var settings := ConfigFile.new()
	settings.set_value("network", "enabled", enabled)
	return settings.save(PATH)
