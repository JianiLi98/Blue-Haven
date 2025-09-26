extends Node2D

@export var follow: Node2D            # 拖 Camera2D 或 Player 进来
@export var strip_count := 3          # 至少 2~3 条
@export var strip_width := 1024.0     # 每条物理地面的宽度（像素）
@export var strip_height := 64.0      # 厚度
@export var floor_y := 600.0          # 地面世界坐标 y（碰撞条的顶沿）
@export var show_debug := false       # 调试可视化（画矩形）

var _strips: Array[StaticBody2D] = []

func _ready() -> void:
	if follow == null:
		push_error("CollisionFloorLooper: 请把 follow 设为 Camera2D 或 Player 节点。")
		return
	_make_strips()

func _process(_dt: float) -> void:
	if follow == null or _strips.is_empty():
		return
	var leftmost := _strips[0]
	var rightmost := _strips[0]
	for sb in _strips:
		if sb.global_position.x < leftmost.global_position.x:
			leftmost = sb
		if sb.global_position.x > rightmost.global_position.x:
			rightmost = sb
	# 当跟随者超过最左条一个宽度，就把最左条搬到最右边
	if follow.global_position.x - leftmost.global_position.x > strip_width:
		leftmost.global_position.x = rightmost.global_position.x + strip_width

func _make_strips() -> void:
	# 先清理旧的
	for c in get_children():
		if c is StaticBody2D:
			remove_child(c)
			c.queue_free()
	_strips.clear()

	# 从 x=0 开始向右铺 strip_count 条
	for i in strip_count:
		var sb := StaticBody2D.new()
		sb.name = "Strip_%d" % i
		add_child(sb)
		sb.global_position = Vector2(i * strip_width, floor_y)

		var shape := RectangleShape2D.new()
		shape.size = Vector2(strip_width, strip_height)

		var cs := CollisionShape2D.new()
		cs.shape = shape
		# 让矩形顶沿位于 floor_y（顶对齐）
		cs.position = Vector2(strip_width * 0.5, -strip_height * 0.5)
		sb.add_child(cs)

		if show_debug:
			var dbg := Node2D.new()
			dbg.name = "DebugDraw"
			sb.add_child(dbg)
			dbg.queue_redraw()
			dbg.draw.connect(func():
				dbg.draw_rect(Rect2(Vector2.ZERO, Vector2(strip_width, strip_height)), Color(0,1,0,0.25), true)
				dbg.draw_rect(Rect2(Vector2.ZERO, Vector2(strip_width, strip_height)), Color(0,1,0,0.8), false))

		_strips.append(sb)
