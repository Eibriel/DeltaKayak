extends Node

func _ready():
	run_tests()


func run_tests():
	test1()
	test2()

func test1():
	print("\nTest 1")
	var a := create_agent()
	a.behavior = [
		{"forward": 1},
	]
	a.spawn(Vector2.ZERO,0.0, Vector3.ONE)
	print(a.cells)
	print(a.positions)
	a.move_agents(0.25)
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

func test2():
	print("\nTest 2")
	var a := create_agent()
	a.behavior = [
		{"forward": 1},
	]
	a.spawn(Vector2.ZERO,0.0, Vector3.ONE)
	a.spawn(Vector2.ZERO,0.0, Vector3.ONE)
	a.queue_for_removal(0)
	a.remove_agents()
	print(a.cells)
	print(a.positions)
	if a.cells[Vector2i(0,0)] != [0]:
		push_error("Test 2 failed")


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
