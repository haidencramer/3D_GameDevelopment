extends Button

@export var action_name: String

func _ready() -> void:
	pressed.connect(on_button_clicked)
	ButtonMappingMenu.update_button.connect(receive_new_text_data)
	
	var get_events = InputMap.action_get_events(action_name)
	if(get_events == null or get_events.size() == 0):
		return
	text = get_events[0].as_text()
	
func on_button_clicked() -> void:
	ButtonMappingMenu.update_control(action_name)

func receive_new_text_data(act_name: String, new_button_name: String):
	if(act_name != action_name):
		return
	text = new_button_name
		
