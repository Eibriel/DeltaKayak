class_name ItemResource
extends Resource

@export var id: String
@export var label: IntTextResource
@export var active: bool = true
@export var trigger_name:String
@export var logic: GDScript

#@export_flags("Visible", "Entered", "Close", "Action", "Far", "Exited", "Hidden") var trigger_on = 0

#@export_group("Actions")
@export var actions: Array[ActionResource]
