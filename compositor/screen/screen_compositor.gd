@tool
#extends CompositorEffect
extends CompositorEffect
class_name CompositorEffectScreen

var context : StringName = "PreviousFrame"
var texture : StringName = "texture"

# This is a very simple effects demo that takes our color values and writes
# back gray scale values. 

func _init():
	needs_motion_vectors = true
	effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	RenderingServer.call_on_render_thread(_initialize_compute)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# When this is called it should be safe to clean up our shader.
		# If not we'll crash anyway because we can no longer call our _render_callback.
		if datamosh_shader.is_valid():
			rd.free_rid(datamosh_shader)
		if loop_frame_shader.is_valid():
			rd.free_rid(loop_frame_shader)

###############################################################################
# Everything after this point is designed to run on our rendering thread

var rd : RenderingDevice

var datamosh_shader : RID
var datamosh_pipeline : RID

var loop_frame_shader : RID
var loop_frame_pipeline : RID

func _initialize_compute():
	rd = RenderingServer.get_rendering_device()
	if !rd:
		return

	# Create our shader
	var shader_file = load("res://compositor/screen.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	datamosh_shader = rd.shader_create_from_spirv(shader_spirv)
	datamosh_pipeline = rd.compute_pipeline_create(datamosh_shader)
	
	#shader_file = load("res://compositor/loop_frame.glsl")
	#shader_spirv = shader_file.get_spirv()
	#loop_frame_shader = rd.shader_create_from_spirv(shader_spirv)
	#loop_frame_pipeline = rd.compute_pipeline_create(loop_frame_shader)


func get_image_uniform(image : RID, binding : int = 0) -> RDUniform:
	var uniform : RDUniform = RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(image)

	return uniform


func _render_callback(p_effect_callback_type, p_render_data):
	if Engine.is_editor_hint():
		return
	
	if rd and p_effect_callback_type == CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		# Get our render scene buffers object, this gives us access to our render buffers. 
		# Note that implementation differs per renderer hence the need for the cast.
		var render_scene_buffers : RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
		
		if render_scene_buffers:
			# Get our render size, this is the 3D render resolution!
			var size = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return

			# We can use a compute shader here 
			var x_groups = (size.x - 1) / 8 + 1
			var y_groups = (size.y - 1) / 8 + 1

			if render_scene_buffers.has_texture(context, texture):
				var tf : RDTextureFormat = render_scene_buffers.get_texture_format(context, texture)
				if tf.width != size.x or tf.height != size.y:
					# This will clear all textures for this viewport under this context
					render_scene_buffers.clear_context(context)
			else:
				var usage_bits : int = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
				#render_scene_buffers.create_texture(context, texture, RenderingDevice.DATA_FORMAT_R16_UNORM, usage_bits, RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, true)
				render_scene_buffers.create_texture(context, texture, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage_bits, RenderingDevice.TEXTURE_SAMPLES_1, size, 1, 1, true)
				Global.refresh_frame = true
				print("recreate")

			# Barrier
			# Deprecated. Barriers are automatically inserted by RenderingDevice.
			# rd.barrier(RenderingDevice.BARRIER_MASK_ALL_BARRIERS, RenderingDevice.BARRIER_MASK_COMPUTE)

			# Loop through views just in case we're doing stereo rendering. No extra cost if this is mono.
			var view_count = render_scene_buffers.get_view_count()
			for view in range(view_count):
				# Get the RID for our color image, we will be reading from and writing to it.
				var input_image = render_scene_buffers.get_color_layer(view)
				#var velocity_buffer = render_scene_buffers.get_velocity_layer(view)
				var velocity_buffer = render_scene_buffers.get_velocity_texture()
				var previous_texture_image = render_scene_buffers.get_texture(context, texture)
				
				var push_constant : PackedInt32Array = PackedInt32Array()
				push_constant.push_back(size.x)
				push_constant.push_back(size.y)
				push_constant.push_back(Time.get_ticks_msec())
				
				if not Global.refresh_frame:
					# Create a uniform set, this will be cached, the cache will be cleared if our viewports configuration is changed
					var uniform : RDUniform = get_image_uniform(input_image)
					var input_set = UniformSetCacheRD.get_cache(datamosh_shader, 0, [ uniform ])
					
					uniform = get_image_uniform(velocity_buffer)
					var velocity_set = UniformSetCacheRD.get_cache(datamosh_shader, 1, [ uniform ])
					
					uniform = get_image_uniform(previous_texture_image)
					var previous_set = UniformSetCacheRD.get_cache(datamosh_shader, 2, [ uniform ])

					# Run Datamosh compute shader
					var compute_list := rd.compute_list_begin()
					rd.compute_list_bind_compute_pipeline(compute_list, datamosh_pipeline)
					rd.compute_list_bind_uniform_set(compute_list, input_set, 0)
					rd.compute_list_bind_uniform_set(compute_list, velocity_set, 1)
					rd.compute_list_bind_uniform_set(compute_list, previous_set, 2)
					rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), 16)
					rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
					rd.compute_list_end()
				
				var uniform := get_image_uniform(input_image)
				var input_set := UniformSetCacheRD.get_cache(datamosh_shader, 0, [ uniform ])
				
				uniform = get_image_uniform(previous_texture_image)
				var previous_set := UniformSetCacheRD.get_cache(datamosh_shader, 1, [ uniform ])
				
				# Run Loop Frame compute shader
				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, loop_frame_pipeline)
				rd.compute_list_bind_uniform_set(compute_list, input_set, 0)
				rd.compute_list_bind_uniform_set(compute_list, previous_set, 1)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
				rd.compute_list_end()
				
				#
				#var cfrom := Vector3.ZERO
				#var cto := Vector3(1, 1, 0)
				#var csize := Vector3(size.x, size.y, 0)
				#rd.texture_copy(input_image, previous_texture_image, cfrom, cto, csize, 0, 0, 0, 0)
				
				Global.refresh_frame = false
