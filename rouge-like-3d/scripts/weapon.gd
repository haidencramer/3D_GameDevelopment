class_name Weapon extends RigidBody3D

@export var weapon_name: String = "Weapon"
@export var damage: float = 10.0
@export var weight: float = 1.0
@export var angular_drag: float = 5.0
@export var swing_force_multiplier: float = 200.0  # Much higher for better response
@export var position_lock_strength: float = 20.0
@export var rotation_lock_strength: float = 5.0

var grip_point: Node3D
var is_held: bool = false
var holder: Node3D = null

var last_mouse_position: Vector2 = Vector2.ZERO
var smoothed_mouse_velocity: Vector2 = Vector2.ZERO
@export var mouse_smoothing: float = 0.3  # Smooths out jittery mouse movement

func _ready() -> void:
	print("\n=== WEAPON READY: ", weapon_name, " ===")
	print("Position: ", global_position)
	
	# Find the GripPoint
	grip_point = get_node_or_null("GripPoint")
	if not grip_point:
		push_error("Weapon '", weapon_name, "' needs a GripPoint child node!")
	else:
		print("GripPoint found")
	
	# Set up physics properties
	gravity_scale = 1.0
	angular_damp = angular_drag
	lock_rotation = false
	linear_damp = 0.5
	
	# Check collision settings
	print("Collision Layer: ", collision_layer)
	print("Collision Mask: ", collision_mask)
	
	# Start in pickup mode
	set_pickup_mode(true)
	
	# Connect collision signal
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("Collision signal connected")

func _physics_process(delta: float) -> void:
	if is_held and holder:
		_update_held_position()
		_apply_mouse_swing(delta)

func set_pickup_mode(enabled: bool) -> void:
	print("Setting pickup mode for ", weapon_name, ": ", enabled)
	
	if enabled:
		# Can be picked up - normal physics
		collision_layer = 1  # Layer 1
		collision_mask = 1   # Collides with layer 1
		freeze = false
		gravity_scale = 1.0
		print("  Weapon is now pickable (gravity ON)")
	else:
		# Being held - special physics
		collision_layer = 2  # Layer 2
		collision_mask = 5   # Collides with layers 1 and 3
		freeze = false
		gravity_scale = 0.0  # No gravity while held
		print("  Weapon is now held (gravity OFF)")

func pickup(holder_node: Node3D, hand_point: Node3D) -> void:
	print("\n=== PICKUP CALLED ===")
	print("Weapon: ", weapon_name)
	print("Holder: ", holder_node.name)
	print("Hand point: ", hand_point.name)
	
	is_held = true
	holder = holder_node
	
	# Disable gravity and change collision
	set_pickup_mode(false)
	
	# Reset velocities
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Position at hand
	global_position = hand_point.global_position
	
	# Initialize mouse tracking
	last_mouse_position = get_viewport().get_mouse_position()
	smoothed_mouse_velocity = Vector2.ZERO
	
	print("Moved to hand position: ", global_position)
	print("SUCCESS: Weapon '", weapon_name, "' picked up")

func drop() -> void:
	print("\n=== DROP CALLED ===")
	print("Weapon: ", weapon_name)
	
	if not is_held:
		print("ERROR: Weapon was not held!")
		return
	
	# Store holder velocity before clearing
	var drop_velocity = Vector3.ZERO
	if holder and holder is CharacterBody3D:
		drop_velocity = holder.velocity
		print("Applying holder velocity: ", drop_velocity)
	
	# Clear held state
	is_held = false
	holder = null
	
	# Re-enable pickup mode
	set_pickup_mode(true)
	
	# Apply velocity for realistic drop
	linear_velocity = drop_velocity + Vector3(0, 2, 0)
	print("Applied drop velocity: ", linear_velocity)
	
	# Reset mouse tracking
	last_mouse_position = Vector2.ZERO
	smoothed_mouse_velocity = Vector2.ZERO
	
	print("SUCCESS: Weapon '", weapon_name, "' dropped")

func _update_held_position() -> void:
	if not grip_point or not holder:
		return
	
	var hand_point = holder.get_node_or_null("HandPoint")
	if not hand_point:
		return
	
	# Calculate target position based on grip point offset
	var grip_offset = grip_point.position
	var target_position = hand_point.global_position - (global_transform.basis * grip_offset)
	
	# Smoothly move to target position
	linear_velocity = (target_position - global_position) * position_lock_strength
	
	# Gentle rotation lock to hand orientation (but allow swing override)
	var target_rotation = hand_point.global_transform.basis
	var rotation_diff = global_transform.basis.get_rotation_quaternion().inverse() * target_rotation.get_rotation_quaternion()
	var axis = rotation_diff.get_axis()
	var angle = rotation_diff.get_angle()
	
	# Only apply rotation lock if the weapon isn't being swung hard
	if angular_velocity.length() < 5.0:
		angular_velocity = axis * angle * rotation_lock_strength

func _apply_mouse_swing(delta: float) -> void:
	var current_mouse = get_viewport().get_mouse_position()
	
	# Calculate raw mouse velocity
	var raw_velocity = Vector2.ZERO
	if last_mouse_position != Vector2.ZERO:
		raw_velocity = (current_mouse - last_mouse_position) / delta
	
	# Smooth the mouse velocity to reduce jitter
	smoothed_mouse_velocity = smoothed_mouse_velocity.lerp(raw_velocity, mouse_smoothing)
	
	# Only apply force if there's significant mouse movement
	if smoothed_mouse_velocity.length() > 10.0:  # Threshold to avoid tiny movements
		var camera = get_viewport().get_camera_3d()
		if camera:
			var cam_right = camera.global_transform.basis.x
			var cam_up = camera.global_transform.basis.y
			
			# Apply torque based on smoothed mouse movement
			# X movement = rotation around up axis
			# Y movement = rotation around right axis
			var torque = (cam_up * smoothed_mouse_velocity.x - cam_right * smoothed_mouse_velocity.y) * swing_force_multiplier * delta
			apply_torque(torque)
	
	last_mouse_position = current_mouse

func _on_body_entered(body: Node) -> void:
	if not is_held:
		return
	
	# Calculate impact force
	var impact_force = linear_velocity.length() + angular_velocity.length()
	
	# Deal damage if target can take damage
	if body.has_method("take_damage"):
		var damage_dealt = damage * (impact_force / 10.0)
		body.take_damage(damage_dealt)
		print("Hit ", body.name, " for ", damage_dealt, " damage!")
