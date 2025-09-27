extends CanvasLayer

@export var pause_panel: Panel 

func pause():
	get_tree().paused = true
	pause_panel.visible = true
	
func unpause():
	get_tree().paused = false
	pause_panel.visible = false

func quit_game():
	get_tree().quit()


func _on_pause_button_pressed() -> void:
	pass # Replace with function body.
