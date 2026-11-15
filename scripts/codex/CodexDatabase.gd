class_name CodexDatabase
extends Resource
## The Codex's content registry. The .tres resource stores entries; category
## labels are listed here and need matching category buttons in Codex.tscn.
##
## SHIPS EMPTY ON PURPOSE — all five categories contain zero entries until you
## add your own CodexEntryData resources to `entries`. The Codex UI reads only
## from this resource, so adding content never requires touching the interface.
##
## The default instance lives at res://data/codex/codex_database.tres.

## The categories the Codex knows about, and the label shown for each.
## The order of this dictionary is the order the Codex lists them in.
##
## To add a sixth category: add a key here AND a button with matching
## `metadata/category` in scenes/codex/Codex.tscn. No code changes needed.
const CATEGORY_LABELS := {
	&"fruits": "Fruits",
	&"junk_foods": "Junk Foods",
	&"enemies": "Enemies",
	&"items": "Items",
	&"environment": "Environment",
}

## Every entry in the Codex, across all categories. Empty by default.
@export var entries: Array[CodexEntryData] = []

## Category ids in display order.
func category_ids() -> Array:
	return CATEGORY_LABELS.keys()

## Display label for a category id (falls back to a capitalised version of the id).
func category_label(category: StringName) -> String:
	return CATEGORY_LABELS.get(category, String(category).capitalize())

## True when `category` is one of the known category ids.
func has_category(category: StringName) -> bool:
	return CATEGORY_LABELS.has(category)

## Every entry filed under `category`, in the order they were added.
func entries_in_category(category: StringName) -> Array[CodexEntryData]:
	var result: Array[CodexEntryData] = []
	for entry: CodexEntryData in entries:
		if entry != null and entry.category == category:
			result.append(entry)
	return result
