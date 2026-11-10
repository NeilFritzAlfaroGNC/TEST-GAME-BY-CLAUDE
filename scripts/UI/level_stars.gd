
extends Control

# ==================================================
# LEVEL STAR DISPLAY
# ==================================================
# Shared by Cafeteria, Canteen, and Victory Screen.
#
# Level Map:
#   show_current_run = false
#
# Victory Screen:
#   show_current_run = true
# ==================================================

@export var level_id: String = "cafeteria_level_1"
@export var show_current_run: bool = false

@onready var star_1: Label = $Stars/Star1
@onready var star_2: Label = $Stars/Star2
@onready var star_3: Label = $Stars/Star3

const GOLD: Color = Color("#E5B94B")
const WHITE: Color = Color("#FFFFFF")


func _ready() -> void:
	refresh_stars()


# ==================================================
# REFRESH STAR DISPLAY
# ==================================================

func refresh_stars() -> void:
	var star_count: int = 0

	if show_current_run:
		star_count = ProgressManager.current_run_stars

		print(
			"[Stars] Victory | Current run: ",
			star_count
		)

	else:
		star_count = ProgressManager.get_level_stars(
			ProgressManager.current_difficulty,
			level_id
		)

		print(
			"[Stars] Level: ",
			level_id,
			" | Difficulty: ",
			ProgressManager.current_difficulty,
			" | Saved stars: ",
			star_count
		)

	set_stars(star_count)


# ==================================================
# DISPLAY STARS
# ==================================================

func set_stars(star_count: int) -> void:
	var count: int = clampi(star_count, 0, 3)

	update_star(star_1, 1, count)
	update_star(star_2, 2, count)
	update_star(star_3, 3, count)


# ==================================================
# UPDATE INDIVIDUAL STAR
# ==================================================

func update_star(
	star: Label,
	star_number: int,
	star_count: int
) -> void:
	if star_number <= star_count:
		star.text = "★"
		star.add_theme_color_override(
			"font_color",
			GOLD
		)
	else:
		star.text = "☆"
		star.add_theme_color_override(
			"font_color",
			WHITE
		)
