extends Node2D

const W := 1280.0
const H := 720.0
const GRAVITY := 240.0
const WEAPONS := ["Granate", "Schwer", "Cluster", "Napalm", "Atom", "MIRV", "Roller", "Dirt-Bombe", "Death Head", "Bouncer", "Erdbeben", "Laser", "Super-MIRV", "Splitterregen", "Bohrer", "Mega-Dirt"]
const PRICES := [0, 80, 125, 150, 240, 190, 110, 105, 310, 145, 180, 165, 290, 175, 200, 225]
const RADII := [35.0, 55.0, 27.0, 21.0, 95.0, 26.0, 27.0, 38.0, 22.0, 38.0, 0.0, 8.0, 28.0, 20.0, 13.0, 72.0]

var terrain := TerrainModel.new()
var players: Array[Dictionary] = []
var current := 0
var round_number := 1
var wind := 0.0
var projectile := Vector2.ZERO
var velocity := Vector2.ZERO
var projectile_active := false
var projectile_weapon := 0
var effects: Array[Dictionary] = []
var queued_bursts: Array[Dictionary] = []
var falling: Array[Dictionary] = []
var shot_owner := 0
var phase := "aim"
var ai_timer := 0.0
var status := ""
var controls: Dictionary = {}
var labels: Dictionary = {}
var shop_open := false
var game_over := false
var rng := RandomNumberGenerator.new()
var stars: Array[Vector2] = []
var player_count := 2
var cpu_count := 1
var shot_count := 0
var ai_difficulty := 1
var shot_direction := 1.0
var bounce_count := 0
var projectile_age := 0.0
var visual_trail: Array[Vector2] = []
var zebra_echo: Array[Vector2] = []
var echo_owner := -1
var visual_clock := 0.0
var visual_muzzle := Vector2.ZERO
var visual_muzzle_time := 0.0
var sparks: Array[Dictionary] = []
var menu_open := true
var income_per_turn := 35
var wind_strength := 40.0
var starting_cash := 250
var landscape_index := 0
var match_wins: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var matches_played := 0
var tournament_target := 3
var sound_enabled := true
var sound_players: Dictionary = {}
var touch_aim_enabled := true
var touch_aim_dragging := false
var touch_aim_index := -1
var touch_aim_origin := Vector2.ZERO
var touch_target := Vector2.ZERO
var touch_target_timer := 0.0
var custom_player_names: Array[String] = []
var ui_root: Control

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_keyboard_control(event)
		return
	if not touch_aim_enabled or menu_open or game_over or phase != "aim" or players.is_empty() or players[current]["cpu"]:
		return
	if event is InputEventScreenTouch and event.pressed:
		_touch_aim_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_touch_aim_at(event.position)

func _keyboard_control(event: InputEventKey) -> void:
	if menu_open or shop_open or game_over or phase != "aim" or players.is_empty() or players[current]["cpu"]:
		return
	match event.keycode:
		KEY_LEFT, KEY_A:
			_nudge_aim("angle", -1.0)
		KEY_RIGHT, KEY_D:
			_nudge_aim("angle", 1.0)
		KEY_UP, KEY_W:
			_nudge_aim("power", 2.0)
		KEY_DOWN, KEY_S:
			_nudge_aim("power", -2.0)
		KEY_SPACE:
			_fire()
		KEY_TAB:
			var weapon: int = int(players[current]["weapon"])
			for offset in range(1, WEAPONS.size() + 1):
				var next_weapon: int = (weapon + offset) % WEAPONS.size()
				if int(players[current]["ammo"][next_weapon]) > 0:
					players[current]["weapon"] = next_weapon
					_refresh_ui()
					break

func _touch_aim_at(target: Vector2) -> void:
	# Touch anywhere on the battlefield; the HUD and menus retain their own input.
	if target.y < 112.0 or target.y > 580.0:
		return
	var origin: Vector2 = _tank_pos(current) + Vector2(0, -17)
	var dx: float = target.x - origin.x
	if absf(dx) < 12.0:
		return
	var direction: float = 1.0 if dx > 0.0 else -1.0
	var best_error: float = INF
	var best_angle: float = 48.0
	var best_power: float = 72.0
	# Solve the existing ballistic equations, including wind, without changing gameplay.
	for angle_deg in range(8, 86, 2):
		var radians: float = deg_to_rad(float(angle_deg))
		for power_percent in range(15, 101, 3):
			var speed: float = float(power_percent) * 6.3
			var vx: float = cos(radians) * speed * direction
			var vy: float = -sin(radians) * speed
			var ax: float = wind * 1.05
			var time: float = absf(dx) / maxf(absf(vx), 1.0)
			for iteration in range(3):
				var diff: float = vx * time + 0.5 * ax * time * time - dx
				var slope: float = vx + ax * time
				if absf(slope) > 0.01:
					time = clampf(time - diff / slope, 0.0, 15.0)
			var estimated_y: float = origin.y + vy * time + 0.5 * GRAVITY * time * time
			var error: float = absf(estimated_y - target.y) + absf(vx * time + 0.5 * ax * time * time - dx) * 2.0
			if error < best_error:
				best_error = error
				best_angle = float(angle_deg)
				best_power = float(power_percent)
	shot_direction = direction
	controls["direction"].text = "RICHTUNG: " + (">" if direction > 0.0 else "<")
	players[current]["angle"] = best_angle
	players[current]["power"] = best_power
	touch_target = target
	touch_target_timer = 1.3
	status = "TOUCH-ZIEL: Winkel %.1f°  |  Kraft %.1f%%" % [best_angle, best_power]
	_refresh_ui()
	queue_redraw()

func _ready() -> void:
	rng.randomize()
	for i in range(55):
		stars.append(Vector2(rng.randf_range(0, W), rng.randf_range(10, 370)))
	_build_ui()
	_setup_audio()
	_new_game()
	_show_menu()

func _setup_audio() -> void:
	for sound_name in ["fire", "impact", "victory"]:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/%s.wav" % sound_name)
		player.volume_db = -9.0 if sound_name == "impact" else -6.0
		add_child(player)
		sound_players[sound_name] = player

func _play_sound(sound_name: String) -> void:
	if sound_enabled and sound_players.has(sound_name):
		var player: AudioStreamPlayer = sound_players[sound_name]
		player.stop()
		player.play()

func _play_weapon_sound(weapon: int) -> void:
	# Reuse bundled samples with distinct per-weapon timbre and loudness.
	if not sound_enabled or not sound_players.has("fire"):
		return
	var player: AudioStreamPlayer = sound_players["fire"]
	var pitches := [1.0, 0.76, 1.18, 0.87, 0.53, 1.07, 1.33, 0.92, 0.58, 1.42, 0.66, 1.7, 0.73, 1.24, 0.81, 0.62]
	player.pitch_scale = pitches[clampi(weapon, 0, pitches.size() - 1)]
	player.volume_db = -3.0 if weapon in [4, 8, 12, 15] else -6.0
	player.stop()
	player.play()

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	controls["sound"].text = "TON: AN" if sound_enabled else "TON: AUS"

func _new_game() -> void:
	terrain.generate_map(landscape_index)
	players.clear()
	var colors := [Color("57baff"), Color("ff657d"), Color("f7c85b"), Color("a68bfa"), Color("71e2a3"), Color("ff9b64"), Color("46d6cb"), Color("ff8bd5"), Color("b7ef63"), Color("f0aaff")]
	for i in range(player_count):
		var is_cpu := i >= player_count - cpu_count
		var player_name: String = ("CPU " if is_cpu else "P") + str(i + 1)
		if not is_cpu and i < custom_player_names.size() and not custom_player_names[i].is_empty():
			player_name = custom_player_names[i]
		players.append({"x": 105.0 + 1070.0 * float(i) / float(player_count - 1), "hp": 100, "shield": 0, "money": starting_cash, "armor": 0, "engine": 0, "damage_upgrade": 0, "angle": 48.0, "power": 72.0, "weapon": 0, "ammo": [999, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "teleports": 0, "walks": 0, "parachutes": 1, "color": colors[i], "name": player_name, "cpu": is_cpu})
	current = 0
	round_number = 1
	game_over = false
	projectile_active = false
	queued_bursts.clear()
	zebra_echo.clear()
	echo_owner = -1
	falling.clear()
	effects.clear()
	sparks.clear()
	shop_open = false
	phase = "aim"
	wind = rng.randf_range(-wind_strength, wind_strength)
	for p in players:
		p["last_ground"] = terrain.height_at(p["x"])
	shot_count = 0
	status = "ZEBRA EDITION: Spieler 1 ist am Zug. Winkel und Kraft einstellen."
	_refresh_ui()
	queue_redraw()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	ui_root = root
	_apply_ui_theme(root)
	var top := PanelContainer.new()
	top.position = Vector2(12, 10)
	top.size = Vector2(1252, 92)
	root.add_child(top)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 20)
	top.add_child(info)
	for key in ["p1", "round", "wind", "p2"]:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 27)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_child(label)
		labels[key] = label
	var bottom := PanelContainer.new()
	bottom.position = Vector2(12, 590)
	bottom.size = Vector2(1256, 119)
	root.add_child(bottom)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	scroll.add_child(row)
	var angle_minus := Button.new()
	angle_minus.text = "−"
	angle_minus.custom_minimum_size = Vector2(66, 94)
	angle_minus.add_theme_font_size_override("font_size", 35)
	angle_minus.pressed.connect(func(): _nudge_aim("angle", -0.5))
	row.add_child(angle_minus)
	controls["angle_minus"] = angle_minus
	var angle_plus := Button.new()
	angle_plus.text = "+"
	angle_plus.custom_minimum_size = Vector2(82, 94)
	angle_plus.add_theme_font_size_override("font_size", 35)
	angle_plus.pressed.connect(func(): _nudge_aim("angle", 0.5))
	row.add_child(angle_plus)
	controls["angle_plus"] = angle_plus
	var power_minus := Button.new()
	power_minus.text = "−"
	power_minus.custom_minimum_size = Vector2(82, 94)
	power_minus.add_theme_font_size_override("font_size", 35)
	power_minus.pressed.connect(func(): _nudge_aim("power", -0.5))
	row.add_child(power_minus)
	controls["power_minus"] = power_minus
	var power_plus := Button.new()
	power_plus.text = "+"
	power_plus.custom_minimum_size = Vector2(82, 94)
	power_plus.add_theme_font_size_override("font_size", 35)
	power_plus.pressed.connect(func(): _nudge_aim("power", 0.5))
	row.add_child(power_plus)
	controls["power_plus"] = power_plus
	var weapon := Button.new()
	weapon.text = "WAFFEN"
	weapon.custom_minimum_size = Vector2(155, 94)
	weapon.pressed.connect(_open_weapon_arsenal)
	row.add_child(weapon)
	controls["weapon"] = weapon
	var arsenal := PopupPanel.new()
	arsenal.title = "WAFFENARSENAL"
	arsenal.size = Vector2i(790, 545)
	root.add_child(arsenal)
	controls["arsenal"] = arsenal
	var arsenal_layout := VBoxContainer.new()
	arsenal_layout.custom_minimum_size = Vector2(760, 510)
	arsenal.add_child(arsenal_layout)
	var arsenal_title := Label.new()
	arsenal_title.text = "WAFFEN WÄHLEN  •  ∞ = unbegrenzt"
	arsenal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arsenal_title.add_theme_font_size_override("font_size", 27)
	arsenal_layout.add_child(arsenal_title)
	var arsenal_grid := GridContainer.new()
	arsenal_grid.columns = 4
	arsenal_grid.add_theme_constant_override("h_separation", 7)
	arsenal_grid.add_theme_constant_override("v_separation", 7)
	arsenal_layout.add_child(arsenal_grid)
	for i in range(WEAPONS.size()):
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(181, 95)
		tile.add_theme_font_size_override("font_size", 19)
		tile.pressed.connect(_weapon_selected.bind(i))
		arsenal_grid.add_child(tile)
		controls["weapon_tile_%d" % i] = tile
	var arsenal_close := Button.new()
	arsenal_close.text = "← ZURÜCK"
	arsenal_close.custom_minimum_size.y = 46
	arsenal_close.pressed.connect(func(): arsenal.hide())
	arsenal_layout.add_child(arsenal_close)
	var angle := HSlider.new()
	angle.min_value = 5
	angle.max_value = 85
	angle.value = 48
	angle.step = 0.5
	angle.custom_minimum_size = Vector2(145, 94)
	angle.value_changed.connect(_angle_changed)
	row.add_child(angle)
	controls["angle"] = angle
	var angle_label := Label.new()
	angle_label.custom_minimum_size.x = 112
	row.add_child(angle_label)
	labels["angle"] = angle_label
	var power := HSlider.new()
	power.min_value = 15
	power.max_value = 100
	power.value = 72
	power.step = 0.5
	power.custom_minimum_size = Vector2(145, 94)
	power.value_changed.connect(_power_changed)
	row.add_child(power)
	controls["power"] = power
	var power_label := Label.new()
	power_label.custom_minimum_size.x = 112
	row.add_child(power_label)
	labels["power"] = power_label
	var touch_button := Button.new()
	touch_button.text = "TOUCH: AN"
	touch_button.custom_minimum_size = Vector2(150, 94)
	touch_button.pressed.connect(_toggle_touch_aim)
	row.add_child(touch_button)
	controls["touch_aim"] = touch_button
	var teleport_button := Button.new()
	teleport_button.text = "TELEPORT"
	teleport_button.custom_minimum_size = Vector2(155, 94)
	teleport_button.pressed.connect(func(): _use_movement_item("teleport"))
	row.add_child(teleport_button)
	controls["teleport"] = teleport_button
	var walk_button := Button.new()
	walk_button.text = "LAUFEN"
	walk_button.custom_minimum_size = Vector2(140, 94)
	walk_button.pressed.connect(func(): _use_movement_item("walk"))
	row.add_child(walk_button)
	controls["walk"] = walk_button
	var shop := Button.new()
	shop.text = "SHOP"
	shop.custom_minimum_size = Vector2(120, 94)
	shop.pressed.connect(_shop_pressed)
	row.add_child(shop)
	controls["shop"] = shop
	var direction_button := Button.new()
	direction_button.text = "RICHTUNG: >"
	direction_button.custom_minimum_size = Vector2(145, 94)
	direction_button.pressed.connect(_toggle_direction)
	row.add_child(direction_button)
	controls["direction"] = direction_button
	var fire := Button.new()
	fire.text = "FEUER!"
	fire.add_theme_font_size_override("font_size", 28)
	fire.custom_minimum_size = Vector2(160, 94)
	fire.pressed.connect(_fire)
	row.add_child(fire)
	controls["fire"] = fire
	var menu_button := Button.new()
	menu_button.text = "MENÜ"
	menu_button.custom_minimum_size = Vector2(125, 94)
	menu_button.pressed.connect(_show_menu)
	row.add_child(menu_button)
	var restart := Button.new()
	restart.text = "NEU"
	restart.custom_minimum_size = Vector2(105, 94)
	restart.pressed.connect(_new_game)
	row.add_child(restart)
	var difficulty_button := Button.new()
	difficulty_button.text = "KI: NORMAL"
	difficulty_button.custom_minimum_size = Vector2(140, 94)
	difficulty_button.pressed.connect(_cycle_difficulty)
	row.add_child(difficulty_button)
	controls["difficulty"] = difficulty_button
	var count_button := Button.new()
	count_button.text = "2 SPIELER"
	count_button.custom_minimum_size = Vector2(115, 94)
	count_button.pressed.connect(_cycle_player_count)
	row.add_child(count_button)
	controls["count"] = count_button
	var cpu_button := Button.new()
	cpu_button.text = "1 CPU"
	cpu_button.custom_minimum_size = Vector2(90, 65)
	cpu_button.pressed.connect(_cycle_cpu_count)
	row.add_child(cpu_button)
	controls["cpu_count"] = cpu_button
	var rules_button := Button.new()
	rules_button.text = "REGELN"
	rules_button.custom_minimum_size = Vector2(105, 65)
	rules_button.pressed.connect(_cycle_rules)
	row.add_child(rules_button)
	controls["rules"] = rules_button
	var message := Label.new()
	message.position = Vector2(28, 567)
	message.add_theme_font_size_override("font_size", 22)
	root.add_child(message)
	labels["status"] = message
	var popup := PopupPanel.new()
	popup.size = Vector2i(650, 560)
	root.add_child(popup)
	controls["popup"] = popup
	var shop_layout := VBoxContainer.new()
	shop_layout.custom_minimum_size = Vector2(620, 530)
	popup.add_child(shop_layout)
	var shop_title := Label.new()
	shop_title.text = "ZEBRA-SHOP"
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_title.add_theme_font_size_override("font_size", 30)
	shop_layout.add_child(shop_title)
	var shop_money := Label.new()
	shop_money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_layout.add_child(shop_money)
	labels["shop_money"] = shop_money
	var shop_tabs := HBoxContainer.new()
	shop_tabs.add_theme_constant_override("separation", 7)
	shop_layout.add_child(shop_tabs)
	for category_name in ["WAFFEN", "SCHUTZ", "EXTRAS"]:
		var tab := Button.new()
		tab.text = category_name
		tab.custom_minimum_size = Vector2(195, 57)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_shop_category.bind(category_name))
		shop_tabs.add_child(tab)
		controls["shop_tab_" + category_name] = tab
	var shop_scroll := ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shop_scroll.follow_focus = true
	shop_layout.add_child(shop_scroll)
	controls["shop_scroll"] = shop_scroll
	var shop_navigation := HBoxContainer.new()
	shop_navigation.add_theme_constant_override("separation", 12)
	shop_layout.add_child(shop_navigation)
	var shop_up := Button.new()
	shop_up.text = "▲  NACH OBEN"
	shop_up.custom_minimum_size = Vector2(290, 62)
	shop_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_up.pressed.connect(_scroll_shop.bind(-260))
	shop_navigation.add_child(shop_up)
	var shop_down := Button.new()
	shop_down.text = "▼  NACH UNTEN"
	shop_down.custom_minimum_size = Vector2(290, 62)
	shop_down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_down.pressed.connect(_scroll_shop.bind(260))
	shop_navigation.add_child(shop_down)
	var shop_items := VBoxContainer.new()
	shop_items.custom_minimum_size.x = 595
	shop_items.add_theme_constant_override("separation", 8)
	shop_scroll.add_child(shop_items)
	var category := Label.new()
	category.text = "WAFFEN & MUNITION"
	category.add_theme_font_size_override("font_size", 24)
	shop_items.add_child(category)
	controls["shop_section_WAFFEN"] = category
	for i in range(1, WEAPONS.size()):
		var buy_button := Button.new()
		buy_button.text = "%s  —  $%d" % [WEAPONS[i], PRICES[i]]
		buy_button.custom_minimum_size.y = 55
		buy_button.pressed.connect(_shop_buy.bind("buy_%d" % i))
		shop_items.add_child(buy_button)
		controls["shop_weapon_%d" % i] = buy_button
	var protection_title := Label.new()
	protection_title.text = "SCHUTZ & VERBESSERUNGEN"
	protection_title.add_theme_font_size_override("font_size", 24)
	shop_items.add_child(protection_title)
	controls["shop_section_SCHUTZ"] = protection_title
	var protection_items := [
		["Schild +40", 100, "shield"],
		["Fallschirm +1", 75, "parachute"],
		["Panzerung +1", 160, "armor"],
		["Feuerkraft +1", 200, "damage_upgrade"],
		["Antrieb +1", 120, "engine"]
	]
	for item in protection_items:
		var buy_button := Button.new()
		buy_button.text = "%s  —  $%d" % [item[0], item[1]]
		buy_button.custom_minimum_size.y = 55
		buy_button.pressed.connect(_shop_buy.bind(item[2]))
		shop_items.add_child(buy_button)
		controls["shop_protection_" + str(item[2])] = buy_button
	var movement_title := Label.new()
	movement_title.text = "BEWEGUNG"
	movement_title.add_theme_font_size_override("font_size", 24)
	shop_items.add_child(movement_title)
	controls["shop_section_EXTRAS"] = movement_title
	for item in [["Teleport (1x)", 170, "teleport"], ["5 Zebralängen laufen", 90, "walk"]]:
		var buy_button := Button.new()
		buy_button.text = "%s  —  $%d" % [item[0], item[1]]
		buy_button.custom_minimum_size.y = 55
		buy_button.pressed.connect(_shop_buy.bind(item[2]))
		shop_items.add_child(buy_button)
		controls["shop_extra_" + str(item[2])] = buy_button
	_select_shop_category("WAFFEN")
	var shop_back := Button.new()
	shop_back.text = "← ZURÜCK ZUM SPIEL"
	shop_back.custom_minimum_size.y = 65
	shop_back.pressed.connect(func(): popup.hide())
	shop_layout.add_child(shop_back)
	_build_main_menu(root)
	var terrain_button := Button.new()
	terrain_button.text = "LANDSCHAFT"
	terrain_button.custom_minimum_size = Vector2(145, 65)
	terrain_button.pressed.connect(_cycle_landscape)
	row.add_child(terrain_button)
	controls["landscape"] = terrain_button
	var sound_button := Button.new()
	sound_button.text = "TON: AN"
	sound_button.custom_minimum_size = Vector2(110, 65)
	sound_button.pressed.connect(_toggle_sound)
	row.add_child(sound_button)
	controls["sound"] = sound_button
	var save_button := Button.new()
	save_button.text = "SPEICHERN"
	save_button.custom_minimum_size = Vector2(145, 65)
	save_button.pressed.connect(_save_game)
	row.add_child(save_button)
	var load_button := Button.new()
	load_button.text = "LADEN"
	load_button.custom_minimum_size = Vector2(110, 65)
	load_button.pressed.connect(_load_game)
	row.add_child(load_button)
	# Compact primary controls stay visible; secondary controls live in a separate extras window.
	var extras_popup := PopupPanel.new()
	extras_popup.title = "EXTRAS"
	extras_popup.size = Vector2i(420, 550)
	root.add_child(extras_popup)
	var extras_scroll := ScrollContainer.new()
	extras_scroll.custom_minimum_size = Vector2(400, 520)
	extras_popup.add_child(extras_scroll)
	var extras_column := VBoxContainer.new()
	extras_column.custom_minimum_size.x = 385
	extras_column.add_theme_constant_override("separation", 5)
	extras_scroll.add_child(extras_column)
	var extras_button := Button.new()
	extras_button.text = "EXTRAS"
	extras_button.custom_minimum_size = Vector2(125, 94)
	extras_button.pressed.connect(func(): extras_popup.popup_centered())
	row.add_child(extras_button)
	controls["extras"] = extras_button
	var extras_back := Button.new()
	extras_back.text = "← ZURÜCK ZUM SPIEL"
	extras_back.custom_minimum_size = Vector2(365, 64)
	extras_back.pressed.connect(func(): extras_popup.hide())
	extras_column.add_child(extras_back)
	# Separate item actions and game settings from the extras window.
	var items_popup := PopupPanel.new()
	items_popup.title = "ITEMS BENUTZEN"
	items_popup.size = Vector2i(430, 350)
	root.add_child(items_popup)
	var items_column := VBoxContainer.new()
	items_column.custom_minimum_size = Vector2(400, 320)
	items_column.add_theme_constant_override("separation", 10)
	items_popup.add_child(items_column)
	var items_button := Button.new()
	items_button.text = "ITEMS"
	items_button.custom_minimum_size = Vector2(120, 94)
	items_button.pressed.connect(func(): items_popup.popup_centered())
	row.add_child(items_button)
	var items_back := Button.new()
	items_back.text = "← ZURÜCK"
	items_back.custom_minimum_size.y = 58
	items_back.pressed.connect(func(): items_popup.hide())
	items_column.add_child(items_back)
	var shield_note := Label.new()
	shield_note.text = "SCHILD: wirkt automatisch nach dem Kauf im SHOP"
	shield_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	items_column.add_child(shield_note)
	var settings_popup := PopupPanel.new()
	settings_popup.title = "EINSTELLUNGEN"
	settings_popup.size = Vector2i(430, 540)
	root.add_child(settings_popup)
	var settings_scroll := ScrollContainer.new()
	settings_scroll.custom_minimum_size = Vector2(400, 510)
	settings_popup.add_child(settings_scroll)
	var settings_column := VBoxContainer.new()
	settings_column.custom_minimum_size.x = 385
	settings_column.add_theme_constant_override("separation", 9)
	settings_scroll.add_child(settings_column)
	var settings_button := Button.new()
	settings_button.text = "EINSTELLUNGEN"
	settings_button.custom_minimum_size = Vector2(365, 58)
	settings_button.pressed.connect(func(): settings_popup.popup_centered())
	extras_column.add_child(settings_button)
	var settings_back := Button.new()
	settings_back.text = "← ZURÜCK"
	settings_back.custom_minimum_size.y = 58
	settings_back.pressed.connect(func(): settings_popup.hide())
	settings_column.add_child(settings_back)
	for item_control in [teleport_button, walk_button]:
		item_control.reparent(items_column)
		item_control.custom_minimum_size = Vector2(385, 60)
	for setting_control in [touch_button, difficulty_button, count_button, cpu_button, rules_button, terrain_button, sound_button]:
		setting_control.reparent(settings_column)
		setting_control.custom_minimum_size = Vector2(365, 58)
	var secondary_controls: Array[Control] = [
		angle, angle_label, power, power_label, menu_button,
		restart, save_button, load_button
	]
	for control in secondary_controls:
		control.reparent(extras_column)
		control.custom_minimum_size = Vector2(365, 58)
	menu_button.pressed.connect(func(): extras_popup.hide())
	restart.pressed.connect(func(): extras_popup.hide())
	load_button.pressed.connect(func(): extras_popup.hide())
	angle_minus.text = "W−"
	angle_plus.text = "W+"
	power_minus.text = "K−"
	power_plus.text = "K+"

func _apply_ui_theme(root: Control) -> void:
	var theme := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("202944")
	normal.border_color = Color("52668e")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	var hover := normal.duplicate()
	hover.bg_color = Color("35486c")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("14233d")
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("panel", "PanelContainer", normal)
	theme.set_color("font_color", "Button", Color("edf5ff"))
	theme.set_color("font_color", "Label", Color("edf5ff"))
	root.theme = theme

func _build_main_menu(root: Control) -> void:
	var overlay := ColorRect.new()
	overlay.name = "MainMenu"
	overlay.color = Color(0.035, 0.055, 0.13, 0.96)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(470, 0)
	column.add_theme_constant_override("separation", 9)
	center.add_child(column)
	var heading := Label.new()
	heading.text = "SCORCHED ZEBRA"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 37)
	column.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "COMIC ARTILLERIE  •  ZEBRA DUELL"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var world_title := Label.new()
	world_title.text = "WÄHLE DEINE LANDSCHAFT"
	world_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(world_title)
	var world_grid := GridContainer.new()
	world_grid.columns = 3
	world_grid.add_theme_constant_override("h_separation", 6)
	world_grid.add_theme_constant_override("v_separation", 6)
	column.add_child(world_grid)
	var world_ids := [0, 4, 5, 6, 7]
	var world_names := ["🌌 COMIC", "🐸 FROSCH", "🏜 WÜSTE & SCHNEE", "🏝 INSEL", "🌋 VULKAN"]
	for i in range(world_ids.size()):
		var world_button := Button.new()
		world_button.text = world_names[i]
		world_button.toggle_mode = true
		world_button.custom_minimum_size = Vector2(151, 49)
		world_button.pressed.connect(_select_menu_world.bind(world_ids[i]))
		world_grid.add_child(world_button)
		controls["world_button_%d" % world_ids[i]] = world_button
	_update_menu_world_buttons()
	var names_label := Label.new()
	names_label.text = "SPIELERNAMEN (MENSCHEN)"
	names_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(names_label)
	var names_scroll := ScrollContainer.new()
	names_scroll.custom_minimum_size = Vector2(470, 90)
	names_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(names_scroll)
	var names_column := VBoxContainer.new()
	names_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names_scroll.add_child(names_column)
	controls["names_column"] = names_column
	_rebuild_name_inputs()
	var play := Button.new()
	play.text = "SPIEL STARTEN"
	play.custom_minimum_size.y = 58
	play.pressed.connect(_start_from_menu)
	column.add_child(play)
	var resume := Button.new()
	resume.text = "← ZURÜCK ZUM SPIEL"
	resume.custom_minimum_size.y = 45
	resume.pressed.connect(_hide_menu)
	column.add_child(resume)
	var help := Label.new()
	help.text = "Querformat empfohlen. Maus: aufs Spielfeld klicken zum Zielen. Tastatur: ←/→ Winkel, ↑/↓ Kraft, Leertaste FEUER, Tab Waffe.\nSHOP kauft Munition und Schutz. MENÜ pausiert das Spiel."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	var load_menu := Button.new()
	load_menu.text = "GESPEICHERTES SPIEL LADEN"
	load_menu.custom_minimum_size.y = 45
	load_menu.pressed.connect(_load_game)
	column.add_child(load_menu)
	var scoreboard := Label.new()
	scoreboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(scoreboard)
	labels["scoreboard"] = scoreboard
	controls["menu"] = overlay

func _show_menu() -> void:
	menu_open = true
	controls["menu"].visible = true

func _hide_menu() -> void:
	menu_open = false
	controls["menu"].visible = false

func _rebuild_name_inputs() -> void:
	if not controls.has("names_column"):
		return
	var names_column: VBoxContainer = controls["names_column"]
	for child in names_column.get_children():
		child.queue_free()
	for i in range(player_count - cpu_count):
		var field := LineEdit.new()
		field.placeholder_text = "Spieler %d" % (i + 1)
		field.max_length = 20
		field.custom_minimum_size.y = 48
		field.text = custom_player_names[i] if i < custom_player_names.size() else ""
		field.text_changed.connect(_player_name_changed.bind(i))
		names_column.add_child(field)

func _player_name_changed(value: String, index: int) -> void:
	while custom_player_names.size() <= index:
		custom_player_names.append("")
	custom_player_names[index] = value.strip_edges()

func _world_name(world: int) -> String:
	var worlds := [0, 4, 5, 6, 7]
	var names := ["COMIC", "FROSCHWELT", "WÜSTE & SCHNEE", "INSELWELT", "VULKAN"]
	var index := worlds.find(world)
	return names[index] if index >= 0 else "COMIC"

func _update_menu_world_buttons() -> void:
	for world in [0, 4, 5, 6, 7]:
		var key := "world_button_%d" % world
		if controls.has(key):
			var button: Button = controls[key]
			button.button_pressed = world == landscape_index
			button.modulate = Color(1.0, 0.88, 0.45) if world == landscape_index else Color.WHITE

func _select_menu_world(world: int) -> void:
	landscape_index = world
	if controls.has("landscape"):
		controls["landscape"].text = _world_name(world)
	_update_menu_world_buttons()

func _start_from_menu() -> void:
	_new_game()
	_hide_menu()

func _refresh_ui() -> void:
	if labels.is_empty() or players.is_empty():
		return
	var living := 0
	for p in players:
		if p["hp"] > 0:
			living += 1
	labels["p1"].text = "%s  HP:%d  Schild:%d" % [players[current]["name"], players[current]["hp"], players[current]["shield"]]
	labels["p2"].text = "Geld $%d  |  %d aktiv" % [players[current]["money"], living]
	labels["round"].text = "RUNDE %d" % round_number
	labels["wind"].text = "WIND %+.0f" % wind
	labels["status"].text = status
	var p: Dictionary = players[current]
	p["angle"] = clampf(float(p["angle"]), 5.0, 85.0)
	controls["angle"].set_value_no_signal(p["angle"])
	controls["power"].set_value_no_signal(p["power"])
	controls["weapon"].text = "WAFFEN: %s (%s)" % [WEAPONS[int(p["weapon"])], "∞" if int(p["weapon"]) == 0 else str(p["ammo"][int(p["weapon"])])]
	labels["angle"].text = "Winkel %.1f°" % float(p["angle"])
	labels["power"].text = "Kraft %.1f%%" % float(p["power"])
	var enabled := not p["cpu"] and phase == "aim" and not game_over
	for key in ["angle", "power", "angle_minus", "angle_plus", "power_minus", "power_plus", "weapon", "shop", "fire", "direction", "touch_aim", "teleport", "walk"]:
		controls[key].disabled = not enabled
	controls["teleport"].text = "TELEPORT (%d)" % int(p.get("teleports", 0))
	controls["walk"].text = "LAUFEN (%d)" % int(p.get("walks", 0))
	controls["difficulty"].text = "KI: " + ["LEICHT", "NORMAL", "SCHWER"][ai_difficulty]
	controls["direction"].text = "RICHTUNG: " + (">" if shot_direction > 0 else "<")
	controls["count"].text = "%d SPIELER" % player_count
	controls["cpu_count"].text = "%d CPU" % cpu_count
	controls["rules"].text = "REGELN $%d" % starting_cash
	controls["landscape"].text = _world_name(landscape_index)
	labels["scoreboard"].text = "TURNIER (bis %d Siege): %s" % [tournament_target, str(match_wins.slice(0, player_count))]
	_update_weapon_arsenal()

func _toggle_touch_aim() -> void:
	touch_aim_enabled = not touch_aim_enabled
	touch_aim_dragging = false
	controls["touch_aim"].text = "TOUCH: AN" if touch_aim_enabled else "TOUCH: AUS"
	queue_redraw()

func _toggle_direction() -> void:
	if players[current]["cpu"] or phase != "aim":
		return
	shot_direction *= -1.0
	controls["direction"].text = "RICHTUNG: " + (">" if shot_direction > 0 else "<")
	queue_redraw()

func _cycle_difficulty() -> void:
	ai_difficulty = (ai_difficulty + 1) % 3
	controls["difficulty"].text = "KI: " + ["LEICHT", "NORMAL", "SCHWER"][ai_difficulty]

func _cycle_player_count() -> void:
	player_count = 2 if player_count >= 10 else player_count + 1
	cpu_count = mini(cpu_count, player_count - 1)
	_rebuild_name_inputs()
	_new_game()

func _cycle_cpu_count() -> void:
	cpu_count = (cpu_count + 1) % player_count
	_rebuild_name_inputs()
	_new_game()

func _cycle_rules() -> void:
	# Presets are applied on the next new match; don't modify a live match's starting funds.
	var presets := [Vector3(250, 35, 40), Vector3(500, 55, 20), Vector3(150, 20, 75)]
	var index := 0
	for i in range(presets.size()):
		if starting_cash == int(presets[i].x):
			index = (i + 1) % presets.size()
			break
	starting_cash = int(presets[index].x)
	income_per_turn = int(presets[index].y)
	wind_strength = presets[index].z
	_new_game()

func _open_weapon_arsenal() -> void:
	if players.is_empty() or players[current]["cpu"] or phase != "aim" or game_over:
		return
	_update_weapon_arsenal()
	controls["arsenal"].popup_centered()

func _update_weapon_arsenal() -> void:
	if players.is_empty():
		return
	var p: Dictionary = players[current]
	var symbols := ["💣", "💥", "🎇", "🔥", "☢", "🚀", "🌀", "⛰", "☠", "🏀", "🌋", "⚡", "🚀", "✨", "⛏", "💣"]
	for i in range(WEAPONS.size()):
		var tile: Button = controls["weapon_tile_%d" % i]
		var amount: int = int(p["ammo"][i])
		var available := i == 0 or amount > 0
		tile.text = "%s %s\n%s" % [symbols[i], WEAPONS[i], "∞" if i == 0 else str(amount)]
		tile.disabled = not available or p["cpu"] or phase != "aim" or game_over
		tile.modulate = Color(1.0, 0.87, 0.38) if int(p["weapon"]) == i else (Color.WHITE if available else Color(0.46, 0.46, 0.5, 0.65))

func _weapon_selected(idx: int) -> void:
	if players.is_empty() or players[current]["cpu"] or phase != "aim" or game_over:
		return
	if idx != 0 and int(players[current]["ammo"][idx]) <= 0:
		return
	players[current]["weapon"] = idx
	controls["arsenal"].hide()
	_refresh_ui()

func _nudge_aim(setting: String, change: float) -> void:
	if players.is_empty() or phase != "aim" or game_over or players[current]["cpu"]:
		return
	var slider: HSlider = controls[setting]
	slider.value = clampf(slider.value + change, slider.min_value, slider.max_value)

func _angle_changed(value: float) -> void:
	players[current]["angle"] = clampf(value, 5.0, 85.0)
	_refresh_ui()
	queue_redraw()

func _power_changed(value: float) -> void:
	players[current]["power"] = value
	_refresh_ui()
	queue_redraw()

func _select_shop_category(category_name: String) -> void:
	for name in ["WAFFEN", "SCHUTZ", "EXTRAS"]:
		var visible_section: bool = name == category_name
		controls["shop_section_" + name].visible = visible_section
		var tab: Button = controls["shop_tab_" + name]
		tab.modulate = Color(1.0, 0.88, 0.45) if visible_section else Color.WHITE
	for i in range(1, WEAPONS.size()):
		controls["shop_weapon_%d" % i].visible = category_name == "WAFFEN"
	for key in ["shield", "parachute", "armor", "damage_upgrade", "engine"]:
		controls["shop_protection_" + key].visible = category_name == "SCHUTZ"
	for key in ["teleport", "walk"]:
		controls["shop_extra_" + key].visible = category_name == "EXTRAS"
	controls["shop_scroll"].scroll_vertical = 0

func _scroll_shop(distance: int) -> void:
	var scroll: ScrollContainer = controls["shop_scroll"]
	var bar := scroll.get_v_scroll_bar()
	scroll.scroll_vertical = clampi(scroll.scroll_vertical + distance, 0, int(bar.max_value - bar.page))

func _shop_pressed() -> void:
	if players.is_empty():
		return
	labels["shop_money"].text = "Dein Guthaben: $%d" % int(players[current]["money"])
	controls["popup"].popup_centered()

func _shop_buy(action: String) -> void:
	_shop_action(StringName(action))
	if not players.is_empty():
		labels["shop_money"].text = "Dein Guthaben: $%d  |  %s" % [int(players[current]["money"]), status]

func _shop_action(action: StringName) -> void:
	if phase != "aim" or players[current]["cpu"]:
		return
	var p: Dictionary = players[current]
	var command := String(action)
	if command == "teleport" or command == "walk":
		var price: int = 170 if command == "teleport" else 90
		if p["money"] >= price:
			p["money"] -= price
			var item_key: String = "teleports" if command == "teleport" else "walks"
			p[item_key] = int(p.get(item_key, 0)) + 1
			status = "Bewegungs-Item gekauft."
		else:
			status = "Nicht genug Geld."
	elif command == "parachute":
		if p["money"] >= 75:
			p["money"] -= 75
			p["parachutes"] += 1
			status = "Fallschirm gekauft."
		else:
			status = "Nicht genug Geld."
	elif command == "shield":
		if p["money"] >= 100:
			p["money"] -= 100
			p["shield"] = mini(100, p["shield"] + 40)
			status = "Schild verstärkt."
		else:
			status = "Nicht genug Geld."
	elif command in ["armor", "damage_upgrade", "engine"]:
		var cost := {"armor": 160, "damage_upgrade": 200, "engine": 120}[command]
		if p[command] >= 3:
			status = "Upgrade bereits maximal."
		elif p["money"] < cost:
			status = "Nicht genug Geld."
		else:
			p["money"] -= cost
			p[command] += 1
			status = "%s auf Stufe %d verbessert." % [command, p[command]]
	elif command.begins_with("buy_"):
		var idx := int(command.trim_prefix("buy_"))
		if p["money"] >= PRICES[idx]:
			p["money"] -= PRICES[idx]
			p["ammo"][idx] += 1
			status = "%s gekauft." % WEAPONS[idx]
		else:
			status = "Nicht genug Geld."
	_refresh_ui()

func _use_movement_item(kind: String) -> void:
	if phase != "aim" or game_over or players[current]["cpu"]:
		return
	var p: Dictionary = players[current]
	var key: String = "teleports" if kind == "teleport" else "walks"
	if int(p.get(key, 0)) <= 0:
		status = "Erst im SHOP kaufen!"
		_refresh_ui()
		return
	var old_x: float = float(p["x"])
	var distance: float = 360.0 if kind == "teleport" else 175.0
	var new_x: float = clampf(old_x + shot_direction * distance, 55.0, W - 55.0)
	for other in players:
		if other != p and other["hp"] > 0 and absf(float(other["x"]) - new_x) < 65.0:
			status = "Zielplatz besetzt! Richtung wechseln."
			_refresh_ui()
			return
	if absf(new_x - old_x) < 15.0:
		status = "Kein Platz am Spielfeldrand."
		_refresh_ui()
		return
	p["x"] = new_x
	p[key] = int(p[key]) - 1
	p["last_ground"] = terrain.height_at(new_x)
	status = "%s nutzt %s!" % [p["name"], "Teleport" if kind == "teleport" else "5-Zebra-Lauf"]
	_refresh_ui()
	queue_redraw()

func _tank_pos(idx: int) -> Vector2:
	var x: float = players[idx]["x"]
	return Vector2(x, terrain.height_at(x) - 11.0)

func _fire() -> void:
	if phase != "aim" and phase != "ai_wait":
		return
	if game_over:
		return
	var p: Dictionary = players[current]
	var weapon: int = p["weapon"]
	if weapon != 0 and p["ammo"][weapon] <= 0:
		status = "Keine Munition!"
		_refresh_ui()
		return
	if weapon != 0:
		p["ammo"][weapon] -= 1
	var direction := shot_direction
	var angle := deg_to_rad(clampf(float(p["angle"]), 5.0, 85.0))
	var speed := float(p["power"]) * 6.3
	projectile = _tank_pos(current) + Vector2(direction * 19, -17)
	velocity = Vector2(cos(angle) * speed * direction, -sin(angle) * speed)
	projectile_weapon = weapon
	projectile_age = 0.0
	visual_trail.clear()
	visual_muzzle = projectile
	visual_muzzle_time = 0.18
	bounce_count = 0
	shot_owner = current
	projectile_active = true
	_play_weapon_sound(weapon)
	phase = "flying"
	status = "%s schießt %s" % [p["name"], WEAPONS[weapon]]
	_refresh_ui()

func _physics_process(delta: float) -> void:
	visual_clock += delta
	touch_target_timer = maxf(0.0, touch_target_timer - delta)
	visual_muzzle_time = maxf(0.0, visual_muzzle_time - delta)
	if menu_open:
		return
	for i in range(sparks.size() - 1, -1, -1):
		var spark: Dictionary = sparks[i]
		spark["life"] -= delta
		spark["pos"] += spark["vel"] * delta
		spark["vel"] += Vector2(0, 190) * delta
		if spark["life"] <= 0:
			sparks.remove_at(i)
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["time"] -= delta
		if effects[i]["time"] <= 0:
			effects.remove_at(i)
	if projectile_active:
		visual_trail.append(projectile)
		if visual_trail.size() > 22:
			visual_trail.remove_at(0)
		projectile_age += delta
		var steps := 5
		for step in range(steps):
			var dt := delta / steps
			velocity += Vector2(wind * 1.05, GRAVITY) * dt
			projectile += velocity * dt
			if projectile.x < 0 or projectile.x > W or projectile.y > TerrainModel.FLOOR + 50 or projectile_age > 18.0:
				_store_zebra_echo()
				projectile_active = false
				_end_shot()
				break
			if projectile.y >= terrain.height_at(projectile.x) or (projectile_age > 0.08 and _hits_tank(projectile)):
				if projectile_weapon == 9 and bounce_count < 3 and projectile.y >= terrain.height_at(projectile.x):
					bounce_count += 1
					_blast(projectile, 17.0, 13)
					projectile.y = terrain.height_at(projectile.x) - 7.0
					velocity.y = -maxf(110.0, absf(velocity.y) * 0.65)
					velocity.x *= 0.8
					continue
				_store_zebra_echo()
				projectile_active = false
				_explode(projectile, projectile_weapon)
				if queued_bursts.is_empty() and falling.is_empty():
					_end_shot()
				break
	if not queued_bursts.is_empty():
		for i in range(queued_bursts.size() - 1, -1, -1):
			queued_bursts[i]["delay"] -= delta
			if queued_bursts[i]["delay"] <= 0:
				var b: Dictionary = queued_bursts[i]
				queued_bursts.remove_at(i)
				_blast(b["pos"], b["radius"], b["damage"])
		if queued_bursts.is_empty() and falling.is_empty() and not projectile_active and phase == "flying":
			_end_shot()
	if not falling.is_empty():
		for i in range(falling.size() - 1, -1, -1):
			var f: Dictionary = falling[i]
			f["velocity"] += Vector2(wind * 0.45, GRAVITY * 0.75) * delta
			f["pos"] += f["velocity"] * delta
			if f["pos"].x < 0 or f["pos"].x > W or f["pos"].y >= terrain.height_at(f["pos"].x):
				falling.remove_at(i)
				_blast(f["pos"], f["radius"], f["damage"])
		if falling.is_empty() and queued_bursts.is_empty() and not projectile_active and phase == "flying":
			_end_shot()
	if phase == "ai_wait":
		ai_timer -= delta
		if ai_timer <= 0:
			_ai_fire()
	queue_redraw()

func _hits_tank(pos: Vector2) -> bool:
	for i in range(players.size()):
		if players[i]["hp"] > 0 and pos.distance_to(_tank_pos(i)) < 14:
			return true
	return false

func _explode(pos: Vector2, weapon: int) -> void:
	match weapon:
		13: # Shrapnel rain: delayed small impacts across a wide strip
			_blast(pos, 17.0, 13)
			for i in range(15):
				var spread := rng.randf_range(-145.0, 145.0)
				var x := clampf(pos.x + spread, 2.0, W - 2.0)
				queued_bursts.append({"pos": Vector2(x, terrain.height_at(x)), "radius": 17.0, "damage": 14, "delay": 0.12 + float(i) * 0.09})
		14: # Drill: concentrated vertical penetration
			for i in range(9):
				queued_bursts.append({"pos": pos + Vector2(0, float(i) * 19.0), "radius": 14.0, "damage": 13, "delay": 0.08 + float(i) * 0.065})
		15: # Mega dirt: raises a broad protective embankment
			terrain.add_dirt(pos.x, pos.y, 112.0)
			terrain.relax_slopes(pos.x, 135.0, 2)
			effects.append({"pos": pos, "radius": 95.0, "time": 0.65})
			_apply_fall_damage()
		10: # Earthquake: collapse and settle nearby slopes
			terrain.quake(pos.x, 245.0, 30.0)
			_apply_fall_damage()
			effects.append({"pos": pos, "radius": 120.0, "time": 0.5})
		11: # Laser: narrow penetrating line from impact
			for i in range(9):
				_blast(pos + Vector2(0, i * 15.0), 10.0, 11)
		12: # Super MIRV: high-density falling submunitions
			_blast(pos, 24.0, 18)
			for i in range(13):
				falling.append({"pos": pos + Vector2((i - 6) * 6.0, -8), "velocity": Vector2((i - 6) * 53.0, -190.0 - rng.randf_range(0, 100)), "radius": 28.0, "damage": 26})
		5: # MIRV: several independently falling submunitions
			_blast(pos, 18.0, 12)
			for i in range(6):
				falling.append({"pos": pos + Vector2((i - 3) * 9.0, -8), "velocity": Vector2((i - 2.5) * 95.0, -170.0 - rng.randf_range(0, 75)), "radius": 24.0, "damage": 25})
		6: # Roller follows the terrain downhill, detonating repeatedly
			var x := pos.x
			var dir := 1.0 if terrain.height_at(x + 15) > terrain.height_at(x - 15) else -1.0
			for i in range(8):
				x = clampf(x + dir * 22, 1, W - 1)
				queued_bursts.append({"pos": Vector2(x, terrain.height_at(x)), "radius": 19.0, "damage": 15, "delay": 0.1 + i * 0.12, "kind": "blast"})
		7: # Dirt bomb raises terrain rather than carving it
			terrain.add_dirt(pos.x, pos.y, 65.0)
			effects.append({"pos": pos, "radius": 50.0, "time": 0.5})
			_apply_fall_damage()
		8: # Death Head: large area saturation
			_blast(pos, 32.0, 30)
			for i in range(17):
				var offset := Vector2(rng.randf_range(-160, 160), rng.randf_range(-45, 45))
				queued_bursts.append({"pos": pos + offset, "radius": 24.0, "damage": 18, "delay": 0.1 + i * 0.075, "kind": "blast"})
		2:
			_blast(pos, 27, 25)
			for i in range(7):
				var offset := Vector2(rng.randf_range(-85, 85), rng.randf_range(-15, 30))
				queued_bursts.append({"pos": pos + offset, "radius": 23.0, "damage": 18, "delay": 0.12 + i * 0.11})
		3:
			_blast(pos, 20, 18)
			for i in range(11):
				var offset := Vector2(rng.randf_range(-105, 105), 0)
				queued_bursts.append({"pos": pos + offset, "radius": 17.0, "damage": 11, "delay": 0.10 + i * 0.09})
		_:
			_blast(pos, RADII[weapon], int(RADII[weapon] * 0.95))

func _blast(pos: Vector2, radius: float, damage: int) -> void:
	_play_sound("impact")
	# Snapshot tank positions before deforming the terrain, otherwise impact damage
	# changes depending on the crater depth.
	var impact_positions: Array[Vector2] = []
	for tank_index in range(players.size()):
		impact_positions.append(_tank_pos(tank_index))
	terrain.carve(pos.x, pos.y, radius)
	_apply_fall_damage()
	# Volcanic ground erupts when a sufficiently powerful blast hits the central cone.
	if landscape_index == 7 and radius >= 35.0 and absf(pos.x - W * 0.5) < 225.0:
		_volcano_eruption(pos)
	effects.append({"pos": pos, "radius": radius, "time": 0.5})
	for n in range(18):
		var a := rng.randf_range(0, TAU)
		var speed := rng.randf_range(60, 250)
		sparks.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * speed, "life": rng.randf_range(0.25, 0.75), "color": Color("ffcb68") if n % 3 else Color("ff685b")})
	for i in range(players.size()):
		var p: Dictionary = players[i]
		var dist := pos.distance_to(impact_positions[i])
		if dist < radius + 24:
			var amount := maxi(1, int(float(damage) * (1.0 - dist / (radius + 30))))
			amount = maxi(1, int(float(amount) * (1.0 + 0.15 * float(players[shot_owner]["damage_upgrade"]))))
			amount = maxi(1, int(float(amount) * (1.0 - 0.12 * float(p["armor"]))))
			var absorbed := mini(p["shield"], amount)
			p["shield"] -= absorbed
			p["hp"] = maxi(0, p["hp"] - (amount - absorbed))
	_refresh_ui()

func _volcano_eruption(impact: Vector2) -> void:
	# A localized, predictable secondary hazard: visible lava burst near the impact.
	var vent_x: float = clampf(impact.x, 80.0, W - 80.0)
	var vent: Vector2 = Vector2(vent_x, terrain.height_at(vent_x))
	effects.append({"pos": vent, "radius": 54.0, "time": 0.9})
	for n in range(24):
		var angle: float = rng.randf_range(-2.8, -0.35)
		var speed: float = rng.randf_range(90.0, 250.0)
		sparks.append({"pos": vent, "vel": Vector2(cos(angle), sin(angle)) * speed, "life": rng.randf_range(0.45, 1.0), "color": Color("ff592b")})
	for i in range(players.size()):
		var p: Dictionary = players[i]
		if int(p["hp"]) <= 0:
			continue
		var distance: float = absf(float(p["x"]) - vent_x)
		if distance < 78.0:
			var damage: int = maxi(1, int(18.0 * (1.0 - distance / 78.0)))
			var absorbed: int = mini(int(p["shield"]), damage)
			p["shield"] = int(p["shield"]) - absorbed
			p["hp"] = maxi(0, int(p["hp"]) - (damage - absorbed))
	status = "VULKANAUSBRUCH! Treffer am Krater lösen Lava aus!"

func _apply_fall_damage() -> void:
	for i in range(players.size()):
		var p: Dictionary = players[i]
		var ground: float = terrain.height_at(p["x"])
		var previous: float = p.get("last_ground", ground)
		var drop: float = ground - previous
		if drop > 18.0:
			if p["parachutes"] > 0:
				p["parachutes"] -= 1
			else:
				p["hp"] = maxi(0, p["hp"] - int((drop - 18.0) * 0.5))
		p["last_ground"] = ground

func _end_shot() -> void:
	if phase != "flying":
		return
	var alive := 0
	var winner := -1
	for i in range(players.size()):
		if players[i]["hp"] > 0:
			alive += 1
			winner = i
	if alive <= 1:
		game_over = true
		_play_sound("victory")
		phase = "finished"
		matches_played += 1
		if winner >= 0:
			match_wins[winner] += 1
		status = "%s gewinnt! Neues Spiel mit NEU." % players[winner]["name"] if winner >= 0 else "Unentschieden!"
		if winner >= 0 and match_wins[winner] >= tournament_target:
			status = "%s gewinnt das Turnier!" % players[winner]["name"]
		_refresh_ui()
		_save_game(true)
		return
	players[current]["money"] += income_per_turn
	shot_count += 1
	for step in range(1, players.size() + 1):
		var candidate := (current + step) % players.size()
		if players[candidate]["hp"] > 0:
			current = candidate
			break
	if shot_count % player_count == 0:
		round_number += 1
	wind = rng.randf_range(-wind_strength, wind_strength)
	if players[current]["cpu"]:
		phase = "ai_wait"
		ai_timer = 0.85
		status = "%s berechnet einen Schuss ..." % players[current]["name"]
	else:
		phase = "aim"
		status = "%s ist am Zug. +$%d pro Schuss." % [players[current]["name"], income_per_turn]
	_refresh_ui()
	_save_game(true)

func _ai_prepare_defense_and_movement() -> void:
	var p: Dictionary = players[current]
	var nearest: float = INF
	var nearest_x: float = float(p["x"])
	for i in range(players.size()):
		if i == current or players[i]["hp"] <= 0:
			continue
		var distance: float = absf(float(players[i]["x"]) - float(p["x"]))
		if distance < nearest:
			nearest = distance
			nearest_x = float(players[i]["x"])
	# Buy protection when wounded or exposed; do not overspend at low difficulty.
	var danger: bool = int(p["hp"]) < 65 or nearest < 210.0
	if danger and int(p["shield"]) < 45 and int(p["money"]) >= 100:
		p["money"] -= 100
		p["shield"] = mini(100, int(p["shield"]) + 40)
	# Experienced AI occasionally invests in escape items.
	if ai_difficulty >= 1 and int(p.get("walks", 0)) == 0 and int(p["money"]) >= 170 and nearest < 210.0:
		p["money"] -= 90
		p["walks"] = 1
	if ai_difficulty == 2 and int(p.get("teleports", 0)) == 0 and int(p["money"]) >= 310 and int(p["hp"]) < 60:
		p["money"] -= 170
		p["teleports"] = 1
	if not danger:
		return
	var move_kind: String = ""
	var move_distance: float = 0.0
	if int(p.get("teleports", 0)) > 0 and int(p["hp"]) < 45:
		move_kind = "teleports"
		move_distance = 360.0
	elif int(p.get("walks", 0)) > 0 and nearest < 185.0:
		move_kind = "walks"
		move_distance = 175.0
	if move_kind == "":
		return
	var old_x: float = float(p["x"])
	var escape_direction: float = -1.0 if nearest_x > old_x else 1.0
	var new_x: float = clampf(old_x + escape_direction * move_distance, 55.0, W - 55.0)
	if absf(new_x - old_x) < 25.0:
		return
	for other in players:
		if other != p and int(other["hp"]) > 0 and absf(float(other["x"]) - new_x) < 65.0:
			return
	p["x"] = new_x
	p[move_kind] = int(p[move_kind]) - 1
	p["last_ground"] = terrain.height_at(new_x)
	status = "%s weicht mit %s aus!" % [p["name"], "Teleport" if move_kind == "teleports" else "Laufen"]
	queue_redraw()

func _ai_fire() -> void:
	var p: Dictionary = players[current]
	_ai_prepare_defense_and_movement()
	# AI saves for protection and chooses purchasable weapons at higher levels.
	if ai_difficulty >= 1 and p["shield"] < 20 and p["money"] >= 100:
		p["money"] -= 100
		p["shield"] += 40
	if ai_difficulty == 2 and p["money"] >= 200 and p["damage_upgrade"] < 2:
		p["money"] -= 200
		p["damage_upgrade"] += 1
	if ai_difficulty >= 1 and p["money"] >= 125 and p["ammo"][2] == 0:
		p["money"] -= 125
		p["ammo"][2] += 1
	var origin := _tank_pos(current)
	var target_idx := -1
	var target_distance := INF
	for i in range(players.size()):
		if i != current and players[i]["hp"] > 0:
			var d := absf(float(players[i]["x"]) - float(p["x"]))
			if d < target_distance:
				target_distance = d
				target_idx = i
	if target_idx < 0:
		return
	var target := _tank_pos(target_idx)
	var direction := signf(target.x - origin.x)
	shot_direction = direction
	var best_error := INF
	var best_angle := 45.0
	var best_power := 70.0
	for angle in range(18, 78, 3):
		for power in range(35, 101, 3):
			var a := deg_to_rad(float(angle))
			var vel := Vector2(direction * cos(a) * power * 6.3, -sin(a) * power * 6.3)
			var pos := origin + Vector2(direction * 19, -17)
			var closest := INF
			for t in range(210):
				vel += Vector2(wind * 1.05, GRAVITY) * 0.035
				pos += vel * 0.035
				closest = minf(closest, pos.distance_to(target))
				if pos.x < 0 or pos.x > W or pos.y >= terrain.height_at(pos.x):
					break

			if closest < best_error:
				best_error = closest
				best_angle = angle
				best_power = power
	var error: float = [8.0, 3.0, 0.8][ai_difficulty]
	p["angle"] = clampf(best_angle + rng.randf_range(-error, error), 5, 85)
	p["power"] = clampf(best_power + rng.randf_range(-error, error), 15, 100)
	p["weapon"] = 0
	if ai_difficulty >= 1 and p["ammo"][2] > 0 and best_error < 80.0:
		p["weapon"] = 2
	elif p["ammo"][1] > 0 and rng.randf() > 0.55:
		p["weapon"] = 1
	_fire()

func _draw_theme_background() -> void:
	# Five distinct world themes; background shapes never modify collision physics.
	var theme: int = landscape_index
	var sky_top: Color = Color("251050")
	var sky_bottom: Color = Color("ff8a9c")
	var mountains: Array = [Color("a56bc6"), Color("7258b0"), Color("48447f")]
	match theme:
		4:
			sky_top = Color("123d4a")
			sky_bottom = Color("8bd0a2")
			mountains = [Color("4d8370"), Color("32645d"), Color("234e52")]
		5:
			sky_top = Color("5476ac")
			sky_bottom = Color("f8ce9c")
			mountains = [Color("c1ad9d"), Color("a7a4ad"), Color("7b809b")]
		6:
			sky_top = Color("197bba")
			sky_bottom = Color("a5ecf2")
			mountains = [Color("8ac6bb"), Color("579a91"), Color("3b7e80")]
		7:
			sky_top = Color("1c1728")
			sky_bottom = Color("aa4140")
			mountains = [Color("68505a"), Color("493640"), Color("302935")]
	for band in range(22):
		var ratio: float = float(band) / 21.0
		draw_rect(Rect2(0, float(band) * 25.0, W, 26), sky_top.lerp(sky_bottom, ratio))
	# Sun, moon, swamp bubbles and volcanic embers.
	if theme == 0:
		draw_circle(Vector2(1020, 140), 74, Color("df9de6"))
		draw_circle(Vector2(125, 115), 52, Color("9b60cf"))
		for i in range(30):
			var star := Vector2(float((i * 191 + 43) % 1280), float((i * 79 + 19) % 290))
			draw_circle(star, 2, Color("fff3fa", 0.8))
	elif theme == 7:
		draw_circle(Vector2(1030, 125), 56, Color("ff8a4b"))
		for i in range(28):
			var e := Vector2(float((i * 193 + 47) % 1280), float((i * 67 + 33) % 400))
			draw_circle(e, 2.0 + float(i % 3), Color("ff9c5b", 0.65))
	elif theme == 4:
		draw_circle(Vector2(1020, 135), 64, Color("e1ff9e"))
		for i in range(14):
			var b := Vector2(float((i * 137 + 30) % 1280), float((i * 83 + 25) % 340))
			draw_arc(b, 6.0 + float(i % 3) * 4.0, 0, TAU, 24, Color("b8f7cd", 0.5), 2.0)
	else:
		draw_circle(Vector2(1000, 145), 65, Color("ffe4ad"))
	# Layered peaks with faceted shading derived from each mountain's own hue.
	for layer in range(3):
		var base: Color = mountains[layer]
		var points := PackedVector2Array([Vector2(0, 615)])
		for x in range(0, 1281, 20):
			var xf: float = float(x)
			var yy: float = 340.0 + float(layer) * 73.0 + sin(xf * 0.008 + float(layer) * 1.8) * (50.0 + float(layer) * 9.0) + sin(xf * 0.021 + float(layer)) * 19.0
			points.append(Vector2(xf, yy))
		points.append(Vector2(1280, 615))
		draw_colored_polygon(points, base)
		for x in range(0, 1280, 40):
			var lx: float = float(x)
			var rx: float = lx + 40.0
			var ly: float = 340.0 + float(layer) * 73.0 + sin(lx * 0.008 + float(layer) * 1.8) * (50.0 + float(layer) * 9.0) + sin(lx * 0.021 + float(layer)) * 19.0
			var ry: float = 340.0 + float(layer) * 73.0 + sin(rx * 0.008 + float(layer) * 1.8) * (50.0 + float(layer) * 9.0) + sin(rx * 0.021 + float(layer)) * 19.0
			var facet_color: Color = base.darkened(0.24) if ry < ly else base.lightened(0.18)
			draw_colored_polygon(PackedVector2Array([Vector2(lx, ly), Vector2(rx, ry), Vector2(rx + 15, ry + 78), Vector2(lx + 15, ly + 78)]), facet_color)
	# World-specific distant details.
	if theme == 4:
		for i in range(9):
			var cx: float = float(i * 157 + 45)
			draw_line(Vector2(cx, 505), Vector2(cx, 435), Color("28594b"), 7)
			draw_circle(Vector2(cx, 425), 30, Color("427d58"))
			draw_circle(Vector2(cx - 12, 412), 16, Color("72a66a"))
	elif theme == 5:
		for i in range(7):
			var cx: float = float(i * 190 + 15)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 43, 520), Vector2(cx, 440), Vector2(cx + 43, 520)]), Color("f4f8f5", 0.8))
	elif theme == 6:
		draw_rect(Rect2(0, 520, W, 95), Color("288eac", 0.75))
		for i in range(17):
			var x: float = float(i * 83)
			draw_arc(Vector2(x, 535 + float(i % 3) * 15), 22, 0, PI, 16, Color("b7f5f1", 0.5), 2)
	elif theme == 7:
		for i in range(3):
			var cx: float = float(i * 430 + 190)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 110, 525), Vector2(cx, 335), Vector2(cx + 110, 525)]), Color("332b35"))
			draw_line(Vector2(cx - 14, 358), Vector2(cx + 14, 358), Color("ff713c"), 10)
			draw_line(Vector2(cx, 360), Vector2(cx + 28, 450), Color("ed5036"), 7)

func _store_zebra_echo() -> void:
	zebra_echo = visual_trail.duplicate()
	zebra_echo.append(projectile)
	echo_owner = shot_owner

func _draw_zebra_echo() -> void:
	if echo_owner != current or zebra_echo.size() < 2:
		return
	for i in range(0, zebra_echo.size(), 3):
		var point: Vector2 = zebra_echo[i]
		draw_circle(point, 2.3, Color(0.35, 0.88, 1.0, 0.45))

func _draw() -> void:
	_draw_theme_background()
	terrain.draw_terrain(self)
	if touch_target_timer > 0.0:
		var alpha: float = minf(1.0, touch_target_timer)
		draw_arc(touch_target, 19.0, 0.0, TAU, 36, Color(0.3, 1.0, 0.85, alpha), 3.0)
		draw_line(touch_target + Vector2(-26, 0), touch_target + Vector2(26, 0), Color(0.3, 1.0, 0.85, alpha), 2.0)
		draw_line(touch_target + Vector2(0, -26), touch_target + Vector2(0, 26), Color(0.3, 1.0, 0.85, alpha), 2.0)
	for i in range(players.size()):
		_draw_tank(i)
	if phase == "aim" and not game_over and not players[current]["cpu"]:
		_draw_zebra_echo()
		_draw_trajectory()
	for f in falling:
		draw_circle(f["pos"], 4.0, Color("ffb34f"))
	# Smooth fading trails and pulsating projectiles, without changing physics.
	if visual_muzzle_time > 0.0:
		var muzzle_alpha: float = visual_muzzle_time / 0.18
		draw_circle(visual_muzzle, 22.0 * muzzle_alpha, Color(1.0, 0.82, 0.3, muzzle_alpha * 0.5))
		draw_circle(visual_muzzle, 10.0 * muzzle_alpha, Color(1.0, 0.96, 0.75, muzzle_alpha))
	if projectile_active:
		for j in range(0, visual_trail.size(), 2):
			var age: float = float(j + 1) / float(visual_trail.size() + 1)
			var point: Vector2 = visual_trail[j]
			draw_circle(point, 1.5 + 4.0 * age, Color(1.0, 0.47 + 0.35 * age, 0.18, 0.5 * age))
		var pulse: float = 1.0 + 0.12 * sin(visual_clock * 20.0)
		draw_circle(projectile, 12.0 * pulse, Color(1.0, 0.5, 0.12, 0.18))
		draw_circle(projectile, 5.5 * pulse, Color("ffde86"))
		draw_arc(projectile, 8.0 * pulse, 0.0, TAU, 18, Color("ff7a5b"), 2.0)
	for spark in sparks:
		draw_circle(spark["pos"], 2.8, spark["color"] * Color(1, 1, 1, clampf(float(spark["life"]) * 2.0, 0, 1)))
	for effect in effects:
		var fade: float = clampf(effect["time"] / 0.5, 0.0, 1.0)
		draw_circle(effect["pos"], effect["radius"] * (1.3 - fade * 0.3), Color(1.0, 0.49 + fade * 0.35, 0.18, fade * 0.5))

func _draw_tank(i: int) -> void:
	var p: Dictionary = players[i]
	if p["hp"] <= 0:
		return
	var pos: Vector2 = _tank_pos(i)
	var accent: Color = p["color"]
	var facing: float = shot_direction if i == current else (1.0 if i < players.size() / 2.0 else -1.0)
	var ink := Color("171725")
	var white := Color("fff9ee")
	# Four legs and hooves. Only visuals change; original collision and aim stay intact.
	for leg_x in [-18.0, -8.0, 10.0, 20.0]:
		var foot := pos + Vector2(leg_x, -2)
		draw_line(foot + Vector2(0, -25), foot, ink, 11.0, true)
		draw_line(foot + Vector2(0, -25), foot + Vector2(0, -4), white, 7.0, true)
		draw_line(foot + Vector2(-4, -15), foot + Vector2(4, -11), ink, 3.0, true)
		draw_rect(Rect2(foot + Vector2(-6, -4), Vector2(12, 6)), ink)
	# Tail and rounded striped body.
	draw_line(pos + Vector2(-25 * facing, -36), pos + Vector2(-36 * facing, -24), ink, 5.0, true)
	draw_circle(pos + Vector2(-37 * facing, -23), 4.0, ink)
	draw_circle(pos + Vector2(0, -35), 27.0, ink)
	draw_circle(pos + Vector2(0, -35), 24.0, white)
	for stripe in range(5):
		var stripe_x: float = -18.0 + float(stripe) * 9.0
		draw_line(pos + Vector2(stripe_x, -54), pos + Vector2(stripe_x + 5, -39), ink, 4.0, true)
		draw_line(pos + Vector2(stripe_x + 5, -39), pos + Vector2(stripe_x + 2, -29), ink, 2.5, true)
	# Neck, mane and head.
	var neck := pos + Vector2(18 * facing, -59)
	draw_line(pos + Vector2(15 * facing, -38), neck, ink, 19.0, true)
	draw_line(pos + Vector2(15 * facing, -38), neck, white, 14.0, true)
	for spike in range(5):
		var mane_y: float = -66.0 + float(spike) * 8.0
		draw_line(pos + Vector2(8 * facing, mane_y), pos + Vector2(15 * facing, mane_y + 5), ink, 5.0, true)
	var head := pos + Vector2(22 * facing, -73)
	draw_circle(head + Vector2(-9 * facing, -16), 8.0, ink)
	draw_circle(head + Vector2(8 * facing, -17), 8.0, ink)
	draw_circle(head + Vector2(-9 * facing, -16), 5.0, Color("f5b6c6"))
	draw_circle(head + Vector2(8 * facing, -17), 5.0, Color("f5b6c6"))
	draw_circle(head, 20.0, ink)
	draw_circle(head, 17.0, white)
	for stripe in range(3):
		var stripe_y: float = -14.0 + float(stripe) * 8.0
		draw_line(head + Vector2(-11 * facing, stripe_y), head + Vector2(-2 * facing, stripe_y + 4), ink, 3.0, true)
	var muzzle := head + Vector2(17 * facing, 10)
	draw_circle(muzzle, 12.0, ink)
	draw_circle(muzzle, 9.5, Color("bcb1bd"))
	draw_circle(muzzle + Vector2(3 * facing, -2), 2.0, ink)
	draw_circle(head + Vector2(6 * facing, -4), 4.0, ink)
	draw_circle(head + Vector2(7 * facing, -5), 1.4, white)
	# Goggles and accent-color strap distinguish the players.
	draw_line(head + Vector2(-15 * facing, -10), head + Vector2(10 * facing, -12), accent, 3.0, true)
	draw_arc(head + Vector2(5 * facing, -10), 7.0, 0.0, TAU, 24, ink, 4.0)
	draw_arc(head + Vector2(5 * facing, -10), 6.0, 0.0, TAU, 24, accent.lightened(0.35), 3.0)
	# The invisible original cannon still determines the actual shot direction.
	# A small sparkle indicates the aiming point without displaying a tank.
	if p["shield"] > 0:
		draw_arc(pos + Vector2(0, -39), 52.0, PI, TAU, 40, Color("7cecff", 0.75), 3.0)
	var bar := Rect2(pos + Vector2(-27, -111), Vector2(54, 7))
	draw_rect(bar.grow(2), ink)
	draw_rect(bar, Color("68243f"))
	draw_rect(Rect2(bar.position, Vector2(54.0 * float(p["hp"]) / 100.0, 7)), Color("66f43f"))

func _draw_trajectory() -> void:
	# Show only the first half of the predicted flight. Physics remains unchanged.
	var p: Dictionary = players[current]
	var direction: int = shot_direction
	var a: float = deg_to_rad(clampf(float(p["angle"]), 5.0, 85.0))
	var v: Vector2 = Vector2(cos(a) * direction, -sin(a)) * float(p["power"]) * 6.3
	var pos: Vector2 = _tank_pos(current) + Vector2(direction * 19, -17)
	var dt: float = 1.0 / 150.0
	var points: Array[Vector2] = []
	for i in range(900):
		v += Vector2(wind * 1.05, GRAVITY) * dt
		pos += v * dt
		if pos.x < 0.0 or pos.x > W or pos.y > float(TerrainModel.FLOOR) + 50.0:
			break
		if pos.y >= terrain.height_at(pos.x):
			break
		points.append(pos)
	var visible_count: int = maxi(1, int(ceil(float(points.size()) * 0.5)))
	for i in range(0, visible_count, 18):
		draw_circle(points[i], 2.5, Color("ffe081", 0.82))


# Version 0.8: Save only stable turn boundaries to avoid restoring half-resolved explosions.
func _save_game(automatic: bool = false) -> void:
	if phase != "aim" and phase != "ai_wait" and phase != "finished":
		status = "Speichern erst nach dem aktuellen Schuss möglich."
		_refresh_ui()
		return
	var data := {"version": 8, "players": _serialize_players(), "current": current,
		"round": round_number, "wind": wind, "landscape": landscape_index,
		"heights": Array(terrain.heights), "shot_count": shot_count,
		"player_count": player_count, "cpu_count": cpu_count,
		"difficulty": ai_difficulty, "starting_cash": starting_cash,
		"income": income_per_turn, "wind_strength": wind_strength,
		"wins": match_wins, "matches": matches_played,
		"game_over": game_over, "direction": shot_direction}
	var file := FileAccess.open("user://scorchnova_save.json", FileAccess.WRITE)
	if file == null:
		status = "Speichern fehlgeschlagen."
	else:
		file.store_string(JSON.stringify(data))
		file.close()
		if not automatic:
			status = "Spielstand gespeichert."
	if not automatic:
		_refresh_ui()

func _serialize_players() -> Array:
	var result := []
	for p in players:
		var entry: Dictionary = p.duplicate(true)
		entry["color"] = p["color"].to_html()
		result.append(entry)
	return result

func _load_game() -> void:
	if not FileAccess.file_exists("user://scorchnova_save.json"):
		status = "Noch kein Spielstand vorhanden."
		_hide_menu()
		_refresh_ui()
		return
	var file := FileAccess.open("user://scorchnova_save.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or parsed.get("version", 0) != 8:
		status = "Spielstandformat nicht kompatibel."
		_hide_menu()
		_refresh_ui()
		return
	var data: Dictionary = parsed
	if not data.has("heights") or not data.has("players") or not data["heights"] is Array or not data["players"] is Array or data["heights"].size() != TerrainModel.WIDTH + 1:
		status = "Spielstand unvollständig."
		_hide_menu()
		_refresh_ui()
		return
	var restored: Array[Dictionary] = []
	for saved in data["players"]:
		if not saved is Dictionary:
			status = "Spielstand beschädigt."
			_hide_menu()
			_refresh_ui()
			return
		var entry: Dictionary = saved
		if not entry.has("color") or not entry["color"] is String:
			status = "Spielstand beschädigt."
			_hide_menu()
			_refresh_ui()
			return
		entry["color"] = Color.html(entry["color"])
		entry["teleports"] = int(entry.get("teleports", 0))
		entry["walks"] = int(entry.get("walks", 0))
		restored.append(entry)
	players = restored
	if players.size() < 2 or players.size() > 10:
		_new_game()
		return
	for entry in players:
		if not entry.has("ammo") or not entry["ammo"] is Array or entry["ammo"].size() != WEAPONS.size() or not entry.has("x") or not entry.has("hp"):
			status = "Spielstand beschädigt."
			_new_game()
			_hide_menu()
			return
	terrain.heights = PackedFloat32Array(data["heights"])
	current = clampi(int(data["current"]), 0, players.size() - 1)
	round_number = int(data["round"])
	wind = float(data["wind"])
	landscape_index = clampi(int(data["landscape"]), 0, 3)
	shot_count = int(data["shot_count"])
	player_count = players.size()
	cpu_count = clampi(int(data["cpu_count"]), 0, player_count - 1)
	ai_difficulty = clampi(int(data["difficulty"]), 0, 2)
	starting_cash = int(data["starting_cash"])
	income_per_turn = int(data["income"])
	wind_strength = float(data["wind_strength"])
	match_wins.clear()
	for n in data["wins"]:
		match_wins.append(int(n))
	while match_wins.size() < 10:
		match_wins.append(0)
	matches_played = int(data["matches"])
	game_over = bool(data["game_over"])
	shot_direction = float(data["direction"])
	projectile_active = false
	queued_bursts.clear()
	falling.clear()
	effects.clear()
	sparks.clear()
	shop_open = false
	phase = "finished" if game_over else ("ai_wait" if players[current]["cpu"] else "aim")
	ai_timer = 0.85
	status = "Spielstand geladen."
	_hide_menu()
	_refresh_ui()
	queue_redraw()

func _cycle_landscape() -> void:
	var worlds := [0, 4, 5, 6, 7]
	var position := worlds.find(landscape_index)
	landscape_index = worlds[(position + 1) % worlds.size()]
	controls["landscape"].text = _world_name(landscape_index)
	_update_menu_world_buttons()
	_new_game()
