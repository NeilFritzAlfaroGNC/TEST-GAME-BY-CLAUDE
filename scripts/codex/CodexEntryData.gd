class_name CodexEntryData
extends Resource
## Data for one Codex card. CodexDatabase stores these Resources, and Codex.gd
## uses unlocked to decide whether real names, art, text and stats are displayed.
##
## EVERY field is optional. An entry that only sets a display_name and a
## category is perfectly valid; any stat left at STAT_UNSET is simply not shown
## by the Codex, and any texture left empty falls back to the neutral "?"
## placeholder.
##
## This project ships with NO entries: the Codex is an empty system you fill in
## yourself. To add content, create a new CodexEntryData resource
## (FileSystem -> right-click -> New Resource -> CodexEntryData), set its fields
## in the Inspector, and append it to `entries` on
## res://data/codex/codex_database.tres.
##
## Nothing here is specific to fruits, junk foods, enemies or any other content
## type: the class only knows about generic fields.

## Sentinel meaning "this stat is not defined for this entry".
## Leave a stat at this value and the Codex hides that row entirely.
const STAT_UNSET := -1.0

## Text shown instead of a locked/unknown value.
const UNKNOWN_TEXT := "???"

## The stats the Codex can display, in the order they appear on the right page.
## Keys match the metadata on the Stat* rows in scenes/codex/Codex.tscn.
const STAT_KEYS := [&"cost", &"cooldown", &"damage", &"range", &"health"]

## Human-readable label for each stat key.
const STAT_LABELS := {
	&"cost": "Cost",
	&"cooldown": "Cooldown",
	&"damage": "Damage",
	&"range": "Range",
	&"health": "Health",
}

@export_group("Identity")
## Stable identifier used for lookups and (later) save data, e.g. &"example_entry".
@export var id: StringName = &""
## The entry's name. Ignored while `unlocked` is false — the Codex shows "???".
@export var display_name: String = ""
## Which Codex category this entry belongs to. Must be one of the keys in
## CodexDatabase.CATEGORY_LABELS (e.g. &"fruits", &"enemies").
@export var category: StringName = &""
## Undiscovered entries appear as a "?" slot and hide all of their information
## behind "???" until this is true.
@export var unlocked: bool = false

@export_group("Art")
## Small texture drawn inside the grid slot. Optional.
@export var icon: Texture2D
## Large texture drawn on the right page. Optional.
@export var large_image: Texture2D

@export_group("Text")
## Free-form description. Optional.
@export_multiline var description: String = ""
## Free-form "special ability" text. Optional.
@export_multiline var ability_description: String = ""

@export_group("Stats (leave at -1 to hide the row)")
@export var cost: float = STAT_UNSET
@export var cooldown: float = STAT_UNSET
@export var damage: float = STAT_UNSET
## Shown as the "Range" stat row. Named attack_range because `range` is a
## built-in GDScript function name.
@export var attack_range: float = STAT_UNSET
@export var health: float = STAT_UNSET

## True when this entry defines the given stat.
func has_stat(stat: StringName) -> bool:
	return get_stat(stat) != STAT_UNSET

## Raw value of a stat, or STAT_UNSET when it is not defined.
func get_stat(stat: StringName) -> float:
	match stat:
		&"cost":
			return cost
		&"cooldown":
			return cooldown
		&"damage":
			return damage
		&"range":
			return attack_range
		&"health":
			return health
	return STAT_UNSET

## Only the stats this entry actually defines, as [{key, label, value}].
## Returns an empty array while the entry is locked.
func visible_stat_rows() -> Array:
	var rows: Array = []
	if not unlocked:
		return rows
	for key: StringName in STAT_KEYS:
		if has_stat(key):
			rows.append({
				"key": key,
				"label": STAT_LABELS[key],
				"value": format_stat(get_stat(key)),
			})
	return rows

## Numbers print without a trailing ".0", so 50 stays "50" and 1.5 stays "1.5".
static func format_stat(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value, 2)

## Title for the right page: the real name only once the entry is unlocked.
func display_title() -> String:
	if not unlocked or display_name.strip_edges().is_empty():
		return UNKNOWN_TEXT
	return display_name

## Description for the right page, or "???" when locked/empty.
func display_description() -> String:
	if not unlocked or description.strip_edges().is_empty():
		return UNKNOWN_TEXT
	return description

## Ability text for the right page, or "???" when locked/empty.
func display_ability() -> String:
	if not unlocked or ability_description.strip_edges().is_empty():
		return UNKNOWN_TEXT
	return ability_description
