extends Node3D

@onready var enevator_anim: AnimationPlayer = $Enevator_Anim
var is_player_inside: bool = false
var pressed: bool = false

@onready var click_sound: AudioStreamPlayer3D = $Button/ClickSound

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		is_player_inside = true


func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		is_player_inside = false
		

func _process(_delta: float) -> void:
	if is_player_inside and Input.is_action_just_pressed("interact"):
		pressed = !pressed
		click_sound.play()
		if pressed:
			enevator_anim.play("doorClose")
		else:
			enevator_anim.play_backwards("doorClose")
			
		
