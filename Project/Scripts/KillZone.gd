extends Area3D
@export var main_menu_path: String = "res://Scene/MainScreen.tscn"

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		handle_player_death()
	else:
		body.queue_free()

func handle_player_death() -> void:
	Net.cleanup_network()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	get_tree().change_scene_to_file(main_menu_path)
