extends SceneTree
const Mission = preload("res://scripts/mission.gd")
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1
	else: print("PASS: ", message)
func _initialize() -> void:
	var m := Mission.new()
	var before := m.energy
	var env := m.environment()
	m.step()
	check(absf(m.energy - before - env.net * Mission.STEP_HOURS) < 0.000001, "Habitat energy conservation")
	var clear := Mission.new()
	var dirty := Mission.new()
	clear.visor_cleaning = true
	clear.step(Mission.STEP_HOURS, true)
	dirty.step(Mission.STEP_HOURS, true)
	check(clear.suit_energy < dirty.suit_energy, "Visor cleaner uses suit battery")
	check(clear.energy == dirty.energy, "Visor cleaner does not use habitat battery")
	check(clear.inspection > dirty.inspection, "Clearer visor improves tactile inspection")
	var safe := Mission.new()
	safe.shelter = true
	safe.conserving = true
	var original_suit := safe.suit_energy
	for i in range(1500): safe.step()
	check(safe.status == "success", "Shelter and conservation provide a viable policy")
	check(safe.suit_energy == original_suit, "Indoor suit is not drained or recharged")
	check(Mission.fixed_baseline().status == "power-abort", "Fixed policy ends from modeled power loss")
	var unprotected := Mission.new()
	unprotected.conserving = true
	for i in range(1500): unprotected.step()
	check(unprotected.status == "dose-abort", "Unsheltered particle event aborts mission")
	var stopped := unprotected.time
	unprotected.step()
	check(stopped == unprotected.time, "Terminal state does not advance")
	quit(1 if failures else 0)
