extends CharacterBody2D

var jump_charge_name: StringName = &"charge"
var jump_jump_name: StringName   = &"jump"

# ---------- Tunables ----------
const GRAVITY := 1200.0
const MAX_CHARGE_TIME := 1.20

const MIN_H_SPEED := 80.0
const MAX_H_SPEED := 500.0

const MIN_JUMP_V := -220.0
const MAX_JUMP_V := -800.0 

const AIR_CONTROL := 0.06
const DIST_MAX := 400.0    # 最远水平距离保持原值

# 动画速度调节
const JUMP_ANIM_BASE_DUR := 0.6
const CHARGE_ANIM_SPEED_RANGE := Vector2(0.8, 2.0)

# 只用它来放大“重力”，从而加快整段轨迹（上升和下降都更快）
const MIN_PACE := 1.0
const MAX_PACE := 2.0

var facing := 1   # 1: right, -1: left
var pace := 1.0   # 当前跳跃加速倍率（只用于放大重力）

# ---------- State machine ----------
enum State { STATIC, CHARGING, JUMPING, STUCK }
var state: State = State.STATIC
var charge_time := 0.0

@onready var blue_anim: AnimatedSprite2D = $BlueAnim
@onready var jump_anim: AnimatedSprite2D = $JumpAnim

var idle_palette: StringName = &"blue"
var jump_sfx_name: String = "jump"
var in_ocean := false

func set_in_ocean(val: bool) -> void:
	in_ocean = val

# --- 动画控制 ---
func _play_idle():
	blue_anim.visible = true
	jump_anim.visible = false
	if blue_anim.sprite_frames and blue_anim.sprite_frames.has_animation(idle_palette):
		if blue_anim.animation != idle_palette or not blue_anim.is_playing():
			blue_anim.play(idle_palette)
	else:
		blue_anim.play("blue")

func _play_charge():
	blue_anim.visible = false
	jump_anim.visible = true
	jump_anim.play(jump_charge_name)

func _play_jump():
	blue_anim.visible = false
	jump_anim.visible = true
	jump_anim.play(jump_jump_name)

func set_idle_palette(new_palette: StringName) -> void:
	idle_palette = new_palette
	if new_palette == &"purple":
		jump_charge_name = &"pur_char"
		jump_jump_name   = &"pur_jump"
		jump_sfx_name    = "heavyJump"
	elif new_palette == &"green":
		jump_charge_name = &"green_char"
		jump_jump_name   = &"green_jump"
		jump_sfx_name    = "heavyJump"
	else:
		jump_charge_name = &"charge"
		jump_jump_name   = &"jump"
		jump_sfx_name    = "jump"

	if is_on_floor() and (state == State.STATIC or state == State.STUCK):
		_play_idle()

func _ready() -> void:
	_play_idle()

# --------- 工具函数（不用 abs/max） ----------
		
func _vy_mag(v: float) -> float:
	if v < 0.0:
		return -v
	return v

func _calc_flight_time(vy: float, g: float) -> float:
	var vy_mag := _vy_mag(vy)
	if g == 0.0:
		return 0.0
	return (vy_mag * 2.0) / g

func _apply_jump_anim_speed(flight_time: float) -> void:
	if flight_time <= 0.0:
		jump_anim.speed_scale = 1.0
		return
	var scale := JUMP_ANIM_BASE_DUR / flight_time
	if scale < 0.25:
		scale = 0.25
	elif scale > 3.5:
		scale = 3.5
	jump_anim.speed_scale = scale

# --------- 主逻辑 ----------
func _physics_process(delta: float) -> void:
	
	# 只在空中放大重力，统一加快上升和下降节奏
	if state != State.STUCK and not is_on_floor():
		velocity.y += (GRAVITY * pace) * delta

	# Start charging
	if is_on_floor() and (state == State.STATIC or state == State.STUCK):
		if Input.is_action_just_pressed("jump"):
			SoundManager.play_sfx("charge")
			state = State.CHARGING
			charge_time = 0.0
			_play_charge()
			jump_anim.speed_scale = CHARGE_ANIM_SPEED_RANGE.x

	# Charging
	if state == State.CHARGING and Input.is_action_pressed("jump"):
		charge_time = min(charge_time + delta, MAX_CHARGE_TIME)
		var k := clampf(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
		jump_anim.speed_scale = lerpf(CHARGE_ANIM_SPEED_RANGE.x, CHARGE_ANIM_SPEED_RANGE.y, k)

	# Release → Jump
	if state == State.CHARGING and Input.is_action_just_released("jump"):
		SoundManager.stop_sfx("charge")
		SoundManager.play_sfx(jump_sfx_name)

		var t: float = clampf(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
		t = pow(t, 1.4)

		# —— 基线（未加速重力）用于求应得位移 —— #
		var base_vy := lerpf(MIN_JUMP_V, MAX_JUMP_V, t)   # 负值向上，不改它
		var base_flight := _calc_flight_time(base_vy, GRAVITY)
		var base_h := lerpf(MIN_H_SPEED, MAX_H_SPEED, t)

		# 先求基线的“应得距离”，并严格夹到 DIST_MAX（保持与之前一致的上限）
		var unclamped_dist := base_h * base_flight
		var target_dist := unclamped_dist
		if target_dist > DIST_MAX:
			target_dist = DIST_MAX
		elif target_dist < 0.0:
			target_dist = 0.0

		# —— 只用 pace 放大“重力”来加快整体节奏 —— #
		pace = lerpf(MIN_PACE, MAX_PACE, t)
		if pace <= 0.0:
			pace = 0.01

		# 加强重力后的飞行时间（Vy 不变，g 变大）
		var new_flight := _calc_flight_time(base_vy, GRAVITY * pace)
		if new_flight <= 0.0:
			new_flight = 0.001

		# 为了保持总位移 == target_dist，反推需要的水平速度
		var need_vx := 0.0
		if new_flight > 0.0:
			need_vx = (target_dist / new_flight) * float(facing)

		# 应用起跳速度：Vy 用基线值（不变），Vx 用反推值
		velocity.y = base_vy
		velocity.x = need_vx

		floor_snap_length = 0.0
		state = State.JUMPING

		# 动画速度也匹配“加快后的飞行时间”
		_apply_jump_anim_speed(new_flight)
		_play_jump()

	# Air control（保留轻微空控，不会让距离更远，只会变短）
	if state == State.JUMPING and not is_on_floor():
		velocity.x = lerp(velocity.x, 0.0, AIR_CONTROL * delta)

	# Ocean effect（保持你的原逻辑）
	if in_ocean:
		velocity.y = lerp(velocity.y, 150.0, 0.15)
		velocity.x = lerp(velocity.x, 0.0, 0.15)

	# Move
	move_and_slide()

	# Landing
	if state == State.JUMPING and is_on_floor():
		velocity.x = move_toward(velocity.x, 0, 4500 * delta)
		if velocity.x < 0.0:
			if -velocity.x < 2.0:
				velocity.x = 0.0
				state = State.STATIC
				_play_idle()
		else:
			if velocity.x < 2.0:
				velocity.x = 0.0
				state = State.STATIC
				_play_idle()

	# Idle fallback
	if is_on_floor() and (state == State.STATIC or state == State.STUCK):
		_play_idle()

# --- 保持脚下缩放 ---
func _scale_keep_feet_world(spr: AnimatedSprite2D, anim: StringName, target_scale: float) -> void:
	if spr == null or spr.sprite_frames == null:
		return
	if not spr.sprite_frames.has_animation(anim):
		return

	var tex := spr.sprite_frames.get_frame_texture(anim, 0)
	if tex == null:
		return

	var h := float(tex.get_height())
	var half := h * 0.5
	var base_y := half
	if not spr.centered:
		base_y = h

	var bottom_local := spr.offset + Vector2(0.0, base_y)
	var before_y := spr.to_global(bottom_local).y

	spr.scale = Vector2(target_scale, target_scale)

	var after_y := spr.to_global(bottom_local).y
	var dy := before_y - after_y
	spr.global_position.y += dy
