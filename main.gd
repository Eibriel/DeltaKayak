extends Control

@export var game_preferences:PreferenceResource
@export var game_state:DKDataResource
@export var initial_position: Marker3D

@onready var dk_world: DKWorld = %DKWorld
@onready var label_demo: Label = $Control/LabelDemo
@onready var interactive_labels_control: Control = %InteractiveLabels
@onready var character: RigidBody3D = %character
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var log_label: RichTextLabel = %LogLabel
@onready var dialogue_control: Control = %DialogueControl

var interactive_labels:Dictionary
var in_trigger:Array[String]

var dialogue_queue: Array[DialogueResource]
var dialogue_time: float
var dialogue_tween: Tween
var write_speed: float

var player_state:Array=[]

var temporizador:= 0.0
var grabbed := false
var moved := true # NOTE first sare disabed
var is_intro := true
var foreshadowing := false
var other_side := false
var kayak_k1: RigidBody3D

var SKIP_INTRO = true

var character_home_position:Vector3
var character_home_rotation:Vector3

const UnhandledTriggers = preload("res://interactives/unhandled_triggers.gd")

var puzzle_items:=[]

func _ready() -> void:
	for c in dk_world.get_children():
		if c.has_meta("is_pepa_kayak"):
			kayak_k1 = c
		if c.name == "Enemy":
			Global.enemy = c
		#if c.has_meta("puzzle_item"):
		#	puzzle_items.append(c)
	
	if OS.has_feature("editor"):
		#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		#Global.enemy.current_state = Global.enemy.STATE.GO_HOME
		#Global.enemy.home_position = %EnemyHome03.global_position
		pass
	else:
		%LabelTemporizador.visible = false
		%LogLabel.visible = false
		var sfx_index := AudioServer.get_bus_index("Master")
		AudioServer.set_bus_volume_db(sfx_index, 0.0)
		AudioServer.set_bus_mute(sfx_index, false)
		initial_position = %InitialPosition
		SKIP_INTRO = false
		character.pepa.visible = true
	
	%GameSettingsContainer.visible = false
	%PauseMenuContainer.visible = true
	%PauseMenu.visible = false
	%GameOverMenu.visible = false
	
	Global.main_scene = self
	Global.grab_joint = %GrabJoint3D
	#Global.grab_joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LIMIT_SOFTNESS, 0.01)
	#Global.grab_joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LIMIT_SOFTNESS, 0.01)
	#Global.grab_joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LIMIT_SOFTNESS, 0.01)
	#Global.grab_joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, 0.01)
	#Global.grab_joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, 0.01)
	#Global.grab_joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, 0.01)
	
	Global.grab_kayak = %GrabKayak
	Global.grab_kayak2 = %GrabKayak2
	#Global.grab_kayak.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LIMIT_SOFTNESS, 0.01)
	#Global.grab_kayak.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LIMIT_SOFTNESS, 0.01)
	#Global.grab_kayak.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LIMIT_SOFTNESS, 0.01)
	#Global.grab_kayak.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, 0.01)
	#Global.grab_kayak.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, 0.01)
	#Global.grab_kayak.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, 0.01)
	
	label_demo.visible = false
	if Global.is_demo():
		label_demo.visible = true
	
	dk_world.connect("trigger_entered", on_trigger_entered)
	dk_world.connect("trigger_exited", on_trigger_exited)
	
	dialogue_label.text = ""
	
	#var state_initializer = DkdataInitialization.new()
	#state_initializer.initialize_data(game_state)
	
	#Start
	character.position = initial_position.position #Vector3(0, 0, 0)
	character.rotation = initial_position.rotation #Vector3(0, 0, 0)
	
	character_home_position = %SaveTeleportStart.global_position
	character_home_rotation = %SaveTeleportStart.global_rotation
	
	%ProportionalSlider.value = character.pid_proportional_par
	%IntegralSlider.value = character.pid_integral_par
	%DerivativeSlider.value = character.pid_derivative_par
	
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	#%IntroChatLabel.visible = true
	intro_animation()
	#Global.character.camera.current = true
	
	if DisplayServer.window_get_vsync_mode(0) == DisplayServer.VSYNC_DISABLED:
		%VSyncButton.set_pressed_no_signal(false)
	else:
		%VSyncButton.set_pressed_no_signal(true)
	
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		%FullScreenButton.set_pressed_no_signal(true)
	else:
		%FullScreenButton.set_pressed_no_signal(false)
	%MouseSensibilitySlider.value = Global.mouse_sensibility
	%FPSSpinbox.set_value_no_signal(Engine.max_fps)
	
	%PauseMenu.main_scene = self
	%BlockPath.position.y = -20
	
	%HintLabel.visible = false
	%MenuThanks.visible = false
	
	%Enemydummy.visible = false

func pause():
	if demo_completed: return
	#player.about_to_pause()
	get_tree().paused = true
	%PauseMenu.show()
	%ResumeButton.grab_focus()
	%MenuCoinAudio.play()
	#$StatsMenu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func unpause():
	%PauseMenu.hide()
	%MenuCoinAudio.play()
	#$StatsMenu.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func intro_animation():
	if SKIP_INTRO:
		end_intro_animation()
	else:
		character.lock_paddling(true)
		%CameraIntro.current = true
		%IntroAnimationPlayer.play("intro_animation")
		say_dialogue("demo_start_point")

func end_intro_animation():
	character.lock_paddling(false)
	character.camera.current = true
	dk_world.select_cameras = true
	#%IntroChatLabel.visible = false
	say_hint("MOVEMENT HINT", 5)
	#say_dialogue("demo_start_point")

var hint_time:=0.0
var tween_hint:Tween
func say_hint(text:String, time:float=30)->void:
	%HintAudio.play()
	hint_time = time
	%HintLabel.text = "[p align=right]%s[/p]" % tr(text)
	if tween_hint:
		tween_hint.kill()
	tween_hint = create_tween()
	%HintLabel.visible = true
	%HintLabel.modulate.a = 0.0
	tween_hint.tween_property(%HintLabel, "modulate:a", 1.0, 5.0)

func handle_hint(delta:float)->void:
	if hint_time != -1:
		hint_time -= delta
		hint_time = max(0, hint_time)
	if hint_time == 0:
		hint_time = -1
		if tween_hint:
			tween_hint.kill()
		tween_hint = create_tween()
		%HintLabel.modulate.a = 1.0
		tween_hint.tween_property(%HintLabel, "modulate:a", 0.0, 3.0)
		tween_hint.tween_callback(%HintLabel.set_visible.bind(false))

func hide_hint()->void:
	hint_time = 0

func enemy_attack():
	Global.enemy.current_state = Global.enemy.STATE.SLEEPING

func enemy_set_home(val:int):
	var homes := [
		%EnemyHome01,
		%EnemyHome02,
		%EnemyHome03
	]
	Global.enemy.home_position = homes[val-1].global_position

func teleport_enemy(val:int):
	if Global.enemy.current_state != Global.enemy.STATE.SLEEPING:
		print("Teleport: Enemy not sleeping")
		return
	if Global.enemy.on_sleeping_time < 10:
		print("Teleport: Sleeping time < 10 %.2f" % Global.enemy.on_sleeping_time)
		return
	if not get_viewport().get_camera_3d().is_position_behind(Global.enemy.global_position):
		print("Teleport: Enemy is in front")
		return
	var points := [
		%EnemyTeleport00,
		%EnemyTeleport01
	]
	if get_viewport().get_camera_3d().is_position_in_frustum(points[val].global_position):
		print("Teleport: Teleport point is in camera")
		return
	print("Teleporting!")
	set_enemy_home(points[val])

func set_enemy_home(home:Node3D):
	Global.enemy.home_position = home.global_position
	Global.enemy.global_rotation = home.global_rotation
	Global.enemy.global_position = Global.enemy.home_position
	Global.enemy.current_state = Global.enemy.STATE.SLEEPING
	Global.enemy.on_sleeping_time = 0.0

func _process(delta: float) -> void:
	handle_triggers(delta)
	handle_dialogue(delta)
	handle_stats(delta)
	handle_hint(delta)
	#handle_demo_puzzle()
	handle_enemy_direction_indicator(delta)
	log_label.text = Global.log_text
	Global.log_text = ""
	temporizador += delta
	var minute := int(temporizador / 60)
	var sec := int(temporizador-(minute*60))
	%LabelTemporizador.text = "%02d:%02d" % [minute,sec]
	if Global.camera != null:
		if Global.camera.has_meta("fog_density"):
			%WorldEnvironment.environment.volumetric_fog_density = float(Global.camera.get_meta("fog_density"))
			Global.log_text = "\nFog:%f" % %WorldEnvironment.environment.volumetric_fog_density
		if %CameraIntro.current == true:
			%WorldEnvironment.environment.ambient_light_energy = 0.03
		elif Global.camera == Global.character.camera:
			%WorldEnvironment.environment.ambient_light_energy = 0.0
		else:
			%WorldEnvironment.environment.ambient_light_energy = 0.02

func handle_enemy_direction_indicator(_delta:float) -> void:
	if Global.enemy == null: return
	var dist := Global.character.global_position.distance_to(Global.enemy.global_position)
	var dire := Global.tri_to_bi(Global.character.global_position.direction_to(Global.enemy.global_position))
	dire = dire.rotated(get_viewport().get_camera_3d().global_rotation.y)
	var angle := Vector2.DOWN.angle_to(dire)-deg_to_rad(90)
	var screen_size := get_viewport().get_visible_rect().size
	%EnemyDirectionIndicator.position = screen_size * 0.5
	%EnemyDirectionIndicator.rotation = angle
	%EnemyIndicatorIcon.scale = Vector2.ONE * clampf(remap(dist, 0, 40, 1, 0), 0, 1)

var puzzle_solved := true #false NOTE: puzzle disabled
var puzzle_progress := false
var demo_completed := false
func set_demo_completed():
	if demo_completed: return
	demo_completed = true
	say_dialogue("demo_exit_point")
	GamePlatform.set_achievement("demo_completed")
	%MenuThanks.visible = true
	%MenuThanks.modulate.a = 0.0
	%LabelThanks.text = "%s\n\n%s" % [tr("THANKS FOR PLAYING"), %LabelTemporizador.text]
	%WishlistEndButton.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var sfx_index := AudioServer.get_bus_index("Master")
	var current_db :float= AudioServer.get_bus_volume_db(sfx_index)
	var demo_end_tween:=create_tween()
	demo_end_tween.tween_property(%MenuThanks, "modulate:a", 1.0, 3.0)
	var change_volume := func (vol_db:float):
		AudioServer.set_bus_volume_db(sfx_index, vol_db)
	demo_end_tween.parallel().tween_method(change_volume, current_db, -30.0, 3.0)

func handle_demo_puzzle():
	if puzzle_solved: return
	var match_count := []
	%VinoIndicador.visible = false
	%CarneIndicador.visible = false
	%TierraIndicador.visible = false
	for c in puzzle_items:
		var pos_a := Vector3(c.position.x, 0, c.position.z)
		var pos_b := Vector3(%TierraLabel.position.x, 0, %TierraLabel.position.z)
		var pos_c := Vector3(%VinoLabel.position.x, 0, %VinoLabel.position.z)
		var pos_d := Vector3(%CarneLabel.position.x, 0, %CarneLabel.position.z)
		c.set_off()
		if pos_a.distance_to(pos_b) < 5:
			%TierraIndicador.visible = true
			if not match_count.has("tierra"):
				match_count.append("tierra")
				c.set_on()
		elif pos_a.distance_to(pos_c) < 5:
			%VinoIndicador.visible = true
			if not match_count.has("vino"):
				match_count.append("vino")
				c.set_on()
		elif pos_a.distance_to(pos_d) < 5:
			%CarneIndicador.visible = true
			if not match_count.has("carne"):
				match_count.append("carne")
				c.set_on()
		
	if match_count.size() > 0 and not puzzle_progress:
		puzzle_progress = true
		set_player_state("puzzle_progress")
	if match_count.size() == 3:
		puzzle_solved = true
		%ExitDoorLight.visible = true
		del_player_state("puzzle_progress")
		del_player_state("puzzle_door")
		del_player_state("puzzle_tierra")
		del_player_state("puzzle_carne")
		del_player_state("puzzle_vino")
		set_player_state("puzzle_solved")
		#%DemoExitDoor.position.y = -20
		#print("OpenDoor")

var door_open:=false
func animate_puzzle_door():
	if door_open: return
	door_open = true
	var tween := create_tween()
	tween.tween_property(%DemoExitDoor, "position:y", -2.7, 7)

func handle_stats(_delta):
	#
	if GamePlatform.stats_support["last_player_position"] == null:
		GamePlatform.stats_support["last_player_position"] = Global.character.position
	var character_distance = Global.character.position.distance_to(GamePlatform.stats_support["last_player_position"])
	character_distance *= 0.001 # Meters to Kilometers
	GamePlatform.stats_support["last_player_position"] = Global.character.position
	
	GamePlatform.stats["distance_traveled"] += character_distance

func handle_dialogue(delta:float) -> void:
	dialogue_time -= delta
	if dialogue_label.text == "": # TODO remove this check
		dialogue_control.visible = false
	else:
		dialogue_control.visible = true
	if dialogue_time > 0: return
	dialogue_label.text = ""
	if dialogue_queue.size() < 1: return
	var d: DialogueResource = dialogue_queue.pop_front() as DialogueResource
	if d.id.begins_with("disabled_"): # TODO remove this check
		return
	var key: String = "%s_dialogue_text" % d.resource_scene_unique_id
	var character_string:String = d.Character.keys()[d.character]
	%CharNameLabel.text = tr(character_string)
	dialogue_label.text = tr(key)
	dialogue_label.visible_ratio = 0
	write_speed = dialogue_label.text.length() * 0.08
	dialogue_time = write_speed + (dialogue_label.text.length() * 0.08)
	
	# Voice
	#var idx = Global.voice_id.find(key)
	var resource_group:ResourceGroup = load("res://sounds/all_voice_files.tres")
	var resources = resource_group.load_matching(["**%s*" % key], [])
	#print(resources)
	if resources.size() > 0:
		%VoicePlayer.stop()
		%VoicePlayer.stream = resources[0]
		dialogue_time = %VoicePlayer.stream.get_length()
		%VoicePlayer.play()
	# NOTE this don't work when exported
	#var audio_path := "res://sounds/voice/character/%s.ogg" % key
	#if FileAccess.file_exists(audio_path):
	#	%VoicePlayer.stop()
	#	%VoicePlayer.stream = load(audio_path)
	#	dialogue_time = %VoicePlayer.stream.get_length()
	#	%VoicePlayer.play()
	#
	if is_dialogue_animating():
		dialogue_tween.kill()
	dialogue_tween = create_tween()
	dialogue_tween.tween_property(dialogue_label, "visible_ratio", 1., 1)

func handle_triggers(_delta:float) -> void:
	if Global.camera == null: return
	
	for sector_id in dk_world.world_definition:
		var sector:Dictionary = dk_world.world_definition[sector_id] as Dictionary
		for trigger in sector.triggers:
			var trigger_position = Global.array_to_vector3(trigger.position)
			var primary_label := ""
			var secondary_label := ""
			var trigger_visible := true
			var always_visible := false
			for i in game_state.items:
				if i.trigger_name == trigger.id:
					if true: #not i.visible:
						trigger_visible = false
						break
					if i.primary_action != "":
						var a = get_item_action(i.primary_action, i)
						if a != null:
							var key: String = "%s_action_label" % a.resource_scene_unique_id
							primary_label = tr(key)
					if i.secondary_action != "":
						var a = get_item_action(i.secondary_action, i)
						if a != null:
							var key: String = "%s_action_label" % a.resource_scene_unique_id
							secondary_label = tr(key)
					always_visible = i.always_visible
					break
			if is_in_trigger(trigger.id) and trigger_visible and \
					(Global.camera.is_position_in_frustum(trigger_position) or always_visible):
				var icon = get_interactive(trigger.id, primary_label, secondary_label, true)
				if Global.camera.is_position_in_frustum(trigger_position):
					icon.position = Global.camera.unproject_position(trigger_position)
				elif always_visible:
					icon.position = get_viewport_rect().size * 0.5
				#icon.visible = true
				icon.visible = false
				icon.set_active(false)
				if is_closest_trigger(trigger.id):
					icon.set_active(true)
			else:
				var icon = get_interactive(trigger.id, primary_label, secondary_label, false)
				if icon != null:
					icon.visible = false

func get_item_action(id:String, item:ItemResource) -> ActionResource:
	for a in item.actions:
		if a.id == id:
			return a
	return null

func get_interactive(id:String, primary_label:String, secondary_label:String, create:bool):
	if id not in interactive_labels:
		if create:
			var icon:Control = preload("res://ui/interactive_label.tscn").instantiate() as Control
			icon.primary_text = primary_label
			icon.secondary_text = secondary_label
			interactive_labels[id] = icon
			interactive_labels_control.add_child(icon)
		else:
			return null
		
	return interactive_labels[id]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("primary_action"):
		if is_saying_dialogue():
			skip_dialogue()
			return
		if Global.is_near_carpincho and not Global.carpincho_near.is_petting():
			Global.carpincho_near.pet()
			Global.character.damage = 0.0
			set_player_state("carpincho")
			say_dialogue("pet_carpincho")
			return
		var handled := false
		for id in in_trigger:
			var this_handled := execute_trigger("primary_action", id)
			if this_handled:
				handled = true
		if not handled:
			say_some_dialogue()
	#elif event.is_action_pressed("secondary_action"):
		#if is_saying_dialogue():
			#skip_dialogue()
			#return
		#for id in in_trigger:
			#execute_trigger("secondary_action", id)
	elif event.is_action_pressed("pepa"):
		on_pepa()
	#elif event.is_action_pressed("compicactus"):
	#	on_compicactus()
	elif event.is_action_pressed("quit"):
		#get_tree().quit()
		pause()
	#elif event.is_action_pressed("help"):
	#	%HelpLabel.visible = !%HelpLabel.visible
	elif event.is_action_pressed("ui_text_backspace"):
		if OS.has_feature("debug"):
			#teleport_enemy(1)
			game_over()

func say_some_dialogue()->void:
	if player_state.size() > 0:
		var last_thougth:String = player_state.pop_back()
		match last_thougth:
			"gol":
				say_dialogue("think_gol")
			"carpincho":
				say_dialogue("think_carpincho")
			"puzzle_door":
				say_dialogue("think_puzzle_door")
			"puzzle_tierra":
				say_dialogue("think_puzzle_tierra")
			"puzzle_carne":
				say_dialogue("think_puzzle_carne")
			"puzzle_vino":
				say_dialogue("think_puzzle_vino")
			"puzzle_progress":
				say_dialogue("think_puzzle_progress")
			"puzzle_solved":
				say_dialogue("think_puzzle_solved")
			"gauchito_gil":
				say_dialogue("think_gauchito_gil")
			"monster_damage":
				say_dialogue("think_monster_damage")
			"monster":
				say_dialogue("think_monster")
	else:
		if other_side:
			say_dialogue("describe_other_side")
		else:
			say_dialogue("describe_night")

func on_pepa():
	if other_side:
		var pepa_dialogues := [
			"pepa_002",
			"pepa_003"
		]
		say_dialogue(pepa_dialogues.pick_random())
	else:
		say_dialogue("pepa_001")

func on_compicactus():
	say_dialogue("compi_im_here")

func on_trigger_entered(id:String):
	#prints("Entered", id)
	if id not in in_trigger:
		in_trigger.append(id)
	execute_trigger("trigger_entered", id)

func on_trigger_exited(id:String):
	#prints("Exited", id)
	if id in in_trigger:
		in_trigger.erase(id)
	execute_trigger("trigger_exited", id)

func execute_trigger(trigger_type:String, trigger_id:String)->bool:
	# var index := "%s:%s" % [type, trigger_id]
	#if not is_closest_trigger(trigger_id): return false
	var handled := false
	for i in game_state.items:
		if not i.active: continue
		if i.trigger_name == trigger_id:
			handled = true
			if "primary_action" == trigger_type and i.primary_action != "":
				var a = get_item_action(i.primary_action, i)
				if a != null:
					if i.logic != null:
						var l_script = i.logic.new()
						l_script._on_trigger(self, game_state, a.id)
					else:
						push_error("Item '%s' has no logic" % i.id)
				else:
					push_error("Action '%s' not found in item '%s'" % [i.primary_action, i.id])
			elif "secondary_action" == trigger_type and i.secondary_action != "":
				var a = get_item_action(i.secondary_action, i)
				if a != null:
					if i.logic != null:
						var l_script = i.logic.new()
						l_script._on_trigger(self, game_state, a.id)
					else:
						push_error("Item '%s' has no logic" % i.id)
				else:
					push_error("Action '%s' not found in item '%s'" % [i.primary_action, i.id])
			else:
				if i.logic != null:
					var l_script = i.logic.new()
					l_script._on_trigger(self, game_state, trigger_type)
	if not handled:
		var unhandled_logic := UnhandledTriggers.new()
		handled = unhandled_logic._on_unhandled_trigger(self, game_state, trigger_id, trigger_type)
	return handled

func is_in_trigger(id:String) -> bool:
	return id in in_trigger

func is_closest_trigger(id:String) -> bool:
	if in_trigger.size() < 1: return false
	if in_trigger.size() == 1: return true
	var min_dist:float = 9999.0
	var min_trigger:String = ""
	for t in in_trigger:
		for sector_id in dk_world.world_definition:
			var sector:Dictionary = dk_world.world_definition[sector_id] as Dictionary
			for trigger in sector.triggers:
				if trigger.id == t:
					var dist := character.position.distance_squared_to(Global.array_to_vector3(trigger.position))
					if min_trigger == "" or dist < min_dist:
						min_dist = dist
						min_trigger = trigger.id
	return id == min_trigger

func say_dialogue(text:String, force: bool = true) -> void:
	for e in game_state.exchanges:
		if e.id == text:
			if force:
				dialogue_queue.resize(0)
				skip_dialogue()
			for d in e.dialogues:
				dialogue_queue.append(d)
			return
	push_error("Cant find dialogue %s" % text)

func skip_dialogue() -> void:
	#dialogue_time = -1.0
	if is_dialogue_animating():
		dialogue_tween.stop()
		dialogue_label.visible_ratio = 1
		dialogue_time -= write_speed
	else:
		dialogue_label.text = ""
		dialogue_time = -1

func is_saying_dialogue() -> bool:
	var is_queue_full := dialogue_queue.size() > 0
	return is_dialogue_animating() or is_queue_full or dialogue_label.text != ""

func is_dialogue_animating() -> bool:
	return dialogue_tween != null and dialogue_tween.is_running()

func sync_misc_data() -> void:
	# NOTE
	# dots (.) in blender object names
	# are turned into lowscores (_) in godot node names
	var misc: MiscDataResource = game_state.misc_data
	node_visible("Muelle1_006", not misc.house_door_open)
	node_collide("Muelle1_006", not misc.house_door_open)
	item_active("character_house_door", not misc.house_door_open)
	item_visible("character_house_door", not misc.house_door_open)
	
	node_visible("Muelle1_007", not misc.next_door_open)
	node_collide("Muelle1_007", not misc.next_door_open)
	item_active("next_door", not misc.next_door_open)
	item_visible("next_door", not misc.next_door_open)
	
	item_active("next_door_key", not misc.has_next_door_key)
	item_visible("next_door_key", not misc.has_next_door_key)
	
	Global.character.pepa.visible = misc.pepa_visible

func node_collide(node_path: NodePath, active: bool):
	var node = dk_world.get_node(node_path)
	for static_body in node.get_children():
		if static_body is StaticBody3D:
			for collision_shape in static_body.get_children():
				if collision_shape is CollisionShape3D:
					collision_shape.disabled = not active

func node_visible(node_path: NodePath, active: bool):
	dk_world.get_node(node_path).visible = active

func item_active(item_id: String, active: bool):
	var item := get_item(item_id)
	if item == null: return
	item.active = active

func item_visible(item_id: String, _visible: bool):
	var item := get_item(item_id)
	if item == null: return
	item.visible = _visible

func get_item(item_id: String) -> ItemResource:
	for i in game_state.items:
		if i.id == item_id:
			return i
	return null

func update_pid_values()->void:
	print("P: %d I: %.1f D: %d" % [
		%ProportionalSlider.value,
		%IntegralSlider.value,
		%DerivativeSlider.value])
	character.pid_proportional_par = %ProportionalSlider.value
	character.pid_integral_par = %IntegralSlider.value
	character.pid_derivative_par = %DerivativeSlider.value

func _on_slider_value_changed(value: float) -> void:
	#update_pid_values()
	pass

func _on_slider_drag_ended(value_changed: bool) -> void:
	#update_pid_values()
	pass

func _on_grab_kayak_body_entered(body: Node3D) -> void:
	if body.name == "character":
		grab_kayak()

func grab_kayak():
	if grabbed: return
	#if not is_grabbing_kayak(): return
	grabbed = true
	var connect_grab = func():
		Global.grab_kayak.global_position = Global.character.global_position
		%KayakGrabber.global_position = Global.character.global_position
		Global.grab_kayak.set_node_a(%KayakGrabber.get_path())
		Global.grab_kayak.set_node_b(Global.character.get_path())
		#
		Global.character.release_grab()
		#Global.grab_kayak2.global_position = kayak_k1.global_position
		#Global.grab_kayak2.set_node_a(%KayakGrabber.get_path())
		#Global.grab_kayak2.set_node_b(kayak_k1.get_path())
	
	%BlockPathOtherSide.position.y = -20
	
	var tt := [
		Vector3(2, 0, 1),
		Vector3(1, 0, -1),
		Vector3(0.5, 0, 0),
		Vector3(-2, 0, -0.5),
	]
	Global.character.lock_grab()
	%Enemydummy.visible =true
	%Enemydummy.global_position = Global.character.global_position
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_callback(%JumpscareAudio.play)
	tween.tween_callback(%JumpscareAudio3.play)
	tween.tween_callback(connect_grab)
	tween.tween_callback(set_player_state.bind("grabbed"))
	tween.tween_callback(say_dialogue.bind("demo_scream"))
	if false:
		tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(0, 0, 1)*3))
		tween.tween_interval(1.0)
		tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(-1, 0, 1)*3))
		tween.tween_callback(say_dialogue.bind("demo2_kayak_movement_3"))
		tween.tween_interval(0.3)
		tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(1, 0, 1)*4))
		tween.tween_interval(0.3)
		tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(-1, 0, 1)*3))
		tween.tween_interval(3)
		tween.tween_callback(connect_grab)
		tween.tween_callback(set_player_state.bind("grabbed"))
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(%KayakGrabber, "global_position", Vector3(-16, 0, -139), 1.3)
		tween.parallel().tween_property(%KayakGrabber, "global_rotation:y", 0, 0.2)
		tween.tween_callback(say_dialogue.bind("demo_scream"))
		tween.tween_property(%KayakGrabber, "global_position", Vector3(-38.872, 0, -146.022), 0.6)
		tween.parallel().tween_property(%KayakGrabber, "global_rotation:y", deg_to_rad(-90+45), 0.7)
		tween.tween_interval(1.0)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(set_datamosh.bind(true))
	tween.tween_property(%KayakGrabber, "global_position", Vector3(-196.017, 0, -147.396), 5.0)
	tween.parallel().tween_property(%KayakGrabber, "global_rotation:y", deg_to_rad(-90+60), 5.0)
	tween.parallel().tween_property(%Enemydummy, "global_position", Vector3(-196.017, 0, -147.396), 5.0)
	tween.tween_callback(ungrab_kayak)
	#tween.tween_callback(kayak_k1.queue_free)
	tween.tween_callback(Global.character.hide_pepa)
	tween.tween_callback(%Enemydummy.set_visible.bind(false))
	tween.tween_interval(3.0)
	tween.tween_callback(say_dialogue.bind("demo_other_side"))
	tween.tween_callback(set_datamosh.bind(false))
	tween.tween_callback(block_backtracking)
	tween.tween_callback(del_player_state.bind("grabbed"))
	tween.tween_callback(set_player_state.bind("other_side"))

func set_player_state(value:String):
	if not player_state.has(value):
		player_state.append(value)

func del_player_state(value:String):
	if player_state.has(value):
		player_state.erase(value)

func block_backtracking():
	%BlockPath.position.y = 0
	set_enemy_home(%EnemyHome00)
	Global.enemy.home_position = %EnemyHome01.global_position
	Global.enemy.current_state = Global.enemy.STATE.GO_HOME

func set_datamosh(value:bool):
	#%WorldEnvironment.compositor.compositor_effects[0].enabled = value
	if value:
		Global.force_datamosh = 0.7
	else:
		var dm_tween := create_tween()
		dm_tween.tween_property(Global, "force_datamosh", 0.0, 10.0)

func ungrab_kayak():
	Global.grab_kayak.set_node_a(NodePath(""))
	Global.grab_kayak.set_node_b(NodePath(""))
	Global.grab_kayak.free()
	#
	Global.grab_kayak2.set_node_a(NodePath(""))
	Global.grab_kayak2.set_node_b(NodePath(""))
	Global.grab_kayak2.free()
	
	Global.character.lock_grab(false)


func _on_first_grab_kayak_body_entered(body: Node3D) -> void:
	if moved: return
	#if not is_grabbing_kayak(): return
	moved = true
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_callback(%JumpscareAudio2.play)
	tween.tween_callback(%JumpscareAudio3.play)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(0, 0, 1)*0.5))
	tween.tween_interval(1.0)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(-1, 0, 1)*1))
	tween.tween_interval(0.3)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(1, 0, 1)*2))
	tween.tween_interval(0.3)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(-1, 0, 1)))
	tween.tween_callback(say_dialogue.bind("demo2_kayak_movement"))
	tween.tween_callback(say_hint.bind("LOOK BUTTON HINT"))
	if false:
		tween.tween_interval(10)
		tween.tween_callback(%JumpscareAudio2.set_pitch_scale.bind(0.8))
		tween.tween_callback(%JumpscareAudio2.play)
		tween.tween_callback(%JumpscareAudio2.set_pitch_scale.bind(0.8))
		tween.tween_callback(%JumpscareAudio3.play)
		tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(0, 0, 1)*0.5))
		tween.tween_interval(1.0)
		tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(-1, 0, 1)*1))
		tween.tween_interval(0.3)
		tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(1, 0, 1)*2))
		tween.tween_interval(1.0)
		tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(-1, 0, 1)))
		tween.tween_callback(say_dialogue.bind("demo2_kayak_movement_2"))
		tween.tween_callback(%JumpscareAudio.play)
		#tween.tween_callback(kayak_k1.set_camera)
		tween.tween_callback(dk_world.set_select_cameras.bind(false))
		tween.tween_callback(kayak_k1.pepa_visible.bind(true))
		tween.tween_interval(3.0)
		tween.tween_callback(dk_world.set_select_cameras.bind(true))
		tween.tween_interval(10.0)
		tween.tween_callback(say_dialogue.bind("demo2_kayak_movement_2b"))

func _on_foreshadowing_body_entered(body: Node3D) -> void:
	if foreshadowing: return
	#if not is_grabbing_kayak(): return
	foreshadowing = true
	say_dialogue("demo_foreshadowing")

var heavy_kayak := false
func _on_heavy_kayak_body_entered(body: Node3D) -> void:
	if heavy_kayak: return
	heavy_kayak = true
	say_dialogue("demo_heavy_kayak")


func is_grabbing_kayak():
	var is_grabbing:bool = false
	var grab_path := Global.grab_joint.get_node_b()
	if grab_path:
		var grabbing_item: Node3D = get_node(grab_path)
		is_grabbing = grabbing_item.name == "KayakKone"
	if not is_grabbing:
		if kayak_k1.global_position.z < -139:
			is_grabbing = true
		elif kayak_k1.global_position.distance_to(Global.character.global_position) < 6:
			is_grabbing = true
	if not is_grabbing:
		say_dialogue("demo_forgot_kayak")
	return is_grabbing


func _on_ana_body_entered(body: Node3D) -> void:
	say_dialogue("demo_ana")

func _on_quit_button_button_up() -> void:
	get_tree().quit()

func _on_resume_button_button_up() -> void:
	unpause()


func _on_menu_button_button_up() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_packed(preload("res://menu.tscn"))


func _on_game_settings_button_up() -> void:
	%PauseMenuContainer.visible = false
	%GameSettingsContainer.visible = true
	%BackButton.grab_focus()


func _on_back_button_up() -> void:
	%PauseMenuContainer.visible = true
	%GameSettingsContainer.visible = false
	%ResumeButton.grab_focus()


func _on_full_screen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _on_v_sync_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ADAPTIVE, 0)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED, 0)
	#Engine.max_fps
	#RenderingServer.force_sync()


func _on_mouse_sensibility_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed: return
	Global.mouse_sensibility = %MouseSensibilitySlider.value


func _on_fps_spinbox_value_changed(value: float) -> void:
	Engine.max_fps = int(%FPSSpinbox.value)


func _on_master_volume_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed: return
	var sfx_index := AudioServer.get_bus_index("Master")
	var value_in_db := remap(%MasterVolumeSlider.value, 0.0, 1.0, -30.0, 6.0)
	AudioServer.set_bus_volume_db(sfx_index, value_in_db)
	if %MasterVolumeSlider.value == 0.0:
		AudioServer.set_bus_mute(sfx_index, true)
	else:
		AudioServer.set_bus_mute(sfx_index, false)


func _on_game_controls_button_up() -> void:
	%HelpLabel.visible = !%HelpLabel.visible


func _on_gol_area_body_entered(body: Node3D) -> void:
	var dist:= Global.character.global_position.distance_to(body.global_position)
	# TODO improve logic
	# maybe should be looking the ball?
	if body.has_node("Football") and dist < 6:
		say_dialogue("gol")

func _on_save():
	character_home_position = %SaveTeleportGil.global_position
	character_home_rotation = %SaveTeleportGil.global_rotation

func game_over():
	if demo_completed: return
	var points := [
		%EnemyTeleport00,
		%EnemyTeleport01
	]
	set_enemy_home(points.pick_random())
	character.global_position = character_home_position
	character.global_rotation = character_home_rotation
	character.damage = 0.0
	%GameOverMenu.visible = true
	%ContinueButton.grab_focus()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_continue_button_up() -> void:
	%GameOverMenu.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_wishlist_button_up() -> void:
	GlobalSteam.open_url("https://store.steampowered.com/app/2632680/Delta_Kayak/?utm_source=demo&utm_content=end_demo")
