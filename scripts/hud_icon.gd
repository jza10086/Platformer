extends Control
@export_enum("ring", "pause", "flag") var kind := "ring"
var ink := Color("335b61")
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var center := size/2
	if kind == "ring":
		draw_circle(center+Vector2(0,2),14,Color(0.20,0.33,0.35,0.14))
		draw_arc(center,12.5,0,TAU,48,Color("9b713c"),5,true)
		draw_arc(center+Vector2(0,-1),11.5,0,TAU,48,Color("ffe4a0"),4,true)
		draw_arc(center+Vector2(-1,-2),11.5,PI,PI*1.7,20,Color("fff9da"),2,true)
	elif kind == "pause":
		for x in [-5.5,5.5]:
			draw_style_box(_rounded_bar(),Rect2(center+Vector2(x-2,-9),Vector2(4,18)))
	elif kind == "flag":
		draw_line(center+Vector2(-6,9),center+Vector2(-6,-10),ink,2,true)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-5,-10),center+Vector2(9,-7),center+Vector2(-5,-2)]),ink)
func _rounded_bar() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ink
	style.set_corner_radius_all(2)
	return style
