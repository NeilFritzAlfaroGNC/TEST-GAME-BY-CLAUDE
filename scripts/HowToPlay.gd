extends Control
## How to Play screen (from the Main Menu). Static instructions plus a button
## to (re)play the guided tutorial at any time.

func _ready() -> void:
	Audio.play_music("music")

func _on_tutorial_pressed() -> void:
	Audio.play("click")
	GameData.start_tutorial()
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_back_pressed() -> void:
	Audio.play("click")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
