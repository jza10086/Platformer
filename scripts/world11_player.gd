extends CharacterBody3D
## Feet-origin, single-plane platforming controller for the block-scale course.
signal jumped
signal landed
signal hit_block(block)
signal damaged
signal died
signal power_changed(big)

const WALK_SPEED := 5.0
const RUN_SPEED := 8.8
# 16.2 / 28 yields about 4.55 tiles at 60 Hz, clearing four-tile pipes.
const JUMP_SPEED := 16.2
const GRAVITY := 28.0
const SMALL_HEIGHT := 0.90
const BIG_HEIGHT := 1.80

var control_enabled := true
var big := false
var height := SMALL_HEIGHT
var invulnerability := 0.0
var star_time := 0.0
var dead := false
var coyote := 0.0
var buffer := 0.0
var was_grounded := false
var previous_position := Vector3.ZERO
var visual: Node3D
var collision: CollisionShape3D
var squash := Vector3.ONE
var facing := 1.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	floor_snap_length = 0.12
	floor_stop_on_slope = true
	collision = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.78, height, 0.78)
	collision.shape = box
	collision.position.y = height * 0.5
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	Shapes.box(visual, Vector3(0, 0.45, 0), Vector3(0.90, 0.90, 0.90), Color("ef795f"))
	Shapes.box(visual, Vector3(0, 0.82, 0), Vector3(0.90, 0.13, 0.90), Color("ffb884"))
	Shapes.box(visual, Vector3(0, 0.12, 0), Vector3(0.90, 0.16, 0.90), Color("c2504c"))
	for x in [-0.17, 0.17]:
		Shapes.box(visual, Vector3(x, 0.52, 0.46), Vector3(0.12, 0.19, 0.035), Color("fff4dd"))
		Shapes.box(visual, Vector3(x + 0.025, 0.52, 0.48), Vector3(0.047, 0.10, 0.018), Color("344b59"))
	Shapes.box(visual, Vector3(0, 0.30, 0.46), Vector3(0.14, 0.04, 0.03), Color("8e4646"))
	previous_position = global_position
	_update_size()

func _physics_process(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	star_time = maxf(0.0, star_time - delta)
	_update_visual(delta)
	previous_position = global_position
	if not control_enabled or dead:
		return
	var axis := Input.get_axis("move_left", "move_right")
	var running := InputMap.has_action("run") and Input.is_action_pressed("run")
	var target := axis * (RUN_SPEED if running else WALK_SPEED)
	var acceleration := 42.0 if is_on_floor() else 24.0
	if absf(axis) < 0.01:
		acceleration = 46.0 if is_on_floor() else 12.0
	velocity.x = move_toward(velocity.x, target, acceleration * delta)
	velocity.z = 0.0
	if absf(axis) > 0.1:
		facing = signf(axis)
	if is_on_floor():
		coyote = 0.10
	else:
		coyote = maxf(0.0, coyote - delta)
	buffer = maxf(0.0, buffer - delta)
	if Input.is_action_just_pressed("jump"):
		buffer = 0.14
	if buffer > 0.0 and coyote > 0.0:
		velocity.y = JUMP_SPEED
		buffer = 0.0
		coyote = 0.0
		squash = Vector3(0.88, 1.12, 0.88)
		jumped.emit()
	if Input.is_action_just_released("jump") and velocity.y > 5.5:
		velocity.y = 5.5
	if not is_on_floor() or velocity.y > 0.0:
		velocity.y -= GRAVITY * delta
	velocity.y = maxf(velocity.y, -26.0)
	var upward := velocity.y > 0.0
	var landing_speed := velocity.y
	move_and_slide()
	position.z = 0.0
	if upward:
		var bumped: Array[int] = []
		for index in get_slide_collision_count():
			var hit := get_slide_collision(index)
			var body := hit.get_collider()
			if hit.get_normal().y < -0.5 and is_instance_valid(body) and body.has_method("bump"):
				var body_id: int = body.get_instance_id()
				if not bumped.has(body_id):
					bumped.append(body_id)
					body.bump(self)
					hit_block.emit(body)
	if is_on_floor() and not was_grounded and landing_speed < -2.0:
		squash = Vector3(1.12, 0.80, 1.12)
		landed.emit()
	was_grounded = is_on_floor()

func _update_visual(delta: float) -> void:
	if not is_instance_valid(visual):
		return
	squash = squash.lerp(Vector3.ONE, 1.0 - exp(-17.0 * delta))
	visual.scale = Vector3(squash.x, squash.y * (2.0 if big else 1.0), squash.z)
	visual.rotation.z = lerp_angle(visual.rotation.z, -velocity.x * 0.012, minf(1.0, delta * 12.0))
	visual.visible = invulnerability <= 0.0 or int(invulnerability * 14.0) % 2 == 0
	if star_time > 0.0:
		visual.scale *= 1.0 + sin(star_time * 18.0) * 0.035

func _update_size() -> void:
	height = BIG_HEIGHT if big else SMALL_HEIGHT
	if is_instance_valid(collision):
		(collision.shape as BoxShape3D).size = Vector3(0.78, height, 0.78)
		collision.position.y = height * 0.5

func grow() -> void:
	if dead or big:
		return
	big = true
	_update_size()
	invulnerability = maxf(invulnerability, 0.8)
	squash = Vector3(1.12, 0.88, 1.12)
	power_changed.emit(big)

func give_star(duration := 10.0) -> void:
	star_time = maxf(star_time, duration)

func take_damage() -> void:
	if dead or not control_enabled or invulnerability > 0.0 or star_time > 0.0:
		return
	if big:
		big = false
		_update_size()
		invulnerability = 2.0
		damaged.emit()
		power_changed.emit(big)
	else:
		dead = true
		control_enabled = false
		velocity = Vector3.ZERO
		damaged.emit()
		died.emit()

func bounce(strength := 10.0) -> void:
	velocity.y = strength
	coyote = 0.0
	buffer = 0.0
	was_grounded = false
	squash = Vector3(0.88, 1.12, 0.88)

func reset_at(point: Vector3) -> void:
	global_position = point
	previous_position = point
	velocity = Vector3.ZERO
	big = false
	dead = false
	invulnerability = 0.0
	star_time = 0.0
	coyote = 0.0
	buffer = 0.0
	was_grounded = false
	control_enabled = true
	squash = Vector3.ONE
	_update_size()
	if is_instance_valid(visual):
		visual.visible = true
	power_changed.emit(big)
