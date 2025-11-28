class_name Weapon extends RigidBody3D

# Weapon stats
@export var weapon_name: String = "Weapon"
@export var damage: float = 10.0
@export var weight: float = 1.0

# Physics settings
@export var angular_drag: float = 5.0  # How much the weapon resists rotation
@export var swing_force_multiplier: float = 50.0

# References
var grip_point: Node3D
var is_held: bool = false
var holder: Node3D = null

# Mouse swing variables
var last_mouse_position: Vector2 = Vector2.ZERO
var mouse_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Find the grip point
	grip_point = get_node_or_null("GripPoint")
	if not grip_point:
		push_error("Weapon needs a GripPoint child node!")
	
	# Set up physics
	gravity_scale = 1.0
	angular_damp = angular_drag
	lock_rotation = false  # Allow free rotation
	
	# Start in pickup mode
	set_pickup_mode(true)

func _physics_process(delta: float) -> void:
	if is_held and holder:
		# Keep weapon grip attached to holder's hand point
		_update_held_position()
		
		# Apply mouse swing forces
		_apply_mouse_swing(delta)

func set_pickup_mode(enabled: bool) -> void:
	"""Toggle between pickup mode and held mode"""
	if enabled:
		collision_layer = 1  # Default layer
		collision_mask = 1
		freeze = false
		gravity_scale = 1.0
	else:
		# When held, only collide with enemies/environment
		collision_layer = 2  # Weapon layer
		collision_mask = 4   # Enemy layer
		freeze = false
		gravity_scale = 0.0  # No gravity when held

func pickup(holder_node: Node3D, hand_point: Node3D) -> void:
	"""Called when player picks up the weapon"""
	is_held = true
	holder = holder_node
	set_pickup_mode(false)
	
	# Position weapon at hand point initially
	global_position = hand_point.global_position
	
	print("Picked up: ", weapon_name)

func drop() -> void:
	"""Called when player drops the weapon"""
	is_held = false
	holder = null
	set_pickup_mode(true)
	
	# Add some drop velocity
	linear_velocity = holder.velocity if holder else Vector3.ZERO
	
	print("Dropped: ", weapon_name)

func _update_held_position() -> void:
	"""Keep the grip point attached to holder's hand while allowing rotation"""
	if not grip_point or not holder:
		return
	
	# Get the hand point from holder
	var hand_point = holder.get_node_or_null("HandPoint")
	if not hand_point:
		return
	
	# Calculate where the weapon should be based on grip point
	var grip_offset = grip_point.position
	var target_position = hand_point.global_position - (global_transform.basis * grip_offset)
	
	# Smoothly move to target position (keeps grip locked)
	var lock_strength = 20.0  # Higher = tighter lock
	linear_velocity = (target_position - global_position) * lock_strength

func _apply_mouse_swing(delta: float) -> void:
	"""Apply force based on mouse movement"""
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	
	var current_mouse = get_viewport().get_mouse_position()
	
	if last_mouse_position != Vector2.ZERO:
		# Calculate mouse velocity
		mouse_velocity = (current_mouse - last_mouse_position) / delta
		
		# Convert 2D mouse movement to 3D torque
		var camera = get_viewport().get_camera_3d()
		if camera:
			# Get camera's right and up vectors
			var cam_right = camera.global_transform.basis.x
			var cam_up = camera.global_transform.basis.y
			
			# Combine mouse X and Y movement into 3D torque
			var torque = (cam_up * mouse_velocity.x - cam_right * mouse_velocity.y) * swing_force_multiplier * delta
			
			# Apply torque to swing the weapon
			apply_torque(torque)
	
	last_mouse_position = current_mouse

func _on_body_entered(body: Node) -> void:
	"""Handle collisions when weapon hits something"""
	if not is_held:
		return
	
	# Calculate impact force
	var impact_force = linear_velocity.length() + angular_velocity.length()
	
	if body.has_method("take_damage"):
		var damage_dealt = damage * (impact_force / 10.0)  # Scale damage by swing speed
		body.take_damage(damage_dealt)
		print("Hit ", body.name, " for ", damage_dealt, " damage!")
