extends RefCounted
## Authored pace/fatigue lesson. Historical absorbed-dose baseline is not health data.
## No clock advances until the controller calls advance after START MISSION.
const SCENARIO_ID := "window-pace-v4"
const EPSILON := 0.000000001
const HISTORY_INTERVAL_SECONDS := 60.0
const MAX_EVENTS := 128
const MAX_SEGMENTS := 128
const CLEANING_MULTIPLIERS := [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75]
const DEFAULTS := {
	"warning_seconds": 1800.0,
	"time_scale": 6.0,
	"base_cleaning_rate_sections_per_minute": 0.125,
	"max_sections": 4,
	"initial_fatigue": 0.0,
	"fatigue_max": 0.9,
	"fatigue_growth_per_minute": 0.08,
	"fatigue_recovery_per_minute": 0.12,
	"clear_solar_power_kw": 8.0,
	"minimum_solar_transmission": 0.25,
	"habitat_load_kw": 1.0,
	"initial_battery_kwh": 0.5,
	"battery_capacity_kwh": 6.0,
	"background_dose_ugy_per_day": 210.0,
	"dose_reference_day_seconds": 86400.0,
	"radiation_ramp_multiplier": 3.0,
	"win_clean_fraction": 0.8,
	"pass_clean_fraction": 0.4,
}
var _settings: Dictionary = DEFAULTS.duplicate(true)
var _sim_elapsed := 0.0
var _real_elapsed := 0.0
var _cleaned_work := 0.0
var _fatigue := 0.0
var _cleaning_active_seconds := 0.0
var _weighted_work_seconds := 0.0
var _battery_kwh := 0.5
var _solar_generated_kwh := 0.0
var _habitat_used_kwh := 0.0
var _curtailed_kwh := 0.0
var _unserved_kwh := 0.0
var _status := "running"
var _pace := 1.0
var _multiplier := 1.0
var _command_count := 0
var _events: Array[Dictionary] = []
var _history: Array[Dictionary] = []
var _pace_segments: Array[Dictionary] = []
var _segments_truncated := false
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
	_fatigue = float(_settings.initial_fatigue)
	_cleaning_active_seconds = 0.0
	_weighted_work_seconds = 0.0
	_battery_kwh = float(_settings.initial_battery_kwh)
	_solar_generated_kwh = 0.0
	_habitat_used_kwh = 0.0
	_curtailed_kwh = 0.0
	_unserved_kwh = 0.0
	_status = "running"
	_pace = 1.0
	_multiplier = 1.0
	_command_count = 0
	_events.clear()
	_history.clear()
	_pace_segments.clear()
	_segments_truncated = false
	_next_history_time = HISTORY_INTERVAL_SECONDS
	_record_event("mission-prepared")
	_record_history()
	return true

static func _valid_settings(value: Dictionary) -> bool:
	for key in DEFAULTS:
		if typeof(value[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value[key])): return false
	if value.warning_seconds < 1.0 or value.warning_seconds > 86400.0: return false
	if value.time_scale < 0.1 or value.time_scale > 60.0: return false
	if value.base_cleaning_rate_sections_per_minute < 0.0 or value.base_cleaning_rate_sections_per_minute > 100.0: return false
	if typeof(value.max_sections) != TYPE_INT or value.max_sections < 1 or value.max_sections > 128: return false
	if value.fatigue_max < 0.0 or value.fatigue_max >= 1.0: return false
	if value.initial_fatigue < 0.0 or value.initial_fatigue > value.fatigue_max: return false
	if value.fatigue_growth_per_minute < 0.0 or value.fatigue_growth_per_minute > 10.0: return false
	if value.fatigue_recovery_per_minute < 0.0 or value.fatigue_recovery_per_minute > 10.0: return false
	if value.clear_solar_power_kw < 0.0 or value.clear_solar_power_kw > 10000.0: return false
	if value.minimum_solar_transmission < 0.0 or value.minimum_solar_transmission > 1.0: return false
	if value.habitat_load_kw < 0.0 or value.habitat_load_kw > 10000.0: return false
	if value.battery_capacity_kwh < 0.001 or value.battery_capacity_kwh > 100000.0: return false
	if value.initial_battery_kwh < 0.0 or value.initial_battery_kwh > value.battery_capacity_kwh: return false
	if value.background_dose_ugy_per_day < 0.0 or value.background_dose_ugy_per_day > 1000000.0: return false
	if value.dose_reference_day_seconds != 86400.0: return false
	if value.radiation_ramp_multiplier < 0.0 or value.radiation_ramp_multiplier > 100.0: return false
	if value.pass_clean_fraction < 0.0 or value.win_clean_fraction > 1.0 or value.pass_clean_fraction > value.win_clean_fraction: return false
	return true

func set_cleaning_speed(multiplier: float) -> bool:
	if _status != "running" or not is_finite(multiplier) or multiplier not in CLEANING_MULTIPLIERS: return false
	if multiplier == _multiplier: return true
	_multiplier = multiplier
	_command_count += 1
	_record_event("pace-selected")
	return true

func set_pace(value: float) -> bool:
	if _status != "running" or not is_finite(value) or value not in [0.5, 1.0, 2.0]: return false
	if value == _pace: return true
	_pace = value
	_record_event("clock-pace-changed")
	return true

func _cleaning_active() -> bool:
	return _status == "running" and _cleaned_work < float(_settings.max_sections)

func _fatigue_slope() -> float:
	if not _cleaning_active(): return 0.0
	var slope := float(_settings.fatigue_growth_per_minute) * maxf(_multiplier - 1.0, 0.0) - float(_settings.fatigue_recovery_per_minute) * maxf(1.0 - _multiplier, 0.0)
	if (_fatigue <= 0.0 and slope < 0.0) or (_fatigue >= float(_settings.fatigue_max) and slope > 0.0): return 0.0
	return slope

func _effective_rate() -> float:
	return float(_settings.base_cleaning_rate_sections_per_minute) * _multiplier * (1.0 - _fatigue)

static func _work_seconds(work: float, rate_per_second: float, rate_slope_per_second: float) -> float:
	if work <= 0.0: return 0.0
	if rate_per_second <= 0.0: return INF
	if rate_slope_per_second == 0.0: return work / rate_per_second
	# Stable positive root of work = rate*t + .5*slope*t^2.
	var discriminant := maxf(0.0, rate_per_second * rate_per_second + 2.0 * rate_slope_per_second * work)
	return 2.0 * work / (rate_per_second + sqrt(discriminant))

func advance(real_seconds: float) -> void:
	if _status != "running" or not is_finite(real_seconds) or real_seconds <= 0.0: return
	var clock_rate := float(_settings.time_scale) * _pace
	var until_deadline := float(_settings.warning_seconds) - _sim_elapsed
	var remaining := minf(real_seconds * clock_rate, until_deadline)
	# Repeated floating-point frame sums can leave a sub-nanosecond residual at
	# the fixed endpoint. Integrate that residual through the same boundaries;
	# never leave an otherwise completed round waiting for another display frame.
	if until_deadline - remaining <= EPSILON: remaining = until_deadline
	while remaining > 0.0 and _status == "running":
		var until_end := float(_settings.warning_seconds) - _sim_elapsed
		var until_history := _next_history_time - _sim_elapsed
		var amount := minf(remaining, minf(until_end, until_history))
		var active := _cleaning_active()
		var fatigue_before := _fatigue
		var fatigue_slope := _fatigue_slope() / 60.0
		var until_fatigue := INF
		var fatigue_target := _fatigue
		if fatigue_slope > 0.0:
			fatigue_target = float(_settings.fatigue_max)
			until_fatigue = (fatigue_target - _fatigue) / fatigue_slope
		elif fatigue_slope < 0.0:
			fatigue_target = 0.0
			until_fatigue = -_fatigue / fatigue_slope
		amount = minf(amount, until_fatigue)
		var work_rate := _effective_rate() / 60.0 if active else 0.0
		var work_slope := -float(_settings.base_cleaning_rate_sections_per_minute) * _multiplier / 60.0 * fatigue_slope if active else 0.0
		var possible_work := work_rate * amount + 0.5 * work_slope * amount * amount
		var work_left := float(_settings.max_sections) - _cleaned_work
		var until_work := INF
		if active and possible_work >= work_left and work_rate > 0.0:
			until_work = _work_seconds(work_left, work_rate, work_slope)
			amount = minf(amount, until_work)
		amount = maxf(0.0, amount)
		var work_before := _cleaned_work
		var solar_before := _solar_power()
		var start_time := _sim_elapsed
		var work_added := maxf(0.0, work_rate * amount + 0.5 * work_slope * amount * amount)
		if active:
			_cleaned_work = minf(float(_settings.max_sections), _cleaned_work + work_added)
			if amount >= until_work: _cleaned_work = float(_settings.max_sections)
			_fatigue = clampf(_fatigue + fatigue_slope * amount, 0.0, float(_settings.fatigue_max))
			if amount >= until_fatigue: _fatigue = fatigue_target
			_cleaning_active_seconds += amount
			# Integral of u*(1-F) dt; valid even for a configurable zero base rate.
			_weighted_work_seconds += _multiplier * ((1.0 - fatigue_before) * amount - 0.5 * fatigue_slope * amount * amount)
		var solar_gain := float(_settings.clear_solar_power_kw) * (1.0 - float(_settings.minimum_solar_transmission)) / float(_settings.max_sections)
		_integrate_energy(amount, solar_before, solar_gain * work_rate, 0.5 * solar_gain * work_slope)
		_sim_elapsed += amount
		if amount >= until_end: _sim_elapsed = float(_settings.warning_seconds)
		elif amount >= until_history: _sim_elapsed = _next_history_time
		_real_elapsed += amount / clock_rate
		remaining = maxf(0.0, remaining - amount)
		if active and amount > 0.0: _record_segment(start_time, fatigue_before, _cleaned_work - work_before, amount)
		if active and _cleaned_work >= float(_settings.max_sections): _record_event("panel-complete")
		if _sim_elapsed >= float(_settings.warning_seconds): _finish()
		if _sim_elapsed >= _next_history_time:
			_record_history()
			_next_history_time += HISTORY_INTERVAL_SECONDS
		# Every zero-length boundary changes a bound or sampling instant above.
		if amount == 0.0 and remaining == 0.0: break

func _integrate_energy(seconds: float, solar_start: float, solar_linear: float, solar_quadratic: float) -> void:
	if seconds <= 0.0: return
	var load := float(_settings.habitat_load_kw)
	var solar_end := solar_start + solar_linear * seconds + solar_quadratic * seconds * seconds
	var cuts := [0.0, seconds]
	# Output increases monotonically with cleaned work; at most one net-zero
	# crossing exists in this polynomial interval. Split before storage clipping.
	if solar_start < load and solar_end > load:
		var low := 0.0
		var high := seconds
		for iteration in range(52):
			var midpoint := (low + high) * 0.5
			if solar_start + solar_linear * midpoint + solar_quadratic * midpoint * midpoint < load: low = midpoint
			else: high = midpoint
		cuts = [0.0, (low + high) * 0.5, seconds]
	for index in range(cuts.size() - 1):
		var a: float = cuts[index]
		var b: float = cuts[index + 1]
		var generated := (solar_start * (b - a) + 0.5 * solar_linear * (b * b - a * a) + solar_quadratic / 3.0 * (b * b * b - a * a * a)) / 3600.0
		var used := load * (b - a) / 3600.0
		var proposed := _battery_kwh + generated - used
		_solar_generated_kwh += generated
		_habitat_used_kwh += used
		_curtailed_kwh += maxf(0.0, proposed - float(_settings.battery_capacity_kwh))
		_unserved_kwh += maxf(0.0, -proposed)
		_battery_kwh = clampf(proposed, 0.0, float(_settings.battery_capacity_kwh))

func _solar_transmission() -> float:
	return float(_settings.minimum_solar_transmission) + (1.0 - float(_settings.minimum_solar_transmission)) * _cleaned_work / float(_settings.max_sections)

func _solar_power() -> float:
	return float(_settings.clear_solar_power_kw) * _solar_transmission()

func _dose() -> float:
	var ramp := float(_settings.radiation_ramp_multiplier)
	return float(_settings.background_dose_ugy_per_day) / float(_settings.dose_reference_day_seconds) * (_sim_elapsed + 0.5 * ramp * _sim_elapsed * _sim_elapsed / float(_settings.warning_seconds))

func _radiation_rate() -> float:
	return float(_settings.background_dose_ugy_per_day) * (1.0 + float(_settings.radiation_ramp_multiplier) * _sim_elapsed / float(_settings.warning_seconds))

func _finish() -> void:
	var fraction := _cleaned_work / float(_settings.max_sections)
	_status = "win" if fraction >= float(_settings.win_clean_fraction) - EPSILON else ("pass" if fraction >= float(_settings.pass_clean_fraction) - EPSILON else "lose")
	_record_event("automatic-shelter-entry")
	_record_history()

func _record_segment(start: float, fatigue_before: float, work: float, seconds: float) -> void:
	var append_new: bool = _pace_segments.is_empty() or _pace_segments[-1].selected_multiplier != _multiplier or absf(float(_pace_segments[-1].end_sim_seconds) - start) > EPSILON
	if append_new:
		_pace_segments.append({"selected_multiplier": _multiplier, "start_sim_seconds": start, "end_sim_seconds": _sim_elapsed, "fatigue_start": fatigue_before, "fatigue_end": _fatigue, "active_sim_seconds": seconds, "cleaned_work": work})
		if _pace_segments.size() > MAX_SEGMENTS:
			_pace_segments.pop_front()
			_segments_truncated = true
	else:
		var segment: Dictionary = _pace_segments[-1]
		segment.end_sim_seconds = _sim_elapsed
		segment.fatigue_end = _fatigue
		segment.active_sim_seconds += seconds
		segment.cleaned_work += work

func _record_event(kind: String) -> void:
	_events.append({"kind": kind, "sim_seconds": _sim_elapsed, "selected_multiplier": _multiplier, "fatigue": _fatigue, "cleaned_work": _cleaned_work, "status": _status})
	if _events.size() > MAX_EVENTS: _events.pop_front()

func _record_history() -> void:
	var row := {"sim_seconds": _sim_elapsed, "real_seconds": _real_elapsed, "selected_multiplier": _multiplier, "fatigue": _fatigue, "cleaned_work": _cleaned_work, "clean_fraction": _cleaned_work / float(_settings.max_sections), "battery_kwh": _battery_kwh, "solar_power_kw": _solar_power(), "dose_ugy": _dose(), "radiation_rate_ugy_per_day": _radiation_rate()}
	if not _history.is_empty() and _history[-1].sim_seconds == _sim_elapsed: _history[-1] = row
	else: _history.append(row)

func snapshot() -> Dictionary:
	var answer := _settings.duplicate(true)
	var clock_rate := float(_settings.time_scale) * _pace
	var left := maxf(0.0, float(_settings.warning_seconds) - _sim_elapsed)
	var active := _cleaning_active()
	var full := _status != "running"
	var whole := int(floor(_cleaned_work))
	answer.merge({
		"scenario_id": SCENARIO_ID, "status": _status, "phase": "sheltered" if full else "outside", "crew_sheltered": full,
		"elapsed_seconds": _real_elapsed, "remaining_seconds": left / clock_rate, "sim_elapsed_seconds": _sim_elapsed, "sim_remaining_seconds": left,
		"pace": _pace, "effective_time_scale": clock_rate, "selected_multiplier": _multiplier, "cleaning_multiplier": _multiplier, "clean_multiplier": _multiplier,
		"fatigue": _fatigue, "fatigue_rate_per_minute": _fatigue_slope(), "cleaning": active,
		"effective_rate_sections_per_minute": _effective_rate(), "cleaning_rate_sections_per_minute": _effective_rate() if active else 0.0,
		"nominal_cleaning_rate_sections_per_minute": float(_settings.base_cleaning_rate_sections_per_minute) * _multiplier,
		"cleaned_work": _cleaned_work, "clean_fraction": _cleaned_work / float(_settings.max_sections), "dust_fraction": 1.0 - _cleaned_work / float(_settings.max_sections),
		"sections_cleaned": whole, "section_progress": _cleaned_work - whole, "cleaning_active_sim_seconds": _cleaning_active_seconds,
		"fatigue_weighted_work_seconds": _weighted_work_seconds, "pace_segments": _pace_segments.duplicate(true), "pace_segments_truncated": _segments_truncated,
		"storm_progress": _sim_elapsed / float(_settings.warning_seconds), "storm_distance_normalized": 1.0 - _sim_elapsed / float(_settings.warning_seconds),
		"dose_ugy": _dose(), "radiation_rate_ugy_per_day": _radiation_rate(), "dose_rate_ugy_per_hour": _radiation_rate() / 24.0,
		"battery_kwh": _battery_kwh, "solar_power_kw": _solar_power(), "net_power_kw": _solar_power() - float(_settings.habitat_load_kw), "solar_transmission": _solar_transmission(),
		"solar_energy_generated_kwh": _solar_generated_kwh, "habitat_energy_used_kwh": _habitat_used_kwh, "curtailed_energy_kwh": _curtailed_kwh, "unserved_energy_kwh": _unserved_kwh,
		"command_count": _command_count, "alert_count": _command_count, "assumptions": _settings.duplicate(true), "events": _events.duplicate(true), "history": _history.duplicate(true),
	})
	return answer

func result() -> Dictionary:
	var answer := snapshot()
	answer["equations"] = {
		"fatigue": "fatigue change per active minute = growth coefficient × max(u−1,0) − recovery coefficient × max(1−u,0), bounded to the configured range",
		"work": "cleaned work = base rate × integral of u × (1−fatigue) over active cleaning minutes",
		"solar": "solar power = clear-array power × dust transmission",
		"battery": "stored energy = initial energy + integral of (solar power − load) × seconds /3600, bounded by capacity",
		"dose": "absorbed dose = integral of the authored rising microgray/day reference rate × outside seconds /86400",
	}
	answer["dose_bonus_awarded"] = false
	answer["outcome_basis"] = "Clean fraction only: win at %.0f%%, pass at %.0f%%, otherwise lose. Everyone enters shelter at the same mission time; the same radiation profile gives the same final dose." % [100.0 * float(_settings.win_clean_fraction), 100.0 * float(_settings.pass_clean_fraction)]
	answer["safety_note"] = "Fatigue and the rising radiation profile are authored game-balancing assumptions, not astronaut physiology, live NASA forecasts or a personal health model. No microgray-to-sievert conversion or dose bonus is applied."
	return answer
