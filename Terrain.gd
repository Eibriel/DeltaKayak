extends Node3D

var img := Image.new()
var blue_noise_img := Image.new()
var shape := HeightMapShape3D.new()

var prev_pos: Vector3

@onready var MULTIMESH:MultiMesh = $Trees.multimesh
@onready var MULTIMESH_JUNCOS:MultiMesh = $Juncos.multimesh

func _ready() -> void:
	$StaticBody3D/CollisionShape3D.shape = shape
	img.load("res://images/heightmap.png")
	img.convert(Image.FORMAT_RF)
	#
	blue_noise_img.load("res://images/tiled_L_64.png")

func _process(delta: float) -> void:
	if prev_pos != position:
		update_terrain()
		distribute_trees()

func update_terrain() -> void:
	prev_pos = position
	var rect := pos2pixel(position, Vector2i(50, 50))
	var img2: Image = img.get_region(rect)
	var data := img2.get_data().to_float32_array()
	for i in data.size():
		data[i] *= 2.0
		data[i] -= 0.8
	shape.map_width = img2.get_width()
	shape.map_depth = img2.get_height()
	shape.map_data = data

func pos2pixel(pos: Vector3, size: Vector2i) -> Rect2i:
	return Rect2i((img.get_width()/2)+pos.x-(size.x/2), (img.get_height()/2)+pos.z-(size.x/2), size.x, size.y)

func pixel2pos(pixel: Vector2i) -> Vector3:
	return Vector3(pixel.x-(img.get_width()/2), 0.0, pixel.y-(img.get_height()/2))

# Source:
# https://github.com/ensanmartin/godot-2d-dithering/blob/main/test_project/materials/blue_noise/simplified_blue_noise.tres
var trees = []
var juncos = []
func distribute_trees() -> void:
	var rec := pos2pixel(position, Vector2i(200, 200))
	var INSTANCE_COUNT = 0
	var INSTANCE_COUNT_JUNCOS = 0
	trees.resize(0)
	juncos.resize(0)
	for x in rec.size.x:
		for y in rec.size.y:
			place_tree(Vector2i(x + rec.get_center().x - (float(rec.size.x)/2), y + rec.get_center().y - (float(rec.size.y)/2)))
	INSTANCE_COUNT = trees.size()
	MULTIMESH.visible_instance_count = INSTANCE_COUNT
	for id in INSTANCE_COUNT:
		var v: Vector3 = trees[id][0]
		var t := Transform3D(Basis(), v)
		t = t.rotated_local(Vector3.UP, trees[id][1])
		t = t.scaled_local(trees[id][2])
		MULTIMESH.set_instance_transform(id, t)

	INSTANCE_COUNT_JUNCOS = juncos.size()
	MULTIMESH_JUNCOS.visible_instance_count = INSTANCE_COUNT_JUNCOS
	for id in INSTANCE_COUNT_JUNCOS:
		var v: Vector3 = juncos[id][0]
		var t := Transform3D(Basis(), v)
		t = t.rotated_local(Vector3.UP, juncos[id][1])
		t = t.scaled_local(juncos[id][2])
		MULTIMESH_JUNCOS.set_instance_transform(id, t)

func place_tree(COORD: Vector2i) -> void:
	#var COORD: Vector2i = pos2pixel(position).get_center()
	var UV: Vector2 = Vector2(COORD) / Vector2(img.get_size())
	var pixel:Color = img.get_pixelv(COORD)
	if pixel.r < 0.05:
		return
	#pixel *= 0.1
	pixel *= 0.8
	#pixel = pixel.clamp()
	var vector_pixel: Vector3 = Vector3(pixel.r, pixel.r, pixel.r)
	# LUMA coefficients
	var gray:float = vector_pixel.dot(Vector3(0.299, 0.587, 0.114))
	# tiles the noise texture
	var tex_size: Vector2i = img.get_size()
	#vec2 tex_uv = mod(UV * tex_size, vec2(64.0)) / vec2(64.0);
	var tex_uv: Vector2 = vector_modulo(COORD, Vector2i(64, 64)) / Vector2(64.0, 64.0)
	#float layer = floor(rand(UV)) * 64.0;
	# TODO var layer:float = floor(rand(UV)) * 64.0
	#vec4 blue_noise = texture(blue_noise_textures, vec3(tex_uv, layer));
	var blue_noise: Color = blue_noise_img.get_pixelv(tex_uv * Vector2(blue_noise_img.get_size())) # TODO missing layer
	#vec3 new_color = step(0.5, gray + (blue_noise - 0.5)).rgb
	var new_color: Color = step(0.5, Color(gray, gray, gray) + (blue_noise - Color(.5, .5, .5)))
	
	
	if new_color == Color(1,1,1):
		var seed_str:String = "%s-%s" % [COORD.x, COORD.y]
		seed(seed_str.hash())
		#print(COORD.x + COORD.y)
		var pos := pixel2pos(COORD)
		pos.y = (img.get_pixelv(COORD).r * 2.0) - 0.8
		if pixel.r > 0.7:
			trees.append(
				[
					pos,
					randf_range(0, PI*2),
					Vector3.ONE * randf_range(0.2, 1.0)
				])
		else:
			pos.y -= 0.5
			juncos.append(
				[
					pos,
					randf_range(0, PI*2),
					Vector3.ONE * randf_range(0.7, 1.0)
				])

func rand(uv: Vector2) -> float:
	return fract(sin(uv.dot(Vector2(12.9898,78.233))) * 43758.5453123)

func fract(x: float) -> float:
	return x - floor(x)

func step(a:float, b:Color) -> Color:
	var r: Color
	r.r = 0.0 if b.r < a else 1.0
	r.g = 0.0 if b.g < a else 1.0
	r.b = 0.0 if b.b < a else 1.0
	return r

func vector_modulo(v1:Vector2i, v2:Vector2i) -> Vector2:
	return Vector2(v1.x % v2.x, v1.y % v2.y)
