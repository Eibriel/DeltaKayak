@tool
extends Path3D

var tree = preload("res://Tree001.glb")

@export var trees_amount: Curve:
	set (value):
		trees_amount = value
		if Engine.is_editor_hint():
			spawn_trees()
	get:
		return trees_amount

#@onready var spawn = $Spawn

func _get_configuration_warnings():
	var warnings = []

	return warnings

func _ready():
	if not Engine.is_editor_hint():
		spawn_trees()

func spawn_trees():
	var points = curve.get_baked_points()
	#var upvectors = path.curve.get_baked_up_vectors()
	
	for child in $Spawn.get_children():
		child.free()
	
	for point in points:
		if randf() < 0.95: continue
		var t: Node3D = tree.instantiate()
		t.position = point
		t.rotation.y = randf_range(0, 360)
		$Spawn.add_child(t)
