extends GutTest

var a :Agent

func before_each():
	a = create_agent()

func after_each():
	#p.free()
	pass

func test_spawn():
	a.spawn(Vector2.ZERO,0.0, Vector3.ONE)
	var expected_cells := {
		Vector2i(0, 0): [0]
	}
	var expected_positions := [Vector2(0, 0)]
	assert_eq_deep(expected_cells, a.cells)
	assert_eq_deep(expected_positions, a.positions)


func test_move():
	a.behavior = {
		"step": "$velocity: v2(0, -1); $angle: 0.0;"
	}
	a.spawn(Vector2.ZERO,0.0, Vector3.ONE)
	a.move_agents(0.25)
	var expected_cells := {
		Vector2i(0, -1): [0]
	}
	#var expected_positions := [Vector2(0, -1.25)]
	assert_eq_deep(expected_cells, a.cells)
	#assert_eq_deep(expected_positions, a.positions, 0.005)


func damage():
	print(a.cells)
	print(a.positions)
	a.queue_for_removal(0)
	a.remove_agents()
	print(a.cells)
	print(a.positions)
	a.spawn(Vector2.ZERO,0.0, Vector3.ONE)
	a.spawn(Vector2(0, 10),0.0, Vector3.ONE)
	print(a.cells)
	print(a.positions)
	a.damage(0, 10)
	a.move_agents(0.25)
	print(a.cells)
	print(a.positions)
	a.remove_agents()
	print(a.cells)
	print(a.positions)

func test_removal2():
	a.spawn(Vector2.ZERO,0.0, Vector3.ONE)
	a.spawn(Vector2.ZERO,0.0, Vector3.ONE)
	a.queue_for_removal(0)
	a.remove_agents()
	var expected_cells := {
		Vector2i(0, 0): [0]
	}
	var expected_positions := [Vector2(0, 0)]
	assert_eq_deep(expected_cells, a.cells)
	assert_eq_deep(expected_positions, a.positions)


func create_agent() -> Agent:
	var m := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = preload("res://meshes/drone001.res")
	mm.instance_count = 1000
	mm.visible_instance_count = 0
	m.multimesh = mm
	var a := Agent.new()
	a.set_multimesh(m)
	return a
