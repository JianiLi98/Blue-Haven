extends Camera2D

@export var fixed_y := 540.0

func _process(_delta: float) -> void:
	# 强制把相机的 y 固定住
	global_position.y = fixed_y
