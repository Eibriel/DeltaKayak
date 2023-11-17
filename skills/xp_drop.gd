extends Agent

var MULTIMESH: MultiMesh

func _init():
	var mm:MultiMeshInstance3D = generate_multimesh(preload("res://meshes/lotus001.res"))
	MULTIMESH = mm.multimesh
	(Global.player as Node3D).get_node("Node3D2").add_child(mm)
	Global.connect("dropped_item", on_dropped_item)


func spawn_agent():
	pass


func move_agents(delta: float):
	var player_position := Vector2(0,0) + shift
	var xp_collected := get_id_on_cirle(player_position, 5)
	if xp_collected >= 0:
		Global.claim_item(Global.ITEMS.XP, 1.0)
		queue_for_removal(xp_collected)
	
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


func on_dropped_item(item_id: int, amount: float, position: Vector2):
	var rotation := 0.0
	#var scale := Vector3(1, 1, 1)
	spawn(position, rotation, scale)
	
