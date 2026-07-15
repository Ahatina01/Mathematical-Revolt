extends Control

@onready var btn_play          = $MainButtons/BtnPlay
@onready var btn_settings      = $MainButtons/BtnSettings
@onready var btn_exit          = $MainButtons/BtnExit
@onready var settings_panel    = $SettingsPanel

# Новые пути: элементы теперь внутри TabContainer/AudioTab
@onready var fullscreen_check  = $SettingsPanel/TabContainer/Общие/FullscreenCheck
@onready var volume_slider     = $SettingsPanel/TabContainer/Общие/VolumeSlider
@onready var btn_close         = $SettingsPanel/TabContainer/Общие/BtnSettingsClose

func _ready():
	btn_play.pressed.connect(_on_play)
	btn_settings.pressed.connect(func(): settings_panel.visible = true)
	btn_exit.pressed.connect(get_tree().quit)
	btn_close.pressed.connect(_on_settings_close)
	fullscreen_check.toggled.connect(_on_fullscreen)
	volume_slider.value_changed.connect(_on_volume)

	settings_panel.visible = false
	_load_settings()

func _input(event: InputEvent):
	if event is InputEventKey and event.is_action_pressed("fullscreen"):
		_toggle_fullscreen()

func _on_play():
	get_tree().change_scene_to_file("res://scenes/video_intro.tscn")

func _on_settings_close():
	settings_panel.visible = false
	_save_settings()

func _on_fullscreen(enabled: bool):
	var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)

func _toggle_fullscreen():
	var now = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_check.button_pressed = not now
	_on_fullscreen(not now)

func _on_volume(value: float):
	AudioServer.set_bus_volume_db(0, linear_to_db(value / 100.0))

func _save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen_check.button_pressed)
	cfg.set_value("audio", "volume", volume_slider.value)
	cfg.save("user://settings.cfg")

func _load_settings():
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	var fs = cfg.get_value("display", "fullscreen", false)
	fullscreen_check.button_pressed = fs
	_on_fullscreen(fs)
	var vol = cfg.get_value("audio", "volume", 80.0)
	volume_slider.value = vol
	_on_volume(vol)
