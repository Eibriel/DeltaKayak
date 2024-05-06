extends Control

@export var primary_text: String = ""
@export var secondary_text: String = ""

@export var is_active:bool = false

@onready var primary_label: Label = %PrimaryLabel
@onready var secondary_label: Label = %SecondayLabel

func _ready() -> void:
	set_labels(primary_text, secondary_text)
	pass

func _enter_tree() -> void:
	#set_labels(primary_text, secondary_text)
	pass

func set_active(_is_active:bool) -> void:
	is_active = _is_active
	primary_label.visible = false
	secondary_label.visible = false
	
	if is_active:
		if primary_label.text != "":
			primary_label.visible = _is_active
		if secondary_label.text != "":
			secondary_label.visible = _is_active

func set_labels(_primary_text: String, _secondary_text: String) -> void:
	primary_label.text = _primary_text
	secondary_label.text = _secondary_text
	set_active(is_active)
