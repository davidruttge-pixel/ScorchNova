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
    # Visible but transparent sci-fi sky treatment (no opaque gameplay overlay).
    # Stronger than the original barely visible atmospheric pass.
    draw_rect(Rect2(Vector2.ZERO, Vector2(w, h * 0.30)), Color(0.12, 0.06, 0.32, 0.18), true)
    for glow in range(7, 0, -1):
        var rr: float = h * (0.025 + float(glow) * 0.018)
        draw_circle(Vector2(w * 0.80, h * 0.115), rr, Color(0.37, 0.16, 0.88, 0.014))
    # Recognizable alien planet with a glowing ring.
    var planet_center := Vector2(w * 0.80, h * 0.115)
    var planet_radius: float = clampf(h * 0.047, 15.0, 55.0)
    draw_circle(planet_center, planet_radius, Color(0.30, 0.48, 0.89, 0.44))
    draw_circle(planet_center + Vector2(-planet_radius * 0.22, -planet_radius * 0.20), planet_radius * 0.73, Color(0.57, 0.71, 1.0, 0.21))
    draw_arc(planet_center, planet_radius * 1.43, 0.18, PI * 1.82, 64, Color(0.72, 0.47, 1.0, 0.65), 2.4)
    # Layered faraway alien ridges (visual only; no collisions).
    for ridge_index in range(3):
        var ridge_depth: float = float(ridge_index)
        var ridge_points := PackedVector2Array()
        var baseline: float = h * (0.245 + ridge_depth * 0.043)
        ridge_points.append(Vector2(0.0, baseline))
        for ridge_step in range(33):
            var rx: float = w * float(ridge_step) / 32.0
            var wave: float = float(ridge_step) * 0.48 + ridge_depth * 1.7
            var ry: float = baseline - h * (0.022 + ridge_depth * 0.009) * (1.0 + sin(wave) * 0.6 + sin(wave * 2.1) * 0.25)
            ridge_points.append(Vector2(rx, ry))
        ridge_points.append(Vector2(w, baseline))
        var ridge_color := Color(0.27 + ridge_depth * 0.045, 0.16 + ridge_depth * 0.035, 0.58 + ridge_depth * 0.025, 0.16)
        draw_colored_polygon(ridge_points, ridge_color)
        for ridge_step in range(32):
            var ax: float = w * float(ridge_step) / 32.0
            var bx: float = w * float(ridge_step + 1) / 32.0
            var wave_a: float = float(ridge_step) * 0.48 + ridge_depth * 1.7
            var wave_b: float = float(ridge_step + 1) * 0.48 + ridge_depth * 1.7
            var ay: float = baseline - h * (0.022 + ridge_depth * 0.009) * (1.0 + sin(wave_a) * 0.6 + sin(wave_a * 2.1) * 0.25)
            var by: float = baseline - h * (0.022 + ridge_depth * 0.009) * (1.0 + sin(wave_b) * 0.6 + sin(wave_b * 2.1) * 0.25)
            draw_line(Vector2(ax, ay), Vector2(bx, by), Color(0.39, 0.77, 1.0, 0.24), 1.4)
    # Cinematic sci-fi celestial bodies, translucent to preserve game readability.
    var moon_pos := Vector2(w * 0.82, h * 0.105)
    for halo in range(7, 0, -1):
        var hr: float = h * (0.021 + float(halo) * 0.011)
        draw_circle(moon_pos, hr, Color(0.38, 0.30, 0.95, 0.004))
    draw_circle(moon_pos, h * 0.027, Color(0.48, 0.62, 1.0, 0.12))
    draw_arc(moon_pos, h * 0.034, -0.9, 2.6, 38, Color(0.65, 0.75, 1.0, 0.18), 1.4)
    var planet_pos := Vector2(w * 0.18, h * 0.09)
    draw_circle(planet_pos, h * 0.017, Color(0.84, 0.38, 0.78, 0.10))
    draw_arc(planet_pos, h * 0.028, 0.1, 3.0, 34, Color(0.85, 0.45, 0.95, 0.14), 1.5)
    # Diagonal ionized nebula bands: subtle purple/blue atmospheric ribbons.
    for band in range(6):
        var b: float = float(band)
        var yy: float = h * (0.015 + b * 0.024)
        var offset: float = sin(elapsed * 0.08 + b) * 8.0
        draw_line(Vector2(0.0, yy + offset), Vector2(w, yy + h * 0.065 + offset), Color(0.51, 0.24 + b * 0.02, 0.85, 0.018), 7.0)
    # Futuristic distant beacon lights on the skyline.
    for beacon in range(7):
        var n: float = float(beacon)
        var bx: float = w * (n + 0.6) / 7.0
        var by: float = h * (0.17 + fmod(n * 0.023, 0.045))
        var blink: float = 0.5 + 0.5 * sin(elapsed * 1.5 + n * 2.4)
        draw_circle(Vector2(bx, by), 4.0 + blink * 2.0, Color(0.25, 0.8, 1.0, 0.018))
        draw_circle(Vector2(bx, by), 1.2, Color(0.55, 0.95, 1.0, 0.12 + blink * 0.13))
    # High-altitude cloud wisps: transparent, layered and slowly drifting.
    # Drawn only across the top of the viewport to avoid covering gameplay.
    for cloud in range(9):
        var c: float = float(cloud)
        var cx: float = fposmod(c * w * 0.173 + elapsed * (1.0 + fmod(c, 3.0)) * 0.6, w + 160.0) - 80.0
        var cy: float = h * (0.035 + fmod(c * 0.071, 0.14))
        var width_scale: float = 0.7 + fmod(c * 0.37, 0.7)
        for puff in range(5):
            var p: float = float(puff)
            var pos := Vector2(cx + (p - 2.0) * 21.0 * width_scale, cy + sin(p * 1.7 + c) * 5.0)
            var radius: float = (19.0 + 8.0 * sin(p * 0.9 + c)) * width_scale
            draw_circle(pos, radius, Color(0.65, 0.78, 1.0, 0.018))
    # Distant stars and atmospheric specks in the upper sky.
    for star in range(42):
        var n: float = float(star)
        var sx: float = fposmod(n * 197.31 + 29.0, w)
        var sy: float = fposmod(n * 31.67 + 13.0, maxf(h * 0.24, 1.0))
        var shimmer: float = 0.5 + 0.5 * sin(elapsed * 0.55 + n * 2.7)
        draw_circle(Vector2(sx, sy), 0.65 + shimmer * 0.5, Color(0.77, 0.87, 1.0, 0.05 + shimmer * 0.07))
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
    # Snow-tipped distant peaks and fine ridge highlights add depth.
    # All mountain detail remains above 26% of screen height.
    for peak in range(14):
        var p: float = float(peak)
        var x: float = w * (p + 0.25) / 14.0
        var y: float = h * (0.145 + fmod(p * 0.031, 0.075))
        var spread: float = w * (0.026 + fmod(p * 0.011, 0.015))
        var tip := Vector2(x, y - h * (0.022 + fmod(p * 0.009, 0.017)))
        var snow := PackedVector2Array([
            tip,
            Vector2(x - spread * 0.22, y - h * 0.007),
            Vector2(x, y - h * 0.014),
            Vector2(x + spread * 0.24, y - h * 0.003)
        ])
        draw_colored_polygon(snow, Color(0.73, 0.84, 1.0, 0.065))
        draw_line(Vector2(x - spread, y), tip, Color(0.48, 0.66, 0.95, 0.035), 1.0)
        draw_line(tip, Vector2(x + spread, y), Color(0.48, 0.66, 0.95, 0.035), 1.0)
    # Fine atmospheric haze separating sky and distant ridges.
    for haze in range(5):
        var q: float = float(haze)
        var yy: float = h * (0.17 + q * 0.017)
        draw_line(Vector2(0.0, yy), Vector2(w, yy), Color(0.42, 0.62, 0.91, 0.012), 3.0)
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
