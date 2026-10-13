extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	var p = game.player
	for i in 10: await physics_frame
	var launches := [5.0,13.0,24.0,32.0,39.0,44.0,53.0,59.0,67.0,75.0,81.0,92.0,98.0]
	var jump_index := 0
	var held := 0
	Input.action_press("move_right")
	for frame in 2400:
		if held>0:
			held -= 1
			if held==0: Input.action_release("jump")
		if jump_index < launches.size() and p.position.x >= launches[jump_index] and p.is_on_floor():
			print("JUMP ",jump_index," at ",p.position)
			Input.action_press("jump")
			held = 40
			jump_index += 1
		await physics_frame
		if game.deaths>0:
			push_error("Route failed near jump "+str(jump_index))
			quit(1)
			return
		if game.won:
			print("PASS: full level completed using movement and jumps only; ",game.coins," rings; ",frame," physics frames")
			Input.action_release("move_right")
			for i in 60: await physics_frame # Finish victory audio before shutdown.
			quit(0)
			return
	push_error("Route timed out at "+str(p.position))
	quit(1)
