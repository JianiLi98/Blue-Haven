extends Area2D

@onready var portal_anim = $AnimatedSprite2D

func _ready() -> void:
	portal_anim.play("light")
