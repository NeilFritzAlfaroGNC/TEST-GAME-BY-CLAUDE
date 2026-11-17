extends RefCounted

const SAVE := "user://codex_tokens.cfg"
const REWARD_META := &"codex_token_rewards"
const INFO := &"info"
const CODEX_DATABASE := preload("res://data/codex/character_codex_database.tres")
const ENTRIES := {
	&"soda_enemy": preload("res://data/tokens/soda_enemy_token.tres"),
	&"donut_enemy": preload("res://data/tokens/donut_enemy_token.tres"),
	&"fries_enemy": preload("res://data/tokens/fries_enemy_token.tres"),
	&"pizza_enemy": preload("res://data/tokens/pizza_enemy_token.tres"),
}


const CHILD_SCENE_IDS := {
	"res://Level3/scenes/sick child/sick_male_child.tscn": &"sick_male",
	"res://Level3/scenes/sick child/sick_female_chid.tscn": &"sick_female",
	"res://Level3/scenes/healthy child/male/healthy_male_weightlifting.tscn": &"healthy_male",
	"res://Level3/scenes/healthy child/male/healthy_male_weightlifting_left.tscn": &"healthy_male_left",
	"res://Level3/scenes/healthy child/male/healthy_male_weightlifting_right.tscn": &"healthy_male_right",
	"res://Level3/scenes/healthy child/female/healthy_female_rope.tscn": &"healthy_female",
	"res://Level3/scenes/healthy child/female/healthy_female_rope_sideways.tscn": &"healthy_female_sideways",
}

 
static func child_id_for_scene(path: String) -> StringName:
	return CHILD_SCENE_IDS.get(path, &"")


static func load_unlocks() -> ConfigFile:
	var config := ConfigFile.new()
	var result := config.load(SAVE)
	if result != OK and result != ERR_FILE_NOT_FOUND:
		push_warning("Could not read Codex token save: " + error_string(result))
	return config


static func is_unlocked(config: ConfigFile, id: StringName, kind: StringName) -> bool:
	var section := "rewards_" + String(id)
	if config.has_section_key(section, kind):
		return config.get_value(section, kind, false)
	var old_count := int(config.get_value("enemy_token_counts", id, 0))
	match kind:
		INFO:
			return old_count > 0 or config.get_value("junk_enemies", id, false)
		&"attack":
			return old_count >= 2
		&"defeated":
			return old_count >= 3
	return false


static func reward_key(id: StringName, kind: StringName) -> StringName:
	return StringName("%s:%s" % [id, kind])


static func _entry_for(id: StringName) -> CodexTokenEntry:
	var enemy := ENTRIES.get(id) as CodexTokenEntry
	if enemy != null:
		return enemy
	for entry: CodexEntryData in CODEX_DATABASE.entries:
		if entry != null and entry.id == id:
			return entry as CodexTokenEntry
	return null


static func reserve_reward(id: StringName, reserved: Array[StringName]) -> StringName:
	var entry := _entry_for(id)
	if entry == null:
		return &""
	var config := load_unlocks()
	var info := reward_key(id, INFO)
	if not is_unlocked(config, id, INFO) and info not in reserved:
		return info
	var available: Array[StringName] = []
	for animation: CodexAnimationData in entry.animations:
		if animation == null:
			continue
		var kind := animation.animation_name
		var key := reward_key(id, kind)
		if key not in reserved and not is_unlocked(config, id, kind):
			available.append(key)
	return &"" if available.is_empty() else available.pick_random()


static func commit_victory(collected: Array[StringName]) -> PackedStringArray:
	var rewards := PackedStringArray()
	if collected.is_empty():
		return rewards
	var config := ConfigFile.new()
	var result := config.load(SAVE)
	if result != OK and result != ERR_FILE_NOT_FOUND:
		push_error("Could not read Codex token save: " + error_string(result))
		return rewards
	for key in collected:
		var parts := String(key).split(":")
		if parts.size() != 2:
			continue
		var id := StringName(parts[0])
		var kind := StringName(parts[1])
		var entry := _entry_for(id)
		if entry == null:
			continue
		var label := "Info"
		if kind != INFO:
			label = _animation_label(entry, kind)
			if label.is_empty():
				continue
		if is_unlocked(config, id, kind):
			continue
		config.set_value("rewards_" + String(id), kind, true)
		rewards.append("%s %s" % [entry.display_name, label])
	if not rewards.is_empty():
		result = config.save(SAVE)
		if result != OK:
			push_error("Could not save Codex tokens: " + error_string(result))
			rewards.clear()
	return rewards


static func _animation_label(entry: CodexTokenEntry, kind: StringName) -> String:
	for animation: CodexAnimationData in entry.animations:
		if animation != null and animation.animation_name == kind:
			return animation.display_name
	return ""


static func reset_all() -> Error:
	if not FileAccess.file_exists(SAVE):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
