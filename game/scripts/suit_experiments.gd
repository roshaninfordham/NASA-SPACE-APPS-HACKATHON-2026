extends RefCounted
## Deterministic teaching models, deliberately separate from mission simulation.
## Units and assumptions are shown by the lab. These are not suit certification data.
const NAMES := ["Radiation", "Dust", "Thermal", "Life support", "Pressure fit"]
const QUESTIONS := [
	"A particle alert arrives. How long will you stay outside before reaching shelter?",
	"Dust covers a test panel. How many cleaning passes will you try?",
	"A test plate loses 60 watts of heat. How much heater power balances it?",
	"Your practice supply holds 120 oxygen units. How hard will you work?",
	"An adjustable mock seal is loose. Find a fit that seals without squeezing."
]
const UNITS := ["minutes outside", "cleaning passes", "heater watts", "oxygen units / minute", "fit setting"]
const RANGES := [[0,60,30], [0,5,0], [0,120,30], [1,6,2], [0,100,25]]

static func evaluate(index: int, value: float) -> Dictionary:
	index = clampi(index, 0, 4)
	var limits: Array = RANGES[index]
	value = clampf(value, float(limits[0]), float(limits[1]))
	match index:
		0:
			# Illustrative event rate; exposure = rate × elapsed time.
			var dose := 1.8 * value / 60.0
			return {"result": "Dose before shelter: %.2f mSv" % dose, "value": dose, "success": value <= 10,
				"why": "At this example rate of 1.8 mSv/hour, dose = rate × time. A shorter trip means less exposure. Reach the storm shelter promptly; suit colour and embroidery do not shield radiation."}
		1:
			var remaining := 100.0 * pow(0.6, value)
			return {"result": "Dust remaining: %.1f%%" % remaining, "value": remaining, "success": remaining < 25,
				"why": "This toy cleaner removes 40% of the remaining dust each pass: 100 × 0.6^passes. It never removes 40 percentage points every time. Real dust removal depends on equipment and conditions."}
		2:
			var net := value - 60.0
			return {"result": "Net heat flow: %+.0f W" % net, "value": net, "success": absf(net) <= 5,
				"why": "Net heat = heater input − heat loss. Near 0 watts the plate balances; positive warms it, negative cools it. A real spacesuit also needs cooling, insulation and careful engineering."}
		3:
			var minutes := 120.0 / value
			return {"result": "Practice supply lasts: %.0f minutes" % minutes, "value": minutes, "success": minutes >= 40,
				"why": "Duration = 120 supply units ÷ units used per minute. Harder work uses oxygen faster. These are practice units, not a claim that a real suit lasts this long. Keep a return reserve."}
		_:
			var fit := 100.0 - absf(value - 50.0) * 2.0
			var state := "Balanced" if value >= 45 and value <= 55 else ("Loose — seal gap" if value < 45 else "Tight — restricted movement")
			return {"result": state, "value": fit, "success": value >= 45 and value <= 55,
				"why": "This mock fitting scale illustrates a tradeoff: a loose seal can leak; overtightening restricts motion. It does not set real suit pressure. Actual pressure suits require qualified testing."}
