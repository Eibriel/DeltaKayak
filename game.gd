extends Node3D

@onready var player = $Player
@onready var damage_texture = $DamageTexture
#@onready var enemies = $Enemies
@onready var camera := %Camera3D
@onready var pu_button_1 := %LevelUpButton1
@onready var pu_button_2 := %LevelUpButton2
@onready var pu_button_3 := %LevelUpButton3
@onready var text_label: Label = %TextLabel


const CLAIM_DISTANCE = 2*2*2 # Squared distanceg

var last_enemy_spawn := 9999.0

var needed_xp := 0

var wave_time := 0.0
var wave_quota := 15
var current_wave := -1
var boss_spawned := false

#var AgentClass = preload("res://agent_class.gd")

var agents: Array[Agent] = []

func pause():
	player.about_to_pause()
	get_tree().paused = true
	$PauseMenu.show()
	$StatsMenu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func unpause():
	$PauseMenu.hide()
	$StatsMenu.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func levelup():
	get_tree().paused = true
	$LevelUpMenu.show()
	$StatsMenu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var buttons = [
		%LevelUpButton1,
		%LevelUpButton2,
		%LevelUpButton3
	]
	var labels = [
		%LevelUpLabel1,
		%LevelUpLabel2,
		%LevelUpLabel3
	]
	for n in 3:
		var upgrades := []
		upgrades.resize(4)
		upgrades.fill(0)
		upgrades[3] = randi_range(-3, 3)
		buttons[n].text = "Season"
		labels[n].text = "Season %d" % upgrades[3]
		buttons[n].set_meta("powerup", upgrades)

func _ready():
	$PauseMenu.hide()
	$LevelUpMenu.hide()
	$StatsMenu.hide()
	%PaddleLeft.hide()
	%PaddleRight.hide()
	Global.player = player
	Global.camera = camera
	
	player.position.x = -1929.6
	player.position.z = 1860.4
	previous_position = Global.player.position
	
	player.connect("damage_update", _on_damage_update)
	player.connect("paddle_left", _on_paddle_left)
	player.connect("paddle_right", _on_paddle_right)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	Global.connect("claimed_item", _on_claimed_item)
	player.set_kayak(Player.KAYAKS.NORMAL_PINK)
	start_level()
	
	pu_button_1.connect("button_up", _on_select_levelup.bind(pu_button_1))
	pu_button_2.connect("button_up", _on_select_levelup.bind(pu_button_2))
	pu_button_3.connect("button_up", _on_select_levelup.bind(pu_button_3))
	# Skills
	var a_earth_trail := preload("res://skills/earth_trail.gd")
	var a_pebble := preload("res://skills/pebble.gd")
	var a_twister := preload("res://skills/twister.gd")
	var a_lightning := preload("res://skills/lightning.gd")
	var a_fire := preload("res://skills/fire.gd")
	var a_ice_shield := preload("res://skills/ice_shield.gd")
	# Enemies
	var a_drone := preload("res://skills/drone.gd")
	# Items
	var a_xp_drop := preload("res://skills/xp_drop.gd")
	var enemies := [
		#a_drone.new()
	]
	var skills := [
		#a_earth_trail.new(),
		#a_twister.new(),
		#a_pebble.new(),
		#a_lightning.new(),
		#a_fire.new(),
		#a_ice_shield.new()
	]
	var items := [
		a_xp_drop.new()
	]
	agents.append_array(enemies)
	agents.append_array(skills)
	agents.append_array(items)
	for s in skills:
		for e in enemies:
			s.collide_with(e)
	
	var file = "res://world_data.json"
	var json_as_text = FileAccess.get_file_as_string(file)
	var json_as_dict = JSON.parse_string(json_as_text)
	if json_as_dict:
		create_elements(json_as_dict)

func create_elements(elements:Dictionary) -> void:
	for e in elements["dialogue"]:
		var area := Area3D.new()
		var cube := CollisionShape3D.new()
		cube.shape = BoxShape3D.new()
		add_child(area)
		area.add_child(cube)
		#var sph := CSGSphere3D.new()
		#sph.position.z = -1.0
		#sph.scale = Vector3.ONE * 0.2
		#area.add_child(sph)
		area.position = convert_position(e)
		area.scale = convert_scale(e)
		area.rotation_order = EULER_ORDER_XYZ
		area.rotation = convert_rotation(e)
		area.connect("area_entered", dialogue_callback.bind(area, e.lines))
	
	for e in elements["sign"]:
		print(e["text"])
		var label := Label3D.new()
		label.text = (e["text"] as String).replace("|","\n")
		label.font_size = 128
		add_child(label)
		label.position = convert_position(e)
		label.position.y = 3.0
		label.scale = convert_scale(e)
		label.rotation_order = EULER_ORDER_XYZ
		label.rotation = convert_rotation(e)
		label.rotate_y(deg_to_rad(180))
		label.modulate = Color.GREEN

func dialogue_callback(_area:Area3D, area:Area3D, lines:Array):
	print("Entered")
	#var a_diff := angle_difference(area.rotation.y, player.rotation.y)
	prints(area.rotation.y, player.rotation.y)
	var v1 := Vector2.UP.rotated(area.rotation.y)
	var v2 := Vector2.UP.rotated(player.rotation.y)
	prints(v1, v2)
	var a_diff = v1.dot(v2)
	prints(a_diff)
	if a_diff < 0:
		print("Ignored")
		return
	# TODO queue dialogue if previous one is running
	var dialogue_tween := create_tween()
	for l: String in lines:
		for ll in l.split("|"):
			if ll == "":
				dialogue_tween.tween_interval(2.0)
			else:
				dialogue_tween.tween_callback(func(): text_label.visible_ratio = 0)
				dialogue_tween.tween_callback(func(): text_label.text = ll)
				dialogue_tween.tween_property(text_label, "visible_ratio", 1.0, 0.1 * ll.length())
				dialogue_tween.tween_interval(2.0)

func convert_position(e:Dictionary) -> Vector3:
	var v:Vector3
	v.x = e.position_x * 10
	v.y = e.position_z * 10
	v.z = -e.position_y * 10
	return v

func convert_scale(e:Dictionary) -> Vector3:
	var v:Vector3
	v.x = e.scale_x
	v.y = e.scale_z
	v.z = -e.scale_y
	return v

func convert_rotation(e:Dictionary) -> Vector3:
	var v:Vector3
	v.x = e.rotation_x
	v.y = e.rotation_z
	v.z = -e.rotation_y
	return v

func _process(delta: float) -> void:
	$Terrain.position = round(player.position / 10) * 10
	

func _physics_process(delta: float) -> void:
	$Player/Node3D2.position = $Player.position
	update_time(delta)
	handle_wave(delta)
	for agent in agents:
		agent.set_shift(Vector2(Global.player.position.x, Global.player.position.z))
		agent.process(delta)


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		pause()

func handle_wave(delta):
	wave_time -= delta
	if wave_time < 0:
		current_wave += 1
		if current_wave >= Global.waves.size():
			current_wave = 0
		boss_spawned = false
		print(current_wave)
		wave_time = 60.0
		wave_quota = Global.waves[current_wave].min
		agents[0].SPAWN_AMOUNT = wave_quota
		agents[0].SPAWN_INTERVAL = Global.waves[current_wave].time

func start_level():
	if Global.player_level != 1:
		levelup()
		pass
	if Global.player_level == 1:
		pass
	needed_xp = Global.level_xp(Global.player_level)
	update_xp()

var previous_position: Vector3
var total_distance: float
func update_time(delta):
	Global.player_time += delta
	var minutes = (Global.player_time/60) as int
	var seconds = Global.player_time - (minutes*60)
	%TimeLabel.text = "%02d:%02d" % [minutes, seconds]
	# TODO move to other place
	%KillsLabel.text = "%d K" % Global.player_kills
	%SkillsLabel.text = "Earth: %d
Water: %d
Air: %d
Fire: %d
Electricity: %d" % Global.skills

	var vel:float = (previous_position.distance_to(Global.player.position) / delta) * (18.0/5.0)
	total_distance += previous_position.distance_to(Global.player.position)
	%SkillsLabel.text = "%d Km/h
%d meters" % [vel, total_distance]
	previous_position = Global.player.position

func update_xp():
	%XPProgressBar.value = (Global.player_xp * 100.0) / needed_xp
	#%XPLabel.text = "%d" % Global.player_xp
	%LevelLabel.text = "LV %d" % Global.player_level
	var mm = ""
	for pm in Global.player_modifiers:
		mm += "%s: %d\n" % [pm, Global.player_modifiers[pm]]
	%StatsTextLabel.text = mm

func update_damage():
	%DamageProgressBar.value = (1.0 - Global.player_damage) * 100

func _exit_tree():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_damage_update(damage:float):
	#var tween = create_tween()
	#tween.tween_method(update_damage, current_damage, 1.0, 0.1)
	#tween.tween_method(update_damage, 1.0, damage, 0.3)
	Global.player_damage = damage
	update_damage()
	if Global.player_damage == 1:
		back_to_main()

func back_to_main():
	queue_free()
	get_tree().change_scene_to_file("res://main.tscn")
	

#func update_damage(damage:float):
#	#damage_texture.material.set_shader_parameter("damage_level", damage)
#	pass

func _on_paddle_left(level:float):
	damage_texture.material.set_shader_parameter("paddle_left", level)
	if level > 0:
		%PaddleLeft.show()
	else:
		%PaddleLeft.hide()
	
func _on_paddle_right(level:float):
	damage_texture.material.set_shader_parameter("paddle_right", level)
	if level > 0:
		%PaddleRight.show()
	else:
		%PaddleRight.hide()


func _on_claimed_item(item_id: int, amount: float):
	match item_id:
		Global.ITEMS.XP:
			Global.player_xp += amount
			update_xp()
			if Global.player_xp >= needed_xp:
				Global.player_xp -= needed_xp
				Global.player_level += 1
				start_level()

func _on_quit_button_button_up():
	back_to_main()

func _on_resume_button_button_up():
	unpause()

func _on_select_levelup(button):
	player.about_to_pause()
	get_tree().paused = false
	$LevelUpMenu.hide()
	$StatsMenu.hide()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var p: Array = button.get_meta("powerup")
	for n in p.size():
		Global.skills[n] += p[n]
