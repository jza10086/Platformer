extends StaticBody3D
const GPDPlatformSound: Script = preload("res://games/minigame/godot_party_default_platformer/scripts/sound.gd")
## One grid cell. Its render module and collider occupy precisely one tile.
@export var kind: String = "brick"
@export var reward: String = ""
@export var remaining: int = 1
var used: bool = false
@export var hidden: bool = false
var owner_game: Node
var visual: Node3D
var collision: CollisionShape3D
var bumping: bool = false
func _ready() -> void:
	visual = $Visual
	collision = $Collision

func _draw() -> void:
	for node: Variant in visual.get_children():
		visual.remove_child(node)
		node.queue_free()
	if used:
		owner_game.ART.make(visual,"crate-item",Vector3.ZERO,Vector3.ONE*0.982,"used")
	elif kind == "brick":
		owner_game.ART.make(visual,"brick",Vector3.ZERO,Vector3.ONE*0.982)
	else:
		owner_game.ART.make(visual,"crate-item",Vector3.ZERO,Vector3.ONE*0.982)
		var label: Label3D = Label3D.new()
		label.text = "?"
		label.font_size = 78
		label.pixel_size = 0.008
		label.outline_size = 0
		label.modulate = Color("704021")
		label.position = Vector3(0,-0.015,0.503)
		visual.add_child(label)
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
	var t: Variant = create_tween()
	t.tween_property(visual,"position:y",0.20,0.075)
	t.tween_property(visual,"position:y",0.0,0.12)
	t.tween_callback(func() -> void: bumping = false)
	owner_game.bump_enemies(global_position)
	if reward.is_empty():
		GPDPlatformSound.play(self,170,0.07,-1,-26)
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
