extends Control

@onready var label: Label = $Label

func _process(_delta: float) -> void:
	label.text = str(Engine.get_frames_per_second())
