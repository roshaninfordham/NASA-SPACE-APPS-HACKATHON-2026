extends RefCounted
## Optical framing only: keep the operator inside the room while the close-up
## crew and array fit the actual unobstructed part of each screen. An asymmetric
## perspective frustum avoids stretching geometry or placing it under controls.
const NEAR := 0.05
const FAR := 400.0
# Seated operator height reveals the distant dune skyline above the array.
# The adaptive lens still keeps the actual work large on every viewport.
const EYE_FROM_CREW := Vector3(1.25, 1.20, -3.8)
const AIM_FROM_CREW := Vector3(1.20, 0.80, 0.0)
# Includes the planted boots, helmet, brush sweep and all edges of the 2.4 m array.
const WORK_BOUNDS := AABB(Vector3(-0.42, 0.0, -0.76), Vector3(3.50, 1.70, 1.52))

static func frame(camera: Camera3D, crew_origin: Vector3, viewport_size: Vector2, work_rect: Rect2) -> bool:
	if not is_instance_valid(camera) or not camera.is_inside_tree(): return false
	if not viewport_size.is_finite() or viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or not crew_origin.is_finite(): return false
	if not work_rect.position.is_finite() or not work_rect.size.is_finite(): return false
	var available := work_rect.intersection(Rect2(Vector2.ZERO, viewport_size)).grow(-8.0)
	if available.size.x < 32.0 or available.size.y < 32.0: return false
	camera.global_position = crew_origin + EYE_FROM_CREW
	camera.look_at(crew_origin + AIM_FROM_CREW, Vector3.UP)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var near_min := Vector2(INF, INF)
	var near_max := Vector2(-INF, -INF)
	for index in range(8):
		var point := camera.to_local(crew_origin + WORK_BOUNDS.get_endpoint(index))
		if point.z >= -NEAR: return false
		var projected := Vector2(point.x, point.y) * (NEAR / -point.z)
		near_min = near_min.min(projected)
		near_max = near_max.max(projected)
	var aspect := viewport_size.x / viewport_size.y
	var fraction := available.size / viewport_size
	var span := near_max - near_min
	var height := maxf(span.y / fraction.y, span.x / (fraction.x * aspect))
	# A little breathing room keeps the brushing head off the panel/rail edges.
	height *= 1.04
	var width := height * aspect
	var near_center := (near_min + near_max) * 0.5
	var screen_center := available.get_center() / viewport_size - Vector2(0.5, 0.5)
	var shift := near_center + Vector2(-screen_center.x * width, screen_center.y * height)
	camera.set_frustum(height, shift, NEAR, FAR)
	return true
