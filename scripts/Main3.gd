extends Node2D

@export var death_y := 1200.0        
@export var next_scene: String = "res://scenes/start.tscn"

var player: Node2D
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
@onready var tutorial1: Label = $Tutorial/TutorialLabel1
@onready var tutorial2: Label = $Tutorial/TutorialLabel2

var is_fading := false

func _ready() -> void:
	player = $Player
	
	# 新场景开始时全黑
	fade_rect.color = Color(0, 0, 0, 1)
	
	# 渐亮
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 2.0)
	
	# label
	tutorial1.visible = false
	tutorial2.visible = false
	_play_tutorial()

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
			get_tree().change_scene_to_file("res://scenes/start.tscn")


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

func _play_tutorial() -> void:
	# ---------- 第一句 ----------
	tutorial1.visible = true
	tutorial1.modulate.a = 0.0

	var tw1 = create_tween()
	tw1.tween_property(tutorial1, "modulate:a", 1.0, 1.0)
	tw1.tween_interval(3.0)
	tw1.tween_property(tutorial1, "modulate:a", 0.0, 1.0)
	await tw1.finished

	tutorial1.visible = false

	# ---------- 第二句 ----------
	tutorial2.visible = true
	tutorial2.modulate.a = 0.0

	var tw2 = create_tween()
	tw2.tween_property(tutorial2, "modulate:a", 1.0, 1.0)
	tw2.tween_interval(3.0)
	tw2.tween_property(tutorial2, "modulate:a", 0.0, 1.0)
	await tw2.finished

	tutorial2.visible = false
