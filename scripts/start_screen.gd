extends Node2D

@export var bgm: AudioStream
@export var bgm_offset := 6


@onready var level_select: CanvasLayer = $LevelSelectUI
@onready var select_btn: TextureButton = $ui/start/LevelSelectButton

func _ready() -> void:
	if bgm:
		SoundManager.play_bgm(bgm, bgm_offset)
	
	select_btn.pressed.connect(func():
		level_select.show_menu()
	)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().paused = true


func _on_SelectLevelButton_pressed() -> void:
	pass # Replace with function body.
