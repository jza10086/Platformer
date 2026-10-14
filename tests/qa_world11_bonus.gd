extends SceneTree
## Entry placement is a controlled fixture. Once entry begins, coin collection
## and exit use ordinary movement/jump/down actions only.
var render := false
var output := "user://captures/world11"
func _initialize(): call_deferred("run")
func capture(label: String):
	if not render: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/bonus-"+label+".png")
func run():
	for arg in OS.get_cmdline_user_args():
		if arg=="--render": render=true
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if render:
		DirAccess.make_dir_recursive_absolute(output)
		root.content_scale_size=Vector2i(1440,900)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
		root.size=Vector2i(1920,1080)
	var game=load("res://scenes/world11.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.set_paused(false)
	var p=game.player
	p.reset_at(Vector3(58,4.01,0))
	for i in 8: await physics_frame
	Input.action_press("down")
	for i in 50: await physics_frame
	Input.action_release("down")
	if not game.underground:
		push_error("BONUS: Down entry failed")
		quit(1)
		return
	await capture("01-entry")
	var room=game.level.get_node("BonusRoom")
	var held=0
	for frame in 3600:
		if held>0:
			held-=1
			if held==0: Input.action_release("jump")
		var target: Node
		for node in room.get_children():
			if node is Area3D and not node.is_queued_for_deletion():
				if not is_instance_valid(target) or node.position.y<target.position.y-0.1 or (is_equal_approx(node.position.y,target.position.y) and absf(node.position.x-p.position.x)<absf(target.position.x-p.position.x)):
					target=node
		if not is_instance_valid(target): break
		var dx: float=target.position.x-p.position.x
		if dx>0.10:
			Input.action_press("move_right")
			Input.action_release("move_left")
		elif dx< -0.10:
			Input.action_press("move_left")
			Input.action_release("move_right")
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")
		if p.is_on_floor() and held==0 and (target.position.y>p.position.y+p.height+0.35 or p.is_on_wall()):
			Input.action_press("jump")
			held=58
		await physics_frame
		if frame%120==0: print("BONUS ",frame," p=",p.position," coins=",game.coins," target=",target.position if is_instance_valid(target) else Vector3.ZERO)
		if game.deaths>0 or not game.underground:
			push_error("BONUS: died or left room before collecting all coins")
			quit(1)
			return
	Input.action_release("jump")
	Input.action_release("move_left")
	Input.action_release("move_right")
	for i in 8: await physics_frame
	await capture("02-collected")
	if game.coins!=19:
		push_error("BONUS: expected 19 coins, got "+str(game.coins))
		quit(1)
		return
	print("PASS: all 19 bonus coins collected by movement and jumping without in-room position changes")
	Input.action_press("move_right")
	for frame in 300:
		await physics_frame
		if not game.underground and not game.warping:
			Input.action_release("move_right")
			print("PASS: bonus route exited naturally to ",p.position," coins=",game.coins," deaths=",game.deaths)
			await capture("03-return")
			for i in 75: await physics_frame
			quit(0)
			return
	push_error("BONUS: exit timed out")
	quit(1)
