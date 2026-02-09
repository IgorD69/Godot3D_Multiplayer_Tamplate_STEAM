extends CanvasLayer

@onready var audioContainer: TabBar = $SettingsMenu/Audio
@onready var controlsContainer: TabBar = $SettingsMenu/Controls


func _on_back_pressed() -> void:
	queue_free()

func _on_audio_settings_pressed() -> void:
	audioContainer.show()
	controlsContainer.hide()

func _on_controls_settings_pressed() -> void:
	controlsContainer.show()
	audioContainer.hide() 
