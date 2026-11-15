extends SceneTree
const Mission = preload("res://scripts/training_mission.gd")
var failures := 0
var assertions := 0

func check(value: bool, message: String) -> void:
	assertions += 1
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func close(a: float, b: float, tolerance: float = 0.000001) -> bool:
	return absf(a - b) <= tolerance

func perform_plan(count: int, pace: float = 1.0, frame_seconds: float = 0.0):
	var model := Mission.new()
	model.set_pace(pace)
	if count > 0:
		model.start_cleaning()
		advance_for(model, 60.0 * count / pace, frame_seconds)
	model.request_return()
	advance_for(model, 90.0 / pace, frame_seconds)
	return model

func advance_for(model, seconds: float, frame_seconds: float) -> void:
	if frame_seconds <= 0.0:
		model.advance(seconds)
		return
	var left := seconds
	while left > 0.0:
		var step := minf(left, frame_seconds)
		model.advance(step)
		left = maxf(0.0, left - step)

func _initialize() -> void:
	var model := Mission.new()
	var initial: Dictionary = model.snapshot()
	check(initial.scenario_id == "window-training-v1" and initial.status == "running" and initial.phase == "outside", "Fresh model identifies its scenario and waiting astronaut")
	check(close(initial.remaining_seconds, 300.0) and close(initial.return_seconds_remaining, 90.0), "Five-minute round contains a ninety-second return")
	check(close(initial.walk_sim_seconds, 432.0 / 0.8) and close(initial.warning_seconds, 1800.0), "Return time derives from distance divided by speed")
	check(initial.sections_needed == 2 and initial.max_additional_sections == 3, "Two sections meet margin while three fit the starting deadline")
	check(close(initial.power_margin_sols, 1.0 / 0.28), "Initial output margin is divided by the explicit scenario dust trend")
	check(close(initial.dose_rate_ugy_per_hour, 210.0 / 24.0), "Historical microgray reference is converted per twenty-four-hour day")
	check(not initial.has("dose_msv"), "Absorbed dose is never relabeled or converted to personal sievert dose")
	check(initial.dose_ugy == 0 and not initial.crew_sheltered, "No starting dose or instant shelter protection is invented")

	for count in range(5):
		var run = perform_plan(count)
		var outcome: Dictionary = run.result()
		var planned_seconds := 540.0 + count * 360.0
		var measured_seconds := minf(planned_seconds, 1800.0)
		var expected_status := "power-shortfall" if count < 2 else ("late" if count == 4 else "success")
		check(outcome.status == expected_status, "Independent section-count outcome " + str(count))
		check(close(outcome.sim_elapsed_seconds, measured_seconds) and close(outcome.elapsed_seconds, measured_seconds / 6.0), "Round stops exactly at arrival or deadline for plan " + str(count))
		check(close(outcome.dose_ugy, 210.0 * measured_seconds / 86400.0), "Absorbed dose integrates only actual simulated time for plan " + str(count))
		check(outcome.sections_cleaned == count and close(outcome.power_margin_sols, (1.0 + 2.0 * count) / 0.28), "Each completed section earns its gain once for plan " + str(count))
		check(outcome.crew_sheltered == (count < 4), "Late return never grants shelter protection for plan " + str(count))
		var comparison: Dictionary = run.plan_for_sections(count)
		check(comparison.status == outcome.status and close(comparison.dose_ugy, outcome.dose_ugy), "Analytical comparison agrees with actual trajectory " + str(count))
		check(comparison.minimum_sections_for_margin == 2 and close(comparison.latest_departure_sim_seconds, 1260.0), "Analytical plan exposes minimum sections and latest departure " + str(count))
		var stopped := run.snapshot()
		check(not run.start_cleaning() and not run.stop_cleaning() and not run.request_return(), "Terminal state rejects all action mutations for plan " + str(count))
		run.advance(10000.0)
		check(run.snapshot() == stopped, "Terminal model remains unchanged after time advances " + str(count))

	var held := Mission.new()
	check(held.start_cleaning() and not held.start_cleaning(), "Repeated clean command cannot restart or duplicate work")
	held.advance(30.0)
	check(close(held.snapshot().section_progress, 0.5) and held.snapshot().sections_cleaned == 0, "Incomplete work has progress but grants no margin")
	check(held.stop_cleaning() and not held.stop_cleaning(), "Pause-cleaning action is idempotent")
	held.advance(10.0)
	check(close(held.snapshot().section_progress, 0.5) and close(held.snapshot().sim_elapsed_seconds, 240.0), "Stopping cleaning preserves work while time and radiation continue")
	held.start_cleaning()
	held.advance(30.0)
	check(held.snapshot().sections_cleaned == 1 and close(held.snapshot().section_progress, 0), "Resuming completes the same section without double work")
	held.advance(10.0)
	check(held.request_return() and not held.request_return(), "Return is accepted once and cannot restart the route")
	check(held.snapshot().sections_cleaned == 1 and close(held.snapshot().section_progress, 0) and not held.snapshot().cleaning, "Return discards incomplete section work and preserves completed gains")
	check(not held.start_cleaning(), "Cleaning cannot resume during the return")
	held.advance(81.0)
	check(held.snapshot().phase == "airlock" and close(held.snapshot().return_progress, 0.9) and not held.snapshot().crew_sheltered, "Final approach is visual airlock entry without granting protection early")
	held.advance(9.0)
	check(held.snapshot().phase == "sheltered" and close(held.snapshot().return_progress, 1), "Shelter applies only at completed entry with no extra hidden delay")

	var exact := Mission.new()
	exact.start_cleaning()
	exact.advance(120.0)
	exact.stop_cleaning()
	exact.advance(90.0)
	exact.request_return()
	exact.advance(90.0)
	check(exact.snapshot().status == "success" and close(exact.snapshot().sim_elapsed_seconds, 1800.0), "Arrival exactly at the inclusive deadline is accepted")
	var late := Mission.new()
	late.start_cleaning()
	late.advance(120.0)
	late.stop_cleaning()
	late.advance(90.001)
	late.request_return()
	late.advance(100.0)
	check(late.snapshot().status == "late" and not late.snapshot().crew_sheltered and late.snapshot().return_progress < 1.0, "Departure one millisecond late cannot round into protected arrival")
	var idle := Mission.new()
	idle.advance(999999999999.0)
	check(idle.snapshot().status == "late" and close(idle.snapshot().sim_elapsed_seconds, 1800.0) and idle.snapshot().phase == "outside", "Huge delta is bounded at deadline without teleporting the astronaut")
	check(idle.snapshot().history.size() == 31, "History samples are bounded to one point per simulated minute")

	for pace in [0.5, 1.0, 2.0]:
		var one = perform_plan(3, pace)
		var many = perform_plan(3, pace, 0.037)
		var a: Dictionary = one.snapshot()
		var b: Dictionary = many.snapshot()
		check(a.status == b.status and a.sections_cleaned == b.sections_cleaned and a.phase == b.phase, "Frame partition preserves discrete state at pace " + str(pace))
		check(close(a.sim_elapsed_seconds, b.sim_elapsed_seconds) and close(a.dose_ugy, b.dose_ugy) and close(a.power_margin_sols, b.power_margin_sols), "Frame partition preserves physics and output at pace " + str(pace))
		check(close(a.elapsed_seconds, 270.0 / pace) and close(a.sim_elapsed_seconds, 1620.0), "Accessibility pace changes play duration, not mission science: " + str(pace))
		check(a.history.size() == b.history.size() and a.events.size() == b.events.size(), "Pace and frame partition keep deterministic trace/event counts: " + str(pace))
	var changing := Mission.new()
	changing.start_cleaning()
	changing.advance(30.0)
	changing.set_pace(2.0)
	changing.advance(15.0)
	check(changing.snapshot().sections_cleaned == 1 and close(changing.snapshot().elapsed_seconds, 45.0) and close(changing.snapshot().sim_elapsed_seconds, 360.0), "Changing pace preserves prior real time, physics and partial work")
	check(not changing.set_pace(0.0) and not changing.set_pace(1.5) and not changing.set_pace(INF), "Only supported accessibility clock rates are accepted")
	var before_invalid: Dictionary = changing.snapshot()
	for delta in [-1.0, 0.0, NAN, INF]: changing.advance(delta)
	check(changing.snapshot() == before_invalid, "Invalid time deltas do not corrupt live state")
	var tiny := Mission.new()
	for index in range(1000): tiny.advance(0.000000001)
	check(close(tiny.snapshot().elapsed_seconds, 0.000001, 0.00000000001), "Positive subframe time is not silently dropped")

	for options in [
		{"walking_speed_mps": 0.0}, {"distance_m": -1.0}, {"dust_loss_points_per_sol": 0.0},
		{"background_dose_ugy_per_day": -1.0}, {"warning_seconds": NAN}, {"time_scale": INF},
		{"section_work_seconds": -1.0}, {"max_sections": 4.5}, {"unexpected": 1},
		{"walking_speed_mps": "0.8"}, {"dose_reference_day_seconds": 88775.0},
		{"walking_speed_mps": 1e-300}, {"dust_loss_points_per_sol": 1e-300}, {"time_scale": 1e-300},
	]:
		check(not changing.reset(options) and changing.snapshot() == before_invalid, "Invalid scenario is rejected without replacing current state: " + str(options))
	var fast := Mission.new({"walking_speed_mps": 1.2})
	var invalid_constructor := Mission.new({"walking_speed_mps": -1.0})
	check(invalid_constructor.snapshot() == model.snapshot(), "Invalid constructor options fall back to a completely initialized canonical scenario")
	check(close(fast.snapshot().walk_sim_seconds, 360.0) and fast.plan_for_sections(4).status == "success", "Custom scenario walking speed follows d/v and changes feasible complete sections")
	var slow := Mission.new({"walking_speed_mps": 0.2})
	check(slow.snapshot().max_additional_sections == 0 and not slow.snapshot().can_return_on_time and slow.plan_for_sections(0).status == "late", "Impossible return does not produce a negative section count or claim zero-section feasibility")
	check(not model.plan_for_sections(-1).valid and not model.plan_for_sections(5).valid and not model.plan_for_sections(2, 0.0).valid, "Planner rejects invalid section counts and speed without division by zero")
	var at_door := Mission.new({"distance_m": 0.0, "initial_spare_power_points": 5.0})
	at_door.request_return()
	check(at_door.snapshot().status == "success" and at_door.snapshot().crew_sheltered and close(at_door.snapshot().sim_elapsed_seconds, 0.0), "Zero-distance scenario can enter immediately without a division by zero")

	var untouched: Dictionary = exact.snapshot()
	var exported: Dictionary = exact.result()
	exported.assumptions.distance_m = 9000.0
	exported.history[0].dose_ugy = 9999.0
	exported.events[0].kind = "tampered"
	exported.comparisons[0].status = "tampered"
	check(exact.snapshot() == untouched, "Exported assumptions, history, events and comparisons cannot mutate live model")
	var flood := Mission.new()
	for index in range(500):
		flood.start_cleaning()
		flood.stop_cleaning()
	check(flood.snapshot().events.size() == Mission.MAX_EVENTS and flood.snapshot().sections_cleaned == 0 and flood.snapshot().dose_ugy == 0.0, "Repeated inputs have bounded history and cannot mint work or time")
	check(exact.reset() and exact.snapshot().status == "running" and exact.snapshot().sections_cleaned == 0 and exact.snapshot().history.size() == 1, "Reset clears run state and restores the canonical scenario")
	print("TRAINING MISSION ASSERTIONS: ", assertions, " FAILURES: ", failures)
	quit(1 if failures else 0)
