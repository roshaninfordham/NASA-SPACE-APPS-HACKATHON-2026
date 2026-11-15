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

func close(a: float, b: float, tolerance := 0.000001) -> bool:
	return absf(a - b) <= tolerance

func advance_for(model, seconds: float, frame_seconds := 0.0) -> void:
	if frame_seconds <= 0.0:
		model.advance(seconds)
		return
	var left := seconds
	while left > 0.0:
		var amount := minf(left, frame_seconds)
		model.advance(amount)
		left = maxf(0.0, left - amount)

func perform_plan(work: float, multiplier := 1.0, pace := 1.0, frame_seconds := 0.0):
	var model = Mission.new()
	model.set_cleaning_speed(multiplier)
	model.set_pace(pace)
	advance_for(model, work * 480.0 / multiplier / (6.0 * pace), frame_seconds)
	model.request_recall()
	advance_for(model, 60.0 / (6.0 * pace), frame_seconds)
	return model

func _initialize() -> void:
	var fresh = Mission.new()
	var initial: Dictionary = fresh.snapshot()
	check(initial.scenario_id == "window-energy-v3" and initial.phase == "outside" and initial.cleaning, "Astronaut begins cleaning automatically outside the observation window")
	check(close(initial.remaining_seconds, 300.0) and close(initial.entry_seconds_remaining, 10.0), "Standard five-minute mission includes an explicit ten-second play-time entry")
	check(not initial.has("walking_speed_mps") and not initial.has("distance_m") and not initial.has("walk_sim_seconds"), "Stationary cleaning has no authoritative walking quantities")
	check(close(initial.cleaning_rate_sections_per_minute, 0.125) and close(initial.section_seconds_remaining, 80.0), "Base rate is one section per eight simulated minutes")
	check(close(initial.required_reserve_kwh, 2.0) and close(initial.battery_kwh, 0.5) and close(initial.projected_battery_at_warning_kwh, 1.0), "Two-hour storm target and actual versus forecast battery are distinct")
	check(close(initial.max_additional_work, 3.625) and initial.max_additional_sections == 3, "Available work reserves explicit entry time")
	check(close(initial.solar_power_kw, 2.0) and close(initial.net_power_kw, 1.0) and close(initial.dose_rate_ugy_per_hour, 8.75), "Solar power, net charging and historical dose conversion use separate units")
	check(initial.alert_count == 0 and initial.dose_ugy == 0.0 and not initial.has("dose_msv"), "Automatic start creates neither an alert nor personal sievert estimate")

	for multiplier in [1.0, 1.25]:
		for count in range(5):
			var model = perform_plan(count, multiplier)
			var state: Dictionary = model.result()
			var planned: float = count * 480.0 / float(multiplier) + 60.0
			var duration := minf(planned, 1800.0)
			var actual_work := minf(float(count), duration * multiplier / 480.0)
			var clean_seconds: float = minf(count * 480.0 / multiplier, duration)
			var energy: float = 0.5 + (clean_seconds + 0.75 * multiplier / 480.0 * clean_seconds * clean_seconds) / 3600.0
			energy += maxf(0.0, duration - clean_seconds) * (1.0 + 1.5 * actual_work) / 3600.0
			var forecast := energy + (1800.0 - duration) * (1.0 + 1.5 * actual_work) / 3600.0
			var expected := "late" if planned > 1800.0 else ("success" if count >= 2 else "power-shortfall")
			var name := str(count) + " sections at " + str(multiplier)
			check(state.status == expected and close(state.sim_elapsed_seconds, duration), "Independent outcome and duration: " + name)
			check(close(state.elapsed_seconds, duration / 6.0) and close(state.dose_ugy, 210.0 * duration / 86400.0), "Independent play time and absorbed dose: " + name)
			check(close(state.cleaned_work, actual_work) and close(state.battery_kwh, energy) and close(state.projected_battery_at_warning_kwh, forecast), "Independent continuous-power integration and warning forecast: " + name)
			check(state.crew_sheltered == (planned <= 1800.0) and state.phase != "returning", "Entry outcome has no walking phase: " + name)
			var comparison: Dictionary = model.plan_for_sections(count, multiplier)
			check(comparison.valid and comparison.status == state.status and close(comparison.cleaned_work, actual_work) and close(comparison.dose_ugy, state.dose_ugy) and close(comparison.battery_kwh, energy) and close(comparison.projected_battery_at_warning_kwh, forecast), "Analytical plan agrees with actual capped work, dose, battery and forecast: " + name)
			check(close(comparison.planned_cleaned_work, count) and close(comparison.outside_sim_seconds, planned), "Plan distinguishes requested work and duration from deadline-limited actuals: " + name)
			var before: Dictionary = model.snapshot()
			check(not model.start_cleaning() and not model.stop_cleaning() and not model.request_recall() and not model.set_cleaning_speed(1.25) and not model.set_pace(0.5), "Finished mission rejects command mutations: " + name)
			model.advance(999999.0)
			check(model.snapshot() == before, "Finished mission cannot accrue more work or dose: " + name)

	var partial = Mission.new()
	partial.advance(40.0)
	var halfway: Dictionary = partial.snapshot()
	check(halfway.sections_cleaned == 0 and close(halfway.section_progress, 0.5) and close(halfway.cleaned_work, 0.5), "Half a section remains visible as continuous progress")
	check(close(halfway.solar_power_kw, 2.75) and close(halfway.clean_fraction, 0.125) and close(halfway.dust_fraction, 0.875) and close(halfway.battery_kwh, 0.5916666667), "Partial clearing raises solar power continuously and integrates stored energy")
	check(partial.stop_cleaning() and not partial.stop_cleaning(), "Hold alert is accepted once")
	partial.advance(10.0)
	check(close(partial.snapshot().cleaned_work, 0.5) and close(partial.snapshot().cleaning_active_sim_seconds, 240.0) and close(partial.snapshot().waiting_sim_seconds, 60.0), "Holding pauses work while outside time and exposure continue")
	check(close(partial.snapshot().projected_battery_at_warning_kwh, halfway.projected_battery_at_warning_kwh) and partial.snapshot().battery_kwh > halfway.battery_kwh, "Holding preserves no-more-cleaning forecast while actual battery continues charging")
	check(partial.start_cleaning() and not partial.start_cleaning(), "Resume alert restarts work once without resetting progress")
	partial.advance(20.0)
	check(partial.request_return() and not partial.request_recall(), "Legacy request_return aliases one recall command")
	var recalled: Dictionary = partial.snapshot()
	check(recalled.phase == "airlock" and not recalled.cleaning and close(recalled.cleaned_work, 0.75), "Recall preserves partial clearing and immediately enters the abstract entry phase")
	check(not partial.set_cleaning_speed(1.25) and not partial.start_cleaning(), "Entry cannot restart cleaning or change its speed")
	partial.advance(5.0)
	check(close(partial.snapshot().entry_progress, 0.5) and close(partial.snapshot().return_progress, 0.5) and not partial.snapshot().crew_sheltered, "Mid-entry remains outside the completed-shelter condition")
	partial.advance(5.0)
	check(partial.snapshot().status == "power-shortfall" and close(partial.snapshot().cleaned_work, 0.75), "Partial credit survives arrival even when the target was missed")

	var mixed = Mission.new()
	mixed.advance(64.0)
	var before_speed: Dictionary = mixed.snapshot()
	check(mixed.set_cleaning_speed(1.25) and mixed.set_cleaning_speed(1.25), "Supported speed alert is bounded and same-speed command is idempotent")
	check(close(mixed.snapshot().cleaned_work, before_speed.cleaned_work) and close(mixed.snapshot().dose_ugy, before_speed.dose_ugy) and mixed.snapshot().alert_count == 1, "A speed change never creates work, time or extra repeated alerts")
	mixed.advance(64.0)
	mixed.request_recall()
	mixed.advance(10.0)
	var mixed_result: Dictionary = mixed.result()
	check(close(mixed_result.cleaned_work, 1.8) and close(mixed_result.sim_elapsed_seconds, 828.0) and close(mixed_result.dose_ugy, 2.0125), "Independent mixed-rate trajectory integrates0.8 plus1.0 sections")
	check(close(mixed_result.battery_kwh, 1.047) and close(mixed_result.projected_battery_at_warning_kwh, 2.046), "Mixed-rate history integrates actual battery and separate warning forecast")
	check(close(mixed_result.cleaning_active_sim_seconds, 768.0) and mixed_result.cleaning_segments.size() == 2, "Active cleaning duration and bounded rate totals are retained")
	var summed_work := 0.0
	var summed_seconds := 0.0
	for segment: Dictionary in mixed_result.cleaning_segments:
		summed_work += segment.rate_sections_per_minute * segment.active_sim_seconds / 60.0
		summed_seconds += segment.active_sim_seconds
		check(close(segment.cleaned_work, segment.rate_sections_per_minute * segment.active_sim_seconds / 60.0), "Each actual rate bucket has consistent work units")
	check(close(summed_work, mixed_result.cleaned_work) and close(summed_seconds, mixed_result.cleaning_active_sim_seconds), "Debrief sums actual rate periods instead of applying final speed retroactively")

	var exact = Mission.new()
	exact.advance(290.0)
	check(close(exact.snapshot().recall_slack_seconds, 0.0) and exact.snapshot().can_recall_on_time, "Latest recall leaves exactly the configured entry time")
	exact.request_recall()
	exact.advance(10.0)
	check(exact.snapshot().status == "success" and close(exact.snapshot().sim_elapsed_seconds, 1800.0), "Entry exactly at inclusive deadline succeeds")
	var late = Mission.new()
	late.advance(290.001)
	late.request_recall()
	late.advance(10.0)
	check(late.snapshot().status == "late" and not late.snapshot().crew_sheltered and late.snapshot().entry_progress < 1.0, "Recall one millisecond late cannot round into completed shelter")
	var instant = Mission.new({"recall_entry_sim_seconds": 0.0})
	instant.advance(160.0)
	check(instant.request_recall() and instant.snapshot().status == "success" and close(instant.snapshot().sim_elapsed_seconds, 960.0) and close(instant.snapshot().projected_battery_at_warning_kwh, 2.1), "Optional instant recall has no hidden duration and panels still contribute to the warning forecast")
	var instant_early = Mission.new({"recall_entry_sim_seconds": 0.0})
	instant_early.request_recall()
	check(instant_early.snapshot().status == "power-shortfall" and instant_early.snapshot().dose_ugy == 0.0, "Immediate first-frame recall cannot invent dose or useful work")
	var instant_boundary = Mission.new({"recall_entry_sim_seconds": 0.0})
	var instant_boundary_plan: Dictionary = instant_boundary.plan_for_work(3.75)
	check(not instant_boundary_plan.on_time and instant_boundary_plan.status == "late", "Instant recall planned exactly at the expired deadline is correctly classified late")
	var instant_minimum: Dictionary = instant_boundary.minimum_reserve_plan()
	check(instant_minimum.valid and instant_minimum.status == "success" and instant_minimum.outside_sim_seconds < 1800.0, "Strict instant-entry boundary still permits the earlier minimum-reserve plan")
	instant_boundary.advance(300.0)
	check(not instant_boundary.request_recall() and instant_boundary.snapshot().status == "late" and not instant_boundary.snapshot().can_recall_on_time, "Expired instant-entry rounds cannot be revived by a late recall command")
	var instant_before = Mission.new({"recall_entry_sim_seconds": 0.0})
	instant_before.advance((1800.0 - 0.000001) / 6.0)
	check(instant_before.request_recall() and instant_before.snapshot().status == "success", "Instant recall strictly before expiry remains executable")
	var unreachable = Mission.new({"recall_entry_sim_seconds": 1900.0})
	check(not unreachable.snapshot().can_recall_on_time and unreachable.snapshot().max_additional_work == 0.0 and not unreachable.plan_for_work(0).on_time, "An entry longer than the warning is recognized as infeasible")
	unreachable.request_recall()
	unreachable.advance(1000000.0)
	check(unreachable.snapshot().status == "late" and not unreachable.snapshot().crew_sheltered and close(unreachable.snapshot().dose_ugy, 4.375), "Impossible entry is capped at the deadline without invented protection")

	for pace in [0.5, 1.0, 2.0]:
		var one = perform_plan(2.4, 1.25, pace)
		var many = perform_plan(2.4, 1.25, pace, 0.037)
		var a: Dictionary = one.snapshot()
		var b: Dictionary = many.snapshot()
		check(a.status == "success" and b.status == a.status and close(a.sim_elapsed_seconds, 981.6) and close(b.sim_elapsed_seconds, a.sim_elapsed_seconds), "Physical trajectory is invariant to clock pace and frame partition: " + str(pace))
		check(close(a.elapsed_seconds, 981.6 / 6.0 / pace) and close(b.elapsed_seconds, a.elapsed_seconds) and close(a.cleaned_work, b.cleaned_work), "Accessibility pace changes only real duration: " + str(pace))
		check(close(a.dose_ugy, b.dose_ugy) and close(a.battery_kwh, b.battery_kwh) and close(a.projected_battery_at_warning_kwh, b.projected_battery_at_warning_kwh), "Frame partition preserves dose, stored energy and forecast: " + str(pace))
	var changing_pace = Mission.new()
	changing_pace.advance(40.0)
	changing_pace.set_pace(2.0)
	changing_pace.advance(20.0)
	check(close(changing_pace.snapshot().cleaned_work, 1.0) and close(changing_pace.snapshot().elapsed_seconds, 60.0) and close(changing_pace.snapshot().sim_elapsed_seconds, 480.0), "Mid-round clock change does not rewrite elapsed real or simulated time")
	var tiny_one = Mission.new()
	var tiny_many = Mission.new()
	tiny_one.advance(0.01)
	for index in range(10000): tiny_many.advance(0.000001)
	check(close(tiny_many.snapshot().cleaned_work, 0.000125, 0.000000000001) and close(tiny_many.snapshot().cleaned_work, tiny_one.snapshot().cleaned_work, 0.000000000001), "Microsecond time partitions retain continuous cleaning work near zero")
	check(close(tiny_many.snapshot().battery_kwh, tiny_one.snapshot().battery_kwh, 0.000000000001) and close(tiny_many.snapshot().dose_ugy, tiny_one.snapshot().dose_ugy, 0.000000000001), "Microsecond partitions preserve energy and absorbed dose")
	var tiny_after_boundary = Mission.new()
	tiny_after_boundary.advance(80.0)
	for index in range(10000): tiny_after_boundary.advance(0.000001)
	check(close(tiny_after_boundary.snapshot().cleaned_work, 1.000125, 0.00000000001), "Tiny increments after a completed section are not repeatedly rounded away")
	var complete = Mission.new()
	complete.set_cleaning_speed(1.25)
	complete.advance(270.0)
	check(close(complete.snapshot().cleaned_work, 4.0) and not complete.snapshot().cleaning and close(complete.snapshot().cleaning_active_sim_seconds, 1536.0), "Complete array caps both visible work and active duration")
	check(close(complete.snapshot().waiting_sim_seconds, 84.0) and close(complete.snapshot().solar_power_kw, 8.0), "Waiting after completion continues generation without duplicate cleaning work")
	complete.request_recall()
	complete.advance(10.0)
	check(complete.snapshot().status == "success" and close(complete.snapshot().cleaning_segments[0].active_sim_seconds, 1536.0), "Entry after completed array does not add work to rate totals")

	var bounded = Mission.new()
	for index in range(200):
		bounded.set_cleaning_speed(1.25 if index % 2 == 0 else 1.0)
		bounded.advance(0.1)
	check(bounded.snapshot().events.size() == 128 and bounded.snapshot().cleaning_segments.size() == 2 and bounded.snapshot().alert_count == 200, "Repeated alerts preserve bounded event and exact rate-summary memory")
	bounded.advance(100000000000000.0)
	check(bounded.snapshot().status == "late" and close(bounded.snapshot().sim_elapsed_seconds, 1800.0) and bounded.snapshot().history.size() == 31, "Huge delta integrates only through deadline with bounded minute history")
	var invalid = Mission.new()
	var pristine: Dictionary = invalid.snapshot()
	for bad in [-1.0, 0.0, 1.01, 2.0, NAN, INF]:
		check(not invalid.set_cleaning_speed(bad), "Unsupported physical cleaning multiplier is rejected: " + str(bad))
	for bad in [-1.0, 0.0, 1.25, NAN, INF]:
		check(not invalid.set_pace(bad), "Unsupported accessibility clock pace is rejected: " + str(bad))
	for bad in [-1.0, 0.0, NAN, INF]: invalid.advance(bad)
	check(invalid.snapshot() == pristine, "Invalid clocks and speed commands leave the whole model unchanged")
	for options in [{"distance_m": 10.0}, {"walking_speed_mps": 1.0}, {"section_work_seconds": 0.0}, {"recall_entry_sim_seconds": -1.0}, {"dust_loss_points_per_sol": 0.28}, {"max_sections": 4.0}, {"background_dose_ugy_per_day": NAN}, {"dose_reference_day_seconds": 88775.0}, {"warning_seconds": true}, {"initial_battery_kwh": 7.0}, {"minimum_solar_transmission": 1.1}, {"battery_capacity_kwh": 0.0}, {"habitat_load_kw": -1.0}, {"storm_duration_hours": -1.0}]:
		check(not invalid.reset(options) and invalid.snapshot() == pristine, "Invalid scenario reset cannot mutate existing run: " + str(options.keys()))
	check(Mission.new({"distance_m": 1.0}).snapshot() == pristine, "Invalid constructor falls back to a complete current scenario")
	check(not invalid.plan_for_work(-1.0).valid and not invalid.plan_for_work(4.1).valid and not invalid.plan_for_work(NAN).valid and not invalid.plan_for_work(2.0, 1.1).valid, "Invalid analytical work and multiplier plans are rejected")
	var target_plan: Dictionary = invalid.plan_for_work(2.0)
	check(target_plan.status == "success" and close(target_plan.outside_sim_seconds, 1020.0) and close(target_plan.battery_kwh, 1.2333333333) and close(target_plan.projected_battery_at_warning_kwh, 2.1), "Two-section recall succeeds using future generation without pretending forecast energy is already stored")
	var threshold := (7.5 - sqrt(16.25)) / 2.0
	var minimum: Dictionary = invalid.minimum_reserve_plan()
	check(minimum.valid and close(minimum.cleaned_work, threshold) and close(minimum.projected_battery_at_warning_kwh, 2.0), "Numerical minimum plan agrees with independent quadratic energy solution")
	var below = perform_plan(threshold - 0.001)
	check(below.snapshot().status == "power-shortfall", "A near-reserve forecast is not rounded into success")
	var crossing_options := {"minimum_solar_transmission": 0.0, "habitat_load_kw": 0.7, "initial_battery_kwh": 0.0}
	var crossing = Mission.new(crossing_options)
	var crossing_frames = Mission.new(crossing_options)
	crossing.advance(80.0)
	advance_for(crossing_frames, 80.0, 0.071)
	var crossed: Dictionary = crossing.snapshot()
	# Solar rises from0 to2kW over480s. Net power crosses zero at168s.
	var expected_charge := 0.5 * (480.0 - 168.0) * 1.3 / 3600.0
	var expected_unserved := 0.5 * 168.0 * 0.7 / 3600.0
	check(close(crossed.battery_kwh, expected_charge) and close(crossed.unserved_energy_kwh, expected_unserved), "Battery empty boundary and net-power sign change preserve later charging")
	check(close(crossed.battery_kwh, crossing_frames.snapshot().battery_kwh) and close(crossed.unserved_energy_kwh, crossing_frames.snapshot().unserved_energy_kwh), "Empty-battery crossing is invariant to frame partitions")
	check(close(crossed.battery_kwh, crossed.initial_battery_kwh + crossed.solar_energy_generated_kwh - crossed.habitat_energy_used_kwh - crossed.curtailed_energy_kwh + crossed.unserved_energy_kwh), "Actual energy ledger conserves energy with explicit unmet load")
	var capacity = Mission.new({"minimum_solar_transmission": 1.0, "initial_battery_kwh": 5.9})
	capacity.advance(100.0)
	var capped: Dictionary = capacity.snapshot()
	check(close(capped.battery_kwh, 6.0) and close(capped.curtailed_energy_kwh, 1.0666666667) and close(capped.projected_battery_at_warning_kwh, 6.0), "Actual and forecast charge respect battery capacity and report discarded surplus")
	check(close(capped.battery_kwh, capped.initial_battery_kwh + capped.solar_energy_generated_kwh - capped.habitat_energy_used_kwh - capped.curtailed_energy_kwh + capped.unserved_energy_kwh), "Capacity clipping retains an independently balanced energy ledger")
	var no_solar = Mission.new({"clear_solar_power_kw": 0.0, "initial_battery_kwh": 0.1})
	no_solar.advance(100.0)
	check(close(no_solar.snapshot().battery_kwh, 0.0) and close(no_solar.snapshot().unserved_energy_kwh, 1.0 / 15.0), "Missing sunlight cannot create negative storage or hide unmet habitat load")
	check(not no_solar.minimum_reserve_plan().valid, "An infeasible reserve is reported rather than inventing a successful plan")
	var future = perform_plan(2.0)
	var at_entry: Dictionary = future.snapshot()
	check(close(at_entry.battery_projection_horizon_seconds, 780.0) and close(at_entry.dose_ugy, 2.4791666667) and at_entry.battery_kwh < at_entry.required_reserve_kwh and at_entry.reserve_met, "Future indoor solar generation supports forecast reserve without extending outside dose")
	future.advance(130.0)
	check(future.snapshot() == at_entry, "Finished round never relabels forecast generation as measured battery or outside dose")
	check(not at_entry.has("power_margin_sols") and not at_entry.has("dust_loss_points_per_sol") and not at_entry.has("spare_power_points"), "Battery model exposes no obsolete percentage-point or sol-margin quantities")
	var detached: Dictionary = mixed.result()
	detached.assumptions.section_work_seconds = 1.0
	detached.cleaning_segments[0].active_sim_seconds = -1.0
	detached.history[0].dose_ugy = -1.0
	detached.events.clear()
	check(mixed.snapshot().section_work_seconds == 480.0 and mixed.snapshot().cleaning_segments[0].active_sim_seconds > 0.0 and mixed.snapshot().history[0].dose_ugy == 0.0 and not mixed.snapshot().events.is_empty(), "Exported config, segments, history and events cannot mutate the model")
	var defaults: Dictionary = Mission.default_settings()
	defaults.section_work_seconds = 1.0
	check(Mission.new().snapshot().section_work_seconds == 480.0, "Default settings are detached between runs")
	check(mixed.result().equations.size() == 4 and not mixed.result().equations.has("return"), "Debrief exposes four cleaning/science equations and no walking equation")
	print("Training mission: ", assertions, " assertions, ", failures, " failures")
	quit(1 if failures else 0)
