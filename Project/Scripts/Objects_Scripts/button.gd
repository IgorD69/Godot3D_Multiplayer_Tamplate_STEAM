extends Node3D

@onready var button_area: Area3D = $buttonArea
const CUBE = preload("uid://cuixqud3u4ur4")
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var can_interact: bool = false
var button_pressed: bool = false
@export var cooldown_time: float = 0.5 # Mărit puțin pentru siguranță în rețea

func _on_button_area_body_entered(body: Node3D) -> void:
	# Verifică grupul "Players" (cum am stabilit anterior)
	if body.is_in_group("Players") and body.is_multiplayer_authority():
		can_interact = true

func _on_button_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("Players") and body.is_multiplayer_authority():
		can_interact = false

func _process(_delta):
	if can_interact and Input.is_action_just_pressed("interact") and not button_pressed:
		# Trimitem cererea la server să activeze butonul
		request_button_activation.rpc()

# Clientul cere, Serverul verifică și execută
@rpc("any_peer", "call_local", "reliable")
func request_button_activation():
	if not multiplayer.is_server() or button_pressed:
		return
		
	_activate_button_logic()

# Această funcție rulează DOAR pe server (Host)
func _activate_button_logic():
	button_pressed = true
	
	# Sincronizăm animația pe toate ecranele
	play_button_anim.rpc("pressed")
	
	# Spawning-ul se face DOAR pe server
	var cube_instance = CUBE.instantiate()
	# IMPORTANT: Cubul trebuie adăugat într-un nod monitorizat de MultiplayerSpawner
	# De obicei, scena principală sau un nod dedicat "SpawnedObjects"
	get_tree().current_scene.add_child(cube_instance, true) 
	cube_instance.global_position = global_position + Vector3(0, 2, 2)
	
	await get_tree().create_timer(cooldown_time).timeout
	
	button_pressed = false
	play_button_anim.rpc("RESET")

@rpc("any_peer", "call_local", "reliable")
func play_button_anim(anim_name: String):
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)  
