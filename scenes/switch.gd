extends Area2D

@export var target_anim: StringName = &"purple"   # 撻红→紫
@export var effect_anim: StringName = &"color"
@export var hide_player_during_fx := true
@export var delay_seconds := 2

@onready var fx: AnimatedSprite2D    = $"color/AnimatedSprite2D"
@onready var vis: AnimatedSprite2D   = $"red/AnimatedSprite2D"   # 只保留红色
@onready var shape: CollisionShape2D = $CollisionShape2D

var player: Node
var _done := false
var reappear_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	vis.play("red")
	monitoring = true
	monitorable = true
	if fx:
		fx.visible = false
	if not body_entered.is_connected(_on_enter):
		body_entered.connect(_on_enter)
	if fx and not fx.animation_finished.is_connected(_on_fx_done):
		fx.animation_finished.connect(_on_fx_done)

func _on_enter(b: Node) -> void:
	if _done:
		return

	if not b.has_method("set_idle_palette"):
		push_warning("body 没有 set_idle_palette(): %s" % b.name)
		return

	SoundManager.play_sfx("switch")

	player = b
	shape.disabled = true

	# 锁定玩家控制（播放特效期间禁止一切操作）
	if player.has_method("lock_controls"):
		player.call("lock_controls", true)

	if vis:
		vis.visible = false
	if hide_player_during_fx:
		player.visible = false

	var n2d := player as Node2D
	if n2d:
		reappear_pos = n2d.global_position
	else:
		reappear_pos = global_position

	var has_color_fx := false
	if fx and fx.sprite_frames:
		if fx.sprite_frames.has_animation(effect_anim):
			has_color_fx = true

	if has_color_fx:
		fx.sprite_frames.set_animation_loop(effect_anim, true)
		fx.global_position = reappear_pos
		fx.visible = true
		fx.play(effect_anim)
		_countdown_then_apply()
	else:
		_apply_and_cleanup()

func _countdown_then_apply() -> void:
	await get_tree().create_timer(delay_seconds).timeout
	if _done:
		return
	_done = true
	_apply_and_cleanup()

func _on_fx_done() -> void:
	# 循环特效会提前触发此信号，这里不处理，等计时结束
	pass

func _apply_and_cleanup() -> void:
	if fx:
		fx.visible = false

	if is_instance_valid(player):
		var n2d := player as Node2D
		if n2d:
			n2d.global_position = reappear_pos
		var body := player as CharacterBody2D
		if body:
			body.velocity = Vector2.ZERO

		# 1) 切到 purple（Player 内部会把 charge/jump 切到 pur_char/pur_jump）
		player.call("set_idle_palette", target_anim)

		# 2) BlueAnim 绝对 1.0 并锁脚底
		var blue := (player as Node).get_node_or_null("BlueAnim") as AnimatedSprite2D
		if blue:
			_scale_keep_feet_world(blue, target_anim, 1.0)

		# 3) JumpAnim 绝对 2.0 并锁脚底（以 pur_jump 为基准；若没有则退回 jump）
		var jump := (player as Node).get_node_or_null("JumpAnim") as AnimatedSprite2D
		if jump:
			var basis_anim := "jump"
			if jump.sprite_frames:
				if jump.sprite_frames.has_animation("pur_jump"):
					basis_anim = "pur_jump"
			_scale_keep_feet_world(jump, basis_anim, 2.0)

		# 缩放会改变脚底高度 → 缩放后立即对齐当前状态（可选但更稳）
		if player.has_method("align_jump_to_idle_baseline_current"):
			player.call("align_jump_to_idle_baseline_current")

		# 显示玩家
		player.visible = true

		# 解锁玩家控制
		if player.has_method("lock_controls"):
			player.call("lock_controls", false)

	queue_free()

# 绝对缩放到 target_scale，并保持“脚底 y”不变
func _scale_keep_feet_world(spr, anim, target_scale) -> void:
	if spr == null:
		return
	if spr.sprite_frames == null:
		return
	if not spr.sprite_frames.has_animation(anim):
		return

	var frames = spr.sprite_frames
	var tex = frames.get_frame_texture(anim, 0)
	if tex == null:
		return

	var h = float(tex.get_height())
	var half = h * 0.5

	var base_y = half
	if not spr.centered:
		base_y = h
	var bottom_local = spr.offset + Vector2(0, base_y)

	var before_y = spr.to_global(bottom_local).y

	spr.scale = Vector2(target_scale, target_scale)

	var after_y = spr.to_global(bottom_local).y
	var dy = before_y - after_y
	spr.global_position.y += dy
