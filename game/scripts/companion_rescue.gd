extends RefCounted
## Deterministic teaching scenario, not certified navigation or airlock physics.
## Positions are metres; time shares Mission's simulated hours.
const START := Vector3(0, 0, 7)
const ROUTE := [Vector3(-7.15, 0, -5.5), Vector3(-7.15, 0, -9.23), Vector3(-7.15, 0, -11.4)]
const INDOOR_RECEIVER := Vector3(-7.15, 0, -13.0)
const WALK_METRES_PER_HOUR := 60.0
const AIRLOCK_HOURS := 0.15
var position := START
var phase := "waiting"
var waypoint := 0
var cycle_hours := 0.0
var elapsed_hours := 0.0
var stop_reason := ""

func request_return() -> bool:
	if phase != "waiting": return false
	phase = "walking"
	return true

func advance(hours: float) -> void:
	if not is_finite(hours) or hours <= 0 or phase not in ["walking", "cycling", "entering"]: return
	var remaining_time := hours
	while remaining_time > 0.000000001 and phase in ["walking", "cycling", "entering"]:
		if phase == "cycling":
			var used := minf(remaining_time, AIRLOCK_HOURS - cycle_hours)
			cycle_hours += used
			remaining_time -= used
			if cycle_hours >= AIRLOCK_HOURS - 0.0000001: phase = "entering"
		else:
			var target: Vector3 = INDOOR_RECEIVER if phase == "entering" else ROUTE[waypoint]
			var travel_time := position.distance_to(target) / WALK_METRES_PER_HOUR
			if remaining_time < travel_time:
				position = position.move_toward(target, remaining_time * WALK_METRES_PER_HOUR)
				remaining_time = 0
			else:
				position = target
				remaining_time -= travel_time
				if phase == "entering": phase = "protected"
				else:
					waypoint += 1
					if waypoint == ROUTE.size(): phase = "cycling"
	elapsed_hours += hours - remaining_time

func protected() -> bool:
	return phase == "protected"

func halt(reason: String) -> void:
	if not protected():
		phase = "halted"
		stop_reason = reason

func remaining_metres() -> float:
	if phase == "entering": return position.distance_to(INDOOR_RECEIVER)
	if waypoint >= ROUTE.size(): return 0.0
	var result := position.distance_to(ROUTE[waypoint])
	for index in range(waypoint + 1, ROUTE.size()): result += ROUTE[index - 1].distance_to(ROUTE[index])
	return result

func snapshot() -> Dictionary:
	return {"phase": phase, "position_metres": [position.x, position.y, position.z], "remaining_metres": remaining_metres(), "cycle_hours": cycle_hours, "elapsed_hours": elapsed_hours, "stop_reason": stop_reason}
