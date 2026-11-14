extends SceneTree
const Mission = preload("res://scripts/mission.gd")
const Adviser = preload("res://scripts/mission_adviser.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1
func state_of(mission) -> Dictionary:
	var result := {}
	for property in mission.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = mission.get(property.name)
			result[property.name] = value.duplicate(true) if value is Dictionary or value is Array else value
	return result
func mission_from_fixture(fixture: Dictionary) -> VeilMission:
	var result := Mission.new()
	for key in fixture: result.set(key, fixture[key])
	return result

func compare_real_trajectories() -> void:
	# Each fixture is initialized independently for the adviser and four actual
	# mission runs. Expected trajectories call the production integrator, not a
	# second implementation of its equations or the adviser's cloning helper.
	var fixtures := [
		{"time": 0.0, "energy": 1.1, "inspection": 0.25, "suit_energy": 0.9, "dose": 0.02, "shelter": false},
		{"time": 3.8, "energy": 6.5, "dust": 0.45, "background_dose": 0.82, "event_start": 4.0, "event_end": 4.5, "peak_tau": 1.6, "shelter": true},
		{"time": 11.5, "energy": 2.45, "dust": 0.4, "suit_energy": 0.04, "visor_cleaning": true, "shelter": false},
		{"time": 5.0, "energy": 11.95, "dust": 0.0, "peak_tau": 0.0, "shelter": true},
		{"time": 4.5, "energy": 5.0, "dose": 3.97, "event_start": 4.25, "event_end": 4.8, "shelter": false}
	]
	for index in range(fixtures.size()):
		var fixture: Dictionary = fixtures[index]
		var source := mission_from_fixture(fixture)
		var before := state_of(source)
		var report := Adviser.analyze(source, 0.75)
		check(state_of(source) == before, "Scenario %d preview leaves the original state untouched" % index)
		check(report.habitat_capacity_kwh == Mission.CAPACITY, "Chart capacity follows the actual model in scenario %d" % index)
		for plan in report.options:
			var actual := mission_from_fixture(fixture)
			actual.conserving = plan.conserving
			actual.cleaning = plan.cleaning
			var end_time: float = minf(Mission.DURATION, actual.time + 0.75)
			while actual.status == "running" and actual.time < end_time - 0.000000001:
				actual.step(minf(Mission.STEP_HOURS, end_time - actual.time), false)
			check(is_equal_approx(plan.habitat_kwh, actual.energy) and is_equal_approx(plan.suit_kwh, actual.suit_energy) and is_equal_approx(plan.dose_msv, actual.dose), "Scenario %d %s matches actual batteries and dose" % [index, plan.id])
			check(plan.status == actual.status and is_equal_approx(plan.elapsed_hours, actual.time - source.time), "Scenario %d %s reports the actual stop reason and duration" % [index, plan.id])
			check(is_equal_approx(plan.panel_dust, actual.dust) and is_equal_approx(plan.research_gained, actual.research - source.research), "Scenario %d %s preserves dust and work tradeoffs" % [index, plan.id])
			check(plan.habitat_kwh >= 0.0 and plan.habitat_kwh <= report.habitat_capacity_kwh and plan.suit_kwh >= 0.0 and plan.dose_added_msv >= 0.0, "Scenario %d %s preserves physical model bounds" % [index, plan.id])
		if report.recommendation.cleaning != "not_comparable":
			var offset := 2 if source.conserving else 0
			check(report.options[offset].reaches_horizon and report.options[offset + 1].reaches_horizon, "Cleaner comparison never rewards a shorter failed run in scenario %d" % index)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var mission := Mission.new()
	mission.background_dose = 0.91
	mission.baseline = {"nested": {"marker": [1, 2, 3]}}
	var original := state_of(mission)
	var env: Dictionary = mission.environment()
	var one: Dictionary = Adviser.analyze(mission, Mission.STEP_HOURS)
	check(state_of(mission) == original, "Preview preserves all live mission state, including nested baseline data")
	check(one.options.size() == 4, "Four cleaner/work combinations are returned without choosing a universal winner")
	var off: Dictionary = one.options[0]
	check(is_equal_approx(off.habitat_kwh, mission.energy + env.net * Mission.STEP_HOURS), "One-step forecast obeys analytical energy balance")
	check(is_equal_approx(off.dose_added_msv, 0.91 / 24.0 * Mission.STEP_HOURS), "Historical/scenario dose parameter is copied rather than reset to default")
	check(is_equal_approx(one.options[0].habitat_kwh - one.options[1].habitat_kwh, 0.9 * Mission.STEP_HOURS), "First cleaning step pays the actual 0.9 kW load before cleaner panels help")
	check(is_equal_approx(one.options[2].habitat_kwh - one.options[0].habitat_kwh, 0.63 * Mission.STEP_HOURS), "Conservation reduces only the modeled nonessential electrical load")
	check(is_equal_approx(one.options[0].research_gained - one.options[2].research_gained, 0.75 * Mission.STEP_HOURS), "Energy conservation exposes its work tradeoff")
	var repeated := Adviser.analyze(mission, Mission.STEP_HOURS)
	check(repeated == one, "Identical state and horizon produce deterministic results")
	one.options[0].habitat_kwh = -999.0
	one.assumptions[0] = "changed by caller"
	check(Adviser.analyze(mission, Mission.STEP_HOURS) == repeated, "Returned reports do not alias cached model or shared assumptions")
	# Independent real Mission run, explicitly set scenario parameters. This
	# checks trajectory agreement without duplicating the forecast equations.
	mission.time = 5.0
	mission.shelter = true
	mission.dust = 0.8
	mission.inspection = 0.7
	mission.peak_tau = 4.0
	mission.event_start = 4.5
	mission.event_end = 5.5
	mission.energy = 7.0
	mission.visor_cleaning = true
	var independent := Mission.new()
	independent.time = 5.0
	independent.shelter = true
	independent.dust = 0.8
	independent.inspection = 0.7
	independent.peak_tau = 4.0
	independent.event_start = 4.5
	independent.event_end = 5.5
	independent.energy = 7.0
	independent.visor_cleaning = true
	independent.background_dose = 0.91
	independent.conserving = true
	independent.cleaning = true
	for step in range(120): independent.step()
	var storm := Adviser.analyze(mission)
	var projection: Dictionary = storm.options[3]
	check(is_equal_approx(projection.habitat_kwh, independent.energy) and is_equal_approx(projection.dose_msv, independent.dose) and is_equal_approx(projection.panel_dust, independent.dust), "Projection matches independent real mission integration across custom event end")
	check(storm.recommendation.cleaning == "off", "During opaque sky, cleaner costs more battery than it recovers in the preview")
	check(is_equal_approx(projection.suit_kwh, mission.suit_energy) and projection.research_gained == 0.0, "Sheltered projection preserves suit charge and does not invent exterior work")
	# A high-dust, clear-sky two-hour window can make cleaning worthwhile.
	mission.time = 5.0
	mission.energy = 6.0
	mission.peak_tau = 0.0
	mission.dust = 0.8
	mission.inspection = 1.0
	var clear := Adviser.analyze(mission, 2.0)
	check(clear.recommendation.cleaning == "on" and clear.recommendation.cleaning_energy_difference_kwh > 0, "Cleaner advice responds to a clear-sky dusty-panel recovery window")
	mission.energy = Mission.CAPACITY
	mission.dust = 0.0
	var full := Adviser.analyze(mission, 0.25)
	check(full.options[0].habitat_kwh <= Mission.CAPACITY and full.options[2].habitat_kwh <= Mission.CAPACITY, "Forecast respects battery saturation")
	mission.time = 4.0
	mission.event_start = 4.0
	mission.event_end = 7.0
	mission.shelter = false
	var exposed := Adviser.analyze(mission, 0.25)
	check("refuge" in exposed.safety_note and "Particle event active" in exposed.safety_note, "Particle warning is independent of battery preference")
	mission.time = 0.0
	mission.suit_energy = 0.01
	var low_suit := Adviser.analyze(mission)
	check("suit" in low_suit.safety_note and low_suit.options[0].status == "suit-abort", "Suit exhaustion is predicted and cannot be solved by habitat conservation")
	check(low_suit.options[0].elapsed_hours < low_suit.horizon_hours and low_suit.recommendation.cleaning == "not_comparable", "Early abort duration is exposed and not ranked against full runs")
	mission.shelter = true
	mission.time = 6.0
	mission.peak_tau = 4.0
	mission.energy = 0.01
	var empty := Adviser.analyze(mission)
	check("None of these" in empty.summary and empty.options[0].status == "power-abort", "All-failing plans are reported rather than dressed up as an optimal policy")
	mission.energy = 8.0
	mission.time = 11.9
	var near_end := Adviser.analyze(mission, 2.0)
	check(is_equal_approx(near_end.horizon_hours, 0.1) and near_end.options[0].elapsed_hours <= 0.100001, "Preview stops at mission end rather than inventing post-mission energy")
	mission.status = "success"
	var finished := Adviser.analyze(mission)
	check(not finished.active and finished.options.is_empty(), "Ended mission cannot be projected as a fresh run")
	mission.status = "running"
	mission.time = 0.0
	check(Adviser.analyze(mission, INF).horizon_hours == 1.0 and Adviser.analyze(mission, 100).horizon_hours == 2.0, "Preview workload is bounded for invalid or oversized horizons")
	compare_real_trajectories()
	var start := Time.get_ticks_usec()
	for index in range(20): Adviser.analyze(mission, 1.0)
	print("ADVISER WARM AVERAGE MICROSECONDS: ", (Time.get_ticks_usec() - start) / 20.0, " (local headless diagnostic, not device performance)")
	print("MISSION ADVISER FAILURES: ", failures)
	quit(1 if failures else 0)
