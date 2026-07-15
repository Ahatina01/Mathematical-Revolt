extends Node2D

@export var total_enemies: int     = 25      # всего врагов на уровне
@export var boss_threshold: int    = 25      # убийств до появления босса
@export var kills_per_point: int   = 5       # убийств за 1 очко прокачки
@export var points_for_boss: int   = 5       # очков за босса

@export var use_literature_in_upgrade: bool = true   # на втором уровне — литературные вопросы

@onready var player       = $Player
@onready var upgrade_menu = $UpMenu
@onready var score_label  = $UI/ScoreLabel
@onready var point_notify = $UI/PointNotify

var enemy_fast: PackedScene
var enemy_tank: PackedScene
var boss_scene: PackedScene

var total_kills:   int = 0
var kills_in_batch: int = 0
var boss_spawned:  bool = false

func _ready():
	_load_scenes()
	_spawn_all_enemies()
	if player and player.has_signal("player_died"):
		player.player_died.connect(_on_player_died)
	point_notify.visible = false
	_update_score()
	
	# Передаём флаг литературы в меню прокачки
	if upgrade_menu and upgrade_menu.has_method("set_question_mode"):
		upgrade_menu.set_question_mode("lit" if use_literature_in_upgrade else "math")

func _load_scenes():
	if ResourceLoader.exists("res://scenes/enemy_fast.tscn"):
		enemy_fast = load("res://scenes/enemy_fast.tscn")
	if ResourceLoader.exists("res://scenes/enemy_tank.tscn"):
		enemy_tank = load("res://scenes/enemy_tank.tscn")
	if ResourceLoader.exists("res://scenes/boss.tscn"):
		boss_scene = load("res://scenes/boss.tscn")

func _spawn_all_enemies():
	for i in range(total_enemies):
		_spawn_one_enemy()

func _spawn_one_enemy():
	var scene = _pick_enemy()
	if not scene: return
	var enemy = scene.instantiate()
	enemy.global_position = _get_spawn_pos()
	enemy.enemy_died.connect(_on_enemy_killed)
	add_child(enemy)

func _pick_enemy():
	if enemy_fast and enemy_tank:
		return enemy_fast if randf() < 0.6 else enemy_tank
	return enemy_fast if enemy_fast else enemy_tank

func _on_enemy_killed():
	total_kills += 1
	kills_in_batch += 1
	_update_score()

	if kills_in_batch >= kills_per_point:
		kills_in_batch = 0
		_give_points(1)
		_show_point_notify()

	if total_kills >= boss_threshold and not boss_spawned:
		_spawn_boss()

func _spawn_boss():
	if not boss_scene:
		push_warning("boss.tscn не найден")
		return
	boss_spawned = true
	var boss = boss_scene.instantiate()
	boss.global_position = _get_spawn_pos()
	boss.boss_died.connect(_on_boss_killed)
	add_child(boss)

func _on_boss_killed():
	_give_points(points_for_boss)
	# Переход на катсцену между уровнями (или сразу в конец игры)
	get_tree().change_scene_to_file("res://scenes/level_03.tscn")

func _on_player_died():
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _update_score():
	if score_label:
		score_label.text = "Побеждено: %d / %d" % [total_kills, boss_threshold]

func _give_points(amount: int):
	if upgrade_menu and upgrade_menu.has_method("add_points"):
		upgrade_menu.add_points(amount)

func _show_point_notify():
	point_notify.text = "⚡ ПОЛУЧЕН 1 УМ!"
	point_notify.visible = true
	await get_tree().create_timer(1.2).timeout
	point_notify.visible = false

func _get_spawn_pos() -> Vector2:
	var points = get_tree().get_nodes_in_group("spawn_point")
	if points.size() > 0:
		return points[randi() % points.size()].global_position
	var r = get_viewport().get_visible_rect()
	match randi() % 4:
		0: return Vector2(randf_range(0, r.size.x), -50)
		1: return Vector2(randf_range(0, r.size.x), r.size.y + 50)
		2: return Vector2(-50, randf_range(0, r.size.y))
		_: return Vector2(r.size.x + 50, randf_range(0, r.size.y))

func _on_menu_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
