class_name VeilPlayer
extends CharacterBody3D
## Camera-relative movement pattern informed by Kenney's MIT starter kit.
## First-person controls and Mars gravity are game-specific.
const GRAVITY := 3.71
const SPEED := 5.0
const TRAINING_RADIUS := 62.0
const BOUNDARY_WARNING_RADIUS := 56.0
const OPERATOR_SPEED := 2.2
const OPERATOR_MIN := Vector2(-3.0, -16.0)
const OPERATOR_MAX := Vector2(3.0, -11.2)
var operator_area := false
var scanner_visibility: Dictionary = {}
var at_training_boundary := false
@export var art: VeilArtProfile = preload("res://art/default_art.tres")
var enabled := false
var touch_move := Vector2.ZERO
var bob := 0.0
var foot_timer := 0.0
var camera: Camera3D
var head: Node3D
var footsteps: AudioStreamPlayer

func _ready() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	head = Node3D.new()
	head.position.y = 1.58
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 78.0
	camera.near = 0.06
	head.add_child(camera)
	camera.current = true
	create_scanner()
	footsteps = AudioStreamPlayer.new()
	footsteps.stream = load("res://assets/audio/land.ogg")
	footsteps.volume_db = -23.0
	add_child(footsteps)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0024)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * 0.0024, -1.2, 1.2)
	if event is InputEventScreenDrag and event.position.x > get_viewport().get_visible_rect().size.x * 0.45:
		rotate_y(-event.relative.x * 0.004)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * 0.004, -1.2, 1.2)

func _physics_process(delta: float) -> void:
	if not enabled:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("left", "right", "forward", "back") + touch_move
	input = input.limit_length()
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var walking_speed := OPERATOR_SPEED if operator_area else SPEED
	velocity.x = move_toward(velocity.x, direction.x * walking_speed, delta * 16.0)
	velocity.z = move_toward(velocity.z, direction.z * walking_speed, delta * 16.0)
	if not is_on_floor(): velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"): velocity.y = 2.4
	move_and_slide()
	_keep_inside_training_area()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5 and is_on_floor()
	if moving:
		bob += delta * 8.0
		foot_timer -= delta
		if foot_timer <= 0:
			footsteps.pitch_scale = randf_range(0.7, 0.9)
			footsteps.play()
			foot_timer = 0.5
	camera.position.y = sin(bob) * 0.018 if moving else lerpf(camera.position.y, 0.0, delta * 8.0)
	var look := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if look.length() > 0.15:
		rotate_y(-look.x * delta * 2.0)
		head.rotation.x = clampf(head.rotation.x - look.y * delta * 1.5, -1.2, 1.2)

func configure_operator_area(active: bool) -> void:
	operator_area = active
	at_training_boundary = false
	if not is_instance_valid(camera): return
	for child in camera.get_children():
		if child is Node3D:
			if active:
				if not scanner_visibility.has(child): scanner_visibility[child] = child.visible
				child.hide()
			elif scanner_visibility.has(child): child.visible = scanner_visibility[child]
	if not active: scanner_visibility.clear()

func _keep_inside_training_area() -> void:
	# A finite training map, not a physical force or an invisible pressure wall.
	# Stop outward travel smoothly instead of teleporting across the outpost.
	if position.y < -5:
		position = Vector3(0, 0.3, -12.6) if operator_area else Vector3(0, 0.3, 14)
		velocity = Vector3.ZERO
	if operator_area:
		# An authored indoor play area. Preserve inward, tangential and vertical
		# movement; never move the operator into the exposed crew's location.
		if position.x < OPERATOR_MIN.x:
			position.x = OPERATOR_MIN.x
			velocity.x = maxf(velocity.x, 0.0)
		elif position.x > OPERATOR_MAX.x:
			position.x = OPERATOR_MAX.x
			velocity.x = minf(velocity.x, 0.0)
		if position.z < OPERATOR_MIN.y:
			position.z = OPERATOR_MIN.y
			velocity.z = maxf(velocity.z, 0.0)
		elif position.z > OPERATOR_MAX.y:
			position.z = OPERATOR_MAX.y
			velocity.z = minf(velocity.z, 0.0)
		at_training_boundary = position.x <= OPERATOR_MIN.x + 0.15 or position.x >= OPERATOR_MAX.x - 0.15 or position.z <= OPERATOR_MIN.y + 0.15 or position.z >= OPERATOR_MAX.y - 0.15
		return
	var horizontal := Vector2(position.x, position.z)
	at_training_boundary = horizontal.length() >= BOUNDARY_WARNING_RADIUS
	if horizontal.length() > TRAINING_RADIUS:
		var outward := horizontal.normalized()
		horizontal = outward * TRAINING_RADIUS
		position.x = horizontal.x
		position.z = horizontal.y
		var flat_velocity := Vector2(velocity.x, velocity.z)
		flat_velocity -= outward * maxf(0.0, flat_velocity.dot(outward))
		velocity.x = flat_velocity.x
		velocity.z = flat_velocity.y

func create_scanner() -> void:
	if art.scanner_scene != null:
		camera.add_child(art.scanner_scene.instantiate())
		return
	# Cosmetic hand-held instrument, separate from collision and simulation.
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color("dfd9c8")
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("263e4d")
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color("8ed8bc")
	screen.emission_enabled = true
	screen.emission = Color("65a894")
	for x in [0.22, 0.45]:
		var glove := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.07
		sphere.height = 0.17
		sphere.radial_segments = 10
		sphere.rings = 6
		glove.mesh = sphere
		glove.material_override = pale
		glove.position = Vector3(x, -0.39, -0.61)
		glove.rotation.x = 0.5
		camera.add_child(glove)
	var scanner := MeshInstance3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(0.25, 0.32, 0.09)
	scanner.mesh = body
	scanner.material_override = dark
	scanner.position = Vector3(0.34, -0.32, -0.66)
	scanner.rotation.x = -0.35
	camera.add_child(scanner)
	var display := MeshInstance3D.new()
	var face := BoxMesh.new()
	face.size = Vector3(0.19, 0.19, 0.012)
	display.mesh = face
	display.material_override = screen
	display.position = Vector3(0, 0.02, 0.052)
	scanner.add_child(display)
	var readout := Label3D.new()
	readout.text = "AEGIS\nFIELD SCAN"
	readout.font_size = 32
	readout.pixel_size = 0.00085
	readout.modulate = Color("163e46")
	readout.outline_size = 0
	readout.position = Vector3(0, 0.02, 0.063)
	scanner.add_child(readout)

func _exit_tree() -> void:
	if is_instance_valid(footsteps): footsteps.stop()
