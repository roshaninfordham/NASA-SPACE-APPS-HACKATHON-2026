extends SceneTree
const Coach = preload("res://scripts/offline_coach.gd")
const Mission = preload("res://scripts/pace_mission.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var model = Mission.new()
	model.advance(20.0)
	var snapshot: Dictionary = model.snapshot()
	var before := snapshot.duplicate(true)
	for id: String in Coach.CONCEPT_IDS:
		var answer: Dictionary = Coach.explain(id, snapshot)
		check(answer.available and answer.id == id, id + " has a constrained explanation")
		check(answer.provider == "offline-rules" and answer.label.contains("source-based rules"), id + " labels its actual implementation")
		check(not answer.explanation.is_empty() and not answer.question.is_empty(), id + " gives a short explanation and investigation question")
		check(answer.source_url.begins_with("https://") and not answer.source_label.is_empty(), id + " retains source attribution")
		check(not answer.boundary.is_empty(), id + " carries the scientific boundary")
		var again: Dictionary = Coach.explain(id, snapshot)
		check(answer == again, id + " is deterministic for unchanged observations")
	check(snapshot == before and model.snapshot() == before, "Explaining does not mutate mission or supplied snapshot")
	var unknown: Dictionary = Coach.explain("invent a fatal dose", snapshot)
	check(not unknown.available and unknown.source_url.is_empty(), "Unknown topic cannot invent a scientific answer")
	check(Coach.explain("power").live_reading.is_empty(), "Missing observations never fabricate a battery reading")
	var poisoned := {"dose_ugy": NAN, "radiation_rate_ugy_per_day": INF, "battery_kwh": "99", "net_power_kw": true, "selected_multiplier": "[url]", "clean_fraction": 2.0, "remaining_seconds": -4.0}
	for id: String in ["dose", "radiation", "power", "speed", "dust", "time"]:
		check(Coach.explain(id, poisoned).live_reading.is_empty(), id + " omits malformed/out-of-range observations")
	var power: Dictionary = Coach.explain("power", {"battery_kwh": 6.0, "battery_capacity_kwh": 6.0, "net_power_kw": 3.0})
	check(power.explanation.contains("full") and power.explanation.contains("cannot be stored"), "Positive net power at capacity does not falsely imply further storage")
	power = Coach.explain("power", {"battery_kwh": 1.5, "net_power_kw": -0.5})
	check(power.explanation.contains("more power than the panel supplies") and power.live_reading.contains("-0.50 kW"), "Energy deficit uses net rate, not invented failure")
	check(Coach.explain("dust", {"clean_fraction": 0.25}).live_reading.contains("75%"), "Dust remaining is derived from actual clean fraction")
	check(Coach.explain("dust", {"clean_fraction": 1.0}).explanation.contains("fully clean"), "Complete cleaning cannot promise extra dust removal")
	check(Coach.explain("speed", {"selected_multiplier": 1.75, "cleaning_rate_sections_per_minute": 0.02}).live_reading.contains("0.020 sections/min"), "Requested multiplier and actual work rate remain distinct")
	check(Coach.explain("time", {"remaining_seconds": 60.0, "sim_remaining_seconds": 1200.0}).live_reading.contains("20.0 min"), "Play time and accelerated mission time have explicit units")
	check(Coach.explain("sievert", {"dose_ugy": 100.0}).live_reading == "Sievert: not calculated", "Absorbed dose never fabricates a sievert conversion")
	check(Coach.explain("sievert").source_url.begins_with("https://www.epa.gov/"), "Sievert definition retains EPA provenance rather than misattributing NASA")
	check(Coach.explain("shelter", {"crew_sheltered": true}).live_reading == "Ren: inside", "Shelter state reflects actual boolean observation")
	check(Coach.explain("shelter").explanation.contains("does not mean radiation becomes zero"), "Shelter explanation avoids a zero-exposure claim")
	var slow = Mission.new()
	var fast = Mission.new()
	slow.set_cleaning_speed(0.5)
	fast.set_cleaning_speed(1.75)
	slow.advance(90.0)
	fast.advance(90.0)
	check(is_equal_approx(slow.snapshot().dose_ugy, fast.snapshot().dose_ugy), "Real completed mission fixtures share final dose across pace choices")
	check(Coach.explain("dose", slow.snapshot()).live_reading == Coach.explain("dose", fast.snapshot()).live_reading, "Coach preserves that invariant instead of claiming a faster-pace dose benefit")
	check(Coach.explain("dose", fast.snapshot()).boundary.contains("share outside duration and dose"), "Dose lesson explicitly explains current mission limit")
	var detached: Dictionary = Coach.explain("dust", snapshot)
	detached.source_url = "changed locally"
	check(Coach.explain("dust", snapshot).source_url.begins_with("https://ntrs.nasa.gov/"), "Caller changes cannot mutate retained source attribution")
	print("Offline coach: ", checks, " checks; ", failures, " failures")
	quit(1 if failures else 0)
