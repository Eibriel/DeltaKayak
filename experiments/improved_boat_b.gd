extends RigidBody3D

var hybrid_astar := HybridAStarBoat.new()
var boat_sim := BoatModel.new()

var area_size := Vector2i(30, 30)
var area_scale := 2.0
var start_pos := Vector2(10.0, 7.0)
var start_yaw := deg_to_rad(-45.0) # 120
var goal_pos := Vector2(45.0, 10.0)
var goal_yaw = deg_to_rad(90.0)
var center := Vector2(0,0)

var origin := Vector2(0,0)

var lines_mat := StandardMaterial3D.new()
var cost_mat := StandardMaterial3D.new()

var time:float
var anim:Array[Dictionary]
var anim_frame := 0
var anim_tick := 0
var anim_playing := false
var local_data := {
	"force": Vector2.ZERO,
	"moment": 0.0,
	"yaw": 0.0,
	"position": Vector2.ZERO
}
var path_found := false
var new_path_requested := true

var rudder_angle: float = 0.0
var revs_per_second: float = 0.0

var anim_ticks_delta:float = 0.15

func _ready() -> void:
	print("Loading BoatModel")
	boat_sim.load_parameters()
	#set_hybrid_astar()
	
	lines_mat.albedo_color = Color.RED
	lines_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	cost_mat.albedo_color = Color.ORANGE_RED
	cost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func set_hybrid_astar():
	hybrid_astar = HybridAStarBoat.new()
	define_area()
	start_yaw = rotation_godot_to_hybridastar(rotation.y)
	goal_pos = position_godot_to_hybridastar(Global.tri_to_bi(%NavTarget.global_position))
	goal_yaw = rotation_godot_to_hybridastar(%NavTarget.rotation.y)

	#var obs_res:Array[Vector2i] = get_obstacles()
	var ox:Array[int] = get_obstacles()[0]
	var oy:Array[int] = get_obstacles()[1]
	for c in %Obstacles.get_children():
		c.queue_free()
	for n in ox.size():
		var obs := CSGBox3D.new()
		var pos := position_hybridastar_to_godot(Vector2(ox[n], oy[n]))
		obs.position.x = pos.x
		obs.position.z = pos.y
		%Obstacles.add_child(obs)
	
	var current_linear_velocity := force_godot_to_hybridastar(Global.tri_to_bi(linear_velocity)) #Global.tri_to_bi(linear_velocity).rotated(rotation.y)
	
	hybrid_astar.hybrid_astar_planning(
		current_linear_velocity * 0.0,
		angular_velocity.y * 0.05,
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
	draw_hmap()
	print("Initialized!")

func _physics_process(delta: float) -> void:
	if new_path_requested:
		new_path_requested = false
		set_hybrid_astar()
	iterate_pathfinding()
	get_foces(delta)
	#apply_forces(delta)

func apply_forces(delta: float) -> void:
	if not anim_playing: return
	var r := float(anim[anim_frame].direction) * 10.0
	rudder_angle = anim[anim_frame].steer
	var direction := (transform.basis * Vector3.FORWARD).normalized()
	apply_central_force(direction * r)
	
	apply_torque(Vector3(0, -rudder_angle, 0) * 10 * r)


var previous_linear_velocity := Vector2.ZERO
var previous_angular_velocity := 0.0
func get_foces(delta: float) -> void:
	time += delta
	if not anim_playing: return
	if anim.size() == 0: return 
	if anim_frame >= anim.size(): return
	if time < anim_ticks_delta: return
	time = 0.0
	%FrameLabel.text = "Frame: %d" % anim_frame
	%TickLabel.text = "Tick: %d" % anim_tick
	if anim_tick == 0:
		if anim_frame == 0:
			#local_data.position.x = anim[anim_frame].x
			#local_data.position.y = anim[anim_frame].y
			#local_data.yaw = anim[anim_frame].yaw
			local_data = {
				"force": Vector2.ZERO,
				"moment": 0.0,
				"yaw": anim[anim_frame].yaw,
				"position": Vector2.ZERO
			}
			previous_angular_velocity = 0.0
			previous_linear_velocity = Vector2.ZERO
			#previous_angular_velocity = angular_velocity.y
			#previous_linear_velocity = force_godot_to_mmg(Global.tri_to_bi(linear_velocity))
		elif anim_frame > 0:
			#local_data.position.x = anim[anim_frame-1].x
			#local_data.position.y = anim[anim_frame-1].y
			#local_data.yaw = anim[anim_frame-1].yaw
			pass
	
	var r := float(anim[anim_frame].direction) * 10.0
	rudder_angle = anim[anim_frame].steer
	revs_per_second = r
	
	%SteerLabel.text = "Steer: %dº" % rad_to_deg(anim[anim_frame].steer)
	%RevsLabel.text = "Revs: %d" % r
	if r < 0:
		%Rudder.rotation.y = -anim[anim_frame].steer
	else:
		%Rudder.rotation.y = -anim[anim_frame].steer
	
	var size_scale := 0.01
	var _linear_velocity:Vector2 = local_data.force
	var _angular_velocity:float = local_data.moment
	var new_local_forces = boat_sim.extended_boat_model(
		_linear_velocity,
		_angular_velocity,
		r,
		anim[anim_frame].steer)
	local_data.force += new_local_forces.force * size_scale
	local_data.moment += new_local_forces.moment
	local_data.yaw -= local_data.moment
	local_data.position += local_data.force.rotated(local_data.yaw+deg_to_rad(90+180))
	
	var pos := position_hybridastar_to_godot(Vector2(local_data.position.x, local_data.position.y))
	
	var rotated_force: Vector2= force_mmg_to_godot(local_data.force, local_data.yaw)
	#var rotated_force: Vector2= -local_data.force.rotated(-rotation.y+deg_to_rad(90))
	
	var damp_number := (1.0 - (0.09))
	var angular_force:float = (local_data.moment - (previous_angular_velocity*damp_number)) * mass
	previous_angular_velocity = local_data.moment
	var torque_multiplier := 14000
	var torque_damp_compensation := 1.1
	apply_torque(Vector3(0, angular_force*torque_multiplier, 0))
	damp_number = (1.0 - (0.09))
	var linear_force:Vector2 = (rotated_force - (previous_linear_velocity*damp_number)) * mass
	previous_linear_velocity = rotated_force
	var force_multiplier := 1800
	var force_damp_compensation := 1.0
	apply_central_force(Global.bi_to_tri(linear_force)*force_multiplier*force_damp_compensation)
	
	#var use_forces = false
	#if use_forces:
		#var use_velocity:= false
		#if use_velocity:
			#linear_velocity.x = rotated_force.x * mass * area_scale
			#linear_velocity.z = rotated_force.y * mass * area_scale
			#angular_velocity.y = local_data.moment * mass
		#else:
			#var force_scale := 100000
			#apply_central_force(Global.bi_to_tri(new_local_forces.force.rotated(local_data.yaw)) * 130)
			##print(new_local_forces.moment*force_scale)
			#apply_torque(Vector3(0, new_local_forces.moment*force_scale, 0))
	#else:
		#position.x = pos.x
		#position.z = pos.y
		#rotation.y = -local_data.yaw
	##%Rudder.rotation.y = -anim[anim_frame].steer
	
	anim_tick += 1
	if anim_tick >= anim[anim_frame].ticks:
		anim_frame += 1
		anim_tick = 0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	linear_velocity *= 0.99
	angular_velocity *= 0.99
	
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	# Gets only the energy going forward
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	var side_component: Vector3 = state.linear_velocity - forward_component
	linear_velocity = forward_component
	linear_velocity += side_component * 0.4

func iterate_pathfinding():
	if path_found: return
	if hybrid_astar.state != hybrid_astar.STATES.ITERATING:
		print("Not iterating")
		return
	hybrid_astar.iterate()
	draw_nodes()

func draw_nodes():
	for c in %Nodes.get_children():
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
		obs.size = Vector3(0.2, 0.2, 1.0)
		obs.position.x = pos.x
		obs.position.z = pos.y
		obs.rotation.y = -pyaw + deg_to_rad(90)
		obs.material = lines_mat
		%Nodes.add_child(obs)
		
		if Vector2(path.x[k], path.y[k]).distance_to(start_pos) < 2.0:
			touch_start_point = true
		
		if Vector2(path.x[k], path.y[k]).distance_to(goal_pos) < 2.0:
			if touch_start_point:
				path_found = true
				anim_playing = true
		
		anim.append({
			"x": path.x[k],
			"y": path.y[k],
			"yaw": path.yaw[k],
			"direction": path.direction[k],
			"steer": path.steer[k],
			"ticks": path.ticks[k]
		})

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		%NavTarget.global_position = global_position
		%NavTarget.global_position += Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		anim_frame = 0
		anim_tick = 0
		anim_playing = false
		path_found = false
		#set_hybrid_astar()
		new_path_requested = true
	elif event.is_action_pressed("ui_up"):
		anim_playing = true
	elif event.is_action_pressed("ui_right"):
		anim_frame += 1
		#anim_tick += 1
		#if anim_tick >= anim[anim_frame].ticks:
			#anim_frame += 1
			#anim_tick = 0

func define_area() -> void:
	origin = Global.tri_to_bi(global_position)
	center = Vector2(area_size) / 2.0
	start_pos = Vector2(center)

# Hybrid A* convertions
func position_godot_to_hybridastar(godot_pos:Vector2) -> Vector2:
	return (Vector2(area_size) - ((-((godot_pos- origin) / area_scale )) + center))

func position_hybridastar_to_godot(hybridastar_pos:Vector2) -> Vector2:
	return (((hybridastar_pos + origin) * area_scale) - origin) - (center*2)

func force_godot_to_hybridastar(godot_force: Vector2) -> Vector2:
	return godot_force.rotated(rotation.y+deg_to_rad(90))*0.01

func rotation_godot_to_hybridastar(godot_rotation:float) -> float:
	return -godot_rotation - deg_to_rad(90)

# MMG convertions
func force_godot_to_mmg(godot_force: Vector2) -> Vector2:
	return godot_force.rotated(rotation.y)

func force_mmg_to_godot(mmg_force: Vector2, mmg_yaw: float) -> Vector2:
	return mmg_force.rotated(mmg_yaw)

func get_obstacles() -> Array:
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
	
	for xx in range(1, x-1):
		for yy in range(1, y-1):
			var point := position_hybridastar_to_godot(Vector2(xx, yy))
			if Geometry2D.is_point_in_polygon(point-Global.tri_to_bi(%CollisionPolygon.global_position), %CollisionPolygon.polygon):
				#print(point)
				ox.append(xx)
				oy.append(yy)
			elif point.distance_to(Global.tri_to_bi(%StaticBody3D.global_position)) < 5.0:
				#print(point)
				ox.append(xx)
				oy.append(yy)
	return [ox, oy]

func draw_hmap():
	for c in %Hmap.get_children():
		c.queue_free()
	var hmap = hybrid_astar.hmap
	for hx in hybrid_astar.hmap.size():
		for hy in hybrid_astar.hmap[hx].size():
			if hybrid_astar.hmap[hx][hy] == INF: continue
			var obs := CSGBox3D.new()
			obs.material = cost_mat
			obs.size = Vector3(
				hybrid_astar.hmap[hx][hy] * 0.02,
				0.1,
				hybrid_astar.hmap[hx][hy] * 0.02,
			)
			var pos := position_hybridastar_to_godot(Vector2(hx, hy))
			obs.position.x = pos.x
			obs.position.z = pos.y
			%Hmap.add_child(obs)

#
#func _physics_process(delta: float) -> void:
	#iterate_pathfinding()
#
#
#func iterate_pathfinding():
	#hybrid_astar.iterate()
