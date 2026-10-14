@tool
extends StaticBody3D
## Visually separate masonry modules; one continuous collider avoids seam snags.
@export var width := 8.0
@export var depth := 3.8
@export var thickness := 2.6
@export var flowers := true
@export var floating := false
const MODULE := 1.0
const SEAM := 0.045
const FRONT := 0.5
var brick_bounds: Array[AABB] = []
var _batches: Dictionary = {}
var _brick_mesh: ArrayMesh
func _ready() -> void:
	var center_z := FRONT - depth / 2.0
	for child in get_children(): child.queue_free()
	brick_bounds.clear()
	_batches.clear()
	_brick_mesh = Shapes.chamfered_cube(0.045)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, thickness, depth)
	var col := CollisionShape3D.new()
	col.name = "SeamlessCollision"
	col.shape = shape
	col.position = Vector3(0,-thickness / 2,center_z)
	add_child(col)
	var columns := maxi(1,roundi(width / MODULE))
	var rows := maxi(1,roundi(thickness / MODULE))
	var slices := maxi(1,roundi(depth / MODULE))
	var cell_width := width / columns
	var cell_height := thickness / rows
	var cell_depth := depth / slices
	var palette := [Color("bd7757"),Color("c9835f"),Color("d08b65"),Color("b97456")]
	if floating: palette = [Color("d89d64"),Color("dda56d"),Color("cf925e"),Color("e3ac72")]
	for row in rows:
		# Alternate full and half end blocks for authentic interlocking courses.
		var offset := cell_width / 2.0 if row % 2 == 1 else 0.0
		for column in range(-1 if offset > 0 else 0,columns):
			var left := maxf(-width/2,-width/2+column*cell_width+offset)
			var right := minf(width/2,-width/2+(column+1)*cell_width+offset)
			if right-left < 0.01: continue
			for slice in slices:
				var grass := 0.14 if row == 0 and not floating else 0.0
				var size := Vector3(right-left-SEAM,cell_height-SEAM-grass,cell_depth-SEAM)
				var pos := Vector3((left+right)/2,-row*cell_height-cell_height/2-grass/2,FRONT-(slice+0.5)*cell_depth)
				var shade := posmod(column+row*3+slice*2+int(position.x),palette.size())
				_add_module("Clay%d" % shade,pos,size,palette[shade])
				brick_bounds.append(AABB(pos-size/2,size))
				if grass > 0:
					_add_module("Grass%d" % posmod(column+slice,2),Vector3(pos.x,-grass/2,pos.z),Vector3(right-left-SEAM*0.72,grass,cell_depth-SEAM*0.72),Color("8ebd78") if posmod(column+slice,2)==0 else Color("99c481"))
				elif row == 0 and slice == 0 and floating:
					# An original inset sun-stone face, carved into each individual brick.
					_add_module("Inset",Vector3(pos.x,pos.y,FRONT-SEAM/2+0.006),Vector3(size.x*0.68,size.y*0.64,0.028),Color("e8b980"))
	for batch_key in _batches:
		var entry: Dictionary = _batches[batch_key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = _brick_mesh
		multimesh.instance_count = entry.transforms.size()
		for i in entry.transforms.size(): multimesh.set_instance_transform(i,entry.transforms[i])
		var visual := MultiMeshInstance3D.new()
		visual.name = "Modules"+batch_key
		visual.multimesh = multimesh
		visual.material_override = Shapes.material(entry.color)
		add_child(visual)
	if flowers and not floating:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x * 831 + width * 271 + 55)
		for i in range(int(width/2.3)):
			var x := rng.randf_range(-width/2+0.5,width/2-0.5)
			var z := 0.9-depth
			Shapes.cylinder(self,Vector3(x,0.18,z),0.035,0.4,Color("447768"))
			Shapes.sphere(self,Vector3(x,0.4,z),Vector3(0.24,0.24,0.24),Color("ffe3a0") if i%2==0 else Color("f5b6ad"))
func _add_module(key: String, pos: Vector3, size: Vector3, color: Color) -> void:
	if not _batches.has(key): _batches[key] = {"color":color,"transforms":[]}
	_batches[key].transforms.append(Transform3D(Basis.from_scale(size),pos))
