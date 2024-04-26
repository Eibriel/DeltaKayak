extends Control

@export var label_name: String = ""

@onready var label: Label = $Label


func _ready() -> void:
	label.text = label_name
	label.visible = false


func set_active(is_active:bool) -> void:
	label.visible = is_active
