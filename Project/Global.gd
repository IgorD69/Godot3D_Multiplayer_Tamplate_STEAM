extends Node
#class_name GlobalScript

var debug
#var player : Player
var LAN: bool = false

var is_focused: bool

var mic_player: AudioStreamPlayer = null
var recording_bus_index: int = -1

func _focus() -> void:
	is_focused = true
	print("FOCUSE")
	#interaction_component.is_focused = true


func _unfocus() -> void:
	is_focused = false
	print("UNFOCUSE")
	#interaction_component.is_focused = false
