extends SceneTree
class Game:
	extends Node3D
	var player: CharacterBody3D
	var underground := false
	var warping := false
	var dying := false
	var won := false
	var score := 0
	var lives := 3
	func award_points(n: int) -> void: score += n
	func add_life() -> void: lives += 1
class Block:
	extends StaticBody3D
	var bumps := 0
	func bump(_p: Node) -> void: bumps += 1
var failures := 0
func _initialize() -> void: call_deferred("run")
func ticks(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1
func run() -> void:
	for action in ["move_left", "move_right", "jump", "run"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var game := Game.new()
	root.add_child(game)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(200, 1, 4)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	game.add_child(floor_body)
	var p = load("res://scripts/world11_player.gd").new()
	game.player = p
	game.add_child(p)
	await ticks(10)
	check(p.is_on_floor() and absf(p.position.y) < 0.06, "Player lands feet-on-ground")
	check(p.visual.get_child(0).mesh.size.is_equal_approx(Vector3(0.9, 0.9, 0.9)), "Player base mesh is an exact 0.9 cube")
	Input.action_press("jump")
	await ticks(32)
	check(p.position.y > 4.4 and p.position.y < 4.8, "Held jump reaches ~4.55 blocks")
	Input.action_release("jump")
	await ticks(50)
	p.reset_at(Vector3(0, 0.1, 0))
	await ticks(10)
	Input.action_press("jump")
	await ticks(3)
	Input.action_release("jump")
	await ticks(12)
	check(p.position.y < 1.5, "Release produces short jump")
	await ticks(50)
	Input.action_press("move_right")
	await ticks(30)
	check(absf(p.velocity.x - 5.0) < 0.01, "Walk is 5 units per second")
	Input.action_press("run")
	await ticks(25)
	check(absf(p.velocity.x - 8.8) < 0.01, "Run is 8.8 units per second")
	Input.action_release("move_right")
	Input.action_release("run")
	await ticks(30)
	check(absf(p.velocity.x) < 0.01 and p.position.z == 0.0, "Stop and Z lock")
	p.grow()
	check(p.big and p.height == 1.8, "Growth doubles collider height")
	p.invulnerability = 0
	p.take_damage()
	check(not p.big and p.invulnerability == 2.0, "Damage shrinks with 2-second invulnerability")
	p.take_damage()
	check(not p.dead, "Invulnerability blocks repeated damage")
	p.invulnerability = 0
	p.take_damage()
	check(p.dead and not p.control_enabled, "Small-player damage emits death state")
	p.reset_at(Vector3.ZERO)
	check(not p.dead and p.control_enabled and not p.big, "Reset restores player")
	var block := Block.new()
	block.collision_layer = 2
	block.position = Vector3(0, 3, 0)
	var block_shape := CollisionShape3D.new()
	block_shape.shape = BoxShape3D.new()
	block.add_child(block_shape)
	game.add_child(block)
	await ticks(10)
	Input.action_press("jump")
	await ticks(30)
	Input.action_release("jump")
	check(block.bumps == 1, "Upward impact bumps block once")
	block.queue_free()
	await ticks(40)
	var e = load("res://scripts/world11_enemy.gd").new()
	e.configure("goomba", game)
	e.position = Vector3(40, 0, 0)
	game.add_child(e)
	await ticks(5)
	check(not e.active and e.position.x == 40.0, "Off-screen enemy stays dormant")
	for flag in ["underground", "warping", "dying", "won"]:
		game.set(flag, true)
		p.position = Vector3(302, 0, 0)
		var old_age: float = e.age
		await ticks(3)
		check(is_instance_valid(e) and not e.active and e.position.x == 40.0 and e.age == old_age, "Enemy fully freezes for " + flag)
		game.set(flag, false)
	p.reset_at(Vector3(30, 0, 0))
	await ticks(5)
	check(e.active and e.position.x < 40.0, "Nearby enemy activates walking")
	p.set_physics_process(false)
	p.position = e.position + Vector3(0, e.height - 0.1, 0)
	p.previous_position = e.position + Vector3(0, e.height + 0.05, 0)
	p.velocity.y = -3
	e._check_player_contact(p)
	check(e.dead and p.velocity.y > 0 and game.score == 100, "Stomp defeats enemy, bounces, scores once")
	var turtle = load("res://scripts/world11_enemy.gd").new()
	turtle.configure("turtle", game)
	turtle.position = Vector3(32, 0, 0)
	game.add_child(turtle)
	p.position = turtle.position + Vector3(0, turtle.height - 0.1, 0)
	p.previous_position = turtle.position + Vector3(0, turtle.height + 0.05, 0)
	p.velocity.y = -3
	turtle._check_player_contact(p)
	check(turtle.shell and not turtle.dead and turtle.height == 0.7, "Turtle stomp enters shell")
	turtle.contact_cooldown = 0
	p.position = turtle.position + Vector3(-0.5, 0, 0)
	p.previous_position = p.position
	p.velocity.y = 0
	turtle._check_player_contact(p)
	check(turtle.shell_moving and turtle.direction == 1, "Side contact kicks stationary shell away")
	for mode in ["mushroom", "star", "life"]:
		var item = load("res://scripts/world11_item.gd").new()
		item.configure(mode, game)
		game.add_child(item)
		item.pickup(p)
		var score: int = game.score
		item.pickup(p)
		check(game.score == score, "Item pickup is single-use: " + mode)
	check(p.big and p.star_time == 10.0 and game.lives == 4, "Rewards grant growth, star and extra life")
	print("RESULT: ", failures, " failures")
	quit(failures)
