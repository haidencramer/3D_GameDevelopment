class_name Weapon extends RigidBody3D

@export var weapon_name: String = "Weapon"
@export var damage: float = 10.0
@export var weight: float = 1.0
@export var angular_drag: float = 1.0

# Physics-based swinging parameters
@export var hand_spring_strength: float = 150.0  # Lower for more freedom
@export var hand_spring_damping: float = 8.0
@export var mouse_swing_force: float = 15.0  # Direct mouse force
@export var mouse_torque_strength: float = 25.0  # Torque from mouse movement
@export var max_distance_from_hand: float = 2.0  # Max stretch distance

var grip_point: Node3D
var is_held: bool = false
var holder: Node3D = null

# Direct mouse tracking
var last_mouse_position: Vector2 = Vector2.ZERO
var mouse_delta: Vector2 = Vector2.ZERO

# 3D hand tracking
var last_hand_position: Vector3 = Vector3.ZERO

# Damage tracking to prevent self-damage
var damage_cooldown: float = 0.0
const DAMAGE_COOLDOWN_TIME: float = 0.3

func _ready() -> void:
	print("\n=== WEAPON READY: ", weapon_name, " ===")
	print("Position: ", global_position)
	
	grip_point = get_node_or_null("GripPoint")
	if not grip_point:
		push_error("Weapon '", weapon_name, "' needs a GripPoint child node!")
	else:
		print("GripPoint found at: ", grip_point.position)
	
	# Physics setup for responsive swinging
	gravity_scale = 1.0
	angular_damp = angular_drag
	linear_damp = 0.1  # Very low for free movement
	lock_rotation = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	
	# Set mass based on weight
	mass = weight
	
	print("Mass: ", mass)
	print("Collision Layer: ", collision_layer)
	print("Collision Mask: ", collision_mask)
	
	set_pickup_mode(true)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		print("Collision signal connected")

func _physics_process(delta: float) -> void:
	if damage_cooldown > 0:
		damage_cooldown -= delta
	
	if is_held and holder:
		_apply_loose_constraint(delta)
		_apply_direct_mouse_swing(delta)

func set_pickup_mode(enabled: bool) -> void:
	print("Setting pickup mode for ", weapon_name, ": ", enabled)
	
	if enabled:
		collision_layer = 1
		collision_mask = 1
		freeze = false
		gravity_scale = 1.0
		linear_damp = 0.5
		angular_damp = angular_drag
		print("  Weapon is now pickable (gravity ON)")
	else:
		# Layer 2 for held weapons, only collide with enemies (layer 3)
		collision_layer = 2
		collision_mask = 4  # Only collide with layer 3 (enemies)
		freeze = false
		gravity_scale = 0.0
		linear_damp = 0.1  # Very low damping for free swinging
		angular_damp = angular_drag * 0.3  # Very low for free rotation
		print("  Weapon is now held (gravity OFF, free swing)")

func pickup(holder_node: Node3D, hand_point: Node3D) -> void:
	print("\n=== PICKUP CALLED ===")
	print("Weapon: ", weapon_name)
	print("Holder: ", holder_node.name)
	print("Hand point: ", hand_point.name)
	
	is_held = true
	holder = holder_node
	
	set_pickup_mode(false)
	
	# Clear velocities for clean pickup
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Position at hand
	var grip_offset = grip_point.position
	global_position = hand_point.global_position - (global_transform.basis * grip_offset)
	global_rotation = hand_point.global_rotation
	
	# Initialize tracking
	last_hand_position = hand_point.global_position
	last_mouse_position = get_viewport().get_mouse_position()
	mouse_delta = Vector2.ZERO
	
	print("Pickup complete - ready to swing!")
	print("Hand position: ", hand_point.global_position)
	print("Weapon position: ", global_position)

func drop() -> void:
	print("\n=== DROP CALLED ===")
	print("Weapon: ", weapon_name)
	
	if not is_held:
		print("ERROR: Weapon was not held!")
		return
	
	var drop_velocity = Vector3.ZERO
	if holder and holder is CharacterBody3D:
		drop_velocity = holder.velocity
		print("Applying holder velocity: ", drop_velocity)
	
	is_held = false
	holder = null
	
	set_pickup_mode(true)
	
	# Keep the weapon's momentum
	linear_velocity += drop_velocity + Vector3(0, 2, 0)
	
	print("SUCCESS: Weapon '", weapon_name, "' dropped")

func _apply_loose_constraint(delta: float) -> void:
	"""Loose spring constraint - keeps weapon near hand but allows free movement"""
	if not grip_point or not holder:
		return
	
	var hand_point = holder.get_node_or_null("SpiderModel/HandPoint")
	if not hand_point:
		return
	
	var grip_world_pos = global_transform * grip_point.position
	var hand_pos = hand_point.global_position
	var displacement = hand_pos - grip_world_pos
	var distance = displacement.length()
	
	# Only pull back if stretched too far
	if distance > max_distance_from_hand:
		var pull_strength = (distance - max_distance_from_hand) * hand_spring_strength
		var spring_force = displacement.normalized() * pull_strength
		var damping = -linear_velocity * hand_spring_damping
		
		apply_central_force(spring_force + damping)
	else:
		# Very gentle centering when close
		if distance > 0.1:
			var gentle_pull = displacement * hand_spring_strength * 0.1
			apply_central_force(gentle_pull)

func _apply_direct_mouse_swing(delta: float) -> void:
	"""Direct mouse movement creates forces and torques on the weapon"""
	var current_mouse = get_viewport().get_mouse_position()
	
	# Calculate mouse movement this frame
	if last_mouse_position != Vector2.ZERO:
		mouse_delta = current_mouse - last_mouse_position
	else:
		mouse_delta = Vector2.ZERO
	
	# Only apply forces if mouse is actually moving
	if mouse_delta.length() > 0.5:  # Small threshold to ignore tiny jitters
		var camera = get_viewport().get_camera_3d()
		if camera:
			# Get camera basis vectors
			var cam_right = camera.global_transform.basis.x
			var cam_up = camera.global_transform.basis.y
			var cam_forward = -camera.global_transform.basis.z
			
			# Convert 2D mouse movement to 3D swing direction
			var swing_direction = (cam_right * mouse_delta.x + cam_up * -mouse_delta.y).normalized()
			
			# Apply linear force in swing direction
			var force_magnitude = mouse_delta.length() * mouse_swing_force
			var swing_force = swing_direction * force_magnitude
			
			# Apply force at the tip of the weapon for rotation
			var tip_offset = -grip_point.position.normalized() * 1.5
			apply_force(swing_force, tip_offset)
			
			# Also apply torque for rotation
			var torque_axis = cam_forward.cross(swing_direction)
			if torque_axis.length() > 0.01:
				torque_axis = torque_axis.normalized()
				var torque_strength = mouse_delta.length() * mouse_torque_strength
				apply_torque(torque_axis * torque_strength)
			
			# Debug output
			if int(Time.get_ticks_msec()) % 100 == 0:  # Print every ~100ms
				print("Mouse delta: ", mouse_delta, " | Force: ", swing_force.length(), " | Angular vel: ", angular_velocity.length())
	
	last_mouse_position = current_mouse

func _on_body_entered(body: Node) -> void:
	if not is_held:
		return
	
	# CRITICAL: Don't damage the holder!
	if body == holder:
		return
	
	# Prevent rapid repeated damage
	if damage_cooldown > 0:
		return
	
	# Calculate impact force
	var impact_speed = linear_velocity.length() + (angular_velocity.length() * 0.5)
	
	# Only deal damage if moving fast enough
	if impact_speed < 3.0:
		print("Hit too weak: ", impact_speed)
		return
	
	# Deal damage based on impact speed and weapon stats
	if body.has_method("take_damage"):
		var base_damage = damage
		var speed_multiplier = clamp(impact_speed / 5.0, 0.5, 3.0)
		var damage_dealt = base_damage * speed_multiplier
		
		body.take_damage(damage_dealt)
		print("*** HIT ", body.name, " for ", damage_dealt, " damage (speed: ", impact_speed, ") ***")
		
		# Set cooldown
		damage_cooldown = DAMAGE_COOLDOWN_TIME
		
		# Impact feedback
		var bounce_force = -linear_velocity.normalized() * impact_speed * 0.3
		apply_central_impulse(bounce_force)
