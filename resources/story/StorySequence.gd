extends Resource
class_name StorySequence

# The image and dialogue belong to data, not to the reusable story presentation.
@export var background: Texture2D
@export var dialogue_entries: PackedStringArray = PackedStringArray()
