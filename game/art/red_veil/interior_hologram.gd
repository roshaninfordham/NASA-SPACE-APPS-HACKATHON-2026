extends RefCounted
## A subdivided icosahedron gives the reference's triangular network without
## screen-space wireframe support. All edges share one mesh; nodes are instanced.
const Ornaments = preload("res://art/red_veil/exterior_ornaments.gd")

static func build_network(parent: Node3D, radius: float, material: Material, subdivisions: int = 2) -> Node3D:
	var network := Node3D.new()
	network.name = "GeodesicHologram"
	parent.add_child(network)
	var phi := (1.0 + sqrt(5.0)) / 2.0
	var vertices: Array[Vector3] = [Vector3(-1,phi,0), Vector3(1,phi,0), Vector3(-1,-phi,0), Vector3(1,-phi,0), Vector3(0,-1,phi), Vector3(0,1,phi), Vector3(0,-1,-phi), Vector3(0,1,-phi), Vector3(phi,0,-1), Vector3(phi,0,1), Vector3(-phi,0,-1), Vector3(-phi,0,1)]
	for index in range(vertices.size()): vertices[index] = vertices[index].normalized()
	var faces: Array = [[0,11,5], [0,5,1], [0,1,7], [0,7,10], [0,10,11], [1,5,9], [5,11,4], [11,10,2], [10,7,6], [7,1,8], [3,9,4], [3,4,2], [3,2,6], [3,6,8], [3,8,9], [4,9,5], [2,4,11], [6,2,10], [8,6,7], [9,8,1]]
	for iteration in range(clampi(subdivisions, 0, 2)):
		var midpoint_cache: Dictionary = {}
		var refined: Array = []
		for face: Array in faces:
			var a := _midpoint(face[0], face[1], vertices, midpoint_cache)
			var b := _midpoint(face[1], face[2], vertices, midpoint_cache)
			var c := _midpoint(face[2], face[0], vertices, midpoint_cache)
			refined.append_array([[face[0], a, c], [face[1], b, a], [face[2], c, b], [a,b,c]])
		faces = refined
	var seen: Dictionary = {}
	var paths: Array = []
	for face: Array in faces:
		for pair in [[face[0], face[1]], [face[1], face[2]], [face[2], face[0]]]:
			var key := Vector2i(mini(pair[0], pair[1]), maxi(pair[0], pair[1]))
			if seen.has(key): continue
			seen[key] = true
			# Follow the spherical surface rather than cutting through the planet.
			var path := PackedVector3Array()
			for step in range(4): path.append(vertices[key.x].slerp(vertices[key.y], step / 3.0) * radius)
			paths.append(path)
	var lines := Ornaments.strokes(network, "GeodesicEdges", paths, 0.0045, material)
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var node_mesh := SphereMesh.new()
	node_mesh.radius = 0.018
	node_mesh.height = 0.036
	node_mesh.radial_segments = 8
	node_mesh.rings = 4
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = node_mesh
	instances.instance_count = vertices.size()
	for index in range(vertices.size()): instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, vertices[index] * radius))
	var nodes := MultiMeshInstance3D.new()
	nodes.name = "GeodesicNodes"
	nodes.multimesh = instances
	nodes.material_override = material
	nodes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	network.add_child(nodes)
	return network

static func _midpoint(a: int, b: int, vertices: Array[Vector3], cache: Dictionary) -> int:
	var key := Vector2i(mini(a,b), maxi(a,b))
	if cache.has(key): return cache[key]
	var index := vertices.size()
	vertices.append((vertices[a] + vertices[b]).normalized())
	cache[key] = index
	return index
