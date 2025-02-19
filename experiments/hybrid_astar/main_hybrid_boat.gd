extends Node3D

var time := 0.0

var anim:Array[Dictionary]
var anim_frame := 0
var anim_tick := 0

var hybrid_astar := HybridAStarBoat.new()
var boat_sim := BoatModel.new()
var aprox_boat_model := AproxBoatModel.new()
var simple_boat_model := SimpleBoatModel.new()

var end_search := false

var local_data := {
	"force": Vector2.ZERO,
	"moment": 0.0,
	"yaw":0.0,
	"position": Vector2.ZERO
}

var initial_linear_velocity := Vector2(0.0, 0.0)
var initial_angular_velocity := 0.00

var fps := 10

func _process(delta: float) -> void:
	time += delta
	if hybrid_astar.state == hybrid_astar.STATES.ITERATING:
		for _n in 1:
			iterate_pathfinding()
			if hybrid_astar.state != hybrid_astar.STATES.ITERATING:
				break
	if time < 1.0 / fps*0.5: return
	if anim.size() == 0: return 
	if anim_frame >= anim.size():
		anim_frame = 0
		anim_tick = 0
		local_data = {
			"force": Vector2.ZERO,
			"moment": 0.0,
			"yaw":0.0,
			"position": Vector2.ZERO
		}
	time = 0.0
	
	%FrameLabel.text = "Frame: %d" % anim_frame
	%TickLabel.text = "Tick: %d" % anim_tick
	
	if anim_tick == 0:
		if anim_frame == 0:
			local_data.force = anim[anim_frame].linear_velocity
			local_data.moment = anim[anim_frame].angular_velocity
			local_data.position.x = anim[anim_frame].x
			local_data.position.y = anim[anim_frame].y
			local_data.yaw = anim[anim_frame].yaw
			anim_frame += 1
			
			simple_boat_model.position = local_data.position
			simple_boat_model.rotation = local_data.yaw
			simple_boat_model.linear_velocity = Vector2.ZERO
			simple_boat_model.angular_velocity = 0.0
			return
		elif anim_frame > 0:
			#local_data.position.x = anim[anim_frame-1].x
			#local_data.position.y = anim[anim_frame-1].y
			#local_data.yaw = anim[anim_frame-1].yaw
			pass
	
	var r := float(anim[anim_frame].direction)# * 10.0
	%SteerLabel.text = "Steer: %dº" % rad_to_deg(anim[anim_frame].steer)
	%RevsLabel.text = "Revs: %d" % r
	var size_scale := 0.01
	var linear_velocity:Vector2 = local_data.force
	var angular_velocity:float = local_data.moment
	var new_local_forces
	if false:
		new_local_forces = boat_sim.extended_boat_model(
			linear_velocity,
			angular_velocity,
			r,
			anim[anim_frame].steer)
		local_data.force += new_local_forces.force * size_scale
		local_data.moment += new_local_forces.moment
	elif false:
		new_local_forces = aprox_boat_model.get_velocity(
			linear_velocity,
			angular_velocity,
			aprox_boat_model.get_rudder_angle_key(anim[anim_frame].steer),
			aprox_boat_model.get_revs_per_second_key(anim[anim_frame].direction)
		)
		local_data.force += Vector2(new_local_forces.x, new_local_forces.y) * size_scale
		local_data.moment += new_local_forces.z
	else:
		#simple_boat_model.linear_velocity = linear_velocity
		#simple_boat_model.angular_velocity = angular_velocity
		new_local_forces = simple_boat_model.calculate_boat_forces(
			r,#anim[anim_frame].direction,
			anim[anim_frame].steer,
		)
		#simple_boat_model.linear_force *= size_scale
		simple_boat_model.step(0.1)
		local_data.force += Vector2(new_local_forces.x, new_local_forces.y)
		local_data.moment += new_local_forces.z
	
	if false:
		local_data.yaw -= local_data.moment
		local_data.position += local_data.force.rotated(local_data.yaw)
		
		%Agent.position.x = local_data.position.x
		%Agent.position.z = local_data.position.y
		%Agent.rotation.y = -local_data.yaw + deg_to_rad(90)
		%Rudder.rotation.y = -anim[anim_frame].steer
	else:
		%Agent.position = Global.bi_to_tri(simple_boat_model.position)
		%Agent.rotation.y = -simple_boat_model.rotation + deg_to_rad(90)
		%Rudder.rotation.y = anim[anim_frame].steer
	#prints(anim_frame, anim_tick)
	
	anim_tick += 1
	if anim_tick >= anim[anim_frame].ticks:
		anim_frame += 1
		anim_tick = 0

var start_pos:Vector2
var goal_pos:Vector2
func _ready() -> void:
	print("test HeapDictTest")
	var heapdict_test := HeapDictTest.new()
	heapdict_test.test_main()
	
	print("Loading BoatModel")
	boat_sim.load_parameters()
	boat_sim.tests()
	
	simple_boat_model.configure(10.0)
	simple_boat_model.ticks_per_second = fps
	
	print("start!")
	var x = 51
	var y = 31
	var sx = 10.0
	var sy = 7.0
	var syaw0 = deg_to_rad(-45 + 180) # 120
	var gx = 45.0
	var gy = 10.0
	var gyaw0 = deg_to_rad(90.0)

	start_pos = Vector2(sx, sy)
	goal_pos = Vector2(gx, gy)

	%Agent.position.x = sx
	%Agent.position.z = sy
	%Agent.rotation.y = -syaw0 + deg_to_rad(90)

	var obs_res = design_obstacles(x, y)
	var ox = obs_res[0]
	var oy = obs_res[1]

	for n in ox.size():
		var obs := CSGBox3D.new()
		#obs.size = Vector3(0.1, 0.1, 0.1)
		obs.position.x = ox[n]
		obs.position.z = oy[n]
		add_child(obs)

	#var t0 = Time.get_ticks_msec()
	hybrid_astar.hybrid_astar_planning(
		initial_linear_velocity,
		initial_angular_velocity,
		Vector2i(x, y),
		sx, sy,
		syaw0,
		gx, gy,
		gyaw0,
		ox, oy,
		hybrid_astar.config.XY_RESO, hybrid_astar.config.YAW_RESO)
	#var t1 = Time.get_ticks_msec()
	#print("running T: ", t1 - t0)
	for hx in hybrid_astar.hmap.size():
		for hy in hybrid_astar.hmap[hx].size():
			if hybrid_astar.hmap[hx][hy] == INF: continue
			var obs := CSGBox3D.new()
			obs.size = Vector3(
				0.1,
				hybrid_astar.hmap[hx][hy] * 0.1,
				0.1,
			)
			obs.position.x = hx
			obs.position.z = hy
			%Hmap.add_child(obs)
	print("Initialized!")

var analystic_expantion_path_id:=0
func iterate_pathfinding():
	if hybrid_astar.state != hybrid_astar.STATES.ITERATING:
		print("Not iterating")
		return
	analystic_expantion_path_id = 0
	hybrid_astar.iterate()
	#draw_analystic_expantion_path()
	draw_nodes()
	
	if end_search:
		hybrid_astar.state = hybrid_astar.STATES.OK
	
	if hybrid_astar.state == hybrid_astar.STATES.ITERATING:
		return
	if hybrid_astar.state != hybrid_astar.STATES.OK:
		print(hybrid_astar.STATES.find_key(hybrid_astar.state))
		return
	
	#var path
	#var path_length:=-1
	#for kk in hybrid_astar.closed_set:
		#if hybrid_astar.closed_set[kk].x.size() > path_length:
			#path_length = hybrid_astar.closed_set[kk].x.size()
			#var n_curr = hybrid_astar.closed_set[kk]
			#path = hybrid_astar.extract_any_path(hybrid_astar.closed_set, n_curr, hybrid_astar.ngoal)
			#var touch_start_point:=false
			#var path_found:=false
			#for k in path.x.size():
				#if Vector2(path.x[k], path.y[k]).distance_to(start_pos) < 2.0:
					#touch_start_point = true
				#
				#if Vector2(path.x[k], path.y[k]).distance_to(goal_pos) < 2.0:
					#if touch_start_point:
						#path_found = true
						#print("Path found!")
						#break
			#if path_found:
				#break
	
	#var ind = hybrid_astar.qp.peek_item()
	#var n_curr = hybrid_astar.open_set[ind]
	#hybrid_astar.closed_set[ind] = n_curr
	
	#if false:
		#var res_update = hybrid_astar.update_node_with_analystic_expantion(n_curr, hybrid_astar.ngoal, true)
		#var fpath = res_update[1]
		#var path = hybrid_astar.extract_path(hybrid_astar.closed_set, fpath, hybrid_astar.nstart)
	
	#if path.pind < 0: return
	#var path = hybrid_astar.extract_any_path(hybrid_astar.closed_set, n_curr, hybrid_astar.ngoal)
	#var path = hybrid_astar.final_path
	
	var path = hybrid_astar.extract_any_path(
		hybrid_astar.closed_set,
		hybrid_astar.open_set[hybrid_astar.qp.peek_item()],
		hybrid_astar.ngoal)
	
	# BUG paths returned are too short and out of order
	anim.resize(0)
	for k in path.x.size():
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
	prints(path.x.size(), anim.size())

func draw_nodes():
	for c in %Nodes.get_children():
		c.queue_free()
	for kk in hybrid_astar.closed_set:
		var path = hybrid_astar.closed_set[kk]
		for k in path.x.size():
			#prints(path.x, path.y)
			var px:float = path.x[k]
			var py:float = path.y[k]
			var pyaw:float = path.yaw[k]
			var obs := CSGBox3D.new()
			obs.size = Vector3(0.2, 0.2, 2.0)
			obs.position.x = px
			obs.position.z = py
			obs.rotation.y = -pyaw + deg_to_rad(90)
			%Nodes.add_child(obs)

func draw_analystic_expantion_path():
	if hybrid_astar.analystic_expantion_paths == null: return
	if hybrid_astar.analystic_expantion_paths.size() == 0: return
	if analystic_expantion_path_id >= hybrid_astar.analystic_expantion_paths.size():
		analystic_expantion_path_id = 0
	var path = hybrid_astar.analystic_expantion_paths[analystic_expantion_path_id]
	
	for c in %AnalysticExpantionPaths.get_children():
		c.queue_free()
	for k in path.x.size():
		var px:float = path.x[k]
		var py:float = path.y[k]
		var obs := CSGBox3D.new()
		obs.size = Vector3.ONE * 0.1
		obs.position.x = px
		obs.position.z = py
		%AnalysticExpantionPaths.add_child(obs)
	analystic_expantion_path_id += 1

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		iterate_pathfinding()
	elif event.is_action_pressed("ui_down"):
		draw_analystic_expantion_path()
	elif event.is_action_pressed("ui_up"):
		end_search = true

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
