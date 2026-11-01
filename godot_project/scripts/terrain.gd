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
	var polygon := PackedVector2Array()
	polygon.append(Vector2(0, FLOOR))
	for x in range(0, WIDTH + 1, 4):
		polygon.append(Vector2(x, height_at(x)))
	polygon.append(Vector2(WIDTH, FLOOR))
	canvas.draw_colored_polygon(polygon, Color("51394e"))
	for x in range(0, WIDTH, 4):
		canvas.draw_line(Vector2(x, height_at(x)), Vector2(x + 4, height_at(x + 4)), Color("61d5a1"), 4.0, true)

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
