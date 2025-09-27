extends Node2D

@export var bgm: AudioStream
@export var bgm_offset := 6

func _ready() -> void:
	if bgm:
		SoundManager.play_bgm(bgm, bgm_offset)
