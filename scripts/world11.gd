extends Node3D
const GPDPlatformSound: Script = preload("res://games/minigame/godot_party_default_platformer/scripts/sound.gd")
const GPDPlatformShapes: Script = preload("res://games/minigame/godot_party_default_platformer/scripts/shapes.gd")
var party_input: PartyInput
## A grid-built 3D interpretation of the NES World 1-1 map.
const DATA: Script = preload("res://games/minigame/godot_party_default_platformer/scripts/world11_data.gd")
const BLOCK: Script = preload("res://games/minigame/godot_party_default_platformer/scripts/world11_block.gd")
const ENEMY: Script = preload("res://games/minigame/godot_party_default_platformer/scripts/world11_enemy.gd")
const ITEM: Script = preload("res://games/minigame/godot_party_default_platformer/scripts/world11_item.gd")
const ART: Script = preload("res://games/minigame/godot_party_default_platformer/scripts/world11_assets.gd")
const UI_FONT: Resource = preload("res://games/minigame/godot_party_default_platformer/assets/fonts/NotoSansCJK.ttc")
const CAMERA_HEIGHT: float = 5.0
const CAMERA_DISTANCE: float = 16.0
const CAMERA_FOV: float = 46.0
@onready var player: Variant = $Player
@onready var camera: Camera3D = $Camera3D
var layout: Dictionary
var level: Node3D
var enemies: Array[Node] = []
var hidden_blocks: Array[Node] = []
var flag: MeshInstance3D
var coins: int = 0
var score: int = 0
var lives: int = 3
var remaining_time: float = 400.0
var won: bool = false
var dying: bool = false
var underground: bool = false
var warping: bool = false
var deaths: int = 0
var elapsed: float = 0.0
var score_label: Label
var coin_label: Label
var time_label: Label
var life_label: Label
var toast: Label
var overlay: ColorRect
var heading: Label
var detail: Label
var help_text: Label
var resume_button: Button
var restart_button: Button
var pause_button: Button
var cube_mesh: ArrayMesh
var material_cache: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	rng.seed = 1101
	_setup_inputs()
	cube_mesh = GPDPlatformShapes.chamfered_cube(0.025)
	layout = DATA.layout()
	_environment()
	_build_level()
	_build_ui()
	player.jumped.connect(func() -> void: GPDPlatformSound.play(self,270,0.12,530,-25))
	player.died.connect(respawn)
	player.damaged.connect(func() -> void: GPDPlatformSound.play(self,420,0.18,150,-23))
	player.power_changed.connect(func(big: bool):
		if big: _show_toast("能量提升"))
	camera.position = Vector3(_camera_min_x(),CAMERA_HEIGHT,CAMERA_DISTANCE)
	camera.rotation = Vector3.ZERO
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = CAMERA_FOV
	for arg: Variant in OS.get_cmdline_user_args():
		if arg.begins_with("--world-view="):
			var view: Variant = arg.trim_prefix("--world-view=")
			var point: Vector3 = {"start":Vector3(2.5,0.1,0),"middle":Vector3(100,0.1,0),"stairs":Vector3(145,0.1,0),"end":Vector3(177,0.1,0)}.get(view,Vector3(2.5,0.1,0))
			player.reset_at(point)
			camera.position.x = _camera_target(point.x)
func _camera_min_x() -> float:
	var size: Variant = get_viewport().get_visible_rect().size
	return (CAMERA_DISTANCE+0.6)*tan(deg_to_rad(CAMERA_FOV*0.5))*size.x/maxf(size.y,1)
func _camera_target(player_x: float) -> float:
	var extent: Variant = _camera_min_x()
	return clampf(player_x+5,extent,208-extent)
func _setup_inputs() -> void:
	pass

func _environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("73b9de")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9edff")
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	$WorldEnvironment.environment = environment
func _build_level() -> void:
	level = Node3D.new()
	level.name = "TileWorld"
	add_child(level)
	enemies.clear()
	hidden_blocks.clear()
	var ground: Node3D = Node3D.new()
	ground.name = "GroundTiles"
	level.add_child(ground)
	var soil_backing: Node3D = Node3D.new()
	soil_backing.name = "SoilBacking"
	ground.add_child(soil_backing)
	for segment: Variant in layout.ground:
		# Non-colliding earth behind the seams, bounded to each real ground segment.
		GPDPlatformShapes.box(soil_backing,Vector3((segment.x+segment.y)*0.5,-1.05,-0.46),Vector3(segment.y-segment.x,2.08,0.05),Color("90543a"))
		for x: Variant in range(segment.x,segment.y):
			for y: Variant in [-1,-2]:
				var shade: Color = [Color("c98c54"),Color("c88a51"),Color("d49459")][posmod(x+y,3)]
				tile_mesh(ground,Vector3(x+0.5,y+0.5,0),shade,"block-grass" if y == -1 else "brick")
		_static_box(ground,Vector3((segment.x+segment.y)*0.5,-1,0),Vector3(segment.y-segment.x,2,1))
	var stairs_root: Node3D = Node3D.new()
	stairs_root.name = "StairTiles"
	level.add_child(stairs_root)
	for step: Variant in layout.stairs:
		for y: Variant in step.y:
			tile_mesh(stairs_root,Vector3(step.x+0.5,y+0.5,0),Color("b58154"))
		_static_box(stairs_root,Vector3(step.x+0.5,step.y*0.5,0),Vector3(1,step.y,1))
	var blocks_root: Node3D = Node3D.new()
	blocks_root.name = "InteractiveBlocks"
	level.add_child(blocks_root)
	for cell: Variant in layout.blocks:
		var block: Variant = BLOCK.new()
		block.configure(cell,self)
		block.name = "Block_%d_%d" % [cell.x,cell.y]
		block.position = Vector3(cell.x+0.5,cell.y+0.5,0)
		blocks_root.add_child(block)
		if cell.hidden: hidden_blocks.append(block)
	for pipe: Variant in layout.pipes: _pipe(pipe.x,pipe.height)
	for entry: Variant in layout.enemies:
		var enemy: Variant = ENEMY.new()
		enemy.configure(entry.kind,self)
		enemy.position = Vector3(entry.x+0.5,entry.get("y",0.05),0)
		level.add_child(enemy)
		enemies.append(enemy)
	_scenery()
	_goal()
	_build_underground()
func tile_mesh(parent: Node, point: Vector3, color: Color, asset: String = "brick") -> MeshInstance3D:
	# Every terrain module still has the same 0.982-unit grid footprint.
	var variant: Variant = "stone" if color == Color("637d90") else ""
	return ART.make(parent,asset,point,Vector3.ONE*0.982,variant)
func _static_box(parent: Node, point: Vector3, size: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	body.position = point
	parent.add_child(body)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body
func _pipe(x: int, height: int) -> void:
	var root: Node3D = Node3D.new()
	root.name = "Pipe_%d" % x
	root.position = Vector3(x+1,0,0)
	level.add_child(root)
	ART.make(root,"pipe",Vector3(0,height*0.5,0),Vector3(2,height,1.2),"pipe",float(height))
	_static_box(root,Vector3(0,height*0.5,0),Vector3(2,height,1.2))
func _scenery() -> void:
	var decoration: Node3D = Node3D.new()
	decoration.name = "Background"
	level.add_child(decoration)
	# Quiet, low-contrast distant silhouettes preserve readable gaps and jumps.
	for x: Variant in [-2,22,47,72,97,122,147,172,197,222]:
		var big: Variant = posmod(x,3) != 0
		var mound: Variant = GPDPlatformShapes.sphere(decoration,Vector3(x,-2.0,-10),Vector3(14 if big else 10,9 if big else 6,3),Color("88beb0"))
		mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mound.material_override.disable_receive_shadows = true
	for x: Variant in [8,32,57,81,106,131,156,181,206]:
		for i: Variant in 3:
			var cloud: Variant = GPDPlatformShapes.box(decoration,Vector3(x+i*1.5,8.7+sin(i*1.7)*0.45,-10),Vector3(2.2,1.1,1.1),Color("edf4e6"))
			cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud.material_override.disable_receive_shadows = true
	for x: Variant in [10,34,53,76,98,119,141,165,190]:
		var tree: Variant = ART.make(decoration,"tree",Vector3(x,2.15,-5.4),Vector3(2.4,4.3,2.4),"distant")
		tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pine: Variant = ART.make(decoration,"tree-pine-small",Vector3(x+3.0,1.2,-5.8),Vector3(1.25,2.4,1.25),"distant")
		pine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x: Variant in [13,24,55,73,96,121,145,172,193]:
		var hedge: Variant = ART.make(decoration,"hedge",Vector3(x,0.36,-2.4),Vector3(3.0,0.72,0.65))
		hedge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ART.make(decoration,"flowers",Vector3(x-2.0,0.22,-1.4),Vector3(0.60,0.44,0.35))
		ART.make(decoration,"rocks",Vector3(x+2.0,0.30,-2.7),Vector3(0.85,0.60,0.65))
	# Align scenery feet with the projected Y=0 ground despite their rear depth.
	# Camera remains at zero pitch/yaw/roll; background receives no collision.
	for mesh: Variant in decoration.get_children():
		if mesh is MeshInstance3D and mesh.has_meta("source_asset"):
			mesh.position.y += mesh.position.z * CAMERA_HEIGHT / CAMERA_DISTANCE
func _goal() -> void:
	GPDPlatformShapes.cylinder(level,Vector3(198.5,5.5,0),0.045,9,Color("e7dfb5"))
	GPDPlatformShapes.sphere(level,Vector3(198.5,10.06,0),Vector3.ONE*0.25,Color("e9be50"))
	flag = ART.make(level,"flag-cloth",Vector3(197.85,9.3,0),Vector3(1.25,0.72,0.10))
	flag.rotation.y = PI
	var castle: Node3D = Node3D.new()
	castle.name = "Castle"
	level.add_child(castle)
	for x: Variant in range(202,207):
		for y: Variant in 3:
			if x == 204 and y < 2: continue
			tile_mesh(castle,Vector3(x+0.5,y+0.5,-0.5),Color("bc8457"))
	for x: Variant in [202,204,206]: tile_mesh(castle,Vector3(x+0.5,3.5,-0.5),Color("c9915b"))
	for x: Variant in [203,204,205]: tile_mesh(castle,Vector3(x+0.5,4.5,-0.9),Color("c9915b"))
	GPDPlatformShapes.box(castle,Vector3(204.5,1,-1.05),Vector3(1,2,0.1),Color("3e4650"))
	ART.make(castle,"door-open",Vector3(204.5,1.05,0.06),Vector3(1.32,2.1,0.26))
	for x: Variant in [203.5,205.5]: GPDPlatformShapes.box(castle,Vector3(x,2.6,0.02),Vector3(0.30,0.52,0.03),Color("4d4e49"))
func _build_underground() -> void:
	var room: Node3D = Node3D.new()
	room.name = "BonusRoom"
	level.add_child(room)
	# Separate room, beyond the overworld: no inherited garden route or islands.
	for x: Variant in range(300,316):
		for y: Variant in [-1,-2]: tile_mesh(room,Vector3(x+0.5,y+0.5,0),Color("637d90"))
	_static_box(room,Vector3(308,-1,0),Vector3(16,2,1))
	for x: Variant in range(304,311): tile_mesh(room,Vector3(x+0.5,10.5,0),Color("637d90"))
	_static_box(room,Vector3(307.5,10.5,0),Vector3(7,1,1))
	var backdrop: Variant = GPDPlatformShapes.box(room,Vector3(308,5,-1.5),Vector3(40,20,0.3),Color("263b56"))
	backdrop.material_override.disable_receive_shadows = true
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x: Variant in [300,315]:
		for y: Variant in 11: tile_mesh(room,Vector3(x+0.5,y+0.5,0),Color("637d90"))
		_static_box(room,Vector3(x+0.5,5.5,0),Vector3(1,11,1))
	for x: Variant in range(304,311):
		for y: Variant in 3: tile_mesh(room,Vector3(x+0.5,y+0.5,0),Color("637d90"))
		_static_box(room,Vector3(x+0.5,1.5,0),Vector3(1,3,1))
	for row: Variant in [3.5,5.5,7.5]:
		for x: Variant in range(304,311):
			if row == 7.5 and x in [304,310]: continue
			_room_coin(room,Vector3(x+0.5,row,0))
	var exit_pipe: Variant = ART.make(room,"pipe",Vector3(313.8,1.0,0),Vector3(2.0,2.0,1.1),"pipe",2.0)
	exit_pipe.rotation.z = PI/2
	_static_box(room,Vector3(314.25,1,0),Vector3(1.5,2,1.1))
func _room_coin(parent: Node, point: Vector3) -> void:
	var area: Area3D = Area3D.new()
	area.position = point
	area.collision_layer = 0
	area.collision_mask = 1
	parent.add_child(area)
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.43
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	area.add_child(col)
	ART.make(area,"coin-gold",Vector3.ZERO,Vector3(0.54,0.54,0.18))
	area.body_entered.connect(func(body: Node):
		if body == player:
			add_coin()
			area.queue_free())
func _physics_process(delta: float) -> void:
	_update_ui()
	if won or dying or warping: return
	elapsed += delta
	remaining_time = maxf(0,remaining_time-delta*2.5)
	if remaining_time <= 0 or player.position.y < -6:
		respawn()
		return
	if player.position.x < 0.45: player.position.x = 0.45
	for block: Variant in hidden_blocks:
		if is_instance_valid(block) and block.hidden and player.velocity.y > 0:
			var head: float = player.position.y+player.height
			if absf(player.position.x-block.position.x)<0.68 and head>block.position.y-0.52 and head<block.position.y+0.2:
				block.bump(player)
				player.velocity.y = -0.2
	if underground:
		camera.position.x = 308
		if player.position.x > 312.1 and player.position.y < 1.7: exit_bonus_room()
	else:
		camera.position.x = lerpf(camera.position.x,_camera_target(player.position.x),1-exp(-5*delta))
		if party_input != null and party_input.is_pressed(&"platform_down") and player.is_on_floor() and absf(player.position.x-58)<0.55 and absf(player.position.y-4)<0.15:
			enter_bonus_room()
		if player.position.x >= 198.1 and player.position.y < 10.2: finish()
	camera.position.y = CAMERA_HEIGHT
	camera.rotation = Vector3.ZERO
func add_coin() -> void:
	coins += 1
	award_points(200)
	if coins%100 == 0: add_life()
	GPDPlatformSound.play(self,980,0.10,1320,-23)
func add_life() -> void:
	lives += 1
	_show_toast("生命 +1")
	GPDPlatformSound.play(self,720,0.30,1080,-21)
func award_points(amount: int) -> void:
	score += amount
func spawn_item(kind: String, point: Vector3) -> void:
	var item: Variant = ITEM.new()
	item.configure(kind,self)
	item.position = point
	level.add_child(item)
	GPDPlatformSound.play(self,430,0.22,700,-25)
func coin_pop(point: Vector3) -> void:
	var coin: Variant = ART.make(level,"coin-gold",point,Vector3(0.52,0.52,0.18))
	var t: Variant = create_tween()
	t.tween_property(coin,"position:y",point.y+1.5,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(coin,"position:y",point.y+0.5,0.17)
	t.tween_callback(coin.queue_free)
func bump_enemies(point: Vector3) -> void:
	for enemy: Variant in enemies:
		if is_instance_valid(enemy) and absf(enemy.position.x-point.x)<1 and absf(enemy.position.y-point.y-0.5)<0.6:
			if enemy.has_method("defeat"): enemy.defeat()
func burst(point: Vector3, color: Color, count: int) -> void:
	for i: Variant in count:
		var n: Variant = GPDPlatformShapes.box(self,point,Vector3.ONE*0.16,color)
		var t: Variant = create_tween().set_parallel(true)
		t.tween_property(n,"position",point+Vector3(rng.randf_range(-1.3,1.3),rng.randf_range(0.5,1.5),rng.randf_range(-0.3,0.3)),0.35)
		t.tween_property(n,"scale",Vector3.ZERO,0.35)
		t.chain().tween_callback(n.queue_free)
func respawn() -> void:
	if won or dying: return
	dying = true
	deaths += 1
	lives -= 1
	player.control_enabled = false
	player.velocity = Vector3.ZERO
	GPDPlatformSound.play(self,400,0.4,140,-23)
	var t: Variant = create_tween()
	t.tween_property(player,"position:y",player.position.y+1.6,0.22)
	t.tween_property(player,"position:y",player.position.y-3.0,0.45)
	await t.finished
	if lives <= 0:
		heading.text = "再挑战一次"
		detail.text = "得分 %06d  ·  金币 %02d" % [score,coins]
		help_text.text = "每一次起跳，都能更熟练。"
		resume_button.hide()
		restart_button.text = "重新开始"
		_button_palette(restart_button,true)
		overlay.show()
		restart_button.grab_focus()
		return
	remove_child(level)
	level.queue_free()
	_build_level()
	underground = false
	warping = false
	player.reset_at(Vector3(2.5,0.1,0))
	camera.position.x = _camera_min_x()
	dying = false
	_show_toast("剩余生命 × %d" % lives)
func enter_bonus_room() -> void:
	if warping: return
	warping = true
	player.control_enabled = false
	var t: Variant = create_tween()
	t.tween_property(player,"position:y",2.0,0.45)
	await t.finished
	underground = true
	_teleport(Vector3(302,8.5,0))
	camera.position.x = 308
	warping = false
func exit_bonus_room() -> void:
	if warping: return
	warping = true
	player.control_enabled = false
	await get_tree().create_timer(0.25).timeout
	underground = false
	_teleport(Vector3(164,2.05,0))
	camera.position.x = 169
	warping = false
func _teleport(point: Vector3) -> void:
	player.global_position = point
	player.previous_position = point
	player.velocity = Vector3.ZERO
	player.coyote = 0
	player.buffer = 0
	player.control_enabled = true
func finish() -> void:
	if won: return
	won = true
	player.control_enabled = false
	player.velocity = Vector3.ZERO
	var flag_bonus: Variant = 5000 if player.position.y > 8 else (2000 if player.position.y>5 else (800 if player.position.y>2 else 100))
	award_points(flag_bonus+int(remaining_time)*50)
	GPDPlatformSound.play(self,660,0.7,990,-20)
	player.position.x = 198.1
	var t: Variant = create_tween().set_parallel(true)
	t.tween_property(flag,"position:y",1.5,1.0)
	t.tween_property(player,"position:y",1.0,1.0)
	t.chain().tween_property(player,"position",Vector3(204.5,0,0),1.5)
	await t.finished
	player.hide()
	heading.text = "1-1 完成"
	detail.text = "得分 %06d  ·  金币 %02d  ·  %d:%02d" % [score,coins,int(elapsed)/60,int(elapsed)%60]
	help_text.text = "越过砖墙、深坑与最后一级台阶。"
	resume_button.hide()
	restart_button.text = "再玩一次"
	_button_palette(restart_button,true)
	pause_button.hide()
	overlay.show()
	restart_button.grab_focus()
func _label(text: String, font_size: int, color: Color = Color("fff5d9")) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font",UI_FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color(0.11,0.25,0.31,0.35))
	label.add_theme_constant_override("shadow_offset_y",2)
	return label
func _stat(parent: Node, caption: String, value: String) -> Label:
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation",1)
	parent.add_child(stack)
	var title: Variant = _label(caption,13)
	stack.add_child(title)
	var number: Variant = _label(value,28)
	stack.add_child(number)
	return number
func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "Interface"
	canvas.process_mode = Node.PROCESS_MODE_INHERIT
	add_child(canvas)
	var ui: Control = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ui.set_script(preload("res://games/minigame/godot_party_default_platformer/scripts/world11_ui_input.gd"))

	canvas.add_child(ui)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side: Variant in ["left","right"]: margin.add_theme_constant_override("margin_"+side,38)
	margin.add_theme_constant_override("margin_top",25)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation",46)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	score_label = _stat(row,"SCORE","000000")
	coin_label = _stat(row,"COINS","× 00")
	var spring: Control = Control.new()
	spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spring)
	_stat(row,"WORLD","1-1")
	var spring2: Control = Control.new()
	spring2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spring2)
	life_label = _stat(row,"LIVES","× 3")
	time_label = _stat(row,"TIME","400")
	pause_button = _button("Ⅱ",false)
	pause_button.custom_minimum_size = Vector2(46,46)
	pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pause_button)
	pause_button.pressed.connect(func() -> void:set_paused(true))
	toast = _label("",16)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-350,105)
	toast.size.x = 700
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(toast)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.07,0.16,0.23,0.93)
	ui.add_child(overlay)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = 440
	column.add_theme_constant_override("separation",22)
	center.add_child(column)
	var eyebrow: Variant = _label("CLOUDSTEP  /  WORLD 1-1",15,Color("9ac9d1"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(eyebrow)
	heading = _label("暂停",50)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	detail = _label("",20,Color("c7d9d9"))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(detail)
	resume_button = _button("继续游戏")
	column.add_child(resume_button)
	resume_button.pressed.connect(func() -> void:set_paused(false))
	restart_button = _button("重新开始",false)
	column.add_child(restart_button)
	restart_button.pressed.connect(restart)
	help_text = _label("",15,Color("aac3cc"))
	help_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(help_text)
	overlay.hide()
func _button(text: String, primary: bool = true) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 52
	button.add_theme_font_override("font",UI_FONT)
	button.add_theme_font_size_override("font_size",19)
	_button_palette(button,primary)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button
func _button_palette(button: Button, primary: bool) -> void:
	for state: Variant in ["normal","hover","pressed","focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color("f3d89b") if primary else Color(1,1,1,0.06)
		if state == "hover": style.bg_color = Color("ffe7b2") if primary else Color(1,1,1,0.12)
		if state == "pressed": style.bg_color = Color("dfc28b") if primary else Color(1,1,1,0.16)
		style.set_corner_radius_all(8)
		style.content_margin_left = 14
		style.content_margin_right = 14
		if state == "focus":
			style.bg_color = Color(0,0,0,0)
			style.border_color = Color("eed49b")
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(state,style)
	for state: Variant in ["font_color","font_focus_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
		button.add_theme_color_override(state,Color("284f55") if primary else Color("f4e8cd"))
func _update_ui() -> void:
	if not is_instance_valid(score_label): return
	score_label.text = "%06d" % score
	coin_label.text = "× %02d" % (coins%100)
	life_label.text = "× %d" % lives
	time_label.text = "%03d" % ceili(remaining_time)
func _show_toast(message: String) -> void:
	toast.text = message
	toast.modulate.a = 1
	var tween: Variant = create_tween()
	tween.tween_interval(2)
	tween.tween_property(toast,"modulate:a",0,0.5)
func set_paused(_value: bool) -> void:
	pass

func restart() -> void:
	pass

func _notification(_what: int) -> void:
	pass

