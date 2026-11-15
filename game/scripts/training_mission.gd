extends RefCounted
## Stationary cleaning lesson. All times are simulated seconds unless named real.
## Authored solar/battery parameters; historical absorbed dose is not a health model.
const SCENARIO_ID := "window-energy-v3"
const EPSILON := 0.0000001
const HISTORY_INTERVAL_SECONDS := 60.0
const MAX_EVENTS := 128
const CLEANING_MULTIPLIERS := [1.0, 1.25]
const DEFAULTS := {
	"warning_seconds": 1800.0,
	"time_scale": 6.0,
	"section_work_seconds": 480.0,
	"recall_entry_sim_seconds": 60.0,
	"max_sections": 4,
	"clear_solar_power_kw": 8.0,
	"minimum_solar_transmission": 0.25,
	"habitat_load_kw": 1.0,
	"initial_battery_kwh": 0.5,
	"battery_capacity_kwh": 6.0,
	"storm_duration_hours": 2.0,
	"storm_load_kw": 1.0,
	"storm_solar_kw": 0.0,
	"background_dose_ugy_per_day": 210.0,
	"dose_reference_day_seconds": 86400.0,
}
var _settings: Dictionary = DEFAULTS.duplicate(true)
var _sim_elapsed := 0.0
var _real_elapsed := 0.0
var _cleaned_work := 0.0
var _cleaning_active_seconds := 0.0
var _entry_elapsed := 0.0
var _recall_time := -1.0
var _arrival_time := -1.0
var _cleaning := true
var _phase := "outside"
var _status := "running"
var _pace := 1.0
var _cleaning_multiplier := 1.0
var _alert_count := 0
var _battery_kwh := 0.5
var _solar_generated_kwh := 0.0
var _habitat_used_kwh := 0.0
var _curtailed_kwh := 0.0
var _unserved_kwh := 0.0
var _events: Array[Dictionary] = []
var _history: Array[Dictionary] = []
var _cleaning_segments: Array[Dictionary] = []
var _next_history_time := HISTORY_INTERVAL_SECONDS

func _init(options: Dictionary = {}) -> void:
	if not reset(options): reset()

static func default_settings() -> Dictionary:
	return DEFAULTS.duplicate(true)

func reset(options: Dictionary = {}) -> bool:
	var candidate := DEFAULTS.duplicate(true)
	for key in options:
		if not candidate.has(key): return false
		candidate[key] = options[key]
	if not _valid_settings(candidate): return false
	_settings = candidate
	_sim_elapsed = 0.0
	_real_elapsed = 0.0
	_cleaned_work = 0.0
	_cleaning_active_seconds = 0.0
	_entry_elapsed = 0.0
	_recall_time = -1.0
	_arrival_time = -1.0
	_cleaning = true
	_phase = "outside"
	_status = "running"
	_pace = 1.0
	_cleaning_multiplier = 1.0
	_alert_count = 0
	_battery_kwh = float(_settings.initial_battery_kwh)
	_solar_generated_kwh = 0.0
	_habitat_used_kwh = 0.0
	_curtailed_kwh = 0.0
	_unserved_kwh = 0.0
	_events.clear()
	_history.clear()
	_cleaning_segments.clear()
	_next_history_time = HISTORY_INTERVAL_SECONDS
	_record_event("automatic-cleaning-started")
	_record_history()
	return true

static func _valid_settings(settings: Dictionary) -> bool:
	for key in DEFAULTS:
		if typeof(settings[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(settings[key])): return false
	if typeof(settings.max_sections) != TYPE_INT or settings.max_sections < 1 or settings.max_sections > 12: return false
	if settings.warning_seconds < 1.0 or settings.warning_seconds > 86400.0: return false
	if settings.time_scale < 0.1 or settings.time_scale > 60.0: return false
	if settings.section_work_seconds < 1.0 or settings.section_work_seconds > 86400.0: return false
	if settings.recall_entry_sim_seconds < 0.0 or settings.recall_entry_sim_seconds > 86400.0: return false
	if settings.clear_solar_power_kw < 0.0 or settings.clear_solar_power_kw > 10000.0: return false
	if settings.minimum_solar_transmission < 0.0 or settings.minimum_solar_transmission > 1.0: return false
	if settings.habitat_load_kw < 0.0 or settings.habitat_load_kw > 10000.0: return false
	if settings.battery_capacity_kwh < 0.001 or settings.battery_capacity_kwh > 100000.0: return false
	if settings.initial_battery_kwh < 0.0 or settings.initial_battery_kwh > settings.battery_capacity_kwh: return false
	if settings.storm_duration_hours < 0.0 or settings.storm_duration_hours > 10000.0: return false
	if settings.storm_load_kw < 0.0 or settings.storm_load_kw > 10000.0: return false
	if settings.storm_solar_kw < 0.0 or settings.storm_solar_kw > 10000.0: return false
	if settings.background_dose_ugy_per_day < 0.0 or settings.background_dose_ugy_per_day > 1000000.0: return false
	return settings.dose_reference_day_seconds == 86400.0

func set_pace(value: float) -> bool:
	if _status != "running" or not is_finite(value) or value not in [0.5, 1.0, 2.0]: return false
	if value == _pace: return true
	_pace = value
	_record_event("clock-pace-changed")
	return true

func set_cleaning_speed(multiplier: float) -> bool:
	if _status != "running" or _phase != "outside" or _cleaned_work >= float(_settings.max_sections) or not is_finite(multiplier) or multiplier not in CLEANING_MULTIPLIERS: return false
	if multiplier == _cleaning_multiplier: return true
	_cleaning_multiplier = multiplier
	_alert_count += 1
	_record_event("cleaning-speed-alert")
	return true

func start_cleaning() -> bool:
	if _status != "running" or _phase != "outside" or _cleaning or _cleaned_work >= float(_settings.max_sections): return false
	_cleaning = true
	_alert_count += 1
	_record_event("resume-cleaning-alert")
	return true

func stop_cleaning() -> bool:
	if _status != "running" or _phase != "outside" or not _cleaning: return false
	_cleaning = false
	_alert_count += 1
	_record_event("hold-cleaning-alert")
	return true

func request_recall() -> bool:
	if _status != "running" or _phase != "outside": return false
	_cleaning = false
	_recall_time = _sim_elapsed
	_phase = "airlock"
	_alert_count += 1
	_record_event("recall-alert")
	if float(_settings.recall_entry_sim_seconds) <= EPSILON: _arrive()
	return true

func request_return() -> bool:
	# Temporary controller compatibility; this is recall/entry, never a walk.
	return request_recall()

func advance(real_seconds: float) -> void:
	if _status != "running" or not is_finite(real_seconds) or real_seconds <= 0.0: return
	var clock_rate := float(_settings.time_scale) * _pace
	var remaining := minf(real_seconds * clock_rate, float(_settings.warning_seconds) - _sim_elapsed)
	while remaining > 0.0 and _status == "running":
		var amount := minf(remaining, float(_settings.warning_seconds) - _sim_elapsed)
		amount = minf(amount, _next_history_time - _sim_elapsed)
		if _cleaning and _phase == "outside":
			var next_work := minf(floor(_cleaned_work) + 1.0, float(_settings.max_sections))
			amount = minf(amount, (next_work - _cleaned_work) / _cleaning_rate())
		if _phase == "airlock": amount = minf(amount, float(_settings.recall_entry_sim_seconds) - _entry_elapsed)
		amount = maxf(0.0, amount)
		var solar_before := _solar_power()
		_sim_elapsed += amount
		_real_elapsed += amount / clock_rate
		remaining = maxf(0.0, remaining - amount)
		if _cleaning and _phase == "outside": _add_cleaning(amount)
		_integrate_energy(amount, solar_before, _solar_power())
		if _phase == "airlock": _entry_elapsed += amount
		_apply_boundaries()
		if _sim_elapsed >= _next_history_time - EPSILON:
			_record_history()
			_next_history_time += HISTORY_INTERVAL_SECONDS
		if amount <= EPSILON and _status == "running" and remaining <= EPSILON: break

func _add_cleaning(seconds: float) -> void:
	if seconds <= 0.0: return
	var before := _cleaned_work
	var next_boundary := minf(floor(before) + 1.0, float(_settings.max_sections))
	var seconds_to_boundary := (next_boundary - before) / _cleaning_rate()
	_cleaned_work = minf(float(_settings.max_sections), _cleaned_work + seconds * _cleaning_rate())
	# Only a step that reaches the scheduled boundary may snap to it. Rounding
	# every tiny increment near zero/integer work would erase small time slices.
	if seconds >= seconds_to_boundary: _cleaned_work = next_boundary
	_cleaning_active_seconds += seconds
	# At most two exact rate buckets: bounded across any number of speed alerts.
	var bucket := -1
	for index in range(_cleaning_segments.size()):
		if _cleaning_segments[index].cleaning_multiplier == _cleaning_multiplier: bucket = index
	if bucket < 0:
		_cleaning_segments.append({"cleaning_multiplier": _cleaning_multiplier, "rate_sections_per_minute": _cleaning_rate() * 60.0, "active_sim_seconds": 0.0, "cleaned_work": 0.0})
		bucket = _cleaning_segments.size() - 1
	_cleaning_segments[bucket].active_sim_seconds += seconds
	_cleaning_segments[bucket].cleaned_work += _cleaned_work - before
	if floor(_cleaned_work) > floor(before): _record_event("section-completed")

func _apply_boundaries() -> void:
	if _cleaning and _cleaned_work >= float(_settings.max_sections):
		_cleaned_work = float(_settings.max_sections)
		_cleaning = false
		_record_event("all-sections-completed")
	# Entry exactly at the deadline wins the tie.
	if _phase == "airlock" and _entry_elapsed >= float(_settings.recall_entry_sim_seconds) - EPSILON: _arrive()
	if _status == "running" and _sim_elapsed >= float(_settings.warning_seconds) - EPSILON:
		_sim_elapsed = float(_settings.warning_seconds)
		_finish("late")

func _arrive() -> void:
	_entry_elapsed = float(_settings.recall_entry_sim_seconds)
	_arrival_time = _sim_elapsed
	_phase = "sheltered"
	_record_event("shelter-entered")
	_finish("success" if _projected_battery() >= _required_reserve() - EPSILON else "power-shortfall")

func _finish(outcome: String) -> void:
	_status = outcome
	_cleaning = false
	_record_event("mission-finished")
	_record_history()

func _cleaning_rate(multiplier: float = -1.0) -> float:
	return (_cleaning_multiplier if multiplier < 0.0 else multiplier) / float(_settings.section_work_seconds)

func _solar_transmission(work: float = -1.0) -> float:
	var fraction := (_cleaned_work if work < 0.0 else work) / float(_settings.max_sections)
	return float(_settings.minimum_solar_transmission) + (1.0 - float(_settings.minimum_solar_transmission)) * clampf(fraction, 0.0, 1.0)

func _solar_power(work: float = -1.0) -> float:
	return float(_settings.clear_solar_power_kw) * _solar_transmission(work)

func _required_reserve() -> float:
	return maxf(0.0, float(_settings.storm_load_kw) - float(_settings.storm_solar_kw)) * float(_settings.storm_duration_hours)

func _projected_battery() -> float:
	var horizon := maxf(0.0, float(_settings.warning_seconds) - _sim_elapsed)
	return clampf(_battery_kwh + (_solar_power() - float(_settings.habitat_load_kw)) * horizon / 3600.0, 0.0, float(_settings.battery_capacity_kwh))

static func _energy_step(initial: float, solar_start: float, solar_end: float, load: float, seconds: float, capacity: float) -> Dictionary:
	var answer := {"battery_kwh": initial, "generated_kwh": 0.0, "used_kwh": 0.0, "curtailed_kwh": 0.0, "unserved_kwh": 0.0}
	if seconds <= 0.0: return answer
	var net_start := solar_start - load
	var net_end := solar_end - load
	# Split a net-power sign change before clipping the battery. Otherwise a
	# deficit at empty could incorrectly cancel charging later in the same frame.
	var split := -net_start / (net_end - net_start) if net_start * net_end < 0.0 else -1.0
	var cuts := [0.0, split, 1.0] if split > 0.0 and split < 1.0 else [0.0, 1.0]
	for index in range(cuts.size() - 1):
		var a: float = cuts[index]
		var b: float = cuts[index + 1]
		var hours := seconds * (b - a) / 3600.0
		var generated := (lerpf(solar_start, solar_end, a) + lerpf(solar_start, solar_end, b)) * 0.5 * hours
		var used := load * hours
		var proposed: float = answer.battery_kwh + generated - used
		answer.generated_kwh += generated
		answer.used_kwh += used
		answer.curtailed_kwh += maxf(0.0, proposed - capacity)
		answer.unserved_kwh += maxf(0.0, -proposed)
		answer.battery_kwh = clampf(proposed, 0.0, capacity)
	return answer

func _integrate_energy(seconds: float, solar_before: float, solar_after: float) -> void:
	var step := _energy_step(_battery_kwh, solar_before, solar_after, float(_settings.habitat_load_kw), seconds, float(_settings.battery_capacity_kwh))
	_battery_kwh = step.battery_kwh
	_solar_generated_kwh += step.generated_kwh
	_habitat_used_kwh += step.used_kwh
	_curtailed_kwh += step.curtailed_kwh
	_unserved_kwh += step.unserved_kwh

func _dose_rate_per_second() -> float:
	return float(_settings.background_dose_ugy_per_day) / float(_settings.dose_reference_day_seconds)

func _record_event(kind: String) -> void:
	_events.append({"kind": kind, "sim_seconds": _sim_elapsed, "real_seconds": _real_elapsed, "cleaned_work": _cleaned_work, "phase": _phase, "status": _status, "cleaning_multiplier": _cleaning_multiplier})
	if _events.size() > MAX_EVENTS: _events.pop_front()

func _record_history() -> void:
	var point := {"sim_seconds": _sim_elapsed, "real_seconds": _real_elapsed, "dose_ugy": _dose_rate_per_second() * _sim_elapsed, "battery_kwh": _battery_kwh, "solar_power_kw": _solar_power(), "projected_battery_at_warning_kwh": _projected_battery(), "cleaned_work": _cleaned_work, "sections_cleaned": int(floor(_cleaned_work)), "cleaning_multiplier": _cleaning_multiplier, "cleaning_active_sim_seconds": _cleaning_active_seconds, "phase": _phase}
	if not _history.is_empty() and absf(float(_history[-1].sim_seconds) - _sim_elapsed) <= EPSILON: _history[-1] = point
	else: _history.append(point)

func snapshot() -> Dictionary:
	var clock_rate := float(_settings.time_scale) * _pace
	var sim_left := maxf(0.0, float(_settings.warning_seconds) - _sim_elapsed)
	var entry_left := maxf(0.0, float(_settings.recall_entry_sim_seconds) - _entry_elapsed)
	var sections := int(floor(_cleaned_work))
	var fraction := _cleaned_work - sections
	var entry_progress := clampf(_entry_elapsed / float(_settings.recall_entry_sim_seconds), 0.0, 1.0) if float(_settings.recall_entry_sim_seconds) > EPSILON else (1.0 if _phase == "sheltered" else 0.0)
	var additional_work := minf(float(_settings.max_sections) - _cleaned_work, maxf(0.0, sim_left - entry_left) * _cleaning_rate()) if _phase == "outside" and _status == "running" else 0.0
	var can_recall := _status != "late" and sim_left + EPSILON >= entry_left
	if float(_settings.recall_entry_sim_seconds) <= EPSILON and _phase == "outside": can_recall = _status == "running" and sim_left > EPSILON
	var answer := _settings.duplicate(true)
	answer.merge({
		"scenario_id": SCENARIO_ID, "elapsed_seconds": _real_elapsed, "remaining_seconds": sim_left / clock_rate,
		"sim_elapsed_seconds": _sim_elapsed, "sim_remaining_seconds": sim_left,
		"cleaned_work": _cleaned_work, "clean_fraction": _cleaned_work / float(_settings.max_sections),
		"dust_fraction": 1.0 - _cleaned_work / float(_settings.max_sections),
		"sections_cleaned": sections, "section_progress": fraction,
		"section_seconds_remaining": (1.0 - fraction) / _cleaning_rate() / clock_rate if _phase == "outside" and sections < int(_settings.max_sections) and _status == "running" else 0.0,
		"cleaning": _cleaning, "cleaning_multiplier": _cleaning_multiplier,
		"cleaning_rate_sections_per_minute": _cleaning_rate() * 60.0,
		"cleaning_rate_sections_per_second": _cleaning_rate(),
		"base_cleaning_rate_sections_per_minute": 60.0 / float(_settings.section_work_seconds),
		"cleaning_active_sim_seconds": _cleaning_active_seconds, "cleaning_segments": _cleaning_segments.duplicate(true),
		"waiting_sim_seconds": maxf(0.0, _sim_elapsed - _cleaning_active_seconds - _entry_elapsed),
		"phase": _phase, "status": _status, "pace": _pace, "effective_time_scale": clock_rate,
		"entry_progress": entry_progress, "entry_seconds_remaining": entry_left / clock_rate,
		"entry_sim_seconds_remaining": entry_left,
		"return_progress": entry_progress, "return_seconds_remaining": entry_left / clock_rate,
		"recall_sim_seconds": _recall_time, "departure_sim_seconds": _recall_time, "arrival_sim_seconds": _arrival_time,
		"latest_recall_sim_seconds": float(_settings.warning_seconds) - float(_settings.recall_entry_sim_seconds),
		"latest_departure_sim_seconds": float(_settings.warning_seconds) - float(_settings.recall_entry_sim_seconds),
		"recall_slack_seconds": (sim_left - entry_left) / clock_rate, "can_recall_on_time": can_recall,
		"return_slack_seconds": (sim_left - entry_left) / clock_rate, "can_return_on_time": can_recall,
		"crew_sheltered": _phase == "sheltered", "alert_count": _alert_count,
		"battery_kwh": _battery_kwh, "solar_power_kw": _solar_power(), "net_power_kw": _solar_power() - float(_settings.habitat_load_kw),
		"solar_transmission": _solar_transmission(), "projected_battery_at_warning_kwh": _projected_battery(),
		"battery_projection_horizon_seconds": sim_left, "required_reserve_kwh": _required_reserve(),
		"reserve_met": _projected_battery() >= _required_reserve() - EPSILON,
		"energy_deficit_kwh": maxf(0.0, _required_reserve() - _projected_battery()),
		"solar_energy_generated_kwh": _solar_generated_kwh, "habitat_energy_used_kwh": _habitat_used_kwh,
		"curtailed_energy_kwh": _curtailed_kwh, "unserved_energy_kwh": _unserved_kwh,
		"projection_assumptions": "Forecast through warning with no more cleaning, unchanged sunlight/output/load, ideal battery and capacity limit. Not energy already stored.",
		"dose_ugy": _dose_rate_per_second() * _sim_elapsed, "dose_rate_ugy_per_hour": _dose_rate_per_second() * 3600.0,
		"max_additional_work": additional_work, "max_additional_sections": maxi(0, int(floor(_cleaned_work + additional_work + EPSILON)) - sections),
		"assumptions": _settings.duplicate(true), "events": _events.duplicate(true), "history": _history.duplicate(true),
	})
	return answer

func plan_for_work(work: float, multiplier_override: float = -1.0) -> Dictionary:
	if not is_finite(work) or work < 0.0 or work > float(_settings.max_sections): return {"valid": false, "reason": "Cleaning amount is outside this scenario."}
	if not is_finite(multiplier_override) or (multiplier_override != -1.0 and multiplier_override not in CLEANING_MULTIPLIERS): return {"valid": false, "reason": "Cleaning multiplier must be 1 or 1.25."}
	var multiplier := _cleaning_multiplier if multiplier_override == -1.0 else multiplier_override
	var cleaning_time := work / _cleaning_rate(multiplier)
	var outside := cleaning_time + float(_settings.recall_entry_sim_seconds)
	var measured := minf(outside, float(_settings.warning_seconds))
	var measured_work := minf(work, measured * _cleaning_rate(multiplier))
	var on_time := outside <= float(_settings.warning_seconds) + EPSILON
	# advance() closes an expired round before another command can be issued.
	# Positive entry can finish at the deadline inside that advance, but an
	# instant recall command must be issued strictly before the clock expires.
	if float(_settings.recall_entry_sim_seconds) <= EPSILON:
		on_time = cleaning_time < float(_settings.warning_seconds) - EPSILON
	var clean_step := _energy_step(float(_settings.initial_battery_kwh), _solar_power(0.0), _solar_power(measured_work), float(_settings.habitat_load_kw), minf(cleaning_time, measured), float(_settings.battery_capacity_kwh))
	var entry_step := _energy_step(clean_step.battery_kwh, _solar_power(measured_work), _solar_power(measured_work), float(_settings.habitat_load_kw), maxf(0.0, measured - cleaning_time), float(_settings.battery_capacity_kwh))
	var projection_horizon := maxf(0.0, float(_settings.warning_seconds) - measured)
	var projected := clampf(float(entry_step.battery_kwh) + (_solar_power(measured_work) - float(_settings.habitat_load_kw)) * projection_horizon / 3600.0, 0.0, float(_settings.battery_capacity_kwh))
	var powered := projected >= _required_reserve() - EPSILON
	return {
		"valid": true, "planned_cleaned_work": work, "cleaned_work": measured_work, "sections_cleaned": int(floor(measured_work + EPSILON)),
		"cleaning_multiplier": multiplier, "cleaning_rate_sections_per_minute": _cleaning_rate(multiplier) * 60.0,
		"cleaning_active_sim_seconds": minf(cleaning_time, measured), "recall_entry_sim_seconds": float(_settings.recall_entry_sim_seconds),
		"outside_sim_seconds": outside, "measured_sim_seconds": measured, "play_seconds": outside / (float(_settings.time_scale) * _pace),
		"battery_kwh": entry_step.battery_kwh, "projected_battery_at_warning_kwh": projected,
		"battery_projection_horizon_seconds": projection_horizon, "required_reserve_kwh": _required_reserve(),
		"solar_power_kw": _solar_power(measured_work),
		"dose_ugy": _dose_rate_per_second() * measured, "dose_duration_sim_seconds": measured,
		"on_time": on_time, "reserve_met": powered, "status": "late" if not on_time else ("success" if powered else "power-shortfall"),
		"max_work_before_deadline": minf(float(_settings.max_sections), maxf(0.0, float(_settings.warning_seconds) - float(_settings.recall_entry_sim_seconds)) * _cleaning_rate(multiplier)),
		"latest_recall_sim_seconds": float(_settings.warning_seconds) - float(_settings.recall_entry_sim_seconds),
		"scope": "Hypothetical constant-rate cleaning then recall from mission start, without holds. Actual battery and dose end at entry/deadline. Battery at warning is a separate fixed-sunlight/load/cleanliness forecast, including continued generation after entry.",
	}

func plan_for_sections(count: int, multiplier_override: float = -1.0) -> Dictionary:
	return plan_for_work(float(count), multiplier_override)

func minimum_reserve_plan() -> Dictionary:
	var entry_reserve := float(_settings.recall_entry_sim_seconds)
	# Keep the zero-entry search endpoint executable, rather than rejecting all
	# earlier feasible plans because the exact-deadline endpoint is terminal.
	if entry_reserve <= EPSILON: entry_reserve = EPSILON * 2.0
	var maximum := minf(float(_settings.max_sections), maxf(0.0, float(_settings.warning_seconds) - entry_reserve) * _cleaning_rate())
	var high_plan := plan_for_work(maximum)
	if not high_plan.on_time or not high_plan.reserve_met: return {"valid": false, "reason": "No on-time constant-rate plan can meet this scenario's reserve."}
	var low := 0.0
	var high := maximum
	for iteration in range(48):
		var midpoint := (low + high) * 0.5
		if plan_for_work(midpoint).reserve_met: high = midpoint
		else: low = midpoint
	return plan_for_work(high)

func result() -> Dictionary:
	var answer := snapshot()
	var comparisons: Array[Dictionary] = []
	for count in range(int(_settings.max_sections) + 1): comparisons.append(plan_for_sections(count))
	answer["comparisons"] = comparisons
	answer["minimum_target_plan"] = minimum_reserve_plan()
	answer["equations"] = {
		"work": "cleaned work = sum of cleaning rate × active time at that rate",
		"solar": "solar power = clear-array power × dust transmission",
		"battery": "stored energy = initial energy + integral of (solar power − habitat load) × time, bounded by battery capacity",
		"dose": "absorbed dose = historical reference dose rate × total time outside",
	}
	answer["safety_note"] = "Faster cleaning is bounded assistance with no invented fatigue or quality penalty. Mission targets are fictional planning goals; the model does not calculate injury, death, personal sievert dose, walking or pressure cycling."
	return answer
