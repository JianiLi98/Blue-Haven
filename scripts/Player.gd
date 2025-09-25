extends CharacterBody2D

# ---------- Tunables (bigger = higher & farther) ----------
const GRAVITY := 950.0            # Gravity while airborne (slightly lower -> longer airtime)
const MAX_CHARGE_TIME := 1.20     # Max charge time (hold time) ↑

# Horizontal speed range (maps charge -> distance)
const MIN_H_SPEED := 80.0         # Short tap distance ↑
const MAX_H_SPEED := 420.0        # Long hold distance ↑

# Vertical jump speeds (more negative = higher)
const MIN_JUMP_V := -220.0        # Short tap height ↑
const MAX_JUMP_V := -680.0        # Long hold height ↑

const AIR_CONTROL := 0.06         # Horizontal decay in air (smaller -> glides farther)
const DIST_MAX := 520.0           # Hard cap of horizontal travel ↑

var facing := 1                   # 1: right, -1: left (change if you add left/right control)

# ---------- State machine ----------
enum State { STATIC, CHARGING, JUMPING, STUCK }
var state: State = State.STATIC
var charge_time := 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if anim:
		anim.play("blue ")

func _physics_process(delta: float) -> void:
	# 1) Gravity (not applied when STUCK)
	if state != State.STUCK and not is_on_floor():
		velocity.y += GRAVITY * delta

	# 2) Grounded: start charging
	if is_on_floor() and (state == State.STATIC or state == State.STUCK):
		if Input.is_action_just_pressed("ui_accept"):
			state = State.CHARGING
			charge_time = 0.0
			if anim:
				anim.play("charge")

	# 3) While charging (charge anim is non-loop; will settle on frame 2)
	if state == State.CHARGING and Input.is_action_pressed("ui_accept"):
		charge_time = min(charge_time + delta, MAX_CHARGE_TIME)
		# Stop any horizontal drift while charging
		velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)

	# 4) Release -> Jump (both height & distance scale with charge, also capped by DIST_MAX)
	if state == State.CHARGING and Input.is_action_just_released("ui_accept"):
		var t: float = clampf(charge_time / MAX_CHARGE_TIME, 0.0, 1.0)
		t = pow(t, 1.4)  # Ease to exaggerate difference between short & long press (slightly softer)

		# Height (more negative = higher)
		var jump_v: float = lerpf(MIN_JUMP_V, MAX_JUMP_V, t)

		# Base horizontal speed from charge
		var base_h: float = lerpf(MIN_H_SPEED, MAX_H_SPEED, t)

		# Compute airtime (up + down), then cap horizontal by max travel.
		var flight_time: float = abs(jump_v) * 2.0 / GRAVITY
		var h_cap: float = DIST_MAX / max(flight_time, 0.0001)
		var h_speed: float = min(base_h, h_cap) * float(facing)

		velocity.x = h_speed
		velocity.y = jump_v

		# Disable snap just for the liftoff frame
		floor_snap_length = 0.0

		state = State.JUMPING
		if anim:
			anim.play("jump")

	# 5) Airborne horizontal decay (smaller AIR_CONTROL -> retains speed longer)
	if state == State.JUMPING and not is_on_floor():
		velocity.x = lerp(velocity.x, 0.0, AIR_CONTROL * delta)

	# 6) Movement
	move_and_slide()

	# 7) Stick to floor on landing so you can immediately charge again
	if state == State.JUMPING and is_on_floor():
		_stick_to_floor()

	# 8) Keep idle anim on ground
	if is_on_floor() and (state == State.STATIC or state == State.STUCK):
		if anim and anim.animation != "blue":
			anim.play("blue")

func _stick_to_floor() -> void:
	velocity = Vector2.ZERO
	state = State.STUCK
	if anim:
		anim.play("blue")
	floor_snap_length = 48.0
