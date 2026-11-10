@tool
extends Node2D
class_name Level1Floor

# ==================================================
# LEVEL 1 - MANUALLY ADJUSTABLE FLOOR
# GODOT 4.7.1
# ==================================================
#
# The floor now uses manually placed:
#
# Platform
# LeftWall
# RightWall
#
# Each is a StaticBody2D with a
# CollisionShape2D and RectangleShape2D.
#
# This script does NOT create collisions.
# This script does NOT draw gray platforms.
#
# Move or resize collisions directly
# using the Godot 2D editor.
#
# The existing EnemySpawner is preserved.
#
# LEVEL 1 ONLY.
# ==================================================


# ==================================================
# INSPECTOR SETTINGS
# ==================================================

@export_group("Floor Settings")

@export var floor_enabled: bool = true:
	set(value):
		floor_enabled = value
		if is_inside_tree():
			_update_floor_state()


@export_group("Debug")

@export var show_debug_messages: bool = false


# ==================================================
# INITIALIZATION
# ==================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_update_floor_state()

	if show_debug_messages:
		print(
			"[Level1Floor] Ready: ",
			name
		)


# ==================================================
# ENABLE / DISABLE FLOOR COLLISIONS
# ==================================================

func _update_floor_state() -> void:
	if Engine.is_editor_hint():
		return

	for body_name in [
		"Platform",
		"LeftWall",
		"RightWall"
	]:
		var body: StaticBody2D = (
			get_node_or_null(body_name)
			as StaticBody2D
		)

		if not is_instance_valid(body):
			push_warning(
				"[Level1Floor] Missing collision body: "
				+ body_name
				+ " on "
				+ name
			)
			continue

		for child in body.get_children():
			if child is CollisionShape2D:
				var collision: CollisionShape2D = (
					child as CollisionShape2D
				)

				collision.set_deferred(
					"disabled",
					not floor_enabled
				)
