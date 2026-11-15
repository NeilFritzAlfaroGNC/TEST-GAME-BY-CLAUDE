class_name CodexAnimationData
extends Resource

@export var display_name: String = "Attack"
@export var sprite_frames: SpriteFrames
@export var animation_name: StringName = &"attack"
@export_range(0, 99, 1, "or_greater") var extra_token_copies_required: int = 1
@export var token_icon: Texture2D

# Older animation resources serialized a total instead of extra copies.
@export_storage var tokens_required: int:
	set(value):
		if value > 0:
			extra_token_copies_required = value - 1
	get:
		return 0
