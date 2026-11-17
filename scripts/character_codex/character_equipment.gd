extends RefCounted

const SAVE_PATH := "user://character_codex.cfg"
const TOKENS := preload("res://scripts/codex/codex_token_unlocks.gd")


static func unlocked_characters() -> Array[CodexTokenEntry]:
	var config := TOKENS.load_unlocks()
	var entries: Array[CodexTokenEntry] = []
	for entry: CodexTokenEntry in TOKENS.ENTRIES.values():
		if TOKENS.is_unlocked(config, entry.id, TOKENS.INFO):
			entries.append(entry)
	for entry: CodexEntryData in TOKENS.CODEX_DATABASE.entries:
		if entry is CodexTokenEntry and entry.category == &"sick_child":
			if TOKENS.is_unlocked(config, entry.id, TOKENS.INFO):
				entries.append(entry as CodexTokenEntry)
	return entries


static func load_id() -> StringName:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return &""
	return StringName(config.get_value("character", "token_id", ""))


static func save_id(id: StringName) -> Error:
	var config := ConfigFile.new()
	config.set_value("character", "token_id", id)
	return config.save(SAVE_PATH)


static func apply_preview(sprite: AnimatedSprite2D, entry: CodexTokenEntry, bounds: Vector2) -> bool:
	for preferred: StringName in [&"idle", &"walk", &""]:
		for animation in entry.animations:
			if animation == null or animation.sprite_frames == null:
				continue
			var animation_name: StringName = animation.animation_name
			if preferred != &"" and animation_name != preferred:
				continue
			var frames: SpriteFrames = animation.sprite_frames
			if not frames.has_animation(animation_name) or frames.get_frame_count(animation_name) == 0:
				continue
			var texture := frames.get_frame_texture(animation_name, 0)
			if texture == null:
				continue
			sprite.sprite_frames = frames
			sprite.scale = Vector2.ONE * minf(bounds.x / texture.get_width(), bounds.y / texture.get_height())
			sprite.play(animation_name)
			return true
	return false
