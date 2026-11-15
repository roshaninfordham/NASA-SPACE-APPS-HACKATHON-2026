extends Node3D
## Visible training array for the window mission only. The 2.4 m presentation
## geometry is illustrative; the mission model alone owns work and power maths.
## All geometry is built once. A single opaque surface shader clears dust
## continuously, without transparency sorting, particles or per-frame meshes.
## A modest clearing-edge glint is driven only by newly observed model work;
## there is no independent visual clock that can invent cleaning progress.
const VisualStyle = preload("res://scripts/visual_style.gd")
const DustShader = preload("res://art/red_veil/training_panel.gdshader")
const WIDTH := 2.4
const DEPTH := 1.55
const TILT_DEGREES := -35.0
var clean_fraction := 0.0
var cleaning := false
var reduced_motion := false
var _has_progress_sample := false
var _work_feedback := 0.0
var _surface: ShaderMaterial
var _deck: Node3D
var _materials: Dictionary = {}

func _ready() -> void:
	name = "TrainingSolarPanel"
	set_meta("presentation_only",true)
	set_meta("nominal_width_m",WIDTH)
	set_meta("nominal_depth_m",DEPTH)
	set_meta("science_note","Illustrative visible array. Model parameters define actual cleaning, panel output and time.")
	_materials.frame = _material(VisualStyle.color("steel").lightened(0.12),0.52,0.45)
	_materials.base = _material(Color("33414a"),0.82,0.25)
	_materials.accent = _material(VisualStyle.color("crimson"),0.68,0.10)
	_build_base()
	_deck = Node3D.new()
	_deck.name = "TiltedArray"
	_deck.position.y = 1.08
	_deck.rotation.x = deg_to_rad(TILT_DEGREES)
	add_child(_deck)
	_box(_deck,"Backplate",Vector3.ZERO,Vector3(WIDTH,0.065,DEPTH),_materials.base)
	for x in [-WIDTH*0.5,WIDTH*0.5]:
		_box(_deck,"SideRail",Vector3(x,0.035,0),Vector3(0.065,0.075,DEPTH+0.065),_materials.frame)
	for z in [-DEPTH*0.5,DEPTH*0.5]:
		_box(_deck,"EndRail",Vector3(0,0.035,z),Vector3(WIDTH,0.075,0.065),_materials.frame)
	_surface = ShaderMaterial.new()
	_surface.resource_name = "TrainingPanelContinuousDust"
	_surface.shader = DustShader
	_surface.set_shader_parameter("clean_fraction",clean_fraction)
	var plane := PlaneMesh.new()
	plane.size = Vector2(WIDTH-0.065,DEPTH-0.065)
	var cells := MeshInstance3D.new()
	cells.name = "DustAndCells"
	cells.mesh = plane
	cells.material_override = _surface
	cells.position.y = 0.04
	_deck.add_child(cells)
	# Small corner plates distinguish the working surface from the stable stand.
	for x in [-1.08,1.08]:
		_box(_deck,"CornerPlate",Vector3(x,0.074,-0.67),Vector3(0.13,0.016,0.11),_materials.accent)
	_sync_surface()
	set_process(false)

func _build_base() -> void:
	for x in [-0.84,0.84]:
		_box(self,"GroundSled",Vector3(x,0.055,0),Vector3(0.20,0.11,1.35),_materials.base)
		_box(self,"Upright",Vector3(x,0.55,0),Vector3(0.11,1.00,0.11),_materials.frame)
		for z in [-0.54,0.54]:
			_box(self,"FootPad",Vector3(x,0.026,z),Vector3(0.34,0.052,0.24),_materials.base)
			_beam(self,Vector3(x,0.11,z),Vector3(x,0.78,0),0.055,_materials.frame)
	_box(self,"CrossBrace",Vector3(0,0.30,0),Vector3(1.78,0.08,0.08),_materials.frame)
	_box(self,"JunctionBox",Vector3(0,0.37,0.12),Vector3(0.27,0.24,0.15),_materials.accent)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = roughness
	value.metallic = metallic
	return value

func _box(parent: Node3D, label: String, center: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)

func _beam(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 8
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = "DiagonalSupport"
	instance.mesh = mesh
	instance.material_override = material
	var up := (to-from).normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < 0.001: side = up.cross(Vector3.RIGHT).normalized()
	instance.transform = Transform3D(Basis(side,up,side.cross(up).normalized()),(from+to)*0.5)
	parent.add_child(instance)

func refresh(snapshot: Dictionary) -> void:
	# The current model's continuous work takes precedence. Explicit normalized
	# progress and a section adapter keep the visual reusable in isolated tools.
	var fraction := float(snapshot.get("cleaning_progress",snapshot.get("clean_fraction",-1.0)))
	if snapshot.has("cleaned_work"):
		fraction = float(snapshot.cleaned_work) / maxf(1.0,float(snapshot.get("max_sections",4)))
	if fraction < 0.0:
		fraction = (float(snapshot.get("sections_cleaned",0))+float(snapshot.get("section_progress",0.0))) / maxf(1.0,float(snapshot.get("max_sections",4)))
	if not is_finite(fraction): fraction = 0.0
	var previous_fraction := clean_fraction
	clean_fraction = clampf(fraction,0.0,1.0)
	cleaning = bool(snapshot.get("cleaning",false))
	# Loading a saved/fixture value, pausing, or moving backwards never causes a
	# false work cue. Both the flecks and glint move with genuine removed dust.
	var advancing := _has_progress_sample and clean_fraction > previous_fraction + 0.0000001
	_work_feedback = 1.0 if advancing and cleaning and clean_fraction < 0.9999 else 0.0
	_has_progress_sample = true
	_sync_surface()

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_sync_surface()

func _sync_surface() -> void:
	if not _surface: return
	_surface.set_shader_parameter("clean_fraction", clean_fraction)
	_surface.set_shader_parameter("work_feedback", 0.0 if reduced_motion else _work_feedback)
