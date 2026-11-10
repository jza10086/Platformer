extends Node3D
const GPDPlatformSound: Script = preload("res://games/minigame/gp_platformer/scripts/sound.gd")
const GPDPlatformShapes: Script = preload("res://games/minigame/gp_platformer/scripts/shapes.gd")
var party_input: PartyInput
## A grid-built 3D interpretation of the NES World 1-1 map.
const ENEMY: Script = preload("res://games/minigame/gp_platformer/scripts/world11_enemy.gd")
const ITEM: Script = preload("res://games/minigame/gp_platformer/scripts/world11_item.gd")
const ART: Script = preload("res://games/minigame/gp_platformer/scripts/world11_assets.gd")
const UI_FONT: Resource = preload("res://games/minigame/gp_platformer/assets/fonts/NotoSansCJK.ttc")
const CAMERA_HEIGHT: float = 5.0
const CAMERA_DISTANCE: float = 16.0
const CAMERA_FOV: float = 46.0
@onready var player: Variant = $Player
@onready var camera: Camera3D = $Camera3D
const Course: PackedScene = preload("res://games/minigame/gp_platformer/scenes/course.tscn")
var spawn_point: Vector3
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
@onready var score_label: Label = %ScoreLabel
@onready var coin_label: Label = %CoinLabel
@onready var time_label: Label = %TimeLabel
@onready var life_label: Label = %LifeLabel
@onready var toast: Label = %Toast
@onready var overlay: ColorRect = %Overlay
@onready var heading: Label = %Heading
@onready var detail: Label = %Detail
@onready var help_text: Label = %HelpText
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var pause_button: Button = %PauseButton
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	rng.seed = 1101
	_setup_inputs()
	spawn_point = player.position
	level = $TileWorld
	_activate_level()
	pause_button.pressed.connect(set_paused.bind(true))
	resume_button.pressed.connect(set_paused.bind(false))
	restart_button.pressed.connect(restart)
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

func _activate_level() -> void:
	flag = level.get_node("FinishFlag")
	hidden_blocks.clear()
	enemies.clear()
	for block: StaticBody3D in level.get_node("InteractiveBlocks").get_children():
		block.owner_game = self
		if block.hidden:
			hidden_blocks.append(block)
	for spawn: Marker3D in level.get_node("EnemySpawns").get_children():
		var enemy: CharacterBody3D = ENEMY.new()
		enemy.configure(spawn.get_meta("kind"), self)
		enemy.position = spawn.position
		level.add_child(enemy)
		enemies.append(enemy)
	for coin: Area3D in level.get_node("BonusRoom").find_children("*", "Area3D", true, false):
		coin.body_entered.connect(_collect_room_coin.bind(coin))

func _collect_room_coin(body: Node3D, coin: Area3D) -> void:
	if body == player:
		add_coin()
		coin.queue_free()

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
	level = Course.instantiate()
	add_child(level)
	_activate_level()
	underground = false
	warping = false
	player.reset_at(spawn_point)
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

