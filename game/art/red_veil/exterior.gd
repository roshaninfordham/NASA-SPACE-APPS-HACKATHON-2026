extends Node3D
const VisualStyle = preload("res://scripts/visual_style.gd")
## Hollow, asymmetric ivory/ruby habitat. Origin: ground center; front: +Z.
const G = preload("res://art/red_veil/exterior_geometry.gd")
const O = preload("res://art/red_veil/exterior_ornaments.gd")
const Details = preload("res://art/red_veil/exterior_details.gd")
const Branding = preload("res://scripts/branding.gd")
@export var pearl_color := VisualStyle.color("pearl")
@export var crimson_color := VisualStyle.color("crimson")
@export var coral_color := VisualStyle.color("coral")
@export var collisions_enabled := true
var pearl: Material
var pearl_inner: Material
var ruby: Material
var dark: Material
var coral: Material
var glass: Material
var metal: Material
const RX := 10.8
const RZ := 7.4

func _ready() -> void:
	pearl = Details.shell_material(pearl_color, false)
	pearl_inner = G.material(Color("bcb8b4"), 0.18, 0.48)
	ruby = Details.shell_material(crimson_color, true)
	dark = G.material(Color("291a24"), 0.45, 0.36)
	coral = G.material(coral_color, 0.12, 0.30, 0.8)
	metal = G.material(Color("645d62"), 0.75, 0.28)
	glass = G.material(Color(0.25, 0.055, 0.10, 0.07), 0.25, 0.12)
	build_hollow_shell()
	build_sweeping_ribbons()
	build_crown()
	build_airlock()
	build_dish_and_antennae()
	build_detail_seams()
	build_ornaments()
	Details.build(self, pearl, ruby, metal, coral, collisions_enabled)
	_build_inspection_anchors()
	if collisions_enabled: build_outer_collisions()
	G.batch_static_meshes(self)

func shell(theta: float, phi: float, offset: float = 0.0) -> Vector3:
	var s := sin(phi)
	var c := cos(phi)
	var lean := s * s
	var x := RX * sin(theta) * c + 0.65 * lean
	var z := RZ * cos(theta) * c - 0.35 * lean
	var y := 0.42 + 6.65 * pow(maxf(s, 0.0), 0.82)
	y += 0.17 * sin(theta + 0.4) * c
	var normal := Vector3(sin(theta) * c, s, cos(theta) * c).normalized()
	return Vector3(x, y, z) + normal * offset

func hole_center(theta: float, kind: String) -> float:
	if kind == "front": return 0.235 - 0.075 * theta
	if kind == "airlock": return 0.17
	return 0.31

func hole_radius(kind: String) -> float:
	if kind == "front": return 0.35
	if kind == "airlock": return 0.34
	return 0.205

func hole_boundary(theta: float, lo: float, hi: float, kind: String, top: bool) -> float:
	var normalized := clampf(2.0 * (theta - lo) / (hi - lo) - 1.0, -1.0, 1.0)
	var swelling := sqrt(maxf(0.0, 1.0 - normalized * normalized))
	# The right almond tip stays thin; the left rises into the shell sweep.
	var asymmetry := 1.0 - 0.13 * normalized if kind == "front" else 1.0
	var extent := hole_radius(kind) * swelling * asymmetry
	return clampf(hole_center(theta, kind) + (extent if top else -extent), 0.0, 1.45)

func shell_patch(title: String, lo: float, hi: float, low: Callable, high: Callable, mat: Material, steps: int = 28, inner: bool = false) -> void:
	G.surface(self, title, steps, 18, func(u: float, v: float) -> Vector3:
		var theta := lerpf(lo, hi, u)
		return shell(theta, lerpf(low.call(theta), high.call(theta), v), -0.19 if inner else 0.0)
	, mat, inner)

func build_hollow_shell() -> void:
	# Window boundaries are analytical curves, not triangles cut from a tessellated sphere.
	var spans := [
		[-PI, -1.82, "solid"], [-1.82, -1.16, "side"],
		[-1.16, -1.12, "solid"], [-1.12, -0.57, "airlock"],
		[-0.57, 0.66, "front"],
		[0.66, 1.08, "solid"], [1.08, 1.79, "side"], [1.79, PI, "solid"]
	]
	for index in range(spans.size()):
		var lo: float = spans[index][0]
		var hi: float = spans[index][1]
		var kind: String = spans[index][2]
		var bottom := func(_theta: float) -> float: return 0.0
		var top := func(_theta: float) -> float: return 1.51
		if kind == "solid":
			shell_patch("PearlShell_%d" % index, lo, hi, bottom, top, pearl)
			shell_patch("InnerShell_%d" % index, lo, hi, bottom, top, pearl_inner, 28, true)
		else:
			var upper := func(theta: float) -> float: return hole_boundary(theta, lo, hi, kind, true)
			var lower := func(theta: float) -> float: return hole_boundary(theta, lo, hi, kind, false)
			shell_patch("SweptWindowBrow_%d" % index, lo, hi, upper, top, pearl, 44)
			shell_patch("SweptWindowInnerBrow_%d" % index, lo, hi, upper, top, pearl_inner, 44, true)
			if kind != "airlock":
				shell_patch("WindowSill_%d" % index, lo, hi, bottom, lower, pearl, 44)
				window_rim(lo, hi, kind, index)
				# Recessed, almost clear glazing keeps the central globe visible.
				G.surface(self, "RecessedRubyGlazing_%d" % index, 44, 15, func(u: float, v: float) -> Vector3:
					var theta := lerpf(lo, hi, u)
					return shell(theta, lerpf(lower.call(theta), upper.call(theta), v), -0.13)
				, glass)
	# Raised foundation is visual only; the world/interior own the level walkable floor.
	G.surface(self, "LowPearlFoundation", 128, 5, func(u: float, v: float) -> Vector3:
		var theta := TAU * u
		var bulge := 0.15 * sin(PI * v)
		return Vector3((10.64 + bulge) * sin(theta), 0.05 + 0.32 * v, (7.26 + bulge) * cos(theta))
	, pearl_inner)

func window_rim(lo: float, hi: float, kind: String, index: int) -> void:
	for upper in [false, true]:
		var points := PackedVector3Array()
		var inset := PackedVector3Array()
		for step in range(81):
			var theta := lerpf(lo, hi, float(step) / 80)
			var phi := hole_boundary(theta, lo, hi, kind, upper)
			points.append(shell(theta, phi, 0.045))
			inset.append(shell(theta, phi, -0.07))
		G.tube(self, "SculptedApertureLip_%d_%s" % [index, upper], points, 0.12 if kind == "front" else 0.09, pearl)
		G.tube(self, "CoralApertureLight_%d_%s" % [index, upper], inset, 0.028, coral, 8)

func build_sweeping_ribbons() -> void:
	# Broad diagonal ribbons are deliberately asymmetric, with no geodesic grid.
	G.surface(self, "DeepCrimsonDiagonalRecess", 128, 7, func(u: float, v: float) -> Vector3:
		var theta := -PI + TAU * u
		var middle := 0.82 + 0.14 * sin(theta + 0.65) + 0.05 * sin(2.0 * theta)
		return shell(theta, middle + (v - 0.5) * 0.20, 0.018)
	, ruby)
	for edge in [-1.0, 1.0]:
		var points := PackedVector3Array()
		for index in range(145):
			var theta := -PI + TAU * index / 144
			var middle := 0.82 + 0.14 * sin(theta + 0.65) + 0.05 * sin(2.0 * theta)
			points.append(shell(theta, middle + edge * 0.103, 0.035))
		G.tube(self, "RubyRecessPearlEdge_%s" % edge, points, 0.055, pearl)
	# A second large flowing blade crosses the first ribbon near the starboard shoulder.
	G.surface(self, "OverlappingPearlBlade", 82, 8, func(u: float, v: float) -> Vector3:
		var theta := lerpf(-0.48, 2.92, u)
		var center := 0.64 + 0.35 * pow(sin(PI * u), 1.3)
		var width := 0.055 + 0.09 * sin(PI * u)
		return shell(theta, center + (v - 0.5) * width, 0.12 + 0.10 * sin(PI * u))
	, pearl)
	var lower_light := PackedVector3Array()
	for index in range(97):
		var theta := lerpf(0.82, 2.95, float(index) / 96)
		lower_light.append(shell(theta, 0.14 + 0.075 * sin(theta), 0.025))
	G.tube(self, "StarboardLowServiceRibbon", lower_light, 0.035, coral, 8)

func crown_point(angle: float, radius: float, height: float) -> Vector3:
	return Vector3(0.65 + 4.65 * radius * cos(angle), height, -0.35 + 2.9 * radius * sin(angle))

func build_crown() -> void:
	G.surface(self, "LayeredPlateauCrown", 112, 12, func(u: float, v: float) -> Vector3:
		var radius := v
		var height := 7.22 + 0.28 * pow(1.0 - radius * radius, 0.8)
		return crown_point(TAU * u, radius, height)
	, pearl)
	G.surface(self, "NarrowCrimsonCrownInset", 112, 4, func(u: float, v: float) -> Vector3:
		return crown_point(TAU * u, 1.0 - 0.025 * sin(PI * v), 7.08 + 0.15 * v)
	, ruby)
	G.surface(self, "CrownUndercut", 112, 5, func(u: float, v: float) -> Vector3:
		var angle := TAU * u
		var upper := crown_point(angle, 1.0, 7.08)
		var horizontal := Vector2((upper.x - 0.65) / RX, (upper.z + 0.35) / RZ)
		var phi := acos(clampf(horizontal.length(), 0.0, 1.0))
		var lower := shell(atan2(horizontal.x, horizontal.y), phi, 0.02)
		return lower.lerp(upper, v)
	, pearl_inner)
	var rim := PackedVector3Array()
	for index in range(129): rim.append(crown_point(TAU * index / 128, 0.997, 7.11))
	G.tube(self, "CrownWarmRunningLight", rim, 0.025, coral, 8)

func build_airlock() -> void:
	var center := Vector3(-7.15, 1.95, 5.95)
	# Open collar, not a solid cylinder: the walking path remains physically clear.
	G.surface(self, "AirlockSculptedCollar", 80, 14, func(u: float, v: float) -> Vector3:
		var angle := TAU * u
		var flare := 0.14 * sin(PI * v)
		return center + Vector3((1.55 + flare) * cos(angle), 1.92 * sin(angle), lerpf(-1.35, 0.66, v))
	, pearl)
	G.surface(self, "AirlockInnerRubyTunnel", 80, 8, func(u: float, v: float) -> Vector3:
		var angle := TAU * u
		return center + Vector3(1.36 * cos(angle), 1.73 * sin(angle), lerpf(-1.28, 0.70, v))
	, ruby, true)
	G.tube(self, "AirlockOuterPearlRim", G.oval_points(center + Vector3(0, 0, 0.67), 1.55, 1.92), 0.16, pearl)
	G.tube(self, "AirlockCoralSeal", G.oval_points(center + Vector3(0, 0, 0.82), 1.36, 1.73), 0.047, coral)
	# Split door leaves are parked visibly to either side, never across the opening.
	for direction in [-1.0, 1.0]:
		G.surface(self, "RetractedAirlockLeaf_%s" % direction, 9, 18, func(u: float, v: float) -> Vector3:
			var y := lerpf(0.28, 3.5, v)
			var bow := 0.12 * sin(PI * v)
			return Vector3(center.x + direction * (1.31 + 0.28 * u + bow), y, center.z + 0.25 + 0.09 * sin(PI * u))
		, pearl_inner)
	# Thin sculpted canopy follows the collar's arch rather than adding a box roof.
	G.surface(self, "FloatingAirlockCanopy", 48, 10, func(u: float, v: float) -> Vector3:
		var angle := lerpf(0.10, PI - 0.10, u)
		return center + Vector3(1.88 * cos(angle), 1.97 * sin(angle) + 0.18, lerpf(0.05, 1.02, v) - 0.16 * sin(PI * v))
	, pearl)
	G.label(self, "AirlockWayfinding", Branding.title() + "  /  HABITAT 01", Vector3(-7.15, 4.24, 6.17), 66, Color("f4dac7"))
	var light := OmniLight3D.new()
	light.name = "AirlockWarmBounce"
	light.position = center + Vector3(0, 0, 1.2)
	light.light_color = coral_color
	light.light_energy = 1.0
	light.omni_range = 5.5
	light.shadow_enabled = false
	add_child(light)

func build_dish_and_antennae() -> void:
	var mount := Vector3(5.5, 6.05, -2.1)
	G.bar(self, "DishSupport", mount, mount + Vector3(0, 0.85, 0), 0.14, metal)
	var center := mount + Vector3(0, 0.85, 0)
	var normal := Vector3(-0.10, 0.82, 0.56).normalized()
	var horizontal := Vector3.RIGHT
	var vertical := normal.cross(horizontal).normalized()
	G.surface(self, "ParabolicIvoryDish", 64, 12, func(u: float, v: float) -> Vector3:
		var radius := 1.2 * v
		var angle := TAU * u
		return center + radius * (cos(angle) * horizontal + sin(angle) * vertical) + normal * (0.34 * radius * radius)
	, pearl, true)
	var rim := PackedVector3Array()
	for index in range(81):
		var angle := TAU * index / 80
		rim.append(center + 1.2 * (cos(angle) * horizontal + sin(angle) * vertical) + normal * 0.4896)
	G.tube(self, "DishRubyRim", rim, 0.045, ruby, 8)
	var focus := center + normal * 0.83
	for angle in [0.3, 2.4, 4.5]:
		G.bar(self, "DishFeedStrut", center + 0.98 * (cos(angle) * horizontal + sin(angle) * vertical) + normal * 0.33, focus, 0.025, metal)
	G.bar(self, "DishFeedHead", focus - normal * 0.12, focus + normal * 0.08, 0.11, ruby)
	for index in range(3):
		var point := Vector3(1.8 + index * 0.34, 7.30, -1.2 - index * 0.35)
		var height := 2.10 - index * 0.58
		G.bar(self, "AntennaMast_%d" % index, point, point + Vector3(0, height, 0), 0.028, metal)
		G.bar(self, "AntennaCoralTip_%d" % index, point + Vector3(0, height - 0.07, 0), point + Vector3(0, height, 0), 0.038, coral)

func build_detail_seams() -> void:
	# Sparse curved service seams belong to the authored shell, never a spherical grid.
	for index in range(5):
		var points := PackedVector3Array()
		for step in range(41):
			var t := float(step) / 40
			var theta := 1.9 + index * 0.13 + 0.22 * sin(PI * t)
			points.append(shell(theta, 0.28 + 0.30 * t, 0.014))
		G.tube(self, "RubyServiceVein_%d" % index, points, 0.013, ruby, 6)
	for index in range(7):
		var t := float(index) / 6
		var theta := lerpf(0.84, 1.03, t)
		var point := shell(theta, 0.28, 0.07)
		G.bar(self, "WarmStatusVent_%d" % index, point, point + Vector3(0, 0.24, 0), 0.018, coral)

func build_outer_collisions() -> void:
	for index in range(72):
		var lo := -PI + TAU * index / 72
		var hi := -PI + TAU * (index + 1) / 72
		var theta := (lo + hi) * 0.5
		if theta > -1.06 and theta < 0.72: continue
		var a := Vector3(10.57 * sin(lo), 0, 7.18 * cos(lo))
		var b := Vector3(10.57 * sin(hi), 0, 7.18 * cos(hi))
		var tangent := b - a
		G.collision_box(self, "OuterWallCollider_%d" % index, (a + b) * 0.5 + Vector3(0, 1.9, 0), Vector3(tangent.length() + 0.06, 3.8, 0.34), -atan2(tangent.z, tangent.x))

func build_ornaments() -> void:
	var gold := G.material(VisualStyle.color("rose_gold"), VisualStyle.number("gold_metallic"), VisualStyle.number("gold_roughness"), 0.18)
	var peach := G.material(Color("f2c3a7"), 0.42, 0.38)
	var lantern_glow := G.material(Color("ffd09a"), 0.05, 0.54, 0.65)
	# Real contour-following raised engraving; one batched mesh per panel.
	O.wave_patch(self, "GoldSeigaihaFrontBrow", func(u: float, v: float) -> Vector3:
		var theta := lerpf(-0.50, 0.70, u)
		var lower := hole_boundary(theta, -0.57, 0.66, "front", true) + 0.024
		var upper := 0.82 + 0.14 * sin(theta + 0.65) + 0.05 * sin(2.0 * theta) - 0.13
		return shell(theta, lerpf(lower, maxf(lower + 0.04, upper), v), 0.028)
	, 3, 15, gold)
	O.wave_patch(self, "GoldSeigaihaStarboard", func(u: float, v: float) -> Vector3:
		var theta := lerpf(0.74, 1.04, u)
		return shell(theta, lerpf(0.10, 0.70, v), 0.03)
	, 5, 5, gold)
	# Amber lattice wraps the crown and the upper almond edge without glazing the opening.
	var lattice: Array = []
	for index in range(100):
		var angle := TAU * index / 100
		lattice.append(PackedVector3Array([crown_point(angle, 1.004, 7.07), crown_point(angle + 0.025, 1.004, 7.25)]))
	for index in range(54):
		var theta := lerpf(-0.54, 0.63, index / 53.0)
		var edge := hole_boundary(theta, -0.57, 0.66, "front", true)
		lattice.append(PackedVector3Array([shell(theta, edge + 0.008, 0.12), shell(theta + 0.012, edge + 0.048, 0.12)]))
	O.strokes(self, "AmberCrownAndWindowLattice", lattice, 0.018, gold)
	for theta in [-0.35, 0.25, 0.85]:
		var phi := 0.82 + 0.14 * sin(theta + 0.65) + 0.05 * sin(2.0 * theta)
		var branch := O.blossom_branch(self, "RubyBandBlossom_%s" % theta, shell(theta, phi, 0.07), 0.72, gold, peach)
		branch.rotation.y = theta
		branch.rotation.x = -phi * 0.70
	# The geometric key pattern sits outside the free opening.
	var key_paths: Array = []
	var center := Vector3(-7.15, 1.95, 6.65)
	for index in range(28):
		var a := TAU * index / 28
		var step := TAU / 28 * 0.58
		var points := PackedVector3Array()
		for offset in [Vector2(0, 0), Vector2(step, 0), Vector2(step, -0.08), Vector2(step * 0.45, -0.08), Vector2(step * 0.45, -0.035)]:
			points.append(center + Vector3((1.52 + offset.y) * cos(a + offset.x), (1.87 + offset.y) * sin(a + offset.x), 0))
		key_paths.append(points)
	O.strokes(self, "GoldAirlockGeometricKey", key_paths, 0.018, gold)
	for side in [-1.0, 1.0]:
		O.square_lantern(self, "AirlockLantern_%s" % side, Vector3(-7.15 + side * 1.92, 2.15, 6.25), 0.85, lantern_glow, gold)
	# Small eight-petal rosette above the portal, leaving the entire walking path clear.
	var petals: Array = []
	for petal in range(8):
		var points := PackedVector3Array()
		for step in range(25):
			var a := TAU * step / 24
			var b := TAU * petal / 8
			points.append(Vector3(-7.15, 4.13, 6.05) + Vector3(cos(b) * (0.12 + 0.11 * cos(a)) - sin(b) * 0.045 * sin(a), sin(b) * (0.12 + 0.11 * cos(a)) + cos(b) * 0.045 * sin(a), 0))
		petals.append(points)
	O.strokes(self, "AirlockGoldRosette", petals, 0.012, gold)

## Presentation anchors share the habitat transform; callers never hard-code world positions.
## These are science explanations, not claims that this alpha simulates pressure or shielding.
func _build_inspection_anchors() -> void:
	var data := [
		["habitat_dome", "HABITAT DOME", Vector3(5.6, 5.8, 1.4), "A habitat needs an airtight pressure vessel, insulation and dust protection. Shielding depends on material, thickness and particle energy; decorative lacquer is not a radiation shield."],
		["observation_windows", "OBSERVATION WINDOWS", Vector3(8.7, 2.6, 2.8), "Layered glazing lets a crew look outside. A real habitat also needs pressure-rated seals and engineered shutters. The viewing openings here are an art-development walkthrough, not a sealed pressure simulation."],
		["regolith_shielding", "REGOLITH SHIELDING", Vector3(12.0, 1.6, -1.8), "Regolith is the loose dust and rock on Mars. A thick layer can help reduce radiation exposure and slow temperature changes. Protection is not a fixed percentage for every extra layer."],
		["airlock", "AIRLOCK", Vector3(-7.15, 2.7, 6.8), "A real airlock uses two sealed doors and a pressure cycle to protect the habitat atmosphere. This alpha keeps the entry open for exploring; its doors do not yet simulate a pressure cycle."]
	]
	for item in data:
		var anchor := Marker3D.new()
		anchor.name = "Inspect_" + item[0]
		anchor.position = item[2]
		anchor.set_meta("inspection_id", item[0])
		anchor.set_meta("inspection_title", item[1])
		anchor.set_meta("inspection_text", item[3])
		add_child(anchor)

func get_inspection_points() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child in get_children():
		if child is Marker3D and child.has_meta("inspection_id"):
			result.append({"id": child.get_meta("inspection_id"), "title": child.get_meta("inspection_title"), "text": child.get_meta("inspection_text"), "position": child.global_position})
	return result
