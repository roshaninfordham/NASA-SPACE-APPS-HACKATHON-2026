extends SceneTree
const Graphics = preload("res://scripts/graphics_preferences.gd")
var failures := 0
var checks := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(description)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var ordinary := {"memory_bytes": 8 * 1024 * 1024 * 1024, "adapter": "integrated", "compact": false}
	var roomy := {"memory_bytes": 16 * 1024 * 1024 * 1024, "adapter": "hardware GPU", "compact": false}
	check(Graphics.resolve("auto", {}) == "low", "Unknown hardware starts conservatively")
	check(Graphics.resolve("auto", ordinary) == "low", "8 GiB devices start with battery saver")
	check(Graphics.resolve("auto", roomy) == "balanced", "Larger desktop starts balanced, never automatically high")
	var mobile := roomy.duplicate(); mobile.compact = true
	check(Graphics.resolve("auto", mobile) == "low", "Mobile/browser remains conservative regardless of RAM")
	var software := roomy.duplicate(); software.adapter = "llvmpipe"
	check(Graphics.resolve("auto", software) == "low", "Software rendering avoids costly defaults")
	check(Graphics.resolve("high", ordinary) == "high", "Player can explicitly override conservative hints")
	check(Graphics.load_mode() == "auto", "Fresh profile starts Auto")
	check(Graphics.save_mode("high") == OK and Graphics.load_mode() == "high", "Manual choice persists")
	check(Graphics.save_mode("ultra") == ERR_INVALID_PARAMETER and Graphics.load_mode() == "high", "Invalid preference cannot replace a valid choice")
	var file := ConfigFile.new(); file.set_value("graphics", "mode", "invalid"); file.save(Graphics.PATH)
	check(Graphics.load_mode() == "auto", "Malformed preference falls back to Auto")
	Graphics.save_mode("low")
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(5): await process_frame
	check(game.graphics_mode == "low" and Engine.max_fps == 30, "Saved preference applies before entering the world")
	await game.start_mission()
	game.set_process(false)
	var before: Dictionary = game.model.snapshot().duplicate(true)
	check(not game.world.sun.shadow_enabled and not game.world.dust_particles.emitting, "Battery saver avoids shadow and decorative dust work")
	check(root.msaa_3d == Viewport.MSAA_DISABLED, "Battery saver disables MSAA")
	game.set_graphics_mode("high")
	check(root.msaa_3d == Viewport.MSAA_4X and Engine.max_fps == 60, "High selects its explicit rendering budget")
	check(game.world.sun.shadow_enabled, "High restores profile shadows")
	game.progress.set_setting("reduced_motion", true); game._apply_preferences()
	check(not game.world.dust_particles.emitting, "Reduced motion wins over High decorative particles")
	game.show_settings()
	var selector: OptionButton = game.modal.find_child("GraphicsQuality", true, false)
	check(selector != null and selector.selected == 3, "Settings exposes current choice")
	selector.select(2); selector.item_selected.emit(2)
	check(game.graphics_mode == "balanced" and Graphics.load_mode() == "balanced", "Settings changes and saves the actual presentation")
	check(game.model.snapshot() == before, "Switching graphics and accessibility leaves mission values unchanged")
	game.queue_free()
	for i in range(3): await process_frame
	print("GRAPHICS PREFERENCES: ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
