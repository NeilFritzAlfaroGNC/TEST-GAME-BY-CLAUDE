extends Control
## Level select: pick a difficulty (Easy/Medium/Hard) and a numbered level.
## Levels unlock in order per difficulty; stars/locks come from the DB (SQLite).
##
## GRID WIDTH: 15 levels + 1 "coming soon" tile no longer fit a fixed 3-column
## grid inside the design box's fixed 648-unit height without the rows running
## off the bottom. Tile size stays fixed at TILE_SIZE (150 units wide is
## ~15mm on a 6.1" phone per the project's own arithmetic, against a ~9mm
## minimum, so it must not shrink) — instead the COLUMN COUNT adapts to
## Layout.m["view"].x, which grows from 1152 (16:9) to ~1512 (21:9), so a
## wider device gets more columns and fewer rows instead of overflow.

const TILE_SIZE := Vector2(150, 96)
const TILE_H_SEP := 16.0   # must match Grid's theme_override_constants/h_separation

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
	if not Layout.changed.is_connected(_build_grid):
		Layout.changed.connect(_build_grid)
	_refresh()

# How many tiles fit per row at the current viewport without shrinking TILE_SIZE.
# Never below 3 (defensive floor; the narrowest supported view already fits 6).
func _grid_columns() -> int:
	# Layout.m["safe"] excludes any device cutout (notch/rounded corner) inset;
	# sizing from the raw view instead (as this used to) can pack a column's
	# worth of tiles into that dead margin, landing the leftmost tile under a
	# left-edge cutout.
	var avail_x: float = Layout.m["safe"].size.x
	var per_col: float = TILE_SIZE.x + TILE_H_SEP
	var cols: int = int(floor((avail_x + TILE_H_SEP) / per_col))
	return maxi(cols, 3)

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
	grid.columns = _grid_columns()
	for c in grid.get_children():
		c.queue_free()
	for n in range(1, GameData.num_levels() + 1):
		var prog: Dictionary = DB.get_level_progress(difficulty, n)
		var unlocked: bool = DB.is_level_unlocked(difficulty, n)
		var btn := Button.new()
		btn.custom_minimum_size = TILE_SIZE
		btn.add_theme_font_size_override("font_size", 22)
		# Boss levels get a badge so the player knows a boss fight is coming.
		var title := ("BOSS %d" % n) if GameData.is_boss_level(n) else ("Level %d" % n)
		if unlocked:
			btn.text = "%s\n%s" % [title, GameData.stars_text(int(prog["stars"]))]
			btn.pressed.connect(_on_level_pressed.bind(n))
		else:
			btn.text = "%s\nLocked" % title
			btn.disabled = true
		if GameData.is_boss_level(n):
			btn.modulate = Color(0.95, 0.75, 1.0)   # light purple = boss tile
		grid.add_child(btn)
	# One locked "coming soon" slot (shown for every difficulty) — reserved for
	# a future content update. Always disabled.
	var soon := Button.new()
	soon.custom_minimum_size = TILE_SIZE
	soon.add_theme_font_size_override("font_size", 20)
	soon.text = "Level %d\nComing Soon" % (GameData.num_levels() + 1)
	soon.disabled = true
	soon.modulate = Color(0.72, 0.72, 0.9)
	grid.add_child(soon)

func _on_level_pressed(n: int) -> void:
	Audio.play("click")
	GameData.start_level(difficulty, n)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_back() -> void:
	Audio.play("click")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
