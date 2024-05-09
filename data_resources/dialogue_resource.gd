class_name DialogueResource
extends Resource

enum Character {
	NARRATOR,
	PROTAGONIST,
	COMPICACTUS,
	PEPA,
	CAROLINA,
	MARTA,
	MIGUEL
}

@export var id: String

#@export_group("Character")
@export var character: Character = 1
@export var image: String

#@export_group("Text")
@export_multiline var text: String

func _init() -> void:
	pass
