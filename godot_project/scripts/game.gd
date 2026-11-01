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
var sparks: Array[Dictionary] = []
var menu_open := true
var income_per_turn := 35
var wind_strength := 40.0
var starting_cash := 250
var landscape_index := 0
var match_wins: Array[int] = [0, 0, 0, 0, 0, 0]
var matches_played := 0
var tournament_target := 3
var sound_enabled := true
var sound_players: Dictionary = {}
var ui_root: Control

func _ready() -> void:
	rng.randomize()
	for i in range(85):
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

func _toggle_sound() -> void:
	sound_enabled = not sound_enabled
	controls["sound"].text = "TON: AN" if sound_enabled else "TON: AUS"

func _new_game() -> void:
	terrain.generate_map(landscape_index)
	players.clear()
	var colors := [Color("57baff"), Color("ff657d"), Color("f7c85b"), Color("a68bfa"), Color("71e2a3"), Color("ff9b64")]
	for i in range(player_count):
		var is_cpu := i >= player_count - cpu_count
		players.append({"x": 105.0 + 1070.0 * float(i) / float(player_count - 1), "hp": 100, "shield": 0, "money": starting_cash, "armor": 0, "engine": 0, "damage_upgrade": 0, "angle": 48.0, "power": 72.0, "weapon": 0, "ammo": [999, 2, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0], "parachutes": 1, "color": colors[i], "name": ("CPU " if is_cpu else "P") + str(i + 1), "cpu": is_cpu})
	current = 0
	round_number = 1
	game_over = false
	projectile_active = false
	queued_bursts.clear()
	falling.clear()
	effects.clear()
	sparks.clear()
	shop_open = false
	phase = "aim"
	wind = rng.randf_range(-wind_strength, wind_strength)
	for p in players:
		p["last_ground"] = terrain.height_at(p["x"])
	shot_count = 0
	status = "Spieler 1 ist am Zug. Winkel und Kraft einstellen."
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
	top.position = Vector2(14, 12)
	top.size = Vector2(1252, 78)
	root.add_child(top)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 20)
	top.add_child(info)
	for key in ["p1", "round", "wind", "p2"]:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 23)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_child(label)
		labels[key] = label
	var bottom := PanelContainer.new()
	bottom.position = Vector2(12, 618)
	bottom.size = Vector2(1256, 91)
	root.add_child(bottom)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	scroll.add_child(row)
	var weapon := OptionButton.new()
	weapon.custom_minimum_size = Vector2(135, 68)
	for w in WEAPONS:
		weapon.add_item(w)
	weapon.item_selected.connect(_weapon_selected)
	row.add_child(weapon)
	controls["weapon"] = weapon
	var angle := HSlider.new()
	angle.min_value = 5
	angle.max_value = 175
	angle.value = 48
	angle.step = 1
	angle.custom_minimum_size = Vector2(145, 65)
	angle.value_changed.connect(_angle_changed)
	row.add_child(angle)
	controls["angle"] = angle
	var angle_label := Label.new()
	angle_label.custom_minimum_size.x = 95
	row.add_child(angle_label)
	labels["angle"] = angle_label
	var power := HSlider.new()
	power.min_value = 15
	power.max_value = 100
	power.value = 72
	power.step = 1
	power.custom_minimum_size = Vector2(125, 65)
	power.value_changed.connect(_power_changed)
	row.add_child(power)
	controls["power"] = power
	var power_label := Label.new()
	power_label.custom_minimum_size.x = 105
	row.add_child(power_label)
	labels["power"] = power_label
	var shop := Button.new()
	shop.text = "SHOP"
	shop.custom_minimum_size = Vector2(95, 65)
	shop.pressed.connect(_shop_pressed)
	row.add_child(shop)
	controls["shop"] = shop
	var direction_button := Button.new()
	direction_button.text = "RICHTUNG: >"
	direction_button.custom_minimum_size = Vector2(115, 65)
	direction_button.pressed.connect(_toggle_direction)
	row.add_child(direction_button)
	controls["direction"] = direction_button
	var fire := Button.new()
	fire.text = "FEUER!"
	fire.custom_minimum_size = Vector2(120, 65)
	fire.pressed.connect(_fire)
	row.add_child(fire)
	controls["fire"] = fire
	var menu_button := Button.new()
	menu_button.text = "MENÜ"
	menu_button.custom_minimum_size = Vector2(105, 65)
	menu_button.pressed.connect(_show_menu)
	row.add_child(menu_button)
	var restart := Button.new()
	restart.text = "NEU"
	restart.custom_minimum_size = Vector2(85, 65)
	restart.pressed.connect(_new_game)
	row.add_child(restart)
	var difficulty_button := Button.new()
	difficulty_button.text = "KI: NORMAL"
	difficulty_button.custom_minimum_size = Vector2(115, 65)
	difficulty_button.pressed.connect(_cycle_difficulty)
	row.add_child(difficulty_button)
	controls["difficulty"] = difficulty_button
	var count_button := Button.new()
	count_button.text = "2 SPIELER"
	count_button.custom_minimum_size = Vector2(90, 65)
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
	var popup := AcceptDialog.new()
	popup.title = "Waffenladen"
	popup.dialog_text = "Wähle einen Einkauf (nur vor deinem Schuss):"
	popup.size = Vector2i(560, 520)
	root.add_child(popup)
	controls["popup"] = popup
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
	for i in range(1, WEAPONS.size()):
		popup.add_button("%s  $%d" % [WEAPONS[i], PRICES[i]], false, "buy_%d" % i)
	popup.add_button("Schild +40  $100", false, "shield")
	popup.add_button("Fallschirm +1  $75", false, "parachute")
	popup.add_button("Panzerung +1 (max. 3)  $160", false, "armor")
	popup.add_button("Feuerkraft +1 (max. 3)  $200", false, "damage_upgrade")
	popup.add_button("Antrieb +1 (max. 3)  $120", false, "engine")
	popup.custom_action.connect(_shop_action)

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
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var heading := Label.new()
	heading.text = "SCORCH NOVA"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 54)
	column.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "ARTILLERIE  •  TAKTIK  •  ZERSTÖRUNG"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var play := Button.new()
	play.text = "SPIEL STARTEN"
	play.custom_minimum_size.y = 76
	play.pressed.connect(_start_from_menu)
	column.add_child(play)
	var resume := Button.new()
	resume.text = "SPIEL FORTSETZEN"
	resume.custom_minimum_size.y = 65
	resume.pressed.connect(_hide_menu)
	column.add_child(resume)
	var help := Label.new()
	help.text = "Querformat empfohlen. Winkel und Kraft einstellen, Waffe wählen, FEUER drücken.\nSHOP kauft Munition und Schutz. MENÜ pausiert das Spiel."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	var load_menu := Button.new()
	load_menu.text = "GESPEICHERTES SPIEL LADEN"
	load_menu.custom_minimum_size.y = 65
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
	controls["angle"].set_value_no_signal(p["angle"])
	controls["power"].set_value_no_signal(p["power"])
	controls["weapon"].select(p["weapon"])
	labels["angle"].text = "Winkel %d°" % int(p["angle"])
	labels["power"].text = "Kraft %d%%" % int(p["power"])
	var enabled := not p["cpu"] and phase == "aim" and not game_over
	for key in ["angle", "power", "weapon", "shop", "fire", "direction"]:
		controls[key].disabled = not enabled
	controls["difficulty"].text = "KI: " + ["LEICHT", "NORMAL", "SCHWER"][ai_difficulty]
	controls["direction"].text = "RICHTUNG: " + (">" if shot_direction > 0 else "<")
	controls["count"].text = "%d SPIELER" % player_count
	controls["cpu_count"].text = "%d CPU" % cpu_count
	controls["rules"].text = "REGELN $%d" % starting_cash
	controls["landscape"].text = ["HÜGEL", "WÜSTE", "ALPEN", "MOND"][landscape_index]
	labels["scoreboard"].text = "TURNIER (bis %d Siege): %s" % [tournament_target, str(match_wins.slice(0, player_count))]
	for i in range(WEAPONS.size()):
		controls["weapon"].set_item_text(i, "%s (%d)" % [WEAPONS[i], p["ammo"][i]])

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
	player_count = 2 if player_count >= 6 else player_count + 1
	cpu_count = mini(cpu_count, player_count - 1)
	_new_game()

func _cycle_cpu_count() -> void:
	cpu_count = (cpu_count + 1) % player_count
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

func _weapon_selected(idx: int) -> void:
	players[current]["weapon"] = idx
	_refresh_ui()

func _angle_changed(value: float) -> void:
	players[current]["angle"] = value
	_refresh_ui()
	queue_redraw()

func _power_changed(value: float) -> void:
	players[current]["power"] = value
	_refresh_ui()
	queue_redraw()

func _shop_pressed() -> void:
	controls["popup"].popup_centered()

func _shop_action(action: StringName) -> void:
	if phase != "aim" or players[current]["cpu"]:
		return
	var p: Dictionary = players[current]
	var command := String(action)
	if command == "parachute":
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
	if p["ammo"][weapon] <= 0:
		status = "Keine Munition!"
		_refresh_ui()
		return
	if weapon != 0:
		p["ammo"][weapon] -= 1
	var direction := shot_direction
	var angle := deg_to_rad(float(p["angle"]))
	var speed := float(p["power"]) * 6.3
	projectile = _tank_pos(current) + Vector2(direction * 19, -17)
	velocity = Vector2(cos(angle) * speed * direction, -sin(angle) * speed)
	projectile_weapon = weapon
	projectile_age = 0.0
	bounce_count = 0
	shot_owner = current
	projectile_active = true
	_play_sound("fire")
	phase = "flying"
	status = "%s schießt %s" % [p["name"], WEAPONS[weapon]]
	_refresh_ui()

func _physics_process(delta: float) -> void:
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
		projectile_age += delta
		var steps := 5
		for step in range(steps):
			var dt := delta / steps
			velocity += Vector2(wind * 0.45, GRAVITY) * dt
			projectile += velocity * dt
			if projectile.x < 0 or projectile.x > W or projectile.y > TerrainModel.FLOOR + 50 or projectile_age > 18.0:
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
			f["velocity"] += Vector2(wind * 0.2, GRAVITY * 0.75) * delta
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

func _ai_fire() -> void:
	var p: Dictionary = players[current]
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
				vel += Vector2(wind * 0.45, GRAVITY) * 0.035
				pos += vel * 0.035
				closest = minf(closest, pos.distance_to(target))
				if pos.x < 0 or pos.x > W or pos.y >= terrain.height_at(pos.x):
					break

			if closest < best_error:
				best_error = closest
				best_angle = angle
				best_power = power
	var error: float = [8.0, 3.0, 0.8][ai_difficulty]
	p["angle"] = clampf(best_angle + rng.randf_range(-error, error), 5, 175)
	p["power"] = clampf(best_power + rng.randf_range(-error, error), 15, 100)
	p["weapon"] = 0
	if ai_difficulty >= 1 and p["ammo"][2] > 0 and best_error < 80.0:
		p["weapon"] = 2
	elif p["ammo"][1] > 0 and rng.randf() > 0.55:
		p["weapon"] = 1
	_fire()

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("10142c"))
	for s in stars:
		draw_circle(s, 1.4, Color("c9d5f7", 0.7))
	for layer in range(3):
		var poly := PackedVector2Array([Vector2(0, 615)])
		for x in range(0, 1281, 12):
			var y := 310 + layer * 62 + sin(x * 0.007 + layer * 1.5) * 35 + sin(x * 0.019 + layer) * 19
			poly.append(Vector2(x, y))
		poly.append(Vector2(1280, 615))
		draw_colored_polygon(poly, Color("24264e").lerp(Color("3b315c"), layer * 0.25))
	terrain.draw_terrain(self)
	for i in range(players.size()):
		_draw_tank(i)
	if phase == "aim" and not game_over and not players[current]["cpu"]:
		_draw_trajectory()
	for f in falling:
		draw_circle(f["pos"], 4.0, Color("ffb34f"))
	if projectile_active:
		draw_circle(projectile, 5.5, Color("ffde86"))
		draw_arc(projectile, 8, 0, TAU, 12, Color("ff7a5b"), 2)
	for spark in sparks:
		draw_circle(spark["pos"], 2.8, spark["color"] * Color(1, 1, 1, clampf(float(spark["life"]) * 2.0, 0, 1)))
	for effect in effects:
		var fade: float = clampf(effect["time"] / 0.5, 0.0, 1.0)
		draw_circle(effect["pos"], effect["radius"] * (1.3 - fade * 0.3), Color(1.0, 0.49 + fade * 0.35, 0.18, fade * 0.5))

func _draw_tank(i: int) -> void:
	var p: Dictionary = players[i]
	if p["hp"] <= 0:
		return
	var pos := _tank_pos(i)
	var c: Color = p["color"]
	draw_rect(Rect2(pos + Vector2(-24, -1), Vector2(48, 12)), Color("101827"))
	for wheel_x in [-16, -5, 6, 17]:
		draw_circle(pos + Vector2(wheel_x, 7), 4, Color("8190a5"))
	draw_rect(Rect2(pos + Vector2(-22, -1), Vector2(44, 9)), c.darkened(0.38))
	draw_rect(Rect2(pos + Vector2(-17, -12), Vector2(34, 13)), c)
	draw_circle(pos + Vector2(0, -12), 9, c.lightened(0.25))
	var dir := 1.0 if i < players.size() / 2.0 else -1.0
	var a := deg_to_rad(float(p["angle"]))
	var start := pos + Vector2(0, -13)
	draw_line(start, start + Vector2(dir * cos(a), -sin(a)) * 30, c.lightened(0.5), 7)
	if p["shield"] > 0:
		draw_arc(pos + Vector2(0, -6), 31, PI, TAU, 40, Color("7cecff", 0.75), 3)
	var bar := Rect2(pos + Vector2(-23, -43), Vector2(46, 5))
	draw_rect(bar, Color("4d2038"))
	draw_rect(Rect2(bar.position, Vector2(46 * float(p["hp"]) / 100.0, 5)), Color("74e3a4"))

func _draw_trajectory() -> void:
	var p: Dictionary = players[current]
	var direction := shot_direction
	var a := deg_to_rad(float(p["angle"]))
	var v := Vector2(cos(a) * direction, -sin(a)) * float(p["power"]) * 6.3
	var pos := _tank_pos(current) + Vector2(direction * 19, -17)
	for i in range(48):
		v += Vector2(wind * 0.45, GRAVITY) * 0.06
		pos += v * 0.06
		if pos.x < 0 or pos.x > W or pos.y > terrain.height_at(pos.x):
			break
		if i % 3 == 0:
			draw_circle(pos, 2.2, Color("ffffff", 0.75))

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
		restored.append(entry)
	players = restored
	if players.size() < 2 or players.size() > 6:
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
	while match_wins.size() < 6:
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
	landscape_index = (landscape_index + 1) % 4
	_new_game()
