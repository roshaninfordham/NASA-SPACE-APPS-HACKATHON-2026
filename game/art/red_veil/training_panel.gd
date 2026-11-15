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
	_materials.frame = _material(VisualStyle.color("pearl"),0.26,0.42)
	_materials.base = _material(Color("202d3b"),0.38,0.65)
	_materials.accent = _material(VisualStyle.color("crimson"),0.24,0.58)
	_materials.gasket = _material(Color("101c2b"),0.65,0.05)
	_materials.fastener = _material(VisualStyle.color("rose_gold"),0.28,0.72)
	_materials.indicator = _material(VisualStyle.color("cyan"),0.24,0.15)
	_materials.indicator.emission_enabled = true
	_materials.indicator.emission = VisualStyle.color("cyan")*0.45
	_build_base()
	_deck = Node3D.new()
	_deck.name = "TiltedArray"
	_deck.position.y = 1.08
	_deck.rotation.x = deg_to_rad(TILT_DEGREES)
	add_child(_deck)
	_box(_deck,"Backplate",Vector3(0,-0.012,0),Vector3(WIDTH,0.065,DEPTH),_materials.base)
	# Each continuous perimeter is one low-poly mesh, not four chunky rails.
	_rim(_deck,"PearlPerimeter",Vector2(WIDTH+0.05,DEPTH+0.05),Vector2(WIDTH-0.055,DEPTH-0.055),0.018,0.057,_materials.frame)
	_rim(_deck,"CrimsonSeam",Vector2(WIDTH+0.025,DEPTH+0.025),Vector2(WIDTH+0.008,DEPTH+0.008),0.058,0.060,_materials.accent)
	_rim(_deck,"CellGasket",Vector2(WIDTH-0.055,DEPTH-0.055),Vector2(WIDTH-0.082,DEPTH-0.082),0.038,0.043,_materials.gasket)
	_surface = ShaderMaterial.new()
	_surface.resource_name = "TrainingPanelContinuousDust"
	_surface.shader = DustShader
	_surface.set_shader_parameter("clean_fraction",clean_fraction)
	var plane := PlaneMesh.new()
	plane.size = Vector2(WIDTH-0.082,DEPTH-0.082)
	var cells := MeshInstance3D.new()
	cells.name = "DustAndCells"
	cells.mesh = plane
	cells.material_override = _surface
	cells.position.y = 0.04
	_deck.add_child(cells)
	# Hardware remains outside the brush surface; a small steady indicator is
	# decorative equipment trim, not a second power or hazard simulation.
	for x in [-1.17,1.17]:
		for z in [-0.74,0.74]:
			_box(_deck,"RecessedFastener",Vector3(x,0.058,z),Vector3(0.021,0.006,0.021),_materials.fastener)
	_box(_deck,"StatusLight",Vector3(0.95,0.058,-0.758),Vector3(0.105,0.006,0.008),_materials.indicator)
	_sync_surface()
	set_process(false)

func _build_base() -> void:
	for x in [-0.84,0.84]:
		_box(self,"GroundSled",Vector3(x,0.055,0),Vector3(0.12,0.075,1.24),_materials.base)
		_beam(self,Vector3(x,0.10,0),Vector3(x,1.04,0),0.036,_materials.frame)
		_beam(self,Vector3(x-0.07,1.01,0),Vector3(x+0.07,1.01,0),0.073,_materials.base)
		for z in [-0.54,0.54]:
			_box(self,"FootPad",Vector3(x,0.026,z),Vector3(0.23,0.052,0.17),_materials.base)
			_beam(self,Vector3(x,0.10,z),Vector3(x,0.78,0),0.022,_materials.base)
	_beam(self,Vector3(-0.84,0.32,0),Vector3(0.84,0.32,0),0.025,_materials.base)
	_box(self,"JunctionBox",Vector3(0,0.37,0.06),Vector3(0.23,0.15,0.09),_materials.frame)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = roughness
	value.metallic = metallic
	return value

func _box(parent: Node3D, label: String, center: Vector3, dimensions: Vector3, material: Material) -> void:
	# Chamfered manufactured edges catch light even in the compatibility
	# renderer. Four eight-vertex rings keep the geometry inexpensive.
	var bevel := minf(0.018,minf(dimensions.x,minf(dimensions.y,dimensions.z))*0.24)
	var rings := [
		_loop(dimensions.x-2*bevel,dimensions.z-2*bevel,-dimensions.y*0.5,bevel),
		_loop(dimensions.x,dimensions.z,-dimensions.y*0.5+bevel,bevel*2),
		_loop(dimensions.x,dimensions.z,dimensions.y*0.5-bevel,bevel*2),
		_loop(dimensions.x-2*bevel,dimensions.z-2*bevel,dimensions.y*0.5,bevel)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(3):
		for index in range(8):
			var next := (index+1)%8
			_quad(surface,rings[row][index],rings[row+1][index],rings[row+1][next],rings[row][next])
	for index in range(8):
		var next := (index+1)%8
		_triangle(surface,Vector3(0,dimensions.y*0.5,0),rings[3][next],rings[3][index])
		_triangle(surface,Vector3(0,-dimensions.y*0.5,0),rings[0][index],rings[0][next])
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)

func _loop(width: float, depth: float, y: float, corner: float) -> PackedVector3Array:
	var x := width*0.5
	var z := depth*0.5
	var c := minf(corner,minf(x,z)*0.8)
	return PackedVector3Array([Vector3(-x+c,y,-z),Vector3(x-c,y,-z),Vector3(x,y,-z+c),Vector3(x,y,z-c),Vector3(x-c,y,z),Vector3(-x+c,y,z),Vector3(-x,y,z-c),Vector3(-x,y,-z+c)])

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b-a).cross(c-a).normalized()
	for vertex in [a,b,c]:
		surface.set_normal(normal)
		surface.add_vertex(vertex)

func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(surface,a,b,c)
	_triangle(surface,a,c,d)

func _rim(parent: Node3D, label: String, outer: Vector2, inner: Vector2, lower: float, upper: float, material: Material) -> void:
	var outside := _loop(outer.x,outer.y,lower,0.045)
	var top := _loop(outer.x-0.012,outer.y-0.012,upper,0.04)
	var inside := _loop(inner.x,inner.y,upper,0.018)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(8):
		var next := (index+1)%8
		_quad(surface,outside[index],top[index],top[next],outside[next])
		_quad(surface,top[index],inside[index],inside[next],top[next])
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = surface.commit()
	instance.material_override = material
	parent.add_child(instance)

func _beam(parent: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 16
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
