class_name TerrainModel
extends RefCounted

var width: int = 1280
const FLOOR := 615
var heights: PackedFloat32Array = PackedFloat32Array()
var rng := RandomNumberGenerator.new()
var world_style: int = 0
var relief_strength: float = 1.0

func generate_map(landscape: int = 0, map_width: int = 1280) -> void:
	width = map_width
	rng.randomize()
	world_style = landscape
	heights.resize(width + 1)
	var phase := rng.randf_range(0.0, 6.28)
	# Each world has a distinct tactical silhouette, not just a color palette.
	var island_centers := [0.13 * width, 0.36 * width, 0.64 * width, 0.87 * width]
	for x in range(width + 1):
		var fx := float(x)
		var y := 435.0 + sin(fx * 0.008 + phase) * 73.0 + sin(fx * 0.021 + phase * 0.4) * 30.0 + sin(fx * 0.049) * 9.0
		match landscape:
			1: y = 465.0 + sin(fx * 0.006 + phase) * 38.0 + sin(fx * 0.025) * 12.0
			2: y = 450.0 - absf(sin(fx * 0.009 + phase)) * 125.0 + sin(fx * 0.031) * 18.0
			3: y = 455.0 + sin(fx * 0.013 + phase) * 48.0 + sin(fx * 0.045) * 15.0
			4:
				# Swamp: broad low marshes separated by small raised hummocks.
				y = 496.0 + sin(fx * 0.005 + phase) * 13.0 + sin(fx * 0.024) * 7.0
				for mound in [0.18 * width, 0.50 * width, 0.82 * width]:
					y -= 62.0 * exp(-pow((fx - mound) / 83.0, 2.0))
			5:
				# Desert/snow: wide dunes alternating with tall, sharp alpine peaks.
				y = 470.0 + sin(fx * 0.006 + phase) * 22.0
				for peak in [0.27 * width, 0.57 * width, 0.83 * width]:
					y -= 145.0 * maxf(0.0, 1.0 - absf(fx - peak) / 115.0)
			6:
				# Island chain: distinct plateaus separated by deep water-like channels.
				y = 545.0
				for center in island_centers:
					var distance := absf(fx - center)
					var island_shape := clampf((distance - 80.0) / 45.0, 0.0, 1.0)
					var island_y := 415.0 + sin(fx * 0.018 + phase) * 13.0 + island_shape * 130.0
					y = minf(y, island_y)
			7:
				# Volcano: a high central cone, a deep crater and jagged ridges.
				y = 477.0 + sin(fx * 0.014 + phase) * 23.0
				var cone := maxf(0.0, 1.0 - absf(fx - float(width) * 0.5) / 290.0)
				y -= 175.0 * cone
				y += 112.0 * exp(-pow((fx - 650.0) / 58.0, 2.0))
				y -= 55.0 * maxf(0.0, 1.0 - absf(fx - float(width) * 0.20) / 80.0)
				y -= 65.0 * maxf(0.0, 1.0 - absf(fx - float(width) * 0.80) / 95.0)
		# Stronger silhouette: valleys stay low while ridges rise visibly higher.
		var relief: float = 1.35 if landscape != 4 else 1.18
		heights[x] = clampf(460.0 + (y - 460.0) * relief, 245.0, 565.0)
	# Make starting positions stable without erasing the worlds' tactical differences.
	# The 10-player layout uses the same x coordinates as the match spawner.
	for count in range(2, 11):
		for i in range(count):
			var spawn_x := 105.0 + float(width - 210) * float(i) / float(count - 1)
			# Only soften the immediate footing; keep neighboring slopes intact.
			var ground_y := height_at(spawn_x)
			for offset in range(-12, 13):
				var index := clampi(int(spawn_x) + offset, 0, width)
				var influence := 1.0 - absf(float(offset)) / 13.0
				heights[index] = lerpf(heights[index], ground_y, influence * 0.6)

func height_at(x: float) -> float:
	return heights[clampi(int(x), 0, width)]

func carve(cx: float, cy: float, radius: float) -> void:
	var lo := maxi(0, int(cx - radius))
	var hi := mini(width, int(cx + radius))
	for x in range(lo, hi + 1):
		var dx := float(x) - cx
		var depth := sqrt(maxf(0.0, radius * radius - dx * dx))
		heights[x] = minf(float(FLOOR), maxf(heights[x], cy + depth))
	relax_slopes(cx, radius + 8.0, 1)

func add_dirt(cx: float, cy: float, radius: float) -> void:
	var lo := maxi(0, int(cx - radius))
	var hi := mini(width, int(cx + radius))
	for x in range(lo, hi + 1):
		var dx := float(x) - cx
		var mound := sqrt(maxf(0.0, radius * radius - dx * dx)) * 0.85
		heights[x] = maxf(145.0, minf(heights[x], cy - mound))

func draw_terrain(canvas: CanvasItem) -> void:
	# Cartoon terrain uses the existing mutable heightmap. All physics remains untouched.
	var outline := PackedVector2Array()
	outline.append(Vector2(0, FLOOR))
	for x in range(0, width + 1, 20):
		outline.append(Vector2(x, height_at(x)))
	outline.append(Vector2(width, FLOOR))
	var earth: Color = [Color("3c2445"), Color("28463b"), Color("7b543d"), Color("504536"), Color("3b5540"), Color("76563f"), Color("326c6e"), Color("422b35")][clampi(world_style, 0, 7)]
	canvas.draw_colored_polygon(outline, earth)

	# Broad colored soil strata follow the actual destructible surface.
	# Polygon bands are clipped naturally by the same heightmap.
	for band in range(3):
		var offset: float = 20.0 + float(band) * 43.0
		var band_poly := PackedVector2Array()
		for x in range(0, width + 1, 20):
			band_poly.append(Vector2(x, minf(float(FLOOR), height_at(x) + offset)))
		band_poly.append(Vector2(width, FLOOR))
		band_poly.append(Vector2(0, FLOOR))
		var palette: Array = [
			[Color("e88a40"), Color("c36a38"), Color("8f4350")],
			[Color("6d9e57"), Color("477b5b"), Color("304f51")],
			[Color("dfae5d"), Color("b98548"), Color("765c57")],
			[Color("d5c1a1"), Color("b7a7a0"), Color("746d87")],
			[Color("83b36b"), Color("518c68"), Color("315b53")],
			[Color("f2d6a4"), Color("c79c65"), Color("86789c")],
			[Color("c6ad75"), Color("8d875b"), Color("526e63")],
			[Color("ac5947"), Color("753d40"), Color("3b303b")]
		]
		var shade: Color = palette[clampi(world_style, 0, 7)][band]
		canvas.draw_colored_polygon(band_poly, shade)

	# Fine contour highlights and shaded grass lip.
	for x in range(0, width, 20):
		var p := Vector2(x, height_at(x))
		var q := Vector2(x + 20, height_at(x + 20))
		canvas.draw_line(p + Vector2(0, 9), q + Vector2(0, 9), Color("34243d"), 13.0, true)
		canvas.draw_line(p + Vector2(0, 5), q + Vector2(0, 5), Color("356b2a"), 11.0, true)
		canvas.draw_line(p, q, ([Color("85dd2c"), Color("69ba53"), Color("d8bf76"), Color("e9f6fa"), Color("7ad76d"), Color("e3c46d"), Color("77d6a5"), Color("5e4b48")][clampi(world_style, 0, 7)]), 9.0, true)
		canvas.draw_line(p + Vector2(0, -2), q + Vector2(0, -2), ([Color("d7ff65"), Color("b6ec81"), Color("fff0a5"), Color("ffffff"), Color("d2ff9a"), Color("fff0ad"), Color("b7f6db"), Color("f38b54")][clampi(world_style, 0, 7)]), 3.0, true)

	# Deterministic pebbles and small soil texture marks; no random flicker.
	for i in range(65):
		var sx: float = float((i * 173 + 59) % width)
		var sy: float = height_at(sx) + 15.0 + float((i * 37) % 155)
		if sy > FLOOR - 8.0:
			continue
		var stone_radius: float = 1.7 + float(i % 4) * 0.8
		canvas.draw_circle(Vector2(sx, sy), stone_radius, Color("643a49") if i % 3 == 0 else Color("ffb46b"))

	# Small grass tufts attached to the changing terrain silhouette.
	for i in range(30):
		var gx: float = float((i * 109 + 23) % width)
		var gy: float = height_at(gx)
		var tuft: float = 5.0 + float(i % 4) * 2.0
		canvas.draw_line(Vector2(gx, gy), Vector2(gx - 3.0, gy - tuft), Color("a3ed37"), 2.0, true)
		canvas.draw_line(Vector2(gx, gy), Vector2(gx + 2.0, gy - tuft * 1.2), Color("c4fa4d"), 2.0, true)

func quake(cx: float, reach: float, strength: float) -> void:
	var original := heights.duplicate()
	for x in range(maxi(1, int(cx - reach)), mini(width - 1, int(cx + reach))):
		var falloff := 1.0 - absf(float(x) - cx) / reach
		var smooth := (original[x - 1] + original[x] * 2.0 + original[x + 1]) / 4.0
		heights[x] = clampf(lerpf(original[x], smooth + strength * 0.17, falloff), 145.0, FLOOR)

# Bounded relaxation softens near-vertical edges after large terrain changes.
# The heightmap is intentionally kept one-dimensional for mobile performance.
func relax_slopes(cx: float, reach: float, iterations: int = 2) -> void:
	var lo := maxi(1, int(cx - reach))
	var hi := mini(width - 1, int(cx + reach))
	for iteration in range(iterations):
		var old := heights.duplicate()
		for x in range(lo, hi + 1):
			var neighbor := (old[x - 1] + old[x + 1]) * 0.5
			if absf(old[x] - neighbor) > 5.0:
				heights[x] = clampf(lerpf(old[x], neighbor, 0.3), 145.0, float(FLOOR))
