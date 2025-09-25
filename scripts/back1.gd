extends TextureRect

@onready var player = get_node("../Player")
@onready var cam = get_node("../Player/Camera2D")

func _ready():
	# 自动铺满窗口
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	stretch_mode = TextureRect.STRETCH_SCALE

func _process(delta):
	# 实时调整背景大小，保证填满
	size = get_viewport().get_visible_rect().size
