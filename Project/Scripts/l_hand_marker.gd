extends Marker3D

@export var sway_amount : float = 0.05
@export var lerp_speed : float = 10.0

@onready var l_hand_marker: Marker3D = $"."

var mouse_input : Vector2

func _input(event):
	if event is InputEventMouseMotion:
		mouse_input = event.relative
	
	self.position = lerp(self.position, self.position.x * mouse_input, lerp_speed)
		

#func _process(delta):
	## Calculăm poziția dorită bazată pe mouse
	#var target_pos = Vector3(
		#-mouse_input.x * sway_amount, 
		#mouse_input.y * sway_amount, 
		#0
	#)
	#
	## Aplicăm un lerp pentru o mișcare fluidă (smoothening)
	#l_hand_marker.position = l_hand_marker.position.lerp(target_pos, delta * lerp_speed)
	#
	## Resetăm inputul pentru a preveni driftul infinit
	#mouse_input = Vector2.ZERO
