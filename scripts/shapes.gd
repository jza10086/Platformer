class_name Shapes
extends RefCounted
static func material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.metallic = metal
	return m
static func box(parent: Node, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = material(color)
	n.position = pos
	parent.add_child(n)
	return n
static func sphere(parent: Node, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 6
	n.mesh = mesh
	n.material_override = material(color)
	n.position = pos
	n.scale = size
	parent.add_child(n)
	return n
static func cylinder(parent: Node, pos: Vector3, radius: float, height: float, color: Color, top := -1.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	n.mesh = mesh
	n.material_override = material(color)
	n.position = pos
	parent.add_child(n)
	return n
