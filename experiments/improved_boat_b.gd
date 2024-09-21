extends RigidBody3D

var hybrid_astar := HybridAStarBoat.new()
var threaded_hybrid_astar := ThreadedHybridAstarBoat.new()
var boat_sim := BoatModel.new()
var aprox_boat_model := AproxBoatModel.new()
var simple_boat_model := SimpleBoatModel.new()

var anim_boat_model := AnimBoatModel.new()

var area_size := Vector2i(30, 30)
var area_scale := 2.0
var start_pos := Vector2(10.0, 7.0)
var start_yaw := deg_to_rad(-45.0) # 120
var goal_pos := Vector2(45.0, 10.0)
var goal_yaw = deg_to_rad(90.0)
var center := area_size / 2.0

var origin := Vector2(0,0)

var lines_mat := StandardMaterial3D.new()
var cost_mat := StandardMaterial3D.new()
var volume_mat := StandardMaterial3D.new()

var time:float = 9999.0
var anim:Array[Dictionary]
var next_anim:Array[Dictionary]
var anim_playing := false
var new_path_requested := true

var pathfinding_position:Vector3
var pathfinding_rotation:Vector3
var pathfinding_linear_velocity:Vector3
var pathfinding_angular_velocity:Vector3

var anim_ticks_delta:float = 0.1
var hybrid_delta: float = 0.1

func _ready() -> void:
	print("Loading BoatModel")
	boat_sim.load_parameters()
	#set_hybrid_astar()
	
	simple_boat_model.configure(10.0)
	#simple_boat_model.ticks_per_second = int(1.0/hybrid_delta)
	
	lines_mat.albedo_color = Color.RED
	lines_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	cost_mat.albedo_color = Color.ORANGE_RED
	cost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	volume_mat.albedo_color = Color.ROYAL_BLUE
	volume_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	pathfinding_position = Vector3(global_position)
	pathfinding_rotation = rotation
	pathfinding_linear_velocity = Vector3(linear_velocity)
	pathfinding_angular_velocity = Vector3(angular_velocity)
	set_area()

func _exit_tree():
	threaded_hybrid_astar.stop_pathfinding()
	threaded_hybrid_astar.destroy()

func _process(delta: float) -> void:
	if new_path_requested and threaded_hybrid_astar.is_pathfinding_alive():
		#path_found = false
		threaded_hybrid_astar.stop_pathfinding()
	elif new_path_requested and not threaded_hybrid_astar.is_pathfinding_alive():
		new_path_requested = false
		#
		var obstacles:= get_obstacles()
		var target_position:Vector3 = %NavTarget.global_position
		var distance_limit := 28
		if target_position.distance_to(pathfinding_position) > distance_limit:
			target_position = (target_position - pathfinding_position).normalized() * distance_limit
			target_position += pathfinding_position
		%NavTarget2.global_position = target_position
		%NavStart.global_position = pathfinding_position
		print("Request Pathfinding")
		threaded_hybrid_astar.run_pathfinding(
			get_current_velocity()[0],
			get_current_velocity()[1],
			Global.tri_to_bi(pathfinding_position),
			pathfinding_rotation.y,
			Global.tri_to_bi(target_position),
			%NavTarget.rotation.y,
			obstacles
		)
		draw_obstacles(obstacles)
	
	draw_boat_volume()

var set_count := 0
func _physics_process(delta: float) -> void:
	var r_anim := threaded_hybrid_astar.get_animation()
	#prints(r_anim.size() > 0, not new_path_requested)
	if r_anim.size() > 0 and not new_path_requested:
		if time > 2.0:
			anim = r_anim
			if set_count <= 1 :
				set_count += 1
			else:
				set_area()
			draw_path() # TODO move out of physics
			time = 0.0
			anim_playing = true
			anim_boat_model.set_anim(anim)
			future_position(delta)
			new_path_requested = true
	get_foces(delta)
	

func future_position(delta:float):
	var fast_anim := AnimBoatModel.new()
	fast_anim.set_anim(anim)
	# NOTE Fast forward 2 seconds
	var vel_data := fast_anim.fast_torward(2.0, delta)
	var pos := position_hybridastar_to_godot(Vector2(vel_data[1].x, vel_data[1].y))
	# BUG FutureBoat is not in the future, but in the present
	%FutureBoat.position.x = pos.x
	%FutureBoat.position.z = pos.y
	%FutureBoat.rotation.y = -vel_data[1].z + deg_to_rad(90+180)
	pathfinding_position = Global.bi_to_tri(pos)
	pathfinding_rotation = Vector3(0, -vel_data[1].z + deg_to_rad(90+180), 0)
	pathfinding_rotation.y = hybrid_astar.rs.pi_2_pi(pathfinding_rotation.y)
	pathfinding_linear_velocity = Vector3(vel_data[0].x, 0, vel_data[0].y)
	pathfinding_angular_velocity = Vector3(0, -vel_data[0].z, 0)
	#prints("Future pos:", vel_data[1])

#var previous_linear_velocity := Vector2.ZERO
#var previous_angular_velocity := 0.0
var force_to_apply := Vector3.ZERO
var torque_to_apply := 0.0
func get_foces(delta: float) -> void:
	if not anim_playing: return
	if anim.size() == 0: return 
	time += delta
	%FrameLabel.text = "Frame: %d" % anim_boat_model.anim_frame
	%TickLabel.text = "Tick: %d" % anim_boat_model.anim_tick
	%SubTickLabel.text = "Sub Tick: %d" % anim_boat_model.anim_subtick
	
	var forces_to_apply := anim_boat_model.tick(delta)
	torque_to_apply = -forces_to_apply.z
	force_to_apply = Vector3(forces_to_apply.x, 0.0, forces_to_apply.y)
	apply_torque(Vector3(0, torque_to_apply, 0))
	# TODO Why it must be multiplied by 2!??
	# It's because the area is scaled by 2?
	# see area_scale variable
	apply_central_force(force_to_apply*2.0)
	
	%SimForce.global_position = global_position + force_to_apply*10
	
	%SteerLabel.text = "Steer: %dº" % rad_to_deg(anim_boat_model.current_frame().steer)
	%RevsLabel.text = "Revs: %d" % float(anim_boat_model.current_frame().direction)
	%Rudder.rotation.y = anim_boat_model.current_frame().steer
	
	var pos := position_hybridastar_to_godot(anim_boat_model.simple_boat_model.position)
	%SimBoat.global_position.x = pos.x
	%SimBoat.global_position.z = pos.y
	%SimBoat.rotation.y = -anim_boat_model.simple_boat_model.rotation + deg_to_rad(90+180)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dvel := simple_boat_model.damped_velocity(
		Global.tri_to_bi(state.linear_velocity),
		state.angular_velocity.y,
		Engine.physics_ticks_per_second,
		-rotation.y + deg_to_rad(90)
	)
	state.linear_velocity = Global.bi_to_tri(dvel[0])
	state.angular_velocity = Vector3(0, dvel[1], 0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		#new_path_requested = true
		pass
	elif event.is_action_pressed("ui_up"):
		#apply_impulse(Vector3.FORWARD.rotated(Vector3.UP, rotation.y)*10)
		%NavTarget.position.z -= 5.0
	elif event.is_action_pressed("ui_down"):
		#apply_impulse(Vector3.BACK.rotated(Vector3.UP, rotation.y)*10)
		%NavTarget.position.z += 5.0
	elif event.is_action_pressed("ui_right"):
		#apply_torque_impulse(Vector3(0,+50,0))
		%NavTarget.position.x += 5.0
	elif event.is_action_pressed("ui_left"):
		#apply_torque_impulse(Vector3(0,-50,0))
		%NavTarget.position.x -= 5.0

func set_area():
	# TODO remove duplicated code
	origin = Global.tri_to_bi(pathfinding_position)
	center = Vector2(area_size) / 2.0
	start_pos = Vector2(center)

func get_obstacles() -> Array[Array]:
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
	
	var pos := position_godot_to_hybridastar(Global.tri_to_bi(pathfinding_position))
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

func draw_obstacles(obstacles:Array) -> void:
	var ox = obstacles[0]
	var oy = obstacles[1]
	for c in %Obstacles.get_children():
		c.queue_free()
	for n in ox.size():
		var obs := CSGBox3D.new()
		var pos := position_hybridastar_to_godot(Vector2(ox[n], oy[n]))
		obs.position.x = pos.x
		obs.position.z = pos.y
		%Obstacles.add_child(obs)
	
	%NavStart.global_position = Global.bi_to_tri(position_hybridastar_to_godot(start_pos))

func get_current_velocity():
	var current_linear_velocity := Global.tri_to_bi(pathfinding_linear_velocity)#.rotated(rotation.y+deg_to_rad(90))
	var current_angular_velocity := -pathfinding_angular_velocity.y
	
	return [
		current_linear_velocity,
		current_angular_velocity
	]

func draw_path()->void:
	#var t_anim := threaded_hybrid_astar.get_animation(true)
	if anim.size() == 0: return
	for c in %Nodes.get_children():
		c.queue_free()
	for t in anim:
		var pos := position_hybridastar_to_godot(Vector2(t.x, t.y))
		var pyaw:float = t.yaw
		var obs := CSGBox3D.new()
		obs.size = Vector3(0.2, 0.2, 1.0)
		obs.position.x = pos.x
		obs.position.z = pos.y
		obs.rotation.y = -pyaw + deg_to_rad(90)
		obs.material = lines_mat
		%Nodes.add_child(obs)

func draw_boat_volume():
	var pos := position_godot_to_hybridastar(Global.tri_to_bi(global_position))
	var yaw := rotation_godot_to_hybridastar(rotation.y)
	"""var volume:Array[Vector2i] = hybrid_astar.get_shape(pos, yaw)
	for c in %StartPointIndicator.get_children():
		c.queue_free()
	for v in volume:
		var vb:= CSGBox3D.new()
		vb.material = volume_mat
		%StartPointIndicator.add_child(vb)
		vb.global_position = Global.bi_to_tri(position_hybridastar_to_godot(Vector2(v)))"""

"""
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
			%Hmap.add_child(obs)"""

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
