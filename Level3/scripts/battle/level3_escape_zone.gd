extends Area2D
class_name Level3EscapeZone

@export_node_path("Node") var battle_controller_path: NodePath = ^".."
@export var enable_escape_detection: bool = true
@export var print_escape_debug: bool = true
var battle_controller: Node

func _ready() -> void:
	battle_controller = get_node_or_null(battle_controller_path)
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_monster_body_entered)
	if battle_controller == null:
		push_error("[Level3Escape] Battle controller missing.")

func _on_monster_body_entered(body: Node2D) -> void:
	if not enable_escape_detection or not body is Level3NutritionMonster:
		return
	if not body.is_active or body.is_cured or not is_instance_valid(battle_controller):
		return
	if battle_controller.battle_finished:
		return
	battle_controller._on_monster_escaped(body)
	if print_escape_debug:
		print("[Level3Escape] Uncured monster escaped: ", battle_controller.escaped_count)
