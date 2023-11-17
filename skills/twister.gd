extends Agent

var MULTIMESH: MultiMesh

func _init():
	var mm:MultiMeshInstance3D = generate_multimesh(preload("res://meshes/lotus001.res"))
	MULTIMESH = mm.multimesh
	(Global.player as Node3D).get_node("Node3D2").add_child(mm)
	SPAWN_AMOUNT = 5
	SPAWN_INTERVAL = 3.0

func spawn_agent():
	var position := Global.get_onscreen_position()
	var rotation := randf_range(PI*-2, PI*2)
	var scale := Vector3(6, 6, 6)
	spawn(position, rotation, scale)

func move_agents(delta: float):
	for id in INSTANCE_COUNT:
		time[id] += delta
		rotations[id] += delta
		if time[id] > 15.0:
			queue_for_removal(id)
	# COLLIDE WITH ENEMIES
	var collided := collide2(3)
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
