extends Node2D

@onready var fade_rect: ColorRect       = $CanvasLayer/FadeRect
@onready var label: Label               = $CanvasLayer2/TutorialLabel
@onready var slime: CharacterBody2D     = $Player
@onready var bubble: AnimatedSprite2D   = $Player/bubble
@onready var ocean_area: Area2D         = $ocean/Area2D
@onready var cliff_end_area: Area2D = $cliff_end_area
@onready var tutorial1: Label = $Tutorial/TutorialLabel1
@onready var tutorial2: Label = $Tutorial/TutorialLabel2

const START_SCENE := "res://scenes/start.tscn"

func _on_exit_cliff(body: Node) -> void:
	if body == slime:
		bubble.visible = false
		bubble.stop()

var ended := false   # 防重入

func _ready() -> void:
	SoundManager.play_bgm(preload("res://assets/sound/oceanbig.mp3"))
	# 开场黑 → 亮
	fade_rect.color = Color(0,0,0,1)
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, 1.2)

	# 气泡思考
	if bubble: bubble.play("found")

	# 监听海水碰撞（玩家何时掉进海）
	if not ocean_area.body_entered.is_connected(_on_ocean_entered):
		ocean_area.body_entered.connect(_on_ocean_entered)
	
	cliff_end_area.body_exited.connect(_on_exit_cliff)
	
	# label
	tutorial1.visible = false
	tutorial2.visible = false
	_play_tutorial()

func _on_ocean_entered(body: Node) -> void:
	if ended: return
	if body != slime: return
	ended = true

	# 通知 player 进入海里
	if slime.has_method("set_in_ocean"):
		slime.set_in_ocean(true)
		SoundManager.play_sfx("splash")

	# 等几秒镜头跟着往下沉 → 渐黑收尾
	await get_tree().create_timer(2.0).timeout
	await _fade_out_and_end()
	

func _fade_out_and_end() -> void:
	SoundManager.fade_out_bgm(3.0)
	
	fade_rect.color = Color(0.0, 0.3, 0.8, 0.0)  # 一开始透明的蓝
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 1.5)  # 1.5 秒充斥全屏
	await tw.finished

	await get_tree().create_timer(2.0).timeout
	
	var tw2 = create_tween()
	tw2.tween_property(fade_rect, "color", Color(0,0,0,1), 2.0)  # 颜色从蓝→黑
	await tw2.finished
	
	get_tree().change_scene_to_file(START_SCENE)
	

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
