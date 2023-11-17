extends Agent

var MULTIMESH: MultiMesh

func _init():
	var mm:MultiMeshInstance3D = generate_multimesh(preload("res://meshes/drone001.res"))
	MULTIMESH = mm.multimesh
	(Global.player as Node3D).get_node("Node3D2").add_child(mm)


func spawn_agent():
	var position := Vector2.ZERO + shift
	var rotation := 0.0
	var scale := Vector3(1, 1, 1)
	position = Global.get_offscreen_position()
	spawn(position, rotation, scale)


func move_agents(delta: float):
	for id in INSTANCE_COUNT:
		var from_position := positions[id]
		# MOVE TOWARDS PLAYER
		var target_position: Vector2= shift + Vector2.ZERO
		positions[id] += positions[id].direction_to(target_position) * CURRENT_SPEED * delta
		# SELF COLLIDE
		if agent_count_on_cell(from_position)>1:
			var cell_center = cell_center(from_position)
			positions[id] += cell_center.direction_to(positions[id]) * CURRENT_SPEED * 0.8 * delta
		# LOOK AT PLAYER
		var v2d := positions[id] - shift
		rotations[id] = (-v2d.angle_to_point(Vector2.ZERO)) + deg_to_rad(-90)
		move_from_to_cell(id, from_position, positions[id])
	# DAMAGE PLAYER
	damage_player(2)
	
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


func on_die(id):
	Global.drop_item(Global.ITEMS.XP, 1.0, positions[id])
