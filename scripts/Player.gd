extends CharacterBody2D

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

# --- 动画控制 ---
func _play_idle():
	blue_anim.visible = true
	jump_anim.visible = false
	blue_anim.play("blue")

func _play_charge():
	blue_anim.visible = false
	jump_anim.visible = true
	jump_anim.play("charge")

func _play_jump():
	blue_anim.visible = false
	jump_anim.visible = true
	jump_anim.play("jump")

func _ready() -> void:
	_play_idle()

func _physics_process(delta: float) -> void:
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

	# 8) Idle 动画
	if is_on_floor() and (state == State.STATIC or state == State.STUCK):
		_play_idle()
