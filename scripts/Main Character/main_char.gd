
extends CharacterBody2D

signal food_consumed

const FOOD_THROW_SCENE: PackedScene = preload(
	"res://scenes/Foods/food_throw.tscn"
)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

var nearby_food: Array[Area2D] = []
var is_processing_food: bool = false


func _ready() -> void:
	if detection_area == null:
		push_error("[MainChar] DetectionArea is missing.")
		return

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

	_play_idle()


# --------------------------------------------------
# FOOD DETECTION
# --------------------------------------------------

func _on_detection_area_entered(area: Area2D) -> void:
	if not is_instance_valid(area):
		return

	var food_root: Node2D = _get_food_root(area)

	if food_root == null:
		return

	if not nearby_food.has(area):
		nearby_food.append(area)
		print("[MainChar] Detected food: ", food_root.name)


func _on_detection_area_exited(area: Area2D) -> void:
	nearby_food.erase(area)


# Finds the highest ancestor in the food group.
# This supports food scenes with nested AnimatedSprite2D/Area2D nodes.
func _get_food_root(food_area: Area2D) -> Node2D:
	if not is_instance_valid(food_area):
		return null

	var current: Node = food_area
	var found_food: Node2D = null

	while current != null and current != self:
		if current is Node2D and current.is_in_group("food"):
			found_food = current as Node2D

		current = current.get_parent()

	return found_food


func can_accept_food(food_area: Area2D) -> bool:
	if is_processing_food:
		return false

	if not is_instance_valid(food_area):
		return false

	var food_root: Node2D = _get_food_root(food_area)

	if food_root == null:
		print(
			"[MainChar] Rejected food: no ancestor belongs "
			+ "to the 'food' group."
		)
		return false

	if not nearby_food.has(food_area):
		print(
			"[MainChar] Rejected ", food_root.name,
			": not detected by DetectionArea."
		)
		return false

	return true


# --------------------------------------------------
# IDENTIFY FOOD TYPE
# --------------------------------------------------

func _is_supported_food(food_name: String) -> bool:
	return food_name in [
		"apple",
		"banana",
		"bean",
		"bread",
		"carrot",
		"chicken",
		"corn",
		"egg",
		"fish",
		"mango",
		"milk",
		"oats",
		"papaya",
		"potato",
		"rice"
	]


func _get_food_key(food: Node2D) -> String:
	if not is_instance_valid(food):
		return ""

	# First try the original scene file path.
	if not food.scene_file_path.is_empty():
		var scene_key: String = (
			food.scene_file_path
			.get_file()
			.get_basename()
			.to_lower()
		)

		if _is_supported_food(scene_key):
			return scene_key

	# Next try the root node's name.
	var root_name: String = str(food.name).to_lower()

	for food_key in [
		"apple",
		"banana",
		"bean",
		"bread",
		"carrot",
		"chicken",
		"corn",
		"egg",
		"fish",
		"mango",
		"milk",
		"oats",
		"papaya",
		"potato",
		"rice"
	]:
		if root_name == food_key or root_name.begins_with(food_key):
			return food_key

	# Finally inspect ancestors in case the supplied node is nested.
	var current: Node = food

	while current != null and current != self:
		var current_name: String = str(current.name).to_lower()

		for food_key in [
			"apple",
			"banana",
			"bean",
			"bread",
			"carrot",
			"chicken",
			"corn",
			"egg",
			"fish",
			"mango",
			"milk",
			"oats",
			"papaya",
			"potato",
			"rice"
		]:
			if (
				current_name == food_key
				or current_name.begins_with(food_key)
			):
				return food_key

		current = current.get_parent()

	push_error(
		"[MainChar] Could not identify food type. Root: "
		+ str(food.name)
		+ ", scene path: " + food.scene_file_path
	)

	return ""


# --------------------------------------------------
# CONSUME FOOD
# --------------------------------------------------

func consume_food(food_area: Area2D) -> void:
	if not can_accept_food(food_area):
		print("[MainChar] Cannot accept this food.")
		return

	# An enemy must exist before the food can be consumed.
	var target: Node2D = find_nearest_enemy()

	if target == null:
		print("[MainChar] No enemy found; food was not consumed.")
		return

	var food: Node2D = _get_food_root(food_area)

	if food == null:
		push_error("[MainChar] Food root was not found.")
		return

	# Capture the type before freeing the original food.
	var food_name: String = _get_food_key(food)

	if food_name.is_empty():
		return

	is_processing_food = true

	food.remove_from_group("food")
	nearby_food.erase(food_area)

	print("[MainChar] Accepted food: ", food_name)

	# Play the character's attack animation.
	await play_attack()

	if not is_instance_valid(self):
		return

	_play_idle()

	# Remove the original food after the attack animation.
	if is_instance_valid(food):
		food.queue_free()

	# Find the target again after the animation.
	var current_target: Node2D = find_nearest_enemy()

	if current_target != null:
		_launch_food_projectile_to(
			current_target,
			food_name
		)
	else:
		print(
			"[MainChar] Enemy disappeared during attack; "
			+ "projectile skipped."
		)

	is_processing_food = false
	food_consumed.emit()

	print("[MainChar] Food consumed; replacement requested.")


# --------------------------------------------------
# CHARACTER ANIMATIONS
# --------------------------------------------------

func _play_idle() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	else:
		push_warning("[MainChar] Animation 'idle' was not found.")


func play_attack() -> void:
	if sprite == null or sprite.sprite_frames == null:
		push_error(
			"[MainChar] AnimatedSprite2D or SpriteFrames is missing."
		)
		return

	if not sprite.sprite_frames.has_animation("attack"):
		push_error("[MainChar] Animation 'attack' was not found.")
		return

	sprite.sprite_frames.set_animation_loop("attack", false)
	sprite.stop()
	sprite.play("attack")

	await sprite.animation_finished


# --------------------------------------------------
# MANUAL PROJECTILE TEST
# --------------------------------------------------

func launch_food_projectile() -> void:
	var target: Node2D = find_nearest_enemy()

	if target == null:
		print("[MainChar] No enemy found; projectile was not launched.")
		return

	_launch_food_projectile_to(target, "mango")


# --------------------------------------------------
# LAUNCH SELECTED FOOD PROJECTILE
# --------------------------------------------------

func _launch_food_projectile_to(
	target: Node2D,
	food_name: String
) -> void:
	if not is_instance_valid(target):
		print("[MainChar] Target no longer exists; projectile not launched.")
		return

	var projectile := FOOD_THROW_SCENE.instantiate() as Node2D

	if projectile == null:
		push_error("[MainChar] Could not instantiate FoodThrow.")
		return

	var projectile_parent: Node = get_tree().current_scene

	if projectile_parent == null:
		projectile_parent = get_parent()

	if projectile_parent == null:
		projectile.free()
		push_error("[MainChar] No parent available for projectile.")
		return

	projectile_parent.add_child(projectile)
	projectile.global_position = global_position

	if not projectile.has_method("launch"):
		projectile.queue_free()
		push_error("[MainChar] FoodThrow has no launch() method.")
		return

	# FoodThrow receives the selected type for its sprite and damage.
	projectile.call(
		"launch",
		target.global_position,
		target,
		food_name
	)

	print(
		"[MainChar] Launched ", food_name,
		" toward ", target.name
	)


# --------------------------------------------------
# FIND NEAREST ENEMY
# --------------------------------------------------

func find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF

	for node in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(node):
			continue

		if not node is Node2D:
			continue

		var enemy := node as Node2D

		var distance: float = global_position.distance_squared_to(
			enemy.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy
