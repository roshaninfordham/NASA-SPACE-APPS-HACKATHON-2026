extends SceneTree
const Mission = preload("res://scripts/pace_mission.gd")
var assertions := 0
var failures := 0

func check(value: bool, message: String) -> void:
	assertions += 1
	if value: print("PASS: ", message)
	else:
		push_error(message)
		failures += 1

func close(a: float, b: float, tolerance := 0.000001) -> bool:
	return absf(a - b) <= tolerance

func advance_for(model, seconds: float, frame := 0.0) -> void:
	if frame <= 0.0:
		model.advance(seconds)
		return
	var left := seconds
	while left > 0.0:
		var step := minf(left, frame)
		model.advance(step)
		left = maxf(0.0, left - step)

func run_constant(multiplier: float, pace := 1.0, frame := 0.0):
	var model = Mission.new()
	model.set_cleaning_speed(multiplier)
	model.set_pace(pace)
	advance_for(model, 90.0 / pace, frame)
	return model

func _initialize() -> void:
	var prepared = Mission.new()
	var initial: Dictionary = prepared.snapshot()
	check(initial.scenario_id == "window-pace-v4" and initial.status == "running" and not initial.crew_sheltered, "Prepared model is outside and advances only when controller starts calling advance")
	check(initial.sim_elapsed_seconds == 0.0 and initial.cleaned_work == 0.0 and initial.fatigue == 0.0 and initial.dose_ugy == 0.0, "Reading preflight snapshot does not move the clock, brush, fatigue or dose")
	check(close(initial.battery_kwh, 0.5) and close(initial.solar_power_kw, 2.0) and close(initial.net_power_kw, 1.0), "Authored array and battery start with dimensioned values")
	check(close(initial.sim_remaining_seconds, 1800.0) and close(initial.remaining_seconds, 90.0) and close(initial.radiation_rate_ugy_per_day, 210.0), "Mission clock and historical starting radiation rate use explicit units")
	check(prepared.set_cleaning_speed(1.75) and close(prepared.snapshot().selected_multiplier, 1.75), "Starting pace can be selected before any time advances")
	check(prepared.snapshot().sim_elapsed_seconds == 0.0 and prepared.snapshot().fatigue == 0.0 and prepared.snapshot().battery_kwh == 0.5, "Preflight commands do not simulate work or charging")
	check(not initial.has("projected_battery_at_warning_kwh") and not initial.has("walking_speed_mps") and not initial.has("recall_entry_sim_seconds"), "New workflow has no recall, walking or reserve-forecast outcome model")

	# Independent closed forms: integrate .125*u*(1-F) through F=.9 and
	# E=1+.025*integral(work dt) for minutes0..30 under these defaults.
	var examples := [
		[0.25, 0.9375, 1.3515625, 0.0, "lose"],
		[0.5, 1.875, 1.703125, 0.0, "pass"],
		[0.75, 2.8125, 2.0546875, 0.0, "pass"],
		[1.0, 3.75, 2.40625, 0.0, "win"],
		[1.25, 3.28125, 2.40625, 0.6, "win"],
		[1.5, 2.4609375, 2.27880859375, 0.9, "pass"],
		[1.75, 2.1328125, 2.1689453125, 0.9, "pass"],
	]
	for row: Array in examples:
		var model = run_constant(row[0])
		var state: Dictionary = model.result()
		var label := "u=" + str(row[0])
		check(state.status == row[4] and close(state.cleaned_work, row[1]), "Independent constant-pace cleaning and result: " + label)
		check(close(state.battery_kwh, row[2]) and close(state.fatigue, row[3]), "Independent cubic energy and fatigue bound: " + label)
		check(close(state.sim_elapsed_seconds, 1800.0) and close(state.elapsed_seconds, 90.0) and state.crew_sheltered and state.phase == "sheltered", "Every pace automatically enters shelter at the same fixed time: " + label)
		check(close(state.dose_ugy, 10.9375) and close(state.radiation_rate_ugy_per_day, 840.0) and not state.dose_bonus_awarded, "Equal outside time gives equal final ramp dose with no bonus: " + label)
		check(close(state.base_cleaning_rate_sections_per_minute * state.fatigue_weighted_work_seconds / 60.0, state.cleaned_work), "Weighted-time equation reproduces actual work: " + label)
		check(close(state.battery_kwh, state.initial_battery_kwh + state.solar_energy_generated_kwh - state.habitat_energy_used_kwh - state.curtailed_energy_kwh + state.unserved_energy_kwh), "Energy ledger closes independently: " + label)
		check(not state.cleaning and state.cleaning_rate_sections_per_minute == 0.0 and state.effective_rate_sections_per_minute > 0.0, "Terminal activity and remaining capability are distinct: " + label)
		check(state.history.size() == 31 and state.pace_segments.size() == 1 and not state.pace_segments_truncated, "Bounded actual history and one constant command period are retained: " + label)
		var end: Dictionary = model.snapshot()
		check(not model.set_cleaning_speed(0.5) and not model.set_pace(2.0), "Finished round rejects commands: " + label)
		model.advance(1000000.0)
		check(model.snapshot() == end, "Finished round cannot accrue extra dose or energy: " + label)
		for pace in [0.5, 1.0, 2.0]:
			var partitioned = run_constant(row[0], pace, 0.037)
			var compared: Dictionary = partitioned.snapshot()
			check(compared.status == row[4] and close(compared.cleaned_work, row[1]) and close(compared.battery_kwh, row[2]), "Pace and frame partition preserve physical result: " + label + ", clock=" + str(pace))
			check(close(compared.elapsed_seconds, 90.0 / pace) and close(compared.dose_ugy, 10.9375) and close(compared.fatigue, row[3]), "Accessibility pacing changes only real duration: " + label + ", clock=" + str(pace))

	# A shorter real-time round is not a shorter Mars exposure or more powerful brush.
	var endpoint = Mission.new()
	endpoint.advance(89.999)
	check(endpoint.snapshot().status == "running" and not endpoint.snapshot().crew_sheltered and endpoint.snapshot().sim_remaining_seconds > 0.0, "Default round remains active just before ninety play seconds")
	endpoint.advance(0.001)
	check(endpoint.snapshot().status == "win" and endpoint.snapshot().crew_sheltered and close(endpoint.snapshot().elapsed_seconds, 90.0) and close(endpoint.snapshot().sim_elapsed_seconds, 1800.0), "Default round ends at ninety active play seconds, not thirty real minutes")
	var previous_clock = Mission.new({"time_scale": 6.0})
	var compressed_clock = Mission.new()
	var compression_plan := [[1.75, 4.0], [0.5, 8.0], [1.25, 5.0], [0.75, 3.0], [1.0, 10.0]]
	for command: Array in compression_plan:
		previous_clock.set_cleaning_speed(command[0])
		compressed_clock.set_cleaning_speed(command[0])
		previous_clock.advance(command[1] * 60.0 / 6.0)
		compressed_clock.advance(command[1] * 60.0 / 20.0)
		var old_state: Dictionary = previous_clock.snapshot()
		var new_state: Dictionary = compressed_clock.snapshot()
		for key in ["sim_elapsed_seconds", "cleaned_work", "fatigue", "battery_kwh", "dose_ugy", "solar_energy_generated_kwh", "habitat_energy_used_kwh", "cleaning_active_sim_seconds", "fatigue_weighted_work_seconds"]:
			check(close(old_state[key], new_state[key]), "Five-minute and ninety-second clocks preserve each physical history boundary: " + key)
	check(previous_clock.snapshot().status == compressed_clock.snapshot().status and close(previous_clock.snapshot().elapsed_seconds, 300.0) and close(compressed_clock.snapshot().elapsed_seconds, 90.0), "Clock compression preserves the result while reducing active play time")

	var ramp = Mission.new()
	ramp.advance(45.0)
	var midpoint: Dictionary = ramp.snapshot()
	check(close(midpoint.radiation_rate_ugy_per_day, 525.0) and close(midpoint.storm_progress, 0.5) and close(midpoint.storm_distance_normalized, 0.5), "Storm indicator and authored instantaneous dose rate follow elapsed mission time")
	check(close(midpoint.dose_ugy, 3.828125) and close(midpoint.dose_rate_ugy_per_hour, 21.875), "Dose is the time integral of the ramp, not final rate times all past time")
	var no_ramp = Mission.new({"radiation_ramp_multiplier": 0.0})
	no_ramp.advance(90.0)
	check(close(no_ramp.snapshot().dose_ugy, 4.375), "Removing authored ramp recovers the historical constant-rate integral")
	var no_dose = Mission.new({"background_dose_ugy_per_day": 0.0})
	no_dose.advance(90.0)
	check(no_dose.snapshot().dose_ugy == 0.0 and no_dose.snapshot().radiation_rate_ugy_per_day == 0.0, "Zero reference rate cannot invent dose")

	var recovery = Mission.new()
	recovery.set_cleaning_speed(1.5)
	recovery.advance(15.0)
	check(close(recovery.snapshot().fatigue, 0.2) and close(recovery.snapshot().cleaned_work, 0.84375), "Five minutes at1.5 builds the authored fatigue and exact work")
	var command_before: Dictionary = recovery.snapshot()
	recovery.set_cleaning_speed(0.5)
	check(recovery.snapshot().fatigue == command_before.fatigue and recovery.snapshot().cleaned_work == command_before.cleaned_work and recovery.snapshot().battery_kwh == command_before.battery_kwh, "A command changes desired pace without retroactive physical effects")
	recovery.advance(10.0)
	check(close(recovery.snapshot().fatigue, 0.0) and close(recovery.snapshot().cleaned_work, 1.03125), "Recovery reaches zero exactly without negative fatigue")
	recovery.advance(3.0)
	check(close(recovery.snapshot().fatigue, 0.0) and close(recovery.snapshot().cleaned_work, 1.09375), "Pace below one continues working at the fatigue floor")
	var fatigue_cap = Mission.new()
	fatigue_cap.set_cleaning_speed(1.75)
	fatigue_cap.advance(45.0)
	check(close(fatigue_cap.snapshot().fatigue, 0.9) and close(fatigue_cap.snapshot().cleaned_work, 1.8046875), "Fastest pace reaches the authored fatigue ceiling at fifteen minutes")
	fatigue_cap.advance(3.0)
	check(close(fatigue_cap.snapshot().fatigue, 0.9) and close(fatigue_cap.snapshot().cleaning_rate_sections_per_minute, 0.021875), "At fatigue cap the effective rate stays positive and bounded")

	var full = Mission.new()
	full.advance(75.0)
	full.set_cleaning_speed(1.75)
	# Solve .21875*(t-.03*t²)=.875 sections; the smaller root is cap time.
	var extra_minutes := (1.0 - sqrt(0.52)) / 0.06
	full.advance(extra_minutes * 3.0)
	var at_cap: Dictionary = full.snapshot()
	check(close(at_cap.cleaned_work, 4.0) and not at_cap.cleaning and not at_cap.crew_sheltered, "Adaptive cleaning can finish the array before automatic entry")
	check(close(at_cap.fatigue, 0.06 * extra_minutes) and close(at_cap.cleaning_active_sim_seconds, 1500.0 + extra_minutes * 60.0), "Work-cap event ends active time and fatigue at the exact quadratic root")
	check(close(at_cap.base_cleaning_rate_sections_per_minute * at_cap.fatigue_weighted_work_seconds / 60.0, 4.0), "Weighted-work integral truncates at full cleaning")
	full.advance(1000.0)
	var completed: Dictionary = full.snapshot()
	check(completed.status == "win" and close(completed.cleaned_work, 4.0) and close(completed.fatigue, at_cap.fatigue), "After completion fatigue and work freeze through the remaining mission")
	check(completed.battery_kwh > at_cap.battery_kwh and close(completed.dose_ugy, 10.9375) and close(completed.cleaning_active_sim_seconds, at_cap.cleaning_active_sim_seconds), "Full panel keeps generating while outside dose continues to fixed end")
	var capped_frames = Mission.new()
	advance_for(capped_frames, 75.0, 0.071)
	capped_frames.set_cleaning_speed(1.75)
	advance_for(capped_frames, 15.0, 0.029)
	check(close(capped_frames.snapshot().battery_kwh, completed.battery_kwh) and close(capped_frames.snapshot().fatigue, completed.fatigue) and close(capped_frames.snapshot().cleaned_work, 4.0), "Cap crossing preserves cubic-energy integration across different frame partitions")

	var mixed_one = Mission.new()
	var mixed_many = Mission.new()
	var commands := [[1.5, 12.6], [0.5, 9.0], [1.25, 15.9], [0.75, 7.5], [1.75, 21.0], [0.25, 4.5], [1.0, 19.5]]
	for command: Array in commands:
		mixed_one.set_cleaning_speed(command[0])
		mixed_many.set_cleaning_speed(command[0])
		mixed_one.advance(command[1])
		advance_for(mixed_many, command[1], 0.043)
	var one: Dictionary = mixed_one.snapshot()
	var many: Dictionary = mixed_many.snapshot()
	check(one.status == many.status and close(one.cleaned_work, many.cleaned_work) and close(one.fatigue, many.fatigue), "Mixed commands and recovery preserve work across frame partitions")
	check(close(one.battery_kwh, many.battery_kwh) and close(one.dose_ugy, many.dose_ugy) and close(one.solar_energy_generated_kwh, many.solar_energy_generated_kwh), "Mixed quadratic-work intervals preserve cubic energy and analytic dose")
	var segment_work := 0.0
	for segment: Dictionary in one.pace_segments: segment_work += segment.cleaned_work
	check(close(segment_work, one.cleaned_work) and one.pace_segments.size() == commands.size(), "Chronological command periods reproduce completed work")
	var clock = Mission.new()
	clock.advance(12.0)
	clock.set_pace(2.0)
	clock.advance(6.0)
	check(close(clock.snapshot().sim_elapsed_seconds, 480.0) and close(clock.snapshot().elapsed_seconds, 18.0) and close(clock.snapshot().cleaned_work, 1.0), "Accessibility clock changes preserve elapsed history and actual work")

	var tiny_one = Mission.new()
	var tiny_many = Mission.new()
	tiny_one.advance(0.01)
	for index in range(10000): tiny_many.advance(0.000001)
	check(close(tiny_many.snapshot().cleaned_work, 0.0004166666666667, 0.000000000001) and close(tiny_many.snapshot().cleaned_work, tiny_one.snapshot().cleaned_work, 0.000000000001), "Microsecond frames do not erase small cleaning increments")
	var tiny_fast_one = Mission.new()
	var tiny_fast_many = Mission.new()
	tiny_fast_one.set_cleaning_speed(1.75)
	tiny_fast_many.set_cleaning_speed(1.75)
	tiny_fast_one.advance(0.01)
	for index in range(10000): tiny_fast_many.advance(0.000001)
	check(close(tiny_fast_many.snapshot().fatigue, tiny_fast_one.snapshot().fatigue, 0.000000000001) and close(tiny_fast_many.snapshot().battery_kwh, tiny_fast_one.snapshot().battery_kwh, 0.000000000001), "Tiny fatigue and cubic-energy increments remain partition invariant")

	var empty_options := {"minimum_solar_transmission": 0.0, "habitat_load_kw": 0.7, "initial_battery_kwh": 0.0}
	var empty = Mission.new(empty_options)
	var empty_frames = Mission.new(empty_options)
	empty.advance(24.0)
	advance_for(empty_frames, 24.0, 0.071)
	check(close(empty.snapshot().battery_kwh, 0.0563333333333) and close(empty.snapshot().unserved_energy_kwh, 0.0163333333333), "Empty battery and net-power crossing recover the independent linear special case")
	check(close(empty.snapshot().battery_kwh, empty_frames.snapshot().battery_kwh), "Empty-battery clipping is invariant to frame partition")
	var capacity = Mission.new({"minimum_solar_transmission": 1.0, "initial_battery_kwh": 5.9})
	capacity.advance(30.0)
	check(close(capacity.snapshot().battery_kwh, 6.0) and close(capacity.snapshot().curtailed_energy_kwh, 1.0666666667), "Battery capacity reports excess generation without creating stored energy")
	var zero_rate = Mission.new({"base_cleaning_rate_sections_per_minute": 0.0})
	zero_rate.advance(90.0)
	check(zero_rate.snapshot().cleaned_work == 0.0 and zero_rate.snapshot().status == "lose" and close(zero_rate.snapshot().battery_kwh, 1.0), "Zero work rate still integrates dirty-panel energy and completes the round")
	var zero_fatigue = Mission.new({"fatigue_max": 0.0})
	zero_fatigue.set_cleaning_speed(1.75)
	zero_fatigue.advance(90.0)
	check(zero_fatigue.snapshot().fatigue == 0.0 and close(zero_fatigue.snapshot().cleaned_work, 4.0), "Zero fatigue cap is a valid no-fatigue scenario without boundary loops")

	for threshold in [[0.4, "pass"], [0.8, "win"], [0.3999, "lose"], [0.7999, "pass"]]:
		var at_threshold = Mission.new({"base_cleaning_rate_sections_per_minute": float(threshold[0]) * 4.0 / 30.0})
		at_threshold.advance(90.0)
		check(at_threshold.snapshot().status == threshold[1], "Clean-fraction outcome boundary: " + str(threshold[0]))
	var invalid = Mission.new()
	var pristine: Dictionary = invalid.snapshot()
	for value in [0.0, -1.0, 0.3, 1.1, 2.0, NAN, INF]: check(not invalid.set_cleaning_speed(value), "Invalid physical pace is rejected: " + str(value))
	for value in [0.0, -1.0, 1.25, NAN, INF]: check(not invalid.set_pace(value), "Invalid accessibility pace is rejected: " + str(value))
	for value in [0.0, -1.0, NAN, INF]: invalid.advance(value)
	check(invalid.snapshot() == pristine, "Paused/invalid deltas and rejected commands leave all physics unchanged")
	for options in [{"warning_seconds": 0.0}, {"max_sections": 0}, {"max_sections": 4.0}, {"fatigue_max": 1.0}, {"initial_fatigue": -0.1}, {"fatigue_growth_per_minute": -1.0}, {"fatigue_recovery_per_minute": NAN}, {"minimum_solar_transmission": 1.1}, {"initial_battery_kwh": 7.0}, {"battery_capacity_kwh": 0.0}, {"pass_clean_fraction": 0.9}, {"dose_reference_day_seconds": 88775.0}, {"radiation_ramp_multiplier": -1.0}, {"recall_entry_sim_seconds": 60.0}]:
		check(not invalid.reset(options) and invalid.snapshot() == pristine, "Invalid scenario cannot mutate an existing run: " + str(options.keys()))
	check(Mission.new({"walking_speed_mps": 1.0}).snapshot() == pristine, "Invalid constructor falls back to complete current defaults")
	var bounded = Mission.new()
	for index in range(200):
		bounded.set_cleaning_speed(1.75 if index % 2 == 0 else 0.25)
		bounded.advance(0.1)
	check(bounded.snapshot().events.size() == 128 and bounded.snapshot().pace_segments.size() == 128 and bounded.snapshot().pace_segments_truncated, "Unbounded button changes cannot grow event or period history without limit")
	check(close(bounded.snapshot().base_cleaning_rate_sections_per_minute * bounded.snapshot().fatigue_weighted_work_seconds / 60.0, bounded.snapshot().cleaned_work), "Exact aggregate work survives truncated command-history display")
	bounded.advance(1000000000000.0)
	check(close(bounded.snapshot().sim_elapsed_seconds, 1800.0) and bounded.snapshot().history.size() == 31 and bounded.snapshot().crew_sheltered, "Huge delta is bounded by fixed automatic shelter time")
	var detached: Dictionary = mixed_one.result()
	detached.assumptions.fatigue_max = 0.0
	detached.history[0].dose_ugy = -1.0
	detached.pace_segments[0].cleaned_work = -1.0
	detached.events.clear()
	check(mixed_one.snapshot().fatigue_max == 0.9 and mixed_one.snapshot().history[0].dose_ugy == 0.0 and mixed_one.snapshot().pace_segments[0].cleaned_work >= 0.0 and not mixed_one.snapshot().events.is_empty(), "Returned settings, histories and periods cannot mutate authoritative state")
	var defaults: Dictionary = Mission.default_settings()
	defaults.warning_seconds = 1.0
	check(Mission.new().snapshot().warning_seconds == 1800.0, "Default settings are detached between callers")
	print("Pace mission: ", assertions, " assertions, ", failures, " failures")
	quit(1 if failures else 0)
