extends CanvasLayer

@export var pause_panel: Panel 

func pause():
	SoundManager.play_sfx("button")
	get_tree().paused = true
	pause_panel.visible = true
	
func unpause():
	SoundManager.play_sfx("button")
	get_tree().paused = false
	pause_panel.visible = false

func quit_game():
	SoundManager.play_sfx("button")
	get_tree().paused = false
	pause_panel.visible = false
	get_tree().change_scene_to_file("res://scenes/start.tscn")


func _on_pause_button_pressed() -> void:
	pause()
