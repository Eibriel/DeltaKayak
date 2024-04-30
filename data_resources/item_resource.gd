class_name ItemResource
extends Resource

@export var id: String
@export var label: IntTextResource
@export var active: bool = true



@export_group("Actions")
@export var actions: Array[ActionResource]
