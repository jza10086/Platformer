extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ",message)
	else:
		push_error("FAIL: "+message)
		failures += 1
func projected_width(camera: Camera3D, center: Vector3, width: float) -> float:
	return absf(camera.unproject_position(center+Vector3(width/2,0,0)).x-camera.unproject_position(center-Vector3(width/2,0,0)).x)
func run() -> void:
	root.size = Vector2i(1920,1080)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 20: await physics_frame
	var camera: Camera3D = game.camera
	check(camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Camera uses real perspective")
	check(camera.global_rotation.is_zero_approx(),"Camera pitch/yaw/roll are all zero: pure side view")
	var player_center: Vector3 = game.player.position+Vector3(0,0.46,0)
	var screen_y := camera.unproject_position(player_center).y / camera.get_viewport().get_visible_rect().size.y
	check(screen_y>0.52 and screen_y<0.57,"Player is framed near 55% screen height, not viewed from above")
	var near_width := projected_width(camera,Vector3(5,0,0),4)
	var far_width := projected_width(camera,Vector3(5,0,-28),4)
	check(near_width>far_width*2.4,"Equal-size near object projects over 2.4x larger than far object")
	var first_platform: Node3D = game.get_node("Platforms/FirstLeap")
	var platform_width := projected_width(camera,first_platform.position,first_platform.width)
	var background: Node3D = game.get_node("DistantIsland0")
	check(projected_width(camera,background.position,4)<platform_width*0.5,"Distant island is less than half the screen width of a small playable island")
	var body: BoxMesh = game.player.visual.get_child(0).mesh
	check(is_equal_approx(body.size.x,body.size.y) and is_equal_approx(body.size.y,body.size.z),"Character body is an exact cube")
	var start = game.get_node("Platforms/Start")
	var collision: CollisionShape3D = start.get_child(0)
	check(is_equal_approx(collision.position.z+collision.shape.size.z/2,0.5),"Platform front lip aligns with cube front instead of hiding the feet")
	var height := camera.position.y
	Input.action_press("jump")
	Input.action_press("move_right")
	for i in 25: await physics_frame
	check(is_equal_approx(camera.position.y,height) and camera.rotation.is_zero_approx(),"Jumping/running cannot introduce vertical pan or camera tilt")
	check(game.player.position.z==0,"Perspective camera preserves locked gameplay plane")
	Input.action_release("jump")
	Input.action_release("move_right")
	print("CAMERA RESULT: ",failures," failure(s)")
	for i in 60: await physics_frame
	quit(failures)
