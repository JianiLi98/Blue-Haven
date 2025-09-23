extends CharacterBody2D

@export var gravity := 1600.0
@export var min_jump_force := 600.0   # 最小起跳力
@export var max_jump_force := 1000.0  # 最大起跳力
@export var max_charge_time := 1.5    # 蓄力上限秒数

@export var min_distance := 150.0     # 最短水平距离
@export var max_distance := 400.0     # 最远水平距离

var is_charging := false
var charge_time := 0.0

func _physics_process(delta):
	# 下落受重力
	if not is_on_floor():
		velocity.y += gravity * delta

	# 开始蓄力
	if Input.is_action_just_pressed("jump") and is_on_floor():
		is_charging = true
		charge_time = 0.0

	# 持续蓄力
	if is_charging and Input.is_action_pressed("jump"):
		charge_time = min(charge_time + delta, max_charge_time)

	# 松开 → 起跳
	if is_charging and Input.is_action_just_released("jump"):
		var t = clamp(charge_time / max_charge_time, 0.0, 1.0)
		var jump_y = lerp(min_jump_force, max_jump_force, t)
		var jump_x = lerp(min_distance, max_distance, t)
		velocity.y = -jump_y
		velocity.x = jump_x
		is_charging = false

	move_and_slide()
