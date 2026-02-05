extends Node
@export var interaction_controller: Node
@export var player_character: CharacterBody3D
@export var interaction_raycast: RayCast3D
@export var player_camera: Camera3D

var current_object: Object
var interaction_component: Node
var potential_object: Object

func _process(_delta: float) -> void:
	if player_character.velocity.length() > 100:
		get_tree().reload_current_scene()
	
	# Dacă avem un obiect curent cu care interacționăm
	if current_object and interaction_component:
		# RIGHT CLICK → aruncă obiectul
		if Input.is_action_just_pressed("R_Click"):
			interaction_component.auxInteract()
			current_object = null
			interaction_component._unfocus()
			interaction_component = null
		# LEFT CLICK ținut → trage obiectul
		elif Input.is_action_pressed("L_Click"):
			interaction_component.Interact()
		# LEFT CLICK eliberat → oprește interacțiunea
		elif Input.is_action_just_released("L_Click"):
			interaction_component.postInteract()
			current_object = null
			interaction_component._unfocus()
			interaction_component = null
	
	# Căutăm obiecte noi cu care să interacționăm
	else:
		potential_object = interaction_raycast.get_collider()
		
		if potential_object and potential_object is Node:
			var component = potential_object.get_node_or_null("InteractionComponent")
			
			if component and component.can_interact:
				# unfocus la componenta precedentă
				if interaction_component and interaction_component != component:
					interaction_component._unfocus()
				
				# focus pe componenta vizată
				component._focus()
				interaction_component = component
				
				#Pentru DEFAULT (obiecte) - LEFT CLICK începe interacțiunea
				if component.interaction_type == component.InteractionType.DEFAULT:
					if Input.is_action_just_pressed("L_Click"):
						current_object = potential_object
						
						# Folosim has_method pentru a fi siguri că nu crapă jocul
						if component.has_method("request_authority"):
							component.request_authority.rpc()
						else:
							print("Eroare: Componenta nu are functia request_authority!")

						component.set_direction(interaction_raycast.get_collision_normal())
						component.preInteract()
							
				# Pentru alte tipuri (DOOR, SWITCH, LAPTOP) - interact key
				elif Input.is_action_just_pressed("interact"):
					component.preInteract()
					if component.interaction_type == component.InteractionType.DOOR:
						component.open_or_close()
					component.postInteract()
		else:
			# Nu mai vizăm nimic
			if interaction_component:
				interaction_component._unfocus()
				interaction_component = null

func isCameraLocked() -> bool:
	return interaction_component and interaction_component.lock_camera and interaction_component.is_interactingw

func Interact() -> void:
	# Această funcție poate rămâne goală sau o poți folosi pentru logica de tip SWITCH/DOOR
	pass
