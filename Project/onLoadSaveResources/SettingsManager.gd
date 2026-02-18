extends Node

const SETTINGS_FILE = "user://settings.cfg"
var config = ConfigFile.new()
var active_action = ""

func _ready():
	load_settings()

func _input(event):
	if active_action != "" and event is InputEventKey and event.is_pressed():
		# 1. Schimbăm tasta în InputMap imediat
		InputMap.action_erase_events(active_action)
		InputMap.action_add_event(active_action, event)
		
		# 2. Actualizăm butonul vizual
		# get_node("Btn_" + active_action).text = event.as_text()
		
		active_action = ""
		get_viewport().set_input_as_handled()

func _on_key_button_pressed(action_name: String):
	active_action = action_name
	
func save_settings():
	# --- AUDIO ---
	config.set_value("Audio", "Master", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))))
	config.set_value("Audio", "Music", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))))
	config.set_value("Audio", "SFX", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))))
	config.set_value("Audio", "Voices", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voices"))))
	
	# --- CONTROLS ---
	config.set_value("Controls", "MouseSens", Global.mouse_sensitivity)
	
	var err = config.save(SETTINGS_FILE)
	if err != OK:
		print("Eroare la salvarea setărilor!")

func load_settings():
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		print("Nu s-a găsit fișierul de setări, se folosesc valorile default.")
		return 
	
	# --- ÎNCĂRCARE AUDIO ---
	_apply_loaded_volume("Master", config.get_value("Audio", "Master", 1.0))
	_apply_loaded_volume("Music", config.get_value("Audio", "Music", 1.0))
	_apply_loaded_volume("SFX", config.get_value("Audio", "SFX", 1.0))
	_apply_loaded_volume("Voices", config.get_value("Audio", "Voices", 1.0))
	
	# --- ÎNCĂRCARE CONTROLS ---
	Global.mouse_sensitivity = config.get_value("Controls", "MouseSens", 0.002)

# Funcție helper pentru a aplica volumul și a gestiona Mute-ul automat
func _apply_loaded_volume(bus_name: String, value: float):
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		AudioServer.set_bus_mute(bus_index, value <= 0.001)
