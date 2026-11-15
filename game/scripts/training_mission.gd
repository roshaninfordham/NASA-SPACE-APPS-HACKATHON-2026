extends RefCounted
## The short operator mission. Scene geometry and interface never own these rules.
## Time: simulated seconds. Dose: absorbed microgray, NOT sievert or a health score.
## Margin: percentage points of output, NOT stored energy or battery autonomy.

const SCENARIO_ID := "window-training-v1"
const EPSILON := 0.0000001
const HISTORY_INTERVAL_SECONDS := 60.0
const MAX_EVENTS := 128
const DEFAULTS := {
	"warning_seconds": 1800.0,
	"time_scale": 6.0,
	"distance_m": 432.0,
	"walking_speed_mps": 0.8,
	"section_work_seconds": 360.0,
	"max_sections": 4,
	"initial_spare_power_points": 1.0,
	"gain_per_section_points": 2.0,
	"dust_loss_points_per_sol": 0.28,
	"target_margin_sols": 15.0,
	"background_dose_ugy_per_day": 210.0,
	"dose_reference_day_seconds": 86400.0,
}

var _settings: Dictionary = DEFAULTS.duplicate(true)
var _sim_elapsed := 0.0
var _real_elapsed := 0.0
var _section_work := 0.0
var _sections := 0
var _return_elapsed := 0.0
var _departure_time := -1.0
var _arrival_time := -1.0
var _cleaning := false
var _phase := "outside"
var _status := "running"
var _pace := 1.0
var _events: Array[Dictionary] = []
var _history: Array[Dictionary] = []
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
	_section_work = 0.0
	_sections = 0
	_return_elapsed = 0.0
	_departure_time = -1.0
	_arrival_time = -1.0
	_cleaning = false
	_phase = "outside"
	_status = "running"
	_pace = 1.0
	_events.clear()
	_history.clear()
	_next_history_time = HISTORY_INTERVAL_SECONDS
	_record_event("mission-ready")
	_record_history()
	return true

static func _valid_settings(settings: Dictionary) -> bool:
	for key in DEFAULTS:
		if typeof(settings[key]) not in [TYPE_INT, TYPE_FLOAT]: return false
		if not is_finite(float(settings[key])): return false
	if typeof(settings.max_sections) != TYPE_INT or settings.max_sections < 1 or settings.max_sections > 12: return false
	if settings.warning_seconds < 1.0 or settings.warning_seconds > 86400.0: return false
	if settings.time_scale < 0.1 or settings.time_scale > 60.0: return false
	if settings.distance_m < 0.0 or settings.distance_m > 20000.0: return false
	if settings.walking_speed_mps < 0.05 or settings.walking_speed_mps > 3.0: return false
	if settings.section_work_seconds < 1.0 or settings.section_work_seconds > 86400.0: return false
	if settings.initial_spare_power_points < 0.0 or settings.initial_spare_power_points > 100.0: return false
	if settings.gain_per_section_points < 0.001 or settings.gain_per_section_points > 100.0: return false
	if settings.dust_loss_points_per_sol < 0.0001 or settings.dust_loss_points_per_sol > 100.0: return false
	if settings.target_margin_sols < 0.0 or settings.target_margin_sols > 365.0: return false
	if settings.background_dose_ugy_per_day < 0.0 or settings.background_dose_ugy_per_day > 1000000.0: return false
	# The observed daily rate is explicitly normalized to a 24-hour reference day.
	# A Mars sol is not silently substituted into the denominator.
	if settings.dose_reference_day_seconds != 86400.0: return false
	return true

func set_pace(value: float) -> bool:
	if _status != "running" or not is_finite(value): return false
	if value not in [0.5, 1.0, 2.0]: return false
	if value == _pace: return true
	_pace = value
	_record_event("pace-changed")
	return true

func start_cleaning() -> bool:
	if _status != "running" or _phase != "outside" or _sections >= int(_settings.max_sections) or _cleaning: return false
	_cleaning = true
	_record_event("cleaning-started")
	return true

func stop_cleaning() -> bool:
	if _status != "running" or not _cleaning: return false
	_cleaning = false
	_record_event("cleaning-paused")
	return true

func request_return() -> bool:
	if _status != "running" or _phase != "outside": return false
	_cleaning = false
	# Work that has not completed a section never earns its output-margin gain.
	_section_work = 0.0
	_departure_time = _sim_elapsed
	_phase = "returning"
	_record_event("return-started")
	if _walk_seconds() <= EPSILON: _arrive()
	return true

func advance(real_seconds: float) -> void:
	if _status != "running" or not is_finite(real_seconds) or real_seconds <= 0.0: return
	var speed := float(_settings.time_scale) * _pace
	# Event-boundary integration is exact for these constant rates and limits the
	# work even if a caller submits an enormous delta after a suspended window.
	var remaining := minf(real_seconds * speed, float(_settings.warning_seconds) - _sim_elapsed)
	while remaining > 0.0 and _status == "running":
		var amount := minf(remaining, float(_settings.warning_seconds) - _sim_elapsed)
		amount = minf(amount, _next_history_time - _sim_elapsed)
		if _cleaning and _phase == "outside":
			amount = minf(amount, float(_settings.section_work_seconds) - _section_work)
		if _phase == "returning":
			amount = minf(amount, _walk_seconds() * 0.9 - _return_elapsed)
		elif _phase == "airlock":
			amount = minf(amount, _walk_seconds() - _return_elapsed)
		amount = maxf(0.0, amount)
		_sim_elapsed += amount
		_real_elapsed += amount / speed
		remaining = maxf(0.0, remaining - amount)
		if _cleaning and _phase == "outside": _section_work += amount
		if _phase in ["returning", "airlock"]: _return_elapsed += amount
		_apply_boundaries()
		if _sim_elapsed >= _next_history_time - EPSILON:
			_record_history()
			_next_history_time += HISTORY_INTERVAL_SECONDS
		# Every zero-length event must change phase/status or move a boundary.
		# Invalid/tiny inputs are ignored rather than spinning an unbounded loop.
		if amount <= EPSILON and _status == "running" and remaining <= EPSILON: break

func _apply_boundaries() -> void:
	if _cleaning and _phase == "outside" and _section_work >= float(_settings.section_work_seconds) - EPSILON:
		_section_work = 0.0
		_sections += 1
		_record_event("section-completed")
		if _sections >= int(_settings.max_sections):
			_cleaning = false
			_record_event("all-sections-completed")
	if _phase == "returning" and _return_elapsed >= _walk_seconds() * 0.9 - EPSILON:
		_phase = "airlock"
		_record_event("airlock-entry")
	# Arrival wins the boundary tie: entry exactly at the deadline is on time.
	if _phase == "airlock" and _return_elapsed >= _walk_seconds() - EPSILON:
		_arrive()
	if _status == "running" and _sim_elapsed >= float(_settings.warning_seconds) - EPSILON:
		_sim_elapsed = float(_settings.warning_seconds)
		_finish("late")

func _arrive() -> void:
	_return_elapsed = _walk_seconds()
	_arrival_time = _sim_elapsed
	_phase = "sheltered"
	_record_event("shelter-entered")
	_finish("success" if _margin_sols() >= float(_settings.target_margin_sols) - EPSILON else "power-shortfall")

func _finish(outcome: String) -> void:
	_status = outcome
	_cleaning = false
	_record_event("mission-finished")
	_record_history()

func _walk_seconds(speed_override: float = -1.0) -> float:
	var speed := float(_settings.walking_speed_mps) if speed_override < 0.0 else speed_override
	return float(_settings.distance_m) / speed

func _spare_points() -> float:
	return float(_settings.initial_spare_power_points) + float(_settings.gain_per_section_points) * _sections

func _margin_sols() -> float:
	return _spare_points() / float(_settings.dust_loss_points_per_sol)

func _dose_rate_per_second() -> float:
	return float(_settings.background_dose_ugy_per_day) / float(_settings.dose_reference_day_seconds)

func _record_event(kind: String) -> void:
	_events.append({"kind": kind, "sim_seconds": _sim_elapsed, "real_seconds": _real_elapsed, "sections_cleaned": _sections, "phase": _phase, "status": _status})
	if _events.size() > MAX_EVENTS: _events.pop_front()

func _record_history() -> void:
	var point := {"sim_seconds": _sim_elapsed, "real_seconds": _real_elapsed, "dose_ugy": _dose_rate_per_second() * _sim_elapsed, "power_margin_sols": _margin_sols(), "sections_cleaned": _sections, "phase": _phase}
	if not _history.is_empty() and absf(float(_history[-1].sim_seconds) - _sim_elapsed) <= EPSILON:
		_history[-1] = point
	else:
		_history.append(point)

func snapshot() -> Dictionary:
	var speed := float(_settings.time_scale) * _pace
	var sim_left := maxf(0.0, float(_settings.warning_seconds) - _sim_elapsed)
	var walk := _walk_seconds()
	var return_left := maxf(0.0, walk - _return_elapsed)
	var needed_total := maxi(0, int(ceil((float(_settings.target_margin_sols) * float(_settings.dust_loss_points_per_sol) - float(_settings.initial_spare_power_points)) / float(_settings.gain_per_section_points) - EPSILON)))
	var additional := 0
	if _phase == "outside" and _status == "running":
		additional = clampi(int(floor((sim_left - walk + _section_work) / float(_settings.section_work_seconds) + EPSILON)), 0, int(_settings.max_sections) - _sections)
	var answer := _settings.duplicate(true)
	answer.merge({
		"scenario_id": SCENARIO_ID,
		"elapsed_seconds": _real_elapsed,
		"remaining_seconds": sim_left / speed,
		"sim_elapsed_seconds": _sim_elapsed,
		"sim_remaining_seconds": sim_left,
		"sections_cleaned": _sections,
		"section_progress": _section_work / float(_settings.section_work_seconds),
		"section_seconds_remaining": maxf(0.0, float(_settings.section_work_seconds) - _section_work) / speed if _phase == "outside" and _sections < int(_settings.max_sections) and _status == "running" else 0.0,
		"cleaning": _cleaning,
		"phase": _phase,
		"status": _status,
		"pace": _pace,
		"effective_time_scale": speed,
		"return_progress": clampf(_return_elapsed / walk, 0.0, 1.0) if walk > EPSILON else (1.0 if _phase == "sheltered" else 0.0),
		"return_seconds_remaining": return_left / speed,
		"walk_sim_seconds": walk,
		"departure_sim_seconds": _departure_time,
		"arrival_sim_seconds": _arrival_time,
		"latest_departure_sim_seconds": float(_settings.warning_seconds) - walk,
		"return_slack_seconds": (sim_left - return_left) / speed,
		"can_return_on_time": sim_left + EPSILON >= return_left,
		"crew_sheltered": _phase == "sheltered",
		"spare_power_points": _spare_points(),
		"power_margin_sols": _margin_sols(),
		"dose_ugy": _dose_rate_per_second() * _sim_elapsed,
		"dose_rate_ugy_per_hour": _dose_rate_per_second() * 3600.0,
		"sections_needed": maxi(0, needed_total - _sections),
		"max_additional_sections": additional,
		"assumptions": _settings.duplicate(true),
		"events": _events.duplicate(true),
		"history": _history.duplicate(true),
	})
	return answer

func plan_for_sections(count: int, speed_override: float = -1.0) -> Dictionary:
	if count < 0 or count > int(_settings.max_sections): return {"valid": false, "reason": "Section count is outside this scenario."}
	if not is_finite(speed_override) or (speed_override != -1.0 and (speed_override < 0.05 or speed_override > 3.0)):
		return {"valid": false, "reason": "Walking speed must be positive and within this scenario's range."}
	var walking_speed := float(_settings.walking_speed_mps) if speed_override == -1.0 else speed_override
	var walk := _walk_seconds(walking_speed)
	var outside := walk + float(count) * float(_settings.section_work_seconds)
	var margin := (float(_settings.initial_spare_power_points) + float(_settings.gain_per_section_points) * count) / float(_settings.dust_loss_points_per_sol)
	var on_time := outside <= float(_settings.warning_seconds) + EPSILON
	var powered := margin >= float(_settings.target_margin_sols) - EPSILON
	return {
		"valid": true,
		"sections_cleaned": count,
		"walking_speed_mps": walking_speed,
		"walk_sim_seconds": walk,
		"outside_sim_seconds": outside,
		"play_seconds": outside / (float(_settings.time_scale) * _pace),
		"power_margin_sols": margin,
		"dose_ugy": _dose_rate_per_second() * minf(outside, float(_settings.warning_seconds)),
		"dose_duration_sim_seconds": minf(outside, float(_settings.warning_seconds)),
		"on_time": on_time,
		"margin_target_met": powered,
		"status": "late" if not on_time else ("success" if powered else "power-shortfall"),
		"max_sections_before_deadline": clampi(int(floor((float(_settings.warning_seconds) - walk) / float(_settings.section_work_seconds) + EPSILON)), 0, int(_settings.max_sections)),
		"minimum_sections_for_margin": maxi(0, int(ceil((float(_settings.target_margin_sols) * float(_settings.dust_loss_points_per_sol) - float(_settings.initial_spare_power_points)) / float(_settings.gain_per_section_points) - EPSILON))),
		"latest_departure_sim_seconds": float(_settings.warning_seconds) - walk,
		"latest_departure_play_seconds": (float(_settings.warning_seconds) - walk) / (float(_settings.time_scale) * _pace),
		"scope": "Hypothetical clean-then-return plan from mission start, without idle time. Dose is accumulated only until arrival or the round deadline; no post-warning radiation forecast is made.",
	}

func result() -> Dictionary:
	var answer := snapshot()
	var comparisons: Array[Dictionary] = []
	for count in range(int(_settings.max_sections) + 1): comparisons.append(plan_for_sections(count))
	answer["comparisons"] = comparisons
	answer["equations"] = {
		"return": "return time = distance ÷ walking speed",
		"outside": "time outside = cleaning time + return time + any waiting",
		"margin": "output-margin horizon = (starting margin + gain × completed sections) ÷ assumed dust trend",
		"dose": "absorbed dose = historical reference dose rate × time outside",
	}
	answer["safety_note"] = "Mission targets are fictional planning goals. The model does not calculate injury, death, medical risk, or personal sievert dose."
	return answer
