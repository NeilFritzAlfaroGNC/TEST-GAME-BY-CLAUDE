extends CharacterBody2D

signal food_consumed(food: FoodData)
signal health_changed(current_health: int, maximum_health: int)
signal game_over
signal hit_received(total_hits: int)

const MAX_HEALTH: int = 3

const GAME_OVER_SCENE: PackedScene = preload(
	"res://scenes/UI/game_over.tscn"
)

const HEART_SCREEN_OFFSET: Vector2 = Vector2(-60, -95)
const HEART_LABEL_SIZE: Vector2 = Vector2(120, 40)

var current_health: int = MAX_HEALTH
var total_hits_received: int = 0
var is_dead: bool = false

var nearby_food: Array[Area2D] = []
var is_processing_food: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var food_consumption: FoodConsumption = $FoodConsumption

@onready var energy_system: Node = (
	get_node_or_null("EnergySystem")
)

@onready var grow_buff: Node = (
	get_node_or_null("GrowBuff")
)

@onready var food_attack: FoodAttack = (
	get_node_or_null("FoodAttack") as FoodAttack
)

@onready var health_display: CanvasLayer = (
	get_node_or_null("HealthDisplay") as CanvasLayer
)

@onready var hearts: Label = (
	get_node_or_null("HealthDisplay/Hearts") as Label
)


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")

	if not detection_area.area_entered.is_connected(
		_on_detection_area_entered
	):
		detection_area.area_entered.connect(
			_on_detection_area_entered
		)

	if not detection_area.area_exited.is_connected(
		_on_detection_area_exited
	):
		detection_area.area_exited.connect(
			_on_detection_area_exited
		)

	if grow_buff == null:
		push_error("[MainCharacter] GrowBuff node is missing.")

	if food_attack == null:
		push_error("[MainCharacter] FoodAttack node is missing.")

	_setup_health_display()
	health_changed.emit(current_health, MAX_HEALTH)
	_play_idle()


func _process(_delta: float) -> void:
	_update_health_display_position()


# ==================================================
# HEALTH DISPLAY
# ==================================================

func _setup_health_display() -> void:
	if health_display == null:
		return

	if hearts == null:
		return

	health_display.layer = 10
	health_display.visible = true
	hearts.visible = true
	hearts.size = HEART_LABEL_SIZE

	hearts.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	hearts.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	hearts.add_theme_font_size_override(
		"font_size",
		28
	)

	_update_health_display(current_health, MAX_HEALTH)
	_update_health_display_position()


func _update_health_display_position() -> void:
	if not is_instance_valid(hearts):
		return

	var screen_position: Vector2 = (
		get_global_transform_with_canvas().origin
	)

	hearts.position = (
		screen_position + HEART_SCREEN_OFFSET
	)


func _update_health_display(
	current: int,
	maximum: int
) -> void:
	if not is_instance_valid(hearts):
		return

	var heart_text: String = ""

	for i in range(maximum):
		if i < current:
			heart_text += "♥"
		else:
			heart_text += "♡"

		if i < maximum - 1:
			heart_text += " "

	hearts.text = heart_text
	print("[Health UI] ", heart_text)


# ==================================================
# PLAYER HEALTH
# ==================================================

func take_hit(damage: int = 1) -> void:
	if is_dead or damage <= 0:
		return

	current_health = maxi(
		current_health - damage,
		0
	)

	total_hits_received += 1

	print("[Player] Hit received!")
	print("[Player] Damage: ", damage)
	print(
		"[Player] Health: ",
		current_health,
		"/",
		MAX_HEALTH
	)

	health_changed.emit(
		current_health,
		MAX_HEALTH
	)

	_update_health_display(
		current_health,
		MAX_HEALTH
	)

	hit_received.emit(total_hits_received)

	if current_health <= 0:
		_die()


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO

	detection_area.set_deferred(
		"monitoring",
		false
	)

	if is_instance_valid(health_display):
		health_display.visible = false

	print("[Player] Game Over.")
	game_over.emit()

	var game_over_instance: Control = (
		GAME_OVER_SCENE.instantiate() as Control
	)

	if game_over_instance == null:
		return

	get_tree().root.add_child(game_over_instance)
	get_tree().paused = true


func reset_health() -> void:
	is_dead = false
	current_health = MAX_HEALTH
	total_hits_received = 0

	detection_area.set_deferred(
		"monitoring",
		true
	)

	if is_instance_valid(health_display):
		health_display.visible = true

	health_changed.emit(
		current_health,
		MAX_HEALTH
	)

	_update_health_display(
		current_health,
		MAX_HEALTH
	)


# ==================================================
# FOOD DETECTION
# ==================================================

func _on_detection_area_entered(
	area: Area2D
) -> void:
	if is_dead:
		return

	if _get_food_root(area) == null:
		return

	if not nearby_food.has(area):
		nearby_food.append(area)


func _on_detection_area_exited(
	area: Area2D
) -> void:
	nearby_food.erase(area)


func _get_food_root(node: Node) -> FoodData:
	var current: Node = node

	while current != null:
		if current is FoodData:
			return current as FoodData

		current = current.get_parent()

	return null


func is_food_in_range(food_area: Area2D) -> bool:
	if is_dead:
		return false

	if not is_instance_valid(food_area):
		return false

	return detection_area.get_overlapping_areas().has(
		food_area
	)


# ==================================================
# FOOD ACCEPTANCE
# ==================================================

func can_accept_food(food_area: Area2D) -> bool:
	if is_dead or is_processing_food:
		return false

	if not is_instance_valid(food_area):
		return false

	if not is_food_in_range(food_area):
		return false

	var food: FoodData = _get_food_root(food_area)

	if food == null:
		return false

	if food.food_name.is_empty():
		return false

	if food.has_category(FoodData.FoodCategory.GLOW):
		if find_nearest_enemy() == null:
			return false

		if is_instance_valid(energy_system):
			if not energy_system.has_energy_protection():
				var actual_cost: float = (
					energy_system.get_discounted_energy_cost(
						food.energy_cost
					)
				)

				if not energy_system.has_enough_energy(
					actual_cost
				):
					return false

	return true


# ==================================================
# FOOD CONSUMPTION
# ==================================================

func consume_food(food_area: Area2D) -> void:
	if is_dead or is_processing_food:
		return

	if not is_instance_valid(food_area):
		return

	if not can_accept_food(food_area):
		print("[Food] Consumption rejected.")
		return

	var food: FoodData = _get_food_root(food_area)

	if food == null:
		return

	var target: Node2D = null

	if food.has_category(FoodData.FoodCategory.GLOW):
		target = find_nearest_enemy()

		if not is_instance_valid(target):
			return

	if not food_consumption.begin_consumption(food):
		return

	is_processing_food = true
	food.set_meta("is_held_for_attack", true)

	print(
		"[FoodConsumption] Started: ",
		food.food_name,
		" | Categories: ",
		", ".join(food.get_selected_category_names())
	)

	var success: bool = true
	var projectile_owns_food: bool = false
	var used_grow_buff: bool = false

	# ----------------------------------------------
	# GO
	# ----------------------------------------------

	if food.has_category(FoodData.FoodCategory.GO):
		if not food.has_category(FoodData.FoodCategory.GLOW):
			await _play_go_eating_animation(food)

		if is_instance_valid(food) and is_instance_valid(
			energy_system
		):
			_apply_go_effects(food)

	if not is_instance_valid(food):
		is_processing_food = false
		return

	# ----------------------------------------------
	# GROW
	# ----------------------------------------------

	if food.has_category(FoodData.FoodCategory.GROW):
		if (
			not food.has_category(FoodData.FoodCategory.GO)
			and not food.has_category(FoodData.FoodCategory.GLOW)
		):
			await _play_go_eating_animation(food)

		if not is_instance_valid(food):
			is_processing_food = false
			return

		_apply_grow_effects(food)

	# ----------------------------------------------
	# WHOA
	# ----------------------------------------------

	if food.has_category(FoodData.FoodCategory.WHOA):
		print("[WHOA] Food detected: ", food.food_name)

	# ----------------------------------------------
	# GLOW
	# ----------------------------------------------

	if food.has_category(FoodData.FoodCategory.GLOW):
		used_grow_buff = (
			is_instance_valid(grow_buff)
			and grow_buff.has_active_buff()
		)

		projectile_owns_food = await _perform_glow_attack(
			food,
			target
		)

		if not projectile_owns_food:
			success = false

	if not success:
		if is_instance_valid(food):
			food.set_meta("is_held_for_attack", false)

		if is_instance_valid(food):
			food_consumption.finish_consumption(food)

		is_processing_food = false
		print("[Food] Attack failed; food returned.")
		return

	# One GLOW attack consumes one use of
	# each currently active GROW effect.
	if used_grow_buff and is_instance_valid(grow_buff):
		grow_buff.consume_buff_use()

	if is_instance_valid(food):
		food.remove_from_group("food")

		if not projectile_owns_food:
			food.set_meta("is_held_for_attack", false)

	food_consumption.finish_consumption(food)
	food_consumed.emit(food)

	if (
		not projectile_owns_food
		and is_instance_valid(food)
	):
		food.queue_free()

	is_processing_food = false

	print(
		"[FoodConsumption] Finished: ",
		food.food_name if is_instance_valid(food) else "food"
	)


# ==================================================
# APPLY GO EFFECTS
# ==================================================

func _apply_go_effects(food: FoodData) -> void:
	if not is_instance_valid(energy_system):
		return

	var total_restore: float = 0.0

	for effect in food.get_all_go_effects():
		match str(effect.get("type", "")):
			"instant_restore":
				total_restore += float(
					effect.get("amount", 0.0)
				)

			"energy_over_time":
				energy_system.add_energy_over_time(
					float(effect.get("rate", 0.0)),
					float(effect.get("duration", 0.0))
				)

			"regeneration_boost":
				energy_system.add_regeneration_boost(
					float(effect.get("bonus", 0.0)),
					float(effect.get("duration", 0.0))
				)

			"energy_discount":
				energy_system.add_energy_discount(
					float(effect.get("percent", 0.0)),
					float(effect.get("duration", 0.0))
				)

			"energy_protection":
				energy_system.add_energy_protection(
					int(effect.get("charges", 1))
				)

	if total_restore > 0.0:
		energy_system.restore_energy(total_restore)

	print("[GO] Restored: ", total_restore)


# ==================================================
# APPLY GROW EFFECTS — FIVE ONLY
# ==================================================

func _apply_grow_effects(food: FoodData) -> void:
	if not is_instance_valid(food):
		return

	if not is_instance_valid(grow_buff):
		return

	for effect in food.get_all_grow_effects():
		var effect_type: int = -1

		match str(effect.get("type", "")):
			"damage":
				effect_type = 0

			"enlarge":
				effect_type = 1

			"knockback":
				effect_type = 2

			"stun":
				effect_type = 3

			"flopping":
				effect_type = 4

			_:
				# Legacy multishot/artillery effect
				# dictionaries are intentionally ignored.
				print(
					"[GROW] Unsupported effect skipped: ",
					effect.get("type", "")
				)
				continue

		grow_buff.activate_effect(
			effect_type,
			float(effect.get("value", 0.0)),
			float(effect.get("duration", 5.0)),
			int(effect.get("uses", 1)),
			effect.get("settings", {})
		)

		print(
			"[GROW] Food: ",
			food.food_name,
			" | Effect: ",
			effect.get("type", "")
		)


# ==================================================
# EATING ANIMATION
# ==================================================

func _play_go_eating_animation(
	food: FoodData
) -> void:
	if not is_instance_valid(food):
		return

	if food.sprite_frames == null:
		return

	if not food.sprite_frames.has_animation("eaten"):
		return

	food.sprite_frames.set_animation_loop(
		"eaten",
		false
	)

	food.stop()
	food.play("eaten")

	print(
		"[Food] Playing eaten animation: ",
		food.food_name
	)

	await food.animation_finished


# ==================================================
# GLOW ATTACK
# ==================================================

func _perform_glow_attack(
	food: FoodData,
	target: Node2D
) -> bool:
	if is_dead:
		return false

	if not is_instance_valid(food):
		return false

	if not is_instance_valid(target):
		return false

	if not is_instance_valid(food_attack):
		return false

	return await food_attack.perform_glow_attack(
		food,
		target
	)


# ==================================================
# CHARACTER ANIMATIONS
# ==================================================

func play_attack() -> bool:
	if is_dead:
		return false

	if not is_instance_valid(sprite):
		return false

	if sprite.sprite_frames == null:
		return false

	if not sprite.sprite_frames.has_animation("attack"):
		push_error("[Attack] Missing attack animation.")
		return false

	sprite.sprite_frames.set_animation_loop(
		"attack",
		false
	)

	sprite.play("attack")
	await sprite.animation_finished

	if is_dead:
		return false

	_play_idle()

	print("[Attack] Animation finished.")
	return true


func _play_idle() -> void:
	if not is_instance_valid(sprite):
		return

	if sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")


# ==================================================
# FIND NEAREST ENEMY
# ==================================================

func find_nearest_enemy() -> Node2D:
	if is_dead:
		return null

	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		var enemy_node: Node2D = enemy as Node2D

		if not enemy_node.is_inside_tree():
			continue

		var distance: float = global_position.distance_to(
			enemy_node.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy_node

	return nearest_enemy
