extends StaticBody3D

@onready var pc_camera: Camera3D = $PC_Camera

var player: Player = null # Use the class_name you defined
var is_near_pc: bool = false
var is_using_pc: bool = false


func _ready():
	pc_camera.current = false
	#pc_camera.enabled = false # Dacă ai opțiunea asta
	
func _on_pc_area_body_entered(body: Node3D) -> void:
	if body is Player: # More reliable than groups
		#print("IN ZONE")
		is_near_pc = true
		player = body

func _on_pc_area_body_exited(body: Node3D) -> void:
	if body is Player:
		#print("EXITED ZONE")
		is_near_pc = false
		# Safety: if player leaves area while using (teleport etc), reset
		if is_using_pc:
			exit_pc()

func _input(event: InputEvent) -> void:
	# Use "interact" to enter OR exit
	if is_near_pc and event.is_action_pressed("interact"):
		if not is_using_pc:
			enter_pc()
		else:
			exit_pc()
		get_viewport().set_input_as_handled()
	
	# Use ESC to exit only if using the PC
	if is_using_pc and event.is_action_pressed("esc"):
		exit_pc()
		get_viewport().set_input_as_handled()

func enter_pc() -> void:
	if not player: return
	
	print("Entering PC mode")
	is_using_pc = true
	pc_camera.make_current() # Use make_current() for reliability
	
	player.is_frozen = true
	if "crosshair" in player and player.crosshair:
		player.crosshair.visible = false
	
	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func exit_pc() -> void:
	if not is_using_pc: return
	
	is_using_pc = false
	
	if player and is_instance_valid(player):
		player.camera.make_current() # Re-activăm camera playerului
		player.is_frozen = false
		if player.crosshair:
			player.crosshair.visible = true
	
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
