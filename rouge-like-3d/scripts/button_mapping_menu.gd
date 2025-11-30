extends Control

signal update_button(newText: String, actionName: String)
var modify_control: bool = false
var modify_action: String
var control_data = {}

func _input(event: InputEvent) -> void:
	if(!modify_control or event is InputEventMouseMotion or !InputMap.has_action(modify_action)):
		return

	InputMap.action_erase_events(modify_action)
	InputMap.action_add_event(modify_action, event)
	control_data[modify_action] = var_to_str(event)
	modify_control = false
	
	update_button.emit(modify_action, event.as_text())
func _ready() -> void:
	var json_data = SaveLoad.load_data("user://", "controls.json")
	
	if (json_data == null):
		return
	control_data = SaveLoad.parse_json_data(json_data)
	
	load_control_data()

func load_control_data():
	for key in control_data:
		var value = str_to_var(control_data[key]) as InputEvent
		
		if(!InputMap.has_action(key)):
			return
		InputMap.action_erase_events(key)
		InputMap.action_add_event(key, value)
	
func update_control(newer_action: String):
	modify_action = newer_action
	modify_control = true

func save_data():
	SaveLoad.save_data("user://", "controls.json", JSON.stringify(control_data))
