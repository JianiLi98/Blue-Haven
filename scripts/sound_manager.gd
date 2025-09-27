extends Node

@onready var sfx: Node = $SFX
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer


func play_sfx(name: String) -> void:
	var player := sfx.get_node(name) as AudioStreamPlayer
	if not player:
		return
	if not player.playing:
		player.play()

func stop_sfx(name: String) -> void:
	var player := sfx.get_node(name) as AudioStreamPlayer
	if not player:
		return
	if player.playing:
		player.stop()


func play_bgm(stream: AudioStream, offset: float = 0.0) -> void:
	if not stream:
		return
	if bgm_player.playing:
		bgm_player.stop()
	bgm_player.stream = stream
	bgm_player.play(offset)
