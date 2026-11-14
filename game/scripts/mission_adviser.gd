extends RefCounted
## Synchronous, main-thread, local counterfactual preview. Never applies actions.
## Every branch executes the actual Mission.step equations from the same state.
const Mission = preload("res://scripts/mission.gd")
const MAX_HORIZON_HOURS := 2.0
const OPTIONS := [
	{"id": "normal_off", "label": "Normal work · cleaner off", "conserving": false, "cleaning": false},
	{"id": "normal_on", "label": "Normal work · cleaner on", "conserving": false, "cleaning": true},
	{"id": "conserve_off", "label": "Save power · cleaner off", "conserving": true, "cleaning": false},
	{"id": "conserve_on", "label": "Save power · cleaner on", "conserving": true, "cleaning": true}
]
const ASSUMPTIONS := [
	"This previews the game's scripted weather, not a live NASA forecast or a learned AI model.",
	"Every option starts from your current mission state. Settings stay fixed for the preview.",
	"You stay where you are. No new inspection work occurs. Your visor setting stays unchanged.",
	"Each run stops at an abort or mission end. Compare duration as well as battery; shorter failed runs are not better plans.",
	"Saving power reduces optional research. Essential life support still needs power in both modes. No single score combines safety, work and energy.",
	"The preview does not plan a walking route or guarantee safe arrival. Model limits and equipment values are illustrative."
]
# A private reusable model avoids disk reads and repeated object construction for
# each option. No references to it escape. Analyze contains no awaits or callbacks.
static var _projection: VeilMission

static func _copy_state(source: VeilMission, target: VeilMission) -> void:
	# Reflect script variables so new scenario parameters are not silently missed.
	# Mission currently contains scalar values and a baseline Dictionary only.
	for property in source.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = source.get(property.name)
			if value is Dictionary or value is Array: value = value.duplicate(true)
			target.set(property.name, value)

static func analyze(mission: VeilMission, horizon_hours: float = 1.0) -> Dictionary:
	if _projection == null: _projection = Mission.new()
	if not is_finite(horizon_hours): horizon_hours = 1.0
	var horizon := minf(clampf(horizon_hours, Mission.STEP_HOURS, MAX_HORIZON_HOURS), maxf(0.0, Mission.DURATION - mission.time))
	var result := {
		"heading": "AEGIS · COMPARE A PLAN",
		"source_time_hours": mission.time,
		"initial_habitat_kwh": mission.energy,
		"habitat_capacity_kwh": Mission.CAPACITY,
		"initial_suit_kwh": mission.suit_energy,
		"initial_dose_msv": mission.dose,
		"horizon_hours": horizon,
		"summary": "Compare what each fixed setting does. You remain in command.",
		"safety_note": "",
		"assumptions": ASSUMPTIONS.duplicate(),
		"options": [],
		"recommendation": {"cleaning": "not_comparable", "conservation": "not_comparable"},
		"active": mission.status == "running" and horizon > 0.0
	}
	if not result.active:
		result.summary = "This mission has ended. Review its result or start another plan."
		return result
	var target_time := mission.time + horizon
	for option in OPTIONS:
		_copy_state(mission, _projection)
		_projection.conserving = option.conserving
		_projection.cleaning = option.cleaning
		while _projection.status == "running" and _projection.time < target_time - 0.000000001:
			_projection.step(minf(Mission.STEP_HOURS, target_time - _projection.time), false)
		var outcome: Dictionary = option.duplicate()
		outcome.merge({
			"current": mission.conserving == option.conserving and mission.cleaning == option.cleaning,
			"elapsed_hours": _projection.time - mission.time,
			"reaches_horizon": _projection.time >= target_time - 0.000001,
			"habitat_kwh": _projection.energy,
			"habitat_change_kwh": _projection.energy - mission.energy,
			"suit_kwh": _projection.suit_energy,
			"dose_msv": _projection.dose,
			"dose_added_msv": _projection.dose - mission.dose,
			"panel_dust": _projection.dust,
			"research_gained": _projection.research - mission.research,
			"generated_kwh": _projection.generated - mission.generated,
			"consumed_kwh": _projection.consumed - mission.consumed,
			"status": _projection.status
		})
		result.options.append(outcome)
	var options: Array = result.options
	var base := 2 if mission.conserving else 0
	var off: Dictionary = options[base]
	var on: Dictionary = options[base + 1]
	# Isolate one decision at a time; do not rank aborted runs against full ones.
	if off.reaches_horizon and on.reaches_horizon:
		var cleaning_gain: float = on.habitat_kwh - off.habitat_kwh
		result.recommendation.cleaning_energy_difference_kwh = cleaning_gain
		if cleaning_gain > 0.01:
			result.recommendation.cleaning = "on"
			result.summary = "With the same work setting, cleaning leaves %.2f kWh more battery over this preview. It removes panel dust, not dust in the sky." % cleaning_gain
		elif cleaning_gain < -0.01:
			result.recommendation.cleaning = "off"
			result.summary = "With the same work setting, leaving the cleaner off preserves %.2f kWh more battery over this preview. Cleaning now costs more power than it recovers in this time." % -cleaning_gain
		else:
			result.recommendation.cleaning = "similar"
			result.summary = "Both cleaner settings leave nearly the same battery over this preview. Compare panel dust and work too; timing can change the result."
	var normal: Dictionary = options[1 if mission.cleaning else 0]
	var conserve: Dictionary = options[3 if mission.cleaning else 2]
	if normal.reaches_horizon and conserve.reaches_horizon:
		result.recommendation.conservation = "tradeoff"
		result.recommendation.conservation_energy_difference_kwh = conserve.habitat_kwh - normal.habitat_kwh
		result.recommendation.conservation_research_difference = conserve.research_gained - normal.research_gained
		result.summary += " Compare the work estimate too. Both modes still use power for essential life support."
	var current: Dictionary = options[(2 if mission.conserving else 0) + (1 if mission.cleaning else 0)]
	if not mission.shelter:
		if mission.time >= mission.event_start and mission.time < mission.event_end:
			result.safety_note = "Particle event active in this scenario: go to the marked refuge. Panel cleaning and a clear visor do not block radiation."
		elif mission.suit_energy < 0.16 or current.status == "suit-abort":
			result.safety_note = "Your suit uses its own battery. Plan your return to the refuge now; saving habitat power cannot refill your suit."
		elif mission.event_start >= mission.time and mission.event_start <= target_time:
			result.safety_note = "A particle event is scheduled soon in this scenario. Reach the refuge before it starts; this preview assumes you stay where you are."
		elif current.status == "dose-abort":
			result.safety_note = "Staying here reaches the scenario's dose-abort limit. Move toward the refuge; a battery comparison is not a safety guarantee."
	var full_options := 0
	for option in options:
		if option.reaches_horizon: full_options += 1
	if full_options == 0:
		result.summary = "None of these fixed settings reaches the preview end. Compare how long each run lasts and why it stops. These choices alone do not provide a safe plan."
	elif not current.reaches_horizon:
		result.summary = "Your current fixed settings stop before the preview ends (%s). Compare the other options and their durations. " % str(current.status) + result.summary
	return result
