extends Control
#multiplayer_connect.gd
@onready var Name = $Name
@onready var addressInput = $TextEdit
const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
const MAX_CONNECTIONS = 20
func _ready():
	# Connect signals properly
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
func _on_create_pressed() -> void:
	print("CREATE button pressed")
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT, MAX_CONNECTIONS)
	if error:
		print("Failed to create server: ", error)
		return

	multiplayer.multiplayer_peer = peer
	print("Server created. ID: ", multiplayer.get_unique_id())

	# Load game scene
	get_tree().change_scene_to_file("res://scenes/MainLevelComplete.tscn")
func _on_host_pressed() -> void:
	print("JOIN button pressed")
	var address = addressInput.text if addressInput.text.length() > 0 else DEFAULT_SERVER_IP

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		print("Failed to join game: ", error)
		return

	multiplayer.multiplayer_peer = peer
	print("Connecting to ", address, "...")
func _on_connected_ok():
	print("Connected to server! ID: ", multiplayer.get_unique_id())
	# Load game scene when connected
	get_tree().change_scene_to_file("res://scenes/MainLevelComplete.tscn")
func _on_connected_fail():
	print("Failed to connect to server")
	multiplayer.multiplayer_peer = null
func _on_server_disconnected():
	print("Server shut down")
	multiplayer.multiplayer_peer = null
