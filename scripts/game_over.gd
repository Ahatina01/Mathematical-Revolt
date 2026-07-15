extends Control

@onready var restart_btn = $RestartButton
@onready var menu_btn    = $MenuButton

func _ready() -> void:
	restart_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/level_01.tscn"))
	menu_btn.pressed.connect(func():    get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
