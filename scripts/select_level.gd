extends CanvasLayer

@onready var dimmer: ColorRect      = $Dimmer
@onready var panel: Control         = $Panel
@onready var btn_l1: TextureButton  = $Panel/VBoxContainer/Level1Button
@onready var btn_l2: TextureButton  = $Panel/VBoxContainer/Level2Button
@onready var btn_l3: TextureButton  = $Panel/VBoxContainer/Level3Button
@onready var btn_back: Button       = $Panel/CloseButton

# 你的关卡路径（按你工程实际改）
const LV1 := "res://scenes/Main.tscn"
const LV2 := "res://scenes/Main2.tscn"
const LV3 := "res://scenes/Main3.tscn"

func _ready() -> void:
	# 初始隐藏+透明（为了淡入）
	visible = false
	dimmer.modulate.a = 0.0
	panel.modulate.a = 0.0

	# 连接按钮
	btn_l1.pressed.connect(_on_l1)
	btn_l2.pressed.connect(_on_l2)
	btn_l3.pressed.connect(_on_l3)
	btn_back.pressed.connect(hide_menu)

func show_menu() -> void:
	# 像 PauseMenu 一样的打开效果
	if not visible:
		visible = true
	SoundManager.play_sfx("button")

	# 拦截点击
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP

	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(dimmer, "modulate:a", 0.65, 0.15)
	tw.tween_property(panel,  "modulate:a", 1.00, 0.15)

func hide_menu() -> void:
	SoundManager.play_sfx("button")
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel,  "modulate:a", 0.0, 0.12)
	tw.tween_property(dimmer, "modulate:a", 0.0, 0.12)
	await tw.finished
	visible = false

# 可选：Esc 关闭
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_menu()

# --- 跳关 ---
func _on_l1() -> void:
	SoundManager.play_sfx("button")
	get_tree().change_scene_to_file(LV1)

func _on_l2() -> void:
	SoundManager.play_sfx("button")
	get_tree().change_scene_to_file(LV2)

func _on_l3() -> void:
	SoundManager.play_sfx("button")
	get_tree().change_scene_to_file(LV3)
