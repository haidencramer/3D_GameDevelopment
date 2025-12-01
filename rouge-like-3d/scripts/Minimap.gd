extends CanvasLayer

# Reference to the minimap viewport
@onready var minimap_viewport = $SubViewportContainer/SubViewport
@onready var minimap_camera = $SubViewportContainer/SubViewport/MinimapCamera3D

# Reference to the player (set this in the editor or via code)
@export var player: Node3D
@export var follow_height: float = 20.0  # Height above player
@export var zoom_level: float = 1.0

func _ready():
	print("Minimap script started!")
	print("Player reference: ", player)
	
	# Setup viewport
	if minimap_viewport:
		minimap_viewport.size = Vector2i(200, 200)
		minimap_viewport.transparent_bg = false
		print("Viewport configured")

func _process(_delta):
	if player and minimap_camera:
		# Position camera above player
		minimap_camera.global_position = player.global_position + Vector3(0, follow_height, 0)
		
		# Make camera look down at player
		minimap_camera.look_at(player.global_position, Vector3.FORWARD)
