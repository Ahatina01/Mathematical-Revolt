extends Node

const RANGES := {
	1: {"min": 1,  "max": 10},
	2: {"min": 1,  "max": 25},
	3: {"min": 5,  "max": 50},
	4: {"min": 10, "max": 100},
	5: {"min": 20, "max": 200},
}

const OPS_BY_DIFFICULTY := {
	1: ["+", "-"],
	2: ["+", "-"],
	3: ["+", "-", "*"],
	4: ["+", "-", "*", "/"],
	5: ["+", "-", "*", "/"],
}


const LIT_QUESTIONS := [
	{
		"question": "Кто написал «Войну и мир»?",
		"correct": "Толстой",
		"options": ["Толстой", "Достоевский", "Тургенев"]
	},
	{
		"question": "Главный герой романа «Преступление и наказание»?",
		"correct": "Раскольников",
		"options": ["Раскольников", "Базаров", "Онегин"]
	},
	{
		"question": "Кто написал «Мёртвые души»?",
		"correct": "Гоголь",
		"options": ["Гоголь", "Пушкин", "Лермонтов"]
	},
	{
		"question": "Из какого произведения фраза «Счастливые часов не наблюдают»?",
		"correct": "Горе от ума",
		"options": ["Горе от ума", "Ревизор", "Евгений Онегин"]
	},
	{
		"question": "Кто автор «Капитанской дочки»?",
		"correct": "Пушкин",
		"options": ["Пушкин", "Гоголь", "Толстой"]
	},
	{
		"question": "Как звали няню Татьяны Лариной в «Евгении Онегине»?",
		"correct": "Филипьевна",
		"options": ["Филипьевна", "Аксинья", "Матрёна"]
	},
	{
		"question": "Кто написал «Герой нашего времени»?",
		"correct": "Лермонтов",
		"options": ["Лермонтов", "Тургенев", "Чехов"]
	},
	{
		"question": "Главный герой «Отцов и детей» Тургенева?",
		"correct": "Базаров",
		"options": ["Базаров", "Чичиков", "Раскольников"]
	},
	{
		"question": "В каком городе происходит действие «Ревизора»?",
		"correct": "Уездный город N",
		"options": ["Уездный город N", "Москва", "Петербург"]
	},
	{
		"question": "Кто написал пьесу «Вишнёвый сад»?",
		"correct": "Чехов",
		"options": ["Чехов", "Островский", "Горький"]
	},
	{
		"question": "Какой чин у Хлестакова в «Ревизоре»?",
		"correct": "Титулярный советник",
		"options": ["Титулярный советник", "Майор", "Коллежский асессор"]
	},
	{
		"question": "Кто написал «На дне»?",
		"correct": "Горький",
		"options": ["Горький", "Чехов", "Толстой"]
	},
	{
		"question": "Как зовут главного героя «Идиота» Достоевского?",
		"correct": "Мышкин",
		"options": ["Мышкин", "Карамазов", "Раскольников"]
	},
	{
		"question": "В каком веке жил Пушкин?",
		"correct": "XIX",
		"options": ["XIX", "XVIII", "XX"]
	},
	{
		"question": "Кто убил старуху-процентщицу в «Преступлении и наказании»?",
		"correct": "Раскольников",
		"options": ["Раскольников", "Свидригайлов", "Разумихин"]
	},
]



func generate_question(difficulty: int) -> Dictionary:
	difficulty = clampi(difficulty, 1, 5)
	var rng = RANGES[difficulty]
	var ops = OPS_BY_DIFFICULTY[difficulty]
	var op  = ops[randi() % ops.size()]
	var a: int
	var b: int
	var correct: int

	match op:
		"+":
			a = randi_range(rng["min"], rng["max"])
			b = randi_range(rng["min"], rng["max"])
			correct = a + b
		"-":
			a = randi_range(rng["min"], rng["max"])
			b = randi_range(rng["min"], a)
			correct = a - b
		"*":
			var m = mini(rng["max"], 12)
			a = randi_range(2, m)
			b = randi_range(2, m)
			correct = a * b
		"/":
			b = randi_range(2, mini(rng["max"], 12))
			a = b * randi_range(1, maxi(1, rng["max"] / b))
			correct = a / b

	return {
		"question": "%d %s %d = ?" % [a, op, b],
		"correct":  correct,
		"options":  _math_options(correct, difficulty),
		"type":     "math",
	}


func _math_options(correct: int, difficulty: int) -> Array:
	var spread = [2, 3, 5, 8, 12][difficulty - 1]
	var used: Dictionary = {}
	used[correct] = true
	var attempts = 0
	while used.size() < 3 and attempts < 60:
		attempts += 1
		var offset = randi_range(1, spread) * (1 if randf() > 0.5 else -1)
		var w = correct + offset
		if w >= 0 and not used.has(w):
			used[w] = true
	if used.size() < 3: used[correct + spread + 1] = true
	if used.size() < 3: used[correct + spread + 2] = true
	var opts = used.keys()
	opts.shuffle()
	return opts


var _lit_pool: Array = []   # пул перемешанных вопросов

func generate_lit_question() -> Dictionary:
	# Перемешиваем пул когда заканчивается — так вопросы не повторяются подряд
	if _lit_pool.is_empty():
		_lit_pool = LIT_QUESTIONS.duplicate()
		_lit_pool.shuffle()

	var q = _lit_pool.pop_back().duplicate()
	q["options"] = q["options"].duplicate()
	q["options"].shuffle()
	q["type"] = "lit"
	return q
