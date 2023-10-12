extends Node3D

@onready var player = $Player
@onready var damage_texture = $DamageTexture
@onready var enemies = $Enemies

const CLAIM_DISTANCE = 2*2*2 # Squared distance

var current_damage := 0.0
var last_enemy_spawn := 9999.0

var player_xp := 0
var player_time := 0.0
var player_damage := 0.0

func _ready():
	Global.player = player
	Global.enemies_node = enemies
	player.connect("damage_update", _on_damage_update)
	player.connect("paddle_left", _on_paddle_left)
	player.connect("paddle_right", _on_paddle_right)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	Global.connect("dropped_item", _on_dropped_item)
	Global.connect("claimed_item", _on_claimed_item)
	equip_weapon("fireball")
	equip_weapon("laser")


func _process(delta):
	last_enemy_spawn += delta
	if last_enemy_spawn > 0.8:
		last_enemy_spawn = 0.0
		spawn_enemy()
	check_collisions()
	update_time(delta)


func update_time(delta):
	player_time += delta
	%TimeLabel.text = "%f" % player_time

func update_xp():
	%XPLabel.text = "%d" % player_xp

func update_damage():
	%DamageLabel.text = "%f" % player_damage

func check_collisions():
	for i in $Items.get_children():
		if player.global_position.distance_squared_to(i.global_position) < CLAIM_DISTANCE:
			i.claim()


func load_enemies():
	for e in Global.enemies:
		var enemy = load("res://enemies/%s.tscn" % e)

func spawn_enemy():
	var enemy_list = Global.enemies.pick_random()
	var enemy = load("res://enemies/%s.tscn" % enemy_list)
	var e = enemy.instantiate()
	var random_direction = Vector3(randf()-0.5, 0.0, randf()-0.5).normalized()
	e.position = Global.player.position + (random_direction * 20) + Vector3(0, 1, 0)
	enemies.add_child(e)

func equip_weapon(_weapon: String):
	var weapon = load("res://weapons/%s.tscn" % _weapon)
	var w = weapon.instantiate()
	Global.player.add_weapon(w)

func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_damage_update(damage:float):
	#var tween = create_tween()
	#tween.tween_method(update_damage, current_damage, 1.0, 0.1)
	#tween.tween_method(update_damage, 1.0, damage, 0.3)
	current_damage = damage
	player_damage = current_damage
	update_damage()
	if current_damage == 1:
		get_tree().quit()
	
#func update_damage(damage:float):
#	#damage_texture.material.set_shader_parameter("damage_level", damage)
#	pass

func _on_paddle_left(level:float):
	damage_texture.material.set_shader_parameter("paddle_left", level)
	
func _on_paddle_right(level:float):
	damage_texture.material.set_shader_parameter("paddle_right", level)


func _on_dropped_item(item_id: int, amount: int, pos: Vector3):
	match item_id:
		Global.ITEMS.XP:
			var xp = preload("res://elements/xp_point.tscn").instantiate()
			xp.position = pos
			$Items.add_child(xp)


func _on_claimed_item(item_id: int, amount: int):
	match item_id:
		Global.ITEMS.XP:
			player_xp += amount
			update_xp()
