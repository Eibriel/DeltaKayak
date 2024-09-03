extends Control

var boat_model := BoatModel.new()

var revs_per_second := 0.0
var rudder_angle := 0.0

var forces = {
	"force": Vector2(3.85, 0.0),
	"moment": 0.0
}

func _ready() -> void:
	boat_model.load_parameters()
	boat_model.tests()
	boat_model.linear_velocity = Vector2(3.85, 0.0) # m/s
	boat_model.angular_velocity = 0.0 # r/s
	#boat_model.p.yaw_rate = 0.0 #r/s
	
	revs_per_second = 4.0
	rudder_angle = deg_to_rad(10.0)
	
	return
	#print(rudder_angle)
	var f = {
		"force": Vector2(3.85, 0.0),
		"moment": 0.0
	}
	for _n in range(10):
		#prints("n", _n)
		var linear_velocity:Vector2 = f.force
		var angular_velocity:float = f.moment
		var new_f = boat_model.extended_boat_model(
			linear_velocity,
			angular_velocity,
			revs_per_second,
			rudder_angle)
		#prints("Raw:", new_f.force, new_f.moment)
		assert(new_f.force.x != NAN)
		f.force += new_f.force
		f.moment += new_f.moment
		#prints(f.force, f.moment)

func _process(_delta: float) -> void:
	var linear_velocity:Vector2 = forces.force
	var angular_velocity:float = forces.moment
	
	var f := boat_model.extended_boat_model(
		linear_velocity,
		angular_velocity,
		revs_per_second,
		rudder_angle)

	forces.force += f.force * _delta
	forces.moment += f.moment * _delta
	
	%Boat.rotation += forces.moment * _delta
	%Boat.position += forces.force.rotated(%Boat.rotation) * _delta
	%Rudder.rotation = -rudder_angle

	%ForceLabel.text = "F: %.4f : %.4f" % [forces.force.x, forces.force.y]
	%MomentLabel.text = "M: %.4f" % forces.moment
	
	%ControlsLabel.text = "%.1f rps\n%dº - %.1f" % [revs_per_second, rad_to_deg(rudder_angle), rudder_angle]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		rudder_angle += deg_to_rad(1)
	elif event.is_action_pressed("ui_right"):
		rudder_angle -= deg_to_rad(1)
	
	if event.is_action_pressed("ui_up"):
		revs_per_second += 10.0
	elif event.is_action_pressed("ui_down"):
		revs_per_second -= 10.0
		#revs_per_second = max(0.01, revs_per_second)
