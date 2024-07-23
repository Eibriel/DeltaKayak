class_name DialogueResource
extends Resource

enum Character {
	NARRATOR,
	PROTAGONIST,
	COMPICACTUS,
	PEPA,
	CAROLINA,
	MARTA,
	MIGUEL,
	DON_PANCHO
}

@export var id: String

#@export_group("Character")
@export var character: Character = Character.PROTAGONIST
@export var image: String
@export var enabled: bool = true
#@export_group("Text")
@export_multiline var text: String

func _init() -> void:
	pass
