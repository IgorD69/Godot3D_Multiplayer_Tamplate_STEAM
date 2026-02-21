extends Node3D

@onready var base_anim: AnimationPlayer = $Rotatte/BaseAnim
@onready var gear_anim: AnimationPlayer = $Rotatte/SpinGear/GearAnim

var forward_Moving: bool = true

func _ready() -> void:
	base_anim.animation_finished.connect(_on_animation_finished)
	base_anim.play("Rotate")
	gear_anim.play("Spin")

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "Rotate":
		forward_Moving = true 
		base_anim.play("DeLoad")
		
	elif anim_name == "Rotate_Backwards":
		forward_Moving = false
		base_anim.play("DeLoad")
		
	elif anim_name == "DeLoad":
		if forward_Moving == true:
			base_anim.play("Rotate_Backwards")
		else:
			base_anim.play("Rotate")
