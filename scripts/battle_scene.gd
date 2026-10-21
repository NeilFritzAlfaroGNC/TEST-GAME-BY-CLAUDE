extends Node2D
class_name BattleScene
## Runs the battle. Shows the countdown and hit counter on the BattleHUD.
## - Surviving until the timer reaches zero is a WIN, rated by hits taken:
##   0 hits = 3 stars, 1 hit = 2 stars, 2 hits = 1 star.
## - Taking max_hits (3) hits ends the battle at once as FAILED (game over).
## Either way the game is paused and the end panel appears.
## Winning saves the stars and unlocks the next level (GameProgress autoload);
## the end panel then offers Next Level above Retry. When failed, Retry is on top.

signal battle_won(stars: int)
signal battle_failed()

@export var battle_duration: float = 20.0 #Seconds; also stops the enemy spawner at the same time
@export var max_hits: int = 3 #Hits on the main character that end the battle as failed
@export_file("*.tscn") var map_scene: String = "res://scene/level_map_screen.tscn"
@export_file("*.tscn") var menu_scene: String = "res://scene/main_menu.tscn"

@onready var timer_label: Label = $BattleHUD/TimerLabel
@onready var hits_label: Label = $BattleHUD/HitsLabel
@onready var end_panel: Control = $BattleHUD/EndPanel
@onready var title_label: Label = $BattleHUD/EndPanel/Column/TitleLabel
@onready var stars_row: Control = $BattleHUD/EndPanel/Column/Stars
@onready var result_label: Label = $BattleHUD/EndPanel/Column/ResultLabel

var time_left: float = 0.0
var player_hits: int = 0
var enemies_defeated: int = 0
var stars: int = 0
var won: bool = false
var ended: bool = false

func _ready() -> void:
	add_to_group("battle") #Enemies and the main character report to this group
	time_left = battle_duration
	if has_node("EnemySpawner"):
		$EnemySpawner.spawn_duration = battle_duration
	end_panel.hide()
	$BattleHUD/EndPanel/Column/NextButton.pressed.connect(_next_level)
	$BattleHUD/EndPanel/Column/RetryButton.pressed.connect(_retry)
	$BattleHUD/EndPanel/Column/MapButton.pressed.connect(_go_to.bind(map_scene))
	$BattleHUD/EndPanel/Column/MenuButton.pressed.connect(_go_to.bind(menu_scene))
	_update_labels()

func _process(delta: float) -> void:
	if ended:
		return
	time_left = maxf(time_left - delta, 0.0)
	_update_labels()
	if time_left <= 0.0:
		end_battle(true) #Survived the whole timer

# Called by enemy_1.gd (through the "battle" group) when a food removes an enemy.
func on_enemy_defeated() -> void:
	enemies_defeated += 1

# Called by mainchar.gd (through the "battle" group) each time an enemy attack lands.
func on_player_hit() -> void:
	if ended:
		return
	player_hits += 1
	_update_labels()
	if player_hits >= max_hits:
		end_battle(false) #Game over

# 3 stars with no hits, one star less per hit; 0 when failed.
func stars_for_hits(hits: int) -> int:
	return clampi(max_hits - hits, 0, 3)

# Stop the battle: freeze everything and show the end panel.
func end_battle(success: bool) -> void:
	if ended:
		return
	ended = true
	won = success
	stars = stars_for_hits(player_hits) if success else 0
	var level: int = GameProgress.current_level
	if success:
		GameProgress.complete_level(level, stars) #Saves stars, unlocks the next level
	# Next Level only after a win (and if there is one); it sits above Retry.
	$BattleHUD/EndPanel/Column/NextButton.visible = success and GameProgress.has_next_level(level)
	title_label.text = ("Level %d Complete!" % level) if success else "Game Over"
	title_label.modulate = Color.WHITE if success else Color(1, 0.45, 0.45)
	for i in stars_row.get_child_count():
		stars_row.get_child(i).filled = i < stars
	var outcome: String = "Failed"
	if success:
		outcome = "Success!" if GameProgress.has_next_level(level) else "Success! All levels complete!"
	result_label.text = "%s\nHits taken: %d   Enemies defeated: %d" % [outcome, player_hits, enemies_defeated]
	end_panel.show()
	if success:
		battle_won.emit(stars)
	else:
		battle_failed.emit()
	get_tree().paused = true

func _update_labels() -> void:
	timer_label.text = "Level %d   Time: %d" % [GameProgress.current_level, ceili(time_left)]
	hits_label.text = "Hits: %d / %d" % [player_hits, max_hits]

func _next_level() -> void:
	GameProgress.current_level += 1
	_retry() #Same battle scene, next level number

func _retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _go_to(scene_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)
