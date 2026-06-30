extends Node
## Autoload singleton ("GameData").
## Food database, numbered level + difficulty definitions, the current run's
## live state, and a thin bridge to the DB autoload (SQLite-backed progress).

# === Food database: real Filipino foods grouped Go / Glow / Grow ===
const FOODS := {
	"Go": ["Kanin", "Tinapay", "Mais", "Kamote", "Patatas", "Pancit", "Oatmeal", "Lugaw"],
	"Glow": ["Malunggay", "Kangkong", "Karot", "Mangga", "Papaya", "Kamatis", "Kalabasa", "Pechay", "Dalandan", "Saging"],
	"Grow": ["Isda", "Manok", "Itlog", "Gatas", "Munggo", "Tokwa", "Hipon", "Karne", "Keso", "Baboy"],
}

# === Numbered levels (1-based). Each focuses on one food group. ===
const LEVELS := [
	{"name": "Energy Start", "correct_group": "Go", "enemies": 4,
	 "lesson": "GO foods give you ENERGY to run, play, and study! Rice (kanin), bread (tinapay), corn (mais), and kamote are Go foods."},
	{"name": "Veggie Patrol", "correct_group": "Glow", "enemies": 4,
	 "lesson": "GLOW foods protect you from getting sick! Vegetables like malunggay, kangkong, and pechay are Glow foods."},
	{"name": "Muscle Up", "correct_group": "Grow", "enemies": 5,
	 "lesson": "GROW foods build strong muscles and bones! Fish (isda), egg (itlog), milk (gatas), and beans (munggo) are Grow foods."},
	{"name": "Power Snack", "correct_group": "Go", "enemies": 5,
	 "lesson": "Go foods are your fuel! Pancit, oatmeal, and lugaw also give you energy to keep going."},
	{"name": "Fruit Shield", "correct_group": "Glow", "enemies": 6,
	 "lesson": "Fruits are Glow foods too! Mangga, papaya, and dalandan give vitamins that keep you healthy."},
	{"name": "Strong Finish", "correct_group": "Grow", "enemies": 6,
	 "lesson": "Grow foods help you grow tall and strong! Manok, hipon, tokwa, and keso build your body."},
]

# === Difficulty modifiers ===
# lives: starting lives. speed_mult: enemy speed. spawn_mult: time between
# spawns (>1 = slower). enemy_bonus: extra enemies. score_mult: points multiplier.
const DIFFICULTIES := {
	"Easy":   {"lives": 5, "speed_mult": 0.70, "spawn_mult": 1.30, "enemy_bonus": 0, "score_mult": 1},
	"Medium": {"lives": 3, "speed_mult": 1.00, "spawn_mult": 1.00, "enemy_bonus": 1, "score_mult": 2},
	"Hard":   {"lives": 2, "speed_mult": 1.40, "spawn_mult": 0.70, "enemy_bonus": 2, "score_mult": 3},
}
const DIFFICULTY_ORDER := ["Easy", "Medium", "Hard"]

# === Runtime state for the current level attempt ===
var current_difficulty: String = "Easy"
var current_level: int = 1          # 1-based level number
var starting_lives: int = 3
var score: int = 0
var lives: int = 3
var last_result: String = ""        # "win" or "lose", read by the Result screen
var last_stars: int = 0

# === Cached persistent value ===
var high_score: int = 0

func _ready() -> void:
	high_score = DB.get_high_score()

# === Level / difficulty lookups ===
func num_levels() -> int:
	return LEVELS.size()

func level_data(number: int) -> Dictionary:
	return LEVELS[clampi(number - 1, 0, LEVELS.size() - 1)]

func current_level_data() -> Dictionary:
	return level_data(current_level)

func difficulty_data() -> Dictionary:
	return DIFFICULTIES[current_difficulty]

func has_next_level() -> bool:
	return current_level < LEVELS.size()

# Begin a chosen level at a chosen difficulty (resets the run state).
func start_level(difficulty: String, number: int) -> void:
	current_difficulty = difficulty
	current_level = number
	starting_lives = int(DIFFICULTIES[difficulty]["lives"])
	lives = starting_lives
	score = 0
	last_result = ""
	last_stars = 0

# Save the outcome of the current level into the DB (scores + progress).
func record_result(won: bool) -> void:
	last_result = "win" if won else "lose"
	last_stars = _compute_stars(won)
	DB.record_level_result(current_difficulty, current_level, score, last_stars, won)
	high_score = DB.get_high_score()

func _compute_stars(won: bool) -> int:
	if not won:
		return 0
	var lost := starting_lives - lives
	if lost <= 0:
		return 3
	if lives * 2 >= starting_lives:
		return 2
	return 1

# === Food helpers ===
func group_color(group: String) -> Color:
	match group:
		"Go":
			return Color(0.96, 0.78, 0.12)   # yellow = energy
		"Glow":
			return Color(0.30, 0.72, 0.34)   # green = protect
		"Grow":
			return Color(0.90, 0.32, 0.28)   # red = build
	return Color(0.6, 0.6, 0.6)

func random_group() -> String:
	var keys := FOODS.keys()
	return keys[randi() % keys.size()]

func random_food(group: String) -> String:
	var arr: Array = FOODS[group]
	return arr[randi() % arr.size()]
