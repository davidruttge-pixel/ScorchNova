extends Node2D
# Lightweight canvas effects designed for Godot 4.3 Compatibility/Web.
# No screen-reading shaders, physics changes or input interception.
var elapsed := 0.0

func _process(delta: float) -> void:
    elapsed += minf(delta, 0.1)
    queue_redraw()

func _draw() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    if viewport_size.x < 1.0 or viewport_size.y < 1.0:
        return
    var w: float = viewport_size.x
    var h: float = viewport_size.y
    # Atmospheric light shafts in the upper sky.
    for i in range(5):
        var center_x: float = w * (0.13 + float(i) * 0.19)
        var drift: float = sin(elapsed * 0.16 + float(i) * 1.7) * w * 0.025
        var top_x: float = center_x + drift
        var points := PackedVector2Array([
            Vector2(top_x - w * 0.035, 0.0),
            Vector2(top_x + w * 0.035, 0.0),
            Vector2(top_x + w * 0.17, h * 0.76),
            Vector2(top_x - w * 0.17, h * 0.76)
        ])
        draw_colored_polygon(points, Color(0.19, 0.48, 0.9, 0.012))
    # Three distant parallax silhouettes. Kept in the upper sky so the
    # foreground battlefield, tanks and controls remain unobstructed.
    for depth in range(3):
        var ridge := PackedVector2Array()
        var d: float = float(depth)
        var base_y: float = h * (0.13 + d * 0.045)
        var amplitude: float = h * (0.018 + d * 0.008)
        var speed: float = 0.35 + d * 0.25
        ridge.append(Vector2(0.0, 0.0))
        for k in range(25):
            var px: float = w * float(k) / 24.0
            var phase: float = px / maxf(w, 1.0) * 11.0 + elapsed * 0.012 * speed
            var py: float = base_y + sin(phase + d * 2.1) * amplitude + sin(phase * 2.4) * amplitude * 0.25
            ridge.append(Vector2(px, py))
        ridge.append(Vector2(w, 0.0))
        var tint := Color(0.11 + d * 0.02, 0.19 + d * 0.025, 0.36 + d * 0.035, 0.055 + d * 0.012)
        draw_colored_polygon(ridge, tint)
    # Simulated soft lens glows; no costly post-processing pass.
    for j in range(3):
        var fx: float = w * (0.2 + float(j) * 0.3)
        var fy: float = h * (0.08 + float(j % 2) * 0.07)
        var breathing: float = 0.65 + 0.35 * sin(elapsed * 0.7 + float(j) * 2.0)
        for ring in range(4, 0, -1):
            draw_circle(Vector2(fx, fy), float(ring) * 15.0 * breathing, Color(0.25, 0.55, 1.0, 0.006))
    # Slowly drifting glowing motes, deterministic and cheap.
    for i in range(34):
        var seed: float = float(i)
        var x: float = fposmod(seed * 173.13 + sin(elapsed * 0.31 + seed) * 26.0, w)
        var y: float = fposmod(seed * 91.77 - elapsed * (3.0 + fmod(seed, 5.0)), h)
        var pulse: float = 0.5 + 0.5 * sin(elapsed * 1.3 + seed * 2.7)
        var radius: float = 1.2 + pulse * 1.5
        draw_circle(Vector2(x, y), radius * 3.2, Color(0.22, 0.62, 1.0, 0.015))
        draw_circle(Vector2(x, y), radius, Color(0.54, 0.83, 1.0, 0.12 + pulse * 0.08))
    # Subtle cinematic corner falloff, no opaque panels.
    for i in range(7):
        var f: float = float(i) / 7.0
        var a: float = 0.008 * (1.0 - f)
        var thickness: float = 10.0 + f * 13.0
        draw_rect(Rect2(Vector2(f * 9.0, f * 9.0), Vector2(w - f * 18.0, h - f * 18.0)), Color(0.02, 0.025, 0.09, a), false, thickness)
