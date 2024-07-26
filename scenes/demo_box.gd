extends RigidBody3D

@export var label_text:String
@export var target_position:Vector3

func _ready() -> void:
	set_off()

func set_off():
	set_light_color(Color.YELLOW)
	%SparkParticles.amount_ratio = 0.0

func set_on():
	set_light_color(Color.GREEN)
	%SparkParticles.amount_ratio = 1.0

func set_light_color(light_color:Color):
	var bulb:MeshInstance3D = %generator.get_node("LightBulb")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = light_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb.material_override = mat
