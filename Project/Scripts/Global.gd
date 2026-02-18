extends Node

var MAIN_SCREEN = load("uid://cubhhgqrk5x0v")
var SETTINGS_SCENE = load("uid://dsr4sx6v6qsiv")
var ESC_MENU = load("uid://b84p0jqodhcxg")
var FACTORY_SCENE_PATH = load("uid://beehu2dulgjte")


var LAN: bool = false
var is_focused: bool
var mouse_sensitivity: float = 0.002
var mic_player: AudioStreamPlayer = null
var recording_bus_index: int = -1


func _focus() -> void:
	is_focused = true
	print("FOCUSE")


func _unfocus() -> void:
	is_focused = false
	print("UNFOCUSE")
