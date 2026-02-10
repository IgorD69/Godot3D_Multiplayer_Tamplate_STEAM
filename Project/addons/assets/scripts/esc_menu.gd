extends CanvasLayer

@export var SETTINGS_SCENE: PackedScene = preload("uid://dsr4sx6v6qsiv")

var settings_instance = null

func _on_settings_pressed() -> void:
	if not is_instance_valid(settings_instance):
		hide()
		settings_instance = SETTINGS_SCENE.instantiate()
		add_child(settings_instance)
		
		settings_instance.tree_exited.connect(func(): 
			settings_instance = null
			show())

	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()
		
func _on_main_menu_pressed() -> void:
	# 1. Curățăm rețeaua
	Net.cleanup_network()
	
	# 2. Ne asigurăm că mouse-ul este vizibil ÎNAINTE de a schimba scena
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# 3. Ștergem meniul de ESC imediat (pentru a nu rămâne suprapus)
	queue_free() 
	
	# 4. Schimbăm scena
	get_tree().change_scene_to_file("res://Scene/MainScreen.tscn")

func _on_resume_pressed() -> void:
	if get_tree().current_scene.name != "MainScreen":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false 
	
	queue_free()
