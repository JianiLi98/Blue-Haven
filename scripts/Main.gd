extends Node2D

@export var death_y := 800.0        
@export var next_scene: String = "res://scenes/Main2.tscn"

var player: Node2D
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
@onready var tutorial_label = $Tutorial/TutorialLabel

var is_fading := false

func _ready() -> void:
	player = $Player
	
	# 新场景开始时全黑
	fade_rect.color = Color(0, 0, 0, 1)
	
	# 渐亮
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 2.0)
	
	# 海浪
	#SoundManager.play_bgm(preload("res://assets/sound/gentle-ocean-waves-birdsong-and-gull-7109.mp3"))
	#森林
	SoundManager.play_bgm(preload("res://assets/sound/forest.mp3"))
	
	# label
	tutorial_label.visible = true
	tutorial_label.modulate.a = 1.0
	
	var tw1 = create_tween()
	tw1.tween_interval(3.0)
	tw1.tween_property(tutorial_label, "modulate:a", 0.0, 1.5)
	await tw1.finished
	
	tutorial_label.visible = false

func _process(delta: float) -> void:
	if is_fading:
		return
	
	# 手动重开（Esc）
	if Input.is_action_just_pressed("ui_cancel"):
		_restart()
	
	# 掉落死亡
	if player.global_position.y > death_y:
		_restart()
	
	# 撞到 Portal 进入下一关
	if $Portal and $Portal.has_overlapping_bodies():
		if $Portal.get_overlapping_bodies().has(player):
			SoundManager.play_sfx("win")
			$Portal/AnimatedSprite2D.stop()
			get_tree().change_scene_to_file("res://scenes/Main2.tscn")


func _restart() -> void:
	SoundManager.play_sfx("fall")
	_fade_and_call(func ():
		get_tree().reload_current_scene()
	)

func _next_level() -> void:
	# freeze player
	player.set_process(false)
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	
	_fade_and_call(func ():
		if next_scene != "":
			get_tree().change_scene_to_file(next_scene)
	)

func _fade_and_call(action: Callable) -> void:
	is_fading = true
	
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 1.0)
	await tw.finished
	
	# Step 2: 切场景
	action.call()
