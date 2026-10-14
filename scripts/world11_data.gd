class_name World11Data
extends RefCounted
## Coordinates are zero-based 16 px map columns, one world unit per tile.
## y=0 is the top of the ground. Blocks use their lower-left grid cell.
const LENGTH := 208
const PIT_RANGES := [Vector2i(69,71),Vector2i(86,89),Vector2i(153,155)]
static func layout() -> Dictionary:
	var blocks: Array[Dictionary] = []
	_add(blocks,16,3,"question","coin")
	for x in [20,22,24]: _add(blocks,x,3,"brick")
	_add(blocks,21,3,"question","mushroom")
	_add(blocks,23,3,"question","coin")
	_add(blocks,22,7,"question","coin")
	_add(blocks,64,4,"question","life",1,true)
	for x in [77,79]: _add(blocks,x,3,"brick")
	_add(blocks,78,3,"question","mushroom")
	for x in range(80,88): _add(blocks,x,7,"brick")
	for x in range(91,94): _add(blocks,x,7,"brick")
	_add(blocks,94,7,"question","coin")
	_add(blocks,94,3,"brick","coin",10)
	_add(blocks,100,3,"brick")
	_add(blocks,101,3,"brick","star")
	for x in [106,109,112]: _add(blocks,x,3,"question","coin")
	_add(blocks,109,7,"question","mushroom")
	_add(blocks,118,3,"brick")
	for x in [121,122,123,128,131]: _add(blocks,x,7,"brick")
	for x in [129,130]:
		_add(blocks,x,3,"brick")
		_add(blocks,x,7,"question","coin")
	for x in [168,169,171]: _add(blocks,x,3,"brick")
	_add(blocks,170,3,"question","coin")
	var stairs: Array[Vector2i] = []
	for pair in [[134,1],[135,2],[136,3],[137,4],[140,4],[141,3],[142,2],[143,1],[148,1],[149,2],[150,3],[151,4],[152,4],[155,4],[156,3],[157,2],[158,1],[181,1],[182,2],[183,3],[184,4],[185,5],[186,6],[187,7],[188,8],[189,8],[198,1]]:
		stairs.append(Vector2i(pair[0],pair[1]))
	return {
		"ground":[Vector2i(0,69),Vector2i(71,86),Vector2i(89,153),Vector2i(155,208)],
		"pipes":[{"x":28,"height":2},{"x":38,"height":3},{"x":46,"height":4},{"x":57,"height":4,"entrance":true},{"x":163,"height":2,"exit":true},{"x":179,"height":2}],
		"blocks":blocks,"stairs":stairs,
		"enemies":[
			{"x":22,"kind":"goomba","y":0.05},
			{"x":40,"kind":"goomba","y":0.05},
			{"x":51,"kind":"goomba","y":0.05},
			{"x":52.5,"kind":"goomba","y":0.05},
			{"x":80,"kind":"goomba","y":8.05},
			{"x":82,"kind":"goomba","y":8.05},
			{"x":97,"kind":"goomba","y":0.05},
			{"x":98.5,"kind":"goomba","y":0.05},
			{"x":114,"kind":"goomba","y":0.05},
			{"x":115.5,"kind":"goomba","y":0.05},
			{"x":124,"kind":"goomba","y":0.05},
			{"x":125.5,"kind":"goomba","y":0.05},
			{"x":128,"kind":"goomba","y":0.05},
			{"x":129.5,"kind":"goomba","y":0.05},
			{"x":174,"kind":"goomba","y":0.05},
			{"x":175.5,"kind":"goomba","y":0.05},
			{"x":107.0,"kind":"turtle","y":0.05}
		]
	}
static func _add(blocks: Array[Dictionary], x: int, y: int, kind: String, reward := "", count := 1, hidden := false) -> void:
	blocks.append({"x":x,"y":y,"kind":kind,"reward":reward,"count":count,"hidden":hidden})
