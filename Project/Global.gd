extends Node
#class_name GlobalScript

var debug
var LAN: bool = false
var is_focused: bool
var mouse_sensitivity: float = 0.002
#var fov: float = 75.0
var mic_player: AudioStreamPlayer = null
var recording_bus_index: int = -1


		
		
func _focus() -> void:
	is_focused = true
	print("FOCUSE")


func _unfocus() -> void:
	is_focused = false
	print("UNFOCUSE")
