extends Control

# ==================================================
# FOOD HEROES - LEVEL 3 NUTRITION RESCUE
# GODOT 4.7.1
#
# COMPLETE NEW LEVEL 3 GAMEPLAY
#
# - No main character
# - No attacks or projectiles
# - Click monsters to view GO/GLOW/GROW
# - Drag food from conveyor onto monsters
# - Bars lock permanently at 100
# - Cure 5 monsters to win
# - 3 uncured escapes = Game Over
#
# Progress saved under scene3_level_3 only.
# ==================================================

const LEVEL_ID: String = "scene3_level_3"

const VICTORY_SCENE: String = (
	"res://scenes/UI/victory_screen.tscn"
)

const MAP_SCENE: String = (
	"res://scenes/Level Map/level_map.tscn"
)


# ==================================================
# INSPECTOR - MONSTER SPAWNING
# ==================================================

@export_group("Level 3 - Monster Spawning")

@export var monster_scene: PackedScene

@export_range(1, 10, 1)
var maximum_active_monsters: int = 3

var spawn_interval: float = 5.0

@export var spawn_immediately: bool = true


# ==================================================
# INSPECTOR - WIN AND LOSE RULES
# ==================================================

@export_group("Level 3 - Victory and Game Over")

var required_cures: int = 5

var maximum_escapes: int = 3


# ==================================================
# INSPECTOR - FOOD FEEDING
# ==================================================

@export_group("Level 3 - Food Feeding")

@export_range(10.0, 120.0, 1.0)
var feeding_distance: float = 55.0

# A food containing multiple categories restores
# the lowest unfinished category it provides.
@export var allow_multicategory_food: bool = true


# ==================================================
# INSPECTOR - DIFFICULTY
# ==================================================

@export_group("Easy Settings", "easy_")
@export_range(0.1,100.0,0.1) var easy_food_energy_given: float = 25.0
@export_range(0.1,60.0,0.1) var easy_monster_spawn_interval: float = 5.0
@export_range(1,50,1) var easy_monsters_to_cure: int = 5
@export_range(1,50,1) var easy_maximum_escapes: int = 6
@export_range(0,49,1) var easy_three_star_escape_limit: int = 0
@export_range(0,49,1) var easy_two_star_escape_limit: int = 3
@export_range(0,49,1) var easy_one_star_escape_limit: int = 5
@export_range(0.0,300.0,1.0) var easy_monster_movement_speed: float = 24.0
@export_range(0.0,20.0,0.1) var easy_nutrition_depletion_rate: float = 0.7

@export_group("Normal Settings", "normal_")
@export_range(0.1,100.0,0.1) var normal_food_energy_given: float = 25.0
@export_range(0.1,60.0,0.1) var normal_monster_spawn_interval: float = 5.0
@export_range(1,50,1) var normal_monsters_to_cure: int = 5
@export_range(1,50,1) var normal_maximum_escapes: int = 3
@export_range(0,49,1) var normal_three_star_escape_limit: int = 0
@export_range(0,49,1) var normal_two_star_escape_limit: int = 1
@export_range(0,49,1) var normal_one_star_escape_limit: int = 2
@export_range(0.0,300.0,1.0) var normal_monster_movement_speed: float = 30.0
@export_range(0.0,20.0,0.1) var normal_nutrition_depletion_rate: float = 1.0

@export_group("Hard Settings", "hard_")
@export_range(0.1,100.0,0.1) var hard_food_energy_given: float = 25.0
@export_range(0.1,60.0,0.1) var hard_monster_spawn_interval: float = 5.0
@export_range(1,50,1) var hard_monsters_to_cure: int = 5
@export_range(1,50,1) var hard_maximum_escapes: int = 3
@export_range(0,49,1) var hard_three_star_escape_limit: int = 0
@export_range(0,49,1) var hard_two_star_escape_limit: int = 1
@export_range(0,49,1) var hard_one_star_escape_limit: int = 2
@export_range(0.0,300.0,1.0) var hard_monster_movement_speed: float = 39.0
@export_range(0.0,20.0,0.1) var hard_nutrition_depletion_rate: float = 1.3

@export_group("")
var applied_difficulty_settings: Dictionary = {}

var food_energy_given: float = 25.0
var monster_movement_speed: float = 30.0
var nutrition_depletion_rate: float = 1.0
var three_star_escape_limit: int = 0
var two_star_escape_limit: int = 1
var one_star_escape_limit: int = 2
var run_difficulty: String = "easy"


# ==================================================
# SCENE REFERENCES
# ==================================================

@onready var monster_container: Node2D = (
	$MonsterContainer
)

@onready var spawn_point: Marker2D = (
	$SpawnPoint
)

@onready var escape_zone: Area2D = (
	$EscapeZone
)

@onready var food_items: Node2D = (
	$FoodItems
)


# ==================================================
# GAME STATE
# ==================================================

var cured_count: int = 0
var escaped_count: int = 0

var battle_finished: bool = false
var spawn_clock: float = 0.0

var active_monsters: Array[Level3NutritionMonster] = []
var selected_monster: Level3NutritionMonster = null

var dragged_food: FoodData = null
var food_original_position: Vector2 = Vector2.ZERO
var conveyor: Node = null


# ==================================================
# UI REFERENCES
# ==================================================

var hud_layer: CanvasLayer

var counter_label: Label
var selected_label: Label

var nutrition_panel: Control
var liquid_ui: CanvasLayer

var result_layer: CanvasLayer


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	_load_difficulty_settings()

	if monster_scene == null:
		push_error(
			"[Level3] Assign Monster Scene in Inspector."
		)
		battle_finished = true
		set_process(false)
		set_process_input(false)
		return

	# Use the existing conveyor group if available.
	conveyor = get_tree().get_first_node_in_group(
		"conveyor"
	)

	_create_hud()

	if spawn_immediately:
		_spawn_monster()

	print("[Level3] Nutrition Rescue ready.")


# ==================================================
# MONSTER SPAWNING
# ==================================================

func _process(delta: float) -> void:

	if battle_finished:
		return

	_clean_monster_list()

	spawn_clock += delta

	if spawn_clock >= spawn_interval:
		spawn_clock = 0.0
		_spawn_monster()

	_update_selected_monster_ui()


func _clean_monster_list() -> void:

	var valid_monsters: Array[Level3NutritionMonster] = []

	for monster in active_monsters:
		if is_instance_valid(monster):
			if monster.is_active:
				valid_monsters.append(monster)

	active_monsters = valid_monsters


func _spawn_monster() -> void:

	if battle_finished:
		return

	if active_monsters.size() >= maximum_active_monsters:
		return

	var instance: Node = monster_scene.instantiate()

	if not instance is Level3NutritionMonster:
		push_error(
			"[Level3] Monster scene root must use "
			+ "level3_nutrition_monster.gd."
		)
		instance.free()
		return

	var monster: Level3NutritionMonster = instance

	monster.position = monster_container.to_local(spawn_point.global_position)
	_apply_difficulty(monster)

	monster.selected.connect(_on_monster_selected)
	monster.cured.connect(_on_monster_cured)

	active_monsters.append(monster)
	monster_container.add_child(monster)

	print("[Level3] Monster spawned.")


# ==================================================
# DIFFICULTY SCALING
# ==================================================

func _load_difficulty_settings() -> void:
	run_difficulty = str(ProgressManager.current_difficulty).to_lower()
	if run_difficulty not in ["easy", "normal", "hard"]:
		run_difficulty = "easy"
	var settings: Dictionary = {}
	for key in ["food_energy_given", "monster_spawn_interval", "monsters_to_cure",
		"maximum_escapes", "three_star_escape_limit", "two_star_escape_limit",
		"one_star_escape_limit", "monster_movement_speed", "nutrition_depletion_rate"]:
		settings[key] = get(run_difficulty + "_" + key)
	food_energy_given = maxf(0.1,float(settings.food_energy_given))
	spawn_interval = maxf(0.1,float(settings.monster_spawn_interval))
	required_cures = maxi(1,int(settings.monsters_to_cure))
	maximum_escapes = maxi(1,int(settings.maximum_escapes))
	three_star_escape_limit = clampi(int(settings.three_star_escape_limit),0,maximum_escapes-1)
	two_star_escape_limit = clampi(int(settings.two_star_escape_limit),three_star_escape_limit,maximum_escapes-1)
	one_star_escape_limit = clampi(int(settings.one_star_escape_limit),two_star_escape_limit,maximum_escapes-1)
	maximum_escapes = mini(maximum_escapes,one_star_escape_limit+1)
	monster_movement_speed = maxf(0,float(settings.monster_movement_speed))
	nutrition_depletion_rate = maxf(0,float(settings.nutrition_depletion_rate))
	applied_difficulty_settings = settings

func _apply_difficulty(monster: Level3NutritionMonster) -> void:
	monster.movement_speed = monster_movement_speed
	monster.nutrition_decay_per_second = nutrition_depletion_rate
	monster.nutrition_gain_per_food = food_energy_given

func calculate_stars_for_escapes(escapes: int) -> int:
	if escapes < 0 or escapes >= maximum_escapes:
		return 0
	if escapes <= three_star_escape_limit:
		return 3
	if escapes <= two_star_escape_limit:
		return 2
	if escapes <= one_star_escape_limit:
		return 1
	return 0


# ==================================================
# SELECT MONSTER
# ==================================================

func _on_monster_selected(
	monster: Level3NutritionMonster
) -> void:

	if battle_finished or not is_instance_valid(monster) or not monster.is_active:
		return

	selected_monster = monster


	_update_selected_monster_ui()

	print("[Level3] Selected monster: ", monster.name)


# ==================================================
# NUTRITION DISPLAY
# ==================================================

func _update_selected_monster_ui() -> void:

	counter_label.text = (
		"Cured: %d/%d    Escaped: %d/%d"
		% [
			cured_count,
			required_cures,
			escaped_count,
			maximum_escapes
		]
	)

	if not is_instance_valid(selected_monster):
		liquid_ui.show_monster(null)
		return

	if not selected_monster.is_active:
		selected_monster = null
		liquid_ui.show_monster(null)
		return

	liquid_ui.show_monster(selected_monster)


# ==================================================
# FOOD DRAGGING
# ==================================================

func _input(event: InputEvent) -> void:

	if battle_finished:
		return

	if event is InputEventMouseButton:

		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			_begin_food_drag(get_canvas_transform().affine_inverse() * event.position)
		else:
			_finish_food_drag(get_canvas_transform().affine_inverse() * event.position)

	elif event is InputEventMouseMotion:

		if is_instance_valid(dragged_food):
			dragged_food.global_position = (
				get_canvas_transform().affine_inverse() * event.position
			)


func _begin_food_drag(mouse_position: Vector2) -> void:

	if is_instance_valid(dragged_food):
		return

	for food_node in food_items.get_children():

		if not food_node is FoodData:
			continue

		var food: FoodData = food_node as FoodData

		if not is_instance_valid(food):
			continue

		if food.is_queued_for_deletion():
			continue

		var local_position: Vector2 = (
			food.to_local(mouse_position)
		)

		if not food.is_visible_in_tree() or food.sprite_frames == null:
			continue
		if not food.sprite_frames.has_animation(food.animation):
			continue
		if food.sprite_frames.get_frame_count(food.animation) == 0:
			continue
		var texture := food.sprite_frames.get_frame_texture(food.animation, food.frame)
		if texture == null:
			continue
		var texture_size := texture.get_size()
		var top_left := food.offset
		if food.centered:
			top_left -= texture_size * 0.5
		var is_over_food := Rect2(top_left, texture_size).has_point(local_position)

		if not is_over_food:
			continue

		dragged_food = food

		food_original_position = food.global_position

		food.set_meta("is_held_for_attack", true)
		food.set_meta("is_queued", false)
		food.set_meta("is_dropping", false)

		if is_instance_valid(conveyor):
			if conveyor.has_method("set_dragged_food"):
				conveyor.call(
					"set_dragged_food",
					food
				)

		return


func _finish_food_drag(drop_position: Vector2) -> void:

	if not is_instance_valid(dragged_food):
		return

	var food: FoodData = dragged_food

	dragged_food = null

	if is_instance_valid(conveyor):
		if conveyor.has_method("set_dragged_food"):
			conveyor.call("set_dragged_food", null)

	var target: Level3NutritionMonster = (
		_find_drop_target(
			drop_position
		)
	)

	if target != null:
		if _feed_monster_with_food(target, food):
			food.queue_free()
			return

	# Return unused food to the conveyor.
	food.global_position = food_original_position
	food.set_meta("is_held_for_attack", false)

	if is_instance_valid(conveyor):
		if conveyor.has_method("release_food_onto_belt"):
			conveyor.call(
				"release_food_onto_belt",
				food
			)


# ==================================================
# FIND MONSTER NEAR DROP
# ==================================================

func _find_drop_target(
	drop_position: Vector2
) -> Level3NutritionMonster:

	# If dropped directly on a monster, feed it.
	for monster in active_monsters:

		if not is_instance_valid(monster):
			continue

		if not monster.is_active:
			continue

		if monster.global_position.distance_to(
			drop_position
		) <= feeding_distance:
			return monster

	return null


# ==================================================
# FEED MONSTER USING FOODDATA
# ==================================================

func _feed_monster_with_food(
	monster: Level3NutritionMonster,
	food: FoodData
) -> bool:

	if battle_finished or not is_instance_valid(monster) or not monster.is_active or monster.is_cured:
		return false

	var categories: Array[int] = []

	for category in range(3):
		if food.has_category(category):
			categories.append(category)

	if categories.is_empty():
		return false

	if not allow_multicategory_food:
		if categories.size() > 1:
			return false

	var values: Dictionary = (
		monster.get_nutrition_values()
	)

	var locks: Dictionary = (
		monster.get_locked_values()
	)

	var names: Array[String] = [
		"GO",
		"GLOW",
		"GROW"
	]

	# Select the lowest unfinished nutrition bar
	# that this food can restore.
	var chosen_category: int = -1
	var lowest_value: float = 101.0

	for category in categories:

		var category_name: String = names[category]

		if bool(locks[category_name]):
			continue

		var value: float = float(values[category_name])

		if value < lowest_value:
			lowest_value = value
			chosen_category = category

	if chosen_category == -1:
		return false

	_on_monster_selected(monster)
	monster.feed_category(chosen_category)
	_update_selected_monster_ui()

	print(
		"[Level3] Fed ",
		food.food_name,
		" | Category: ",
		names[chosen_category]
	)

	return true


# ==================================================
# MONSTER CURED
# ==================================================

func _on_monster_cured(
	monster: Level3NutritionMonster
) -> void:

	if battle_finished:
		return

	cured_count += 1

	print(
		"[Level3] Cured: ",
		cured_count,
		"/",
		required_cures
	)

	if selected_monster == monster:
		selected_monster = null

	active_monsters.erase(monster)
	monster.queue_free()

	_update_selected_monster_ui()

	if cured_count >= required_cures:
		_finish_victory()


# ==================================================
# ESCAPE DETECTOR
# ==================================================

func _on_monster_escaped(body: Node2D) -> void:

	if battle_finished:
		return

	if not body is Level3NutritionMonster:
		return

	var monster: Level3NutritionMonster = body

	if not monster.is_active:
		return

	if monster.is_cured:
		return

	monster.mark_escaped()

	escaped_count += 1

	if selected_monster == monster:
		selected_monster = null

	active_monsters.erase(monster)
	monster.queue_free()

	print(
		"[Level3] Escaped: ",
		escaped_count,
		"/",
		maximum_escapes
	)

	_update_selected_monster_ui()

	if escaped_count >= maximum_escapes:
		_finish_game_over()


# ==================================================
# VICTORY
# ==================================================

func _finish_victory() -> void:

	if battle_finished or cured_count < required_cures or escaped_count >= maximum_escapes:
		return

	battle_finished = true
	_stop_encounter()

	var earned_stars: int = calculate_stars_for_escapes(escaped_count)

	ProgressManager.current_run_stars = earned_stars

	ProgressManager.save_level_stars(
		run_difficulty,
		LEVEL_ID,
		earned_stars
	)

	print(
		"[Level3] Victory! Stars: ",
		earned_stars
	)

	get_tree().call_deferred(
		"change_scene_to_file",
		VICTORY_SCENE
	)


# ==================================================
# GAME OVER
# ==================================================

func _finish_game_over() -> void:

	if battle_finished:
		return

	battle_finished = true
	_stop_encounter()

	ProgressManager.current_run_stars = 0

	# Do not save progress on Game Over.
	_create_game_over_screen()

	print("[Level3] GAME OVER - %d uncured escapes." % escaped_count)


# ==================================================
# HUD CREATION
# ==================================================

func _create_hud() -> void:

	hud_layer = CanvasLayer.new()
	hud_layer.name = "Level3HUD"
	add_child(hud_layer)

	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(root)

	counter_label = Label.new()
	counter_label.position = Vector2(18, 10)
	counter_label.size = Vector2(350, 28)
	counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(counter_label)

	liquid_ui = CanvasLayer.new()
	liquid_ui.name = "MonsterNutritionUI"
	liquid_ui.set_script(preload("res://Level3/scripts/ui/level3_monster_nutrition_ui.gd"))
	add_child(liquid_ui)
	nutrition_panel = liquid_ui.root_control
	_update_selected_monster_ui()


# ==================================================
# GAME OVER UI
# ==================================================

func _create_game_over_screen() -> void:

	result_layer = CanvasLayer.new()
	result_layer.layer = 20
	add_child(result_layer)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	result_layer.add_child(backdrop)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 160)
	panel.set_anchors_preset(
		Control.PRESET_CENTER
	)
	panel.position = Vector2(318, 140)
	result_layer.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)

	var title: Label = Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	column.add_child(title)

	var details: Label = Label.new()
	details.text = "%d monsters escaped without being cured." % maximum_escapes
	details.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	column.add_child(details)

	var retry: Button = Button.new()
	retry.text = "Retry Level 3"
	column.add_child(retry)
	retry.pressed.connect(_retry_level)

	var map_button: Button = Button.new()
	map_button.text = "Back to Map"
	column.add_child(map_button)
	map_button.pressed.connect(_return_to_map)


func _stop_encounter() -> void:
	if is_instance_valid(dragged_food):
		dragged_food.set_meta("is_held_for_attack", false)
		dragged_food.global_position = food_original_position
	dragged_food = null
	if is_instance_valid(conveyor):
		conveyor.call("set_dragged_food", null)
		conveyor.set_process(false)
		if conveyor is AnimatedSprite2D:
			conveyor.pause()
	var food_spawn := get_node_or_null("FoodSpawn")
	if food_spawn != null and food_spawn.has_method("stop_spawning"):
		food_spawn.call("stop_spawning")
	for monster in active_monsters:
		if is_instance_valid(monster):
			monster.is_active = false
			monster._stop_movement()
			var animation := monster.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if animation:
				animation.pause()
	selected_monster = null
	_update_selected_monster_ui()


func _retry_level() -> void:
	get_tree().reload_current_scene()


func _return_to_map() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)
