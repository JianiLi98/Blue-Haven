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

var facing := 1   # 1 right  -1 left

# ---------- State machine ----------
enum State { STATIC, CHARGING, JUMPING, STUCK }
var state: State = State.STATIC
var charge_time := 0.0

@onready var blue_anim: AnimatedSprite2D = $BlueAnim
@onready var jump_anim: AnimatedSprite2D = $JumpAnim
@onready var collider: CollisionShape2D = $CollisionShape2D

var jump_sfx_name: String = "jump"

# ---------- Flip / Mirror World ----------
@export var mirror_y: float = 540.0        # set to your real axis
@export var flip_cooldown: float = 0.30
@export var ground_mask: int = 3
@export var probe_down: float = 900.0
@export var only_flip_on_floor := false
@export var mirror_guard: float = 6.0

@export var place_eps: float = 1.0
@export var snap_len: float = 16.0
@export var extra_down_offset: float = 0.0   # set 0 to avoid gaps; change if you need

var _last_flip_time := -999.0
var _is_flipping := false
var inverted := false   # false upright  true hanging

# ----------------- Anim helpers -----------------
func _feet_world_y_for(spr: AnimatedSprite2D, anim_name: StringName) -> float:
	if spr == null:
		return spr.global_position.y
	if spr.sprite_frames == null:
		return spr.global_position.y
	if not spr.sprite_frames.has_animation(anim_name):
		return spr.global_position.y
	var tex := spr.sprite_frames.get_frame_texture(anim_name, 0)
	if tex == null:
		return spr.global_position.y
	var h := float(tex.get_height())
	var base_y := h * 0.5
	if not spr.centered:
		base_y = h
	var bottom_local := spr.offset + Vector2(0.0, base_y)
	return spr.to_global(bottom_local).y

func _align_jump_to_idle_baseline_for(anim_name: StringName) -> void:
	var idle_anim_name: StringName = &"blue"
	if not (blue_anim.sprite_frames and blue_anim.sprite_frames.has_animation(idle_anim_name)):
		idle_anim_name = blue_anim.animation
	var idle_bottom := _feet_world_y_for(blue_anim, idle_anim_name)
	var jump_bottom := _feet_world_y_for(jump_anim, anim_name)
	var dy := idle_bottom - jump_bottom
	jump_anim.global_position.y += dy

# ----------------- Anim -----------------
func _play_idle():
	blue_anim.visible = true
	jump_anim.visible = false
	blue_anim.flip_v = inverted
	if blue_anim.sprite_frames and blue_anim.sprite_frames.has_animation(&"blue"):
		if blue_anim.animation != &"blue" or not blue_anim.is_playing():
			blue_anim.play(&"blue")

func _play_charge():
	blue_anim.visible = false
	jump_anim.visible = true
	jump_anim.flip_v = inverted
	jump_anim.play(jump_charge_name)
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
	# allow down only when upright  allow up only when hanging
	if Input.is_action_just_pressed("ui_down") and not inverted:
		_flip_to(true)
	elif Input.is_action_just_pressed("ui_up") and inverted:
		_flip_to(false)

	# gravity
	if state != State.STUCK and not is_on_floor():
		if inverted:
			velocity.y += -GRAVITY * delta
		else:
			velocity.y += GRAVITY * delta

	# start charge on floor
	if is_on_floor() and state in [State.STATIC, State.STUCK]:
		if Input.is_action_just_pressed("jump"):
			SoundManager.play_sfx("charge")
			state = State.CHARGING
			charge_time = 0.0
			_play_charge()

	# charging
	if state == State.CHARGING and Input.is_action_pressed("jump"):
		print("!!!!")
		charge_time += delta
		if charge_time > MAX_CHARGE_TIME:
			charge_time = MAX_CHARGE_TIME
		var step := 2000.0 * delta
		if velocity.x > 0.0:
			velocity.x -= step
			if velocity.x < 0.0:
				velocity.x = 0.0
		elif velocity.x < 0.0:
			velocity.x += step
			if velocity.x > 0.0:
				velocity.x = 0.0

	# release to jump
	if state == State.CHARGING and Input.is_action_just_released("jump"):
		SoundManager.stop_sfx("charge")
		SoundManager.play_sfx(jump_sfx_name)

		var t := charge_time / MAX_CHARGE_TIME
		if t < 0.0:
			t = 0.0
		if t > 1.0:
			t = 1.0
		t = t ** 1.4

		var jump_v := MIN_JUMP_V + (MAX_JUMP_V - MIN_JUMP_V) * t
		if inverted:
			jump_v = -jump_v

		var base_h := MIN_H_SPEED + (MAX_H_SPEED - MIN_H_SPEED) * t
		var vabs := jump_v
		if vabs < 0.0:
			vabs = -vabs
		var flight_time := vabs * 2.0 / GRAVITY
		if flight_time < 0.0001:
			flight_time = 0.0001
		var h_cap := DIST_MAX / flight_time
		var h_speed := base_h
		if h_speed > h_cap:
			h_speed = h_cap
		h_speed *= float(facing)

		velocity.x = h_speed
		velocity.y = jump_v
		floor_snap_length = 0.0

		state = State.JUMPING
		_play_jump()

	# air horizontal damping
	if state == State.JUMPING and not is_on_floor():
		velocity.x = lerp(velocity.x, 0.0, AIR_CONTROL * delta)

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
	if is_on_floor() and state in [State.STATIC, State.STUCK]:
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

	var current_y := global_position.y
	var mirrored_y := 2.0 * mirror_y - current_y
	var x := global_position.x

	# ray strictly inside target half  always cast downward
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

	var target_pos: Vector2
	if target_inverted:
		target_pos = Vector2(x, surface_y + foot_h + place_eps + extra_down_offset)
	else:
		target_pos = Vector2(x, surface_y - foot_h - place_eps)

	# apply transform and snap firmly to the new floor
	global_position = target_pos
	velocity = Vector2.ZERO
	inverted = target_inverted
	if inverted:
		up_direction = Vector2.DOWN
	else:
		up_direction = Vector2.UP
	blue_anim.flip_v = inverted
	jump_anim.flip_v = inverted

	floor_snap_length = snap_len
	move_and_slide()
	move_and_slide()

	var tries := 10
	while not is_on_floor() and tries > 0:
		if inverted:
			global_position.y += 1.0
		else:
			global_position.y -= 1.0
		move_and_slide()
		tries -= 1

	state = State.STATIC
	_play_idle()

	_last_flip_time = now
	_is_flipping = false
	SoundManager.play_sfx("switch")

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
