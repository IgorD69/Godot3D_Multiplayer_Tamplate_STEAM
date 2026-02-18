extends RayCast3D

var can_detect = true 

func _process(_delta):
	if is_colliding():
		var collider = get_collider()
		
		if collider.has_method("interact"):
			if Input.is_action_just_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				collider.interact()
	
		#detect_coal(collider)

func detect_coal(collider):
	if not can_detect:
		return
		
	print(collider.name)
	
	can_detect = false
	
	await get_tree().create_timer(1.0).timeout 
	
	can_detect = true
