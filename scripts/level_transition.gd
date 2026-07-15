extends Control

@export var next_scene: String = "res://scenes/level_02.tscn"
@onready var video = $VideoPlayer
@onready var skip_btn = $SkipButton

func _ready() -> void:
	video.expand = true
	video.size = get_viewport().get_visible_rect().size
	# Растягиваем видео на весь экран
	video.finished.connect(_go_next)
	skip_btn.pressed.connect(_go_next)
	skip_btn.visible = false
	if not video.stream:
		_go_next()
		return
	video.play()
	await get_tree().create_timer(0.5).timeout
	skip_btn.visible = true

func _input(event):
	if event is InputEventKey and event.is_action_pressed("ui_accept"):
		_go_next()

func _go_next():
	get_tree().change_scene_to_file(next_scene)
