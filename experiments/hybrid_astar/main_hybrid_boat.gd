extends Node3D

var time := 0.0

var anim:Array[Dictionary]
var anim_frame := 0
var anim_tick := 0

var hybrid_astar := HybridAStarBoat.new()
var boat_sim := BoatModel.new()

var end_search := false

var local_data := {
	"force": Vector2.ZERO,
	"moment": 0.0,
	"yaw":0.0,
	"position": Vector2.ZERO
}

func _process(delta: float) -> void:
	time += delta
	if hybrid_astar.state == hybrid_astar.STATES.ITERATING:
		for _n in 100:
			iterate_pathfinding()
			if hybrid_astar.state != hybrid_astar.STATES.ITERATING:
				break
	if time < 0.1: return
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
			local_data.position.x = anim[anim_frame].x
			local_data.position.y = anim[anim_frame].y
			local_data.yaw = anim[anim_frame].yaw
		elif anim_frame > 0:
			local_data.position.x = anim[anim_frame-1].x
			local_data.position.y = anim[anim_frame-1].y
			local_data.yaw = anim[anim_frame-1].yaw
	
	var r := float(anim[anim_frame].direction) * 10.0
	%SteerLabel.text = "Steer: %dº" % rad_to_deg(anim[anim_frame].steer)
	%RevsLabel.text = "Revs: %d" % r
	var size_scale := 0.01
	var linear_velocity:Vector2 = local_data.force
	var angular_velocity:float = local_data.moment
	var new_local_forces = boat_sim.extended_boat_model(
		linear_velocity,
		angular_velocity,
		r,
		anim[anim_frame].steer)
	local_data.force += new_local_forces.force * size_scale
	local_data.moment += new_local_forces.moment
	local_data.yaw -= local_data.moment
	local_data.position += local_data.force.rotated(local_data.yaw)
	
	%Agent.position.x = local_data.position.x
	%Agent.position.z = local_data.position.y
	%Agent.rotation.y = -local_data.yaw + deg_to_rad(90)
	%Rudder.rotation.y = -anim[anim_frame].steer
	
	#prints(anim_frame, anim_tick)
	
	anim_tick += 1
	if anim_tick >= anim[anim_frame].ticks:
		anim_frame += 1
		anim_tick = 0

func _ready() -> void:
	print("test HeapDictTest")
	var heapdict_test := HeapDictTest.new()
	heapdict_test.test_main()
	
	print("Loading BoatModel")
	boat_sim.load_parameters()
	boat_sim.tests()
	
	print("start!")
	var x = 51
	var y = 31
	var sx = 10.0
	var sy = 7.0
	var syaw0 = deg_to_rad(-45.0) # 120
	var gx = 45.0
	var gy = 10.0
	var gyaw0 = deg_to_rad(90.0)

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
		Vector2.ZERO,
		0.0,
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
	
	var path
	var path_cost
	for kk in hybrid_astar.closed_set:
		path = hybrid_astar.closed_set[kk]
		pass
		
	#if path.pind < 0: return
	path = hybrid_astar.extract_any_path(hybrid_astar.closed_set, path, hybrid_astar.ngoal)
	#var path = hybrid_astar.final_path
	
	for k in path.x.size():
		anim.append({
			"x": path.x[k],
			"y": path.y[k],
			"yaw": path.yaw[k],
			"direction": path.direction[k],
			"steer": path.steer[k],
			"ticks": path.ticks[k]
		})

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
