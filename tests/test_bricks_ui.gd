extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func ticks(count: int) -> void:
	for i in count: await physics_frame
func controls_within(node: Node, bounds: Rect2) -> bool:
	if node is Control and node.is_visible_in_tree() and node.size.length()>0:
		if not bounds.grow(1).encloses(node.get_global_rect()): return false
	for child in node.get_children():
		if not controls_within(child,bounds): return false
	return true
func run() -> void:
	root.content_scale_size = Vector2i(1440,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await ticks(10)
	var platforms: Node = game.get_node("Platforms")
	var all_modular := true
	var single_colliders := true
	var all_bounds := true
	var modules := 0
	for platform in platforms.get_children():
		var collider_count := 0
		for child in platform.get_children():
			if child is CollisionShape3D: collider_count += 1
			if child is MultiMeshInstance3D:
				all_modular = all_modular and child.multimesh.mesh.get_faces().size()>36
				modules += child.multimesh.instance_count
		single_colliders = single_colliders and collider_count==1
		all_modular = all_modular and platform.brick_bounds.size()>=12
		for brick: AABB in platform.brick_bounds:
			all_bounds = all_bounds and brick.position.x>=-platform.width/2-0.001 and brick.end.x<=platform.width/2+0.001 and brick.end.z<=0.5+0.001 and brick.end.y<=0.001
	check(all_modular and modules>800,"Terrain consists of individually transformed, truly chamfered 3D modules")
	check(single_colliders,"Every platform has exactly one uninterrupted gameplay collider")
	check(all_bounds,"Every visual brick stays inside its platform footprint and play surface")
	var small = game.get_node("Platforms/FirstLeap")
	check(small.floating and is_equal_approx(small.thickness,1.0),"Short platforms are one-course floating brick rows")
	# Real physics walk crosses each visible start-platform seam without jumping.
	game.player.reset_at(Vector3(-2.9,0.01,0))
	await ticks(6)
	Input.action_press("move_right")
	var stable := true
	for frame in 64:
		await ticks(1)
		stable = stable and game.player.is_on_floor() and absf(game.player.position.y)<0.025
	Input.action_release("move_right")
	check(stable and game.player.position.x>4.2,"Running across eight masonry seams never snags, drops, or bumps")
	await ticks(12)
	var ui: Control = game.get_node("Interface/HUD")
	var cards: Array[Node] = ui.find_children("*","PanelContainer",true,false)
	check(cards.is_empty(),"HUD and overlays contain no boxed card panels")
	check(ui.find_children("*Tutorial*","",true,false).is_empty(),"No opening tutorial banner or persistent debug controls")
	var before_pickup: int = game.coins
	for node in game.get_children():
		if node is Area3D and node.has_signal("collected") and not node.taken:
			node._collect(game.player)
			break
	check(game.coins==before_pickup+1 and game.coin_label.text=="%02d" % game.coins,"Ring pickup updates the floating zero-padded HUD counter")
	for window_size in [Vector2i(1920,1080),Vector2i(1280,800),Vector2i(960,540),Vector2i(640,360)]:
		root.size = window_size
		await ticks(2)
		var bounds := Rect2(Vector2.ZERO,root.get_visible_rect().size)
		check(controls_within(ui,bounds),"HUD stays within %dx%d window" % [window_size.x,window_size.y])
		game.set_paused(true)
		await ticks(2)
		check(controls_within(ui,bounds),"Pause menu stays within %dx%d window" % [window_size.x,window_size.y])
		game.set_paused(false)
	game.pause_button.pressed.emit()
	await ticks(2)
	check(paused and game.overlay.visible and game.resume_button.has_focus(),"Pause icon opens menu and keyboard focus moves to Continue")
	check(game.resume_button.get_theme_color("font_focus_color")==Color("284f55"),"Focused primary button retains high-contrast dark text")
	check(game.help_text.text.contains("空格") and game.help_text.text.contains("Esc"),"Movement and keyboard help is available inside pause")
	game.resume_button.pressed.emit()
	await ticks(2)
	check(not paused and not game.overlay.visible,"Continue closes pause and returns to play")
	game.finish()
	await ticks(2)
	check(game.overlay.visible and not game.resume_button.visible and not game.pause_button.visible,"Victory has one replay action and hides pause control")
	check(controls_within(ui,Rect2(Vector2.ZERO,root.get_visible_rect().size)),"Victory fits the smallest supported window")
	print("BRICK/UI RESULT: ",checks," checks, ",failures," failure(s)")
	await ticks(60)
	quit(failures)
