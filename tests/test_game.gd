extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func ticks(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await ticks(10)
	var p = game.player
	check(p.is_on_floor(),"CharacterBody lands on start island")
	check(abs(p.position.y)<0.06,"Player collision matches island top")
	Input.action_press("jump")
	await ticks(20)
	check(p.position.y>1.6,"Held jump reaches useful height")
	Input.action_release("jump")
	await ticks(45)
	check(p.is_on_floor(),"Jump lands without penetration")
	p.reset_at(Vector3(0,0.1,0))
	await ticks(8)
	Input.action_press("jump")
	await ticks(3)
	Input.action_release("jump")
	await ticks(10)
	check(p.position.y<1.4,"Released jump is shorter")
	await ticks(45)
	Input.action_press("move_right")
	await ticks(15)
	check(p.velocity.x>7,"Acceleration reaches running speed")
	Input.action_release("move_right")
	await ticks(15)
	check(abs(p.velocity.x)<0.1,"Friction stops horizontal movement")
	check(p.position.z==0,"Character stays on the 2.5D plane")
	# Walk off the first ledge, then request jump inside the 120ms grace window.
	p.reset_at(Vector3(5.9,0.01,0))
	await ticks(5)
	Input.action_press("move_right")
	while p.is_on_floor(): await ticks(1)
	await ticks(3)
	Input.action_press("jump")
	await ticks(3)
	check(p.velocity.y>8,"Coyote jump works after leaving a ledge")
	Input.action_release("jump")
	Input.action_release("move_right")
	p.reset_at(Vector3(0,0.35,0))
	p.velocity.y = -5
	Input.action_press("jump")
	await ticks(6)
	check(p.velocity.y>7,"Buffered jump fires on landing")
	Input.action_release("jump")
	p.reset_at(Vector3(0,0.05,0))
	await ticks(10)
	var coin: Area3D
	for node in game.get_children():
		if node is Area3D and node.has_signal("collected"):
			coin = node
			break
	var before: int = game.coins
	coin._collect(p)
	coin._collect(p)
	check(game.coins==before+1,"Coin can be awarded only once")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await ticks(2)
	check(paused,"Escape input opens pause")
	if not paused: game.set_paused(true)
	var pos: Vector3 = p.position
	Input.action_press("move_right")
	await ticks(20)
	check(p.position==pos,"Pause freezes simulation")
	Input.action_release("move_right")
	game.set_paused(false)
	p.reset_at(Vector3(49,0.1,0))
	await ticks(10)
	check(game.checkpoint,"Crossing flag activates checkpoint")
	p.position = Vector3(60,-12,0)
	await ticks(4)
	check(abs(p.position.x-49)<0.1 and p.position.y>-1,"Falling respawns at checkpoint")
	p.reset_at(Vector3(77,1.51,0))
	await ticks(10)
	check(abs(p.position.x-49)<0.1,"Spikes respawn player")
	p.reset_at(Vector3(105,1.1,0))
	await ticks(5)
	check(game.won and game.overlay.visible,"Goal opens victory overlay")
	check(not p.control_enabled,"Victory stops player control")
	game.restart()
	await ticks(10)
	check(not current_scene.won and current_scene.coins==0 and not current_scene.checkpoint,"Restart clears all run state")
	print("RESULT: ",failures," failure(s)")
	await ticks(60) # Let the dummy audio mixer release its final playback.
	quit(failures)
