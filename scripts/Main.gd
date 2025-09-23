extends Node2D

@export var death_y := 800.0
var player

func _ready():
	player = $Player

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().reload_current_scene()

	if player.global_position.y > death_y:
		get_tree().reload_current_scene()
