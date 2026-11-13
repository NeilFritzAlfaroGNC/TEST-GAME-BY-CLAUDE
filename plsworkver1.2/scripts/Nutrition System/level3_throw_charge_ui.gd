extends ThrowChargeUI
class_name Level3ThrowChargeUI

# ==================================================
# LEVEL 3 — THROW CHARGE AND PLAYER BUFF HUD
# GODOT 4.7.1
# ==================================================
#
# Prepared for future Level 3 gameplay.
#
# INHERITED FEATURES:
# - GO, GLOW and GROW charge indicators
# - Selected category outline
# - Ready-to-throw glow
# - Nutrition HUD alignment
# - Manual positioning
# - Charge percentage display
# - Damage boost indicator and countdown
# - Cooldown reduction indicator and countdown
# - Charge boost indicator and countdown
# - Buff expiration updates
#
# LEVEL 3 ADAPTATION:
# - Connect to Level3GameplayController
# - Refresh HUD on battle start
# - Refresh HUD on battle stop
#
# Existing Cafeteria HUD remains unchanged.
# ==================================================


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:

	# Initialize all inherited UI systems.
	super._ready()

	# The parent ThrowChargeUI already connects:
	# - ThrowChargeSystem signals
	# - ItemThrowController category selection
	# - ItemThrowController combat buff signals
	# - NutritionUI visibility
	#
	# Only the Level 3 coordinator requires
	# an additional connection.

	var battle: Node = get_parent()

	if not is_instance_valid(battle):
		push_error(
			"[Level3ThrowChargeUI] Battle scene missing."
		)
		return

	var coordinator: Level3GameplayController = (
		battle.get_node_or_null(
			"Level3GameplayController"
		) as Level3GameplayController
	)

	if coordinator == null:
		push_warning(
			"[Level3ThrowChargeUI] "
			+ "Level3GameplayController not found. "
			+ "Battle start/stop refresh unavailable."
		)
		return

	if not is_instance_valid(display_control):
		push_error(
			"[Level3ThrowChargeUI] "
			+ "Inherited HUD did not initialize."
		)
		return

	# ----------------------------------------------
	# BATTLE START
	# ----------------------------------------------

	if not coordinator.level_systems_started.is_connected(
		_on_level3_systems_started
	):
		coordinator.level_systems_started.connect(
			_on_level3_systems_started
		)

	# ----------------------------------------------
	# BATTLE STOP
	# ----------------------------------------------

	if not coordinator.level_systems_stopped.is_connected(
		_on_level3_systems_stopped
	):
		coordinator.level_systems_stopped.connect(
			_on_level3_systems_stopped
		)

	if show_debug_messages:
		print(
			"[Level3ThrowChargeUI] "
			+ "Level 3 coordinator connected."
		)


# ==================================================
# BATTLE STARTED
# ==================================================

func _on_level3_systems_started() -> void:

	if not is_instance_valid(display_control):
		return

	display_control.queue_redraw()

	if show_debug_messages:
		print(
			"[Level3ThrowChargeUI] "
			+ "Battle started. HUD refreshed."
		)


# ==================================================
# BATTLE STOPPED
# ==================================================

func _on_level3_systems_stopped() -> void:

	if not is_instance_valid(display_control):
		return

	display_control.queue_redraw()

	if show_debug_messages:
		print(
			"[Level3ThrowChargeUI] "
			+ "Battle stopped. HUD refreshed."
		)
