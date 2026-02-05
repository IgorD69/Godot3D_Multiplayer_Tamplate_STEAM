extends RayCast3D

func _process(_delta):
	if is_colliding():
		var collider = get_collider()
		
		if collider.has_method("interact"):
			if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				collider.interact()
