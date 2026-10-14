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

## A true 26-face chamfered solid, shared by each independent masonry module.
static func chamfered_cube(bevel := 0.045) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 0.5
	var s := h-bevel
	# Six inset face rectangles.
	for axis in 3:
		for direction in [-1.0,1.0]:
			var normal := Vector3.ZERO
			normal[axis] = direction
			var a := (axis+1)%3
			var b := (axis+2)%3
			var points: Array[Vector3] = []
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point := normal*h
				point[a] = corner.x*s
				point[b] = corner.y*s
				points.append(point)
			_face(surface,points,normal)
	# Twelve bevel strips between those faces.
	for free_axis in 3:
		var a := (free_axis+1)%3
		var b := (free_axis+2)%3
		for sa in [-1.0,1.0]:
			for sb in [-1.0,1.0]:
				var normal := Vector3.ZERO
				normal[a] = sa
				normal[b] = sb
				var points: Array[Vector3] = []
				for corner in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
					var point := Vector3.ZERO
					point[free_axis] = corner.x*s
					point[a] = sa*(h if corner.y == 0 else s)
					point[b] = sb*(s if corner.y == 0 else h)
					points.append(point)
				_face(surface,points,normal.normalized())
	# Eight triangular corners close the solid.
	for x in [-1.0,1.0]:
		for y in [-1.0,1.0]:
			for z in [-1.0,1.0]:
				_face(surface,[Vector3(x*h,y*s,z*s),Vector3(x*s,y*h,z*s),Vector3(x*s,y*s,z*h)],Vector3(x,y,z).normalized())
	return surface.commit()
static func _face(surface: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	# Godot renders clockwise winding; normals are explicit for crisp bevels.
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal)>0: points.reverse()
	for i in range(1,points.size()-1):
		for p in [points[0],points[i],points[i+1]]:
			surface.set_normal(normal)
			surface.add_vertex(p)
