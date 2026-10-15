extends Node2D
## Procedural special-effects manager — child "Fx" of Main, created in code.
## Owns the Go/Glow/Grow attack effects (zap / heal / slam), the camera shake,
## and the floating "+nutrient" reward popups. Pure output: it reads no game
## state, so it survives the art phase unchanged.
## Main creates this manager and calls setup(Hero, Camera2D). Change attack and
## popup timings here to tune effects without changing hit/scoring rules.

var _hero: Area2D
var _cam: Camera2D

# Hero effect tweens are single-flight: a new slam/heal kills the previous one
# and re-anchors to _hero_home, so an interrupted lunge can never leave the
# hero permanently displaced from its home spot.
var _hero_home := Vector2.ZERO
var _hero_move_tween: Tween
var _hero_tint_tween: Tween

# Screen-shake state (used by the Grow slam, boss hits, and lost lives).
var _shake_time: float = 0.0
var _shake_dur: float = 0.0
var _shake_strength: float = 0.0

# Wire to the scene's Hero and Camera2D (called right after add_child).
func setup(hero: Area2D, cam: Camera2D) -> void:
	_hero = hero
	_cam = cam
	_hero_home = hero.position

func _process(delta: float) -> void:
	# Camera shake decay.
	if _shake_time > 0.0:
		_shake_time -= delta
		var s := _shake_strength * (_shake_time / _shake_dur)
		_cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
	elif _cam.offset != Vector2.ZERO:
		_cam.offset = Vector2.ZERO

# The attack that matches a food group.
func play_attack(group: String, target: Vector2) -> void:
	match group:
		"Go":
			_zap(_hero.global_position, target)
		"Glow":
			_heal(_hero.global_position)
		"Grow":
			_slam(target)
		_:
			_zap(_hero.global_position, target)

func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_dur = duration
	_shake_time = duration

# Floating "+nutrient" text that rises from the Hero and fades — a small visual
# reward that also teaches what each correct food provides.
func nutrient_popup(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.z_index = 60
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.position = _hero.position + Vector2(randf_range(-40, 0), -80)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 80.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.set_parallel(false)
	tw.tween_callback(lbl.queue_free)

# Go = ZAP: a jagged lightning bolt from the Hero to the enemy.
func _zap(from: Vector2, to: Vector2) -> void:
	Audio.play("zap")
	var line := Line2D.new()
	line.width = 6.0
	line.default_color = Color(1.0, 0.95, 0.30)
	line.z_index = 50
	add_child(line)
	var pts := PackedVector2Array()
	var segments := 8
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var p := from.lerp(to, t)
		if i != 0 and i != segments:
			p += Vector2(randf_range(-18, 18), randf_range(-18, 18))
		pts.append(p)
	line.points = pts
	var tw := create_tween()
	tw.tween_interval(0.06)
	tw.tween_property(line, "modulate:a", 0.0, 0.20)
	tw.tween_callback(line.queue_free)

# Glow = HEAL: a green pulse on the Hero plus an expanding ring.
func _heal(center: Vector2) -> void:
	Audio.play("heal")
	_spawn_ring(center, Color(0.30, 0.95, 0.45))
	if _hero_tint_tween != null and _hero_tint_tween.is_valid():
		_hero_tint_tween.kill()
	_hero.modulate = Color(0.45, 1.0, 0.55)
	_hero_tint_tween = create_tween()
	_hero_tint_tween.tween_property(_hero, "modulate", Color(1, 1, 1, 1), 0.4)

# Grow = SLAM: a heavy impact ring, screen shake, and a Hero lunge.
func _slam(target: Vector2) -> void:
	Audio.play("slam")
	_spawn_ring(target, Color(1.0, 0.55, 0.20))
	shake(9.0, 0.30)
	if _hero_move_tween != null and _hero_move_tween.is_valid():
		_hero_move_tween.kill()
	_hero.position = _hero_home
	var dir := (target - _hero.global_position).normalized()
	_hero_move_tween = create_tween()
	_hero_move_tween.tween_property(_hero, "position", _hero_home + dir * 28.0, 0.06)
	_hero_move_tween.tween_property(_hero, "position", _hero_home, 0.18)

func _spawn_ring(center: Vector2, color: Color) -> void:
	var ring := Line2D.new()
	ring.width = 6.0
	ring.default_color = color
	ring.closed = true
	ring.z_index = 40
	ring.position = center
	var pts := PackedVector2Array()
	var n := 24
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * 30.0)
	ring.points = pts
	add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.4)
	tw.tween_property(ring, "modulate:a", 0.0, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(ring.queue_free)
