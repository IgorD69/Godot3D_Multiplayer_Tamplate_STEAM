extends Node

const SETTINGS_FILE = "user://settings.cfg"
var config = ConfigFile.new()

func _ready():
	load_settings()

func save_settings():
	# Audio
	config.set_value("Audio", "Master", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))))
	config.set_value("Audio", "Music", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))))
	config.set_value("Audio", "SFX", db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))))
	
	# Controls
	config.set_value("Controls", "MouseSens", Global.mouse_sensitivity)
	
	config.save(SETTINGS_FILE)

func load_settings():
	var err = config.load(SETTINGS_FILE)
	if err != OK:
		return # Dacă nu există fișierul, rămânem pe default
	
	# Încărcăm Audio
	var master_vol = config.get_value("Audio", "Master", 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_vol))
	
	# Încărcăm Controls
	Global.mouse_sensitivity = config.get_value("Controls", "MouseSens", 0.002)
