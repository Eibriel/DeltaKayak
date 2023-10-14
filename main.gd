extends Node3D

@onready var player = $Player
@onready var damage_texture = $DamageTexture
@onready var enemies = $Enemies
@onready var camera := %Camera3D

const CLAIM_DISTANCE = 2*2*2 # Squared distance

var last_enemy_spawn := 9999.0

var needed_xp := 0

var wave_time := 60.0
var wave_quota := 500


func _ready():
	Global.player = player
	Global.enemies_node = enemies
	player.connect("damage_update", _on_damage_update)
	player.connect("paddle_left", _on_paddle_left)
	player.connect("paddle_right", _on_paddle_right)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	Global.connect("dropped_item", _on_dropped_item)
	Global.connect("claimed_item", _on_claimed_item)
	start_level()


func _process(delta):
	$Player/Node3D2.position = $Player.position
	#
	last_enemy_spawn += delta
	wave_time -= delta
	if wave_time < 0:
		wave_time = 60.0
		wave_quota = randi_range(150, 1500)
	if enemies.get_children().size() >= wave_quota: return
	if last_enemy_spawn > 0.1:
		last_enemy_spawn = 0.0
		spawn_enemy()
	#check_collisions()
	update_time(delta)


func start_level():
	if Global.player_level == 1:
		equip_weapon("snowplow")
	if Global.player_level == 2:
		equip_weapon("fireball")
	if Global.player_level == 3:
		equip_weapon("laser")
	needed_xp = Global.level_xp(Global.player_level)
	update_xp()


func update_time(delta):
	Global.player_time += delta
	%TimeLabel.text = "%f" % Global.player_time
	# TODO move to other place
	%KillsLabel.text = "%d K" % Global.player_kills

func update_xp():
	%XPProgressBar.value = (Global.player_xp * 100) / needed_xp
	#%XPLabel.text = "%d" % Global.player_xp
	%LevelLabel.text = "LV %d" % Global.player_level

func update_damage():
	%DamageLabel.text = "%f" % Global.player_damage

#func check_collisions():
#	for i in $Items.get_children():
#		if player.global_position.distance_squared_to(i.global_position) < CLAIM_DISTANCE:
#			i.claim()


func load_enemies():
	for e in Global.enemies:
		var enemy = load("res://enemies/%s.tscn" % e)

func spawn_enemy():
	var enemy_list = Global.enemies.pick_random()
	var enemy = load("res://enemies/%s.tscn" % enemy_list)
	var e = enemy.instantiate()
	enemies.add_child(e)
	
	var width := 640
	var height := 480
	var screen_corners = [
		Vector2i(0, 0),
		Vector2i(0, height),
		Vector2i(width, height),
		Vector2i(width, 0),
		Vector2i(0, 0)
	]
	var corner_intersections = []
	for c in screen_corners:
		var rayVector = camera.project_ray_normal(c)
		var rayPoint = camera.project_ray_origin(c)
		var intersection = planeRayIntersection(rayVector,rayPoint, Vector3.ZERO, Vector3.UP)
		corner_intersections.append(intersection)
	
	#var p = randi_range(0, screen_corners.size()-2)
	var p = [0, 0, 0, 1, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3].pick_random()
	e.global_position = lerp(corner_intersections[p], corner_intersections[p+1], randf()) + Vector3(0, 1, 0)

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
	Global.player_damage = damage
	update_damage()
	if Global.player_damage == 1:
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
			Global.player_xp += amount
			update_xp()
			if Global.player_xp >= needed_xp:
				Global.player_xp -= needed_xp
				Global.player_level += 1
				start_level()


func planeRayIntersection(rayVector: Vector3, rayPoint: Vector3, planePoint: Vector3, planeNormal: Vector3):
	var diff: Vector3 = rayPoint - planePoint
	var prod1 = diff.dot(planeNormal)
	var prod2 = rayVector.dot(planeNormal)
	var prod3 = prod1 / prod2
	var intersection: Vector3 = rayPoint - (rayVector * prod3)
	return intersection
