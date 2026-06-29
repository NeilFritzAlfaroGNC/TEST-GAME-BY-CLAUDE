extends Node
## Autoload singleton ("GameData").
## Holds the food database, level definitions, the current run's state,
## and offline local save/load (replaces the planned SQLite with built-in
## FileAccess + JSON so the project runs with no extra plugins).

# === Food database: real Filipino foods grouped Go / Glow / Grow ===
const FOODS := {
	"Go": ["Kanin", "Tinapay", "Mais", "Kamote", "Patatas", "Pancit", "Oatmeal", "Lugaw"],
	"Glow": ["Malunggay", "Kangkong", "Karot", "Mangga", "Papaya", "Kamatis", "Kalabasa", "Pechay", "Dalandan", "Saging"],
	"Grow": ["Isda", "Manok", "Itlog", "Gatas", "Munggo", "Tokwa", "Hipon", "Karne", "Keso", "Baboy"],
}

# === Levels: each level asks for one food group and spawns some enemies ===
const LEVELS := [
	{
		"name": "Level 1: Energy Boost",
		"correct_group": "Go",
		"enemies": 4,
		"lesson": "GO foods give you ENERGY to run, play, and study! Rice (kanin), bread (tinapay), corn (mais), and kamote are Go foods.",
	},
	{
		"name": "Level 2: Grow Strong",
		"correct_group": "Grow",
		"enemies": 5,
		"lesson": "GROW foods build strong muscles and bones! Fish (isda), egg (itlog), milk (gatas), and beans (munggo) are Grow foods.",
	},
	{
		"name": "Level 3: Glow & Protect",
		"correct_group": "Glow",
		"enemies": 6,
		"lesson": "GLOW foods protect you from getting sick! Vegetables and fruits like malunggay, kangkong, and mangga are Glow foods.",
	},
]

# === Runtime state for the current run ===
var current_level: int = 0
var score: int = 0
var lives: int = 3
var last_result: String = ""   # "win" or "lose", read by the Result screen

# === Persistent state (backed by the DB autoload: SQLite, else JSON) ===
var high_score: int = 0

func _ready() -> void:
	load_game()

func reset_run() -> void:
	current_level = 0
	score = 0
	lives = 3
	last_result = ""

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

# === Offline save / load (delegated to the DB autoload) ===
func save_game() -> void:
	if score > high_score:
		high_score = score
	var reached: int = LEVELS.size() if last_result == "win" else current_level + 1
	reached = clampi(reached, 1, LEVELS.size())
	DB.record_run(score, last_result, reached)
	high_score = DB.get_high_score()

func load_game() -> void:
	high_score = DB.get_high_score()
