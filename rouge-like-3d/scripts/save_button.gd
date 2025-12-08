extends Button

func _ready() -> void:
	pressed.connect(on_button_pressed)
	
func on_button_pressed() -> void:
	print("Save button pressed")
	
	# Save the control data
	ButtonMappingMenu.save_data()
	
	# Close the menu
	var input_mapping_panel = get_parent().get_parent().get_parent().get_parent()
	if input_mapping_panel:
		print("Closing input mapping menu")
		input_mapping_panel.queue_free()
	else:
		print("ERROR: Could not find input mapping panel to close")
