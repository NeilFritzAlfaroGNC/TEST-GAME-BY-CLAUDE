
extends Resource
class_name EnemyStatOverride

@export_group("Enemy")
@export var enemy_scene: PackedScene

@export_group("Health Override")
@export var override_health: bool = false
@export_range(1, 9999, 1) var health: int = 5

@export_group("Attack Override")
@export var override_attack: bool = false
@export_range(0, 9999, 1) var attack: int = 5

@export_group("Movement Override")
@export var override_move_speed: bool = false
@export_range(0.0, 2000.0, 1.0) var move_speed: float = 60.0

@export_group("Attack Timing Override")
@export var override_attack_interval: bool = false
@export_range(0.05, 20.0, 0.05) var attack_interval: float = 1.5
@export var override_first_attack_delay: bool = false
@export_range(0.0, 10.0, 0.05) var first_attack_delay: float = 0.0

@export_group("Nutrition Damage Override")
@export var override_nutrition_damage_multiplier: bool = false
@export_range(1, 100, 1) var nutrition_damage_multiplier: int = 10
@export var override_nutrition_damage_category: bool = false
@export_enum("GO", "GLOW", "GROW") var nutrition_damage_category: int = NutritionSystem.FoodType.GROW
