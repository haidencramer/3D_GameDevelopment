#extends Control
#
#@onready var options_button = $OptionsButton
#@export var input_mapping_scene: PackedScene
#
#func _ready():
	#options_button.pressed.connect(_on_options_button_pressed)
	#
#func _process(delta):
	#pass
	#
#
#
#
#func on_start_button_pressed() -> void:
	#get_tree().change_scene_to_file("res://scenes/MultiplayerConnect.tscn")
#
#
#func _on_options_button_pressed() -> void:
	#var input_mapping = input_mapping_scene.instantiate()
	#add_child(input_mapping)
#
#
#func _on_quit_button_pressed() -> void:
	#get_tree().quit()
#
#
#func _on_button_4_pressed() -> void:
	#get_tree().change_scene_to_file("res://scenes/Credits.tscn")

extends Control

@onready var options_button = $OptionsButton
@onready var start_button = $Button
@onready var credits_button = $Button4  # Adjust if needed
@onready var quit_button = $Button3
@onready var title_sprite = $Sprite2D
@export var input_mapping_scene: PackedScene

# Multiplayer UI elements
var multiplayer_ui_visible := false
var create_button: Button
var join_button: Button
var back_button: Button
var ip_input: LineEdit
var name_input: LineEdit
var ip_label: Label

# Store original title position
var original_title_position: Vector2

const PORT = 7000
const DEFAULT_SERVER_IP = "127.0.0.1"
const MAX_CONNECTIONS = 20

func _ready():
	options_button.pressed.connect(_on_options_button_pressed)
	start_button.pressed.connect(on_start_button_pressed)
	if credits_button:
		credits_button.pressed.connect(_on_credits_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Store original title position
	if title_sprite:
		original_title_position = title_sprite.position
	
	# Connect multiplayer signals
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	_create_multiplayer_ui()

func _create_multiplayer_ui():
	# Get the style from existing buttons for consistency
	var button_style_normal = start_button.get_theme_stylebox("normal")
	var button_style_hover = start_button.get_theme_stylebox("hover")
	var button_style_pressed = start_button.get_theme_stylebox("pressed")
	
	# Smaller dimensions for multiplayer UI
	var ui_width = 320
	var ui_height = 65
	var start_x = 774  # Centered position
	var start_y = 200
	var spacing = 75
	
	# Create IP Label with wooden background (matching button style)
	ip_label = Label.new()
	ip_label.text = "Server IP"
	ip_label.position = Vector2(start_x, start_y)
	ip_label.size = Vector2(ui_width, ui_height)
	ip_label.add_theme_font_size_override("font_size", 28)
	ip_label.add_theme_color_override("font_color", Color.BLACK)
	ip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Add the wooden background style (same as buttons)
	if button_style_normal:
		ip_label.add_theme_stylebox_override("normal", button_style_normal)
	ip_label.visible = false
	add_child(ip_label)
	
	# Create Name Input
	name_input = LineEdit.new()
	name_input.position = Vector2(start_x, start_y + spacing)
	name_input.size = Vector2(ui_width, ui_height)
	name_input.placeholder_text = "Username"
	name_input.add_theme_font_size_override("font_size", 24)
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.visible = false
	add_child(name_input)
	
	# Create IP Input
	ip_input = LineEdit.new()
	ip_input.position = Vector2(start_x, start_y + spacing * 2)
	ip_input.size = Vector2(ui_width, ui_height)
	ip_input.placeholder_text = "127.0.0.1"
	ip_input.text = DEFAULT_SERVER_IP
	ip_input.add_theme_font_size_override("font_size", 24)
	ip_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_input.visible = false
	add_child(ip_input)
	
	# Create Create Server button
	create_button = Button.new()
	create_button.text = "Create Server"
	create_button.position = Vector2(start_x, start_y + spacing * 3)
	create_button.size = Vector2(ui_width, ui_height)
	create_button.add_theme_color_override("font_color", Color.BLACK)
	create_button.add_theme_font_size_override("font_size", 28)
	if button_style_normal:
		create_button.add_theme_stylebox_override("normal", button_style_normal)
	if button_style_hover:
		create_button.add_theme_stylebox_override("hover", button_style_hover)
	if button_style_pressed:
		create_button.add_theme_stylebox_override("pressed", button_style_pressed)
	create_button.pressed.connect(_on_create_pressed)
	create_button.visible = false
	add_child(create_button)
	
	# Create Join Server button
	join_button = Button.new()
	join_button.text = "Join Server"
	join_button.position = Vector2(start_x, start_y + spacing * 4)
	join_button.size = Vector2(ui_width, ui_height)
	join_button.add_theme_color_override("font_color", Color.BLACK)
	join_button.add_theme_font_size_override("font_size", 28)
	if button_style_normal:
		join_button.add_theme_stylebox_override("normal", button_style_normal)
	if button_style_hover:
		join_button.add_theme_stylebox_override("hover", button_style_hover)
	if button_style_pressed:
		join_button.add_theme_stylebox_override("pressed", button_style_pressed)
	join_button.pressed.connect(_on_join_pressed)
	join_button.visible = false
	add_child(join_button)
	
	# Create Back button
	back_button = Button.new()
	back_button.text = "Back"
	back_button.position = Vector2(start_x, start_y + spacing * 5)
	back_button.size = Vector2(ui_width, ui_height)
	back_button.add_theme_color_override("font_color", Color.BLACK)
	back_button.add_theme_font_size_override("font_size", 28)
	if button_style_normal:
		back_button.add_theme_stylebox_override("normal", button_style_normal)
	if button_style_hover:
		back_button.add_theme_stylebox_override("hover", button_style_hover)
	if button_style_pressed:
		back_button.add_theme_stylebox_override("pressed", button_style_pressed)
	back_button.pressed.connect(_on_back_pressed)
	back_button.visible = false
	add_child(back_button)

func on_start_button_pressed() -> void:
	# Hide main menu buttons
	start_button.visible = false
	options_button.visible = false
	if credits_button:
		credits_button.visible = false
	quit_button.visible = false
	
	# Move title sprite up to avoid overlap (reduced movement)
	if title_sprite:
		title_sprite.position.y = original_title_position.y 
	
	# Show multiplayer UI
	ip_label.visible = true
	name_input.visible = true
	ip_input.visible = true
	create_button.visible = true
	join_button.visible = true
	back_button.visible = true
	multiplayer_ui_visible = true

func _on_back_pressed() -> void:
	# Hide multiplayer UI
	ip_label.visible = false
	name_input.visible = false
	ip_input.visible = false
	create_button.visible = false
	join_button.visible = false
	back_button.visible = false
	multiplayer_ui_visible = false
	
	# Restore title sprite to original position
	if title_sprite:
		title_sprite.position = original_title_position
	
	# Show main menu buttons
	start_button.visible = true
	options_button.visible = true
	if credits_button:
		credits_button.visible = true
	quit_button.visible = true

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

func _on_join_pressed() -> void:
	print("JOIN button pressed")
	var address = ip_input.text if ip_input.text.length() > 0 else DEFAULT_SERVER_IP

	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(address, PORT)
	if error:
		print("Failed to join game: ", error)
		return

	multiplayer.multiplayer_peer = peer
	print("Connecting to ", address, "...")

func _on_connected_ok():
	print("Connected to server! ID: ", multiplayer.get_unique_id())
	get_tree().change_scene_to_file("res://scenes/MainLevelComplete.tscn")

func _on_connected_fail():
	print("Failed to connect to server")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	print("Server shut down")
	multiplayer.multiplayer_peer = null

func _on_options_button_pressed() -> void:
	var input_mapping = input_mapping_scene.instantiate()
	add_child(input_mapping)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_credits_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Credits.tscn")
