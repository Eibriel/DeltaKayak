extends Node3D

var time := 0.0

var anim:Array[Vector2]
var anim_frame := 0

func _process(delta: float) -> void:
	time += delta
	if time < 0.1: return
	if anim_frame >= anim.size(): return
	time = 0.0
	%Agent.position.x = anim[anim_frame].x
	%Agent.position.z = anim[anim_frame].y
	var tail:= CSGSphere3D.new()
	tail.position = %Agent.position
	add_child(tail)
	anim_frame += 1

func _ready() -> void:
	print("start!")
	var x = 51
	var y = 31
	var sx = 10.0
	var sy = 7.0
	var syaw0 = deg_to_rad(120.0)
	var gx = 45.0
	var gy = 20.0
	var gyaw0 = deg_to_rad(90.0)

	var obs_res = design_obstacles(x, y)
	var ox = obs_res[0]
	var oy = obs_res[1]

	var hybrid_astar := HybridAStar.new()

	var t0 = 0.0
	var path = hybrid_astar.hybrid_astar_planning(sx, sy, syaw0, gx, gy, gyaw0,
								 ox, oy, hybrid_astar.config.XY_RESO, hybrid_astar.config.YAW_RESO)
	var t1 = 0.5
	print("running T: ", t1 - t0)

	if not path:
		print("Searching failed!")
		return

	x = path.x
	y = path.y
	var yaw = path.yaw
	var direction = path.direction

func get_env()->Array[Array]:
	var ox:Array[int]= []
	var oy:Array[int]= []

	# ¡Array will ignore float appends!

	for i in range(60):
		ox.append(i)
		oy.append(int(0.0))
	for i in range(60):
		ox.append(int(60.0))
		oy.append(i)
	for i in range(61):
		ox.append(i)
		oy.append(int(60.0))
	for i in range(61):
		ox.append(int(0.0))
		oy.append(i)
	for i in range(40):
		ox.append(int(20.0))
		oy.append(i)
	for i in range(40):
		ox.append(int(40.0))
		oy.append(int(60.0 - i))

	return [ox, oy]

func design_obstacles(x, y) -> Array:
	var ox := []
	var oy := []

	for i in range(x):
		ox.append(i)
		oy.append(0)
	for i in range(x):
		ox.append(i)
		oy.append(y - 1)
	for i in range(y):
		ox.append(0)
		oy.append(i)
	for i in range(y):
		ox.append(x - 1)
		oy.append(i)
	for i in range(10, 21):
		ox.append(i)
		oy.append(15)
	for i in range(15):
		ox.append(20)
		oy.append(i)
	for i in range(15, 30):
		ox.append(30)
		oy.append(i)
	for i in range(16):
		ox.append(40)
		oy.append(i)

	return [ox, oy]
