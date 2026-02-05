extends StaticBody3D

var can_interact: bool = true
var cooldown_time: float = 0.5
var is_open: bool = false 

@onready var button_anim: AnimationPlayer = $TrayButtonMesh/AnimationPlayer
@onready var tray_anim: AnimationPlayer = $"../../sertart/AnimationPlayer"

func interact():
	if can_interact:
		can_interact = false
		
		button_anim.play("press")
		
		if is_open:
			tray_anim.play("close")
			is_open = false
			print("Sertar închis")
		else:
			tray_anim.play("open")
			is_open = true
			print("Sertar deschis")
		
		await get_tree().create_timer(cooldown_time).timeout
		can_interact = true
