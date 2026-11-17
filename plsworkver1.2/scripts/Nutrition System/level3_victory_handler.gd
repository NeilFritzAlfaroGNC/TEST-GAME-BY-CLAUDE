extends Node
class_name Level3VictoryHandler

# ==================================================
# LEVEL 3 — VICTORY HANDLER
# GODOT 4.7.1
# ==================================================
#
# Prepared for future Level 3 gameplay.
#
# Responsibilities:
# - Listen for accepted Level 3 victories
# - Calculate current-run stars
# - Prevent duplicate victory processing
# - Preserve future progression compatibility
#
# Does NOT:
# - Save progression
# - Open the Victory screen
# - Modify the existing levels
# ==================================================


signal victory_result_ready(stars: int, hits: int)


@export_group("Level 3 Victory Settings")
@export var automatically_connect_controller: bool = true

@export_group("Scene References")
@export var gameplay_controller_path: NodePath = ^"Level3GameplayController"

@export_group("Debugging")
@export var print_debug_messages: bool = true


var gameplay_controller: Level3GameplayController = null
var victory_processed: bool = false
var hits_received: int = 0
var current_stars: int = 0


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	if automatically_connect_controller:
		_connect_gameplay_controller.call_deferred()


# ==================================================
# CONNECT GAMEPLAY CONTROLLER
# ==================================================

func _connect_gameplay_controller() -> void:
	if not is_inside_tree():
		return

	var battle: Node = get_parent()

	if battle == null:
		push_error(
			"[Level3Victory] Parent battle scene missing."
		)
		return

	gameplay_controller = (
		battle.get_node_or_null(gameplay_controller_path)
		as Level3GameplayController
	)

	if gameplay_controller == null:
		push_error(
			"[Level3Victory] Level3GameplayController missing."
		)
		return

	if not gameplay_controller.level_victory_accepted.is_connected(
		_on_victory_accepted
	):
		gameplay_controller.level_victory_accepted.connect(
			_on_victory_accepted
		)

	if print_debug_messages:
		print(
			"[Level3Victory] Victory signal connected."
		)


# ==================================================
# RECORD PLAYER HIT
# ==================================================
#
# The future battle scene should call this only
# when a genuine enemy hit is registered.
# ==================================================

func register_player_hit() -> void:
	if victory_processed:
		return

	if not is_instance_valid(gameplay_controller):
		return

	if not gameplay_controller.battle_started:
		return

	if gameplay_controller.battle_finished:
		return

	hits_received += 1

	if print_debug_messages:
		print(
			"[Level3Victory] Player hits: ",
			hits_received
		)


# ==================================================
# VICTORY ACCEPTED
# ==================================================

func _on_victory_accepted() -> void:
	if victory_processed:
		return

	if not is_instance_valid(gameplay_controller):
		return

	if not gameplay_controller.battle_finished:
		return

	victory_processed = true

	current_stars = ProgressManager.calculate_stars(
		hits_received
	)

	if print_debug_messages:
		print(
			"[Level3Victory] Victory accepted. "
			+ "Hits: ",
			hits_received,
			" | Stars: ",
			current_stars
		)

	victory_result_ready.emit(
		current_stars,
		hits_received
	)


# ==================================================
# RESET
# ==================================================

func reset_victory_tracking() -> void:
	if is_instance_valid(gameplay_controller):
		if gameplay_controller.battle_started:
			push_warning(
				"[Level3Victory] Cannot reset "
				+ "during an active battle."
			)
			return

	victory_processed = false
	hits_received = 0
	current_stars = 0

	if print_debug_messages:
		print(
			"[Level3Victory] Tracking reset."
		)
