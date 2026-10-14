extends Control
var game: Node
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		game.set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("restart") and (game.won or game.dying or get_tree().paused):
		get_viewport().set_input_as_handled()
		game.restart()
