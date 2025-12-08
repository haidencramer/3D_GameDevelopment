extends Button

@export var action_name: String

func _ready() -> void:
	pressed.connect(on_button_clicked)
	ButtonMappingMenu.update_button.connect(receive_new_text_data)
	
	# Display current key binding
	update_button_text()
	
func update_button_text() -> void:
	"""Updates the button text to show the current key binding"""
	var get_events = InputMap.action_get_events(action_name)
	if get_events == null or get_events.size() == 0:
		text = "Not Set"
		return
	
	# Get the first event (keyboard key)
	var event = get_events[0]
	if event is InputEventKey:
		text = OS.get_keycode_string(event.physical_keycode)
	elif event is InputEventMouseButton:
		text = "Mouse " + str(event.button_index)
	else:
		text = event.as_text()
	
func on_button_clicked() -> void:
	text = "Press any key..."
	ButtonMappingMenu.update_control(action_name)

func receive_new_text_data(act_name: String, new_button_name: String) -> void:
	if act_name != action_name:
		return
	text = new_button_name
