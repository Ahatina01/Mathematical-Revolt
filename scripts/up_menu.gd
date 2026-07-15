extends CanvasLayer


@export var question_mode: String = "math"   # "math", "lit", "mixed"

const COST: int            = 1
const HP_UP: int           = 2
const ATTACK_UP: int       = 1
const STAMINA_UP: float    = 20.0
const MAX_HP_LVL: int      = 10
const MAX_ATTACK_LVL: int  = 10
const MAX_STA_LVL: int     = 10
const MATH_DIFFICULTY: int = 2
const TIME_LIMIT: float    = 10.0

# ── УЗЛЫ ─────────────────────────────────────────────────────────

@onready var panel         = $Panel
@onready var points_label  = $Panel/MarginContainer/VBoxContainer/PointsLabel
@onready var hp_label      = $Panel/MarginContainer/VBoxContainer/HBoxContainer/HPLabel
@onready var attack_label  = $Panel/MarginContainer/VBoxContainer/HBoxContainer2/AttackLabel
@onready var stamina_label = $Panel/MarginContainer/VBoxContainer/HBoxContainer3/StaminaLabel
@onready var btn_hp        = $Panel/MarginContainer/VBoxContainer/HBoxContainer/BtnHP
@onready var btn_attack    = $Panel/MarginContainer/VBoxContainer/HBoxContainer2/BtnAttack
@onready var btn_stamina   = $Panel/MarginContainer/VBoxContainer/HBoxContainer3/BtnStamina
@onready var feedback_label = $Panel/MarginContainer/VBoxContainer/FeedbackLabel
@onready var btn_close     = $Panel/MarginContainer/VBoxContainer/BtnClose

@onready var math_panel    = $MathPanel
@onready var q_label       = $MathPanel/VBoxContainer/QuestionLabel
@onready var timer_bar     = $MathPanel/VBoxContainer/TimerBar
@onready var a_btns: Array = [
	$MathPanel/VBoxContainer/HBoxContainer/AnswerBtn0,
	$MathPanel/VBoxContainer/HBoxContainer/AnswerBtn1,
	$MathPanel/VBoxContainer/HBoxContainer/AnswerBtn2,
]

# ── ДАННЫЕ ───────────────────────────────────────────────────────

var upgrade_points: int = 0
var hp_lvl:         int = 0
var attack_lvl:     int = 0
var stamina_lvl:    int = 0

var pending:   String     = ""
var question:  Dictionary = {}

var timer_active: bool  = false
var answer_timer: float = 0.0

# ================================================================
#  ИНИЦИАЛИЗАЦИЯ
# ================================================================

func _ready() -> void:
	process_mode        = Node.PROCESS_MODE_ALWAYS
	panel.visible       = false
	math_panel.visible  = false
	feedback_label.text = ""

	timer_bar.min_value = 0.0
	timer_bar.max_value = TIME_LIMIT
	timer_bar.value     = TIME_LIMIT
	timer_bar.visible   = false

	btn_hp.pressed.connect(func():     _ask("hp"))
	btn_attack.pressed.connect(func(): _ask("attack"))
	btn_stamina.pressed.connect(func(): _ask("stamina"))
	btn_close.pressed.connect(close)

	for i in range(a_btns.size()):
		var idx = i
		a_btns[i].pressed.connect(func(): _on_answer(idx))

# ── Установка режима вопросов извне (например, из game3.gd)
func set_question_mode(mode: String) -> void:
	if mode in ["math", "lit", "mixed"]:
		question_mode = mode
	else:
		print("Ошибка: неверный режим вопроса ", mode)


func open() -> void:
	panel.visible       = true
	math_panel.visible  = false
	feedback_label.text = ""
	pending             = ""
	question            = {}
	timer_active        = false
	get_tree().paused   = true
	_refresh()

func close() -> void:
	panel.visible      = false
	math_panel.visible = false
	timer_active       = false
	get_tree().paused  = false

func add_points(amount: int) -> void:
	upgrade_points += amount
	if panel.visible:
		_refresh()


func _ask(upgrade_type: String) -> void:
	if upgrade_points < COST:
		_fb("Недостаточно очков!", Color.ORANGE)
		return

	pending = upgrade_type

	# Генерация вопроса в зависимости от режима
	match question_mode:
		"lit":
			question = MathSystem.generate_lit_question()
		"mixed":
			if randf() < 0.5:
				question = MathSystem.generate_question(MATH_DIFFICULTY)
			else:
				question = MathSystem.generate_lit_question()
		_:  # "math"
			question = MathSystem.generate_question(MATH_DIFFICULTY)

	q_label.text = question["question"]

	var opts: Array = question["options"]
	for i in range(a_btns.size()):
		a_btns[i].text     = str(opts[i])
		a_btns[i].disabled = false
		a_btns[i].modulate = Color.WHITE

	timer_active = true
	answer_timer = TIME_LIMIT
	timer_bar.value    = TIME_LIMIT
	timer_bar.visible  = true
	timer_bar.modulate = Color(0.2, 1.0, 0.2)

	math_panel.visible  = true
	feedback_label.text = ""


func _on_answer(idx: int) -> void:
	if not math_panel.visible or question.is_empty():
		return
	timer_active = false

	var chosen  = question["options"][idx]
	var correct = question["correct"]
	var right   = (str(chosen) == str(correct))

	# Подсветка кнопок
	for i in range(a_btns.size()):
		a_btns[i].disabled = true
		if str(question["options"][i]) == str(correct):
			a_btns[i].modulate = Color(0.3, 1.0, 0.4)
		else:
			a_btns[i].modulate = Color(1.0, 0.4, 0.4)

	if right:
		upgrade_points -= COST
		_apply(pending)
		_fb("✓ Верно! Характеристика улучшена.", Color(0.3, 1.0, 0.4))
	else:
		upgrade_points -= COST
		_fb("✗ Неверно! Очко потеряно. Ответ: %s" % str(correct), Color(1.0, 0.4, 0.4))
		_refresh()

	pending  = ""
	question = {}

	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(math_panel):
		math_panel.visible = false
		timer_bar.visible  = false
		_refresh()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("upgrade_menu"):
		if panel.visible:
			close()
		else:
			open()

	if timer_active and math_panel.visible:
		answer_timer -= delta
		timer_bar.value = answer_timer
		var t = answer_timer / TIME_LIMIT
		timer_bar.modulate = Color(1.0 - t, t, 0.2)
		if answer_timer <= 0.0:
			_on_timeout()

func _on_timeout() -> void:
	timer_active = false
	if not math_panel.visible:
		return
	upgrade_points -= COST
	_refresh()
	_fb("⏰ Время вышло! Очко потеряно.", Color.RED)
	math_panel.visible = false
	timer_bar.visible  = false
	pending  = ""
	question = {}


func _apply(t: String) -> void:
	var p = _player()
	match t:
		"hp":
			hp_lvl += 1
			if p: p.upgrade_health(HP_UP)
		"attack":
			attack_lvl += 1
			if p: p.upgrade_attack(ATTACK_UP)
		"stamina":
			stamina_lvl += 1
			if p: p.upgrade_stamina(STAMINA_UP)
	_refresh()


func _refresh() -> void:
	points_label.text  = "Очки прокачки: %d" % upgrade_points
	hp_label.text      = "❤  Здоровье     ур.%d/%d  (+%d хп)"   % [hp_lvl,      MAX_HP_LVL,      HP_UP]
	attack_label.text  = "⚔  Атака        ур.%d/%d  (+%d урон)"  % [attack_lvl,  MAX_ATTACK_LVL,  ATTACK_UP]
	stamina_label.text = "⚡ Выносливость  ур.%d/%d  (+%d)"       % [stamina_lvl, MAX_STA_LVL,     int(STAMINA_UP)]
	btn_hp.disabled      = upgrade_points < COST or hp_lvl      >= MAX_HP_LVL
	btn_attack.disabled  = upgrade_points < COST or attack_lvl  >= MAX_ATTACK_LVL
	btn_stamina.disabled = upgrade_points < COST or stamina_lvl >= MAX_STA_LVL

func _fb(text: String, color: Color) -> void:
	feedback_label.text = text
	feedback_label.add_theme_color_override("font_color", color)

func _player() -> Node:
	var p = get_tree().get_nodes_in_group("player")
	return p[0] if p.size() > 0 else null
