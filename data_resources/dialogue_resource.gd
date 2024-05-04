class_name DialogueResource
extends Resource

enum Character {
	NARRATOR,
	PROTAGONIST,
	COMPICACTUS,
	PEPA
}

@export var id: String

@export_group("Character")
@export var character: Character
@export var image: String

@export_group("Text")
@export var text: IntTextResource

func _init() -> void:
	pass
