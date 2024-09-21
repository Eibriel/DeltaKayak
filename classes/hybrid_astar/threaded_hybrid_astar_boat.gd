## This class allows to run Hybrid A* pathfinding for boats in a separated thread.
class_name ThreadedHybridAstarBoat

var hybrid_astar: HybridAStarBoat

const area_size := Vector2i(30, 30)
const area_scale := 2.0
const max_time := 2000

var thread: Thread
var mutex: Mutex

# Threaded vars
var path_found := false
var is_pathfinding_stopped := false
var origin:Vector2
var center:Vector2
var start_pos:Vector2
var start_yaw:float
var goal_pos:Vector2
var goal_yaw:float
var anim:Array[Dictionary]


func _init() -> void:
	thread = Thread.new()
	mutex = Mutex.new()

func run_pathfinding(
			_linear_velocity: Vector2,
			_angular_velocity: float,
			_boat_position:Vector2,
			_boat_rotation:float,
			_goal_position:Vector2,
			_goal_rotation:float,
			_obstacles:Array[Array]
		) -> void:
	if thread.is_started():
		thread.wait_to_finish()
	assert(not thread.is_started())
	path_found = false
	is_pathfinding_stopped = false
	origin = _boat_position
	center = Vector2(area_size) / 2.0
	start_pos = Vector2(center)
	thread.start(_run_pathfinding.bind(
		_linear_velocity,
		_angular_velocity,
		_boat_position,
		_boat_rotation,
		_goal_position,
		_goal_rotation,
		_obstacles
	))

func stop_pathfinding() -> void:
	mutex.lock()
	is_pathfinding_stopped = true
	mutex.unlock()

func is_pathfinding_alive() -> bool:
	return thread.is_alive()

func get_animation(force:=false) -> Array[Dictionary]:
	var anim_r:Array[Dictionary] = []
	mutex.lock()
	if path_found:
		anim_r = anim.duplicate(true)
	mutex.unlock()
	return anim_r

## This function must be called when closing the game.
##
func destroy() -> void:
	thread.wait_to_finish()
	print("Threaded Hybrid A* Boat closed.")

# Threaded functions
func _run_pathfinding(
		linear_velocity: Vector2,
		angular_velocity: float,
		boat_position:Vector2,
		boat_rotation:float,
		goal_position:Vector2,
		goal_rotation:float,
		obstacles:Array[Array]
	) -> void:
	hybrid_astar = HybridAStarBoat.new()
	
	start_yaw = rotation_godot_to_hybridastar(boat_rotation)
	goal_pos = position_godot_to_hybridastar(goal_position)
	goal_yaw = rotation_godot_to_hybridastar(goal_rotation)

	#var obs_res = get_obstacles()
	var ox:Array[int] = obstacles[0]
	var oy:Array[int] = obstacles[1]
	
	anim.resize(0)
	
	assert(start_pos == Vector2(15, 15))
	var time := Time.get_ticks_msec()
	hybrid_astar.hybrid_astar_planning(
		linear_velocity,
		angular_velocity,
		area_size,
		start_pos.x,
		start_pos.y,
		start_yaw,
		goal_pos.x,
		goal_pos.y,
		goal_yaw,
		ox,
		oy,
		hybrid_astar.config.XY_RESO,
		hybrid_astar.config.YAW_RESO
	)
	#draw_hmap()
	print("Initialized in %d ms!" % (Time.get_ticks_msec() - time))

	time = Time.get_ticks_msec()
	while true:
		if path_found:
			print("Path found in %d ms" % (Time.get_ticks_msec() - time))
			break
		if safe_is_pathfinding_stopped(): break
		if hybrid_astar.state != hybrid_astar.STATES.ITERATING:
			#print("Not iterating")
			break
		hybrid_astar.iterate()
		draw_nodes()
		# BUG using time as early termination will cause
		# the game to behave differently according to computation power
		# of the player's PC
		if (Time.get_ticks_msec()-time) > max_time:
			mutex.lock()
			path_found = true
			print("Path finding timeout! %d" % anim.size())
			mutex.unlock()
		if hybrid_astar.state == hybrid_astar.STATES.ERROR:
			mutex.lock()
			path_found = true
			print("Path finding failed!")
			mutex.unlock()

## Allows the safe access to is_pathfinding_stopped
func safe_is_pathfinding_stopped() -> bool:
	var r:bool
	mutex.lock()
	r = is_pathfinding_stopped
	mutex.unlock()
	return r

"""
func define_area() -> void:
	origin = Global.tri_to_bi(global_position)
	center = Vector2(area_size) / 2.0
	#var future_position_offset := Global.tri_to_bi(linear_velocity / 22)
	#start_pos = Vector2(center) + future_position_offset
	start_pos = Vector2(center)
"""

func draw_nodes():
	var path
	var path_cost
	for kk in hybrid_astar.closed_set:
		path = hybrid_astar.closed_set[kk]
		pass
		
	if path.pind < 0: return
	path = hybrid_astar.extract_any_path(hybrid_astar.closed_set, path, hybrid_astar.ngoal)
	
	var touch_start_point := false
	var t_anim: Array[Dictionary] = []
	var t_path_found = false
	if Vector2(path.x[0], path.y[0]) == Vector2(15,15):
		for k in path.x.size():
			if Vector2(path.x[k], path.y[k]).distance_to(goal_pos) < 2.0:
				t_path_found = true
			t_anim.append({
				"x": path.x[k],
				"y": path.y[k],
				"yaw": path.yaw[k],
				"direction": path.direction[k],
				"steer": path.steer[k],
				"ticks": path.ticks[k],
				"linear_velocity": path.linear_velocity[k],
				"angular_velocity": path.angular_velocity[k]
			})
	mutex.lock() # Safely sets state
	path_found = t_path_found
	if t_anim.size()>0:
		anim = t_anim
	mutex.unlock()

# Hybrid A* convertions
func position_godot_to_hybridastar(godot_pos:Vector2) -> Vector2:
	return (Vector2(area_size) - ((-((godot_pos- origin) / area_scale )) + center))

func position_hybridastar_to_godot(hybridastar_pos:Vector2) -> Vector2:
	return (((hybridastar_pos + origin) * area_scale) - origin) - (center*2)

#func force_godot_to_hybridastar(godot_force: Vector2) -> Vector2:
#	return godot_force.rotated(rotation.y+deg_to_rad(90))*0.01

func rotation_godot_to_hybridastar(godot_rotation:float) -> float:
	return -godot_rotation - deg_to_rad(90)

# MMG convertions
#func force_godot_to_mmg(godot_force: Vector2) -> Vector2:
#	return godot_force.rotated(rotation.y)

func force_mmg_to_godot(mmg_force: Vector2, mmg_yaw: float) -> Vector2:
	return mmg_force.rotated(mmg_yaw)



# End threaded functions
