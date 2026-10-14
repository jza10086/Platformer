extends StaticBody3D
## One grid cell. Its render module and collider occupy precisely one tile.
var kind := "brick"
var reward := ""
var remaining := 1
var used := false
var hidden := false
var owner_game: Node
var visual: Node3D
var collision: CollisionShape3D
var bumping := false
func configure(data: Dictionary, game: Node) -> void:
	kind = data.get("kind", "brick")
	reward = data.get("reward", "")
	remaining = data.get("count", 1)
	hidden = data.get("hidden", false)
	owner_game = game
func _ready() -> void:
	collision_layer = 0 if hidden else 2
	collision_mask = 0
	collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE
	collision.shape = shape
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	_draw()
	visual.visible = not hidden
func _draw() -> void:
	for node in visual.get_children():
		visual.remove_child(node)
		node.queue_free()
	var color := Color("d58c49") if kind == "brick" else Color("dca62c")
	if used: color = Color("9b7958")
	owner_game.tile_mesh(visual,Vector3.ZERO,color)
	if kind == "brick" and not used:
		for yy in [-0.16,0.17]:
			Shapes.box(visual,Vector3(0,yy,0.496),Vector3(0.92,0.028,0.012),Color("744931"))
		for v in [Vector2(0,0.33),Vector2(-0.23,0),Vector2(0.23,0),Vector2(0,-0.33)]:
			Shapes.box(visual,Vector3(v.x,v.y,0.496),Vector3(0.028,0.28,0.012),Color("744931"))
	elif not used:
		var label := Label3D.new()
		label.text = "?"
		label.font_size = 78
		label.pixel_size = 0.010
		label.outline_size = 0
		label.modulate = Color("76502b")
		label.position = Vector3(0,-0.015,0.51)
		visual.add_child(label)
	for xx in [-0.35,0.35]:
		for yy in [-0.35,0.35]:
			Shapes.box(visual,Vector3(xx,yy,0.502),Vector3(0.045,0.045,0.018),Color("8b6138"))
func bump(actor: Node) -> void:
	if used or bumping: return
	if hidden:
		hidden = false
		visual.show()
		set_deferred("collision_layer",2)
	if reward.is_empty() and kind == "brick" and actor.big:
		used = true
		bumping = true
		owner_game.award_points(50)
		owner_game.burst(global_position,Color("d58c49"),8)
		set_deferred("collision_layer",0)
		queue_free()
		return
	bumping = true
	var t := create_tween()
	t.tween_property(visual,"position:y",0.20,0.075)
	t.tween_property(visual,"position:y",0.0,0.12)
	t.tween_callback(func(): bumping = false)
	owner_game.bump_enemies(global_position)
	if reward.is_empty():
		Sound.play(self,170,0.07,-1,-26)
		return
	remaining -= 1
	if reward == "coin":
		owner_game.add_coin()
		owner_game.coin_pop(global_position+Vector3(0,0.65,0))
	else:
		owner_game.spawn_item(reward,global_position+Vector3(0,0.55,0))
	if remaining <= 0:
		used = true
		_draw()
