extends Area3D
signal collected(coin: Area3D)
var taken := false
var phase := 0.0
var base_y := 0.0
var visual: Node3D
func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	base_y = position.y
	phase = position.x*0.7
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	col.shape = shape
	add_child(col)
	visual = Node3D.new()
	add_child(visual)
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.19
	mesh.outer_radius = 0.36
	mesh.rings = 16
	mesh.ring_segments = 8
	ring.mesh = mesh
	ring.rotation.x = PI/2
	ring.material_override = Shapes.material(Color("ffcf6e"),0.28)
	visual.add_child(ring)
	body_entered.connect(_collect)
func _process(delta: float) -> void:
	phase += delta*2.6
	visual.position.y = sin(phase)*0.10
	visual.rotation.y += delta*1.3
func _collect(body: Node) -> void:
	if taken or not body.is_in_group("player"): return
	taken = true
	hide()
	set_deferred("monitoring",false)
	collected.emit(self)
