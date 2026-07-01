extends Control
## Level select: pick a difficulty (Easy/Medium/Hard) and a numbered level.
## Levels unlock in order per difficulty; stars/locks come from the DB (SQLite).

@onready var grid: GridContainer = $Center/VBox/Grid
@onready var info: Label = $Center/VBox/Info
@onready var easy_btn: Button = $Center/VBox/DifficultyRow/EasyButton
@onready var medium_btn: Button = $Center/VBox/DifficultyRow/MediumButton
@onready var hard_btn: Button = $Center/VBox/DifficultyRow/HardButton

var difficulty: String = "Easy"

func _ready() -> void:
	Audio.play_music("music")
	difficulty = GameData.current_difficulty
	easy_btn.pressed.connect(func(): _set_difficulty("Easy"))
	medium_btn.pressed.connect(func(): _set_difficulty("Medium"))
	hard_btn.pressed.connect(func(): _set_difficulty("Hard"))
	$Center/VBox/BackButton.pressed.connect(_on_back)
	_refresh()

func _set_difficulty(d: String) -> void:
	Audio.play("click")
	difficulty = d
	_refresh()

func _refresh() -> void:
	GameData.current_difficulty = difficulty
	_highlight_difficulty()
	var diff: Dictionary = GameData.DIFFICULTIES[difficulty]
	info.text = "%s:  %d lives  •  x%d points  •  %s monsters" % [
		difficulty, int(diff["lives"]), int(diff["score_mult"]), _speed_word(diff)
	]
	_build_grid()

func _highlight_difficulty() -> void:
	var buttons := {"Easy": easy_btn, "Medium": medium_btn, "Hard": hard_btn}
	for key in buttons:
		var b: Button = buttons[key]
		if key == difficulty:
			b.modulate = Color(1.0, 0.85, 0.3)   # gold = selected
		else:
			b.modulate = Color(0.8, 0.82, 0.88)

func _speed_word(diff: Dictionary) -> String:
	var m: float = float(diff["speed_mult"])
	if m < 0.9:
		return "slow"
	if m > 1.1:
		return "fast"
	return "normal"

func _build_grid() -> void:
	for c in grid.get_children():
		c.queue_free()
	for n in range(1, GameData.num_levels() + 1):
		var prog: Dictionary = DB.get_level_progress(difficulty, n)
		var unlocked: bool = DB.is_level_unlocked(difficulty, n)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(150, 96)
		btn.add_theme_font_size_override("font_size", 22)
		if unlocked:
			btn.text = "Level %d\n%s" % [n, _stars(int(prog["stars"]))]
			btn.pressed.connect(_on_level_pressed.bind(n))
		else:
			btn.text = "Level %d\nLocked" % n
			btn.disabled = true
		grid.add_child(btn)
	# One locked "coming soon" slot (shown for every difficulty) — reserved for
	# a future content update. Always disabled.
	var soon := Button.new()
	soon.custom_minimum_size = Vector2(150, 96)
	soon.add_theme_font_size_override("font_size", 20)
	soon.text = "Level %d\nComing Soon" % (GameData.num_levels() + 1)
	soon.disabled = true
	soon.modulate = Color(0.72, 0.72, 0.9)
	grid.add_child(soon)

func _stars(s: int) -> String:
	s = clampi(s, 0, 3)
	return "*".repeat(s) + "-".repeat(3 - s)

func _on_level_pressed(n: int) -> void:
	Audio.play("click")
	GameData.start_level(difficulty, n)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back() -> void:
	Audio.play("click")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
