
extends Node2D

signal projectile_finished

@export var flight_duration: float = 0.7
@export var arc_height: float = 100.0

@export_group("Food Damage")
@export_range(0, 999, 1) var apple_damage: int = 10
@export_range(0, 999, 1) var banana_damage: int = 10
@export_range(0, 999, 1) var bean_damage: int = 5
@export_range(0, 999, 1) var bread_damage: int = 15
@export_range(0, 999, 1) var carrot_damage: int = 10
@export_range(0, 999, 1) var chicken_damage: int = 20
@export_range(0, 999, 1) var corn_damage: int = 10
@export_range(0, 999, 1) var egg_damage: int = 15
@export_range(0, 999, 1) var fish_damage: int = 20
@export_range(0, 999, 1) var mango_damage: int = 10
@export_range(0, 999, 1) var milk_damage: int = 5
@export_range(0, 999, 1) var oats_damage: int = 5
@export_range(0, 999, 1) var papaya_damage: int = 15
@export_range(0, 999, 1) var potato_damage: int = 20
@export_range(0, 999, 1) var rice_damage: int = 5

var food_sprites: Dictionary = {}
var food_areas: Dictionary = {}
var food_damages: Dictionary = {}

var active_food: AnimatedSprite2D = null
var active_hit_area: Area2D = null
var active_damage: int = 0

var start_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var elapsed: float = 0.0

var has_hit: bool = false
var is_flying: bool = false
var target_enemy: Node2D = null


func _ready() -> void:
	food_damages = {
		"apple": apple_damage,
		"banana": banana_damage,
		"bean": bean_damage,
		"bread": bread_damage,
		"carrot": carrot_damage,
		"chicken": chicken_damage,
		"corn": corn_damage,
		"egg": egg_damage,
		"fish": fish_damage,
		"mango": mango_damage,
		"milk": milk_damage,
		"oats": oats_damage,
		"papaya": papaya_damage,
		"potato": potato_damage,
		"rice": rice_damage
	}

	# Register only food nodes that actually exist.
	for food_name in food_damages.keys():
		var food := get_node_or_null(NodePath(food_name))

		if food == null:
			# Missing future food is expected; skip it silently.
			continue

		if not food is AnimatedSprite2D:
			push_warning(
				"[FoodThrow] Skipping " + food_name
				+ ": node must be an AnimatedSprite2D."
			)
			continue

		var food_sprite := food as AnimatedSprite2D
		var area := food_sprite.get_node_or_null("Area2D") as Area2D

		if area == null:
			push_warning(
				"[FoodThrow] Skipping " + food_name
				+ ": Area2D is missing."
			)
			continue

		food_sprites[food_name] = food_sprite
		food_areas[food_name] = area

		food_sprite.hide()
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)

		if not area.area_entered.is_connected(_on_area_entered):
			area.area_entered.connect(_on_area_entered)

		if not area.body_entered.is_connected(_on_body_entered):
			area.body_entered.connect(_on_body_entered)


func has_food(food_name: String) -> bool:
	return food_sprites.has(food_name.strip_edges().to_lower())


func launch(
	target: Vector2,
	enemy_target: Node2D = null,
	food_name: String = "mango"
) -> void:
	if not is_node_ready():
		await ready

	food_name = food_name.strip_edges().to_lower()

	if not food_sprites.has(food_name):
		push_warning(
			"[FoodThrow] Cannot launch '" + food_name
			+ "': its node is not configured in FoodThrow.tscn."
		)
		projectile_finished.emit()
		queue_free()
		return

	active_food = food_sprites[food_name] as AnimatedSprite2D
	active_hit_area = food_areas[food_name] as Area2D
	active_damage = int(food_damages[food_name])

	start_position = global_position
	target_position = target
	target_enemy = enemy_target
	elapsed = 0.0
	has_hit = false
	is_flying = true

	# Hide and disable every other food.
	for key in food_sprites.keys():
		var sprite := food_sprites[key] as AnimatedSprite2D
		var area := food_areas[key] as Area2D

		sprite.hide()
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)

	active_food.show()
	active_hit_area.set_deferred("monitorable", true)
	active_hit_area.set_deferred("monitoring", true)


func _process(delta: float) -> void:
	if not is_flying or has_hit:
		return

	if flight_duration <= 0.0:
		global_position = target_position
		_reach_target()
		return

	elapsed += delta

	var progress: float = clampf(
		elapsed / flight_duration,
		0.0,
		1.0
	)

	var horizontal_position: Vector2 = start_position.lerp(
		target_position,
		progress
	)

	var height_offset: float = (
		4.0 * arc_height * progress * (1.0 - progress)
	)

	global_position = (
		horizontal_position - Vector2(0.0, height_offset)
	)

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
	if has_hit or active_hit_area == null:
		return

	if area.is_in_group("enemy"):
		_hit_enemy(area)
	elif area.get_parent() != null:
		if area.get_parent().is_in_group("enemy"):
			_hit_enemy(area.get_parent())


func _on_body_entered(body: Node2D) -> void:
	if has_hit:
		return

	if body.is_in_group("enemy"):
		_hit_enemy(body)


func _hit_enemy(enemy: Node) -> void:
	if has_hit:
		return

	has_hit = true
	is_flying = false

	if is_instance_valid(active_hit_area):
		active_hit_area.set_deferred("monitoring", false)
		active_hit_area.set_deferred("monitorable", false)

	if active_damage > 0 and enemy.has_method("take_damage"):
		enemy.take_damage(active_damage)
	elif active_damage > 0:
		push_warning(
			"[FoodThrow] Target has no take_damage() method."
		)

	print(
		"[FoodThrow] ", active_food.name,
		" dealt ", active_damage, " damage."
	)

	if (
		active_food.sprite_frames == null
		or not active_food.sprite_frames.has_animation("attack")
	):
		_finish_projectile()
		return

	active_food.sprite_frames.set_animation_loop("attack", false)
	active_food.stop()
	active_food.play("attack")

	await active_food.animation_finished

	_finish_projectile()


func _finish_projectile() -> void:
	if not is_instance_valid(self):
		return

	is_flying = false
	projectile_finished.emit()
	queue_free()
