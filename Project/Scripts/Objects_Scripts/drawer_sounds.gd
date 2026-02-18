extends AudioStreamPlayer3D

@export var audio_list: Array[AudioStream]

var current_index : int = 0
var current_audio : AudioStream

# handle play music
func _play_music(index: int = 0) -> void:
	# prevents any errors
	if !audio_list.has(index): return
	if current_audio: current_audio.stop()

	audio_list[index].play()
	current_index = index
	current_audio = audio_list[index]

# handle skipping songs
func _nav_musiclist(direction: int = 0) -> void:
	# prevents any errors
	var new_index = current_index + direction
	if !audio_list.has(new_index): return

	_play_music(new_index)
