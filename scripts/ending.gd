extends Control

@onready var video = $VideoPlayer
@onready var skip_btn = $SkipButton

func _ready():
	video.expand = true
	video.size = get_viewport().get_visible_rect().size
	video.finished.connect(_on_finished)
	skip_btn.pressed.connect(_skip)
	skip_btn.visible = false
	# Показываем кнопку через 0.5 секунды
	await get_tree().create_timer(0.5).timeout
	skip_btn.visible = true

func _input(event):
	if event.is_action_pressed("ui_accept"):   # Пробел или Enter
		_skip()

func _skip():
	if video.is_playing():
		video.stop()
	_on_finished()

func _on_finished():
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
