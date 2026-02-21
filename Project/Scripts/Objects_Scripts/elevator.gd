extends AnimatableBody3D

@onready var elevator_anim: AnimationPlayer = $"../Elevator_Anim"
@onready var click_sound: AudioStreamPlayer3D = $Button/ClickSound

var is_player_inside: bool = false
var is_moving: bool = false
var is_up: bool = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	# Verificăm dacă cel care a intrat este jucătorul local
	if body.is_in_group("Player") and body.is_multiplayer_authority():
		is_player_inside = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player") and body.is_multiplayer_authority():
		is_player_inside = false

func _process(_delta: float) -> void:
	if is_player_inside and Input.is_action_just_pressed("interact") and not is_moving:
		sync_elevator_trigger.rpc()

@rpc("any_peer", "call_local", "reliable")
func sync_elevator_trigger() -> void:
	if is_moving: return
	
	is_moving = true
	click_sound.play()
	
	if not is_up:
		elevator_anim.play("doorClose")
		await elevator_anim.animation_finished
		elevator_anim.play("UP")
		await elevator_anim.animation_finished
		elevator_anim.play_backwards("doorClose")
		
		is_up = true
	else:
		elevator_anim.play("doorClose")
		await elevator_anim.animation_finished
		elevator_anim.play_backwards("UP")
		await elevator_anim.animation_finished
		elevator_anim.play_backwards("doorClose")
		await elevator_anim.animation_finished
		is_up = false
	
	is_moving = false
