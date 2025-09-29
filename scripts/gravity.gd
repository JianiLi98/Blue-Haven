extends CharacterBody2D

var jump_charge_name: StringName = &"charge"
var jump_jump_name:   StringName = &"jump"

# ---------- Tunables ----------
const GRAVITY := 1200.0
const MAX_CHARGE_TIME := 1.20
const MIN_H_SPEED := 80.0
const MAX_H_SPEED := 500.0
const MIN_JUMP_V := -220.0
const MAX_JUMP_V := -800.0
const AIR_CONTROL := 0.06
const DIST_MAX := 400.0

var facing := 1   # 1 right  -1 left

# ---------- State machine ----------
enum State { STATIC, CHARGING, JUMPING, STUCK }
var state: State = State.STATIC
var charge_time := 0.0

@onready var blue_anim: AnimatedSprite2D = $BlueAnim
@onready var jump_anim: AnimatedSprite2D = $JumpAnim
@onready var collider: CollisionShape2D   = $CollisionShape2D

var jump_sfx_name: String = "jump"

# ---------- Flip / Mirror World ----------
@export var mirror_y: float = 540.0
@export var flip_cooldown: float = 0.30
@export var ground_mask: int = 3
@export var probe_down: float = 900.0
@export var only_flip_on_floor := false
@export var mirror_guard: float = 6.0

@export var place_eps_up: float = 0.0
@export var place_eps_down: float = 0.0
@export var snap_len: float = 16.0
@export var extra_down_offset: float = 0.0

var _last_flip_time := -999.0
var _is_flipping := false
var inverted := false

# ---------- SFX names ----------
@export var sfx_flip_down: String = "down"
@export var sfx_flip_up:   String = "up"

# ---------- Jump pacing & animation ----------
const JUMP_ANIM_BASE_DUR := 0.6
const CHARGE_ANIM_SPEED_RANGE := Vector2(0.8, 2.0)
const MIN_PACE := 1.0
const MAX_PACE := 2.0

var pace := 1.0

# ---------- Transform / Palette ----------
var idle_palette: StringName = &"blue"
var in_ocean := false

func set_in_ocean(val: bool) -> void:
	in_ocean = val

func set_idle_palette(new_palette: StringName) -> void:
	# 切换待机调色板，并同步 charge/jump 动画名与音效
	idle_palette = new_palette
	if String(new_palette) == "purple":
		jump_charge_name = &"pur_char"
		jump_jump_name   = &"pur_jump"
		jump_sfx_name    = "heavyJump"
	elif String(new_palette) == "green":
		jump_charge_name = &"green_char"
		jump_jump_name   = &"green_jump"
		jump_sfx_name    = "heavyJump"
	else:
		jump_charge_name = &"charge"
		jump_jump_name   = &"jump"
		jump_sfx_name    = "jump"

	# 若当前在地面且处于 idle/stuck，则立即切到新待机动画
	if is_on_floor():
		if state == State.STATIC or state == State.STUCK:
			_play_idle()

# ----------------- Anim helpers -----------------
func _feet_world_y_for(spr: AnimatedSprite2D, anim_name: StringName) -> float:
	if spr == null:
		return 0.0
	if spr.sprite_frames == null:
		return spr.global_position.y
	if not spr.sprite_frames.has_animation(anim_name):
		return spr.global_position.y

	var tex := spr.sprite_frames.get_frame_texture(anim_name, 0)
	if tex == null:
		return spr.global_position.y

	var h := float(tex.get_height())
	var half := h * 0.5

	var down_local: Vector2
	var up_local: Vector2
	if spr.centered:
		down_local = Vector2(0.0,  half)
		up_local   = Vector2(0.0, -half)
	else:
		down_local = Vector2(0.0, h)
		up_local   = Vector2(0.0, 0.0)

	var feet_local: Vector2
	if spr.flip_v:
		feet_local = up_local
	else:
		feet_local = down_local

	var bottom_local := spr.offset + feet_local
	return spr.to_global(bottom_local).y

func _align_jump_to_idle_baseline_for(anim_name: StringName) -> void:
	var idle_anim_name: StringName = idle_palette
	if blue_anim.sprite_frames == null:
		idle_anim_name = blue_anim.animation
	elif not blue_anim.sprite_frames.has_animation(idle_anim_name):
		idle_anim_name = blue_anim.animation

	var idle_bottom := _feet_world_y_for(blue_anim, idle_anim_name)
	var jump_bottom := _feet_world_y_for(jump_anim, anim_name)
	var dy := idle_bottom - jump_bottom
	jump_anim.global_position.y += dy

func align_jump_to_idle_baseline_current() -> void:
	# 供道具触发后对齐（外部会在缩放后调用）
	if state == State.CHARGING:
		_align_jump_to_idle_baseline_for(jump_charge_name)
	else:
		_align_jump_to_idle_baseline_for(jump_jump_name)

# --------- 工具函数 ----------
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

# ----------------- Anim -----------------
func _play_idle():
	blue_anim.visible = true
	jump_anim.visible = false
	blue_anim.flip_v = inverted

	var anim_to_play: StringName = idle_palette
	var can_play := false
	if blue_anim.sprite_frames:
		if blue_anim.sprite_frames.has_animation(anim_to_play):
			can_play = true
	if not can_play:
		anim_to_play = &"blue"

	if blue_anim.animation != anim_to_play or not blue_anim.is_playing():
		blue_anim.play(anim_to_play)

func _play_charge():
	blue_anim.visible = false
	jump_anim.visible = true
	jump_anim.flip_v = inverted
	jump_anim.play(jump_charge_name)
	jump_anim.speed_scale = CHARGE_ANIM_SPEED_RANGE.x
	_align_jump_to_idle_baseline_for(jump_charge_name)

func _play_jump():
	blue_anim.visible = false
	jump_anim.visible = true
	jump_anim.flip_v = inverted
	jump_anim.play(jump_jump_name)
	_align_jump_to_idle_baseline_for(jump_jump_name)

# ----------------- Lifecycle -----------------
func _ready() -> void:
	up_direction = Vector2.UP
	_play_idle()

func _physics_process(delta: float) -> void:
	# flip control
	if Input.is_action_just_pressed("ui_down") and not inverted:
		_flip_to(true)
	elif Input.is_action_just_pressed("ui_up") and inverted:
		_flip_to(false)

	# gravity（空中时用 pace 放大重力；倒置则取反方向）
	if state != State.STUCK and not is_on_floor():
		var g := GRAVITY * pace
		if inverted:
			velocity.y += -g * delta
		else:
			velocity.y += g * delta

	# start charge on floor
	if is_on_floor():
		if state == State.STATIC or state == State.STUCK:
			if Input.is_action_just_pressed("jump"):
				SoundManager.play_sfx("charge")
				state = State.CHARGING
				charge_time = 0.0
				_play_charge()

	# charging（推进蓄力动画的速度 0.8 → 2.0）
	if state == State.CHARGING and Input.is_action_pressed("jump"):
		charge_time += delta
		if charge_time > MAX_CHARGE_TIME:
			charge_time = MAX_CHARGE_TIME

		# 清水平速度
		var step := 2000.0 * delta
		if velocity.x > 0.0:
			velocity.x -= step
			if velocity.x < 0.0:
				velocity.x = 0.0
		elif velocity.x < 0.0:
			velocity.x += step
			if velocity.x > 0.0:
				velocity.x = 0.0

		# 蓄力动画速度插值
		var k := charge_time / MAX_CHARGE_TIME
		if k < 0.0:
			k = 0.0
		if k > 1.0:
			k = 1.0
		jump_anim.speed_scale = lerp(CHARGE_ANIM_SPEED_RANGE.x, CHARGE_ANIM_SPEED_RANGE.y, k)

	# release to jump（关键：与正向完全等价）
	if state == State.CHARGING and Input.is_action_just_released("jump"):
		SoundManager.stop_sfx("charge")
		SoundManager.play_sfx(jump_sfx_name)

		var t := charge_time / MAX_CHARGE_TIME
		if t < 0.0:
			t = 0.0
		if t > 1.0:
			t = 1.0
		t = pow(t, 1.4)

		# —— 基线（未加速重力）用于求应得位移 —— #
		var base_vy := MIN_JUMP_V + (MAX_JUMP_V - MIN_JUMP_V) * t  # 负值向上
		if inverted:
			base_vy = -base_vy

		var base_flight := _calc_flight_time(base_vy, GRAVITY)
		if base_flight <= 0.0:
			base_flight = 0.001

		var base_h := MIN_H_SPEED + (MAX_H_SPEED - MIN_H_SPEED) * t

		# 求基线的“应得水平距离”，夹到 DIST_MAX
		var unclamped_dist := base_h * base_flight
		var target_dist := unclamped_dist
		if target_dist > DIST_MAX:
			target_dist = DIST_MAX
		if target_dist < 0.0:
			target_dist = 0.0

		# —— 只用 pace 放大“重力”来加快整体节奏（Vy 不变） —— #
		pace = MIN_PACE + (MAX_PACE - MIN_PACE) * t
		if pace <= 0.0:
			pace = 0.01

		# 加强重力后的飞行时间（方向已在 Vy）
		var new_flight := _calc_flight_time(base_vy, GRAVITY * pace)
		if new_flight <= 0.0:
			new_flight = 0.001

		# 反推水平速度，使总水平位移 == target_dist
		var need_vx := 0.0
		if new_flight > 0.0:
			need_vx = (target_dist / new_flight) * float(facing)

		# 应用起跳速度
		velocity.x = need_vx
		velocity.y = base_vy
		floor_snap_length = 0.0

		state = State.JUMPING
		_apply_jump_anim_speed(new_flight)  # 动画节奏匹配飞行时间
		_play_jump()

	# Air control（轻微空控：只会缩短距离，不会变远）
	if state == State.JUMPING and not is_on_floor():
		velocity.x = lerp(velocity.x, 0.0, AIR_CONTROL * delta)

	# Ocean effect（可选：如需水中迟滞）
	if in_ocean:
		velocity.y = lerp(velocity.y, 150.0, 0.15)
		velocity.x = lerp(velocity.x, 0.0, 0.15)

	# move
	move_and_slide()

	# land
	if state == State.JUMPING and is_on_floor():
		var step2 := 4500.0 * delta
		if velocity.x > 0.0:
			velocity.x -= step2
			if velocity.x < 0.0:
				velocity.x = 0.0
		elif velocity.x < 0.0:
			velocity.x += step2
			if velocity.x > 0.0:
				velocity.x = 0.0

		if abs(velocity.x) < 2.0:
			velocity.x = 0.0
			state = State.STATIC
			_play_idle()

	# keep idle fresh on floor
	if is_on_floor():
		if state == State.STATIC or state == State.STUCK:
			_play_idle()

# ----------------- Flip -----------------
func _flip_to(target_inverted: bool) -> void:
	if _is_flipping:
		return
	if only_flip_on_floor and not is_on_floor():
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_flip_time < flip_cooldown:
		return
	_is_flipping = true

	# 若在蓄力中翻转，先停掉蓄力音并回到静止（更稳）
	if state == State.CHARGING:
		SoundManager.stop_sfx("charge")
		state = State.STATIC
		charge_time = 0.0
		_play_idle()

	var x := global_position.x
	var current_y := global_position.y
	var mirrored_y := 2.0 * mirror_y - current_y

	# 在目标半区内，始终向“下”射线探地面
	var from: Vector2
	var to: Vector2
	if target_inverted:
		var start_y := mirror_y + mirror_guard + 1.0
		if start_y < mirrored_y - 2.0:
			start_y = mirrored_y - 2.0
		from = Vector2(x, start_y)
		to   = Vector2(x, start_y + probe_down)
	else:
		var end_y := mirror_y - mirror_guard - 1.0
		var start_y2 := end_y - probe_down
		if start_y2 > mirrored_y + 2.0:
			start_y2 = mirrored_y + 2.0
		from = Vector2(x, start_y2)
		to   = Vector2(x, end_y)

	var hit := _raycast_first(from, to, ground_mask)
	if hit.is_empty():
		hit = _raycast_first(from, to, 0x7FFFFFFF)
	if hit.is_empty():
		_is_flipping = false
		return

	var surface_y: float = (hit["position"] as Vector2).y
	var foot_h := _feet_half_height()

	# 目标落点：轻微“压入”地面 0.25px，交给分离器贴回
	var target_pos: Vector2
	if target_inverted:
		target_pos = Vector2(x, surface_y + foot_h + place_eps_down - 0.25 + extra_down_offset)
	else:
		target_pos = Vector2(x, surface_y - foot_h - place_eps_up + 0.25)

	# 应用位姿
	global_position = target_pos
	velocity = Vector2.ZERO
	inverted = target_inverted
	if inverted:
		up_direction = Vector2.DOWN
	else:
		up_direction = Vector2.UP
	blue_anim.flip_v = inverted
	jump_anim.flip_v = inverted

	# 一帧内强力贴地
	var old_snap := floor_snap_length
	if snap_len > 48.0:
		floor_snap_length = snap_len
	else:
		floor_snap_length = 48.0
	if inverted:
		velocity.y = -30.0
	else:
		velocity.y = 30.0
	move_and_slide()
	floor_snap_length = old_snap

	# 保险：半像素步进收尾
	var tries := 12
	while not is_on_floor() and tries > 0:
		if inverted:
			global_position.y += 0.5
		else:
			global_position.y -= 0.5
		move_and_slide()
		tries -= 1

	state = State.STATIC
	_play_idle()

	_last_flip_time = now
	_is_flipping = false

	# 翻转音效
	if target_inverted:
		SoundManager.play_sfx(sfx_flip_down)
	else:
		SoundManager.play_sfx(sfx_flip_up)

# ----------------- Helpers -----------------
func _feet_half_height() -> float:
	if collider and collider.shape:
		var s := collider.shape
		if s is RectangleShape2D:
			return (s as RectangleShape2D).size.y * 0.5
		elif s is CapsuleShape2D:
			var r := (s as CapsuleShape2D).radius
			var h := (s as CapsuleShape2D).height
			return (h + 2.0 * r) * 0.5
		elif s is CircleShape2D:
			return (s as CircleShape2D).radius
	return 16.0

func _raycast_first(from: Vector2, to: Vector2, mask: int) -> Dictionary:
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.collision_mask = mask
	params.exclude = [self]
	params.collide_with_bodies = true
	params.collide_with_areas = true
	params.hit_from_inside = true
	var res := space.intersect_ray(params)
	if "position" in res:
		return res
	var empty := {}
	return empty
