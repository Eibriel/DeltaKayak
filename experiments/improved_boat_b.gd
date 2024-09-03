extends RigidBody3D

var hybrid_astar := HybridAStarBoat.new()
var boat_sim := BoatModel.new()

var area_size := Vector2i(60, 60)
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
	"yaw":0.0,
	"position": Vector2.ZERO
}

func _ready() -> void:
	print("Loading BoatModel")
	boat_sim.load_parameters()
	
	define_area()
	start_yaw = rotation.y - deg_to_rad(90)
	goal_pos = global_to_area(Global.tri_to_bi(-%NavTarget.global_position)-center)
	goal_yaw = %NavTarget.rotation.y - deg_to_rad(90)

	#var obs_res:Array[Vector2i] = get_obstacles()
	var ox:Array[int] = get_obstacles()[0]
	var oy:Array[int] = get_obstacles()[1]
	for n in ox.size():
		var obs := CSGBox3D.new()
		var pos := area_to_global(Vector2(ox[n], oy[n])-center)
		obs.position.x = pos.x
		obs.position.z = pos.y
		%Obstacles.add_child(obs)
	
	hybrid_astar.hybrid_astar_planning(
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
	
	lines_mat.albedo_color = Color.RED
	lines_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	cost_mat.albedo_color = Color.ORANGE_RED
	cost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

func _physics_process(delta: float) -> void:
	time += delta
	if not anim_playing: return
	if anim.size() == 0: return 
	if anim_frame >= anim.size(): return
	if time < 0.1: return
	time = 0.0
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
	#%SteerLabel.text = "Steer: %dº" % rad_to_deg(anim[anim_frame].steer)
	#%RevsLabel.text = "Revs: %d" % r
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
	
	var pos := area_to_global(Vector2(local_data.position.x, local_data.position.y)) - center
	
	position.x = pos.x
	position.z = pos.y
	rotation.y = -local_data.yaw + deg_to_rad(90+180)
	#%Rudder.rotation.y = -anim[anim_frame].steer
	
	anim_tick += 1
	if anim_tick >= anim[anim_frame].ticks:
		anim_frame += 1
		anim_tick = 0

func iterate_pathfinding():
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
	if path.pind < 0: return
	path = hybrid_astar.extract_path(hybrid_astar.closed_set, path, hybrid_astar.ngoal)
	anim.resize(0)
	for k in path.x.size():
		#prints(path.x, path.y)
		#var px:float = path.x[k]
		#var py:float = path.y[k]
		var pos := area_to_global(Vector2(path.x[k], path.y[k])-center)
		var pyaw:float = path.yaw[k]
		var obs := CSGBox3D.new()
		obs.size = Vector3(0.2, 0.2, 2.0)
		obs.position.x = pos.x
		obs.position.z = pos.y
		obs.rotation.y = -pyaw + deg_to_rad(90)
		obs.material = lines_mat
		%Nodes.add_child(obs)
		
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
		iterate_pathfinding()
	elif event.is_action_pressed("ui_up"):
		anim_playing = true

func define_area() -> void:
	origin = Global.tri_to_bi(global_position)
	center = Vector2(area_size) / 2.0
	start_pos = Vector2(center)
	
func global_to_area(global_pos:Vector2) -> Vector2:
	return origin - global_pos

func area_to_global(local_pos:Vector2) -> Vector2:
	return local_pos + origin

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

	return [ox, oy]

func draw_hmap():
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
			var pos := area_to_global(Vector2(hx, hy)-center)
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
