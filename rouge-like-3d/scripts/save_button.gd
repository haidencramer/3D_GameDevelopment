extends Button

func _ready() -> void:
	pressed.connect(on_button_pressed)
	
func on_button_pressed():
	ButtonMappingMenu.save_data()
	
	var input_mapping_panel = get_parent().get_parent().get_parent().get_parent()
	input_mapping_panel.queue_free()
