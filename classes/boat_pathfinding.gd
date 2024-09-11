class_name BoatPathfinding

var hybrid_astar := HybridAStarBoat.new()
var aprox_boat_model := AproxBoatModel.new()

var area_size := Vector2i(30, 30)
var area_scale := 2.0

var start_pos := Vector2(10.0, 7.0)
var start_yaw := deg_to_rad(-45.0) # 120
var goal_pos := Vector2(45.0, 10.0)
var goal_yaw = deg_to_rad(90.0)
var center := Vector2(0,0)
var path_found := false

var is_obstacle:Callable

var origin := Vector2(0,0)

var debug_elements: Node3D
var debug_start_point: Node3D
var debug_goal_point: Node3D
var debug_obstacles: Node3D
var debug_nodes: Node3D

var lines_mat := StandardMaterial3D.new()
var cost_mat := StandardMaterial3D.new()
var volume_mat := StandardMaterial3D.new()

var anim:Array[Dictionary]
var anim_frame := 0
var anim_tick := 0
var anim_subtick := 0
var anim_state := ANIM_STATES.IDLE

var initialized := false

enum ANIM_STATES {
	IDLE,
	PLAYING,
	ENDED
}

## Scale of simulation
## 0.1 means that each tick will last 0.1 seconds
var anim_ticks_delta:float = 0.1 #0.15

func _init(_debug_elements:Node3D) -> void:
	debug_elements = _debug_elements
	debug_start_point = CSGSphere3D.new()
	debug_start_point.name = "DebugStartPoint"
	debug_start_point.top_level = true
	debug_elements.add_child(debug_start_point)
	debug_goal_point = CSGSphere3D.new()
	debug_goal_point.radius = 2.0
	debug_goal_point.name = "DebugGoalPoint"
	debug_goal_point.top_level = true
	debug_elements.add_child(debug_goal_point)
	debug_obstacles = Node3D.new()
	debug_obstacles.name = "DebugObstacles"
	debug_obstacles.top_level = true
	debug_obstacles.position.y = 5.0
	debug_elements.add_child(debug_obstacles)
	debug_nodes = Node3D.new()
	debug_nodes.name = "DebugNodes"
	debug_nodes.top_level = true
	debug_nodes.position.y = 5.0
	debug_elements.add_child(debug_nodes)
	
	lines_mat.albedo_color = Color.RED
	lines_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	cost_mat.albedo_color = Color.ORANGE_RED
	cost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	volume_mat.albedo_color = Color.ROYAL_BLUE
	volume_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	

func initialize_pathfinding(
		global_position:Vector2,
		_start_yaw:float,
		_goal_pos:Vector2,
		_goal_yaw:float,
		_linear_velocity:Vector2,
		_angular_velocity:float,
		_is_obstacle:Callable):
	initialized = true
	anim_state = ANIM_STATES.IDLE
	path_found = false
	anim_frame = 0
	anim_tick = 0
	anim_subtick = 0
	hybrid_astar = HybridAStarBoat.new()
	define_area(
		global_position,
		_linear_velocity
	)
	
	## Ensure that goal is inside search area
	if global_position.distance_to(_goal_pos) > 30:
		_goal_pos = ((_goal_pos - global_position).normalized()*25) + global_position
	
	start_yaw = rotation_godot_to_hybridastar(_start_yaw)
	goal_pos = position_godot_to_hybridastar(_goal_pos)
	goal_yaw = rotation_godot_to_hybridastar(_goal_yaw)
	is_obstacle = _is_obstacle
	
	debug_goal_point.global_position = Global.bi_to_tri(_goal_pos)

	var obs_res = get_obstacles(global_position, _start_yaw)
	var ox:Array[int] = obs_res[0]
	var oy:Array[int] = obs_res[1]
	
	hybrid_astar.hybrid_astar_planning(
		_linear_velocity * 0.0,
		_angular_velocity * 0.0,
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
	print("Initialized!")
	
	draw_obstacles(ox, oy)
	draw_boat_volume(global_position, _start_yaw)


func iterate_pathfinding() -> void:
	if path_found:
		#print("Path found")
		return
	if hybrid_astar.state != hybrid_astar.STATES.ITERATING:
		#print("Not iterating")
		initialized = false
		return
	hybrid_astar.iterate()
	draw_nodes()

## To be called every _process_physics
func subtick() -> Dictionary:
	if not anim_state == ANIM_STATES.PLAYING: return {"ok": false}
	if anim.size() == 0:
		anim_state = ANIM_STATES.IDLE
		path_found = false
		return {"ok": false}
	if anim_frame >= anim.size():
		anim_state = ANIM_STATES.ENDED
		path_found = false
		return {"ok": false}
	
	var res_frame := anim[anim_frame]
	
	var data:= {"ok": true, "data": res_frame, "frame":anim_frame, "tick":anim_tick, "subtick":anim_subtick}
	
	anim_subtick += 1
	assert(Engine.physics_ticks_per_second * anim_ticks_delta > 0)
	if anim_subtick >= Engine.physics_ticks_per_second * anim_ticks_delta:
		anim_tick += 1
		anim_subtick = 0
		if anim_tick > anim[anim_frame].ticks:
			anim_frame += 1
			anim_tick = 0
	
	return data


# Tools

func define_area(_global_position:Vector2, _linear_velocity:Vector2) -> void:
	origin = _global_position
	center = Vector2(area_size) / 2.0
	var future_position_offset := _linear_velocity / 22
	start_pos = Vector2(center) + future_position_offset

func get_obstacles(global_position:Vector2, global_yaw:float) -> Array:
	var x := area_size.x
	var y := area_size.y
	var ox:Array[int]= []
	var oy:Array[int]= []

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
	
	var pos := position_godot_to_hybridastar(global_position)
	var yaw := rotation_godot_to_hybridastar(global_yaw)
	var volume:Array[Vector2i] = hybrid_astar.get_shape(pos, yaw)
	for xx in range(1, x-1):
		for yy in range(1, y-1):
			# NOTE: dont set as obstacle cells that are inside
			# bote's volume. That creates issues when solving.
			if Vector2i(xx, yy) in volume: continue
			#
			var point := position_hybridastar_to_godot(Vector2(xx, yy))
			if is_obstacle.call(point):
				ox.append(xx)
				oy.append(yy)
			"""if Geometry2D.is_point_in_polygon(point-Global.tri_to_bi(%CollisionPolygon.global_position), %CollisionPolygon.polygon):
				#print(point)
				ox.append(xx)
				oy.append(yy)
			elif point.distance_to(Global.tri_to_bi(%StaticBody3D.global_position)) < 5.0:
				#print(point)
				ox.append(xx)
				oy.append(yy)"""
	return [ox, oy]



# Draw Debug

func draw_pathfinding_debug():
	#draw_boat_volume()
	pass
	

func draw_nodes():
	for c in debug_nodes.get_children():
		c.queue_free()
	var path
	var path_cost
	for kk in hybrid_astar.closed_set:
		path = hybrid_astar.closed_set[kk]
		pass
		
	if path.pind < 0: return
	path = hybrid_astar.extract_any_path(hybrid_astar.closed_set, path, hybrid_astar.ngoal)
	anim.resize(0)
	
	var touch_start_point := false
	for k in path.x.size():
		var pos := position_hybridastar_to_godot(Vector2(path.x[k], path.y[k]))
		var pyaw:float = path.yaw[k]
		var obs := CSGBox3D.new()
		obs.size = Vector3(0.5, 0.5, 1.0)
		obs.position.x = pos.x
		obs.position.z = pos.y
		obs.rotation.y = -pyaw + deg_to_rad(90)
		obs.material = lines_mat
		debug_nodes.add_child(obs)
		
		if Vector2(path.x[k], path.y[k]).distance_to(start_pos) < 2.0:
			touch_start_point = true
		
		if Vector2(path.x[k], path.y[k]).distance_to(goal_pos) < 2.0:
			if touch_start_point:
				print("Path Found!")
				path_found = true
				anim_state = ANIM_STATES.PLAYING
		
		anim.append({
			"x": path.x[k],
			"y": path.y[k],
			"yaw": path.yaw[k],
			"direction": path.direction[k],
			"steer": path.steer[k],
			"ticks": path.ticks[k],
			"linear_velocity": path.linear_velocity[k],
			"angular_velocity": path.angular_velocity[k]
		})

func draw_obstacles(ox:Array, oy:Array):
	for c in debug_obstacles.get_children():
		c.queue_free()
	for n in ox.size():
		var obs := CSGBox3D.new()
		obs.name = "Obstacle_%d-%d" % [ox[n], oy[n]]
		var pos := position_hybridastar_to_godot(Vector2(ox[n], oy[n]))
		obs.position.x = pos.x
		obs.position.z = pos.y
		debug_obstacles.add_child(obs)
	
	#%NavStart.global_position = Global.bi_to_tri(position_hybridastar_to_godot(start_pos))

func draw_boat_volume(_global_position:Vector2, _rotation:float):
	var pos := position_godot_to_hybridastar(_global_position)
	var yaw := rotation_godot_to_hybridastar(_rotation)
	var volume:Array[Vector2i] = hybrid_astar.get_shape(pos, yaw)
	for c in debug_start_point.get_children():
		c.queue_free()
	for v in volume:
		var vb:= CSGBox3D.new()
		vb.material = volume_mat
		debug_start_point.add_child(vb)
		vb.global_position = Global.bi_to_tri(position_hybridastar_to_godot(Vector2(v)))
	#print(volume)


# Hybrid A* convertions
func position_godot_to_hybridastar(godot_pos:Vector2) -> Vector2:
	return (Vector2(area_size) - ((-((godot_pos- origin) / area_scale )) + center))

func position_hybridastar_to_godot(hybridastar_pos:Vector2) -> Vector2:
	return (((hybridastar_pos + origin) * area_scale) - origin) - (center*2)

func force_godot_to_hybridastar(godot_force: Vector2, _rotation:float) -> Vector2:
	return godot_force.rotated(_rotation+deg_to_rad(90))*0.01

func rotation_godot_to_hybridastar(godot_rotation:float) -> float:
	return -godot_rotation - deg_to_rad(90)


# MMG convertions
func force_godot_to_mmg(godot_force: Vector2, _rotation:float) -> Vector2:
	return godot_force.rotated(_rotation)

func force_mmg_to_godot(mmg_force: Vector2, mmg_yaw: float) -> Vector2:
	return mmg_force.rotated(mmg_yaw)
