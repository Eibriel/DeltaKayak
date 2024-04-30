class_name PreferenceResource
extends Resource

enum Language {ENGLISH, ESPANISH_SPAIN, ESPANISH_LATAM}

@export_group("Video")
@export_range(-1.0, 1.0) var brightness: float
@export var full_screen: bool = true

@export_group("Audio")
@export_range(0, 100) var master_volume: int = 50
@export_range(0, 100) var music_volume: int = 50
@export_range(0, 100) var voice_volume: int = 50
@export_range(0, 100) var vfx_volume: int = 50

@export_group("Language")
@export var selected_language: Language = Language.ENGLISH

@export_group("Accesibility")
@export var text_to_speech: bool = false
@export var high_contrast: bool = false
@export_range(3, 10) var font_size: int = 5

