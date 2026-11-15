extends RefCounted

const SAVE := "user://codex_tokens.cfg"
const REWARD_META := &"codex_token_rewards"
const INFO := &"info"
const ANIMATIONS := [&"attack", &"defeated"]
const NAMES := {
	&"soda_enemy": "Soda Enemy",
	&"donut_enemy": "Donut Enemy",
}


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


static func reserve_reward(id: StringName, reserved: Array[StringName]) -> StringName:
	if not NAMES.has(id):
		return &""
	var config := load_unlocks()
	var info := reward_key(id, INFO)
	if not is_unlocked(config, id, INFO) and info not in reserved:
		return info
	var available: Array[StringName] = []
	for kind: StringName in ANIMATIONS:
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
		if not NAMES.has(id) or (kind != INFO and kind not in ANIMATIONS):
			continue
		if is_unlocked(config, id, kind):
			continue
		config.set_value("rewards_" + String(id), kind, true)
		rewards.append("%s %s" % [NAMES[id], String(kind).capitalize()])
	if not rewards.is_empty():
		result = config.save(SAVE)
		if result != OK:
			push_error("Could not save Codex tokens: " + error_string(result))
			rewards.clear()
	return rewards


static func reset_all() -> Error:
	if not FileAccess.file_exists(SAVE):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
