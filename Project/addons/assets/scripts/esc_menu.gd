extends CanvasLayer

@export var SETTINGS_SCENE: PackedScene = preload("uid://dsr4sx6v6qsiv")

var settings_instance = null

func _on_settings_pressed() -> void:
	hide()
	if settings_instance == null:
		settings_instance = SETTINGS_SCENE.instantiate()
		add_child(settings_instance)
		
		settings_instance.tree_exited.connect(func(): settings_instance = null)
	else:
		settings_instance.queue_free()
		settings_instance = null

func _on_resume_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free() 

func _on_main_menu_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://Scene/World.tscn")
