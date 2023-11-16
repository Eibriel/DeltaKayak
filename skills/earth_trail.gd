extends Agent

var MULTIMESH: MultiMesh

func _init():
	var m := MultiMeshInstance3D.new()
	MULTIMESH = MultiMesh.new()
	MULTIMESH.transform_format = MultiMesh.TRANSFORM_3D
	MULTIMESH.mesh = preload("res://meshes/drone001.res")
	MULTIMESH.instance_count = 1000
	MULTIMESH.visible_instance_count = 0
	m.multimesh = MULTIMESH
	m.position.y = 0.458
	(Global.player as Node3D).get_node("Node3D2").add_child(m)


func spawn_agent():
	var position := Vector2.ZERO + shift
	var rotation := 0.0
	var scale := Vector3(1, 1, 1)
	position = get_offscreen_position()
	spawn(position, rotation, scale)


func move_agents(delta: float):
	for id in INSTANCE_COUNT:
		var from_position := positions[id]
		# MOVE TOWARDS PLAYER
		var target_position: Vector2= shift + Vector2.ZERO
		positions[id] += positions[id].direction_to(target_position) * CURRENT_SPEED * delta
		# LOOK AT PLAYER
		var v2d := positions[id] - shift
		rotations[id] = (-v2d.angle_to_point(Vector2.ZERO)) + deg_to_rad(-90)
		move_from_to_cell(id, from_position, positions[id])
		# DAMAGE PLAYER
		damage_player(id, v2d)
		# COLLIDE WITH PLAYER
		if collide(id, positions[id]):
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
