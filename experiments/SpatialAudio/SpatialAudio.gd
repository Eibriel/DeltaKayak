extends Node3D

@onready var csg_sphere_3d_2: CSGSphere3D = $CSGSphere3D2
@onready var audio_stream_player_3d_2: AudioStreamPlayer3D = $AudioStreamPlayer3D2
@onready var audio_stream_player_3d_4: AudioStreamPlayer3D = $Radio/AudioStreamPlayer3D4

var deltay := 0.0
func _process(delta: float) -> void:
	deltay += delta
	csg_sphere_3d_2.rotate_y(0.2*delta)
	if deltay > 0.1 and not audio_stream_player_3d_2.playing:
		print("Play1")
		audio_stream_player_3d_2.play()
	if deltay > 0.3 and not audio_stream_player_3d_4.playing:
		print("Play2")
		audio_stream_player_3d_4.play()
