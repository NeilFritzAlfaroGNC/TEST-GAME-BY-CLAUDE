extends Control
## Pause overlay inside Main.tscn ("PausePopup/Root").
## Its process_mode is ALWAYS (set in the scene) so Esc and its buttons keep
## working while the tree is paused — everything else in the level (enemies,
## spawn timers, belt foods, camera shake) freezes via get_tree().paused.
## Leaving mid-level records NO result: progress only saves on a win/lose.
## The scene connects HUD pause, resume, retry, level-select and menu buttons
## to these handlers; pause mode is set in the scene so the overlay keeps processing.

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle()
		get_viewport().set_input_as_handled()

# The Android system Back button pauses/resumes instead of killing the game.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle()

# The HUD "Pause" button (wired in Main.tscn). While paused the HUD itself is
# frozen, so this only ever opens the menu; Esc or Resume closes it.
func _on_pause_button_pressed() -> void:
	_toggle()

func _toggle() -> void:
	var main: Node = get_tree().current_scene
	if main != null and bool(main.get("_tutorial_overlay_active")):
		return
	if get_tree().paused:
		_resume()
	else:
		_pause()

func _pause() -> void:
	# The tutorial owns the tree pause while its overlay is active.
	var main = get_tree().current_scene
	if main == null or not main.game_active or bool(main.get("_tutorial_overlay_active")):
		return
	# Return any held food to the belt first: a mouse release during the pause
	# would otherwise complete the drop (and could feed the Hero) on resume.
	for f in main.foods_container.get_children():
		if is_instance_valid(f) and f.dragging:
			f.cancel_drag()
	Audio.play("click")
	get_tree().paused = true
	visible = true

func _resume() -> void:
	Audio.play("click")
	get_tree().paused = false
	visible = false

func _on_resume_pressed() -> void:
	_resume()

func _on_retry_pressed() -> void:
	Audio.play("click")
	_leave("res://scenes/Main.tscn", true)

func _on_level_select_pressed() -> void:
	Audio.play("click")
	GameData.tutorial_mode = false
	_leave("res://scenes/LevelSelect.tscn", false)

func _on_menu_pressed() -> void:
	Audio.play("click")
	GameData.tutorial_mode = false
	_leave("res://scenes/MainMenu.tscn", false)

# Quitting out of a paused level: the tree MUST be unpaused first or the next
# scene loads frozen.
func _leave(scene_path: String, restart: bool) -> void:
	get_tree().paused = false
	if restart:
		if GameData.tutorial_mode:
			GameData.start_tutorial()   # retrying the tutorial stays a tutorial
		else:
			GameData.start_level(GameData.current_difficulty, GameData.current_level)
	get_tree().change_scene_to_file(scene_path)
