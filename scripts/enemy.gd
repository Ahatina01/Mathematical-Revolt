extends CharacterBody2D

@export_group("Характеристики")
@export var speed: float           = 100.0
@export var health: int            = 1
@export var damage: int            = 1
@export var attack_cooldown: float = 1.2
@export var windup_duration: float = 0.45
@export var detection_range: float = 320.0

@export_group("Патруль")
@export var patrol_speed:  float = 48.0
@export var patrol_radius: float = 90.0

@export_group("Внешний вид")
@export var normal_color: Color = Color.WHITE
@export var stun_color:   Color = Color(0.4, 0.6, 1.0)


enum State { PATROL, CHASE, WINDUP, ATTACK, STUNNED, DEAD }
var state := State.PATROL


var player: Node = null

var stun_timer:   float = 0.0
var attack_cd:    float = 0.0
var windup_timer: float = 0.0

var _wants_attack: bool = false

var spawn_point:   Vector2
var patrol_target: Vector2
var last_dir:      Vector2 = Vector2.RIGHT

signal enemy_died

func _ready() -> void:
	spawn_point   = global_position
	patrol_target = _rand_patrol_point()
	add_to_group("enemy")

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	$AnimatedSprite2D.modulate = normal_color
	_anim("idle")



func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	attack_cd = maxf(attack_cd - delta, 0.0)

	if _wants_attack:
		_wants_attack = false
		_do_attack()  
		return

	match state:
		State.PATROL:  _tick_patrol()
		State.CHASE:   _tick_chase()
		State.WINDUP:  _tick_windup(delta)
		State.ATTACK:  pass   
		State.STUNNED: _tick_stun(delta)

	_update_state()




func _tick_patrol() -> void:
	var dir  = (patrol_target - global_position).normalized()
	last_dir = dir
	velocity = dir * patrol_speed
	move_and_slide()
	_anim("walk")

	if global_position.distance_to(patrol_target) < 12.0:
		patrol_target = _rand_patrol_point()
		_anim("idle")


func _rand_patrol_point() -> Vector2:
	var angle = randf() * TAU
	var dist  = randf_range(20.0, patrol_radius)
	return spawn_point + Vector2(cos(angle), sin(angle)) * dist




func _tick_chase() -> void:
	if not is_instance_valid(player):
		state = State.PATROL
		return

	var dir  = (player.global_position - global_position).normalized()
	last_dir = dir
	velocity = dir * speed
	move_and_slide()
	_anim("walk")

	if global_position.distance_to(player.global_position) < 42.0 and attack_cd <= 0.0:
		_begin_windup()



func _begin_windup() -> void:
	state        = State.WINDUP
	windup_timer = windup_duration
	velocity     = Vector2.ZERO
	_anim("windup")


func _tick_windup(delta: float) -> void:
	windup_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()

	if windup_timer <= 0.0:
		
		_wants_attack = true




func _do_attack() -> void:
	state     = State.ATTACK
	attack_cd = attack_cooldown
	_anim("attack")

	await get_tree().create_timer(0.15).timeout
	if not is_instance_valid(self) or state != State.ATTACK:
		return

	if is_instance_valid(player):
		if global_position.distance_to(player.global_position) < 55.0:
			player.take_damage(damage)

	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(self) and state == State.ATTACK:
		state = State.CHASE



func apply_stun(duration: float) -> void:
	state      = State.STUNNED
	stun_timer = duration
	velocity   = Vector2.ZERO
	$AnimatedSprite2D.modulate = stun_color
	_anim("stun")


func _tick_stun(delta: float) -> void:
	stun_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()

	if stun_timer <= 0.0:
		$AnimatedSprite2D.modulate = normal_color
		state = State.PATROL



func _update_state() -> void:
	if state in [State.STUNNED, State.WINDUP, State.ATTACK, State.DEAD]:
		return
	if not is_instance_valid(player):
		state = State.PATROL
		return
	var dist = global_position.distance_to(player.global_position)
	state = State.CHASE if dist <= detection_range else State.PATROL


func take_damage(amount: int = 1) -> void:
	if state == State.DEAD:
		return

	health -= amount

	# Мигаем белым при попадании
	$AnimatedSprite2D.modulate = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	if not is_instance_valid(self):
		return
	# Восстанавливаем нужный цвет
	$AnimatedSprite2D.modulate = stun_color if state == State.STUNNED else normal_color

	if health <= 0:
		_die()

func _die():
	state = State.DEAD
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	var frames = $AnimatedSprite2D.sprite_frames
	if frames and frames.has_animation("death"):
		frames.set_animation_loop("death", false)   # отключаем цикл
		_anim("death")
		await $AnimatedSprite2D.animation_finished
		$AnimatedSprite2D.stop()
		$AnimatedSprite2D.frame = frames.get_frame_count("death") - 1
	emit_signal("enemy_died")
	await get_tree().create_timer(2.0).timeout
	queue_free()





#  АНИМАЦИЯ — 4 НАПРАВЛЕНИЯ
#  |x| >= |y| → "e" или "w"
#  |y|  > |x| → "s" или "n"

func _dir4(dir: Vector2) -> String:
	if abs(dir.x) >= abs(dir.y):
		return "e" if dir.x >= 0.0 else "w"
	else:
		return "s" if dir.y >= 0.0 else "n"


func _anim(action: String) -> void:
	var spr: AnimatedSprite2D = $AnimatedSprite2D
	if not spr or not spr.sprite_frames:
		return
	var full   = action + "_" + _dir4(last_dir)
	var frames = spr.sprite_frames
	var target: String
	if frames.has_animation(full):
		target = full
	elif frames.has_animation(action):
		target = action
	else:
		return
	# Не перезапускаем ту же анимацию — избегаем рывков
	if spr.animation != target:
		spr.play(target)
