extends CharacterBody2D

const GRAVITY := 1000.0
const RUN_SPEED := 100.0
const FLOOR_SNAP := 32.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var bubble: AnimatedSprite2D = $bubble

# ----- 新增：指向 ocean，并算出它的“世界坐标系”底边 y -----
@export var ocean_path: NodePath           # 设成 CanvasLayer 下的 ocean 节点
var _ocean_bottom_world_y := INF
var _locked_at_bottom := false

func _ready() -> void:
	floor_snap_length = FLOOR_SNAP
	anim.play("jumploop")
	bubble.play("bubble")
	_compute_ocean_bottom_y()

func _compute_ocean_bottom_y() -> void:
	var ocean := get_node_or_null(ocean_path)
	if ocean == null:
		return

	# 取 ocean 的贴图高度（Sprite2D）或可见矩形（TextureRect）
	var bottom_screen_y := 0.0
	if ocean is Sprite2D and ocean.texture:
		var spr := ocean as Sprite2D
		var h := float(spr.texture.get_height()) * spr.scale.y
		var bottom_local_y = 0.0
		if spr.centered:
			bottom_local_y = h * 0.5
		else:
			bottom_local_y = h
				
		# CanvasLayer 上的 to_global() 是“屏幕坐标”
		bottom_screen_y = spr.to_global(Vector2(0, bottom_local_y)).y
	elif ocean.has_method("get_rect"): # TextureRect 等 UI 节点
		var rect: Rect2 = ocean.get_rect()
		bottom_screen_y = ocean.to_global(rect.end).y
	else:
		return

	# 将“屏幕 y”换到“世界 y”
	var cam := get_viewport().get_camera_2d()
	if cam:
		_ocean_bottom_world_y = cam.screen_to_world(Vector2(0, bottom_screen_y)).y
	else:
		# 没有相机时，屏幕坐标与世界坐标近似一致
		_ocean_bottom_world_y = bottom_screen_y

func _physics_process(delta: float) -> void:
	if _locked_at_bottom:
		velocity = Vector2.ZERO
		return

	# 重力
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 始终向前匀速
	velocity.x = RUN_SPEED

	move_and_slide()

	# 到达 ocean 底部 → 钳住并停止
	if global_position.y >= _ocean_bottom_world_y:
		global_position.y = _ocean_bottom_world_y
		velocity = Vector2.ZERO
		_locked_at_bottom = true
