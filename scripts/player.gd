extends CharacterBody2D

@export_group("Движение")
@export var move_speed: float = 280.0

@export_group("Здоровье")
@export var max_health: int = 5
@export var armor: int = 0

@export_group("Выносливость")
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 22.0

@export_group("Кувырок")
@export var roll_speed: float = 580.0
@export var roll_duration: float = 0.32
@export var roll_cost: float = 30.0
@export var roll_cooldown: float = 0.65

@export_group("Блок")
@export var block_hit_cost: float = 25.0
@export var block_speed_mult: float = 0.4

@export_group("Атака")
@export var attack_damage: int = 1
@export var attack_duration: float = 0.28
@export var attack_cost: float = 15.0

@onready var anim:        AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape:  CollisionShape2D = $CollisionShape2D
@onready var attack_area: Area2D           = $AttackArea

# Ссылка на Label для отображения сердец (путь подстрой под свою сцену)
@onready var health_label: Label = get_node("../UI/HealthLabel")

enum State { IDLE, WALK, ROLL, ATTACK, BLOCK_START, BLOCK_HOLD, DEAD }
var state := State.IDLE

var move_dir := Vector2.ZERO
var last_dir := Vector2.RIGHT

var current_health:  int
var current_stamina: float

var roll_dir   := Vector2.ZERO
var roll_timer := 0.0
var roll_cd    := 0.0

var block_start_timer:    float = 0.0
var block_start_duration: float = 0.18

var attack_timer := 0.0
var attack_cd    := 0.0

var health_bar:  ProgressBar = null
var stamina_bar: ProgressBar = null

signal player_died

# ============================================================
#  _ready()
# ============================================================
func _ready() -> void:
	current_health  = max_health
	current_stamina = max_stamina
	add_to_group("player")

	# Поиск баров (если есть)
	var hb = get_tree().get_nodes_in_group("health_bar")
	if hb.size() > 0:
		health_bar = hb[0]
		health_bar.max_value = max_health
		health_bar.value = current_health

	var sb = get_tree().get_nodes_in_group("stamina_bar")
	if sb.size() > 0:
		stamina_bar = sb[0]
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina

	# Обновляем отображение сердец
	update_health_display()

# ============================================================
#  ОТОБРАЖЕНИЕ ЗДОРОВЬЯ (текстовые сердечки)
# ============================================================
func update_health_display() -> void:
	if not health_label:
		return
	var hearts = ""
	for i in range(max_health):
		if i < current_health:
			hearts += "❤"
		else:
			hearts += "🖤"
	health_label.text = hearts

# ============================================================
#  Физика и состояния
# ============================================================
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	roll_cd   = maxf(roll_cd   - delta, 0.0)
	attack_cd = maxf(attack_cd - delta, 0.0)

	match state:
		State.ROLL:        _tick_roll(delta)
		State.ATTACK:      _tick_attack(delta)
		State.BLOCK_START: _tick_block_start(delta)
		State.BLOCK_HOLD:  _tick_block_hold()
		_:                 _tick_normal()

	if state != State.ROLL:
		_regen_stamina(delta)

func _tick_normal() -> void:
	move_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	if move_dir != Vector2.ZERO:
		last_dir = move_dir
		velocity = move_dir * move_speed
		state    = State.WALK
	else:
		velocity = Vector2.ZERO
		state    = State.IDLE

	if Input.is_action_just_pressed("roll") and roll_cd <= 0.0 and current_stamina >= roll_cost:
		_begin_roll()
		return

	if Input.is_action_just_pressed("block"):
		_begin_block()
		return

	if Input.is_action_just_pressed("attack") and attack_cd <= 0.0:
		_begin_attack()
		return

	move_and_slide()
	_play_move_anim()

func _begin_roll() -> void:
	state      = State.ROLL
	roll_timer = roll_duration
	roll_cd    = roll_cooldown
	roll_dir   = (move_dir if move_dir != Vector2.ZERO else last_dir).normalized()
	_spend_stamina(roll_cost)
	body_shape.set_deferred("disabled", true)
	_play_anim("roll", true)

func _tick_roll(delta: float) -> void:
	roll_timer -= delta
	velocity    = roll_dir * roll_speed
	move_and_slide()
	if roll_timer <= 0.0:
		body_shape.set_deferred("disabled", false)
		state = State.IDLE

func _begin_block() -> void:
	state             = State.BLOCK_START
	block_start_timer = block_start_duration
	velocity          = Vector2.ZERO
	_play_anim("block_start", true)

func _tick_block_start(delta: float) -> void:
	block_start_timer -= delta
	move_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if move_dir != Vector2.ZERO:
		last_dir = move_dir
	velocity = move_dir * move_speed * block_speed_mult
	move_and_slide()
	if block_start_timer <= 0.0:
		state = State.BLOCK_HOLD
		_play_anim("block_hold", true)
		return
	if not Input.is_action_pressed("block"):
		state = State.IDLE

func _tick_block_hold() -> void:
	move_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if move_dir != Vector2.ZERO:
		last_dir = move_dir
	velocity = move_dir * move_speed * block_speed_mult
	move_and_slide()
	if not Input.is_action_pressed("block"):
		state = State.IDLE
		_play_move_anim()
		return
	_play_anim("block_hold")

func is_blocking() -> bool:
	return state == State.BLOCK_START or state == State.BLOCK_HOLD

func _begin_attack() -> void:
	state        = State.ATTACK
	attack_timer = attack_duration
	attack_cd    = attack_duration
	velocity     = Vector2.ZERO
	_spend_stamina(attack_cost)
	_play_anim("attack", true)
	await get_tree().create_timer(attack_duration * 0.5).timeout
	if state == State.ATTACK and is_instance_valid(self) and attack_area:
		for body in attack_area.get_overlapping_bodies():
			if body != self and body.has_method("take_damage"):
				body.take_damage(attack_damage)

func _tick_attack(delta: float) -> void:
	attack_timer -= delta
	move_and_slide()
	if attack_timer <= 0.0:
		state = State.IDLE

# ============================================================
#  Анимация (без изменений)
# ============================================================
func _dir4(dir: Vector2) -> String:
	if abs(dir.x) >= abs(dir.y):
		return "e" if dir.x >= 0.0 else "w"
	else:
		return "s" if dir.y >= 0.0 else "n"

func _play_anim(action: String, force: bool = false) -> void:
	if not anim or not anim.sprite_frames:
		return
	var full   = action + "_" + _dir4(last_dir)
	var frames = anim.sprite_frames
	var target: String
	if frames.has_animation(full):
		target = full
	elif frames.has_animation(action):
		target = action
	else:
		return
	if force or anim.animation != target:
		anim.play(target)

func _play_move_anim() -> void:
	match state:
		State.WALK: _play_anim("walk")
		State.IDLE: _play_anim("idle")

# ============================================================
#  Урон, лечение, смерть
# ============================================================
func take_damage(amount: int = 1) -> void:
	if state == State.DEAD or state == State.ROLL:
		return

	if is_blocking():
		if current_stamina > 0.0:
			_spend_stamina(block_hit_cost)
			anim.modulate = Color(0.4, 0.7, 1.0)
			await get_tree().create_timer(0.12).timeout
			if is_instance_valid(self):
				anim.modulate = Color.WHITE
			return
		else:
			state = State.IDLE

	var dmg = max(amount - armor, 0)
	if dmg == 0:
		return

	current_health -= dmg
	current_health  = max(current_health, 0)
	_sync_health_bar()
	update_health_display()

	anim.modulate = Color.RED
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self):
		anim.modulate = Color.WHITE

	if current_health <= 0:
		_die()

func heal(amount: int) -> void:
	current_health = mini(current_health + amount, max_health)
	_sync_health_bar()
	update_health_display()

func _die() -> void:
	state    = State.DEAD
	velocity = Vector2.ZERO
	emit_signal("player_died")
	if anim.sprite_frames and anim.sprite_frames.has_animation("death"):
		anim.play("death")

# ============================================================
#  Стамина и бары
# ============================================================
func _spend_stamina(amount: float) -> void:
	current_stamina = maxf(current_stamina - amount, 0.0)
	_sync_stamina_bar()

func _regen_stamina(delta: float) -> void:
	if current_stamina >= max_stamina:
		return
	current_stamina = minf(current_stamina + stamina_regen * delta, max_stamina)
	_sync_stamina_bar()

func _sync_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health

func _sync_stamina_bar() -> void:
	if stamina_bar:
		stamina_bar.value = current_stamina

# ============================================================
#  Прокачка
# ============================================================
func upgrade_health(amount: int) -> void:
	max_health    += amount
	current_health = mini(current_health + amount, max_health)
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	update_health_display()

func upgrade_stamina(amount: float) -> void:
	max_stamina     += amount
	current_stamina  = minf(current_stamina + amount, max_stamina)
	if stamina_bar:
		stamina_bar.max_value = max_stamina
		stamina_bar.value = current_stamina

func upgrade_armor(amount: int) -> void:
	armor += amount

func upgrade_attack(amount: int) -> void:
	attack_damage += amount
