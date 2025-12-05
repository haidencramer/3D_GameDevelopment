extends Control

@onready var options_button = $OptionsButton
@export var input_mapping_scene: PackedScene

func _ready():
	options_button.pressed.connect(_on_options_button_pressed)
	
func _process(delta):
	pass
	



func on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MultiplayerConnect.tscn")


func _on_options_button_pressed() -> void:
	var input_mapping = input_mapping_scene.instantiate()
	add_child(input_mapping)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
