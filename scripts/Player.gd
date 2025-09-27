extends CharacterBody2D

var jump_charge_name: StringName = &"charge"
var jump_jump_name:   StringName = &"jump"

# ---------- Tunables ----------
const GRAVITY := 1200.0
const MAX_CHARGE_TIME := 1.20

const MIN_H_SPEED := 80.0
const MAX_H_SPEED := 500.0

const MIN_JUMP_V := -220.0
const MAX_JUMP_V := -550.0

const AIR_CONTROL := 0.06
const DIST_MAX := 520.0

var facing := 1   # 1: right, -1: left

# ---------- State machine ----------
enum State { STATIC, CHARGING, JUMPING, STUCK }
var state: State = State.STATIC
var charge_time := 0.0

@onready var blue_anim: AnimatedSprite2D = $BlueAnim
@onready var jump_anim: AnimatedSprite2D = $JumpAnim

# ✨ 新增：待机配色（等于 BlueAnim 里动画的名字）
var idle_palette: StringName = &"blue"

# --- 动画控制 ---
func _play_idle():
	blue_anim.visible = true
	jump_anim.visible = false
	# 改：按当前配色播放；若找不到就退回 blue
	if blue_anim.sprite_frames and blue_anim.sprite_frames.has_animation(idle_palette):
		if blue_anim.animation != idle_palette or not blue_anim.is_playing():
			blue_anim.play(idle_palette)
	else:
		blue_anim.play("blue")  # 安全兜底

func _play_charge():
	blue_anim.visible = false
	jump_anim.visible = true
	jump_anim.play(jump_charge_name)   # 原: "charge"

func _play_jump():
	blue_anim.visible = false
	jump_anim.visible = true
	jump_anim.play(jump_jump_name)     # 原: "jump"

func set_idle_palette(new_palette: StringName) -> void:
	idle_palette = new_palette

	# 紫色 → 跳跃动画名切到 pur_char / pur_jump
	if new_palette == &"purple":
		jump_charge_name = &"pur_char"
		jump_jump_name   = &"pur_jump"
	elif new_palette == &"green":
		jump_charge_name = &"green_char"
		jump_jump_name   = &"green_jump"
	else:
		jump_charge_name = &"charge"
		jump_jump_name   = &"jump"

	# 地面静止/卡住时立刻刷新待机
	if is_on_floor() and (state == State.STATIC or state == State.STUCK):
		_play_idle()


func _ready() -> void:
	_play_idle()

func _physics_process(delta: float) -> void:
	# 下面全是你的原有逻辑，不动
	# 1) Gravity
	if state != State.STUCK and not is_on_floor():
		velocity.y += GRAVITY * delta

	# 2) 地面上按下 → 蓄力
	if is_on_floor() and (state == State.STATIC or state == State.STUCK):
		if Input.is_action_just_pressed("jump"):
			state = State.CHARGING
			charge_time = 0.0
			_play_charge()

	# 3) 蓄力中
	if state == State.CHARGING and Input.is_action_pressed("jump"):
		charge_time = min(charge_time + delta, MAX_CHARGE_TIME)
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)

	# 4) 松开 → 跳
	if state == State.CHARGING and Input.is_action_just_released("jump"):
		var t: float = clampf(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
		t = pow(t, 1.4)
		var jump_v: float = lerpf(MIN_JUMP_V, MAX_JUMP_V, t)
		var base_h: float = lerpf(MIN_H_SPEED, MAX_H_SPEED, t)
		var flight_time: float = abs(jump_v) * 2.0 / GRAVITY
		var h_cap: float = DIST_MAX / max(flight_time, 0.0001)
		var h_speed: float = min(base_h, h_cap) * float(facing)

		velocity.x = h_speed
		velocity.y = jump_v
		floor_snap_length = 0.0

		state = State.JUMPING
		_play_jump()

	# 5) 空中水平衰减
	if state == State.JUMPING and not is_on_floor():
		velocity.x = lerp(velocity.x, 0.0, AIR_CONTROL * delta)

	# 6) 移动
	move_and_slide()

	# 7) 落地
	if state == State.JUMPING and is_on_floor():
		velocity.x = move_toward(velocity.x, 0, 4500 * delta)
		if abs(velocity.x) < 2:
			velocity.x = 0
			state = State.STATIC
			_play_idle()

	# 8) Idle 动画（保持原逻辑，但现在会按 idle_palette 播放）
	if is_on_floor() and (state == State.STATIC or state == State.STUCK):
		_play_idle()
		
func _scale_keep_feet_world(spr: AnimatedSprite2D, anim: StringName, target_scale: float) -> void:
	if spr == null or spr.sprite_frames == null:
		return
	if not spr.sprite_frames.has_animation(anim):
		return

	# 用第 0 帧作为高度基准（若想以当前帧为准，可把 0 换成 spr.frame）
	var tex := spr.sprite_frames.get_frame_texture(anim, 0)
	if tex == null:
		return

	var h := float(tex.get_height())
	var half := h * 0.5

	var base_y := half
	if not spr.centered:
		base_y = h

	# 计算缩放前后底边的世界 y 并补偿
	var bottom_local := spr.offset + Vector2(0.0, base_y)
	var before_y := spr.to_global(bottom_local).y

	# 绝对设置为 target_scale（不会越调用越大）
	spr.scale = Vector2(target_scale, target_scale)

	var after_y := spr.to_global(bottom_local).y
	var dy := before_y - after_y
	spr.global_position.y += dy
