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

var temporizador:= 0.0
var grabbed := false
var moved := false
var is_intro := true
var foreshadowing := false

var kayak_k1: RigidBody3D

const SKIP_INTRO = true

const UnhandledTriggers = preload("res://interactives/unhandled_triggers.gd")

func _ready() -> void:
	Global.main_scene = self
	Global.grab_joint = %GrabJoint3D
	Global.grab_joint.set_param_x(Generic6DOFJoint3D.PARAM_LINEAR_LIMIT_SOFTNESS, 0.01)
	Global.grab_joint.set_param_y(Generic6DOFJoint3D.PARAM_LINEAR_LIMIT_SOFTNESS, 0.01)
	Global.grab_joint.set_param_z(Generic6DOFJoint3D.PARAM_LINEAR_LIMIT_SOFTNESS, 0.01)
	Global.grab_joint.set_param_x(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, 0.01)
	Global.grab_joint.set_param_y(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, 0.01)
	Global.grab_joint.set_param_z(Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, 0.01)
	
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
	
	%ProportionalSlider.value = character.pid_proportional_par
	%IntegralSlider.value = character.pid_integral_par
	%DerivativeSlider.value = character.pid_derivative_par
	
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	for c in dk_world.get_children():
		if c.has_meta("is_pepa_kayak"):
			kayak_k1 = c
	
	%IntroChatLabel.visible = true
	intro_animation()

func intro_animation():
	if SKIP_INTRO:
		end_intro_animation()
	else:
		%IntroAnimationPlayer.play("intro_animation")

func end_intro_animation():
	dk_world.select_cameras = true
	%IntroChatLabel.visible = false
	say_dialogue("demo_start_point")

func _process(delta: float) -> void:
	handle_triggers(delta)
	handle_dialogue(delta)
	handle_stats(delta)
	handle_demo_puzzle()
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

func handle_demo_puzzle():
	var match_count := 0
	%VinoIndicador.visible = false
	%CarneIndicador.visible = false
	%TierraIndicador.visible = false
	for c in dk_world.get_children():
		if c.has_meta("puzzle_item"):
			#prints("Puzzle:", c.label_text)
			var pos_a := Vector3(c.position.x, 0, c.position.z)
			match c.label_text:
				"Sol":
					var pos_b := Vector3(%TierraLabel.position.x, 0, %TierraLabel.position.z)
					if pos_a.distance_to(pos_b) < 5:
						#print("Sol y Tierra")
						%TierraIndicador.visible = true
						match_count += 1
				"Cáliz":
					var pos_b := Vector3(%VinoLabel.position.x, 0, %VinoLabel.position.z)
					if pos_a.distance_to(pos_b) < 5:
						#print("Cáliz y Vino")
						%VinoIndicador.visible = true
						match_count += 1
				"Espada":
					var pos_b := Vector3(%CarneLabel.position.x, 0, %CarneLabel.position.z)
					if pos_a.distance_to(pos_b) < 5:
						#print("Espada y Carne")
						%CarneIndicador.visible = true
						match_count += 1
	if match_count == 3:
		%DemoExitDoor.position.y = -20
		#print("OpenDoor")
	else:
		%DemoExitDoor.position.y = 0
	if Global.character.position.distance_to(%FinishPositionDemo.global_position) < 6 \
	 and not %LabelThanks.visible:
		%LabelThanks.visible = true
		%LabelThanks.text += "\n\n%s" % %LabelTemporizador.text

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
	if dialogue_label.text == "":
		dialogue_control.visible = false
	else:
		dialogue_control.visible = true
	if dialogue_time > 0: return
	dialogue_label.text = ""
	if dialogue_queue.size() < 1: return
	var d: DialogueResource = dialogue_queue.pop_front() as DialogueResource
	var key: String = "%s_dialogue_text" % d.resource_scene_unique_id
	var character_string:String = d.Character.keys()[d.character]
	dialogue_label.text = "%s:\n\t%s" % [tr(character_string), tr(key)]
	dialogue_label.visible_ratio = 0
	if is_dialogue_animating():
		dialogue_tween.stop()
	dialogue_tween = create_tween()
	write_speed = dialogue_label.text.length() * 0.08
	dialogue_tween.tween_property(dialogue_label, "visible_ratio", 1., 1)
	dialogue_time = write_speed + (dialogue_label.text.length() * 0.08)
	# TODO
	# - Skip animation
	# - Skip text

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
		for id in in_trigger:
			execute_trigger("primary_action", id)
	elif event.is_action_pressed("secondary_action"):
		if is_saying_dialogue():
			skip_dialogue()
			return
		for id in in_trigger:
			execute_trigger("secondary_action", id)
	elif event.is_action_pressed("pepa"):
		say_dialogue("¡¡Pepa!!")
	elif event.is_action_pressed("compicactus"):
		on_compicactus()
	elif event.is_action_pressed("quit"):
		get_tree().quit()
	elif event.is_action_pressed("help"):
		%HelpLabel.visible = !%HelpLabel.visible

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

func execute_trigger(trigger_type:String, trigger_id:String):
	# var index := "%s:%s" % [type, trigger_id]
	if not is_closest_trigger(trigger_id): return
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
	if not handled and trigger_type == "primary_action":
		var unhandled_logic := UnhandledTriggers.new()
		unhandled_logic._on_unhandled_trigger(self, game_state, trigger_id)

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
	update_pid_values()

func _on_slider_drag_ended(value_changed: bool) -> void:
	update_pid_values()

func _on_grab_kayak_body_entered(body: Node3D) -> void:
	if body.name == "character":
		grab_kayak()

func grab_kayak():
	if grabbed: return
	if not is_grabbing_kayak(): return
	grabbed = true
	var connect_grab = func():
		Global.grab_kayak.global_position = Global.character.global_position
		%KayakGrabber.global_position = Global.character.global_position
		Global.grab_kayak.set_node_a(%KayakGrabber.get_path())
		Global.grab_kayak.set_node_b(Global.character.get_path())
		#
		Global.character.release_grab()
		Global.grab_kayak2.global_position = kayak_k1.global_position
		Global.grab_kayak2.set_node_a(%KayakGrabber.get_path())
		Global.grab_kayak2.set_node_b(kayak_k1.get_path())
	
	%BlockPathOtherSide.position.y = -20
	
	var tt := [
		Vector3(2, 0, 1),
		Vector3(1, 0, -1),
		Vector3(0.5, 0, 0),
		Vector3(-2, 0, -0.5),
	]
	Global.character.lock_grab()
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
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
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(%KayakGrabber, "global_position", Vector3(-16, 0, -139), 1.3)
	tween.parallel().tween_property(%KayakGrabber, "global_rotation:y", 0, 0.2)
	tween.tween_callback(say_dialogue.bind("demo_scream"))
	for t in tt:
		tween.tween_property(%KayakGrabber, "global_position", Vector3(-16, 0, -139)+t, 0.6)
		tween.parallel().tween_property(%KayakGrabber, "global_rotation:y", deg_to_rad(randi_range(-90, 90)), 0.8)
	tween.tween_property(%KayakGrabber, "global_position", Vector3(-38.872, 0, -146.022), 0.6)
	tween.parallel().tween_property(%KayakGrabber, "global_rotation:y", deg_to_rad(-90+45), 0.7)
	tween.tween_interval(1.0)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(set_datamosh.bind(true))
	tween.tween_property(%KayakGrabber, "global_position", Vector3(-196.017, 0, -147.396), 6.0)
	tween.parallel().tween_property(%KayakGrabber, "global_rotation:y", deg_to_rad(-90+60), 6.0)
	tween.tween_callback(ungrab_kayak)
	tween.tween_callback(kayak_k1.queue_free)
	tween.tween_interval(3.0)
	tween.tween_callback(say_dialogue.bind("demo_other_side"))
	tween.tween_callback(set_datamosh.bind(false))

func set_datamosh(value:bool):
	%WorldEnvironment.compositor.compositor_effects[0].enabled = value

func ungrab_kayak():
	Global.grab_kayak.set_node_a(NodePath(""))
	Global.grab_kayak.set_node_b(NodePath(""))
	#
	Global.grab_kayak2.set_node_a(NodePath(""))
	Global.grab_kayak2.set_node_b(NodePath(""))
	
	Global.character.lock_grab(false)


func _on_first_grab_kayak_body_entered(body: Node3D) -> void:
	if moved: return
	if not is_grabbing_kayak(): return
	moved = true
	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(0, 0, 1)*0.5))
	tween.tween_interval(1.0)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(-1, 0, 1)*1))
	tween.tween_interval(0.3)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(1, 0, 1)*2))
	tween.tween_interval(0.3)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(-1, 0, 1)))
	tween.tween_callback(say_dialogue.bind("demo2_kayak_movement"))
	tween.tween_interval(10)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(0, 0, 1)*0.5))
	tween.tween_interval(1.0)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(-1, 0, 1)*1))
	tween.tween_interval(0.3)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(1, 0, 1)*2))
	tween.tween_interval(1.0)
	tween.tween_callback(Global.character.apply_central_impulse.bind(Vector3(-1, 0, 1)))
	tween.tween_callback(say_dialogue.bind("demo2_kayak_movement_2"))
	tween.tween_callback(kayak_k1.set_camera)
	tween.tween_callback(dk_world.set_select_cameras.bind(false))
	tween.tween_callback(kayak_k1.pepa_visible.bind(true))
	tween.tween_interval(3.0)
	tween.tween_callback(dk_world.set_select_cameras.bind(true))
	tween.tween_interval(10.0)
	tween.tween_callback(say_dialogue.bind("demo2_kayak_movement_2b"))

func _on_foreshadowing_body_entered(body: Node3D) -> void:
	if foreshadowing: return
	if not is_grabbing_kayak(): return
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
