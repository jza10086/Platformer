extends SceneTree
## Independent feature QA. Controlled player placements isolate interactions;
## complete, unmodified-start traversal is covered separately by qa_world11_route.
var failures := 0
var checks := 0
var game: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: "+label)
func ticks(count: int) -> void:
	for i in count: await physics_frame
func fresh(freeze_enemies := true) -> void:
	paused = false
	for action in ["move_left","move_right","jump","run","down"]:
		if InputMap.has_action(action): Input.action_release(action)
	if is_instance_valid(game):
		root.remove_child(game)
		game.queue_free()
		await process_frame
	game = load("res://scenes/world11.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	if freeze_enemies:
		for enemy in game.enemies: enemy.set_physics_process(false)
	await ticks(8)
func keyboard(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await ticks(1)
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await ticks(1)
func controls_within(node: Node, bounds: Rect2) -> bool:
	if node is Control and node.is_visible_in_tree() and node.size.length()>0:
		if not bounds.grow(1).encloses(node.get_global_rect()):
			print("OVERFLOW ",node.name," ",node.get_global_rect()," in ",bounds)
			return false
	for child in node.get_children():
		if not controls_within(child,bounds): return false
	return true
func block_at(x: int, y: int) -> Node:
	return game.level.get_node("InteractiveBlocks/Block_%d_%d" % [x,y])
func make_enemy(kind: String, point: Vector3) -> Node:
	var enemy = game.ENEMY.new()
	enemy.configure(kind,game)
	enemy.position = point
	game.level.add_child(enemy)
	return enemy
func run() -> void:
	root.content_scale_size = Vector2i(1440,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = Vector2i(1920,1080)
	await fresh()
	var layout: Dictionary = game.layout
	check(layout.ground == [Vector2i(0,69),Vector2i(71,86),Vector2i(89,153),Vector2i(155,208)],"Exact 208-column ground and 2/3/2-tile pits")
	var expected_pipes := {28:2,38:3,46:4,57:4,163:2,179:2}
	var pipes_ok: bool = layout.pipes.size()==6
	for pipe in layout.pipes: pipes_ok = pipes_ok and expected_pipes.get(pipe.x,-1)==pipe.height
	check(pipes_ok,"All six 2-tile-wide pipes match reference positions/heights")
	var expected_stairs := [Vector2i(134,1),Vector2i(135,2),Vector2i(136,3),Vector2i(137,4),Vector2i(140,4),Vector2i(141,3),Vector2i(142,2),Vector2i(143,1),Vector2i(148,1),Vector2i(149,2),Vector2i(150,3),Vector2i(151,4),Vector2i(152,4),Vector2i(155,4),Vector2i(156,3),Vector2i(157,2),Vector2i(158,1),Vector2i(181,1),Vector2i(182,2),Vector2i(183,3),Vector2i(184,4),Vector2i(185,5),Vector2i(186,6),Vector2i(187,7),Vector2i(188,8),Vector2i(189,8),Vector2i(198,1)]
	check(layout.stairs==expected_stairs,"All stair columns and flag base match reference")
	var expected_cells := {"16,3":"question:coin","20,3":"brick:","21,3":"question:mushroom","22,3":"brick:","23,3":"question:coin","24,3":"brick:","22,7":"question:coin","64,4":"question:life","77,3":"brick:","78,3":"question:mushroom","79,3":"brick:","94,3":"brick:coin","94,7":"question:coin","100,3":"brick:","101,3":"brick:star","106,3":"question:coin","109,3":"question:coin","109,7":"question:mushroom","112,3":"question:coin","118,3":"brick:","129,3":"brick:","130,3":"brick:","129,7":"question:coin","130,7":"question:coin","168,3":"brick:","169,3":"brick:","170,3":"question:coin","171,3":"brick:"}
	for x in [80,81,82,83,84,85,86,87,91,92,93,121,122,123,128,131]: expected_cells["%d,7" % x]="brick:"
	var cells_ok: bool = layout.blocks.size()==44
	for cell in layout.blocks: cells_ok = cells_ok and expected_cells.get("%d,%d" % [cell.x,cell.y],"NO")==cell.kind+":"+cell.reward
	check(cells_ok,"All 44 brick/question/secret cells match the independent map oracle")
	check(block_at(64,4).hidden and block_at(64,4).collision_layer==0,"1-UP block is initially hidden, one row above ordinary blocks")
	var goombas := 0
	var turtles := 0
	var elevated := 0
	for enemy in layout.enemies:
		if enemy.kind=="goomba": goombas += 1
		if enemy.kind=="turtle": turtles += 1
		if enemy.y>8: elevated += 1
	check(goombas==16 and turtles==1 and elevated==2,"16 walking enemies + 1 turtle; two enemies supported on high blocks")
	var tiles := 0
	var tiles_ok := true
	for tile in game.level.get_node("GroundTiles").get_children():
		if tile is MeshInstance3D:
			tiles += 1
			tiles_ok = tiles_ok and tile.scale.is_equal_approx(Vector3.ONE*0.982) and is_equal_approx(fmod(tile.position.x,1),0.5) and is_equal_approx(absf(fmod(tile.position.y,1)),0.5)
	check(tiles_ok and tiles==402,"Ground is 402 independent equal-size 3D tiles on the grid")
	var p = game.player
	check(p.is_on_floor() and absf(p.position.y)<0.01,"Player settles on the ground without penetration")
	var cube: BoxMesh = p.visual.get_child(0).mesh
	check(cube.size.is_equal_approx(Vector3.ONE*0.90),"Small character body remains an exact cube")
	check(game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and game.camera.rotation.is_zero_approx(),"Real perspective camera stays at zero pitch/yaw/roll")
	Input.action_press("move_right")
	var seams_ok := true
	for i in 100:
		await ticks(1)
		seams_ok = seams_ok and p.is_on_floor() and absf(p.position.y)<0.01
	Input.action_release("move_right")
	check(seams_ok and p.position.x>10,"Walking across tile seams does not bump or snag")
	await ticks(12)
	p.reset_at(Vector3(16.5,0.01,0))
	await ticks(5)
	Input.action_press("jump")
	await ticks(30)
	Input.action_release("jump")
	check(block_at(16,3).used and game.coins==1 and game.score==200,"Physical head collision awards a question-block coin")
	await ticks(40)
	block_at(16,3).bump(p)
	block_at(16,3).bump(p)
	check(game.coins==1,"Repeated hits on a used block cannot duplicate its reward")
	var camera_y: float = game.camera.position.y
	check(p.position.z==0 and game.camera.rotation.is_zero_approx() and is_equal_approx(game.camera.position.y,camera_y),"Jumping preserves horizontal camera and locked depth")
	await fresh()
	p = game.player
	var growth = block_at(21,3)
	growth.bump(p)
	var item: Node
	for child in game.level.get_children():
		if child.get_script()==game.ITEM: item=child
	check(is_instance_valid(item) and item.mode=="mushroom","Growth question block emits an actual moving pickup")
	var old_score: int = game.score
	item.pickup(p)
	item.pickup(p)
	check(p.big and is_equal_approx(p.height,1.8) and game.score==old_score+1000,"Mushroom grows collision/body once and cannot duplicate score")
	var brick = block_at(20,3)
	old_score = game.score
	brick.bump(p)
	brick.bump(p)
	check(brick.is_queued_for_deletion() and game.score==old_score+50,"Big character breaks a brick once, even with same-frame repeated contact")
	p.invulnerability=0
	p.take_damage()
	check(not p.big and not p.dead and p.invulnerability>1.9,"Damage shrinks a grown character and grants invulnerability")
	p.take_damage()
	check(not p.dead and game.lives==3,"Repeated damage during invulnerability does not cost another life")
	p.give_star(1)
	p.invulnerability=0
	p.take_damage()
	check(not p.dead and p.star_time>0,"Star prevents contact damage")
	await fresh()
	p = game.player
	var enemy = make_enemy("goomba",Vector3(10,0.01,0))
	p.reset_at(Vector3(9.8,2.0,0))
	p.velocity.y=-4
	var stomped := false
	for i in 40:
		await ticks(1)
		if is_instance_valid(enemy) and enemy.dead: stomped=true
	check(stomped and game.deaths==0 and game.score==100,"Descending real physics contact stomps an enemy instead of hurting the player")
	await fresh()
	p = game.player
	enemy = make_enemy("goomba",Vector3(3.0,0.01,0))
	await ticks(5)
	check(game.deaths==1 and game.lives==2 and game.dying,"Side contact with a small player starts exactly one death")
	await ticks(60)
	check(not game.dying and p.position.distance_to(Vector3(2.5,0,0))<0.2,"Death rebuilds level and respawns at the start")
	await fresh()
	p = game.player
	var multi = block_at(94,3)
	for i in 12:
		multi.bump(p)
		await ticks(15)
	check(game.coins==10 and multi.used,"Multi-coin brick stops at its configured ten rewards")
	await fresh()
	p = game.player
	p.reset_at(Vector3(64.5,0.01,0))
	await ticks(5)
	Input.action_press("jump")
	await ticks(28)
	Input.action_release("jump")
	check(not block_at(64,4).hidden and block_at(64,4).used,"Upward input reveals and consumes the hidden 1-UP block")
	await fresh(false)
	p = game.player
	p.reset_at(Vector3(58,4.01,0))
	await ticks(5)
	Input.action_press("down")
	await ticks(50)
	Input.action_release("down")
	check(game.underground and not game.warping and p.position.x>300,"Down on the fourth pipe enters the bonus room through gameplay input")
	var room = game.level.get_node("BonusRoom")
	var room_coins := 0
	for node in room.get_children():
		if node is Area3D: room_coins += 1
	check(room_coins==19,"Bonus room contains the original 7+7+5 coin arrangement")
	var enemy_positions: Array[Vector3] = []
	for e in game.enemies:
		if is_instance_valid(e): enemy_positions.append(e.position)
	await ticks(30)
	var frozen := true
	var ei := 0
	for e in game.enemies:
		if is_instance_valid(e):
			frozen = frozen and e.position==enemy_positions[ei]
			ei += 1
	check(frozen,"Overworld enemies remain frozen while the player is underground")
	p.reset_at(Vector3(311.2,0.01,0))
	await ticks(5)
	Input.action_press("move_right")
	await ticks(40)
	Input.action_release("move_right")
	check(not game.underground and not game.warping and p.position.x>163 and p.position.x<167,"Walking into the underground exit returns to the fifth pipe")
	await fresh()
	p = game.player
	await keyboard(KEY_ESCAPE)
	check(paused and game.overlay.visible,"Actual Escape input opens pause")
	var position_before: Vector3 = p.position
	var time_before: float = game.remaining_time
	Input.action_press("move_right")
	await ticks(30)
	Input.action_release("move_right")
	check(p.position==position_before and game.remaining_time==time_before,"Pause freezes player and countdown")
	await keyboard(KEY_ESCAPE)
	check(not paused and not game.overlay.visible,"Actual Escape input resumes play")
	game.coins=3
	game.set_paused(true)
	await keyboard(KEY_R)
	await ticks(8)
	game=current_scene
	p=game.player
	check(not paused and game.coins==0 and game.lives==3,"Actual R key reloads a paused scene and resets state")
	for size in [Vector2i(1920,1080),Vector2i(1280,800),Vector2i(960,540),Vector2i(640,360)]:
		root.size=size
		await ticks(2)
		var bounds := Rect2(Vector2.ZERO,root.get_visible_rect().size)
		check(controls_within(game.get_node("Interface"),bounds),"HUD fits %dx%d" % [size.x,size.y])
		game.set_paused(true)
		await ticks(2)
		check(controls_within(game.get_node("Interface"),bounds),"Pause fits %dx%d" % [size.x,size.y])
		game.set_paused(false)
	await fresh()
	game.coins=7
	game.score=1400
	game.player.position=Vector3(70,-7,0)
	await ticks(2)
	check(game.deaths==1 and game.lives==2,"Falling into a real pit costs one life")
	await ticks(60)
	check(game.coins==7 and game.score==1400 and game.remaining_time>395,"Respawn preserves earned score/coins and resets time")
	game.remaining_time=0.01
	await ticks(3)
	check(game.deaths==2 and game.lives==1,"Timeout costs exactly one life")
	await ticks(60)
	game.remaining_time=0.01
	await ticks(70)
	check(game.lives==0 and game.overlay.visible and not game.resume_button.visible and not game.player.control_enabled,"Last life shows game over with replay and no Continue")
	game.restart_button.pressed.emit()
	await ticks(12)
	game=current_scene
	check(game.lives==3 and game.coins==0 and game.score==0 and not game.won and not game.dying,"Replay fully resets lives, score, coins and terminal state")
	print("WORLD11 FEATURE RESULT: ",checks," checks; ",failures," failure(s)")
	await ticks(75) # Finish transient audio/tweens before engine shutdown.
	quit(failures)
