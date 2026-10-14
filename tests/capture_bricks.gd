extends SceneTree
## Rendered QA captures. Run on a real display, not with --headless.
var output := "user://captures"
var game: Node
func _initialize() -> void: call_deferred("run")
func settle(frames := 20) -> void:
	for i in frames: await process_frame
func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var actual := screenshot.get_size()
	var error := screenshot.save_png(output+"/"+filename+"-%dx%d.png" % [actual.x,actual.y])
	if error != OK:
		push_error("Cannot save screenshot: "+error_string(error))
		quit(1)
	print("RENDER_CAPTURE ",filename," ",actual)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size = Vector2i(1440,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = Vector2i(1920,1080)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_paused(false)
	await settle(30)
	await capture("01-start")
	game.player.reset_at(Vector3(49,0.1,0))
	game.camera.position.x = 53
	await settle(90)
	await capture("02-middle")
	game.set_paused(true)
	await settle()
	await capture("03-pause")
	game.set_paused(false)
	game.player.reset_at(Vector3(100.8,1.1,0))
	game.camera.position.x = 101
	await settle(30)
	await capture("04-goal")
	game.player.reset_at(Vector3(105,1.1,0))
	await settle(30)
	await capture("05-victory")
	quit()
