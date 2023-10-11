extends Node3D

@onready var player = $Player
@onready var damage_texture = $DamageTexture

var current_damage := 0.0

func _ready():
	player.connect("damage_update", _on_damage_update)
	player.connect("paddle_left", _on_paddle_left)
	player.connect("paddle_right", _on_paddle_right)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_damage_update(damage:float):
	var tween = create_tween()
	tween.tween_method(update_damage, current_damage, 1.0, 0.1)
	tween.tween_method(update_damage, 1.0, damage, 0.3)
	current_damage = damage
	
func update_damage(damage:float):
	damage_texture.material.set_shader_parameter("damage_level", damage)

func _on_paddle_left(level:float):
	damage_texture.material.set_shader_parameter("paddle_left", level)
	
func _on_paddle_right(level:float):
	damage_texture.material.set_shader_parameter("paddle_right", level)
