extends Node2D

@export var death_y := 800.0        
@export var next_scene: String = "res://scenes/Main2.tscn"

var player: Node2D
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect

var is_fading := false

func _ready() -> void:
	player = $Player
	
	# 新场景开始时全黑
	fade_rect.color = Color(0, 0, 0, 1)
	
	# 渐亮
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 1.0)

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
			get_tree().change_scene_to_file("res://scenes/Main2.tscn")

func _restart() -> void:
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
