
extends CharacterBody2D

signal food_consumed(food: FoodData)
signal health_changed(current_health: int, maximum_health: int)
signal game_over
signal hit_received(total_hits: int)

const MAX_HEALTH: int = 3
const GAME_OVER_SCENE: PackedScene = preload("res://scenes/UI/game_over.tscn")

# TODO: Temporary heart UI. Revisit its design and positioning later.
const HEART_SCREEN_OFFSET: Vector2 = Vector2(-60, -95)
const HEART_LABEL_SIZE: Vector2 = Vector2(120, 40)

var current_health: int = MAX_HEALTH
var total_hits_received: int = 0
var is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var food_consumption: FoodConsumption = $FoodConsumption
@onready var energy_system: Node = get_node_or_null("EnergySystem")
@onready var grow_buff: Node = get_node_or_null("GrowBuff")
@onready var food_attack: FoodAttack = get_node_or_null("FoodAttack") as FoodAttack

@onready var health_display: CanvasLayer = get_node_or_null("HealthDisplay") as CanvasLayer
@onready var hearts: Label = get_node_or_null("HealthDisplay/Hearts") as Label

var nearby_food: Array[Area2D] = []
var is_processing_food: bool = false


func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")

	if not detection_area.area_entered.is_connected(_on_detection_area_entered):
		detection_area.area_entered.connect(_on_detection_area_entered)

	if not detection_area.area_exited.is_connected(_on_detection_area_exited):
		detection_area.area_exited.connect(_on_detection_area_exited)

	if grow_buff == null:
		push_error("[MainCharacter] GrowBuff node is missing.")

	if food_attack == null:
		push_error("[MainCharacter] FoodAttack component is missing.")

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
		push_error("[MainCharacter] HealthDisplay CanvasLayer is missing.")
		return

	if hearts == null:
		push_error("[MainCharacter] HealthDisplay/Hearts Label is missing.")
		return

	health_display.layer = 10
	health_display.visible = true

	hearts.visible = true
	hearts.size = HEART_LABEL_SIZE
	hearts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hearts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	hearts.add_theme_font_size_override("font_size", 28)
	hearts.add_theme_color_override("font_color", Color.WHITE)

	_update_health_display(current_health, MAX_HEALTH)
	_update_health_display_position()

	print("[Health UI] Initialized above character.")


func _update_health_display_position() -> void:
	if not is_instance_valid(health_display):
		return

	if not is_instance_valid(hearts):
		return

	var screen_position: Vector2 = get_global_transform_with_canvas().origin
	hearts.position = screen_position + HEART_SCREEN_OFFSET


func _update_health_display(current: int, maximum: int) -> void:
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
	hearts.visible = true

	print("[Health UI] ", heart_text)


# ==================================================
# PLAYER HEALTH AND DAMAGE
# ==================================================

func take_hit(damage: int = 1) -> void:
	if is_dead or damage <= 0:
		return

	current_health = maxi(current_health - damage, 0)
	total_hits_received += 1

	print("[Player] Hit received!")
	print("[Player] Damage: ", damage)
	print("[Player] Health: ", current_health, "/", MAX_HEALTH)
	print("[Player] Total hits: ", total_hits_received)

	health_changed.emit(current_health, MAX_HEALTH)
	_update_health_display(current_health, MAX_HEALTH)

	hit_received.emit(total_hits_received)

	if current_health <= 0:
		_die()


func _die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO

	detection_area.set_deferred("monitoring", false)

	if is_instance_valid(health_display):
		health_display.visible = false

	print("[Player] Game Over. Health reached zero.")

	game_over.emit()

	# Create the Game Over screen before pausing the game.
	var game_over_instance: Control = GAME_OVER_SCENE.instantiate() as Control

	if game_over_instance == null:
		push_error("[MainCharacter] Could not instantiate Game Over scene.")
		return

	get_tree().root.add_child(game_over_instance)

	# Pause the entire battle.
	get_tree().paused = true

	print("[GameOver] Battle paused.")


func reset_health() -> void:
	is_dead = false
	current_health = MAX_HEALTH
	total_hits_received = 0

	detection_area.set_deferred("monitoring", true)

	if is_instance_valid(health_display):
		health_display.visible = true

	health_changed.emit(current_health, MAX_HEALTH)
	_update_health_display(current_health, MAX_HEALTH)

	print("[Player] Health reset.")


# ==================================================
# FOOD DETECTION
# ==================================================

func _on_detection_area_entered(area: Area2D) -> void:
	if is_dead:
		return

	if _get_food_root(area) == null:
		return

	if not nearby_food.has(area):
		nearby_food.append(area)


func _on_detection_area_exited(area: Area2D) -> void:
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

	if not is_instance_valid(detection_area):
		return false

	return detection_area.get_overlapping_areas().has(food_area)


# ==================================================
# FOOD VALIDATION
# ==================================================

func can_accept_food(food_area: Area2D) -> bool:
	if is_dead or is_processing_food:
		return false

	if not is_instance_valid(food_area):
		return false

	if not is_food_in_range(food_area):
		return false

	var food := _get_food_root(food_area)

	if food == null or food.food_name.is_empty():
		return false

	if food.has_category(FoodData.FoodCategory.GLOW):
		if find_nearest_enemy() == null:
			print("[Food] GLOW rejected: no enemy found.")
			return false

		if energy_system != null:
			if not energy_system.has_enough_energy(food.energy_cost):
				print("[Food] GLOW rejected: insufficient energy.")
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

	var food := _get_food_root(food_area)

	if food == null:
		return

	var target: Node2D = null

	if food.has_category(FoodData.FoodCategory.GLOW):
		target = find_nearest_enemy()

		if target == null:
			return

		if energy_system != null:
			if not energy_system.has_enough_energy(food.energy_cost):
				return

	if not food_consumption.begin_consumption(food):
		return

	is_processing_food = true

	food.set_meta("is_held_for_attack", true)

	print("[Food] Locked at drop position: ", food.global_position)
	print("[Food] Processing: ", food.food_name)
	print("[Food] Categories: ", ", ".join(food.get_selected_category_names()))

	var consumption_success := true
	var used_buff := false
	var projectile_owns_food := false

	# GO: Restore energy.
	if food.has_category(FoodData.FoodCategory.GO):
		if energy_system != null:
			energy_system.restore_energy(food.energy_restore)
			print("[GO] Restored energy: ", food.energy_restore)
		else:
			print("[GO] EnergySystem node is missing.")

	# GROW: Activate the separate GrowBuff component.
	if food.has_category(FoodData.FoodCategory.GROW):
		if grow_buff != null:
			grow_buff.activate_buff(
				food.damage_bonus,
				food.buff_duration,
				food.buff_uses
			)
		else:
			push_error("[GROW] Cannot activate: GrowBuff is missing.")

	# WHOA: Effects will be implemented separately.
	if food.has_category(FoodData.FoodCategory.WHOA):
		print("[WHOA] Food detected: ", food.food_name)

	# GLOW: Delegate the attack to FoodAttack.
	if food.has_category(FoodData.FoodCategory.GLOW):
		used_buff = (
			grow_buff != null
			and grow_buff.has_active_buff()
		)

		projectile_owns_food = await _perform_glow_attack(
			food,
			target
		)

		if not projectile_owns_food:
			consumption_success = false

	# Restore the food if the attack failed.
	if not consumption_success:
		if is_instance_valid(food):
			food.set_meta("is_held_for_attack", false)

		food_consumption.finish_consumption(food)
		is_processing_food = false

		print("[Food] Food restored after failed attack.")
		return

	if used_buff and grow_buff != null:
		grow_buff.consume_buff_use()

	# The projectile now owns the original GLOW food.
	if projectile_owns_food:
		food.remove_from_group("food")
	else:
		food.set_meta("is_held_for_attack", false)
		food.remove_from_group("food")

	food_consumption.finish_consumption(food)
	food_consumed.emit(food)

	if not projectile_owns_food and is_instance_valid(food):
		food.queue_free()

	is_processing_food = false


# ==================================================
# GLOW ATTACK INTERFACE
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
		push_error("[Attack] FoodAttack component is missing.")
		return false

	return await food_attack.perform_glow_attack(food, target)


# ==================================================
# CHARACTER ANIMATIONS
# ==================================================

func play_attack() -> bool:
	if is_dead:
		return false

	if not is_instance_valid(sprite):
		return false

	if not sprite.sprite_frames.has_animation("attack"):
		push_error("[Attack] Missing attack animation.")
		return false

	sprite.sprite_frames.set_animation_loop("attack", false)
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

	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


# ==================================================
# ENEMY SEARCH
# ==================================================

func find_nearest_enemy() -> Node2D:
	if is_dead:
		return null

	var enemies := get_tree().get_nodes_in_group("enemy")

	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		if not enemy is Node2D:
			continue

		var enemy_node := enemy as Node2D

		var distance := global_position.distance_to(
			enemy_node.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy_node

	return nearest_enemy
