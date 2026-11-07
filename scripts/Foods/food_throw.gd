
extends Node2D

signal projectile_finished

@export_group("Normal Projectile")
@export var flight_duration: float = 0.7
@export var arc_height: float = 100.0

@export_group("Flopping Trajectory")
@export_range(0.0, 100.0, 1.0)
var flop_side_variation: float = 22.0

@export_range(0.0, 3.0, 0.1)
var flop_rotation_amount: float = 0.6


# ==================================================
# FOOD REFERENCES
# ==================================================

var active_food: FoodData = null
var active_hit_area: Area2D = null

var active_damage: int = 0

var original_parent: Node = null
var original_index: int = -1

var original_global_position: Vector2 = Vector2.ZERO
var original_food_scale: Vector2 = Vector2.ONE
var original_food_rotation: float = 0.0

var effect_settings: Dictionary = {}
var grow_effects: Dictionary = {}


# ==================================================
# FLIGHT DATA
# ==================================================

var start_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO

var elapsed: float = 0.0
var segment_duration: float = 0.7
var segment_arc_height: float = 100.0

var target_enemy: Node2D = null

var is_holding: bool = false
var is_flying: bool = false
var is_finishing: bool = false

var grow_size_multiplier: float = 1.0
var grow_knockback_strength: float = 0.0
var grow_stun_duration: float = 0.0


# ==================================================
# FLOPPING
# ==================================================

var flopping_enabled: bool = false

var flop_max_hits: int = 5
var flop_bounce_range: float = 250.0
var flop_bounce_duration: float = 0.3
var flop_bounce_height: float = 65.0
var flop_random_fallback: bool = true

var flop_is_bouncing: bool = false
var flop_random_mode: bool = false
var flop_fallback_used: bool = false

var flop_selecting_target: bool = false
var flop_side_offset: float = 0.0

var hit_enemies: Array[Node] = []


# ==================================================
# READY
# ==================================================

func _ready() -> void:

	for category_name in ["Glow", "Grow", "Go"]:

		var category: Node2D = (
			get_node_or_null(category_name) as Node2D
		)

		if category == null:
			if category_name == "Glow":
				push_error(
					"[FoodThrow] Glow container missing."
				)
			continue

		_setup_food_category(category)

	print(
		"[FoodThrow] Food categories initialized."
	)


func _setup_food_category(
	category: Node2D
) -> void:

	for child in category.get_children():

		if not child is FoodData:
			continue

		child.hide()
		child.remove_from_group("food")

		var area: Area2D = (
			child.find_child("Area2D", true, false) as Area2D
		)

		if area != null:

			area.set_deferred("monitoring", false)
			area.set_deferred("monitorable", false)


# ==================================================
# RECEIVE GROW MODIFIERS
# ==================================================

func set_grow_effects(
	effects: Dictionary
) -> void:

	grow_effects = effects.duplicate(true)

	grow_size_multiplier = maxf(
		float(effects.get("size_multiplier", 1.0)),
		1.0
	)

	grow_knockback_strength = maxf(
		float(effects.get("knockback_strength", 0.0)),
		0.0
	)

	grow_stun_duration = maxf(
		float(effects.get("stun_duration", 0.0)),
		0.0
	)

	var flop: Dictionary = effects.get("flopping", {})

	flopping_enabled = bool(
		flop.get("enabled", false)
	)

	# No 5-hit cap. Combined Fish can have
	# 10, 15 or 20 total unique hits.
	flop_max_hits = maxi(
		int(flop.get("max_hits", 5)),
		1
	)

	flop_bounce_range = maxf(
		float(flop.get("bounce_range", 250.0)),
		10.0
	)

	flop_bounce_duration = maxf(
		float(flop.get("bounce_duration", 0.3)),
		0.05
	)

	flop_bounce_height = maxf(
		float(flop.get("bounce_height", 65.0)),
		0.0
	)

	flop_random_fallback = bool(
		flop.get("random_fallback", true)
	)

	print(
		"[GROW] Flopping: ",
		flopping_enabled,
		" | Maximum unique hits: ",
		flop_max_hits
	)


# ==================================================
# PREPARE ORIGINAL FOOD
# ==================================================

func prepare_food(
	food: FoodData,
	character: Node2D
) -> bool:

	if not is_instance_valid(food):
		return false

	if not is_instance_valid(character):
		return false

	var area: Area2D = (
		food.find_child("Area2D", true, false) as Area2D
	)

	if area == null:
		push_error(
			"[FoodThrow] Original food has no Area2D."
		)
		return false

	if food.get_parent() == null:
		return false

	active_food = food
	active_hit_area = area

	original_parent = food.get_parent()
	original_index = food.get_index()

	original_global_position = food.global_position
	original_food_scale = food.scale
	original_food_rotation = food.rotation

	top_level = true
	global_position = original_global_position

	food.reparent(self, true)
	food.set_meta("is_held_for_attack", true)

	if not active_hit_area.area_entered.is_connected(
		_on_area_entered
	):
		active_hit_area.area_entered.connect(
			_on_area_entered
		)

	if not active_hit_area.body_entered.is_connected(
		_on_body_entered
	):
		active_hit_area.body_entered.connect(
			_on_body_entered
		)

	is_holding = true
	is_flying = false
	is_finishing = false

	flop_is_bouncing = false
	flop_random_mode = false
	flop_fallback_used = false
	flop_selecting_target = false

	hit_enemies.clear()

	active_hit_area.set_deferred("monitoring", false)
	active_hit_area.set_deferred("monitorable", false)

	return true


# ==================================================
# RETURN FOOD ON FAILED ATTACK
# ==================================================

func return_food_to_original_parent() -> void:

	is_holding = false
	is_flying = false
	is_finishing = true

	if not is_instance_valid(active_food):
		return

	active_food.scale = original_food_scale
	active_food.rotation = original_food_rotation
	active_food.show()

	if is_instance_valid(original_parent):

		active_food.reparent(original_parent, true)

		if original_index >= 0:

			var last_index: int = maxi(
				0,
				original_parent.get_child_count() - 1
			)

			original_parent.move_child(
				active_food,
				mini(original_index, last_index)
			)

	active_food.global_position = original_global_position
	active_food.set_meta("is_held_for_attack", false)

	if is_instance_valid(active_hit_area):

		active_hit_area.set_deferred("monitoring", true)
		active_hit_area.set_deferred("monitorable", true)


# ==================================================
# LAUNCH
# ==================================================

func launch(
	target: Vector2,
	enemy_target: Node2D,
	food_name: String,
	damage: float,
	food_data: FoodData
) -> bool:

	if not is_instance_valid(active_food):
		return false

	if not is_instance_valid(active_hit_area):
		return false

	if not is_instance_valid(enemy_target):
		return false

	if not is_instance_valid(food_data):
		return false

	if (
		active_food.food_name.strip_edges().to_lower()
		!= food_name.strip_edges().to_lower()
	):
		return false

	# ----------------------------------------------
	# ORIGINAL GLOW EFFECTS
	# ----------------------------------------------

	effect_settings.clear()

	if food_data.enable_freeze:
		effect_settings["enable_freeze"] = true
		effect_settings["freeze_duration"] = (
			food_data.freeze_duration
		)

	if food_data.enable_stun:
		effect_settings["enable_stun"] = true
		effect_settings["stun_duration"] = (
			food_data.stun_duration
		)

	if food_data.enable_burn:
		effect_settings["enable_burn"] = true
		effect_settings["burn_tick_damage"] = (
			food_data.burn_tick_damage
		)
		effect_settings["burn_duration"] = (
			food_data.burn_duration
		)
		effect_settings["burn_tick_count"] = (
			food_data.burn_tick_count
		)
		effect_settings["burn_tick_interval"] = (
			food_data.burn_tick_interval
		)

	if food_data.enable_knockback:
		effect_settings["enable_knockback"] = true
		effect_settings["knockback_strength"] = (
			food_data.knockback_strength
		)

	# ----------------------------------------------
	# GROW KNOCKBACK
	# ----------------------------------------------

	if grow_knockback_strength > 0.0:

		var original_knockback: float = float(
			effect_settings.get("knockback_strength", 0.0)
		)

		effect_settings["enable_knockback"] = true
		effect_settings["knockback_strength"] = (
			original_knockback + grow_knockback_strength
		)

	# ----------------------------------------------
	# GROW STUN
	# ----------------------------------------------

	if grow_stun_duration > 0.0:

		var original_stun: float = float(
			effect_settings.get("stun_duration", 0.0)
		)

		effect_settings["enable_stun"] = true
		effect_settings["stun_duration"] = (
			original_stun + grow_stun_duration
		)

	# ----------------------------------------------
	# ENLARGE
	# ----------------------------------------------

	active_food.scale = (
		original_food_scale * grow_size_multiplier
	)

	# ----------------------------------------------
	# INITIALIZE FLIGHT
	# ----------------------------------------------

	active_damage = roundi(damage)

	start_position = global_position
	target_position = target
	target_enemy = enemy_target

	elapsed = 0.0
	segment_duration = flight_duration
	segment_arc_height = arc_height

	is_holding = false
	is_flying = true
	is_finishing = false

	flop_is_bouncing = false
	flop_random_mode = false
	flop_fallback_used = false
	flop_selecting_target = false

	hit_enemies.clear()

	active_hit_area.set_deferred("monitorable", true)
	active_hit_area.set_deferred("monitoring", true)

	print(
		"[FoodThrow] Launched: ",
		food_name,
		" | Damage: ",
		active_damage,
		" | Size: ",
		grow_size_multiplier,
		" | Flopping: ",
		flopping_enabled
	)

	return true


# ==================================================
# FLIGHT
# ==================================================

func _process(delta: float) -> void:

	if is_holding or not is_flying or is_finishing:
		return

	if flop_selecting_target:
		return

	elapsed += delta

	if segment_duration <= 0.0:
		global_position = target_position
		_reach_target()
		return

	var progress: float = clampf(
		elapsed / segment_duration,
		0.0,
		1.0
	)

	var line_position: Vector2 = start_position.lerp(
		target_position,
		progress
	)

	var height_offset: float = (
		4.0 * segment_arc_height
		* progress * (1.0 - progress)
	)

	global_position = (
		line_position - Vector2(0.0, height_offset)
	)

	if flop_is_bouncing:

		var direction: Vector2 = (
			target_position - start_position
		).normalized()

		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT

		var perpendicular: Vector2 = Vector2(
			-direction.y,
			direction.x
		)

		global_position += (
			perpendicular
			* sin(progress * PI)
			* flop_side_offset
		)

		if is_instance_valid(active_food):
			active_food.rotation = (
				original_food_rotation
				+ sin(progress * TAU * 2.0)
				* flop_rotation_amount
			)

	if progress >= 1.0:
		_reach_target()


# ==================================================
# TARGET REACHED
# ==================================================

func _reach_target() -> void:

	if is_finishing:
		return

	if flop_random_mode:
		print("[GROW FLOP] Final random bounce finished.")
		_complete_flight()
		return

	if is_instance_valid(target_enemy):
		if not hit_enemies.has(target_enemy):
			_hit_enemy(target_enemy)
			return

	if flopping_enabled:
		_request_next_flop()
	else:
		_complete_flight()


# ==================================================
# COLLISION SIGNALS
# ==================================================

func _on_area_entered(area: Area2D) -> void:

	if not is_flying or is_finishing:
		return

	if flop_selecting_target or flop_random_mode:
		return

	var enemy: Node = _resolve_enemy(area)

	if enemy != null:
		_hit_enemy(enemy)


func _on_body_entered(body: Node2D) -> void:

	if not is_flying or is_finishing:
		return

	if flop_selecting_target or flop_random_mode:
		return

	var enemy: Node = _resolve_enemy(body)

	if enemy != null:
		_hit_enemy(enemy)


func _resolve_enemy(node: Node) -> Node:

	var current: Node = node

	while current != null:

		if current.is_in_group("enemy"):
			return current

		current = current.get_parent()

	return null


# ==================================================
# DAMAGE AN ENEMY ONCE
# ==================================================

func _hit_enemy(enemy: Node) -> void:

	if not is_flying or is_finishing:
		return

	if flop_selecting_target or flop_random_mode:
		return

	if not is_instance_valid(enemy):
		return

	if hit_enemies.has(enemy):
		return

	hit_enemies.append(enemy)

	_apply_glow_effects(enemy)

	if is_instance_valid(enemy):

		if enemy.has_method("take_damage"):

			enemy.take_damage(active_damage)

			print(
				"[FoodThrow] Damage dealt: ",
				active_damage
			)

	# ----------------------------------------------
	# FLOPPING
	# ----------------------------------------------

	if flopping_enabled:

		print(
			"[GROW FLOP] Unique hits: ",
			hit_enemies.size(),
			"/",
			flop_max_hits
		)

		if hit_enemies.size() >= flop_max_hits:
			_complete_flight()
			return

		_request_next_flop()
		return

	# ----------------------------------------------
	# ENLARGE
	# ----------------------------------------------

	if grow_size_multiplier > 1.0:
		return

	_complete_flight()


# ==================================================
# REQUEST NEXT FLOP
# ==================================================

func _request_next_flop() -> void:

	if not flopping_enabled or is_finishing:
		return

	if flop_selecting_target:
		return

	if hit_enemies.size() >= flop_max_hits:
		_complete_flight()
		return

	flop_selecting_target = true

	call_deferred("_choose_next_flop")


# ==================================================
# FIND NEXT UNHIT ENEMY
# ==================================================

func _choose_next_flop() -> void:

	if not is_inside_tree() or is_finishing:
		return

	var candidates: Array[Node2D] = []

	for enemy in get_tree().get_nodes_in_group("enemy"):

		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		if hit_enemies.has(enemy):
			continue

		var enemy_node: Node2D = enemy as Node2D

		if not enemy_node.is_inside_tree():
			continue

		if enemy_node.is_queued_for_deletion():
			continue

		var distance: float = global_position.distance_to(
			enemy_node.global_position
		)

		if distance <= flop_bounce_range:
			candidates.append(enemy_node)

	flop_selecting_target = false

	if not candidates.is_empty():

		var random_index: int = randi_range(
			0,
			candidates.size() - 1
		)

		var next_enemy: Node2D = (
			candidates[random_index]
		)

		_start_flop_segment(
			next_enemy.global_position,
			next_enemy,
			false
		)

		print(
			"[GROW FLOP] Bouncing toward: ",
			next_enemy.name
		)

		return

	if flop_random_fallback and not flop_fallback_used:
		_start_random_flop()
	else:
		_complete_flight()


# ==================================================
# START NEXT FLOP SEGMENT
# ==================================================

func _start_flop_segment(
	destination: Vector2,
	next_enemy: Node2D,
	random_bounce: bool
) -> void:

	start_position = global_position
	target_position = destination

	target_enemy = next_enemy

	elapsed = 0.0

	segment_duration = flop_bounce_duration
	segment_arc_height = (
		flop_bounce_height
		* randf_range(0.75, 1.25)
	)

	flop_side_offset = randf_range(
		-flop_side_variation,
		flop_side_variation
	)

	flop_is_bouncing = true
	flop_random_mode = random_bounce

	is_flying = true


# ==================================================
# ONE RANDOM FINAL BOUNCE
# ==================================================

func _start_random_flop() -> void:

	if flop_fallback_used:
		_complete_flight()
		return

	flop_fallback_used = true

	var angle: float = randf_range(0.0, TAU)

	var max_distance: float = maxf(
		60.0,
		minf(flop_bounce_range, 150.0)
	)

	var distance: float = randf_range(
		60.0,
		max_distance
	)

	var direction: Vector2 = Vector2(
		cos(angle),
		sin(angle)
	)

	var destination: Vector2 = (
		global_position + direction * distance
	)

	if is_instance_valid(active_hit_area):
		active_hit_area.set_deferred(
			"monitoring",
			false
		)

	_start_flop_segment(
		destination,
		null,
		true
	)

	print(
		"[GROW FLOP] No further enemy. ",
		"One final random bounce."
	)


# ==================================================
# APPLY GLOW STATUS EFFECTS
# ==================================================

func _apply_glow_effects(enemy: Node) -> void:

	if not is_instance_valid(enemy):
		return

	if effect_settings.get("enable_freeze", false):
		if enemy.has_method("apply_freeze"):
			enemy.apply_freeze(
				float(
					effect_settings.get(
						"freeze_duration",
						0.0
					)
				)
			)

	if effect_settings.get("enable_stun", false):
		if enemy.has_method("apply_stun"):
			enemy.apply_stun(
				float(
					effect_settings.get(
						"stun_duration",
						0.0
					)
				)
			)

	if effect_settings.get("enable_burn", false):
		if enemy.has_method("apply_burn"):
			enemy.apply_burn(
				float(
					effect_settings.get(
						"burn_tick_damage",
						0.0
					)
				),
				float(
					effect_settings.get(
						"burn_duration",
						0.0
					)
				),
				int(
					effect_settings.get(
						"burn_tick_count",
						0
					)
				),
				float(
					effect_settings.get(
						"burn_tick_interval",
						0.0
					)
				)
			)

	if effect_settings.get("enable_knockback", false):
		if enemy.has_method("apply_knockback"):

			var direction: Vector2 = Vector2.RIGHT

			if enemy is Node2D:

				var enemy_node: Node2D = enemy as Node2D

				direction = (
					enemy_node.global_position
					- global_position
				).normalized()

			if direction == Vector2.ZERO:
				direction = Vector2.RIGHT

			enemy.apply_knockback(
				direction,
				float(
					effect_settings.get(
						"knockback_strength",
						0.0
					)
				)
			)


# ==================================================
# COMPLETE FLIGHT
# ==================================================

func _complete_flight() -> void:

	if is_finishing:
		return

	is_finishing = true
	is_flying = false
	flop_selecting_target = false

	if is_instance_valid(active_hit_area):
		active_hit_area.set_deferred("monitoring", false)
		active_hit_area.set_deferred("monitorable", false)

	if (
		not hit_enemies.is_empty()
		and is_instance_valid(active_food)
		and active_food.sprite_frames != null
		and active_food.sprite_frames.has_animation("attack")
	):
		_play_hit_animation_and_finish()
	else:
		_finish_projectile()


# ==================================================
# IMPACT ANIMATION
# ==================================================

func _play_hit_animation_and_finish() -> void:

	if not is_instance_valid(active_food):
		_finish_projectile()
		return

	active_food.rotation = original_food_rotation

	active_food.sprite_frames.set_animation_loop(
		"attack",
		false
	)

	active_food.stop()
	active_food.play("attack")

	await active_food.animation_finished

	_finish_projectile()


# ==================================================
# CLEANUP
# ==================================================

func _finish_projectile() -> void:

	if not is_inside_tree():
		return

	is_holding = false
	is_flying = false
	is_finishing = true

	projectile_finished.emit()
	queue_free()
