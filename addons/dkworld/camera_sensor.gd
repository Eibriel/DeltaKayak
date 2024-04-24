extends Area3D
class_name CameraSensor

@export var world_node:DKWorld
@export var camera:Camera3D
@export var path:Path3D

func _ready():
	connect("area_entered", world_node.camera_entered.bind(camera, path))
	connect("area_exited", world_node.camera_exited.bind(camera, path))
