extends RigidBody3D
class_name FloatingElement

@export var model:Node3D
@export var break_sound:AudioStreamPlayer3D
@export var break_particles:GPUParticles3D
@export var break_point:float
@export var smart_damp:float

func _ready() -> void:
	model.rotation.x = randf_range(deg_to_rad(0), deg_to_rad(360))

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Damp if not colliding
	if smart_damp > 0 and state.get_contact_count() == 0:
		var tps:float = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
		state.linear_velocity *= 1.0 - (smart_damp / tps)
	# Handle destruction
	if break_point > 0:
		if state.get_contact_count() > 0:
			var collision_impulse:float = state.get_contact_impulse(0).length()
			#print("Impulse:", collision_impulse)
			if collision_impulse > break_point:
				destroy.call_deferred()

func destroy() -> void:
	Global.character.release_grab() # TODO only if is grabbing this item
	#queue_free()
	global_position.y = -3
	break_particles.emitting = true
	break_sound.play()
