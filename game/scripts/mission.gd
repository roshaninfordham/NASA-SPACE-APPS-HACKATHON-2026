class_name VeilMission
extends RefCounted
## Units: hours, kW, kWh, mSv. All hardware values are educational assumptions.
const CAPACITY := 12.0
const ESSENTIAL_KW := 0.55
const SUIT_LIFE_SUPPORT_KW := 0.12
const STEP_HOURS := 1.0 / 120.0
const HOURS_PER_SECOND := 0.05
const DURATION := 12.0
const DOSE_LIMIT := 4.0
const RECOVERY_KWH := 2.4
var time := 0.0
var energy := 8.0
var suit_energy := 0.9
var dose := 0.0
var dust := 0.28
var visor_dust := 0.25
var inspection := 0.0
var shelter := false
var cleaning := false
var conserving := false
var visor_cleaning := false
var status := "running"
var research := 0.0
var generated := 0.0
var consumed := 0.0
var background_dose := 0.67
var baseline: Dictionary = {}
var event_start := 4.0
var event_end := 7.0
var peak_tau := 2.8

func _init() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/nasa-observations.json"))
	background_dose = float(source.observations[0].value)

func environment() -> Dictionary:
	var storm := pow(sin(PI * clampf((time - 1.0) / 10.0, 0.0, 1.0)), 2.0)
	var tau := 0.25 + peak_tau * storm
	var mu := 0.65 + 0.35 * sin(PI * time / DURATION)
	var transmission := exp(-tau / mu)
	var event := time >= event_start and time < event_end
	var solar := 4.8 * (0.75 + 0.25 * inspection) * transmission * (1.0 - dust)
	var load_kw := ESSENTIAL_KW + (0.12 if conserving else 0.75) + (0.9 if cleaning else 0.0)
	return {"storm": storm, "tau": tau, "transmission": transmission, "event": event, "solar": solar, "load": load_kw, "net": solar - load_kw, "dose_rate": (background_dose / 24.0 + (1.8 if event else 0.0)) * (0.15 if shelter else 1.0)}

func step(dt: float = STEP_HOURS, inspecting: bool = false) -> void:
	assert(dt > 0.0 and dt <= 0.1)
	if status != "running": return
	dt = minf(dt, DURATION - time)
	var env := environment()
	energy = clampf(energy + env.net * dt, 0.0, CAPACITY)
	dose += env.dose_rate * dt
	if not shelter:
		suit_energy = maxf(0.0, suit_energy - (SUIT_LIFE_SUPPORT_KW + (0.04 if visor_cleaning else 0.0)) * dt)
		visor_dust = clampf(visor_dust + (0.03 + env.storm * 0.12 - (0.6 if visor_cleaning else 0.0)) * dt, 0.0, 0.95)
		if inspecting: inspection = minf(1.0, inspection + (1.0 - visor_dust) * dt / 0.3)
		research += (0.25 if conserving else 1.0) * dt
	dust = clampf(dust + (0.035 * (0.3 + env.storm) - (0.25 if cleaning else 0.0)) * dt, 0.0, 0.95)
	generated += env.solar * dt
	consumed += env.load * dt
	time += dt
	if suit_energy <= 0.0 and not shelter: status = "suit-abort"
	elif energy <= 0.0: status = "power-abort"
	elif dose >= DOSE_LIMIT: status = "dose-abort"
	elif time >= DURATION - 0.000001: status = "success" if energy >= RECOVERY_KWH else "partial"

func summary() -> Dictionary:
	return {"time_hours": time, "habitat_kwh": energy, "suit_kwh": suit_energy, "dose_msv": dose, "inspection": inspection, "status": status, "generated_kwh": generated, "consumed_kwh": consumed}

static func fixed_baseline() -> Dictionary:
	var run := VeilMission.new()
	run.shelter = true
	run.cleaning = true
	for i in range(1500):
		run.step()
		if run.status != "running": break
	return run.summary()

func visual_snapshot() -> Dictionary:
	var env := environment()
	return {"time_hours": time, "storm": env.storm, "event_active": env.event, "solar_kw": env.solar, "habitat_kwh": energy, "suit_kwh": suit_energy, "dose_msv": dose, "panel_dust": dust, "visor_dust": visor_dust, "inspection": inspection, "sheltered": shelter, "panel_cleaning": cleaning, "visor_cleaning": visor_cleaning, "conserving": conserving, "status": status}
