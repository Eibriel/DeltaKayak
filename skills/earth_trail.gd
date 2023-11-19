extends Agent

var MULTIMESH: MultiMesh

func _init():
	var mm:MultiMeshInstance3D = generate_multimesh(preload("res://meshes/iceberg.res"))
	MULTIMESH = mm.multimesh
	(Global.player as Node3D).get_node("Node3D2").add_child(mm)


func spawn_agent():
	var position := Vector2.ZERO + shift + Vector2(randf_range(-1,1), randf_range(-1,1))
	var rotation := 0.0
	var scale := Vector3(0.02, 0.02, 0.02)
	spawn(position, rotation, scale)


func move_agents(delta: float):
	for id in INSTANCE_COUNT:
		time[id] += delta
		# COLLIDE WITH ENEMIES
		var collided := collide3(2)
		if collided.data:
			# Set as mudded
			collided.agent.flags[collided.id] |= FLAG.MUDDED
		if time[id] > 10.0:
			queue_for_removal(id)
	update_multimesh()


func update_multimesh():
	MULTIMESH.visible_instance_count = INSTANCE_COUNT
	for id in INSTANCE_COUNT:
		var v2d := positions[id] - shift
		var v: Vector3 = Vector3(v2d.x, 0.0, v2d.y)
		var t := Transform3D(Basis(), v)
		t = t.rotated_local(Vector3.UP, rotations[id])
		t = t.scaled_local(scale)
		MULTIMESH.set_instance_transform(id, t)
