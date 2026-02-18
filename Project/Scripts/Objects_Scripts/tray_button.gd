extends StaticBody3D

var can_interact: bool = true
var cooldown_time: float = 0.5
var is_open: bool = false 

@onready var button_anim: AnimationPlayer = $TrayButtonMesh/AnimationPlayer
@onready var button_sfx: AudioStreamPlayer3D = $Button
@onready var tray_anim: AnimationPlayer = $"../../Propps/Sertar/StaticBody/AnimationPlayer"

@onready var sfx_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
 
@export var sfx_playlist: Array[AudioStream]

func interact():
	if can_interact:
		button_anim.play("press")
		can_interact = false
		
		if is_open:
			tray_anim.play("close")
			button_sfx.play()
			is_open = false
			play_sfx(1)
		else:
			tray_anim.play("open")
			button_sfx.play()
			is_open = true
			play_sfx(0)
		
		await get_tree().create_timer(cooldown_time).timeout
		can_interact = true

func play_sfx(index: int):
	if index < sfx_playlist.size() and sfx_playlist[index] != null:
		sfx_player.stream = sfx_playlist[index]
		sfx_player.play()
