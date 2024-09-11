extends RigidBody3D

var hybrid_astar := HybridAStarBoat.new()
var boat_sim := BoatModel.new()
var aprox_boat_model := AproxBoatModel.new()

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
var volume_mat := StandardMaterial3D.new()

var time:float
var anim:Array[Dictionary]
var anim_frame := 0
var anim_tick := 0
var anim_subtick := 0
var anim_playing := false
var local_data := {
	"linear_velocity": Vector2.ZERO,
	"angular_velocity": 0.0,
	"yaw": 0.0,
	"position": Vector2.ZERO
}
var path_found := false
var new_path_requested := true

var rudder_angle: float = 0.0
var revs_per_second: float = 0.0

var anim_ticks_delta:float = 0.1 #0.15

func _ready() -> void:
	print("Loading BoatModel")
	boat_sim.load_parameters()
	#set_hybrid_astar()
	
	lines_mat.albedo_color = Color.RED
	lines_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	cost_mat.albedo_color = Color.ORANGE_RED
	cost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	volume_mat.albedo_color = Color.ROYAL_BLUE
	volume_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	#Engine.physics_ticks_per_second = 10
	#Engine.physics_ticks_per_second = 120

func set_hybrid_astar():
	hybrid_astar = HybridAStarBoat.new()
	define_area()
	start_yaw = rotation_godot_to_hybridastar(rotation.y)
	goal_pos = position_godot_to_hybridastar(Global.tri_to_bi(%NavTarget.global_position))
	goal_yaw = rotation_godot_to_hybridastar(%NavTarget.rotation.y)

	var obs_res = get_obstacles()
	var ox:Array[int] = obs_res[0]
	var oy:Array[int] = obs_res[1]
	for c in %Obstacles.get_children():
		c.queue_free()
	for n in ox.size():
		var obs := CSGBox3D.new()
		var pos := position_hybridastar_to_godot(Vector2(ox[n], oy[n]))
		obs.position.x = pos.x
		obs.position.z = pos.y
		%Obstacles.add_child(obs)
	
	%NavStart.global_position = Global.bi_to_tri(position_hybridastar_to_godot(start_pos))
	
	hybrid_astar.hybrid_astar_planning(
		get_current_velocity()[0], # TODO pass velocity
		get_current_velocity()[1], # TODO
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
		%NavTarget.global_position = global_position
		%NavTarget.global_position += Vector3(randf_range(-20, 20), 0, randf_range(-20, 20))
		anim_frame = 0
		anim_tick = 0
		anim_subtick = 0
		anim_playing = false
		path_found = false
		set_hybrid_astar()
	iterate_pathfinding()
	get_foces(delta)
	draw_boat_volume()
	#apply_forces(delta)

func get_current_velocity():
	var current_linear_velocity := Global.tri_to_bi(linear_velocity).rotated(rotation.y+deg_to_rad(90)) * 0.1
	var current_angular_velocity := -angular_velocity.y * 0.05
	
	return [
		current_linear_velocity,
		current_angular_velocity
	]

func draw_boat_volume():
	var pos := position_godot_to_hybridastar(Global.tri_to_bi(global_position))
	var yaw := rotation_godot_to_hybridastar(rotation.y)
	var volume:Array[Vector2i] = hybrid_astar.get_shape(pos, yaw)
	for c in %StartPointIndicator.get_children():
		c.queue_free()
	for v in volume:
		var vb:= CSGBox3D.new()
		vb.material = volume_mat
		%StartPointIndicator.add_child(vb)
		vb.global_position = Global.bi_to_tri(position_hybridastar_to_godot(Vector2(v)))
	#print(volume)

func apply_forces(delta: float) -> void:
	if not anim_playing: return
	var r := float(anim[anim_frame].direction) * 10.0
	rudder_angle = anim[anim_frame].steer
	var direction := (transform.basis * Vector3.FORWARD).normalized()
	apply_central_force(direction * r)
	
	apply_torque(Vector3(0, -rudder_angle, 0) * 10 * r)


var previous_linear_velocity := Vector2.ZERO
var previous_angular_velocity := 0.0

var force_to_apply := Vector3.ZERO
var torque_to_apply := 0.0
func get_foces(delta: float) -> void:
	#linear_velocity *= 0.0
	#angular_velocity *= 0.0
	if not anim_playing: return
	if anim.size() == 0: return 
	if anim_frame >= anim.size(): return
	time += delta
	
	%FrameLabel.text = "Frame: %d" % anim_frame
	%TickLabel.text = "Tick: %d" % anim_tick
	%SubTickLabel.text = "Sub Tick: %d" % anim_subtick
	
	# Calculate forces 10 times per second
	#if anim_tick == 0 and anim_subtick == 0:
	if anim_subtick == 0:
		if anim_frame == 0:
			#linear_velocity *= 0.0
			#angular_velocity *= 0.0
			local_data = {
				"linear_velocity": anim[anim_frame].linear_velocity,
				"angular_velocity": anim[anim_frame].angular_velocity,
				"yaw": anim[anim_frame].yaw,
				#"position": position_hybridastar_to_godot(Vector2(anim[anim_frame].x, anim[anim_frame].y))
				"position": Vector2.ZERO
			}
			previous_angular_velocity = get_current_velocity()[1]
			previous_linear_velocity = get_current_velocity()[0]
			#previous_angular_velocity = angular_velocity.y
			#previous_linear_velocity = force_godot_to_mmg(Global.tri_to_bi(linear_velocity))
			anim_frame += 1
			return
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
		%Rudder.rotation.y = -anim[anim_frame].steer
		var size_scale := 0.01
		var _linear_velocity:Vector2 = local_data.linear_velocity
		var _angular_velocity:float = local_data.angular_velocity
		var new_local_velocity
		if false:
			new_local_velocity = boat_sim.extended_boat_model(
				_linear_velocity,
				_angular_velocity,
				r,
				anim[anim_frame].steer)
			local_data.linear_velocity += new_local_velocity.force * size_scale
			local_data.angular_velocity += new_local_velocity.moment
		else:
			new_local_velocity = aprox_boat_model.get_velocity(
				_linear_velocity,
				_angular_velocity,
				aprox_boat_model.get_rudder_angle_key(anim[anim_frame].steer),
				aprox_boat_model.get_revs_per_second_key(anim[anim_frame].direction)
			)
			local_data.linear_velocity += Vector2(new_local_velocity.x, new_local_velocity.y) * size_scale
			local_data.angular_velocity += new_local_velocity.z
		local_data.position += local_data.linear_velocity.rotated(local_data.yaw)
		local_data.yaw -= local_data.angular_velocity
		
		var rotated_linear_velocity: Vector2= force_mmg_to_godot(local_data.linear_velocity, local_data.yaw)
		
		if false:
			var damp_number := 0.18
			var angular_acceleration:float = local_data.angular_velocity - previous_angular_velocity*damp_number
			var angular_force:float = angular_acceleration * mass
			previous_angular_velocity = local_data.angular_velocity
			var torque_multiplier := 190.0
			torque_to_apply = angular_force*torque_multiplier
			
			damp_number = 0.12
			var linear_acceleration:Vector2 = rotated_linear_velocity - previous_linear_velocity * damp_number
			var linear_force:Vector2 = linear_acceleration * mass
			previous_linear_velocity = rotated_linear_velocity
			var force_multiplier := 22.0
			force_to_apply = Global.bi_to_tri(linear_force)*force_multiplier
		else:
			var all_force_multiplier := 1490.0
			var damp_number := 0.0112
			var angular_acceleration:float = local_data.angular_velocity * damp_number
			var angular_force:float = angular_acceleration * mass
			previous_angular_velocity = local_data.angular_velocity
			var torque_multiplier := all_force_multiplier * 10.0
			torque_to_apply = angular_force*torque_multiplier
			
			damp_number = 0.013
			var linear_acceleration:Vector2 = rotated_linear_velocity * damp_number
			var linear_force:Vector2 = linear_acceleration * mass
			previous_linear_velocity = rotated_linear_velocity
			var force_multiplier := all_force_multiplier * 1.0
			force_to_apply = Global.bi_to_tri(linear_force)*force_multiplier
	
	# Apply forces on every physics tick
	# NOTE no need to multiply by delta!
	apply_torque(Vector3(0, torque_to_apply, 0))
	apply_central_force(force_to_apply)
	
	const use_position:=false
	if use_position:
		# BUG position is not aligned with the path for some reason
		var pos := position_hybridastar_to_godot(Vector2(local_data.position.x, local_data.position.y)) + center*2 #- origin
		global_position.x = pos.x
		global_position.z = pos.y
		rotation.y = -local_data.yaw + deg_to_rad(180+90)
		
	anim_subtick += 1
	assert(Engine.physics_ticks_per_second * anim_ticks_delta > 0)
	if anim_subtick >= Engine.physics_ticks_per_second * anim_ticks_delta:
		anim_tick += 1
		anim_subtick = 0
		if anim_tick >= anim[anim_frame].ticks:
			anim_frame += 1
			anim_tick = 0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	#return
	var _liner_damp := 0.9
	var _angular_damp := 0.9
	
	linear_velocity *= 1.0 - _liner_damp / Engine.physics_ticks_per_second
	angular_velocity *= 1.0 - _angular_damp / Engine.physics_ticks_per_second
	#return
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	# Gets only the energy going forward
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	var side_component: Vector3 = state.linear_velocity - forward_component
	linear_velocity = forward_component
	linear_velocity += side_component * 0.4

func iterate_pathfinding():
	if path_found: return
	if hybrid_astar.state != hybrid_astar.STATES.ITERATING:
		#print("Not iterating")
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
			"ticks": path.ticks[k],
			"linear_velocity": path.linear_velocity[k],
			"angular_velocity": path.angular_velocity[k]
		})

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		new_path_requested = true
	elif event.is_action_pressed("ui_up"):
		apply_impulse(Vector3.FORWARD.rotated(Vector3.UP, rotation.y)*100)
	elif event.is_action_pressed("ui_down"):
		apply_impulse(Vector3.BACK.rotated(Vector3.UP, rotation.y)*100)
	elif event.is_action_pressed("ui_right"):
		apply_torque_impulse(Vector3(0,+100,0))
	elif event.is_action_pressed("ui_left"):
		apply_torque_impulse(Vector3(0,-100,0))

func define_area() -> void:
	origin = Global.tri_to_bi(global_position)
	center = Vector2(area_size) / 2.0
	var future_position_offset := Global.tri_to_bi(linear_velocity / 22)
	#start_pos = Vector2(center) + future_position_offset
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
	
	var pos := position_godot_to_hybridastar(Global.tri_to_bi(global_position))
	var yaw := rotation_godot_to_hybridastar(rotation.y)
	var volume:Array[Vector2i] = hybrid_astar.get_shape(pos, yaw)
	for xx in range(1, x-1):
		for yy in range(1, y-1):
			# NOTE: dont set as obstacle cells that are inside
			# bote's volume. That creates issues when solving.
			if Vector2i(xx, yy) in volume: continue
			#
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
