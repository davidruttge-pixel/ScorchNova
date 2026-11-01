class_name TerrainModel
extends RefCounted

const WIDTH := 1280
const FLOOR := 615
var heights: PackedFloat32Array = PackedFloat32Array()
var rng := RandomNumberGenerator.new()

func generate_map(landscape: int = 0) -> void:
	rng.randomize()
	heights.resize(WIDTH + 1)
	var phase := rng.randf_range(0.0, 6.28)
	for x in range(WIDTH + 1):
		var y := 435.0 + sin(x * 0.008 + phase) * 73.0 + sin(x * 0.021 + phase * 0.4) * 30.0 + sin(x * 0.049) * 9.0
		match landscape:
			1: y = 465.0 + sin(x * 0.006 + phase) * 38.0 + sin(x * 0.025) * 12.0
			2: y = 450.0 + absf(sin(x * 0.009 + phase)) * -125.0 + sin(x * 0.031) * 18.0
			3: y = 455.0 + sin(x * 0.013 + phase) * 48.0 + sin(x * 0.045) * 15.0
		heights[x] = clampf(y, 290.0, 540.0)

func height_at(x: float) -> float:
	return heights[clampi(int(x), 0, WIDTH)]

func carve(cx: float, cy: float, radius: float) -> void:
	var lo := maxi(0, int(cx - radius))
	var hi := mini(WIDTH, int(cx + radius))
	for x in range(lo, hi + 1):
		var dx := float(x) - cx
		var depth := sqrt(maxf(0.0, radius * radius - dx * dx))
		heights[x] = minf(float(FLOOR), maxf(heights[x], cy + depth))
	relax_slopes(cx, radius + 8.0, 1)

func add_dirt(cx: float, cy: float, radius: float) -> void:
	var lo := maxi(0, int(cx - radius))
	var hi := mini(WIDTH, int(cx + radius))
	for x in range(lo, hi + 1):
		var dx := float(x) - cx
		var mound := sqrt(maxf(0.0, radius * radius - dx * dx)) * 0.85
		heights[x] = maxf(145.0, minf(heights[x], cy - mound))

func draw_terrain(canvas: CanvasItem) -> void:
	# Cartoon terrain uses the existing mutable heightmap. All physics remains untouched.
	var outline := PackedVector2Array()
	outline.append(Vector2(0, FLOOR))
	for x in range(0, WIDTH + 1, 4):
		outline.append(Vector2(x, height_at(x)))
	outline.append(Vector2(WIDTH, FLOOR))
	canvas.draw_colored_polygon(outline, Color("9d4b2d"))

	# Broad colored soil strata follow the actual destructible surface.
	# Polygon bands are clipped naturally by the same heightmap.
	for band in range(3):
		var offset: float = 20.0 + float(band) * 43.0
		var band_poly := PackedVector2Array()
		for x in range(0, WIDTH + 1, 4):
			band_poly.append(Vector2(x, minf(float(FLOOR), height_at(x) + offset)))
		band_poly.append(Vector2(WIDTH, FLOOR))
		band_poly.append(Vector2(0, FLOOR))
		var shade := Color("c96b30")
		if band == 1:
			shade = Color("a74b2e")
		elif band == 2:
			shade = Color("78334a")
		canvas.draw_colored_polygon(band_poly, shade)

	# Fine contour highlights and shaded grass lip.
	for x in range(0, WIDTH, 4):
		var p := Vector2(x, height_at(x))
		var q := Vector2(x + 4, height_at(x + 4))
		canvas.draw_line(p + Vector2(0, 5), q + Vector2(0, 5), Color("285d29"), 9.0, true)
		canvas.draw_line(p, q, Color("9df12d"), 7.0, true)
		canvas.draw_line(p + Vector2(0, -2), q + Vector2(0, -2), Color("d5ff64"), 2.0, true)

	# Deterministic pebbles and small soil texture marks; no random flicker.
	for i in range(115):
		var sx: float = float((i * 173 + 59) % WIDTH)
		var sy: float = height_at(sx) + 15.0 + float((i * 37) % 155)
		if sy > FLOOR - 8.0:
			continue
		var stone_radius: float = 1.7 + float(i % 4) * 0.8
		canvas.draw_circle(Vector2(sx, sy), stone_radius, Color("663747") if i % 3 == 0 else Color("e58b42"))
		canvas.draw_arc(Vector2(sx - 0.4, sy - 0.5), stone_radius, PI, TAU, 8, Color("f7b45d"), 1.0)

	# Small grass tufts attached to the changing terrain silhouette.
	for i in range(45):
		var gx: float = float((i * 109 + 23) % WIDTH)
		var gy: float = height_at(gx)
		var tuft: float = 5.0 + float(i % 4) * 2.0
		canvas.draw_line(Vector2(gx, gy), Vector2(gx - 3.0, gy - tuft), Color("a3ed37"), 2.0, true)
		canvas.draw_line(Vector2(gx, gy), Vector2(gx + 2.0, gy - tuft * 1.2), Color("c4fa4d"), 2.0, true)

func quake(cx: float, reach: float, strength: float) -> void:
	var original := heights.duplicate()
	for x in range(maxi(1, int(cx - reach)), mini(WIDTH - 1, int(cx + reach))):
		var falloff := 1.0 - absf(float(x) - cx) / reach
		var smooth := (original[x - 1] + original[x] * 2.0 + original[x + 1]) / 4.0
		heights[x] = clampf(lerpf(original[x], smooth + strength * 0.17, falloff), 145.0, FLOOR)

# Bounded relaxation softens near-vertical edges after large terrain changes.
# The heightmap is intentionally kept one-dimensional for mobile performance.
func relax_slopes(cx: float, reach: float, iterations: int = 2) -> void:
	var lo := maxi(1, int(cx - reach))
	var hi := mini(WIDTH - 1, int(cx + reach))
	for iteration in range(iterations):
		var old := heights.duplicate()
		for x in range(lo, hi + 1):
			var neighbor := (old[x - 1] + old[x + 1]) * 0.5
			if absf(old[x] - neighbor) > 5.0:
				heights[x] = clampf(lerpf(old[x], neighbor, 0.3), 145.0, float(FLOOR))
