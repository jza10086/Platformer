extends SceneTree
## Independent visual-integration QA. Does not edit product resources.
var failures := 0
var checks := 0
var asset_instances := 0
var missing_textures := []
var bad_extents := []
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",label)
func ticks(n: int):
	for i in n: await physics_frame
func inspect(node: Node):
	if node is MeshInstance3D and node.has_meta("source_asset"):
		asset_instances += 1
		var bounds: AABB=node.mesh.get_aabb()
		if not bounds.size.is_equal_approx(Vector3.ONE) or not bounds.position.is_equal_approx(-Vector3.ONE*0.5): bad_extents.append(str(node.get_path())+" "+str(bounds))
		for surface in node.mesh.get_surface_count():
			var material=node.mesh.surface_get_material(surface)
			if not material is StandardMaterial3D or material.albedo_texture==null or material.albedo_texture.get_width()==0: missing_textures.append(str(node.get_path()))
	for child in node.get_children(): inspect(child)
func block(game: Node,x: int,y: int): return game.level.get_node("InteractiveBlocks/Block_%d_%d" % [x,y])
func run():
	var game=load("res://scenes/world11.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	inspect(game)
	check(asset_instances>600,"Over 600 true imported/derived 3D mesh instances participate in the level (%d)" % asset_instances)
	check(missing_textures.is_empty(),"Every imported instance has a nonempty texture on every surface: "+str(missing_textures))
	check(bad_extents.is_empty(),"Every normalized asset has centered unit local AABB: "+str(bad_extents))
	var ground=game.level.get_node("GroundTiles")
	var ground_count=0
	var alignment=true
	for tile in ground.get_children():
		if tile is MeshInstance3D:
			ground_count+=1
			alignment=alignment and tile.scale.is_equal_approx(Vector3.ONE*0.982) and absf(fmod(tile.position.x,1)-0.5)<0.0001 and absf(fmod(absf(tile.position.y),1)-0.5)<0.0001
	check(ground_count==402 and alignment,"Exactly 402 centered 0.982-unit terrain meshes retain all 1-unit grid boundaries")
	var stair_alignment=true
	for tile in game.level.get_node("StairTiles").get_children():
		if tile is MeshInstance3D: stair_alignment=stair_alignment and tile.scale.is_equal_approx(Vector3.ONE*0.982) and tile.has_meta("source_asset")
	check(stair_alignment,"All stair visuals use the identical 0.982-unit asset adapter")
	for pipe in game.layout.pipes:
		var pipe_root=game.level.get_node("Pipe_%d" % pipe.x)
		var visual=pipe_root.get_child(0)
		var collider=pipe_root.get_child(1).get_child(0)
		var rendered=AABB(visual.position-visual.scale*0.5,visual.scale)
		check(rendered.position.is_equal_approx(Vector3(-1,0,-0.6)) and rendered.size.is_equal_approx(collider.shape.size) and visual.mesh.get_aabb().size.is_equal_approx(Vector3.ONE),"Pipe %d rendered bounds match collider (2 × %d × 1.2)" % [pipe.x,pipe.height])
	var q=block(game,16,3)
	var original=q.visual.get_child(0)
	check(original.get_meta("source_asset").ends_with("crate-item.glb") and q.visual.get_child_count()==2 and q.visual.get_child(1).text=="?","Unused question block has imported crate plus readable question label")
	q.bump(game.player)
	await ticks(15)
	check(q.used and q.visual.get_child_count()==1 and q.visual.get_child(0).get_meta("source_asset").ends_with("crate-item.glb"),"Used question block removes its label while retaining imported module")
	check(q.visual.get_child(0).scale.is_equal_approx(Vector3.ONE*0.982) and q.collision.shape.size==Vector3.ONE and absf(q.visual.position.y)<0.0001,"Question bump returns to centered grid position; collider remains one tile")
	var used=q.visual.get_child(0).mesh.surface_get_material(0).albedo_texture.get_image()
	var fresh=block(game,23,3).visual.get_child(0).mesh.surface_get_material(0).albedo_texture.get_image()
	check(used.get_data()!=fresh.get_data(),"Used state has a genuinely different desaturated palette")
	var secret=block(game,64,4)
	check(secret.hidden and not secret.visual.visible and secret.collision_layer==0,"Secret asset is invisible and noncolliding before activation")
	var coins=0
	var coin_geometry=true
	for node in game.level.get_node("BonusRoom").get_children():
		if node is Area3D:
			coins+=1
			var visual=node.get_child(1)
			coin_geometry=coin_geometry and visual.get_meta("source_asset").ends_with("coin-gold.glb") and visual.position.is_zero_approx() and visual.scale.is_equal_approx(Vector3(0.54,0.54,0.18)) and is_equal_approx(node.get_child(0).shape.radius,0.43)
	check(coins==19 and coin_geometry,"All 19 bonus coins retain centered visuals and original collection radius")
	for mode in ["mushroom","life","star"]:
		var item=game.ITEM.new()
		item.configure(mode,game)
		item.position=Vector3(5,1,0)
		game.level.add_child(item)
		var expected="star.glb" if mode=="star" else "mushroom-single.glb"
		check(item.visual.get_child_count()==1 and item.visual.get_child(0).get_meta("source_asset").ends_with(expected) and item.get_child(0).shape.size.is_equal_approx(Vector3(0.65,0.72,0.65)),"%s pickup has imported model and unchanged collider" % mode)
		item.queue_free()
	check(game.player.visual.get_child(0).mesh is BoxMesh and game.player.visual.get_child(0).mesh.size.is_equal_approx(Vector3.ONE*0.9),"Original coral cube character is preserved")
	check(game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and game.camera.rotation.is_zero_approx() and game.camera.position.y==5 and game.camera.position.z==16,"Original horizontal perspective camera is preserved")
	print("INDEPENDENT ASSET RESULT: ",checks," checks; ",failures," failure(s)")
	await ticks(75)
	quit(failures)
