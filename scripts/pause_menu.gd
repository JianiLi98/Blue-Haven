extends Control

@onready var continue_btn = $VBoxContainer/ContinueButton
@onready var exit_btn = $VBoxContainer/ExitButton

func _ready():
	visible = false
	continue_btn.pressed.connect(_on_continue_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

func show_menu():
	visible = true
	get_tree().paused = true

func hide_menu():
	visible = false
	get_tree().paused = false

func _on_continue_pressed():
	print("continue!") 
	hide_menu()

func _on_exit_pressed():
	print("exit!") 
	get_tree().quit()
