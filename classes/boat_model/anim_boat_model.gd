class_name AnimBoatModel

var simple_boat_model := SimpleBoatModel.new()

var time:float
var anim:Array[Dictionary]
var anim_frame := 0
var anim_tick := 0
var anim_subtick := 0

var anim_ticks_delta:float
func _init() -> void:
	anim_ticks_delta = 0.1
	simple_boat_model.configure(10.0)

func is_playing() -> bool:
	return anim_frame <= anim.size()-1

func current_frame() -> Dictionary:
	if is_playing():
		return anim[anim_frame]
	else:
		return anim[anim_frame-1]

var rudder_angle:float
var revs_per_second:float
func tick(delta: float) -> Vector3:
	if anim_frame >= anim.size():
		return Vector3.ZERO
	# Calculate forces 10 times per second
	if anim_tick == 0: # On tick
		if anim_frame == 0: # On frame
			simple_boat_model.linear_velocity = anim[anim_frame].linear_velocity
			simple_boat_model.angular_velocity = anim[anim_frame].angular_velocity
			simple_boat_model.position = Vector2(anim[anim_frame].x, anim[anim_frame].y)
			simple_boat_model.rotation = anim[anim_frame].yaw
			assert(simple_boat_model.position == Vector2(15,15))
			anim_frame += 1
			return Vector3.ZERO
		if anim_frame > 0 and false:
			simple_boat_model.linear_velocity = anim[anim_frame-1].linear_velocity
			simple_boat_model.angular_velocity = anim[anim_frame-1].angular_velocity
			simple_boat_model.position = Vector2(anim[anim_frame-1].x, anim[anim_frame-1].y)
			simple_boat_model.rotation = anim[anim_frame-1].yaw
	
		rudder_angle = anim[anim_frame].steer
		revs_per_second = float(anim[anim_frame].direction)
	
	var boat_forces := simple_boat_model.calculate_boat_forces(
		revs_per_second,
		rudder_angle
	)
	simple_boat_model.step(delta)

	anim_subtick += 1
	assert(Engine.physics_ticks_per_second * anim_ticks_delta > 0)
	if anim_subtick >= Engine.physics_ticks_per_second * anim_ticks_delta:
		anim_tick += 1
		anim_subtick = 0
		if anim_tick >= anim[anim_frame].ticks:
			anim_frame += 1
			anim_tick = 0
	
	return boat_forces

func fast_torward(time_in_seconds: float, delta: float) -> Array[Vector3]:
	assert(delta>0)
	for n in int(time_in_seconds/delta):
		tick(delta)
	var vel := Vector3(
		simple_boat_model.linear_velocity.x,
		simple_boat_model.linear_velocity.y,
		simple_boat_model.angular_velocity,
		)
	return [vel, Vector3(
		simple_boat_model.position.x,
		simple_boat_model.position.y,
		simple_boat_model.rotation
	)]

func set_anim(animation:Array[Dictionary]):
	anim_frame = 0
	anim_tick = 0
	anim_subtick = 0
	anim = animation
