extends Node3D
const UI_FONT = preload("res://assets/fonts/NotoSansCJK.ttc")
const CAMERA_HEIGHT := 1.3
const CAMERA_DISTANCE := 18.0
const CAMERA_FOV := 50.0
const COIN = preload("res://scenes/coin.tscn")
@onready var player = $Player
@onready var camera: Camera3D = $Camera3D
var coins := 0
var total_coins := 0
var spawn := Vector3(0,0.1,0)
var checkpoint := false
var won := false
var elapsed := 0.0
var deaths := 0
var coin_label: Label
var progress: ProgressBar
var toast: Label
var pause_button: Button
var overlay_eyebrow: Label
var help_text: Label
var menu_column: VBoxContainer
var overlay: ColorRect
var heading: Label
var detail: Label
var resume_button: Button
var restart_button: Button
var checkpoint_flag: MeshInstance3D
var motes: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.seed = 723817
	_setup_inputs()
	_build_world()
	_build_pickups()
	_build_hazards()
	_build_ui()
	player.jumped.connect(func():
		_burst(player.position+Vector3(0,0.1,0),Color("fff1cb"),5)
		Sound.play(self,270,0.13,490,-24))
	player.landed.connect(func(): _burst(player.position+Vector3(0,0.1,0),Color("fff1cb"),4))
	camera.position = Vector3(5,CAMERA_HEIGHT,CAMERA_DISTANCE)
	camera.rotation = Vector3.ZERO
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = CAMERA_FOV
	# Optional reproducible visual review; never displayed in the shipped HUD.
	for arg in OS.get_cmdline_user_args():
		if arg == "--view=middle":
			player.reset_at(Vector3(49,0.1,0))
			camera.position.x = 53
			elapsed = 20
func _setup_inputs() -> void:
	var actions := {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE,KEY_W,KEY_UP],"pause":[KEY_ESCAPE],"restart":[KEY_R]}
	for action in actions:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)
func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("79b8c8")
	sky_mat.sky_horizon_color = Color("e6e7d2")
	sky_mat.ground_bottom_color = Color("779aab")
	sky_mat.ground_horizon_color = Color("e6e7d2")
	sky_mat.sky_curve = 0.20
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9e9ed")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	$WorldEnvironment.environment = environment
	# Real depth layers: distant scenery gets smaller in perspective, never
	# scaled up to compensate for distance. None of it intersects the play lane.
	for i in range(23):
		var x := float(i)*11-65
		var mountain := Shapes.cylinder(self,Vector3(x,-10,-55-rng.randf_range(0,12)),5,rng.randf_range(9,14),Color("91b2b5"),0)
		mountain.name = "DistantMountain%d" % i
		mountain.rotation.y = rng.randf()*TAU
		mountain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mountain.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(19):
		var x := float(i)*11-46
		var y := rng.randf_range(8.5,13.0)
		var z := rng.randf_range(-36,-23)
		for j in range(3):
			var cloud := Shapes.sphere(self,Vector3(x+j*1.15,y+sin(j*1.7)*0.3,z),Vector3(3.0,0.85,1.5),Color("f3f0dd"))
			cloud.name = "DistantCloud%d_%d" % [i,j]
			cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in range(14):
		var x := float(i)*12-40
		var y := rng.randf_range(-4.6,-2.8)
		var z := rng.randf_range(-38,-24)
		var island := Node3D.new()
		island.name = "DistantIsland%d" % i
		add_child(island)
		island.position = Vector3(x,y,z)
		Shapes.cylinder(island,Vector3(0,-0.95,0),0.65,1.9,Color("98b4ad"),2.0)
		Shapes.cylinder(island,Vector3.ZERO,2.0,0.20,Color("b5cbb2"))
	# Decorative wind-sculpted trees, always behind the playable plane.
	for location in [Vector2(-2.3,0),Vector2(20,1),Vector2(38,0),Vector2(49,0),Vector2(76,1.5),Vector2(105,1)]:
		_tree(Vector3(location.x,location.y,-1.4))
	_sign(Vector3(4.5,0,-0.8),"→")
	_sign(Vector3(30,0,-0.8),"↑")
	_checkpoint_structure()
	_goal_structure()
func _tree(pos: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	Shapes.cylinder(root,Vector3(0,1,0),0.16,2,Color("805f53"),0.1)
	Shapes.sphere(root,Vector3(-0.3,2.35,0),Vector3(2.5,2.2,1.8),Color("6eaa88"))
	Shapes.sphere(root,Vector3(0.7,2.9,0),Vector3(1.9,1.8,1.6),Color("a1c489"))
func _sign(pos: Vector3, text: String) -> void:
	Shapes.box(self,pos+Vector3(0,0.5,0),Vector3(0.10,1,0.12),Color("795e54"))
	Shapes.box(self,pos+Vector3(0,1,0),Vector3(0.9,0.62,0.16),Color("f0d6a9"))
	var label := Label3D.new()
	label.text = text
	label.font_size = 66
	label.pixel_size = 0.007
	label.modulate = Color("6a7062")
	label.outline_size = 0
	label.position = pos+Vector3(0,1,0.1)
	add_child(label)
func _checkpoint_structure() -> void:
	Shapes.cylinder(self,Vector3(49,1.6,-0.65),0.065,3.2,Color("f7e4be"))
	checkpoint_flag = Shapes.box(self,Vector3(49.55,2.65,-0.65),Vector3(1.1,0.7,0.10),Color("e98b68"))
	Shapes.cylinder(self,Vector3(49,0.07,-0.65),0.5,0.14,Color("f7e4be"))
func _goal_structure() -> void:
	for x in [103.0,106.0]:
		Shapes.box(self,Vector3(x,3,-0.4),Vector3(0.55,4,0.7),Color("f0d7b0"))
		Shapes.box(self,Vector3(x,1.15,-0.4),Vector3(0.85,0.3,0.95),Color("ca987b"))
	Shapes.box(self,Vector3(104.5,5,-0.4),Vector3(3.7,0.6,0.95),Color("f7dfb4"))
	Shapes.box(self,Vector3(104.5,5.5,-0.4),Vector3(2.5,0.4,0.75),Color("93ba8a"))
	var sun := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 0.91
	sun.mesh = torus
	sun.material_override = Shapes.material(Color("ffd47c"),0.25)
	sun.rotation.x = PI/2
	sun.position = Vector3(104.5,3.3,-0.4)
	add_child(sun)
func _build_pickups() -> void:
	var placements := [Vector2(3,1.3),Vector2(5,1.3),Vector2(8.3,2),Vector2(12,2.3),Vector2(16.3,3),Vector2(20,2.4),Vector2(23,2.4),Vector2(26.5,2.5),Vector2(30,1.3),Vector2(34,2.1),Vector2(39,1.3),Vector2(42.5,2.8),Vector2(46,2),Vector2(52,1.3),Vector2(56,2.7),Vector2(60,3.1),Vector2(64,3.9),Vector2(68,3.9),Vector2(73,3),Vector2(78,3),Vector2(82,3),Vector2(86,2.5),Vector2(90,1.6),Vector2(94,2.6),Vector2(98,3.4),Vector2(103,2.4),Vector2(106,2.4)]
	for point in placements:
		var coin = COIN.instantiate()
		coin.position = Vector3(point.x,point.y,0)
		add_child(coin)
		coin.collected.connect(_on_coin)
		total_coins += 1
	Sound.play(self,880+float(coins%4)*110,0.16,-1,-19)
func _build_hazards() -> void:
	for point in [Vector2(34,0),Vector2(77,1.5)]:
		var area := Area3D.new()
		area.position = Vector3(point.x,point.y,0)
		area.collision_layer = 0
		area.collision_mask = 1
		add_child(area)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.35,0.55,1.2)
		col.shape = shape
		col.position.y = 0.25
		area.add_child(col)
		for x in [-0.45,0.0,0.45]:
			Shapes.cylinder(area,Vector3(x,0.30,0),0.27,0.6,Color("815e6a"),0)
		area.body_entered.connect(func(body: Node):
			if body == player: respawn())
func _on_coin(coin: Area3D) -> void:
	coins += 1
	Sound.play(self,880+float(coins%4)*110,0.16,-1,-19)
	coin_label.text = "%02d" % coins
	_burst(coin.position,Color("ffd77c"),7)
func _burst(point: Vector3, color: Color, count: int) -> void:
	for i in count:
		var n := Shapes.box(self,point,Vector3.ONE*0.12,color)
		var to := point+Vector3(rng.randf_range(-0.8,0.8),rng.randf_range(0.3,1.1),rng.randf_range(-0.4,0.4))
		var t := create_tween().set_parallel(true)
		t.tween_property(n,"position",to,0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(n,"scale",Vector3.ZERO,0.42)
		t.chain().tween_callback(n.queue_free)
func _physics_process(delta: float) -> void:
	if won: return
	elapsed += delta
	if player.position.y < -9: respawn()
	if player.position.x > 48 and not checkpoint:
		checkpoint = true
		Sound.play(self,520,0.4,1040,-20)
		spawn = Vector3(49,0.15,0)
		checkpoint_flag.material_override = Shapes.material(Color("8dc3a3"))
		_show_toast("已到达检查点")
		_burst(Vector3(49,2.5,0),Color("f7dfb4"),14)
	if player.position.x > 104 and player.position.y > 0.8: finish()
	var target_x := clampf(player.position.x+3.2,5,101)
	camera.position.x = lerpf(camera.position.x,target_x,1-exp(-4.0*delta))
	# Pure horizontal follow: no pitch, orbit, or jump-driven vertical pan.
	camera.position.y = CAMERA_HEIGHT
	progress.value = clampf(player.position.x/104.0*100.0,0,100)
func respawn() -> void:
	if won: return
	deaths += 1
	Sound.play(self,300,0.25,150,-24)
	player.reset_at(spawn)
	camera.position.x = clampf(spawn.x+3.2,5,101)
	_show_toast("重新出发")
func finish() -> void:
	if won: return
	won = true
	Sound.play(self,660,0.7,990,-18)
	player.control_enabled = false
	player.velocity = Vector3.ZERO
	progress.value = 100
	_burst(player.position+Vector3(0,1,0),Color("ffd17a"),30)
	overlay_eyebrow.text = "01  /  云上花园 · 完成"
	heading.text = "抵达云端"
	detail.text = "太阳环  %02d / %02d     ·     %d:%02d" % [coins,total_coins,int(elapsed)/60,int(elapsed)%60]
	help_text.text = "把下一次跳跃，留给更好的风景。"
	pause_button.hide()
	resume_button.hide()
	restart_button.text = "再来一次"
	_button_palette(restart_button,true)
	overlay.show()
	restart_button.grab_focus()
func _show_toast(message: String) -> void:
	toast.text = message
	toast.modulate.a = 1
	var t := create_tween()
	t.tween_interval(1.8)
	t.tween_property(toast,"modulate:a",0,0.6)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not won:
		set_paused(true)
func set_paused(value: bool) -> void:
	if won: return
	get_tree().paused = value
	overlay.visible = value
	if value:
		overlay_eyebrow.text = "CLOUDSTEP  /  云间跃行"
		heading.text = "歇一会儿"
		detail.text = "风景还在，等你继续。"
		help_text.text = "A / D 或 ← / →  移动\n空格 / W / ↑  跳跃 · 长按跳得更高\nEsc  继续    ·    R  重新开始"
		resume_button.show()
		restart_button.text = "重新开始"
		resume_button.grab_focus()
func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
func _style(color: Color, radius := 20) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 25
	style.content_margin_right = 25
	style.content_margin_top = 15
	style.content_margin_bottom = 15
	return style
func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font",UI_FONT)
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",color)
	return l
func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)
	var ui := Control.new()
	ui.name = "HUD"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.set_script(preload("res://scripts/ui_input.gd"))
	ui.game = self
	canvas.add_child(ui)
	ui.set_process_unhandled_input(true)
	# Counters float directly over the world; no enclosing card or help banner.
	var row := HBoxContainer.new()
	row.name = "RingCounter"
	row.position = Vector2(36,28)
	row.add_theme_constant_override("separation",10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(row)
	row.add_child(_icon("ring",Vector2(36,48)))
	coin_label = _label("00",34,Color("335b61"))
	coin_label.name = "Count"
	_hud_shadow(coin_label)
	row.add_child(coin_label)
	var total := _label("/ %02d" % total_coins,20,Color("4c7375"))
	total.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_shadow(total)
	row.add_child(total)
	var level := VBoxContainer.new()
	level.name = "LevelProgress"
	level.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	level.position = Vector2(-105,30)
	level.size = Vector2(210,48)
	level.add_theme_constant_override("separation",8)
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(level)
	var title := _label("01  /  云上花园",16,Color("466a6e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_shadow(title)
	level.add_child(title)
	progress = ProgressBar.new()
	progress.name = "Journey"
	progress.custom_minimum_size = Vector2(210,3)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.show_percentage = false
	var track := _style(Color(0.20,0.35,0.38,0.14),2)
	var fill := _style(Color("487b78"),2)
	for style in [track,fill]:
		style.content_margin_left = 0
		style.content_margin_right = 0
		style.content_margin_top = 0
		style.content_margin_bottom = 0
	progress.add_theme_stylebox_override("background",track)
	progress.add_theme_stylebox_override("fill",fill)
	level.add_child(progress)
	pause_button = Button.new()
	pause_button.name = "Pause"
	pause_button.tooltip_text = "暂停 / Esc"
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-82,26)
	pause_button.size = Vector2(48,48)
	pause_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pause_button.add_theme_stylebox_override("normal",_style(Color(1,1,1,0),24))
	pause_button.add_theme_stylebox_override("hover",_style(Color(1,1,1,0.27),24))
	pause_button.add_theme_stylebox_override("pressed",_style(Color(0.20,0.35,0.38,0.12),24))
	pause_button.add_theme_stylebox_override("focus",_focus_style(24))
	ui.add_child(pause_button)
	var pause_icon := _icon("pause",Vector2(48,48))
	pause_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_button.add_child(pause_icon)
	pause_button.pressed.connect(func(): set_paused(true))
	toast = _label("",18,Color("335b61"))
	toast.name = "Feedback"
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-250,96)
	toast.size.x = 500
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_shadow(toast)
	ui.add_child(toast)
	# Pause and results share a cinematic scrim instead of another boxed panel.
	overlay = ColorRect.new()
	overlay.name = "MenuOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.10,0.23,0.26,0.91)
	ui.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	menu_column = VBoxContainer.new()
	menu_column.name = "MenuContent"
	menu_column.custom_minimum_size.x = 440
	menu_column.add_theme_constant_override("separation",22)
	center.add_child(menu_column)
	overlay_eyebrow = _label("CLOUDSTEP  /  云间跃行",15,Color("b8cdc4"))
	overlay_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(overlay_eyebrow)
	heading = _label("歇一会儿",52,Color("fff3d8"))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(heading)
	detail = _label("风景还在，等你继续。",20,Color("cedbd2"))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(detail)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	menu_column.add_child(spacer)
	resume_button = _button("继续冒险",true)
	resume_button.pressed.connect(func(): set_paused(false))
	menu_column.add_child(resume_button)
	restart_button = _button("重新开始",false)
	restart_button.pressed.connect(restart)
	menu_column.add_child(restart_button)
	help_text = _label("",15,Color("b8cdc4"))
	help_text.name = "MenuHelp"
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_text.add_theme_constant_override("line_spacing",6)
	menu_column.add_child(help_text)
	overlay.hide()
func _hud_shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color",Color(1,1,0.94,0.48))
	label.add_theme_constant_override("shadow_offset_x",0)
	label.add_theme_constant_override("shadow_offset_y",1)
func _icon(kind: String, minimum: Vector2) -> Control:
	var icon := Control.new()
	icon.set_script(preload("res://scripts/hud_icon.gd"))
	icon.kind = kind
	icon.custom_minimum_size = minimum
	return icon
func _focus_style(radius: int) -> StyleBoxFlat:
	var style := _style(Color(0,0,0,0),radius)
	style.border_color = Color("eed49b")
	style.set_border_width_all(2)
	return style
func _button(text: String, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",UI_FONT)
	button.custom_minimum_size.y = 58
	button.add_theme_font_size_override("font_size",20)
	_button_palette(button,primary)
	return button

func _button_palette(button: Button, primary: bool) -> void:
	button.add_theme_color_override("font_color",Color("284f55") if primary else Color("f4e8cd"))
	button.add_theme_color_override("font_focus_color",Color("284f55") if primary else Color("fff7e0"))
	button.add_theme_color_override("font_hover_color",Color("284f55") if primary else Color("fff7e0"))
	button.add_theme_color_override("font_pressed_color",Color("284f55") if primary else Color("fff7e0"))
	button.add_theme_color_override("font_hover_pressed_color",Color("284f55") if primary else Color("fff7e0"))
	button.add_theme_stylebox_override("normal",_style(Color("f3d89b") if primary else Color(1,1,1,0.04),10))
	button.add_theme_stylebox_override("hover",_style(Color("ffe7b2") if primary else Color(1,1,1,0.10),10))
	button.add_theme_stylebox_override("pressed",_style(Color("dfc28b") if primary else Color(1,1,1,0.16),10))
	button.add_theme_stylebox_override("focus",_focus_style(10))
