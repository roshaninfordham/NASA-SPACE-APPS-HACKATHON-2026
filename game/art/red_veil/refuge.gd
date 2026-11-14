extends Node3D
## Compact passive shelter. Local protected space is x +/-3.3, z +/-3.5.
## The +Z doorway stays open; mission state and dose calculations live elsewhere.
const G = preload("res://art/red_veil/exterior_geometry.gd")
const O = preload("res://art/red_veil/exterior_ornaments.gd")
const Branding = preload("res://scripts/branding.gd")
@export var collisions_enabled := true
var pearl: Material
var ruby: Material
var earth: Material
var coral: Material
var cyan: Material

func _ready() -> void:
	pearl = G.material(Color("d8d2c9"), 0.22, 0.45)
	ruby = G.material(Color("5f1628"), 0.35, 0.36)
	earth = G.material(Color("6a4c46"), 0.04, 0.92)
	coral = G.material(Color("ff735c"), 0.10, 0.30, 1.6)
	cyan = G.material(Color("e4b57c"), 0.12, 0.30, 1.2)
	build_shell()
	build_portal()
	build_interior()
	build_ornaments()
	if collisions_enabled: build_collisions()
	G.batch_static_meshes(self)

func perimeter() -> PackedVector3Array:
	var points := PackedVector3Array([Vector3(1.5, 0, 3.7), Vector3(3.3, 0, 3.7)])
	var centers := [Vector3(3.3, 0, 3.3), Vector3(3.3, 0, -3.3), Vector3(-3.3, 0, -3.3), Vector3(-3.3, 0, 3.3)]
	for corner in range(4):
		for step in range(17):
			var angle := corner * PI / 2.0 + float(step) / 16.0 * PI / 2.0
			points.append(centers[corner] + Vector3(0.4 * sin(angle), 0, 0.4 * cos(angle)))
	points.append(Vector3(-1.5, 0, 3.7))
	return points

func along(points: PackedVector3Array, value: float) -> Vector3:
	var offset := clampf(value, 0.0, 1.0) * (points.size() - 1)
	var index := mini(int(offset), points.size() - 2)
	return points[index].lerp(points[index + 1], offset - index)

func build_shell() -> void:
	var open_ring := perimeter()
	G.surface(self, "ContinuousOpaqueShieldWall", open_ring.size() * 3, 14, func(u: float, v: float) -> Vector3:
		var p := along(open_ring, u)
		return Vector3(p.x, 3.03 * v, p.z)
	, pearl)
	G.surface(self, "RecessedInteriorLiner", open_ring.size() * 3, 12, func(u: float, v: float) -> Vector3:
		var p := along(open_ring, u)
		return Vector3(p.x * 0.946, 0.05 + 2.95 * v, p.z * 0.946)
	, G.material(Color("aaa5a0"), 0.14, 0.68), true)
	G.surface(self, "RegolithCoveredLowerSkirt", open_ring.size() * 3, 6, func(u: float, v: float) -> Vector3:
		var p := along(open_ring, u)
		return Vector3(p.x * 1.001, 0.03 + 0.56 * v, p.z * 1.001)
	, earth)
	var closed_ring := open_ring.duplicate()
	closed_ring.append(closed_ring[0])
	G.surface(self, "OpaqueRoundedShieldRoof", closed_ring.size() * 3, 24, func(u: float, v: float) -> Vector3:
		var p := along(closed_ring, u)
		return Vector3(p.x * v, 3.03 + 0.62 * (1.0 - pow(v, 5.0)), p.z * v)
	, earth)
	G.surface(self, "ContinuousCeilingLiner", closed_ring.size() * 3, 10, func(u: float, v: float) -> Vector3:
		var p := along(closed_ring, u)
		return Vector3(p.x * v, 3.02, p.z * v)
	, pearl, true)
	var crown := PackedVector3Array()
	var seam := PackedVector3Array()
	for p in closed_ring:
		crown.append(Vector3(p.x, 3.04, p.z))
		seam.append(Vector3(p.x * 1.002, 2.74, p.z * 1.002))
	G.tube(self, "ShieldRoofPearlFascia", crown, 0.085, pearl)
	G.tube(self, "CrimsonPressureSeam", seam, 0.035, ruby)
	# Header occupies only the area above the accessible three-metre doorway.
	G.surface(self, "FrontPortalHeader", 20, 5, func(u: float, v: float) -> Vector3:
		return Vector3(lerpf(-1.5, 1.5, u), lerpf(2.83, 3.04, v), 3.7)
	, pearl)

func portal_path(width: float, height: float, z: float) -> PackedVector3Array:
	var points := PackedVector3Array([Vector3(-width, 0.06, z), Vector3(-width, height - 0.5, z)])
	for step in range(25):
		var angle := PI - PI / 2.0 * step / 24
		points.append(Vector3(-width + 0.5 + 0.5 * cos(angle), height - 0.5 + 0.5 * sin(angle), z))
	points.append(Vector3(width - 0.5, height, z))
	for step in range(25):
		var angle := PI / 2.0 - PI / 2.0 * step / 24
		points.append(Vector3(width - 0.5 + 0.5 * cos(angle), height - 0.5 + 0.5 * sin(angle), z))
	points.append(Vector3(width, 0.06, z))
	return points

func build_portal() -> void:
	G.tube(self, "HeavyPearlPortal", portal_path(1.61, 2.91, 3.70), 0.14, pearl, 16)
	G.tube(self, "CrimsonPortalGasket", portal_path(1.54, 2.83, 3.73), 0.07, ruby, 12)
	G.tube(self, "CoralShelterThreshold", portal_path(1.51, 2.77, 3.76), 0.027, coral, 10)
	G.label(self, "ShelterIdentifier", Branding.title() + "  /  REFUGE 02", Vector3(0, 3.19, 3.76), 52, Color("f5ddd0"))
	for x in [-2.45, 2.45]:
		G.bar(self, "PortalStatus_%s" % x, Vector3(x, 1.35, 3.72), Vector3(x, 1.95, 3.72), 0.032, cyan)
	var light := OmniLight3D.new()
	light.name = "WarmRefugePractical"
	light.position = Vector3(0, 2.55, 2.15)
	light.light_color = Color("ffd6ba")
	light.light_energy = 0.85
	light.omni_range = 5.5
	light.shadow_enabled = false
	add_child(light)

func build_interior() -> void:
	# The rear display faces the doorway. No fictional force field or zero-dose claim.
	G.surface(self, "RecessedShelterStatusPanel", 24, 8, func(u: float, v: float) -> Vector3:
		return Vector3(lerpf(-1.6, 1.6, u), lerpf(1.0, 2.35, v), -3.43)
	, ruby)
	G.label(self, "PassiveShieldLabel", "PASSIVE SHIELD\nREGOLITH + RESERVE WATER", Vector3(0, 1.82, -3.40), 45, Color("b4e8e7"))
	for side in [-1.0, 1.0]:
		G.bar(self, "InteriorGuide_%s" % side, Vector3(side * 3.30, 0.20, 2.8), Vector3(side * 3.30, 0.20, -2.8), 0.021, cyan)

func build_collisions() -> void:
	G.collision_box(self, "ShieldLeftWall", Vector3(-3.5, 1.51, 0), Vector3(0.4, 3.02, 7.4))
	G.collision_box(self, "ShieldRightWall", Vector3(3.5, 1.51, 0), Vector3(0.4, 3.02, 7.4))
	G.collision_box(self, "ShieldRearWall", Vector3(0, 1.51, -3.6), Vector3(7.4, 3.02, 0.2))
	for side in [-1.0, 1.0]:
		G.collision_box(self, "ShieldFrontWall_%s" % side, Vector3(side * 2.6, 1.51, 3.6), Vector3(2.2, 3.02, 0.2))
	G.collision_box(self, "ShieldPortalHeader", Vector3(0, 2.93, 3.6), Vector3(3.0, 0.22, 0.2))
	G.collision_box(self, "ShieldRoof", Vector3(0, 3.14, 0), Vector3(7.4, 0.26, 7.4))

func build_ornaments() -> void:
	var gold := G.material(Color("b98947"), 0.72, 0.34)
	var lantern_glow := G.material(Color("ffd09a"), 0.05, 0.54, 0.65)
	for side in [-1.0, 1.0]:
		O.lantern(self, "RefugeLantern_%s" % side, Vector3(side * 2.45, 1.94, 3.82), 0.66, lantern_glow, gold)
		O.wave_patch(self, "RefugeGoldWave_%s" % side, func(u: float, v: float) -> Vector3:
			return Vector3(side * 2.50 + (u - 0.5) * 1.25, 0.75 + 0.50 * v, 3.715)
		, 2, 4, gold)
	var lattice: Array = []
	for index in range(38):
		var x := lerpf(-3.3, 3.3, index / 37.0)
		lattice.append(PackedVector3Array([Vector3(x, 2.78, 3.72), Vector3(x + 0.07, 2.96, 3.72)]))
	O.strokes(self, "RefugeAmberFasciaLattice", lattice, 0.014, gold)
