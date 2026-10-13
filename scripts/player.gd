extends CharacterBody3D
signal jumped
signal landed
const SPEED := 7.6
const JUMP := 11.6
const GRAVITY := 28.0
var coyote := 0.0
var buffer := 0.0
var control_enabled := true
var visual: Node3D
var was_grounded := false
var squash := Vector3.ONE
func _ready() -> void:
	floor_snap_length = 0.25
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.82,0.92,0.82)
	col.shape = shape
	col.position.y = 0.46
	add_child(col)
	visual = Node3D.new()
	add_child(visual)
	Shapes.box(visual,Vector3(0,0.46,0),Vector3(0.92,0.92,0.92),Color("ed725a"))
	Shapes.box(visual,Vector3(0,0.86,0),Vector3(0.92,0.12,0.92),Color("ffb279"))
	for x in [-0.19,0.19]:
		Shapes.box(visual,Vector3(x,0.55,0.471),Vector3(0.12,0.19,0.04),Color("fff5dc"))
		Shapes.box(visual,Vector3(x+0.024,0.55,0.497),Vector3(0.045,0.1,0.015),Color("384c53"))
	Shapes.box(visual,Vector3(0,0.31,0.471),Vector3(0.13,0.035,0.035),Color("914c47"))
func _physics_process(delta: float) -> void:
	if not control_enabled: return
	var axis := Input.get_axis("move_left","move_right")
	velocity.x = move_toward(velocity.x,axis*SPEED,(48.0 if is_on_floor() else 30.0)*delta)
	velocity.z = 0
	if is_on_floor(): coyote = 0.12
	else: coyote -= delta
	buffer -= delta
	if Input.is_action_just_pressed("jump"): buffer = 0.14
	if buffer > 0 and coyote > 0:
		velocity.y = JUMP
		buffer = 0
		coyote = 0
		squash = Vector3(0.82,1.19,0.82)
		jumped.emit()
	if Input.is_action_just_released("jump") and velocity.y > 4.5: velocity.y = 4.5
	if not is_on_floor(): velocity.y -= GRAVITY*delta
	var before_y := velocity.y
	move_and_slide()
	position.z = 0
	if is_on_floor() and not was_grounded and before_y < -2:
		squash = Vector3(1.16,0.77,1.16)
		landed.emit()
	was_grounded = is_on_floor()
	squash = squash.lerp(Vector3.ONE,1-exp(-16*delta))
	visual.scale = squash
	visual.rotation.z = lerp_angle(visual.rotation.z,-velocity.x*0.018,delta*10)
	if position.x < -4: position.x = -4
func reset_at(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
	coyote = 0
	buffer = 0
	was_grounded = false
	control_enabled = true
