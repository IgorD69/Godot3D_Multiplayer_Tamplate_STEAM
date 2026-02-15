extends CanvasLayer

# --- REFERINȚE UI ---
@onready var audioContainer: TabBar = $SettingsMenu/Audio
@onready var controlsContainer: TabBar = $SettingsMenu/Controls

@onready var mouse_sensitivity_slider: HSlider = $SettingsMenu/Controls/VBoxContainer2/MouseSensitivitySlider
@onready var fov_slider: HSlider = $SettingsMenu/Controls/VBoxContainer2/FOV_Slider

@onready var master: HSlider = $SettingsMenu/Audio/HBoxContainer/VBoxContainer2/Master
@onready var music: HSlider = $SettingsMenu/Audio/HBoxContainer/VBoxContainer2/Music
@onready var sound_effects: HSlider = $SettingsMenu/Audio/HBoxContainer/VBoxContainer2/SoundEffects

# --- CONFIGURARE AUDIO ---
@export var master_bus_name: String = "Master"
@export var music_bus_name: String = "Music"
@export var sfx_bus_name: String = "SFX"

func _ready() -> void:
	update_sliders_to_current_volumes()

# --- NAVIGARE ---
func _on_back_pressed() -> void:
	SettingsManager.save_settings()
	queue_free()

func _on_audio_settings_pressed() -> void:
	audioContainer.show()
	controlsContainer.hide()

func _on_controls_settings_pressed() -> void:
	controlsContainer.show()
	audioContainer.hide() 

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		_on_back_pressed()

# --- LOGICĂ AUDIO ---
func _on_master_value_changed(value: float) -> void:
	_set_bus_volume(master_bus_name, value)

func _on_music_value_changed(value: float) -> void:
	_set_bus_volume(music_bus_name, value)

func _on_sound_effects_value_changed(value: float) -> void:
	_set_bus_volume(sfx_bus_name, value)

func _set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		AudioServer.set_bus_mute(bus_index, value <= 0.001)

# --- LOGICĂ CONTROLS ---
func _on_mouse_sensitivity_slider_value_changed(value: float) -> void:
	Global.mouse_sensitivity = value * 0.002
	_apply_to_local_player()


func _apply_to_local_player() -> void:
	var players = get_tree().get_nodes_in_group("Players")
	for player in players:
		if player.is_multiplayer_authority():
			if "MOUSE_SENSITIVITY" in player:
				player.MOUSE_SENSITIVITY = Global.mouse_sensitivity
			
			#if camera:
				#camera.fov = Global.fov

# --- SINCRONIZARE VIZUALĂ SLIDERE ---
func update_sliders_to_current_volumes() -> void:
	var master_bus = AudioServer.get_bus_index(master_bus_name)
	if master_bus != -1:
		master.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus))
	
	var music_bus = AudioServer.get_bus_index(music_bus_name)
	if music_bus != -1:
		music.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
		
	var sfx_bus = AudioServer.get_bus_index(sfx_bus_name)
	if sfx_bus != -1:
		sound_effects.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))
	
	# Sensibilitatea
	if mouse_sensitivity_slider:
		mouse_sensitivity_slider.value = Global.mouse_sensitivity / 0.002
	
	
