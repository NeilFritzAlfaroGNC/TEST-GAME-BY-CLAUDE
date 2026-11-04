
extends Control

@export var level_id: String = "cafeteria_level_1"

# Enable this only for the Victory screen.
# The Level Map should leave it disabled.
@export var show_current_run: bool = false

@onready var star_1: Label = $Stars/Star1
@onready var star_2: Label = $Stars/Star2
@onready var star_3: Label = $Stars/Star3

const GOLD = Color("#E5B94B")
const WHITE = Color("#FFFFFF")


func _ready() -> void:
	refresh_stars()


# Decide whether to display the current run or saved best rating.
func refresh_stars() -> void:
	var saved_stars: int = 0

	if show_current_run:
		saved_stars = ProgressManager.current_run_stars
	else:
		saved_stars = ProgressManager.get_level_stars(
			ProgressManager.current_difficulty,
			level_id
		)

	set_stars(saved_stars)


# Display the earned stars.
func set_stars(star_count: int) -> void:
	update_star(star_1, 1, star_count)
	update_star(star_2, 2, star_count)
	update_star(star_3, 3, star_count)


func update_star(
	star: Label,
	star_number: int,
	star_count: int
) -> void:
	if star_number <= star_count:
		star.text = "★"
		star.add_theme_color_override("font_color", GOLD)
	else:
		star.text = "☆"
		star.add_theme_color_override("font_color", WHITE)
