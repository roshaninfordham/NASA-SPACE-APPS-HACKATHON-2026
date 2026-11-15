extends RefCounted
## Local, deterministic explanation selection. No network, model weights or generated text.
## Pure with respect to the supplied mission snapshot: never changes simulation or progress.

const CONCEPT_IDS := ["radiation", "dose", "sievert", "dust", "power", "time", "speed", "shelter"]
const CATALOG_PATH := "res://data/mission-concepts.json"
static var _catalog: Dictionary = {}

static func _sources() -> Dictionary:
	if not _catalog.is_empty(): return _catalog
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary and parsed.get("concepts") is Array:
		for entry: Variant in parsed.concepts:
			if entry is Dictionary and entry.get("id") in CONCEPT_IDS:
				_catalog[entry.id] = entry.duplicate(true)
	return _catalog

static func _number(state: Dictionary, key: String, minimum := 0.0, maximum := 1000000000.0) -> float:
	var value: Variant = state.get(key)
	if not (value is float or value is int): return NAN
	var number := float(value)
	if not is_finite(number) or number < minimum or number > maximum: return NAN
	return number

static func explain(concept_id: String, snapshot: Dictionary = {}) -> Dictionary:
	var sources := _sources()
	if not concept_id in CONCEPT_IDS or not sources.has(concept_id):
		return {"available": false, "id": concept_id, "provider": "offline-rules", "explanation": "Choose one of the eight mission ideas.", "question": "", "live_reading": "", "source_url": "", "source_label": "", "boundary": "No explanation is inferred for an unknown topic.", "title": "Mission guide"}
	var source: Dictionary = sources[concept_id]
	var result := {
		"available": true, "id": concept_id, "title": str(source.title),
		"provider": "offline-rules", "label": "Offline mission guide · source-based rules",
		"explanation": "", "question": "", "live_reading": "",
		"source_url": str(source.source_url), "source_label": str(source.source_label),
		"boundary": ""
	}
	match concept_id:
		"radiation":
			result.explanation = "Radiation rate tells how quickly absorbed energy arrives. Like heavier rain, a higher rate adds to the total more quickly."
			result.question = "If the rate doubles for the same amount of time, what happens to the added dose?"
			result.boundary = "This rate follows an authored story curve, not live Mars weather; cleaning pace does not change it."
			var rate := _number(snapshot, "radiation_rate_ugy_per_day")
			if is_finite(rate): result.live_reading = "Modeled rate now: %.1f µGy per Earth day" % rate
		"dose":
			result.explanation = "Dose is the total absorbed energy per kilogram. It builds up over time, like water collecting in a bucket."
			result.question = "How is a bucket's filling rate different from the amount already in the bucket?"
			result.boundary = "Completed rounds in this mission share outside duration and dose; faster cleaning does not earn a lower-dose bonus. This is not a medical reading."
			var dose := _number(snapshot, "dose_ugy")
			if is_finite(dose): result.live_reading = "Accumulated model dose: %.2f µGy" % dose
		"sievert":
			result.explanation = "Gray measures absorbed energy. Sievert also needs information about radiation type, and effective dose needs body-tissue weighting."
			result.question = "Why is an absorbed-energy number alone not enough to describe every effect?"
			result.boundary = "This game does not calculate sievert, personal health risk or injury."
			result.live_reading = "Sievert: not calculated"
		"dust":
			result.explanation = "Dust is like a curtain over the solar cells. Cleaning lets more sunlight reach them, which can increase solar power."
			result.question = "If the panel gets cleaner but the habitat uses more power, must the battery fill?"
			result.boundary = "The panel's sections and light-transmission rule are game settings; Pathfinder research supports the dust–light relationship."
			var clean := _number(snapshot, "clean_fraction", 0.0, 1.0)
			if is_finite(clean):
				result.live_reading = "Panel cleaned: %.0f%% · dust remaining: %.0f%%" % [clean * 100.0, (1.0 - clean) * 100.0]
				if clean >= 1.0: result.explanation = "The modeled panel is fully clean. More brushing cannot remove extra dust, but sunlight can still supply power."
		"power":
			result.explanation = "Power is how fast energy flows. The battery stores energy left after the habitat's needs, like a tank with water flowing in and out."
			result.question = "What happens to stored energy when the habitat uses power faster than the panel supplies it?"
			result.boundary = "kW is a rate; kWh is an amount. Hardware ratings and battery capacity are lesson settings."
			var energy := _number(snapshot, "battery_kwh")
			var net := _number(snapshot, "net_power_kw", -1000000000.0)
			var capacity := _number(snapshot, "battery_capacity_kwh")
			if is_finite(energy): result.live_reading = "Stored energy: %.2f kWh" % energy
			if is_finite(net):
				result.live_reading += (" · " if not str(result.live_reading).is_empty() else "") + "Net power: %+.2f kW" % net
				if net < 0.0: result.explanation = "The habitat is asking for more power than the panel supplies. Available stored energy covers the difference until the battery empties."
				elif net > 0.0 and is_finite(energy) and is_finite(capacity) and energy >= capacity:
					result.explanation = "The modeled battery is full. The panel can still make power, but extra energy cannot be stored above its capacity."
		"time":
			result.explanation = "The countdown shows play time left. The science uses a faster mission clock, and both clocks stop while you pause to learn."
			result.question = "Why should a science calculation use mission time rather than the time you spend reading?"
			result.boundary = "The default round is 90 active seconds; accelerated mission time and automatic entry are story choices."
			var left := _number(snapshot, "remaining_seconds")
			var mission_left := _number(snapshot, "sim_remaining_seconds")
			if is_finite(left): result.live_reading = "Play time left: %.0f s" % left
			if is_finite(mission_left): result.live_reading += (" · " if not str(result.live_reading).is_empty() else "") + "Mission time left: %.1f min" % (mission_left / 60.0)
		"speed":
			result.explanation = "The pace control is a request, not a promise of completed work. Our invented tiredness rule can make a fast command less effective."
			result.question = "Try a steady pace and a fast pace: which clears more, and what happens to tiredness?"
			result.boundary = "Pace and tiredness are authored game rules, not measured astronaut physiology."
			var selected := _number(snapshot, "selected_multiplier", 0.0, 10.0)
			var actual := _number(snapshot, "cleaning_rate_sections_per_minute")
			if is_finite(selected): result.live_reading = "Requested pace: %.2f×" % selected
			if is_finite(actual): result.live_reading += (" · " if not str(result.live_reading).is_empty() else "") + "Actual work rate: %.3f sections/min" % actual
		"shelter":
			result.explanation = "Walls and surrounding material can change radiation exposure. Some particles still get through, so coming inside does not mean radiation becomes zero."
			result.question = "Why does ending our outside-dose counter not prove there is no radiation indoors?"
			result.boundary = "Ren enters automatically at the deadline; this mission has no walking distance, recall decision or certified shelter factor."
			if snapshot.get("crew_sheltered") is bool: result.live_reading = "Ren: inside" if snapshot.crew_sheltered else "Ren: beside the shelter"
	return result
