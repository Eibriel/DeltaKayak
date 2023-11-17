extends Agent

var MULTIMESH: MultiMesh

func _init():
	var mm:MultiMeshInstance3D = generate_multimesh(preload("res://meshes/jellyfish.res"))
	MULTIMESH = mm.multimesh
	(Global.player as Node3D).get_node("Node3D2").add_child(mm)


func spawn_agent():
	var position := Vector2.ZERO + shift
	var rotation := randf_range(PI*-2, PI*2)
	var scale := Vector3(0.25, 0.25, 0.25)
	spawn(position, rotation, scale)


func move_agents(delta: float):
	for id in INSTANCE_COUNT:
		var from_position := positions[id]
		# MOVE FORWARD
		var target_position: Vector2= positions[id] + (Vector2.UP.rotated(-rotations[id] + deg_to_rad(180)))
		positions[id] -= positions[id].direction_to(target_position) * CURRENT_SPEED * delta
		move_from_to_cell(id, from_position, positions[id])
		time[id] += delta
		if time[id] > 3.0:
			queue_for_removal(id)
		
	# COLLIDE WITH ENEMIES
	var collided := collide2(2)
	if collided >= 0:
		#prints(INSTANCE_COUNT, collided)
		queue_for_removal(collided)
	
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
