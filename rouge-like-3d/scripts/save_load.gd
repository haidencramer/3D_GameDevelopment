extends Node

func save_data(path: String, fileName: String, data: String) -> void:
	var save_file = FileAccess.open(path + fileName, FileAccess.WRITE)
	save_file.store_pascal_string(data)
	
func load_data(path: String, file_name: String):
	if(!FileAccess.file_exists(path + file_name)):
		return null
		
	var load_file = FileAccess.open(path + file_name, FileAccess.READ)
	
	var return_data = load_file.get_pascal_string()
	return return_data

func parse_json_data(data: String):
	var json = JSON.new()
	var error = json.parse(data)
	
	if(error == OK):
		var data_received = json.data;
		
		if typeof(data_received) == TYPE_DICTIONARY:
			return data_received
		else:
			print("bad data")
