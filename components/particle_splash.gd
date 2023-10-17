extends Node3D

var parent: Node3D

func _ready():
	parent = get_parent_node_3d()
	parent.connect("received_attack", play_particles)

func play_particles():
	$GPUParticles3D.set_emitting(true)
