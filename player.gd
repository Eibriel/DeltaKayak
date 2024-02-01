extends RigidBody3D
class_name Player

signal make_noise(intensity:int)
signal damage_update(damage: float)
signal paddle_left(level: float)
signal paddle_right(level: float)
signal received_attack

@export var paddle_force: Curve

@onready var left_paddle = $LeftPaddle
@onready var right_paddle = $RightPaddle

@onready var audio_paddle_right = $AudioPaddleRight
@onready var audio_paddle_left = $AudioPaddleLeft
@onready var audio_collision = $AudioCollision
@onready var character_animation = $character/AnimationPlayer


const SPEED := 140 #370
const TORQUE := 30 #60
const KAYAKS := {
	"NORMAL_PINK": 0,
	"NORMAL_CIAN": 1,
	"NORMAL_GREEN": 2,
	"NORMAL_VIOLET": 3,
	"HOTDOG": 4,
	"BANANA": 5
}

var torque := .0
var paddle_previous_status := 0
var paddle_status := 0
var paddle_hold := .0
var next_paddle := 0
var consecutive_paddling := 0
var alternate_paddling := -1
var first_paddle := 0
var previous_side := 0
var stopped := true
var holding := false

#var max_life := 100
var life:float = 100.0
var recovery_life := 0.0
var recovery_time := 0.0

var kayak_material: StandardMaterial3D
var character_material: StandardMaterial3D

func _ready():
	character_animation.get_animation("Idle").loop_mode = 1
	character_animation.get_animation("Idle")
	character_animation.set_blend_time("Idle", "LeftPaddle", 0.2)
	character_animation.set_blend_time("Idle", "RightPaddle", 0.2)
	character_animation.set_blend_time("LeftPaddle", "RightPaddle", 0.2)
	character_animation.set_blend_time("RightPaddle", "LeftPaddle", 0.2)
	character_animation.set_blend_time("LeftPaddle", "Idle", 0.2)
	character_animation.set_blend_time("RightPaddle", "Idle", 0.2)
	play_animation("idle")
	
#	var kayak_mesh:ArrayMesh = $Kayak/Kayak2.mesh
#	kayak_material = kayak_mesh.surface_get_material(0)
#	kayak_material.shading_mode = StandardMaterial3D.SHADING_MODE_PER_VERTEX
#	kayak_material.emission_enabled = true
	var character_mesh:ArrayMesh = $character/Armature/Skeleton3D/Character.mesh
	character_material = character_mesh.surface_get_material(0)
	character_material.shading_mode = StandardMaterial3D.SHADING_MODE_PER_VERTEX
	character_material.emission_enabled = true
	

func _input(event):
	#TODO if trying to press 2 buttons at the same time
	#change state when first button is released. Don't block
	if event.is_action_pressed("paddle_left"):
		if paddle_status == 0:
			next_paddle = 0
			set_paddle_state(-1)
			play_animation("left")
		else:
			next_paddle = -1
	elif event.is_action_pressed("paddle_right"):
		if paddle_status == 0:
			next_paddle = 0
			set_paddle_state(1)
			play_animation("right")
		else:
			next_paddle = 1
	elif event.is_action_released("paddle_left") or event.is_action_released("paddle_right"):
		match next_paddle:
			0:
				set_paddle_state(0)
				play_animation("idle")
			-1:
				set_paddle_state(-1)
				play_animation("left")
			1:
				set_paddle_state(1)
				play_animation("right")
		next_paddle = 0

func _process(delta):
	recovery_time += delta
	if recovery_time >= 1.0:
		recovery_time = 0.0
		life += Global.player_modifiers.recovery
		if life > Global.player_modifiers.max_health:
			life = Global.player_modifiers.max_health

func _physics_process(delta):
	var new_state = false
	var started_holding = false
	if paddle_status != paddle_previous_status:
		if stopped:
			first_paddle = true
		else:
			first_paddle = false
		paddle_hold = .0
		paddle_previous_status = paddle_status
		new_state = true
		emit_signal("paddle_right", 0)
		emit_signal("paddle_left", 0)
	else:
		paddle_hold += delta
	if paddle_hold >= 1.5:
		if !holding:
			holding = true
			started_holding = true
			alternate_paddling = -1
	else:
		holding = false
	
	if paddle_status == 1:
		torque = TORQUE
		emit_signal("paddle_right", min(1, paddle_hold/1.5))
	elif paddle_status == -1:
		torque = -TORQUE
		emit_signal("paddle_left", min(1, paddle_hold/1.5))
	
	left_paddle.position.y = 0.2
	right_paddle.position.y = 0.2
	Global.camera.rotate_z(-Global.camera.rotation.z*0.05)
	if paddle_status != 0 :
		if !holding:
			var turning_assist: float = 1.0 - min(1, float(consecutive_paddling) / 2)
			var torque_assist: float = (1.0 - turning_assist) * float(torque) * 1
			var rithm_assist: float = 1 + min(1, float(alternate_paddling) / 20)
			if !first_paddle:
				var modified_speed = SPEED * (Global.player_modifiers.move_speed * 0.01)
				go_forward((modified_speed*rithm_assist)*paddle_force.sample(paddle_hold)*turning_assist*delta)
			var torque:float = (torque+torque_assist)*paddle_force.sample(paddle_hold)*delta
			apply_torque(Vector3(0, torque, 0))
			Global.camera.rotate_z(torque*0.001)
			if paddle_status == -1:
				right_paddle.position.y = 0.2
				left_paddle.position.y = 0
				left_paddle.position.z = paddle_force.sample(paddle_hold)
			elif paddle_status == 1:
				left_paddle.position.y = 0.2
				right_paddle.position.y = 0
				right_paddle.position.z = paddle_force.sample(paddle_hold)
		else:
			apply_torque(Vector3(0, -torque*paddle_force.sample(paddle_hold-1.5)*delta*3, 0))
		if new_state:
			#print("Paddle")
			pass
		elif started_holding:
			#print("Hold")
			pass
	stopped = false
	if holding:
		stopped = true


func set_paddle_state(state: int):
	paddle_status = state
	if state != 0:
		play_paddle_sound(state)
		emit_signal("make_noise", 2)
		if state == previous_side:
			consecutive_paddling += 1
			alternate_paddling = 0
		else:
			consecutive_paddling = 0
			alternate_paddling += 1
		previous_side = state


func _integrate_forces(state):
	if paddle_status !=0 and holding:
		state.linear_velocity *= 0.99
		state.angular_velocity *= 0.999
	else:
		state.linear_velocity *= 0.999
		state.angular_velocity *= 0.99
	var forward_direction := (transform.basis * Vector3.FORWARD).normalized()
	var forward_component: Vector3 = forward_direction * state.linear_velocity.dot(forward_direction)
	state.linear_velocity = forward_component
	


func go_forward(speed:float):
	var direction := (transform.basis * Vector3.FORWARD).normalized()
	apply_central_force(direction * speed)


func play_paddle_sound(side):
	var sound_path = "res://sounds/paddle_0"+str(randi_range(1, 9))+".mp3"
	var sound = load(sound_path)
	if side == 1:
		audio_paddle_right.stream = sound
		audio_paddle_right.play()
	elif side == -1:
		audio_paddle_left.stream = sound
		audio_paddle_left.play()


func _on_body_entered(_body):
	var sound_path = "res://sounds/collision_0"+str(randi_range(1, 8))+".mp3"
	var sound = load(sound_path)
	audio_collision.stream = sound
	audio_collision.play()
	emit_signal("make_noise", 6)
	#add_damage(30)


func play_animation(anim: String):
	character_animation.speed_scale = 2
	match anim:
		"idle":
			character_animation.play("Idle")
		"right":
			character_animation.play("RightPaddle")
			character_animation.seek(0.6)
		"left":
			character_animation.play("LeftPaddle")
			character_animation.seek(0.6)


func receive_attack(damage:float):
	damage -= Global.player_modifiers.armor
	if damage < 0.:
		damage = 0.
	prints("DAMAGE:", damage)
	var modified_max_life: float = Global.player_modifiers.max_health
	life -= damage
	if life < 0.:
		life = 0.
	var damage_level: float = 1. - (life/modified_max_life)
	#print(damage_level)
	var tween = create_tween()
	tween.set_parallel()
	tween.tween_property(kayak_material, "emission", Color.RED, 0.1)
	tween.tween_property(character_material, "emission", Color.RED, 0.1)
	tween.set_parallel(false)
	tween.tween_property(character_material, "emission", Color.BLACK, 0.1)
	tween.tween_property(kayak_material, "emission", Color.BLACK, 0.1)
	emit_signal("damage_update", damage_level)
	emit_signal("received_attack")


func add_weapon(node: Node3D):
	$Weapons.add_child(node)


func set_kayak(kayak_id: int):
	return
	$Normal.visible = false
	$Banana.visible = false
	$Hotdog.visible = false
	var particle_material = $GPUParticles3D_Trail.draw_pass_1.material
	var water_material = $Water.material
	match kayak_id:
		KAYAKS.NORMAL_PINK:
			kayak_material = $Normal.mesh.surface_get_material(0)
			$Normal.visible = true
			$OmniLight3D2.light_color = Color(0.85, 0.41, 0.64)
			$OmniLight3D3.light_color = Color(0.98, 0.85, 0.89)
			particle_material.albedo_color = Color(0.54, 0.15, 0.31)
			kayak_material.albedo_color = Color(0.54, 0.15, 0.31)
			water_material.set_shader_parameter("albedo", Color(0.29, 0.01, 0.2))
		KAYAKS.NORMAL_GREEN:
			kayak_material = $Normal.mesh.surface_get_material(0)
			$Normal.visible = true
			$OmniLight3D2.light_color = Color(0.42, 0.85, 0.41)
			$OmniLight3D3.light_color = Color(0.9, 0.98, 0.84)
			particle_material.albedo_color = Color(0.15, 0.54, 0.24)
			kayak_material.albedo_color = Color(0.15, 0.54, 0.24)
			water_material.set_shader_parameter("albedo", Color(0.01, 0.29, 0.04))
		KAYAKS.NORMAL_CIAN:
			kayak_material = $Normal.mesh.surface_get_material(0)
			$Normal.visible = true
			$OmniLight3D2.light_color = Color(0.41, 0.83, 0.85)
			$OmniLight3D3.light_color = Color(0.84, 0.97, 0.98)
			particle_material.albedo_color = Color(0.15, 0.51, 0.54)
			kayak_material.albedo_color = Color(0.15, 0.51, 0.54)
			water_material.set_shader_parameter("albedo", Color(0.01, 0.27, 0.29))
		KAYAKS.NORMAL_VIOLET:
			kayak_material = $Normal.mesh.surface_get_material(0)
			$Normal.visible = true
			$OmniLight3D2.light_color = Color(0.66, 0.41, 0.85)
			$OmniLight3D3.light_color = Color(0.92, 0.84, 0.98)
			particle_material.albedo_color = Color(0.38, 0.15, 0.54)
			kayak_material.albedo_color = Color(0.38, 0.15, 0.54)
			water_material.set_shader_parameter("albedo", Color(0.19, 0.01, 0.29))
			
		KAYAKS.BANANA:
			kayak_material = $Banana.mesh.surface_get_material(0)
			$Banana.visible = true
			$OmniLight3D2.light_color = Color(0.85, 0.8, 0.41)
			$OmniLight3D3.light_color = Color(0.98, 0.93, 0.84)
			particle_material.albedo_color = Color(0.54, 0.51, 0.15)
			water_material.set_shader_parameter("albedo", Color(0.29, 0.21, 0.01))
		KAYAKS.HOTDOG:
			kayak_material = $Hotdog.mesh.surface_get_material(1)
			$Hotdog.visible = true
			$OmniLight3D2.light_color = Color(0.85, 0.69, 0.41)
			$OmniLight3D3.light_color = Color(0.98, 0.92, 0.84)
			particle_material.albedo_color = Color(0.32, 0.27, 0.11)
			water_material.set_shader_parameter("albedo", Color(0.11, 0.14, 0.05))

func about_to_pause():
	set_paddle_state(0)
	play_animation("idle")
