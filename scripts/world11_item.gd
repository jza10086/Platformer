extends CharacterBody3D
## Block rewards with their own motion and single-use pickup handling.
signal picked_up(mode)
const GRAVITY := 24.0
var mode := "mushroom"
var owner_game: Node
var direction := 1.0
var collected := false
var age := 0.0
var visual: Node3D

func configure(new_mode: String, game: Node) -> void:
	mode = new_mode
	owner_game = game

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	floor_snap_length = 0.10
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.65, 0.72, 0.65)
	collision.shape = box
	collision.position.y = 0.36
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	if mode == "star":
		var core := Shapes.box(visual, Vector3(0, 0.42, 0), Vector3(0.43, 0.43, 0.30), Color("ffe17d"))
		core.rotation.z = PI / 4.0
		Shapes.box(visual, Vector3(0, 0.42, 0), Vector3(0.72, 0.16, 0.28), Color("fff0a8"))
		Shapes.box(visual, Vector3(0, 0.42, 0), Vector3(0.16, 0.72, 0.28), Color("fff0a8"))
	else:
		var cap_color := Color("76c9a1") if mode == "life" else Color("f1aa64")
		Shapes.box(visual, Vector3(0, 0.22, 0), Vector3(0.42, 0.44, 0.44), Color("fff0cf"))
		Shapes.box(visual, Vector3(0, 0.57, 0), Vector3(0.76, 0.30, 0.72), cap_color)
		Shapes.box(visual, Vector3(-0.18, 0.60, 0.368), Vector3(0.17, 0.12, 0.025), Color("fff1cf"))
		Shapes.box(visual, Vector3(0.18, 0.60, 0.368), Vector3(0.17, 0.12, 0.025), Color("fff1cf"))
	for x in [-0.09, 0.09]:
		Shapes.box(visual, Vector3(x, 0.30, 0.235), Vector3(0.05, 0.09, 0.025), Color("415262"))

func _physics_process(delta: float) -> void:
	if collected:
		return
	age += delta
	velocity.x = direction * (3.8 if mode == "star" else 2.5)
	velocity.y = maxf(velocity.y - GRAVITY * delta, -24.0)
	if mode == "star" and is_on_floor():
		velocity.y = 8.0
	velocity.z = 0.0
	move_and_slide()
	position.z = 0.0
	if is_on_wall():
		direction *= -1.0
	if mode == "star":
		visual.rotation.y += delta * 3.0
	if global_position.y < -12.0:
		queue_free()
		return
	if age < 0.12 or not is_instance_valid(owner_game):
		return
	var player := owner_game.get("player") as CharacterBody3D
	if not is_instance_valid(player) or not player.control_enabled or player.dead:
		return
	if absf(player.global_position.x - global_position.x) > 0.72:
		return
	if absf(player.global_position.z - global_position.z) > 0.75:
		return
	if player.global_position.y > global_position.y + 0.76 or player.global_position.y + player.height < global_position.y:
		return
	pickup(player)

func pickup(player: CharacterBody3D) -> void:
	if collected:
		return
	collected = true
	match mode:
		"mushroom":
			player.grow()
			_award(1000)
		"star":
			player.give_star(10.0)
			_award(1000)
		"life":
			if is_instance_valid(owner_game) and owner_game.has_method("add_life"):
				owner_game.add_life()
			else:
				_award(1000)
		_:
			if is_instance_valid(owner_game) and owner_game.has_method("add_coin"):
				owner_game.add_coin()
	picked_up.emit(mode)
	queue_free()

func _award(points: int) -> void:
	if is_instance_valid(owner_game) and owner_game.has_method("award_points"):
		owner_game.award_points(points)
