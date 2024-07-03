extends RigidBody3D

func _ready() -> void:
	%pepa.get_node("AnimationPlayer").play("Sitting")
	%pepa.visible = false

func pepa_visible(value=true):
	%pepa.visible = value

func set_camera():
	%Camera3D.current = true
