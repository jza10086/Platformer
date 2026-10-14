extends RefCounted
## Visual-only adapters for Kenney Platformer Kit 4.1 (CC0).
## Geometry is normalized from its actual imported AABB. Nothing here creates
## collision bodies or changes the level grid, player, camera, or game rules.
const DIRECTORY := "res://assets/kenney/platformer-kit/Models/"
static var mesh_cache: Dictionary = {}
static var material_cache: Dictionary = {}
static var palette_image: Image

static func make(parent: Node, asset: String, point: Vector3, size: Vector3, variant := "", pipe_height := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "Asset_" + asset.replace("-", "_")
	instance.mesh = normalized_mesh(asset, variant, pipe_height)
	instance.position = point
	instance.scale = size
	instance.set_meta("source_asset", DIRECTORY + asset + ".glb")
	instance.set_meta("visual_extent", size)
	parent.add_child(instance)
	return instance

static func normalized_mesh(asset: String, variant := "", pipe_height := 0.0) -> ArrayMesh:
	if asset == "brick" and variant.is_empty(): variant = "masonry"
	var key := "%s:%s:%.3f" % [asset, variant, pipe_height]
	if mesh_cache.has(key): return mesh_cache[key]
	var packed := load(DIRECTORY + asset + ".glb") as PackedScene
	assert(packed != null, "Missing licensed model: " + asset)
	var root := packed.instantiate()
	var source := _find_mesh(root)
	assert(source != null, "Model contains no mesh: " + asset)
	var bounds := source.mesh.get_aabb()
	var center := bounds.get_center()
	var extent := bounds.size
	var result := ArrayMesh.new()
	for surface in source.mesh.get_surface_count():
		var arrays := source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in vertices.size():
			var point := vertices[index]
			vertices[index] = (point - center) / extent
			if not normals.is_empty(): normals[index] = (normals[index] * extent).normalized()
			if pipe_height > 0:
				# The source pipe has a short body followed by a 0.285714-unit
				# collar. Extend only the body; preserve the collar's world height.
				var collar_start := 0.27857143
				var collar_height := 0.57142865
				var y := point.y - bounds.position.y
				if y <= collar_start + 0.00001:
					vertices[index].y = y / collar_start * (pipe_height - collar_height) / pipe_height - 0.5
				else:
					vertices[index].y = (pipe_height - collar_height + (y - collar_start) * 2.0) / pipe_height - 0.5
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		result.surface_set_material(surface, _material(source.mesh.surface_get_material(surface), variant))
	root.free()
	mesh_cache[key] = result
	return result

static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null: return found
	return null

static func _material(original: Material, variant: String) -> Material:
	if material_cache.has(variant): return material_cache[variant]
	var material := original.duplicate() as StandardMaterial3D
	material.roughness = 0.88
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if not variant.is_empty():
		if palette_image == null:
			palette_image = (load(DIRECTORY + "Textures/colormap.png") as Texture2D).get_image()
		var changed := palette_image.duplicate() as Image
		for y in changed.get_height():
			for x in changed.get_width():
				var color := changed.get_pixel(x, y)
				match variant:
					"masonry":
						# The original brick has blue-grey mortar. Warm that mortar
						# so narrow joints do not read as holes into the blue sky.
						if color.h > 0.55 and color.h < 0.78 and color.s > 0.10:
							color = Color.from_hsv(0.065, 0.45, color.v * 0.58, color.a)
					"pipe": color = Color.from_hsv(0.39, color.s * 0.80, color.v * 0.88, color.a)
					"life":
						if color.s > 0.35 and (color.h < 0.12 or color.h > 0.9):
							color = Color.from_hsv(0.39, color.s * 0.85, color.v, color.a)
					"used": color = Color.from_hsv(0.10, color.s * 0.18, color.v * 0.65, color.a)
					"stone": color = Color.from_hsv(0.60, color.s * 0.18, color.v * 0.68, color.a)
					"distant": color = color.lerp(Color("8ec5b4"), 0.40)
				changed.set_pixel(x, y, color)
		material.albedo_texture = ImageTexture.create_from_image(changed)
	if variant == "distant":
		material.disable_receive_shadows = true
	material_cache[variant] = material
	return material
