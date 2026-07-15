extends CharacterBody2D

@export_group("Фаза 1 — обычная")
@export var speed_normal: float   = 78.0
@export var damage_normal: int    = 2
@export var windup_normal: float  = 0.55
@export var attack_cd_normal: float = 1.4

@export_group("Фаза 2 — ярость (< 35% хп)")
@export var speed_enraged: float  = 135.0
@export var damage_enraged: int   = 3
@export var windup_enraged: float = 0.28
@export var attack_cd_enraged: float = 0.85

@export_group("Общие")
@export var max_health: int       = 15
@export var detection_range: float = 500.0
@export var enrage_threshold: float = 0.35

enum State { IDLE, CHASE, WINDUP, ATTACK, STUNNED, DEAD }
var state := State.IDLE

var current_health: int
var player: CharacterBody2D = null
var is_enraged := false

var stun_timer:   float = 0.0
var attack_cd:    float = 0.0
var windup_timer: float = 0.0
var last_dir: Vector2   = Vector2.RIGHT

var hp_label: Label = null

signal boss_died


func _ready() -> void:
	current_health = max_health
	add_to_group("enemy")

	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

	hp_label = Label.new()
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 16)
	add_child(hp_label)
	hp_label.position = Vector2(-50, -65)
	_update_hp_label()

	$AnimatedSprite2D.scale = Vector2(1.6, 1.6)
	_apply_phase_color()
	_play_anim("idle")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	attack_cd = maxf(attack_cd - delta, 0.0)

	match state:
		State.IDLE:    _tick_idle()
		State.CHASE:   _tick_chase()
		State.WINDUP:  _tick_windup(delta)
		State.ATTACK:  pass
		State.STUNNED: _tick_stun(delta)

	_update_state()


func _tick_idle() -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	_play_anim("idle")


func _tick_chase() -> void:
	if not is_instance_valid(player):
		state = State.IDLE
		return

	var dir = (player.global_position - global_position).normalized()
	last_dir = dir
	var spd = speed_enraged if is_enraged else speed_normal
	velocity = dir * spd
	move_and_slide()
	_play_directional_anim("walk")

	if global_position.distance_to(player.global_position) < 50.0 and attack_cd <= 0.0:
		_begin_windup()


func _begin_windup() -> void:
	state = State.WINDUP
	windup_timer = windup_enraged if is_enraged else windup_normal
	velocity = Vector2.ZERO
	_play_directional_anim("windup")


func _tick_windup(delta: float) -> void:
	windup_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	if windup_timer <= 0.0:
		_do_attack()


func _do_attack() -> void:
	state = State.ATTACK
	attack_cd = attack_cd_enraged if is_enraged else attack_cd_normal
	_play_directional_anim("attack")

	if not is_instance_valid(self) or not is_inside_tree():
		return
	var tree = get_tree()
	if tree:
		await tree.create_timer(0.18).timeout
	else:
		return

	if not is_instance_valid(self) or state != State.ATTACK:
		return

	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < 65.0:
			var dmg = damage_enraged if is_enraged else damage_normal
			var parried = false
			if player.has_method("try_parry"):
				parried = player.try_parry(self)
			if not parried:
				player.take_damage(dmg)

	if not is_instance_valid(self) or not is_inside_tree():
		return
	tree = get_tree()
	if tree:
		await tree.create_timer(0.25).timeout
	else:
		return

	if is_instance_valid(self) and state == State.ATTACK:
		state = State.CHASE


func apply_stun(duration: float) -> void:
	state = State.STUNNED
	stun_timer = duration
	velocity = Vector2.ZERO
	$AnimatedSprite2D.modulate = Color(0.5, 0.6, 1.0)
	_play_directional_anim("stun")


func _tick_stun(delta: float) -> void:
	stun_timer -= delta
	velocity = Vector2.ZERO
	move_and_slide()
	if stun_timer <= 0.0:
		_apply_phase_color()
		state = State.CHASE


func _update_state() -> void:
	if state in [State.STUNNED, State.WINDUP, State.ATTACK, State.DEAD]:
		return
	if not is_instance_valid(player):
		state = State.IDLE
		return
	var dist = global_position.distance_to(player.global_position)
	state = State.CHASE if dist <= detection_range else State.IDLE


func _enter_enrage() -> void:
	is_enraged = true
	_apply_phase_color()


func _apply_phase_color() -> void:
	$AnimatedSprite2D.modulate = Color(1.0, 0.5, 0.1) if is_enraged else Color(1.0, 0.7, 0.2)


func take_damage(amount: int = 1) -> void:
	if state == State.DEAD:
		return

	current_health -= amount
	current_health = max(current_health, 0)
	_update_hp_label()

	$AnimatedSprite2D.modulate = Color.WHITE
	if is_instance_valid(self) and is_inside_tree():
		var tree = get_tree()
		if tree:
			await tree.create_timer(0.1).timeout
		else:
			return
	else:
		return

	if not is_instance_valid(self):
		return
	_apply_phase_color()

	if not is_enraged and current_health <= int(max_health * enrage_threshold):
		_enter_enrage()

	if current_health <= 0:
		_die()


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)

	var sprite = $AnimatedSprite2D
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.sprite_frames.set_animation_loop("death", false)
		_play_directional_anim("death")
		if is_instance_valid(self) and is_inside_tree():
			await sprite.animation_finished
			sprite.stop()
			sprite.frame = sprite.sprite_frames.get_frame_count("death") - 1
		else:
			pass
	else:
		if is_instance_valid(self) and is_inside_tree():
			await get_tree().create_timer(0.5).timeout

	emit_signal("boss_died")

	if is_instance_valid(self) and is_inside_tree():
		var tree = get_tree()
		if tree:
			await tree.create_timer(0.5).timeout
	queue_free()


func _update_hp_label() -> void:
	if hp_label:
		hp_label.text = "⚔ БОСС  %d / %d" % [current_health, max_health]


func _dir_suffix(dir: Vector2) -> String:
	var deg = fmod(rad_to_deg(dir.angle()) + 360.0, 360.0)
	if deg < 45.0 or deg >= 315.0: return "e"
	elif deg < 135.0: return "s"
	elif deg < 225.0: return "w"
	else: return "n"


func _play_directional_anim(action: String) -> void:
	var spr = $AnimatedSprite2D
	if not spr or not spr.sprite_frames:
		return
	var suffix = _dir_suffix(last_dir)
	var full = "%s_%s" % [action, suffix]
	var frames = spr.sprite_frames
	var target = full if frames.has_animation(full) else (action if frames.has_animation(action) else "")
	if target != "" and spr.animation != target:
		spr.play(target)


func _play_anim(action: String) -> void:
	var spr = $AnimatedSprite2D
	if spr and spr.sprite_frames and spr.sprite_frames.has_animation(action):
		if spr.animation != action:
			spr.play(action)
