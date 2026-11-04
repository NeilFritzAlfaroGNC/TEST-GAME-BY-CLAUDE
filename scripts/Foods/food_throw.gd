
extends Node2D

signal projectile_finished

@export var flight_duration: float = 0.7
@export var arc_height: float = 100.0

var active_food: FoodData = null
var active_hit_area: Area2D = null
var active_damage: int = 0

var start_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var elapsed: float = 0.0

var has_hit: bool = false
var is_flying: bool = false
var is_holding: bool = false

var target_enemy: Node2D = null

var original_parent: Node = null
var original_index: int = -1
var original_global_position: Vector2 = Vector2.ZERO

var effect_settings: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		if child is FoodData:
			child.hide()
			child.remove_from_group("food")

			var template_area := child.find_child(
				"Area2D", true, false
			) as Area2D

			if template_area != null:
				template_area.set_deferred("monitoring", false)
				template_area.set_deferred("monitorable", false)


func prepare_food(food: FoodData, character: Node2D) -> bool:
	if not is_instance_valid(food) or not is_instance_valid(character):
		return false

	var area := food.find_child("Area2D", true, false) as Area2D

	if area == null:
		push_error("[FoodThrow] Original food has no Area2D.")
		return false

	if food.get_parent() == null:
		push_error("[FoodThrow] Original food has no parent.")
		return false

	active_food = food
	active_hit_area = area
	original_parent = food.get_parent()
	original_index = food.get_index()
	original_global_position = food.global_position

	top_level = true
	global_position = original_global_position

	food.reparent(self, true)
	food.set_meta("is_held_for_attack", true)

	if not active_hit_area.area_entered.is_connected(_on_area_entered):
		active_hit_area.area_entered.connect(_on_area_entered)

	if not active_hit_area.body_entered.is_connected(_on_body_entered):
		active_hit_area.body_entered.connect(_on_body_entered)

	is_holding = true
	is_flying = false
	has_hit = false

	active_hit_area.set_deferred("monitoring", false)
	active_hit_area.set_deferred("monitorable", false)

	print("[FoodThrow] Original food held at: ", food.global_position)

	return true


func return_food_to_original_parent() -> void:
	is_holding = false
	is_flying = false

	if not is_instance_valid(active_food):
		return

	if is_instance_valid(original_parent):
		active_food.reparent(original_parent, true)

		if original_index >= 0:
			var last_index: int = maxi(
				0, original_parent.get_child_count() - 1
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

	print("[FoodThrow] Original food returned to its previous position.")


func launch(
	target: Vector2,
	enemy_target: Node2D,
	food_name: String,
	damage: float,
	food_data: FoodData
) -> bool:
	if not is_instance_valid(active_food) or not is_instance_valid(active_hit_area):
		return false

	if not is_instance_valid(enemy_target) or not is_instance_valid(food_data):
		return false

	if active_food.food_name.strip_edges().to_lower() != food_name.strip_edges().to_lower():
		return false

	effect_settings.clear()

	if food_data.enable_freeze:
		effect_settings["enable_freeze"] = true
		effect_settings["freeze_duration"] = food_data.freeze_duration

	if food_data.enable_stun:
		effect_settings["enable_stun"] = true
		effect_settings["stun_duration"] = food_data.stun_duration

	if food_data.enable_burn:
		effect_settings["enable_burn"] = true
		effect_settings["burn_tick_damage"] = food_data.burn_tick_damage
		effect_settings["burn_duration"] = food_data.burn_duration
		effect_settings["burn_tick_count"] = food_data.burn_tick_count
		effect_settings["burn_tick_interval"] = food_data.burn_tick_interval

	if food_data.enable_knockback:
		effect_settings["enable_knockback"] = true
		effect_settings["knockback_strength"] = food_data.knockback_strength

	is_holding = false
	active_damage = roundi(damage)
	start_position = global_position
	target_position = target
	target_enemy = enemy_target
	elapsed = 0.0
	has_hit = false
	is_flying = true

	active_hit_area.set_deferred("monitorable", true)
	active_hit_area.set_deferred("monitoring", true)

	print(
		"[FoodThrow] Launching original food: ",
		food_name,
		" | Damage: ",
		active_damage,
		" | Enabled Effects: ",
		effect_settings
	)

	return true


func _process(delta: float) -> void:
	if is_holding or not is_flying or has_hit:
		return

	if flight_duration <= 0.0:
		global_position = target_position
		_reach_target()
		return

	elapsed += delta

	var progress: float = clampf(elapsed / flight_duration, 0.0, 1.0)

	var horizontal_position: Vector2 = start_position.lerp(
		target_position,
		progress
	)

	var height_offset: float = (
		4.0 * arc_height * progress * (1.0 - progress)
	)

	global_position = horizontal_position - Vector2(0.0, height_offset)

	if progress >= 1.0:
		_reach_target()


func _reach_target() -> void:
	if has_hit:
		return

	if is_instance_valid(target_enemy):
		_hit_enemy(target_enemy)
	else:
		_finish_projectile()


func _on_area_entered(area: Area2D) -> void:
	if not is_flying or has_hit:
		return

	if area.is_in_group("enemy"):
		_hit_enemy(area)
		return

	var parent := area.get_parent()

	if parent != null and parent.is_in_group("enemy"):
		_hit_enemy(parent)


func _on_body_entered(body: Node2D) -> void:
	if not is_flying or has_hit:
		return

	if body.is_in_group("enemy"):
		_hit_enemy(body)


func _apply_glow_effects(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	if effect_settings.get("enable_freeze", false):
		if enemy.has_method("apply_freeze"):
			enemy.apply_freeze(
				float(effect_settings.get("freeze_duration", 0.0))
			)

	if effect_settings.get("enable_stun", false):
		if enemy.has_method("apply_stun"):
			enemy.apply_stun(
				float(effect_settings.get("stun_duration", 0.0))
			)

	if effect_settings.get("enable_burn", false):
		if enemy.has_method("apply_burn"):
			enemy.apply_burn(
				float(effect_settings.get("burn_tick_damage", 0.0)),
				float(effect_settings.get("burn_duration", 0.0)),
				int(effect_settings.get("burn_tick_count", 0)),
				float(effect_settings.get("burn_tick_interval", 0.0))
			)

	if effect_settings.get("enable_knockback", false):
		if enemy.has_method("apply_knockback"):
			var direction: Vector2 = (
				enemy.global_position - global_position
			).normalized()

			if direction == Vector2.ZERO:
				direction = Vector2.RIGHT

			enemy.apply_knockback(
				direction,
				float(effect_settings.get("knockback_strength", 0.0))
			)


func _hit_enemy(enemy: Node) -> void:
	if has_hit:
		return

	has_hit = true
	is_flying = false

	if is_instance_valid(active_hit_area):
		active_hit_area.set_deferred("monitoring", false)
		active_hit_area.set_deferred("monitorable", false)

	if is_instance_valid(enemy):
		if enemy.has_method("take_damage"):
			enemy.take_damage(active_damage)
			print("[FoodThrow] Damage dealt: ", active_damage)
		else:
			push_warning("[FoodThrow] Enemy has no take_damage() method.")

		_apply_glow_effects(enemy)

	if (
		is_instance_valid(active_food)
		and active_food.sprite_frames != null
		and active_food.sprite_frames.has_animation("attack")
	):
		active_food.sprite_frames.set_animation_loop("attack", false)
		active_food.stop()
		active_food.play("attack")
		await active_food.animation_finished

	_finish_projectile()


func _finish_projectile() -> void:
	if not is_inside_tree():
		return

	is_holding = false
	is_flying = false

	projectile_finished.emit()
	queue_free()
