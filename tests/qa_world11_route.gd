extends SceneTree
## Complete course using normal movement/jump actions only. No position writes,
## disabled enemies, physics modifications, or direct finish calls are allowed.
var render := false
var output := "user://captures/world11"
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	if not render: return
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output+"/route-"+label+".png")
	print("ROUTE_CAPTURE ",label," ",error_string(error))
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--render": render=true
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	if render:
		DirAccess.make_dir_recursive_absolute(output)
		root.content_scale_size=Vector2i(1440,900)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
		root.size=Vector2i(1920,1080)
	var game = load("res://scenes/world11.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.set_paused(false)
	var p = game.player
	for i in 8: await physics_frame
	await capture("00-start")
	Input.action_press("move_right")
	var held := 0
	var milestones := [28.0,46.0,69.0,86.0,106.0,138.0,153.0,163.0,181.0,190.0]
	var next_milestone := 0
	var jumps := 0
	for frame in 6000:
		if held>0:
			held-=1
			if held==0: Input.action_release("jump")
		var reason := ""
		if p.is_on_floor() and held==0:
			for pipe in game.layout.pipes:
				var gap: float=pipe.x-p.position.x
				if pipe.height>p.position.y+0.10 and gap>-0.4 and gap<2.6:
					reason="pipe%d" % pipe.x
			for pit in game.DATA.PIT_RANGES:
				var gap: float=pit.x-p.position.x
				if gap>0.0 and gap<1.9: reason="pit%d" % pit.x
			for step in game.layout.stairs:
				var gap: float=step.x-p.position.x
				if step.y>p.position.y+0.10 and gap>-0.4 and gap<1.5: reason="stair%d" % step.x
			for enemy in game.enemies:
				if is_instance_valid(enemy) and not enemy.dead:
					var gap: float=enemy.position.x-p.position.x
					if gap>0 and gap<2.1 and absf(enemy.position.y-p.position.y)<1.1: reason="enemy"
			if not reason.is_empty():
				print("JUMP ",jumps," ",reason," at ",p.position," frame=",frame)
				Input.action_press("jump")
				held=44
				jumps+=1
		await physics_frame
		if frame%180==0: print("POSITION frame=",frame," p=",p.position," velocity=",p.velocity)
		if next_milestone<milestones.size() and p.position.x>=milestones[next_milestone]:
			print("MILESTONE ",milestones[next_milestone]," frame=",frame," p=",p.position)
			await capture("%02d-x%03d" % [next_milestone+1,int(milestones[next_milestone])])
			next_milestone+=1
		if game.deaths>0:
			push_error("ROUTE FAILED: death after "+str(jumps)+" jumps at frame "+str(frame)+" pos "+str(p.position))
			await capture("failure")
			quit(1)
			return
		if game.won:
			Input.action_release("move_right")
			Input.action_release("jump")
			print("PASS: input-only route reached flag: frames=",frame," jumps=",jumps," coins=",game.coins," score=",game.score," deaths=",game.deaths)
			await capture("11-flag")
			for i in 190: await physics_frame
			if not game.overlay.visible or not game.heading.text.contains("完成"):
				push_error("ROUTE FAILED: flag animation did not open completion")
				quit(1)
				return
			await capture("12-victory")
			print("PASS: flag slide/castle entry ends in completion overlay; all ",milestones.size()," course milestones crossed")
			quit(0)
			return
	push_error("ROUTE TIMED OUT at "+str(p.position))
	quit(1)
