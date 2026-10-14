extends CharacterBody3D
## Original cuboid critters. Contact is resolved independently of world collision.
signal defeated(enemy)
const GRAVITY := 28.0
var kind := "goomba"
var owner_game: Node
var direction := -1.0
var active := false
var dead := false
var shell := false
var shell_moving := false
var contact_cooldown := 0.0
var death_time := 0.0
var age := 0.0
var height := 0.76
var visual: Node3D
var collision: CollisionShape3D

func configure(new_kind: String, game: Node) -> void:
	kind = new_kind
	owner_game = game

func _ready() -> void:
	add_to_group("world11_enemies")
	collision_layer = 4
	collision_mask = 2
	floor_snap_length = 0.12
	height = 1.15 if kind == "turtle" else 0.76
	collision = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.72, height, 0.70)
	collision.shape = box
	collision.position.y = height * 0.5
	add_child(collision)
	_build_visual()

func _build_visual() -> void:
	if is_instance_valid(visual):
		visual.queue_free()
	visual = Node3D.new()
	add_child(visual)
	if kind == "turtle":
		Shapes.box(visual, Vector3(0, 0.39, 0), Vector3(0.74, 0.64, 0.72), Color("4d9e87"))
		Shapes.box(visual, Vector3(0, 0.42, 0.365), Vector3(0.54, 0.40, 0.035), Color("86c796"))
		if not shell:
			Shapes.box(visual, Vector3(-0.11, 0.92, 0), Vector3(0.54, 0.45, 0.57), Color("e3c17c"))
			for x in [-0.22, 0.04]:
				Shapes.box(visual, Vector3(x, 0.97, 0.298), Vector3(0.09, 0.13, 0.026), Color("243e49"))
	else:
		Shapes.box(visual, Vector3(0, 0.45, 0), Vector3(0.76, 0.59, 0.71), Color("a67c97"))
		Shapes.box(visual, Vector3(0, 0.69, 0), Vector3(0.79, 0.12, 0.73), Color("c79fb5"))
		for x in [-0.19, 0.19]:
			Shapes.box(visual, Vector3(x, 0.46, 0.367), Vector3(0.16, 0.17, 0.035), Color("fff0d9"))
			Shapes.box(visual, Vector3(x - 0.025, 0.45, 0.392), Vector3(0.06, 0.10, 0.02), Color("493b54"))
	if not shell:
		for x in [-0.23, 0.23]:
			Shapes.box(visual, Vector3(x, 0.085, 0.08), Vector3(0.29, 0.17, 0.65), Color("5a5162"))

func _physics_process(delta: float) -> void:
	# Bonus rooms use remote coordinates; freeze the overworld without waking
	# or culling its residents until the player returns. Missing mock flags are null.
	if is_instance_valid(owner_game):
		for flag in ["underground", "warping", "dying", "won"]:
			if owner_game.get(flag) == true:
				return
	age += delta
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	if dead:
		death_time -= delta
		if death_time <= 0.0:
			queue_free()
		return
	var player := _player()
	if not is_instance_valid(player):
		return
	if not active:
		if global_position.x > player.global_position.x + 15.0:
			return
		active = true
	if global_position.y < -12.0 or global_position.x < player.global_position.x - 32.0:
		queue_free()
		return
	var speed := 1.65 if kind == "turtle" else 1.4
	if shell:
		speed = 9.5 if shell_moving else 0.0
	velocity.x = direction * speed
	velocity.y = maxf(velocity.y - GRAVITY * delta, -24.0)
	velocity.z = 0.0
	move_and_slide()
	position.z = 0.0
	if is_on_wall():
		direction *= -1.0
	if not shell:
		visual.rotation.z = sin(age * 9.0) * 0.045
	else:
		visual.rotation.y += delta * (14.0 if shell_moving else 0.0)
	_check_player_contact(player)
	if shell_moving and not dead:
		for other in get_tree().get_nodes_in_group("world11_enemies"):
			if other != self and not other.dead and global_position.distance_to(other.global_position) < 0.85:
				other.defeat(200)

func _player() -> CharacterBody3D:
	if not is_instance_valid(owner_game):
		return null
	return owner_game.get("player") as CharacterBody3D

func _check_player_contact(player: CharacterBody3D) -> void:
	if not player.control_enabled or player.dead or contact_cooldown > 0.0:
		return
	var feet: Vector3 = player.global_position
	if absf(feet.x - global_position.x) > 0.70 or absf(feet.z - global_position.z) > 0.70:
		return
	if feet.y > global_position.y + height + 0.12 or feet.y + player.height < global_position.y + 0.10:
		return
	if player.star_time > 0.0:
		defeat(200)
		return
	var top := global_position.y + height
	var previous_feet: Vector3 = player.previous_position
	var stomp: bool = player.velocity.y <= 0.5 and previous_feet.y >= top - 0.22 and feet.y >= top - 0.33
	if stomp:
		player.global_position.y = maxf(player.global_position.y, top)
		player.bounce(10.5)
		contact_cooldown = 0.22
		if kind == "turtle":
			if not shell:
				_enter_shell()
			elif shell_moving:
				shell_moving = false
			else:
				_kick(player)
		else:
			defeat(100)
	elif shell and not shell_moving:
		_kick(player)
	else:
		player.take_damage()

func _enter_shell() -> void:
	shell = true
	shell_moving = false
	height = 0.70
	(collision.shape as BoxShape3D).size.y = height
	collision.position.y = height * 0.5
	_build_visual()
	_award(100)

func _kick(player: CharacterBody3D) -> void:
	shell_moving = true
	direction = 1.0 if player.global_position.x <= global_position.x else -1.0
	contact_cooldown = 0.25
	_award(100)

func defeat(points := 100) -> void:
	if dead:
		return
	dead = true
	death_time = 0.28
	velocity = Vector3.ZERO
	collision_layer = 0
	visual.scale.y = 0.22
	_award(points)
	defeated.emit(self)

func _award(points: int) -> void:
	if is_instance_valid(owner_game) and owner_game.has_method("award_points"):
		owner_game.award_points(points)
