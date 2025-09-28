extends Node

@onready var sfx: Node = $SFX
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer


func play_sfx(sfx_name: String) -> void:
	var player := sfx.get_node(sfx_name) as AudioStreamPlayer
	if not player:
		return
	if not player.playing:
		player.play()

func stop_sfx(sfx_name: String) -> void:
	var player := sfx.get_node(sfx_name) as AudioStreamPlayer
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

func fade_out_bgm(duration: float = 2.0) -> void:
	if not bgm_player.playing:
		return
	var tw := create_tween()
	# 从当前音量渐变到 -80db（基本听不见）
	tw.tween_property(bgm_player, "volume_db", -80.0, duration)
	# 淡出完成后彻底 stop
	tw.tween_callback(Callable(self, "_stop_bgm"))

func _stop_bgm() -> void:
	if bgm_player.playing:
		bgm_player.stop()
	bgm_player.volume_db = 0.0
