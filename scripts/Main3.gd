extends Node2D

@export var death_band_center_y := 500.0       # 中轴线（尖刺行）世界 Y
@export var death_band_half_height := 20.0     # 死亡带半高度
@export var next_scene: String = "res://scenes/end.tscn"
@export var vanish_duration := 0.25            # 玩家消失动画时长

var player: Node2D
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
@onready var tutorial1: Label = $Tutorial/TutorialLabel1
@onready var tutorial2: Label = $Tutorial/TutorialLabel2

var is_fading := false
var is_dying := false

func _ready() -> void:
	SoundManager.play_bgm(preload("res://assets/sound/gentle-ocean-waves-birdsong-and-gull-7109.mp3"))
	player = $Player
	
	# 新场景开始时全黑 → 渐亮
	fade_rect.color = Color(0, 0, 0, 1)
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 1.0)
	
	# 教学文字
	tutorial1.visible = false
	tutorial2.visible = false
	_play_tutorial()

func _process(delta: float) -> void:
	if is_fading or is_dying:
		return
	
	# 手动重开（Esc）
	if Input.is_action_just_pressed("ui_cancel"):
		_restart()
		return

	# 进入“中轴线 ± half_height”的死亡带：先播放玩家消失，再黑屏重开
	var py := player.global_position.y
	var top_y := death_band_center_y - death_band_half_height
	var bottom_y := death_band_center_y + death_band_half_height + 100.0
	if py >= top_y and py <= bottom_y:
		_die_and_fade()
		return
	
	# 撞到 Portal 进入下一关
	if $Portal and $Portal.has_overlapping_bodies():
		if $Portal.get_overlapping_bodies().has(player):
			SoundManager.play_sfx("win")
			$Portal/AnimatedSprite2D.stop()
			get_tree().change_scene_to_file("res://scenes/end.tscn")

# 玩家消失动画 → 渐黑重开（保留你原来的黑屏/渐亮流程）
func _die_and_fade() -> void:
	if is_dying:
		return
	is_dying = true
	SoundManager.play_sfx("fall")

	# 冻结玩家并禁用碰撞
	if is_instance_valid(player):
		if player.has_method("set_process"):
			player.set_process(false)
		if player.has_method("set_physics_process"):
			player.set_physics_process(false)
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		for c in player.get_children():
			if c is CollisionShape2D:
				c.disabled = true
			elif c is CollisionPolygon2D:
				c.disabled = true

	# 消失动画（淡出 + 轻微缩小）
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(player, "modulate:a", 0.0, vanish_duration)
	tw.tween_property(player, "scale", player.scale * 0.8, vanish_duration)
	await tw.finished

	# 渐黑并重载场景（重置玩家）
	_restart()

func _restart() -> void:
	if is_fading:
		return
	is_fading = true
	SoundManager.play_sfx("fall")
	_fade_and_call(func ():
		get_tree().reload_current_scene()
	)

func _next_level() -> void:
	if player.has_method("set_process"):
		player.set_process(false)
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	
	_fade_and_call(func ():
		if next_scene != "":
			get_tree().change_scene_to_file(next_scene)
	)

func _fade_and_call(action: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 1.0)  # 渐黑
	await tw.finished
	action.call()  # 切场景后在 _ready() 中再渐亮

func _play_tutorial() -> void:
	# ---------- 第一句 ----------
	tutorial1.visible = true
	tutorial1.modulate.a = 0.0

	var tw1 = create_tween()
	tw1.tween_property(tutorial1, "modulate:a", 1.0, 1.0) 
	tw1.tween_interval(2.0)
	tw1.tween_property(tutorial1, "modulate:a", 0.0, 1.0)
	await tw1.finished

	tutorial1.visible = false

	# ---------- 第二句 ----------
	tutorial2.visible = true
	tutorial2.modulate.a = 0.0

	var tw2 = create_tween()
	tw2.tween_property(tutorial2, "modulate:a", 1.0, 1.0) 
	tw2.tween_interval(2.0)
	tw2.tween_property(tutorial2, "modulate:a", 0.0, 1.0)
	await tw2.finished

	tutorial2.visible = false
 
