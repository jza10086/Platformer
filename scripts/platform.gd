@tool
extends StaticBody3D
@export var width := 8.0
@export var depth := 3.8
@export var thickness := 2.6
@export var flowers := true
func _ready() -> void:
	# Keep the visible front lip aligned with the cube front (~Z=0.46).
	# Depth extends behind the play plane so perspective cannot hide the feet.
	var center_z := 0.5 - depth / 2.0
	for child in get_children(): child.queue_free()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, thickness, depth)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0,-thickness / 2,center_z)
	add_child(col)
	Shapes.box(self, Vector3(0,-(thickness+0.36)/2,center_z),Vector3(width,thickness-0.36,depth),Color("bb8270"))
	Shapes.box(self, Vector3(0,-0.18,center_z),Vector3(width,0.36,depth),Color("8bbd81"))
	Shapes.box(self, Vector3(0,-0.47,0.512),Vector3(width,0.24,0.06),Color("d8a47f"))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 831 + width * 271 + 55)
	for i in range(int(width*0.8)):
		var x := rng.randf_range(-width/2+0.3,width/2-0.3)
		Shapes.box(self,Vector3(x,-rng.randf_range(0.8,thickness-0.2),0.525),Vector3(rng.randf_range(0.15,0.48),0.15,0.06),Color("e5b39a"))
	if flowers:
		for i in range(int(width/1.4)):
			var x := rng.randf_range(-width/2+0.5,width/2-0.5)
			var z := 0.9-depth
			Shapes.cylinder(self,Vector3(x,0.18,z),0.035,0.4,Color("447768"))
			Shapes.sphere(self,Vector3(x,0.4,z),Vector3(0.26,0.26,0.26),Color("ffe3a0") if i%2==0 else Color("f5b6ad"))
	# Layered tapered rock beneath every floating island.
	var rock := Shapes.cylinder(self,Vector3(0,-thickness-0.5,center_z),0.45,1.4,Color("967467"),1.0)
	rock.scale = Vector3(width*0.42,1,depth*0.43)
