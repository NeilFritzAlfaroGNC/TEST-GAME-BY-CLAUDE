extends Node
class_name Level1BattleController

# ==================================================
# LEVEL 1 - BATTLE AND SCORING CONTROLLER
# GODOT 4.7.1
#
# FEATURES:
# - Difficulty-based feeding quotas
# - Strict shared spawning quota across 3 floors
# - Independent floor spawning settings
# - Difficulty-based game-over time limits
# - Countdown HUD
# - Game Over when time expires
# - Retry button on Game Over
# - Optional custom Game Over scene
# - Accuracy and completion-time star ratings
# - Victory screen and progress saving
#
# LEVEL 1 ONLY
# ==================================================


# ==================================================
# SIGNALS
# ==================================================

signal battle_completed(
	stars: int,
	monsters_fed: int,
	elapsed_time: float,
	accuracy: float
)

signal battle_game_over(
	monsters_fed: int,
	elapsed_time: float,
	accuracy: float
)


# ==================================================
# SCENE PATHS
# ==================================================

const VICTORY_SCREEN_PATH: String = (
	"res://scenes/UI/victory_screen.tscn"
)

const LEVEL_ID: String = "cafeteria_level_1"


# ==================================================
# SCENE REFERENCES
# ==================================================

@export_group("Scene References")

@export var food_drag_controller_path: NodePath = (
	^"../FoodDragController"
)

@export var floors_root_path: NodePath = (
	^"../Level1Floors"
)


# ==================================================
# BATTLE SETTINGS
# ==================================================

@export_group("Battle Settings")

@export var automatically_start: bool = true
@export var show_hud: bool = true

@export var save_progress_on_victory: bool = false
@export var open_victory_screen: bool = false


# ==================================================
# GAME OVER SETTINGS
# ==================================================

@export_group("Game Over Settings")

@export var enable_time_limit: bool = true

# Optional custom scene.
# Leave empty to use the built-in Game Over overlay.
@export var custom_game_over_scene: PackedScene

@export var show_game_over_overlay: bool = true

# Optional main menu path for the Game Over overlay.
@export_file("*.tscn")
var main_menu_scene_path: String = ""


# ==================================================
# EASY DIFFICULTY
# ==================================================

@export_group("Easy Difficulty")

@export_range(1, 999, 1)
var easy_monster_quota: int = 15

@export_range(1.0, 3600.0, 1.0)
var easy_time_limit: float = 240.0

@export_range(1.0, 3600.0, 1.0)
var easy_three_star_time: float = 120.0

@export_range(1.0, 3600.0, 1.0)
var easy_two_star_time: float = 210.0


# ==================================================
# NORMAL DIFFICULTY
# ==================================================

@export_group("Normal Difficulty")

@export_range(1, 999, 1)
var normal_monster_quota: int = 20

@export_range(1.0, 3600.0, 1.0)
var normal_time_limit: float = 360.0

@export_range(1.0, 3600.0, 1.0)
var normal_three_star_time: float = 180.0

@export_range(1.0, 3600.0, 1.0)
var normal_two_star_time: float = 270.0


# ==================================================
# HARD DIFFICULTY
# ==================================================

@export_group("Hard Difficulty")

@export_range(1, 999, 1)
var hard_monster_quota: int = 25

@export_range(1.0, 3600.0, 1.0)
var hard_time_limit: float = 480.0

@export_range(1.0, 3600.0, 1.0)
var hard_three_star_time: float = 240.0

@export_range(1.0, 3600.0, 1.0)
var hard_two_star_time: float = 360.0


# ==================================================
# ACCURACY THRESHOLDS
# ==================================================

@export_group("Accuracy Thresholds")

@export_range(0.0, 100.0, 1.0)
var three_star_accuracy_percent: float = 90.0

@export_range(0.0, 100.0, 1.0)
var two_star_accuracy_percent: float = 75.0


# ==================================================
# FLOOR 1 SPAWNING
# ==================================================

@export_group("Floor 1 Spawning")

@export_range(1, 3, 1)
var floor_1_maximum_active_enemies: int = 3

@export_range(0.1, 60.0, 0.1)
var floor_1_minimum_spawn_interval: float = 2.0

@export_range(0.1, 60.0, 0.1)
var floor_1_maximum_spawn_interval: float = 4.0


# ==================================================
# FLOOR 2 SPAWNING
# ==================================================

@export_group("Floor 2 Spawning")

@export_range(1, 3, 1)
var floor_2_maximum_active_enemies: int = 3

@export_range(0.1, 60.0, 0.1)
var floor_2_minimum_spawn_interval: float = 2.0

@export_range(0.1, 60.0, 0.1)
var floor_2_maximum_spawn_interval: float = 4.0


# ==================================================
# FLOOR 3 SPAWNING
# ==================================================

@export_group("Floor 3 Spawning")

@export_range(1, 3, 1)
var floor_3_maximum_active_enemies: int = 3

@export_range(0.1, 60.0, 0.1)
var floor_3_minimum_spawn_interval: float = 2.0

@export_range(0.1, 60.0, 0.1)
var floor_3_maximum_spawn_interval: float = 4.0


# ==================================================
# DEBUG
# ==================================================

@export_group("Debug")

@export var show_debug_messages: bool = true


# ==================================================
# REFERENCES
# ==================================================

var food_drag_controller: Level1FoodDragController = null

var floors_root: Node = null

var floor_spawners: Array[Level1EnemySpawner] = []

var hud_label: Label = null

var game_over_layer: CanvasLayer = null


# ==================================================
# BATTLE STATE
# ==================================================

var monsters_fed: int = 0
var missed_drops: int = 0

var elapsed_seconds: float = 0.0
var remaining_seconds: float = 0.0

var difficulty: String = "easy"

var target_monsters: int = 15
var total_enemies_spawned: int = 0

var current_time_limit: float = 240.0

var three_star_time_limit: float = 120.0
var two_star_time_limit: float = 210.0

var battle_running: bool = false
var battle_finished: bool = false
var game_over_triggered: bool = false

var final_stars: int = 0


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	if show_hud:
		_create_hud()

	_refresh_hud()

	set_process(true)

	call_deferred("_setup_battle")


# ==================================================
# SETUP
# ==================================================

func _setup_battle() -> void:

	food_drag_controller = (
		get_node_or_null(food_drag_controller_path)
		as Level1FoodDragController
	)

	if not is_instance_valid(food_drag_controller):
		push_error(
			"[Level1Battle] FoodDragController missing."
		)
		return

	if not food_drag_controller.monster_fed.is_connected(
		_on_monster_fed
	):
		food_drag_controller.monster_fed.connect(
			_on_monster_fed
		)

	if not food_drag_controller.food_drop_missed.is_connected(
		_on_food_drop_missed
	):
		food_drag_controller.food_drop_missed.connect(
			_on_food_drop_missed
		)

	food_drag_controller.set_interactions_enabled(false)

	_load_difficulty_settings()
	remaining_seconds = current_time_limit

	_configure_floor_spawners()

	_refresh_hud()

	_debug(
		"Ready | Difficulty: "
		+ difficulty
		+ " | Quota: "
		+ str(target_monsters)
		+ " | Time limit: "
		+ str(current_time_limit)
	)

	if automatically_start:
		start_battle()


# ==================================================
# LOAD DIFFICULTY
# ==================================================

func _load_difficulty_settings() -> void:

	difficulty = (
		ProgressManager.current_difficulty.to_lower()
	)

	match difficulty:

		"hard":

			target_monsters = hard_monster_quota
			current_time_limit = hard_time_limit

			three_star_time_limit = hard_three_star_time
			two_star_time_limit = hard_two_star_time

		"normal":

			target_monsters = normal_monster_quota
			current_time_limit = normal_time_limit

			three_star_time_limit = normal_three_star_time
			two_star_time_limit = normal_two_star_time

		_:

			difficulty = "easy"

			target_monsters = easy_monster_quota
			current_time_limit = easy_time_limit

			three_star_time_limit = easy_three_star_time
			two_star_time_limit = easy_two_star_time

	target_monsters = maxi(target_monsters, 1)

	current_time_limit = maxf(
		current_time_limit,
		1.0
	)

	three_star_time_limit = maxf(
		three_star_time_limit,
		1.0
	)

	two_star_time_limit = maxf(
		two_star_time_limit,
		three_star_time_limit
	)

	if enable_time_limit:

		if three_star_time_limit > current_time_limit:
			push_warning(
				"[Level1Battle] Three-star threshold "
				+ "exceeds the Game Over time limit."
			)

		if two_star_time_limit > current_time_limit:
			push_warning(
				"[Level1Battle] Two-star threshold "
				+ "exceeds the Game Over time limit."
			)


# ==================================================
# CONFIGURE FLOOR SPAWNERS
# ==================================================

func _configure_floor_spawners() -> void:

	floor_spawners.clear()

	floors_root = get_node_or_null(
		floors_root_path
	)

	if not is_instance_valid(floors_root):

		push_error(
			"[Level1Battle] Level1Floors missing."
		)
		return

	_configure_one_floor(
		"Floor1",
		floor_1_maximum_active_enemies,
		floor_1_minimum_spawn_interval,
		floor_1_maximum_spawn_interval
	)

	_configure_one_floor(
		"Floor2",
		floor_2_maximum_active_enemies,
		floor_2_minimum_spawn_interval,
		floor_2_maximum_spawn_interval
	)

	_configure_one_floor(
		"Floor3",
		floor_3_maximum_active_enemies,
		floor_3_minimum_spawn_interval,
		floor_3_maximum_spawn_interval
	)

	_debug(
		"Connected floor spawners: "
		+ str(floor_spawners.size())
	)


func _configure_one_floor(
	floor_name: String,
	max_active: int,
	min_interval: float,
	max_interval: float
) -> void:

	if not is_instance_valid(floors_root):
		return

	var floor_node: Node = (
		floors_root.get_node_or_null(floor_name)
	)

	if not is_instance_valid(floor_node):

		push_warning(
			"[Level1Battle] Floor missing: "
			+ floor_name
		)
		return

	var spawner: Level1EnemySpawner = (
		floor_node.get_node_or_null("EnemySpawner")
		as Level1EnemySpawner
	)

	if not is_instance_valid(spawner):

		push_warning(
			"[Level1Battle] EnemySpawner missing: "
			+ floor_name
		)
		return

	spawner.set_battle_controller(self)

	spawner.configure_spawn_limits(
		max_active,
		min_interval,
		max_interval
	)

	floor_spawners.append(spawner)


# ==================================================
# START BATTLE
# ==================================================

func start_battle() -> void:

	if battle_running or battle_finished:
		return

	if not is_instance_valid(food_drag_controller):

		push_error(
			"[Level1Battle] Cannot start without "
			+ "FoodDragController."
		)
		return

	if floor_spawners.is_empty():

		push_error(
			"[Level1Battle] No floor spawners configured."
		)
		return

	monsters_fed = 0
	missed_drops = 0

	elapsed_seconds = 0.0
	remaining_seconds = current_time_limit

	total_enemies_spawned = 0

	final_stars = 0
	game_over_triggered = false

	battle_running = true
	battle_finished = false

	food_drag_controller.set_interactions_enabled(true)

	for spawner in floor_spawners:

		if is_instance_valid(spawner):
			spawner.start_spawning()

	_refresh_hud()

	_debug(
		"Battle started | Time remaining: "
		+ str(remaining_seconds)
	)


# ==================================================
# GLOBAL SPAWN QUOTA
# ==================================================

func can_spawn_more_enemies() -> bool:

	if not battle_running:
		return false

	if battle_finished or game_over_triggered:
		return false

	if enable_time_limit and remaining_seconds <= 0.0:
		return false

	return total_enemies_spawned < target_monsters


func get_remaining_spawn_count() -> int:

	return maxi(
		target_monsters - total_enemies_spawned,
		0
	)


func try_register_spawn(
	spawner: Level1EnemySpawner
) -> bool:

	if not can_spawn_more_enemies():
		return false

	if not is_instance_valid(spawner):
		return false

	if not floor_spawners.has(spawner):
		return false

	if not spawner.spawning_enabled:
		return false

	total_enemies_spawned += 1

	_debug(
		"Spawned: "
		+ str(total_enemies_spawned)
		+ "/"
		+ str(target_monsters)
	)

	if total_enemies_spawned >= target_monsters:

		_debug(
			"Global spawn quota reached."
		)

		_stop_floor_spawners()

	_refresh_hud()

	return true


# ==================================================
# BATTLE TIMER
# ==================================================

func _process(delta: float) -> void:

	if not battle_running:
		return

	if battle_finished or game_over_triggered:
		return

	elapsed_seconds += delta

	if enable_time_limit:

		remaining_seconds = maxf(
			current_time_limit - elapsed_seconds,
			0.0
		)

		if remaining_seconds <= 0.0:

			_trigger_game_over()
			return

	_refresh_hud()


# ==================================================
# SUCCESSFUL FEED
# ==================================================

func _on_monster_fed() -> void:

	if not battle_running:
		return

	if battle_finished or game_over_triggered:
		return

	if enable_time_limit and remaining_seconds <= 0.0:
		_trigger_game_over()
		return

	monsters_fed += 1

	_debug(
		"Monsters fed: "
		+ str(monsters_fed)
		+ "/"
		+ str(target_monsters)
	)

	_refresh_hud()

	if monsters_fed >= target_monsters:
		_complete_battle()


# ==================================================
# MISSED DROP
# ==================================================

func _on_food_drop_missed() -> void:

	if not battle_running:
		return

	if battle_finished or game_over_triggered:
		return

	missed_drops += 1

	_refresh_hud()


# ==================================================
# ACCURACY
# ==================================================

func get_accuracy_percent() -> float:

	var total_attempts: int = (
		monsters_fed + missed_drops
	)

	if total_attempts <= 0:
		return 100.0

	return (
		float(monsters_fed)
		/ float(total_attempts)
	) * 100.0


# ==================================================
# STAR CALCULATION
# ==================================================

func calculate_final_stars() -> int:

	var accuracy: float = get_accuracy_percent()

	if (
		elapsed_seconds <= three_star_time_limit
		and accuracy >= three_star_accuracy_percent
	):
		return 3

	if (
		elapsed_seconds <= two_star_time_limit
		and accuracy >= two_star_accuracy_percent
	):
		return 2

	return 1


# ==================================================
# VICTORY
# ==================================================

func _complete_battle() -> void:

	if battle_finished or game_over_triggered:
		return

	battle_finished = true
	battle_running = false

	final_stars = calculate_final_stars()

	if is_instance_valid(food_drag_controller):

		food_drag_controller.set_interactions_enabled(
			false
		)

	_stop_floor_spawners()

	get_parent().process_mode = (
		Node.PROCESS_MODE_DISABLED
	)

	_refresh_hud()

	var accuracy: float = get_accuracy_percent()

	_debug("=================================")
	_debug("LEVEL 1 COMPLETED")
	_debug(
		"Monsters spawned: "
		+ str(total_enemies_spawned)
	)
	_debug(
		"Monsters fed: "
		+ str(monsters_fed)
	)
	_debug(
		"Time: "
		+ str(snappedf(elapsed_seconds, 0.1))
	)
	_debug(
		"Accuracy: "
		+ str(snappedf(accuracy, 0.1))
	)
	_debug("Stars: " + str(final_stars))
	_debug("=================================")

	if open_victory_screen or save_progress_on_victory:

		ProgressManager.current_run_stars = final_stars
		ProgressManager.last_completed_level_id = LEVEL_ID

	if save_progress_on_victory:

		ProgressManager.save_level_stars(
			difficulty,
			LEVEL_ID,
			final_stars
		)

	battle_completed.emit(
		final_stars,
		monsters_fed,
		elapsed_seconds,
		accuracy
	)

	if open_victory_screen:

		call_deferred("_open_victory_screen")


# ==================================================
# GAME OVER
# ==================================================

func _trigger_game_over() -> void:

	if battle_finished or game_over_triggered:
		return

	game_over_triggered = true

	battle_running = false
	battle_finished = true

	final_stars = 0

	remaining_seconds = 0.0

	if is_instance_valid(food_drag_controller):

		food_drag_controller.set_interactions_enabled(
			false
		)

	_stop_floor_spawners()

	_refresh_hud()

	var accuracy: float = get_accuracy_percent()

	_debug("=================================")
	_debug("LEVEL 1 GAME OVER")
	_debug("Reason: Time limit reached")
	_debug(
		"Monsters fed: "
		+ str(monsters_fed)
		+ "/"
		+ str(target_monsters)
	)
	_debug(
		"Total spawned: "
		+ str(total_enemies_spawned)
	)
	_debug("Stars: 0")
	_debug("=================================")

	# Stop the gameplay scene but let this controller
	# and its Game Over UI continue processing.
	process_mode = Node.PROCESS_MODE_ALWAYS

	get_parent().process_mode = (
		Node.PROCESS_MODE_DISABLED
	)

	battle_game_over.emit(
		monsters_fed,
		elapsed_seconds,
		accuracy
	)

	if custom_game_over_scene != null:

		call_deferred(
			"_open_custom_game_over_scene"
		)

	elif show_game_over_overlay:

		call_deferred(
			"_show_game_over_overlay"
		)


# ==================================================
# STOP FLOOR SPAWNERS
# ==================================================

func _stop_floor_spawners() -> void:

	for spawner in floor_spawners:

		if not is_instance_valid(spawner):
			continue

		spawner.stop_spawning()


# ==================================================
# OPEN VICTORY SCREEN
# ==================================================

func _open_victory_screen() -> void:

	if not is_inside_tree():
		return

	var error: Error = (
		get_tree().change_scene_to_file(
			VICTORY_SCREEN_PATH
		)
	)

	if error != OK:

		push_error(
			"[Level1Battle] Victory scene failed: "
			+ str(error)
		)


# ==================================================
# OPEN CUSTOM GAME OVER SCENE
# ==================================================

func _open_custom_game_over_scene() -> void:

	if not is_inside_tree():
		return

	if custom_game_over_scene == null:
		_show_game_over_overlay()
		return

	var error: Error = (
		get_tree().change_scene_to_packed(
			custom_game_over_scene
		)
	)

	if error != OK:

		push_error(
			"[Level1Battle] Game Over scene failed: "
			+ str(error)
		)

		_show_game_over_overlay()


# ==================================================
# BUILT-IN GAME OVER OVERLAY
# ==================================================

func _show_game_over_overlay() -> void:

	if not is_inside_tree():
		return

	if is_instance_valid(game_over_layer):
		return

	game_over_layer = CanvasLayer.new()

	game_over_layer.name = "Level1GameOver"
	game_over_layer.layer = 100
	game_over_layer.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(game_over_layer)

	# Fill the entire screen.
	var backdrop: ColorRect = ColorRect.new()

	backdrop.name = "Backdrop"

	backdrop.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	backdrop.color = Color(
		0.04,
		0.07,
		0.09,
		0.88
	)

	backdrop.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)

	game_over_layer.add_child(backdrop)

	# Keep the layout centered.
	var center: CenterContainer = CenterContainer.new()

	center.name = "GameOverCenter"

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	game_over_layer.add_child(center)

	var panel: PanelContainer = PanelContainer.new()

	panel.custom_minimum_size = Vector2(
		350.0,
		250.0
	)

	center.add_child(panel)

	var style: StyleBoxFlat = StyleBoxFlat.new()

	style.bg_color = Color("#172322")
	style.border_color = Color("#ce7777")

	style.set_border_width_all(2)
	style.set_corner_radius_all(12)

	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22

	panel.add_theme_stylebox_override(
		"panel",
		style
	)

	var content: VBoxContainer = VBoxContainer.new()

	content.add_theme_constant_override(
		"separation",
		16
	)

	panel.add_child(content)

	var title_label: Label = Label.new()

	title_label.text = "GAME OVER"

	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title_label.add_theme_font_size_override(
		"font_size",
		32
	)

	title_label.add_theme_color_override(
		"font_color",
		Color("#ff9d9d")
	)

	content.add_child(title_label)

	var reason_label: Label = Label.new()

	reason_label.text = (
		"Time's up!\n"
		+ "Monsters fed: "
		+ str(monsters_fed)
		+ " / "
		+ str(target_monsters)
		+ "\n"
		+ "No stars earned."
	)

	reason_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	reason_label.add_theme_font_size_override(
		"font_size",
		17
	)

	content.add_child(reason_label)

	var retry_button: Button = Button.new()

	retry_button.text = "Retry Level 1"

	retry_button.custom_minimum_size = Vector2(
		220.0,
		44.0
	)

	content.add_child(retry_button)

	retry_button.pressed.connect(
		_retry_level
	)

	if not main_menu_scene_path.is_empty():

		var menu_button: Button = Button.new()

		menu_button.text = "Main Menu"

		menu_button.custom_minimum_size = Vector2(
			220.0,
			40.0
		)

		content.add_child(menu_button)

		menu_button.pressed.connect(
			_return_to_main_menu
		)

	retry_button.grab_focus()


# ==================================================
# RETRY LEVEL
# ==================================================

func _retry_level() -> void:

	if not is_inside_tree():
		return

	var error: Error = (
		get_tree().reload_current_scene()
	)

	if error != OK:

		push_error(
			"[Level1Battle] Retry failed: "
			+ str(error)
		)


# ==================================================
# RETURN TO MAIN MENU
# ==================================================

func _return_to_main_menu() -> void:

	if main_menu_scene_path.is_empty():
		return

	if not ResourceLoader.exists(
		main_menu_scene_path
	):

		push_error(
			"[Level1Battle] Main Menu scene not found: "
			+ main_menu_scene_path
		)
		return

	var error: Error = (
		get_tree().change_scene_to_file(
			main_menu_scene_path
		)
	)

	if error != OK:

		push_error(
			"[Level1Battle] Main Menu failed: "
			+ str(error)
		)


# ==================================================
# HUD
# ==================================================

func _create_hud() -> void:

	var layer: CanvasLayer = CanvasLayer.new()

	layer.name = "Level1ScoreHUD"
	layer.layer = 10

	add_child(layer)

	var placement: CenterContainer = (
		CenterContainer.new()
	)

	placement.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	layer.add_child(placement)

	placement.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_WIDE
	)

	placement.offset_top = 8.0

	var panel: PanelContainer = PanelContainer.new()

	panel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	placement.add_child(panel)

	var background: StyleBoxFlat = StyleBoxFlat.new()

	background.bg_color = Color("#172322ed")
	background.border_color = Color("#91b6a5")

	background.set_border_width_all(1)
	background.set_corner_radius_all(8)

	background.content_margin_left = 14.0
	background.content_margin_right = 14.0
	background.content_margin_top = 6.0
	background.content_margin_bottom = 6.0

	panel.add_theme_stylebox_override(
		"panel",
		background
	)

	hud_label = Label.new()

	hud_label.name = "ScoreLabel"

	hud_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	hud_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	hud_label.add_theme_font_size_override(
		"font_size",
		16
	)

	hud_label.add_theme_color_override(
		"font_color",
		Color("#fff8e8")
	)

	panel.add_child(hud_label)


# ==================================================
# REFRESH HUD
# ==================================================

func _refresh_hud() -> void:

	if not is_instance_valid(hud_label):
		return

	var minutes: int = 0
	var seconds: int = 0

	if enable_time_limit:

		# Ceil prevents displaying 00:00 early.
		var time_left: int = maxi(
			ceili(remaining_seconds),
			0
		)

		minutes = floori(time_left / 60.0)
		seconds = time_left % 60

	else:

		var elapsed: int = maxi(
			int(elapsed_seconds),
			0
		)

		minutes = floori(elapsed / 60.0)
		seconds = elapsed % 60

	var accuracy_text: String = "—"

	if monsters_fed + missed_drops > 0:

		accuracy_text = (
			"%.1f%%" % get_accuracy_percent()
		)

	var time_caption: String = (
		"Time left" if enable_time_limit else "Time"
	)

	var hud_text: String = (
		"Monsters fed  %d / %d"
		+ "     •     Spawned  %d / %d"
		+ "     •     %s  %02d:%02d"
		+ "     •     Accuracy  %s"
	) % [
		monsters_fed,
		target_monsters,
		total_enemies_spawned,
		target_monsters,
		time_caption,
		minutes,
		seconds,
		accuracy_text
	]

	if game_over_triggered:

		hud_text += "\nGAME OVER - Time's up!"

	elif battle_finished:

		var star_label: String = (
			"star" if final_stars == 1 else "stars"
		)

		hud_text += (
			"\nVictory  •  %d %s"
			% [
				final_stars,
				star_label
			]
		)

	if hud_label.text != hud_text:
		hud_label.text = hud_text


# ==================================================
# DEBUG
# ==================================================

func _debug(message: String) -> void:

	if show_debug_messages:

		print(
			"[Level1Battle] ",
			message
		)
