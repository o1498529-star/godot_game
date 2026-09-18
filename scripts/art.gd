extends RefCounted

static var materials: Dictionary = {}

static func mat(hex: String) -> StandardMaterial3D:
	if materials.has(hex):
		return materials[hex]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.72
	materials[hex] = m
	return m

static func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.position = at
	node.material_override = mat(color)
	parent.add_child(node)
	return node

static func box(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, at, color)

static func ball(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 8
	var node := mesh(parent, shape, at, color)
	node.scale = size
	return node

static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: String, top: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top < 0.0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 16
	return mesh(parent, shape, at, color)

static func collision(parent: CollisionObject3D, at: Vector3, size: Vector3) -> CollisionShape3D:
	var c := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	c.shape = shape
	c.position = at
	parent.add_child(c)
	return c

static func cat() -> Node3D:
	var root := Node3D.new()
	root.name = "Cat"
	ball(root, Vector3(0, 1.05, 0), Vector3(0.85, 1.0, 0.62), "e89f53")
	ball(root, Vector3(0, 1.08, -0.28), Vector3(0.55, 0.65, 0.16), "fff0ce")
	ball(root, Vector3(0, 1.84, 0), Vector3(1.12, 1.0, 0.92), "edac63")
	for side in [-1.0, 1.0]:
		var ear := cylinder(root, Vector3(side * 0.36, 2.38, 0.02), 0.26, 0.56, "d88741", 0.025)
		ear.rotation.z = side * -0.16
		var inner := cylinder(root, Vector3(side * 0.36, 2.4, -0.12), 0.16, 0.36, "f0b9a7", 0.01)
		inner.rotation.z = side * -0.16
		ball(root, Vector3(side * 0.24, 1.96, -0.39), Vector3(0.36, 0.4, 0.18), "fff9e7")
		ball(root, Vector3(side * 0.24, 1.97, -0.48), Vector3(0.2, 0.25, 0.08), "42bca9")
		ball(root, Vector3(side * 0.24, 1.97, -0.52), Vector3(0.09, 0.18, 0.04), "163845")
		ball(root, Vector3(side * 0.17, 1.68, -0.43), Vector3(0.36, 0.29, 0.2), "fff0ce")
		var leg := Node3D.new()
		leg.name = "LeftLeg" if side < 0 else "RightLeg"
		leg.position = Vector3(side * 0.24, 0.67, 0)
		root.add_child(leg)
		ball(leg, Vector3(0, -0.24, 0), Vector3(0.31, 0.65, 0.34), "c77f3c")
		ball(leg, Vector3(0, -0.51, -0.11), Vector3(0.4, 0.25, 0.6), "176e84")
		var arm := Node3D.new()
		arm.name = "LeftArm" if side < 0 else "RightArm"
		arm.position = Vector3(side * 0.48, 1.42, 0)
		root.add_child(arm)
		ball(arm, Vector3(side * 0.06, -0.24, 0), Vector3(0.28, 0.64, 0.3), "e89f53")
		ball(arm, Vector3(side * 0.06, -0.49, 0), Vector3(0.3, 0.28, 0.3), "fff0ce")
	ball(root, Vector3(0, 1.77, -0.56), Vector3(0.18, 0.13, 0.12), "9d5754")
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.88, 0.25)
	root.add_child(tail)
	var tail_mesh := ball(tail, Vector3(0, 0.13, 0.43), Vector3(0.24, 0.28, 1.0), "c77f3c")
	tail_mesh.rotation.x = -0.5
	ball(tail, Vector3(0, 0.36, 0.83), Vector3(0.26, 0.3, 0.28), "fff0ce")
	box(root, Vector3(0, 1.51, 0), Vector3(0.75, 0.17, 0.72), "e85d62")
	var scarf := box(root, Vector3(0.22, 1.25, 0.4), Vector3(0.24, 0.59, 0.12), "e85d62")
	scarf.rotation.z = -0.18
	box(root, Vector3(0, 1.04, 0.37), Vector3(0.5, 0.58, 0.25), "197b96")
	return root

static func vehicle(parent: StaticBody3D, bus: bool, color: String) -> void:
	var length := 5.8 if bus else 3.6
	var height := 2.75 if bus else 1.65
	box(parent, Vector3(0, 0.8, 0), Vector3(2.08, 1.1, length), color)
	box(parent, Vector3(0, height - 0.48, -0.15), Vector3(1.94, 0.96, length - 1.0), color)
	box(parent, Vector3(0, height - 0.48, length / 2.0 - 0.48), Vector3(1.66, 0.64, 0.035), "204b67")
	box(parent, Vector3(0, 0.43, length / 2.0 + 0.025), Vector3(2.17, 0.18, 0.15), "fff0ce")
	for side in [-1.0, 1.0]:
		for z in [-length * 0.32, length * 0.32]:
			var wheel := cylinder(parent, Vector3(side * 1.03, 0.4, z), 0.4, 0.18, "233b4f")
			wheel.rotation.z = PI / 2
			var hub := cylinder(parent, Vector3(side * 1.14, 0.4, z), 0.2, 0.025, "accbd1")
			hub.rotation.z = PI / 2
		box(parent, Vector3(side * 0.7, 0.87, length / 2.0 + 0.03), Vector3(0.38, 0.23, 0.06), "ffdf75")
		for z in ([-1.7, -0.55, 0.6, 1.7] if bus else [-0.55, 0.4]):
			box(parent, Vector3(side * 0.98, height - 0.44, z), Vector3(0.03, 0.6, 0.8), "28627a")
	collision(parent, Vector3(0, height / 2.0, 0), Vector3(2.18, height, length))

static func tree(parent: Node3D, at: Vector3) -> void:
	cylinder(parent, at + Vector3(0, 1.2, 0), 0.19, 2.4, "966d50")
	ball(parent, at + Vector3(0, 3, 0), Vector3(2.2, 2.6, 2.2), "63bb70")
	ball(parent, at + Vector3(0.55, 3.5, 0), Vector3(1.7, 1.8, 1.7), "91d26a")
