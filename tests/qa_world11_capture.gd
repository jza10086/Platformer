extends SceneTree
## Native renderer captures only; this is not route-completion evidence.
var output := "user://captures/world11"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size = Vector2i(1440,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = Vector2i(1920,1080)
	var game = load("res://scenes/world11.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_paused(false)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/01-start-native.png")
	print("CAPTURE start-native ",root.size)
	game.set_paused(true)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/02-pause-native.png")
	print("CAPTURE pause-native ",root.size)
	quit()
