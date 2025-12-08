extends Control

signal update_button(actionName: String, newText: String)

var modify_control: bool = false
var modify_action: String
var control_data = {}

func _ready() -> void:
	print("ButtonMappingMenu ready")
	load_saved_controls()

func _input(event: InputEvent) -> void:
	# Ignore if not waiting for input
	if not modify_control:
		return
	
	# Ignore mouse motion
	if event is InputEventMouseMotion:
		return
	
	# Ignore if action doesn't exist
	if not InputMap.has_action(modify_action):
		print("ERROR: Action '", modify_action, "' does not exist!")
		modify_control = false
		return
	
	# Only accept key presses and mouse buttons
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	
	# Don't accept key releases, only presses
	if event is InputEventKey and not event.pressed:
		return
	
	if event is InputEventMouseButton and not event.pressed:
		return
	
	print("New input for '", modify_action, "': ", event.as_text())
	
	# IMPORTANT: Consume the input event to prevent it from triggering UI buttons
	get_viewport().set_input_as_handled()
	
	# Clear all existing events for this action
	InputMap.action_erase_events(modify_action)
	
	# Add the new event
	InputMap.action_add_event(modify_action, event)
	
	# Save to control data
	control_data[modify_action] = var_to_str(event)
	
	# Stop waiting for input
	modify_control = false
	
	# Get display text
	var display_text = ""
	if event is InputEventKey:
		display_text = OS.get_keycode_string(event.physical_keycode)
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				display_text = "Left Mouse"
			MOUSE_BUTTON_RIGHT:
				display_text = "Right Mouse"
			MOUSE_BUTTON_MIDDLE:
				display_text = "Middle Mouse"
			MOUSE_BUTTON_WHEEL_UP:
				display_text = "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN:
				display_text = "Wheel Down"
			_:
				display_text = "Mouse " + str(event.button_index)
	else:
		display_text = event.as_text()
	
	# Notify buttons to update
	update_button.emit(modify_action, display_text)
	
	print("Input mapped successfully: ", modify_action, " -> ", display_text)

func update_control(newer_action: String) -> void:
	"""Called when a button is clicked to start remapping"""
	print("Waiting for input for action: ", newer_action)
	modify_action = newer_action
	modify_control = true

func load_saved_controls() -> void:
	"""Load controls from saved file"""
	var json_data = SaveLoad.load_data("user://", "controls.json")
	
	if json_data == null:
		print("No saved controls found, using defaults")
		return
	
	control_data = SaveLoad.parse_json_data(json_data)
	
	if control_data == null:
		print("Failed to parse control data")
		return
	
	print("Loading saved controls...")
	
	# Apply saved controls
	for key in control_data:
		var value = str_to_var(control_data[key]) as InputEvent
		
		if not InputMap.has_action(key):
			print("WARNING: Action '", key, "' does not exist, skipping")
			continue
		
		# Clear existing events
		InputMap.action_erase_events(key)
		
		# Add the saved event
		InputMap.action_add_event(key, value)
		
		print("  Loaded: ", key, " -> ", value.as_text())

func save_data() -> void:
	"""Save current control mappings to file"""
	print("Saving controls...")
	print("Control data: ", control_data)
	
	var json_string = JSON.stringify(control_data)
	SaveLoad.save_data("user://", "controls.json", json_string)
	
	print("Controls saved successfully!")
