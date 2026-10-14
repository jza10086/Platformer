extends CharacterBody3D
## Block rewards with their own motion and single-use pickup handling.
signal picked_up(mode)
const ART = preload("res://scripts/world11_assets.gd")
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
		ART.make(visual,"star",Vector3(0,0.42,0),Vector3(0.72,0.72,0.30))
	else:
		ART.make(visual,"mushroom-single",Vector3(0,0.36,0),Vector3(0.76,0.72,0.60),"life" if mode == "life" else "")

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
