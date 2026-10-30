extends Node2D

# CANDY KINGDOM - Godot 4.x
# 20 нива с постепенно увеличаваща се трудност, специални фонове и анимации.

const COLS := 8
const ROWS := 8
const TYPES := 6
const LEVEL_COUNT := 20

# Брой ходове за всяко ниво.
const LEVEL_MOVES := [
	30, 28, 27, 26, 25, 24, 23, 22, 21, 18,
	20, 19, 18, 18, 17, 16, 15, 14, 13, 12
]

# Колко различни цвята се появяват на дъската във всяко ниво.
const LEVEL_TYPES := [
	3, 5, 5, 6, 6, 6, 6, 6, 6, 6,
	6, 6, 6, 6, 6, 6, 6, 6, 6, 6
]

const MENU := 0
const PLAYING := 1
const COMPLETE := 2
const GAME_OVER := 3
const VICTORY := 4
const SHOP := 5
const MAX_LIVES := 5
const LIFE_REGEN_SECONDS := 1800
const DAILY_REWARD := 50

const COLORS := [
	Color("#ff527c"), Color("#39c9ff"), Color("#75e56f"),
	Color("#ffc247"), Color("#b783ff"), Color("#ff8c42")
]

# Ключът е индексът на цвета: 0 розов, 1 син, 2 зелен,
# 3 жълт, 4 лилав, 5 оранжев. Стойността е целта за този цвят.
const GOALS := [
	{0: 10, 1: 10},                         # 1: 3 цвята, събери 2
	{0: 10, 1: 10, 2: 10},                 # 2: 5 цвята, събери 3
	{1: 15, 2: 15, 3: 15},
	{0: 18, 2: 18, 4: 18},
	{1: 20, 3: 20, 5: 20},
	{0: 22, 2: 22, 4: 22},
	{0: 20, 1: 20, 3: 20, 5: 20},
	{1: 23, 2: 23, 4: 23, 5: 23},
	{0: 25, 2: 25, 3: 25, 5: 25},
	{0: 26, 1: 26, 3: 26, 4: 26},         # 10: специално ниво
	{0: 27, 1: 27, 2: 27, 5: 27},
	{0: 29, 2: 29, 3: 29, 4: 29},
	{1: 31, 2: 31, 4: 31, 5: 31},
	{0: 18, 1: 18, 2: 18, 3: 18, 4: 18},
	{0: 19, 1: 19, 2: 19, 4: 19, 5: 19},
	{0: 20, 1: 20, 2: 20, 3: 20, 5: 20},
	{0: 21, 1: 21, 2: 21, 3: 21, 4: 21},
	{0: 22, 1: 22, 2: 22, 4: 22, 5: 22},
	{0: 23, 1: 23, 2: 23, 3: 23, 5: 23},
	{0: 24, 1: 24, 2: 24, 3: 24, 4: 24}  # 20: финално ниво
]

const TOP := Color("#17102f")
const BOTTOM := Color("#38205d")

var board: Array = []
var collected: Array[int] = [0, 0, 0, 0, 0, 0]

var level := 1
var unlocked := 1
var coins := 0
var level_stars: Array[int] = []
var booster_moves := 0
var booster_bomb := false
var booster_shuffle := false
var boss_hp := 0
var boss_max_hp := 0
var shop_rects: Array[Rect2] = []
var shop_back_rect := Rect2()
var shop_open_rect := Rect2()
var shop_return_mode := MENU
var play_map_rect := Rect2()
var play_shop_rect := Rect2()
var shop_item_labels: Array[String] = []
var shop_item_prices: Array[int] = []
var map_scroll := 0.0
var lives := MAX_LIVES
var life_timer := 0
var daily_claim_time := 0
var daily_claimed_today := false
var hammer_stock := 0
var hammer_mode := false
var extra_life_stock := 0
var hammer_button_rect := Rect2()
var daily_button_rect := Rect2()
var screen_flash := 0.0
var shake_time := 0.0
var shake_strength := 0.0
var moves: int = 30
var score: int = 0
var cascade_count: int = 0
var selected := Vector2i(-1, -1)
var _touch_start_pos := Vector2.ZERO
var _touch_last_pos := Vector2.ZERO
var _touch_active := false

var mode := MENU
var busy := false

var screen := Vector2(720, 1280)
var board_origin := Vector2.ZERO
var board_size := 512.0
var cell := 64.0

var clock := 0.0

var stars: Array[Dictionary] = []
var particles: Array[Dictionary] = []

# Анимация на събраните бонбони към целите.
var flying_candies: Array[Dictionary] = []

# Анимация на падащите бонбони.
var falling_candies: Array[Dictionary] = []

var menu_rects: Array[Rect2] = []

var continue_rect := Rect2()
var retry_rect := Rect2()
var home_rect := Rect2()

var message := ""
var message_time := 0.0
var complete_time := 0.0


func _ready() -> void:
	randomize()
	level_stars.resize(LEVEL_COUNT)
	level_stars.fill(0)

	get_viewport().size_changed.connect(_layout)

	_layout()
	_load_progress()

	for i in range(90):
		stars.append({
			"p": Vector2(randf(), randf()),
			"r": randf_range(0.7, 2.0),
			"phase": randf_range(0.0, TAU),
			"speed": randf_range(0.7, 2.0)
		})

	set_process(true)
	queue_redraw()


func _layout() -> void:
	screen = get_viewport_rect().size

	# На телефони използваме почти цялата ширина за дъската.
	# Оставяме място за горния HUD и долните бутони/подсказки.
	var horizontal_margin := clampf(screen.x * 0.025, 8.0, 18.0)
	var top_space := clampf(screen.y * 0.17, 118.0, 205.0)
	var bottom_space := clampf(screen.y * 0.10, 70.0, 112.0)

	board_size = minf(
		minf(screen.x - horizontal_margin * 2.0 - 12.0, screen.y - top_space - bottom_space),
		900.0
	)
	board_size = maxf(board_size, 180.0)
	cell = board_size / float(COLS)

	board_origin = Vector2(
		(screen.x - board_size) * 0.5,
		top_space
	)

	# Ако екранът е много нисък, центрираме дъската в наличното място.
	if board_origin.y + board_size > screen.y - bottom_space:
		board_origin.y = maxf(90.0, screen.y - board_size - bottom_space)

	queue_redraw()


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://candy_kingdom.cfg") == OK:
		unlocked = clampi(int(cfg.get_value("progress", "unlocked", LEVEL_COUNT)), 1, LEVEL_COUNT)
		coins = maxi(0, int(cfg.get_value("progress", "coins", 0)))
		lives = clampi(int(cfg.get_value("progress", "lives", MAX_LIVES)), 0, MAX_LIVES)
		life_timer = int(cfg.get_value("progress", "life_timer", 0))
		daily_claim_time = int(cfg.get_value("progress", "daily_claim_time", 0))
		hammer_stock = maxi(0, int(cfg.get_value("progress", "hammer_stock", 0)))
		extra_life_stock = maxi(0, int(cfg.get_value("progress", "extra_life_stock", 0)))
		booster_moves = maxi(0, int(cfg.get_value("boosters", "moves", 0)))
		booster_bomb = bool(cfg.get_value("boosters", "bomb", false))
		booster_shuffle = bool(cfg.get_value("boosters", "shuffle", false))
		_update_lives()
		for i in range(LEVEL_COUNT):
			level_stars[i] = clampi(int(cfg.get_value("stars", str(i + 1), 0)), 0, 3)
	else:
		unlocked = LEVEL_COUNT
		_save_progress()


func _save_progress() -> void:
	var cfg := ConfigFile.new()

	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "lives", lives)
	cfg.set_value("progress", "life_timer", life_timer)
	cfg.set_value("progress", "daily_claim_time", daily_claim_time)
	cfg.set_value("progress", "hammer_stock", hammer_stock)
	cfg.set_value("progress", "extra_life_stock", extra_life_stock)
	cfg.set_value("boosters", "moves", booster_moves)
	cfg.set_value("boosters", "bomb", booster_bomb)
	cfg.set_value("boosters", "shuffle", booster_shuffle)
	for i in range(LEVEL_COUNT):
		cfg.set_value("stars", str(i + 1), level_stars[i])
	cfg.save("user://candy_kingdom.cfg")


func _update_lives() -> void:
	if lives >= MAX_LIVES:
		life_timer = 0
		return
	var now := int(Time.get_unix_time_from_system())
	if life_timer <= 0:
		life_timer = now
	var elapsed := maxi(0, now - life_timer)
	var gained := int(elapsed / LIFE_REGEN_SECONDS)
	if gained > 0:
		lives = mini(MAX_LIVES, lives + gained)
		if lives < MAX_LIVES:
			life_timer += gained * LIFE_REGEN_SECONDS
		else:
			life_timer = 0
		_save_progress()


func _claim_daily_reward() -> void:
	var today := int(Time.get_unix_time_from_system() / 86400)
	var previous_day := int(daily_claim_time / 86400)
	if today == previous_day:
		message = "ВЕЧЕ ВЗЕ НАГРАДАТА СИ ДНЕС!"
		message_time = 2.0
		return
	coins += DAILY_REWARD
	lives = mini(MAX_LIVES, lives + 1)
	hammer_stock += 1
	daily_claim_time = int(Time.get_unix_time_from_system())
	_save_progress()
	message = "ДНЕВНА НАГРАДА: +50 МОНЕТИ, ЖИВОТ И ЧУК!"
	message_time = 3.0


func _world_name(n: int) -> String:
	if n <= 5:
		return "ЗАХАРЕН СВЯТ"
	if n <= 10:
		return "КАРАМЕЛЕН СВЯТ"
	if n <= 15:
		return "ЛЕДЕН СВЯТ"
	return "МАГИЧЕСКИ СВЯТ"


func _world_color(n: int) -> Color:
	if n <= 5:
		return Color("#f58ab8")
	if n <= 10:
		return Color("#d58a42")
	if n <= 15:
		return Color("#67c9ef")
	return Color("#a783ef")


func _use_hammer(at: Vector2i) -> void:
	if hammer_stock <= 0:
		message = "НЯМАШ ЧУК. КУПИ ОТ МАГАЗИНА!"
		message_time = 2.0
		hammer_mode = false
		return
	var kind: int = board[at.x][at.y]
	if kind < 0:
		return
	hammer_stock -= 1
	var pos := board_origin + (Vector2(at) + Vector2(0.5, 0.5)) * cell
	_burst(pos, Color("#ffe16b"))
	_burst(pos, Color("#ffffff"))
	var found: Array[Vector2i] = [at]
	busy = true
	hammer_mode = false
	moves -= 1
	await _resolve(found)
	if _goals_done():
		_finish_level()
	elif moves <= 0:
		_lose_life()
	_save_progress()
	busy = false
	queue_redraw()


func _lose_life() -> void:
	lives = maxi(0, lives - 1)
	if lives < MAX_LIVES and life_timer == 0:
		life_timer = int(Time.get_unix_time_from_system())
	_save_progress()
	mode = GAME_OVER
	message = "ЗАГУБИ ЕДИН ЖИВОТ"
	message_time = 2.0


func _new_level(n: int) -> void:
	if n < 1 or n > unlocked:
		return
	_update_lives()
	if lives <= 0:
		message = "НЯМА ЖИВОТИ! ИЗЧАКАЙ ИЛИ ВЗЕМИ ДНЕВНАТА НАГРАДА."
		message_time = 3.0
		mode = MENU
		return
	hammer_mode = false
	level = n
	moves = int(LEVEL_MOVES[level - 1]) + booster_moves
	score = 0
	cascade_count = 0
	booster_moves = 0
	boss_max_hp = 3 if level % 5 == 0 else 0
	boss_hp = boss_max_hp
	var available_types: int = int(LEVEL_TYPES[level - 1])

	collected = [0, 0, 0, 0, 0, 0]

	selected = Vector2i(-1, -1)
	busy = false

	particles.clear()
	flying_candies.clear()
	falling_candies.clear()

	board.clear()

	for x in range(COLS):
		var col: Array = []

		for y in range(ROWS):
			col.append(-1)

		board.append(col)

	for y in range(ROWS):
		for x in range(COLS):
			var k: int = randi_range(0, available_types - 1)

			while (
				(x >= 2 and board[x - 1][y] == k and board[x - 2][y] == k)
				or
				(y >= 2 and board[x][y - 1] == k and board[x][y - 2] == k)
			):
				k = randi_range(0, available_types - 1)

			board[x][y] = k

	if booster_shuffle:
		_shuffle_board()
		booster_shuffle = false
	if not _has_valid_move():
		_shuffle_board()

	mode = PLAYING
	_save_progress()

	if level == 1:
		message = "ОБУЧЕНИЕ: СЪБЕРИ 10 РОЗОВИ И 10 СИНИ БОНБОНА"
	elif level == 2:
		message = "ВЕЧЕ ИМА 5 ЦВЯТА! СЪБЕРИ 3 ОТ ТЯХ"
	elif level == 10:
		message = "СПЕЦИАЛНО НИВО 10: КАРАМЕЛЕНО ПРЕДИЗВИКАТЕЛСТВО!"
	elif level == 20:
		message = "ФИНАЛНО НИВО: ПОКАЖИ КАКВО МОЖЕШ!"
	else:
		message = "ИЗПЪЛНИ ЦВЕТНИТЕ ЦЕЛИ!"
	message_time = 3.0

	queue_redraw()


func _process(dt: float) -> void:
	clock += dt
	_update_lives()
	if screen_flash > 0.0:
		screen_flash = maxf(0.0, screen_flash - dt)
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - dt)

	message_time = maxf(0.0, message_time - dt)

	if mode == COMPLETE:
		complete_time -= dt

		if complete_time <= 0.0:
			mode = MENU

	# Частици.
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]

		p.life -= dt
		p.pos += p.vel * dt
		p.vel.y += 130.0 * dt
		p.rot += p.spin * dt

		particles[i] = p

		if p.life <= 0.0:
			particles.remove_at(i)

	# Летящи към целите бонбони.
	for i in range(flying_candies.size() - 1, -1, -1):
		var fly: Dictionary = flying_candies[i]

		fly.elapsed = float(fly.elapsed) + dt
		flying_candies[i] = fly

		if float(fly.elapsed) >= float(fly.duration):
			flying_candies.remove_at(i)

	# Падащи бонбони.
	for i in range(falling_candies.size() - 1, -1, -1):
		var fall: Dictionary = falling_candies[i]

		fall.elapsed = float(fall.elapsed) + dt
		falling_candies[i] = fall

		if float(fall.elapsed) >= float(fall.duration):
			falling_candies.remove_at(i)

	queue_redraw()


func _draw() -> void:
	if shake_time > 0.0:
		var offset := Vector2(sin(clock * 95.0), cos(clock * 83.0)) * shake_strength * shake_time
		draw_set_transform(offset, 0.0, Vector2.ONE)
	_draw_bg()

	match mode:
		MENU:
			_draw_menu()

		SHOP:
			_draw_shop()

		PLAYING:
			_draw_hud()
			_draw_goals()
			_draw_board()
			_draw_moving_candies()
			_draw_fx()
			_draw_hint()

		COMPLETE:
			_draw_complete()

		GAME_OVER:
			_draw_failed()

		VICTORY:
			_draw_victory()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if screen_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(1.0, 0.88, 0.55, screen_flash * 0.30))


func _draw_bg() -> void:
	var bg_top: Color = TOP
	var bg_bottom: Color = BOTTOM
	if mode == PLAYING and level <= 5:
		bg_top = Color("#54234d")
		bg_bottom = Color("#d86f9c")
	elif mode == PLAYING and level <= 10:
		bg_top = Color("#4b2118")
		bg_bottom = Color("#b76a32")
	elif mode == PLAYING and level <= 15:
		bg_top = Color("#123b63")
		bg_bottom = Color("#67c9ef")
	elif mode == PLAYING and level >= 16:
		bg_top = Color("#102c58")
		bg_bottom = Color("#713b91")

	for i in range(36):
		var t := float(i) / 35.0
		draw_rect(
			Rect2(0, screen.y * float(i) / 36.0, screen.x, screen.y / 36.0 + 2.0),
			bg_top.lerp(bg_bottom, t)
		)

	var left_color: Color = Color("#8b4325") if mode == PLAYING and level == 10 else Color("#503078")
	var right_color: Color = Color("#d28a42") if mode == PLAYING and level == 10 else Color("#48296e")
	if mode == PLAYING and level == 20:
		left_color = Color("#245f9b")
		right_color = Color("#9b4cae")
	draw_circle(Vector2(screen.x * 0.06, screen.y * 0.8), screen.x * 0.32, left_color)
	draw_circle(Vector2(screen.x * 0.95, screen.y * 0.82), screen.x * 0.35, right_color)

	# Декоративни кръгове като бонбони в специалните нива.
	if mode == PLAYING and (level == 10 or level == 20):
		for i in range(9):
			var candy_x: float = screen.x * (0.08 + float(i % 3) * 0.42)
			var candy_y: float = screen.y * (0.22 + float(i / 3) * 0.25)
			var candy_color: Color = Color("#ffd27a") if level == 10 else Color("#ff8ad8")
			draw_circle(Vector2(candy_x, candy_y), 10.0 + float(i % 2) * 5.0, Color(candy_color.r, candy_color.g, candy_color.b, 0.16))

	# Полупрозрачни захарни сфери в краищата на екрана.
	for i in range(10):
		var side_x: float = 0.035 if i % 2 == 0 else 0.965
		var yy: float = fposmod(float(i) * 0.137 + clock * 0.012, 1.0)
		var rr: float = 5.0 + float(i % 3) * 2.5
		var candy_tint: Color = COLORS[i % COLORS.size()]
		draw_circle(Vector2(screen.x * side_x, screen.y * yy), rr, Color(candy_tint.r, candy_tint.g, candy_tint.b, 0.13))
		draw_circle(Vector2(screen.x * side_x - 2.0, screen.y * yy - 2.0), rr * 0.24, Color(1, 1, 1, 0.28))

	for s in stars:
		var p: Vector2 = s.p

		var a := 0.35 + 0.55 * (
			0.5 + 0.5 * sin(clock * s.speed + s.phase)
		)

		draw_circle(
			Vector2(p.x * screen.x, p.y * screen.y),
			s.r,
			Color(0.9, 0.82, 1.0, a)
		)


func _panel(rect: Rect2, color: Color, radius: float = 13.0) -> void:
	var sb := StyleBoxFlat.new()

	sb.bg_color = color

	sb.corner_radius_top_left = int(radius)
	sb.corner_radius_top_right = int(radius)
	sb.corner_radius_bottom_left = int(radius)
	sb.corner_radius_bottom_right = int(radius)

	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1

	sb.border_color = Color(1, 1, 1, 0.14)

	draw_style_box(sb, rect)


func _button(
	rect: Rect2,
	label: String,
	color: Color,
	size: int = 19
) -> void:
	_panel(rect, color, 15.0)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(
			rect.position.x,
			rect.position.y + rect.size.y * 0.62
		),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		size,
		Color.WHITE
	)


func _draw_menu() -> void:
	var font := ThemeDB.fallback_font
	_update_lives()

	# Горна лента
	draw_string(font, Vector2(0, 54), "CANDY KINGDOM", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 34, Color("#fff3ff"))
	draw_string(font, Vector2(0, 82), "ПРИКЛЮЧЕНИЕ ПРЕЗ ЧЕТИРИ СЛАДКИ СВЯТА", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 12, Color("#e3caff"))
	_panel(Rect2(14, 101, screen.x * 0.40, 38), Color("#302047", 0.94), 13)
	draw_string(font, Vector2(25, 126), "🪙 %d" % coins, HORIZONTAL_ALIGNMENT_LEFT, screen.x * 0.36, 17, Color("#ffdc66"))
	_panel(Rect2(screen.x * 0.46, 101, screen.x * 0.50, 38), Color("#302047", 0.94), 13)
	draw_string(font, Vector2(screen.x * 0.47, 126), "♥ " + str(lives) + "/" + str(MAX_LIVES) + " ЖИВОТА", HORIZONTAL_ALIGNMENT_CENTER, screen.x * 0.48, 16, Color("#ff8eaf"))
	if lives < MAX_LIVES:
		var remaining := LIFE_REGEN_SECONDS - (int(Time.get_unix_time_from_system()) - life_timer) % LIFE_REGEN_SECONDS
		draw_string(font, Vector2(0, 157), "СЛЕДВАЩ ЖИВОТ СЛЕД %02d:%02d" % [int(remaining / 60), remaining % 60], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 11, Color("#e9d5ff"))

	shop_open_rect = Rect2(screen.x * 0.66, 169, screen.x * 0.30, 36)
	_button(shop_open_rect, "🛒 МАГАЗИН", Color("#8749a9"), 13)
	daily_button_rect = Rect2(screen.x * 0.06, 169, screen.x * 0.56, 36)
	var today := int(Time.get_unix_time_from_system() / 86400)
	var claimed := int(daily_claim_time / 86400) == today
	_button(daily_button_rect, "🎁 ДНЕВЕН ПОДАРЪК  " + ("ВЗЕТ" if claimed else "+50 МОНЕТИ"), Color("#986b2d") if not claimed else Color("#51415e"), 12)

	# Картата е разделена на четири големи острова. Всеки остров съдържа пет нива.
	menu_rects.clear()
	var map_top: float = 222.0
	var map_bottom: float = screen.y - 58.0
	var available_h: float = maxf(400.0, map_bottom - map_top)
	var section_h: float = available_h / 4.0
	var world_names: Array[String] = ["1. ЗАХАРЕНО КРАЛСТВО", "2. КАРАМЕЛЕНА ДОЛИНА", "3. ЛЕДЕНИ ПЛАНИНИ", "4. ВЪЛШЕБНА ЗЕМЯ"]
	var world_colors: Array[Color] = [Color("#f18ab9"), Color("#e5a35d"), Color("#70d5ee"), Color("#b69aff")]
	var world_dark: Array[Color] = [Color("#8d416f"), Color("#89522f"), Color("#326f91"), Color("#60468f")]
	var x_pattern: Array[float] = [0.19, 0.36, 0.64, 0.81, 0.50]

	for zone in range(4):
		var zy: float = map_top + float(zone) * section_h
		var card := Rect2(12, zy, screen.x - 24, section_h - 9)
		_panel(card, Color(world_dark[zone].r, world_dark[zone].g, world_dark[zone].b, 0.30), 24)
		# Светъл вътрешен остров и долна сянка.
		draw_circle(Vector2(screen.x * 0.50, zy + section_h * 0.57), minf(screen.x * 0.43, section_h * 0.62), Color(world_colors[zone].r, world_colors[zone].g, world_colors[zone].b, 0.075))
		draw_string(font, Vector2(0, zy + 23), world_names[zone], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 15, world_colors[zone])
		# Малки декоративни бонбони по краищата на острова.
		for deco in range(4):
			var dx: float = screen.x * (0.08 if deco % 2 == 0 else 0.92)
			var dy: float = zy + 55.0 + float(deco) * maxf(18.0, (section_h - 85.0) / 3.0)
			draw_circle(Vector2(dx, dy), 5.0 + float(deco % 2) * 2.0, Color(world_colors[zone].r, world_colors[zone].g, world_colors[zone].b, 0.65))
			draw_circle(Vector2(dx - 2, dy - 2), 1.8, Color(1, 1, 1, 0.75))

		var path_points: Array[Vector2] = []
		for j in range(5):
			var px: float
			var py: float
			if section_h < 170.0:
				# При хоризонтален/нисък прозорец петте спирки са в един ред.
				px = screen.x * (0.15 + float(j) * 0.175)
				py = zy + section_h * 0.66
			else:
				px = screen.x * x_pattern[j]
				py = zy + 48.0 + float(j) * (section_h - 73.0) / 4.0
			path_points.append(Vector2(px, py))

		# Широка тъмна основа и златна пунктирана пътека.
		for j in range(path_points.size() - 1):
			var a: Vector2 = path_points[j]
			var b: Vector2 = path_points[j + 1]
			draw_line(a, b, Color(0.20, 0.11, 0.30, 0.82), 12.0, true)
			draw_line(a, b, Color("#ffe2a0"), 5.0, true)
			for dot in range(1, 5):
				draw_circle(a.lerp(b, float(dot) / 5.0), 2.2, Color("#fff8d9"))

		for j in range(5):
			var idx: int = zone * 5 + j
			var center: Vector2 = path_points[j]
			var open: bool = idx + 1 <= unlocked
			var boss_level: bool = (idx + 1) % 5 == 0
			var node_rect := Rect2(center - Vector2(25, 25), Vector2(50, 50))
			menu_rects.append(node_rect)

			# Сянка и ореол около нивото.
			draw_circle(center + Vector2(0, 4), 28, Color(0, 0, 0, 0.32))
			draw_circle(center, 30, Color(world_colors[zone].r, world_colors[zone].g, world_colors[zone].b, 0.20 if open else 0.06))
			var node_color: Color = world_colors[zone] if open else Color("#62576b")
			if boss_level:
				# Замък за бос нивата 5, 10, 15 и 20.
				draw_rect(Rect2(center + Vector2(-19, -3), Vector2(38, 26)), world_dark[zone])
				draw_rect(Rect2(center + Vector2(-23, -18), Vector2(11, 22)), world_dark[zone])
				draw_rect(Rect2(center + Vector2(12, -18), Vector2(11, 22)), world_dark[zone])
				draw_colored_polygon(PackedVector2Array([center + Vector2(-25, -18), center + Vector2(-17, -30), center + Vector2(-9, -18)]), world_colors[zone])
				draw_colored_polygon(PackedVector2Array([center + Vector2(9, -18), center + Vector2(17, -30), center + Vector2(25, -18)]), world_colors[zone])
				draw_circle(center, 18, node_color)
			else:
				draw_circle(center, 23, node_color)
			draw_circle(center, 17, Color("#302044"))
			var level_label: String = str(idx + 1) if open else "🔒"
			draw_string(font, Vector2(center.x - 20, center.y + 6), level_label, HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color.WHITE)
			if boss_level:
				draw_string(font, Vector2(center.x - 25, center.y - 31), "★ БОС", HORIZONTAL_ALIGNMENT_CENTER, 50, 10, Color("#ffe59a"))
			if level_stars[idx] > 0:
				draw_string(font, Vector2(center.x - 25, center.y + 43), "★".repeat(level_stars[idx]), HORIZONTAL_ALIGNMENT_CENTER, 50, 12, Color("#ffe36b"))
			if idx + 1 == unlocked:
				draw_arc(center, 32, 0.0, TAU, 48, Color("#fff2a6"), 2.5, true)

	draw_string(font, Vector2(0, screen.y - 19), "ОТКЛЮЧЕНИ: %d/20  •  СЪБРАНИ ЗВЕЗДИ: %d  •  ЗАМЪКЪТ Е БОС" % [unlocked, _total_stars()], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 10, Color("#f3ddff"))


func _total_stars() -> int:
	var total := 0
	for amount in level_stars:
		total += amount
	return total


func draw_ellipse_placeholder(rect: Rect2, tint: Color) -> void:
	var c := rect.get_center()
	draw_circle(Vector2(c.x, rect.position.y + rect.size.y * 0.55), rect.size.x * 0.40, Color(tint.r, tint.g, tint.b, 0.07))
	draw_circle(Vector2(c.x - rect.size.x * 0.28, rect.position.y + rect.size.y * 0.72), 8, Color(tint.r, tint.g, tint.b, 0.22))
	draw_circle(Vector2(c.x + rect.size.x * 0.28, rect.position.y + rect.size.y * 0.72), 10, Color(tint.r, tint.g, tint.b, 0.22))


func _draw_shop() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 75), "СЛАДЪК МАГАЗИН", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 34, Color("#fff3ff"))
	_panel(Rect2(screen.x * 0.12, 91, screen.x * 0.76, 48), Color("#3b285b"), 16)
	draw_string(font, Vector2(0, 122), "🪙 %d МОНЕТИ" % coins, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 21, Color("#ffdc66"))
	draw_string(font, Vector2(0, 164), "ТВОИТЕ БОНУСИ", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 16, Color("#d9c2ff"))
	draw_string(font, Vector2(0, 190), "➕ ХОДОВЕ: %d     💣 БОМБА: %s     🔀 РАЗБЪРКВАНЕ: %s" % [booster_moves, "ДА" if booster_bomb else "НЕ", "ДА" if booster_shuffle else "НЕ"], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 12, Color("#f4eaff"))
	draw_string(font, Vector2(0, 213), "🔨 ЧУКОВЕ: %d     ❤️ ЖИВОТИ В РЕЗЕРВ: %d" % [hammer_stock, extra_life_stock], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 13, Color("#ffe4a0"))
	shop_rects.clear()
	shop_item_labels = ["+5 ХОДА ЗА СЛЕДВАЩО НИВО", "БОМБА 3×3 ЗА СЛЕДВАЩО НИВО", "РАЗБЪРКВАНЕ НА ДЪСКАТА", "ЧУК – ПРЕМАХВА 1 БОНБОН", "+1 ЖИВОТ В РЕЗЕРВ", "ПАКЕТ ОТ 3 ЧУКА"]
	shop_item_prices = [20, 35, 18, 15, 25, 38]
	var item_h: float = 55.0
	var gap: float = 7.0
	var first_y: float = 230.0
	for i in range(shop_item_labels.size()):
		var r := Rect2(screen.x * 0.09, first_y + float(i) * (item_h + gap), screen.x * 0.82, item_h)
		shop_rects.append(r)
		var owned := ""
		if i == 0: owned = "  •  ИМАШ: %d" % booster_moves
		elif i == 1: owned = "  •  %s" % ("АКТИВНА" if booster_bomb else "")
		elif i == 2: owned = "  •  %s" % ("АКТИВНО" if booster_shuffle else "")
		elif i == 3: owned = "  •  ИМАШ: %d" % hammer_stock
		elif i == 4: owned = "  •  ИМАШ: %d" % extra_life_stock
		elif i == 5: owned = "  •  ИМАШ: %d" % hammer_stock
		var affordable := coins >= shop_item_prices[i]
		_panel(r, Color("#7650a8") if affordable else Color("#51445f"), 15.0)
		draw_string(font, Vector2(0, r.position.y + 23), shop_item_labels[i] + owned, HORIZONTAL_ALIGNMENT_CENTER, screen.x, 14, Color.WHITE)
		draw_string(font, Vector2(0, r.position.y + 43), "%d 🪙" % shop_item_prices[i], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 13, Color("#ffdf79"))
	shop_back_rect = Rect2(screen.x * 0.18, screen.y - 76.0, screen.x * 0.64, 52.0)
	_button(shop_back_rect, "← НАЗАД КЪМ ИГРАТА" if shop_return_mode == PLAYING else "← НАЗАД КЪМ КАРТАТА", Color("#604080"), 16)


func _draw_hud() -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, 48),
		"CANDY KINGDOM",
		HORIZONTAL_ALIGNMENT_CENTER,
		screen.x,
		32,
		Color("#fff3ff")
	)

	_panel(Rect2(screen.x * 0.25, 53, screen.x * 0.50, 27), Color("#6a3b8b"), 12.0)
	draw_string(ThemeDB.fallback_font, Vector2(0, 73), "РЕЗУЛТАТ: %s" % _format_score(score), HORIZONTAL_ALIGNMENT_CENTER, screen.x, 17, Color("#ffe17a"))

	var w := (screen.x - 50.0) / 2.0

	_panel(Rect2(18, 82, w, 45), Color("#512b72"), 16.0)
	_panel(Rect2(32 + w, 82, w, 45), Color("#512b72"), 16.0)
	draw_line(Vector2(30, 86), Vector2(18 + w - 12, 86), Color(1, 1, 1, 0.18), 2.0, true)
	draw_line(Vector2(44 + w, 86), Vector2(32 + 2 * w - 12, 86), Color(1, 1, 1, 0.18), 2.0, true)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(18, 111),
		"НИВО %d / 20" % level,
		HORIZONTAL_ALIGNMENT_CENTER,
		w,
		18,
		Color("#ffcf5a")
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(32 + w, 111),
		"ХОДОВЕ: %d" % moves,
		HORIZONTAL_ALIGNMENT_CENTER,
		w,
		18,
		Color("#9beaff")
	)

	if boss_max_hp > 0:
		draw_string(ThemeDB.fallback_font, Vector2(0, 132), "БОС %s  ♥ %d/%d" % ["🍭" if level % 10 == 5 else "👑", boss_hp, boss_max_hp], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 17, Color("#ff9cba"))
	draw_string(ThemeDB.fallback_font, Vector2(0, 175), _world_name(level), HORIZONTAL_ALIGNMENT_CENTER, screen.x, 12, _world_color(level))

	draw_string(ThemeDB.fallback_font, Vector2(14, 151), "ЖИВОТИ: " + "♥".repeat(lives) + "♡".repeat(MAX_LIVES - lives), HORIZONTAL_ALIGNMENT_LEFT, screen.x * 0.55, 17, Color("#ff739f"))
	play_map_rect = Rect2(12, 178, screen.x * 0.43, 34)
	play_shop_rect = Rect2(screen.x * 0.55, 178, screen.x * 0.43 - 12, 34)
	_button(play_map_rect, "← КАРТА", Color("#604080"), 13)
	_button(play_shop_rect, "🛒 МАГАЗИН  •  %d 🪙" % coins, Color("#8752a5"), 12)
	hammer_button_rect = Rect2(screen.x - 132.0, 133.0, 118.0, 38.0)
	_button(hammer_button_rect, "🔨 ЧУК: %d" % hammer_stock, Color("#95652d") if hammer_mode else Color("#65458d"), 14)
	if hammer_mode:
		draw_string(ThemeDB.fallback_font, Vector2(0, board_origin.y - 8), "ИЗБЕРИ БОНБОН ЗА ПРЕМАХВАНЕ", HORIZONTAL_ALIGNMENT_CENTER, screen.x, 14, Color("#ffe58b"))


# Целите показват само иконка и брояч.
func _format_score(value: int) -> String:
	var raw := str(maxi(0, value))
	var result := ""
	while raw.length() > 3:
		result = " " + raw.substr(raw.length() - 3, 3) + result
		raw = raw.substr(0, raw.length() - 3)
	return raw + result


func _draw_goals() -> void:
	var goals: Dictionary = GOALS[level - 1]
	var count := goals.size()

	var gap := 12.0

	var item_w := minf(
		112.0,
		(screen.x - 45.0 - gap * (count - 1)) / float(count)
	)

	var total := item_w * count + gap * (count - 1)
	var start := (screen.x - total) * 0.5

	_panel(Rect2(start - 9.0, 140.0, total + 18.0, 62.0), Color("#321d50"), 17.0)
	draw_line(Vector2(start, 145), Vector2(start + total, 145), Color("#ffe7a8", 0.65), 2.0, true)

	var index := 0

	for key in goals.keys():
		var kind := int(key)
		var x := start + float(index) * (item_w + gap)

		_draw_candy(
			Vector2(x + 22.0, 171.0),
			18.0,
			kind,
			1.0,
			0.0
		)

		var text := "%d/%d" % [
			collected[kind],
			int(goals[key])
		]

		var tint := Color("#baffb0") if collected[kind] >= int(goals[key]) else Color.WHITE

		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + 42.0, 177.0),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			item_w - 42.0,
			17,
			tint
		)

		index += 1


func _draw_board() -> void:
	# Дебела рамка като захарна глазура около игралното поле.
	_panel(Rect2(board_origin - Vector2(16, 16), Vector2(board_size + 32, board_size + 32)), Color("#f6c66f"), 25.0)
	_panel(Rect2(board_origin - Vector2(11, 11), Vector2(board_size + 22, board_size + 22)), Color("#7b3d91"), 21.0)
	_panel(Rect2(board_origin - Vector2(6, 6), Vector2(board_size + 12, board_size + 12)), Color("#25133f"), 18.0)

	for y in range(ROWS):
		for x in range(COLS):
			var rect := Rect2(
				board_origin + Vector2(x, y) * cell,
				Vector2(cell, cell)
			).grow(-2.0)

			var tile_color: Color = Color("#56346e") if (x + y) % 2 == 0 else Color("#45285f")
			_panel(rect, tile_color, 9.0)
			draw_line(rect.position + Vector2(7, 3), rect.position + Vector2(rect.size.x - 7, 3), Color(1, 1, 1, 0.10), 1.0, true)

			var k: int = board[x][y]

			# Не рисуваме бонбоните, които в момента падат.
			if k >= 0 and not _is_falling_target(Vector2i(x, y)):
				var center := rect.position + rect.size * 0.5

				var pulse := 1.0 + 0.025 * sin(
					clock * 3.0 + float(x + y)
				)

				if selected == Vector2i(x, y):
					pulse = 1.0 + 0.10 * sin(clock * 10.0)

				_draw_candy(
					center,
					cell * 0.42 * pulse,
					k,
					1.0,
					0.07 * sin(clock * 2.0 + x * 0.7 + y * 0.4)
				)

				if selected == Vector2i(x, y):
					draw_arc(
						center,
						cell * 0.44,
						0.0,
						TAU,
						40,
						Color("#fff1a6"),
						3.0,
						true
					)


func _is_falling_target(target: Vector2i) -> bool:
	for fall in falling_candies:
		if fall.to_cell == target:
			return true

	return false


# Рисуваме движещите се бонбони.
func _draw_moving_candies() -> void:
	# Падащи бонбони.
	for fall in falling_candies:
		var duration := maxf(0.01, float(fall.duration))

		var t := clampf(
			float(fall.elapsed) / duration,
			0.0,
			1.0
		)

		var eased := 1.0 - pow(1.0 - t, 3.0)

		var pos: Vector2 = fall.from.lerp(fall.to, eased)

		_draw_candy(
			pos,
			cell * 0.42,
			int(fall.kind),
			1.0,
			0.04 * sin(clock * 8.0 + float(fall.kind))
		)

	# Бонбони, които летят към целите горе.
	for fly in flying_candies:
		var duration := maxf(0.01, float(fly.duration))

		var t := clampf(
			float(fly.elapsed) / duration,
			0.0,
			1.0
		)

		var eased := t * t * (3.0 - 2.0 * t)

		var pos: Vector2 = fly.from.lerp(fly.to, eased)

		var shrink := 1.0 - 0.45 * eased

		_draw_candy(
			pos,
			cell * 0.30 * shrink,
			int(fly.kind),
			1.0,
			clock * 2.0
		)


# Намираме точната позиция на иконката за даден цвят.
func _goal_position(kind: int) -> Vector2:
	var goals: Dictionary = GOALS[level - 1]

	var gap := 12.0

	var item_w := minf(
		112.0,
		(screen.x - 45.0 - gap * (goals.size() - 1)) / float(goals.size())
	)

	var total := item_w * goals.size() + gap * (goals.size() - 1)
	var start := (screen.x - total) * 0.5

	var index := 0

	for key in goals.keys():
		if int(key) == kind:
			return Vector2(
				start + float(index) * (item_w + gap) + 22.0,
				171.0
			)

		index += 1

	return Vector2(screen.x * 0.5, 171.0)


# Бонбон с тяло, усукани краища и отблясъци.
func _draw_candy(
	center: Vector2,
	radius: float,
	kind: int,
	scale: float = 1.0,
	rotation: float = 0.0
) -> void:
	if scale <= 0.01:
		return

	var r: float = radius * scale
	var c: Color = COLORS[kind]
	draw_set_transform(center, rotation, Vector2.ONE)

	# Мека сянка и външен блясък.
	draw_circle(Vector2(0, r * 0.16), r * 0.94, Color(0.04, 0.02, 0.10, 0.30))
	draw_circle(Vector2.ZERO, r * 0.91, Color(c.r, c.g, c.b, 0.18))

	# Всеки цвят има собствена форма, но всички изглеждат като глазирани бонбони.
	var points := PackedVector2Array()
	match kind:
		0: # Розов - кръгла желирана капка.
			draw_circle(Vector2.ZERO, r * 0.82, c.darkened(0.18))
			draw_circle(Vector2(0, -r * 0.06), r * 0.76, c)
		1: # Син - диамант със заоблен визуален силует.
			points = PackedVector2Array([Vector2(0, -r), Vector2(r * 0.76, -r * 0.05), Vector2(r * 0.55, r * 0.72), Vector2(-r * 0.55, r * 0.72), Vector2(-r * 0.76, -r * 0.05)])
			draw_colored_polygon(points, c.darkened(0.20))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -r * 0.88), Vector2(r * 0.64, -r * 0.03), Vector2(r * 0.46, r * 0.60), Vector2(-r * 0.46, r * 0.60), Vector2(-r * 0.64, -r * 0.03)]), c)
		2: # Зелен - пухкава звезда.
			for i in range(10):
				var angle: float = -PI / 2.0 + TAU * float(i) / 10.0
				points.append(Vector2(cos(angle), sin(angle)) * (r * (0.96 if i % 2 == 0 else 0.58)))
			draw_colored_polygon(points, c.darkened(0.18))
			for i in range(points.size()):
				draw_line(points[i], points[(i + 1) % points.size()], c.lightened(0.25), maxf(1.0, r * 0.045), true)
		3: # Жълт - квадратен карамелен бонбон.
			var candy_rect := Rect2(Vector2(-r * 0.76, -r * 0.76), Vector2(r * 1.52, r * 1.52))
			var sb := StyleBoxFlat.new()
			sb.bg_color = c.darkened(0.16)
			sb.corner_radius_top_left = int(r * 0.34)
			sb.corner_radius_top_right = int(r * 0.34)
			sb.corner_radius_bottom_left = int(r * 0.34)
			sb.corner_radius_bottom_right = int(r * 0.34)
			draw_style_box(sb, candy_rect.grow(1.5))
			sb.bg_color = c
			draw_style_box(sb, candy_rect)
		4: # Лилав - шестоъгълен скъпоценен бонбон.
			for i in range(6):
				var angle: float = TAU * float(i) / 6.0 - PI / 2.0
				points.append(Vector2(cos(angle), sin(angle)) * r * 0.91)
			draw_colored_polygon(points, c.darkened(0.20))
			var inner_points := PackedVector2Array()
			for point in points:
				inner_points.append(point * 0.88)
			draw_colored_polygon(inner_points, c)
		5: # Оранжев - бонбон тип дражé.
			draw_set_transform(center, rotation, Vector2(1.12, 0.82))
			draw_circle(Vector2.ZERO, r * 0.88, c.darkened(0.20))
			draw_circle(Vector2(0, -r * 0.05), r * 0.81, c)
			draw_set_transform(center, rotation, Vector2.ONE)

	# Глазирана горна повърхност и характерен бял отблясък.
	draw_circle(Vector2(-r * 0.23, -r * 0.30), r * 0.19, Color(1, 1, 1, 0.72))
	draw_circle(Vector2(-r * 0.18, -r * 0.31), r * 0.085, Color(1, 1, 1, 0.34))
	draw_circle(Vector2(r * 0.27, -r * 0.13), r * 0.065, Color(1, 1, 1, 0.82))
	draw_arc(Vector2.ZERO, r * 0.78, PI * 1.08, PI * 1.88, 20, c.lightened(0.40), maxf(1.0, r * 0.055), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_fx() -> void:
	for p in particles:
		var alpha := clampf(
			float(p.life) / float(p.max_life),
			0.0,
			1.0
		)

		draw_set_transform(
			p.pos,
			float(p.rot),
			Vector2.ONE
		)

		draw_circle(
			Vector2.ZERO,
			float(p.radius) * alpha,
			Color(
				p.color.r,
				p.color.g,
				p.color.b,
				alpha
			)
		)

		draw_line(
			Vector2(-3, 0),
			Vector2(3, 0),
			Color(1, 1, 1, alpha),
			1.5
		)

		draw_set_transform(
			Vector2.ZERO,
			0.0,
			Vector2.ONE
		)


func _draw_hint() -> void:
	var y := minf(
		screen.y - 30.0,
		board_origin.y + board_size + 43.0
	)

	var label := message if message_time > 0.0 else "РАЗМЕНИ ДВА СЪСЕДНИ БОНБОНА"

	draw_string(
		ThemeDB.fallback_font,
		Vector2(12, y),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		screen.x - 24.0,
		14,
		Color("#fff0ff")
	)


func _modal() -> void:
	_panel(
		Rect2(
			25,
			screen.y * 0.32,
			screen.x - 50.0,
			screen.y * 0.42
		),
		Color("#24143f"),
		24.0
	)


func _draw_complete() -> void:
	_modal()

	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, screen.y * 0.40),
		"БРАВО! 🎉",
		HORIZONTAL_ALIGNMENT_CENTER,
		screen.x,
		36,
		Color("#ffcf5a")
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, screen.y * 0.40 + 50),
		"ПРЕМИНА НИВО %d!" % level,
		HORIZONTAL_ALIGNMENT_CENTER,
		screen.x,
		22,
		Color.WHITE
	)

	continue_rect = Rect2(
		screen.x * 0.2,
		screen.y * 0.55,
		screen.x * 0.6,
		58
	)

	draw_string(ThemeDB.fallback_font, Vector2(0, screen.y * 0.48), "★".repeat(level_stars[level - 1]), HORIZONTAL_ALIGNMENT_CENTER, screen.x, 34, Color("#ffdf62"))
	draw_string(ThemeDB.fallback_font, Vector2(0, screen.y * 0.52), "РЕЗУЛТАТ: %s  •  +%d МОНЕТИ" % [_format_score(score), 10 + level_stars[level - 1] * 5], HORIZONTAL_ALIGNMENT_CENTER, screen.x, 15, Color("#ffe6a0"))
	_button(
		continue_rect,
		"КЪМ ГЛАВНОТО МЕНЮ",
		Color("#a04fbd"),
		17
	)


func _draw_failed() -> void:
	_modal()

	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, screen.y * 0.39),
		"ОПИТАЙ ОТНОВО!",
		HORIZONTAL_ALIGNMENT_CENTER,
		screen.x,
		30,
		Color("#ff8caa")
	)

	retry_rect = Rect2(
		screen.x * 0.2,
		screen.y * 0.51,
		screen.x * 0.6,
		55
	)

	home_rect = Rect2(
		screen.x * 0.2,
		screen.y * 0.62,
		screen.x * 0.6,
		55
	)

	_button(
		retry_rect,
		"ОПИТАЙ ПАК",
		Color("#a04fbd")
	)

	_button(
		home_rect,
		"ГЛАВНО МЕНЮ",
		Color("#604080")
	)


func _draw_victory() -> void:
	_modal()

	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, screen.y * 0.42),
		"ПОБЕДА! 🏆",
		HORIZONTAL_ALIGNMENT_CENTER,
		screen.x,
		40,
		Color("#ffcf5a")
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, screen.y * 0.42 + 55),
		"ПРЕМИНА И 20-ТЕ НИВА!",
		HORIZONTAL_ALIGNMENT_CENTER,
		screen.x,
		20,
		Color.WHITE
	)

	continue_rect = Rect2(
		screen.x * 0.2,
		screen.y * 0.57,
		screen.x * 0.6,
		60
	)

	_button(
		continue_rect,
		"ГЛАВНО МЕНЮ",
		Color("#a04fbd")
	)


func _input(event: InputEvent) -> void:
	# Мишка/тракпад за компютър.
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_tap(event.position)
		return

	# На телефон обработваме докосването при отпускане, за да различим
	# кратко натискане на бутон от плъзгане на бонбон.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_pos = event.position
			_touch_last_pos = event.position
			_touch_active = true
		elif _touch_active:
			_touch_last_pos = event.position
			_handle_touch_release(event.position)
		return

	if event is InputEventScreenDrag and _touch_active:
		_touch_last_pos = event.position


func _handle_touch_release(end_pos: Vector2) -> void:
	var start_pos := _touch_start_pos
	_touch_active = false
	var delta := end_pos - start_pos

	# Плъзгане между две съседни клетки = размяна с един жест.
	if mode == PLAYING and not busy and delta.length() >= 18.0:
		var start_local := start_pos - board_origin
		var end_local := end_pos - board_origin
		var start_inside := Rect2(Vector2.ZERO, Vector2(board_size, board_size)).has_point(start_local)
		var end_inside := Rect2(Vector2.ZERO, Vector2(board_size, board_size)).has_point(end_local)

		if start_inside:
			var first := Vector2i(
				clampi(int(start_local.x / cell), 0, COLS - 1),
				clampi(int(start_local.y / cell), 0, ROWS - 1)
			)
			var second := first
			if absf(delta.x) >= absf(delta.y):
				second.x += 1 if delta.x > 0.0 else -1
			else:
				second.y += 1 if delta.y > 0.0 else -1

			if second.x >= 0 and second.x < COLS and second.y >= 0 and second.y < ROWS:
				selected = Vector2i(-1, -1)
				if hammer_mode:
					_use_hammer(first)
				else:
					_swap_and_resolve(first, second)
				queue_redraw()
				return

	# Ако жестът е кратък, третираме го като нормално докосване на бутон/клетка.
	_tap(end_pos)


func _tap(pos: Vector2) -> void:
	if mode == MENU:
		if shop_open_rect.has_point(pos):
			shop_return_mode = MENU
			mode = SHOP
			queue_redraw()
			return
		if daily_button_rect.has_point(pos):
			_claim_daily_reward()
			queue_redraw()
			return
		for i in range(menu_rects.size()):
			if menu_rects[i].has_point(pos):
				if i + 1 <= unlocked:
					_new_level(i + 1)

				return

		return

	if mode == SHOP:
		if shop_back_rect.has_point(pos):
			mode = shop_return_mode
		else:
			for i in range(shop_rects.size()):
				if shop_rects[i].has_point(pos):
					_buy_shop_item(i)
					break
		queue_redraw()
		return

	if mode == COMPLETE:
		if continue_rect.has_point(pos):
			mode = MENU

		return

	if mode == GAME_OVER:
		if retry_rect.has_point(pos):
			if lives <= 0 and extra_life_stock > 0:
				extra_life_stock -= 1
				lives = 1
				_save_progress()
			_new_level(level)

		elif home_rect.has_point(pos):
			mode = MENU

		return

	if mode == VICTORY:
		if continue_rect.has_point(pos):
			mode = MENU

		return

	if mode != PLAYING or busy:
		return
	if play_map_rect.has_point(pos):
		mode = MENU
		selected = Vector2i(-1, -1)
		hammer_mode = false
		_save_progress()
		queue_redraw()
		return
	if play_shop_rect.has_point(pos):
		shop_return_mode = PLAYING
		mode = SHOP
		queue_redraw()
		return
	if hammer_button_rect.has_point(pos):
		hammer_mode = not hammer_mode
		message = "ИЗБЕРИ БОНБОН ЗА ЧУКА" if hammer_mode else "ЧУКЪТ Е ИЗКЛЮЧЕН"
		message_time = 1.5
		queue_redraw()
		return

	var local := pos - board_origin

	if (
		local.x < 0.0
		or local.y < 0.0
		or local.x >= board_size
		or local.y >= board_size
	):
		return

	var spot := Vector2i(
		int(local.x / cell),
		int(local.y / cell)
	)

	if hammer_mode:
		_use_hammer(spot)
		return

	if selected.x < 0:
		selected = spot

	elif selected == spot:
		selected = Vector2i(-1, -1)

	else:
		var d := (spot - selected).abs()

		if d.x + d.y == 1:
			var first := selected

			selected = Vector2i(-1, -1)

			_swap_and_resolve(first, spot)

		else:
			selected = spot

	queue_redraw()


func _buy_shop_item(index: int) -> void:
	if index < 0 or index >= shop_item_prices.size():
		return
	var price: int = shop_item_prices[index]
	if coins < price:
		message = "НЯМА ДОСТАТЪЧНО МОНЕТИ! ТРЯБВАТ ТИ %d." % price
		message_time = 2.2
		return
	coins -= price
	match index:
		0:
			booster_moves += 5
			message = "КУПИ +5 ХОДА! ЩЕ СЕ ИЗПОЛЗВАТ В СЛЕДВАЩОТО НИВО."
		1:
			booster_bomb = true
			message = "КУПИ БОМБА 3×3 ЗА СЛЕДВАЩОТО НИВО!"
		2:
			booster_shuffle = true
			message = "РАЗБЪРКВАНЕТО Е ПОДГОТВЕНО ЗА СЛЕДВАЩОТО НИВО!"
		3:
			hammer_stock += 1
			message = "ПОЛУЧИ 1 ЧУК!"
		4:
			extra_life_stock += 1
			message = "ПОЛУЧИ 1 ЖИВОТ В РЕЗЕРВ!"
		5:
			hammer_stock += 3
			message = "ПОЛУЧИ ПАКЕТ ОТ 3 ЧУКА!"
	message_time = 2.5
	_save_progress()


func _swap_and_resolve(a: Vector2i, b: Vector2i) -> void:
	busy = true

	_swap(a, b)

	queue_redraw()

	await get_tree().create_timer(0.12).timeout

	var found := _find_matches()

	if found.is_empty():
		_swap(a, b)

		message = "НЯМА КОМБИНАЦИЯ – ОПИТАЙ ОТНОВО!"
		message_time = 1.4

		busy = false

		queue_redraw()

		return

	moves -= 1

	await _resolve(found)

	if _goals_done():
		_finish_level()

	elif moves <= 0:
		_lose_life()

	busy = false

	queue_redraw()


func _shuffle_board() -> void:
	if board.is_empty():
		return
	var attempts := 0
	while attempts < 250:
		attempts += 1
		for y in range(ROWS):
			for x in range(COLS):
				board[x][y] = randi_range(0, int(LEVEL_TYPES[level - 1]) - 1)
		if _find_matches().is_empty() and _has_valid_move():
			break
	message = "НЯМАШ ВЪЗМОЖНИ ХОДОВЕ – НОВО ПОДРЕЖДАНЕ!"
	message_time = 1.8


func _has_valid_move() -> bool:
	if board.is_empty():
		return false
	for y in range(ROWS):
		for x in range(COLS):
			var here := Vector2i(x, y)
			if x + 1 < COLS:
				_swap(here, Vector2i(x + 1, y))
				var horizontal_match := not _find_matches().is_empty()
				_swap(here, Vector2i(x + 1, y))
				if horizontal_match:
					return true
			if y + 1 < ROWS:
				_swap(here, Vector2i(x, y + 1))
				var vertical_match := not _find_matches().is_empty()
				_swap(here, Vector2i(x, y + 1))
				if vertical_match:
					return true
	return false


func _swap(a: Vector2i, b: Vector2i) -> void:
	var temp: int = board[a.x][a.y]

	board[a.x][a.y] = board[b.x][b.y]
	board[b.x][b.y] = temp


func _find_matches() -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	# Хоризонтални комбинации.
	for y in range(ROWS):
		var x := 0

		while x < COLS:
			var k: int = board[x][y]
			var end := x + 1

			while end < COLS and board[end][y] == k:
				end += 1

			if k >= 0 and end - x >= 3:
				for n in range(x, end):
					var p := Vector2i(n, y)

					if not result.has(p):
						result.append(p)

			x = end

	# Вертикални комбинации.
	for x in range(COLS):
		var y := 0

		while y < ROWS:
			var k: int = board[x][y]
			var end := y + 1

			while end < ROWS and board[x][end] == k:
				end += 1

			if k >= 0 and end - y >= 3:
				for n in range(y, end):
					var p := Vector2i(x, n)

					if not result.has(p):
						result.append(p)

			y = end

	return result


# Премахване, събиране и падане на новите бонбони.
func _resolve(found: Array[Vector2i]) -> void:
	cascade_count = 0
	while not found.is_empty():
		cascade_count += 1
		var wave_points: int = found.size() * 60 * mini(cascade_count, 5)
		score += wave_points
		if cascade_count >= 2:
			var cascade_words := ["", "", "СЛАДКА ВЕРИГА!", "ВКУСНО!", "НЕВЕРОЯТНО!", "ЗАХАРЕН ВЗРИВ!"]
			message = cascade_words[mini(cascade_count, cascade_words.size() - 1)] + "  +" + _format_score(wave_points)
			message_time = 1.25
		# Специални комбинации: 4+ бонбона изчистват ред, 5+ правят дъгова експлозия.
		if booster_bomb:
			var bomb_center: Vector2i = found[0]
			for bx in range(maxi(0, bomb_center.x - 1), mini(COLS, bomb_center.x + 2)):
				for by in range(maxi(0, bomb_center.y - 1), mini(ROWS, bomb_center.y + 2)):
					var bomb_cell := Vector2i(bx, by)
					if not found.has(bomb_cell): found.append(bomb_cell)
			booster_bomb = false
			_save_progress()
			_burst(board_origin + (Vector2(bomb_center) + Vector2(0.5, 0.5)) * cell, Color("#fff27a"))
		# Комбинация от 5+ бонбона дава само голям визуален ефект.
		# Вече НЕ премахва всички бонбони от същия цвят.
		if found.size() >= 5:
			screen_flash = 0.75
			shake_time = 0.22
			shake_strength = 5.0
			var celebration_pos := board_origin + (Vector2(found[0]) + Vector2(0.5, 0.5)) * cell
			_burst(celebration_pos, Color("#fff27a"))
		elif found.size() == 4:
			screen_flash = 0.35
			var center: Vector2i = found[0]
			for xx in range(COLS):
				var row_pos := Vector2i(xx, center.y)
				if not found.has(row_pos): found.append(row_pos)
			_burst(board_origin + (Vector2(center) + Vector2(0.5, 0.5)) * cell, Color("#fff27a"))
		var goals: Dictionary = GOALS[level - 1]

		# Събраните бонбони излитат към съответната цел горе.
		for p in found:
			var k: int = board[p.x][p.y]

			var from_pos := board_origin + (
				Vector2(p) + Vector2(0.5, 0.5)
			) * cell

			if k >= 0:
				_burst(from_pos, COLORS[k])

			if (
				k >= 0
				and goals.has(k)
				and collected[k] < int(goals[k])
			):
				collected[k] += 1

				flying_candies.append({
					"from": from_pos,
					"to": _goal_position(k),
					"kind": k,
					"elapsed": 0.0,
					"duration": randf_range(0.65, 0.90)
				})

			board[p.x][p.y] = -1

		if boss_max_hp > 0 and not found.is_empty():
			boss_hp = maxi(0, boss_hp - 1)
			screen_flash = 0.65
			_burst(Vector2(screen.x * 0.5, 120), Color("#ffdb7a"))

		queue_redraw()

		await get_tree().create_timer(0.30).timeout

		# Ако всички цели са събрани (и босът е победен), приключваме
		# нивото веднага, без да генерираме нови бонбони.
		if _goals_done():
			break

		# Подготвяме новото подреждане.
		var new_board: Array = []

		for x in range(COLS):
			var new_col: Array = []

			for y in range(ROWS):
				new_col.append(-1)

			new_board.append(new_col)

		falling_candies.clear()

		# Преместваме останалите бонбони надолу.
		for x in range(COLS):
			var write_y := ROWS - 1

			for y in range(ROWS - 1, -1, -1):
				var kind: int = board[x][y]

				if kind >= 0:
					new_board[x][write_y] = kind

					if write_y != y:
						var fall_start := board_origin + Vector2(
							x + 0.5,
							y + 0.5
						) * cell

						var fall_end := board_origin + Vector2(
							x + 0.5,
							write_y + 0.5
						) * cell

						falling_candies.append({
							"from": fall_start,
							"to": fall_end,
							"to_cell": Vector2i(x, write_y),
							"kind": kind,
							"elapsed": 0.0,
							"duration": 0.40 + 0.08 * float(write_y - y)
						})

					write_y -= 1

			# Новите бонбони падат отгоре в празните места.
			while write_y >= 0:
				var available_types: int = int(LEVEL_TYPES[level - 1])
				var new_kind: int = randi_range(0, available_types - 1)

				new_board[x][write_y] = new_kind

				var new_start := board_origin + Vector2(
					x + 0.5,
					-float(ROWS - write_y) * 0.85
				) * cell

				var new_end := board_origin + Vector2(
					x + 0.5,
					write_y + 0.5
				) * cell

				falling_candies.append({
					"from": new_start,
					"to": new_end,
					"to_cell": Vector2i(x, write_y),
					"kind": new_kind,
					"elapsed": 0.0,
					"duration": 0.55 + 0.06 * float(ROWS - write_y)
				})

				write_y -= 1

		board = new_board

		queue_redraw()

		# Изчакваме бонбоните да паднат.
		await get_tree().create_timer(1.35).timeout

		falling_candies.clear()

		queue_redraw()

		# Проверяваме дали падането е създало нова комбинация.
		found = _find_matches()
		if found.is_empty() and not _has_valid_move():
			_shuffle_board()
			queue_redraw()
			await get_tree().create_timer(0.35).timeout


func _goals_done() -> bool:
	if boss_max_hp > 0 and boss_hp > 0:
		return false
	var goals: Dictionary = GOALS[level - 1]

	for key in goals.keys():
		var k := int(key)

		if collected[k] < int(goals[key]):
			return false

	return true


func _finish_level() -> void:
	var earned_stars := 1
	if moves >= 5: earned_stars = 2
	if moves >= 10: earned_stars = 3
	level_stars[level - 1] = maxi(level_stars[level - 1], earned_stars)
	coins += 10 + earned_stars * 5
	_save_progress()
	if level == LEVEL_COUNT:
		mode = VICTORY
		return

	unlocked = mini(LEVEL_COUNT, maxi(unlocked, level + 1))

	_save_progress()

	mode = COMPLETE
	complete_time = 2.5

	selected = Vector2i(-1, -1)


func _burst(at: Vector2, color: Color) -> void:
	for i in range(12):
		var angle := TAU * float(i) / 12.0 + randf_range(-0.2, 0.2)
		var speed := randf_range(65.0, 175.0)

		particles.append({
			"pos": at,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": randf_range(0.35, 0.65),
			"max_life": 0.65,
			"radius": randf_range(2.0, 5.0),
			"color": color,
			"rot": randf_range(0.0, TAU),
			"spin": randf_range(-8.0, 8.0)
		})
