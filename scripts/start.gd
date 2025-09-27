extends CharacterBody2D

const GRAVITY := 1000.0
const HOP_INTERVAL := 3.0
const HOP_VY := -380.0
const RUN_SPEED := 100.0
const FLOOR_SNAP := 32.0

var _cooldown := 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var bubble: AnimatedSprite2D = $bubble

func _ready() -> void:
	floor_snap_length = FLOOR_SNAP
	anim.play("jumploop")  # 永远循环播放这个动画
	bubble.play("bubble")
	
func _physics_process(delta: float) -> void:
	# 重力
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 始终向前匀速
	velocity.x = RUN_SPEED

	move_and_slide()


func _on_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn") # Replace with function body. # Replace with function body.
