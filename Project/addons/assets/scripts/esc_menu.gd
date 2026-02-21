extends CanvasLayer

@onready var player_list_container = $PlayerList/HBoxContainer/VBoxContainer2
var settings_instance = null

func _ready() -> void:
	refresh_player_volumes()

func refresh_player_volumes() -> void:
	for child in player_list_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	var all_players = get_tree().get_nodes_in_group("Players")
	
	for p in all_players:
		if p.is_multiplayer_authority():
			continue
		
		if "player_name" in p and "voice_player" in p:
			create_voice_control(p)

func create_voice_control(player_node) -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	
	var label = Label.new()
	label.text = player_node.player_name
	label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(label)
	
	# Slider-ul de Volum
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 2.0 
	slider.step = 0.05
	slider.custom_minimum_size.x = 150
	
	if player_node.voice_player:
		slider.value = db_to_linear(player_node.voice_player.volume_db)
	
	slider.value_changed.connect(func(value):
		if is_instance_valid(player_node) and player_node.voice_player:
			player_node.voice_player.volume_db = linear_to_db(value)
	)
	
	vbox.add_child(slider)
	player_list_container.add_child(vbox)


func _on_settings_pressed() -> void:
	if not is_instance_valid(settings_instance):
		hide()
		settings_instance = Global.SETTINGS_SCENE.instantiate()
		add_child(settings_instance)
		
		settings_instance.tree_exited.connect(func(): 
			settings_instance = null
			show())
			
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()


		
func _on_main_menu_pressed() -> void:
	Net.cleanup_network()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_free() 
	get_tree().change_scene_to_packed(Global.MAIN_SCREEN)

func _on_resume_pressed() -> void:
	if get_tree().current_scene.name != "MainScreen":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false 
	
	queue_free()
