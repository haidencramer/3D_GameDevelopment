
#func _physics_process(delta: float) -> void:
	#if is_held and holder:
		#_update_held_position()
		#_apply_mouse_swing(delta)

#func set_pickup_mode(enabled: bool) -> void:
	#if enabled:
		#collision_layer = 1
		#collision_mask = 1
		#freeze = false
		#gravity_scale = 1.0
	#else:
		#collision_layer = 2
		#collision_mask = 4
		#freeze = false
		#gravity_scale = 0.0
		
#func pickup(holder_node: Node3D, hand_point: Node3D) -> void:
	#is_held = true
	#holder = holder_node
	#set_pickup_mode(false)
	#global_position = hand_point.global_position
	#print("Picked up: ", weapon_name)

#func drop() -> void:
	#var drop_vel = Vector3.ZERO
	#if holder and holder is CharacterBody3D:
		#drop_vel = holder.velocity
#
	#is_held = false
	#set_pickup_mode(true)
#
	#linear_velocity = drop_vel
	#holder = null
#
	#print("Dropped: ", weapon_name)

#func _update_held_position() -> void:
	#if not grip_point or not holder:
		#return
	#
	#var hand_point = holder.get_node_or_null("HandPoint")
	#if not hand_point:
		#return
	#
	#var grip_offset = grip_point.position
	#var target_position = hand_point.global_position - (global_transform.basis * grip_offset)
	#
	#var lock_strength = 20.0
	#linear_velocity = (target_position - global_position) * lock_strength

#func _apply_mouse_swing(delta: float) -> void:
	#if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		#return
	#
	#var current_mouse = get_viewport().get_mouse_position()
	#
	#if last_mouse_position != Vector2.ZERO:
		#mouse_velocity = (current_mouse - last_mouse_position) / delta
		#
		#var camera = get_viewport().get_camera_3d()
		#if camera:
			#var cam_right = camera.global_transform.basis.x
			#var cam_up = camera.global_transform.basis.y
			#
			#var torque = (cam_up * mouse_velocity.x - cam_right * mouse_velocity.y) * swing_force_multiplier * delta
			#apply_torque(torque)
	#
	#last_mouse_position = current_mouse

class_name Weapon extends RigidBody3D

# Weapon Properties
@export var weapon_name: String = "Weapon"
@export var damage: float = 10.0
@export var weight: float = 1.0
@export var angular_drag: float = 5.0

# Attack Properties
@export var light_attack_cooldown: float = 0.5
@export var heavy_attack_cooldown: float = 1.0
@export var light_swing_strength: float = 30.0
@export var heavy_swing_strength: float = 60.0

# Internal Variables
var grip_point: Node3D
var is_held: bool = false
var holder: Node3D = null

# Attack System Variables
var is_attacking: bool = false
var attack_time: float = 0.0
var attack_type: String = ""
var cooldown_timer: float = 0.0

func _ready() -> void:
	grip_point = get_node_or_null("GripPoint")
	if not grip_point:
		push_error("Weapon needs a GripPoint child node!")
	
	gravity_scale = 1.0
	angular_damp = angular_drag
	lock_rotation = false
	
	set_pickup_mode(true)

func _physics_process(delta: float) -> void:
	if is_held and holder:
		_constrain_to_hand(delta)
		_handle_attacks(delta)

func set_pickup_mode(enabled: bool) -> void:
	if enabled:
		collision_layer = 1  # Layer 1 for physics
		collision_mask = 1   # Collides with floor/walls
		freeze = false
		gravity_scale = 1.0
	else:  # When held
		collision_layer = 4  # Layer 4 for weapon hits
		collision_mask = 4   # Detect enemy hits
		freeze = false
		gravity_scale = 0.0

func pickup(holder_node: Node3D, hand_point: Node3D) -> void:
	is_held = true
	holder = holder_node
	
	# Don't freeze - we want physics for attacking
	freeze = false
	gravity_scale = 0.0
	collision_layer = 4  # Different layer for hitting enemies
	collision_mask = 4   # Detect enemy hits
	
	# Parent to hand point
	var old_parent = get_parent()
	old_parent.remove_child(self)
	hand_point.add_child(self)
	
	# Position relative to hand
	if grip_point:
		position = -grip_point.position
	else:
		position = Vector3.ZERO
	
	rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	print("Picked up: ", weapon_name)

func drop() -> void:
	# Store global transform before reparenting
	var global_trans = global_transform
	
	# Calculate drop velocity
	var drop_vel = Vector3.ZERO
	if holder and holder is CharacterBody3D:
		drop_vel = holder.velocity
		
		# Add forward toss force - short toss
		var forward = -holder.get_node("SpiderModel").transform.basis.z
		var toss_force = forward * 2.0 + Vector3.UP * 1.0
		drop_vel += toss_force
	
	# Reparent back to scene root
	var hand_point = get_parent()
	hand_point.remove_child(self)
	holder.get_parent().add_child(self)  # Add to scene root
	
	# Restore global position
	global_transform = global_trans
	
	is_held = false
	is_attacking = false  # Cancel any ongoing attack
	attack_type = ""
	cooldown_timer = 0.0
	
	set_pickup_mode(true)
	linear_velocity = drop_vel
	angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	holder = null
	
	print("Dropped: ", weapon_name)

# ===================================
# ATTACK SYSTEM
# ===================================

func _constrain_to_hand(delta: float) -> void:
	# Keep weapon rotation somewhat aligned with hand when not attacking heavily
	var hand_point = get_parent()
	if not hand_point:
		return
	
	# Smoothly rotate back toward hand orientation when not in heavy attack
	var constraint_strength = 0.9 if not is_attacking else 0.3
	
	# Interpolate rotation back to hand point
	var target_rotation = hand_point.rotation
	rotation = rotation.lerp(target_rotation, constraint_strength * delta * 10.0)
	
	# Limit angular velocity to prevent wild spinning
	var max_angular_velocity = 20.0 if is_attacking else 5.0
	angular_velocity = angular_velocity.limit_length(max_angular_velocity)

func _handle_attacks(delta: float) -> void:
	# Update cooldown
	if cooldown_timer > 0:
		cooldown_timer -= delta
	
	# Check for new attack input (only if not on cooldown)
	if not is_attacking and cooldown_timer <= 0:
		if Input.is_action_just_pressed("light_attack"):
			start_attack("light")
			cooldown_timer = light_attack_cooldown
		elif Input.is_action_just_pressed("heavy_attack"):
			start_attack("heavy")
			cooldown_timer = heavy_attack_cooldown
	
	# Process ongoing attack
	if is_attacking:
		attack_time += delta
		_apply_attack_swing(delta)
		
		# End attack after duration
		var attack_duration = 0.3 if attack_type == "light" else 0.6
		if attack_time >= attack_duration:
			end_attack()

func start_attack(type: String) -> void:
	is_attacking = true
	attack_type = type
	attack_time = 0.0
	print("Started ", type, " attack with ", weapon_name, "!")

func end_attack() -> void:
	is_attacking = false
	attack_type = ""
	angular_velocity = Vector3.ZERO  # Stop spinning
	# Weapon will smoothly return to hand orientation via _constrain_to_hand()
	print("Attack ended")

func _apply_attack_swing(delta: float) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
	
	var hand_point = get_parent()
	if not hand_point:
		return
	
	# Get hand's orientation as base for attacks
	var hand_right = hand_point.global_transform.basis.x
	var hand_forward = -hand_point.global_transform.basis.z
	var hand_up = hand_point.global_transform.basis.y
	
	# Different swing patterns for light vs heavy
	if attack_type == "light":
		# Quick horizontal slash - rotates around hand's up axis
		var swing_progress = attack_time / 0.3
		var swing_angle = sin(swing_progress * PI) * light_swing_strength
		
		# Rotate the weapon around the hand's up axis (horizontal slash)
		var target_rotation = hand_point.rotation
		target_rotation.y += deg_to_rad(swing_angle)
		rotation = rotation.lerp(target_rotation, delta * 15.0)
		
	elif attack_type == "heavy":
		# Powerful overhead slam - rotates around hand's right axis
		var swing_progress = attack_time / 0.6
		
		if swing_progress < 0.3:
			# Wind up (pull back)
			var wind_up_angle = swing_progress / 0.3 * -60.0  # Pull back 60 degrees
			var target_rotation = hand_point.rotation
			target_rotation.x += deg_to_rad(wind_up_angle)
			rotation = rotation.lerp(target_rotation, delta * 10.0)
		else:
			# Slam down
			var slam_progress = (swing_progress - 0.3) / 0.7
			var slam_angle = slam_progress * 120.0  # Swing forward 120 degrees
			var target_rotation = hand_point.rotation
			target_rotation.x += deg_to_rad(slam_angle - 60.0)  # Account for wind-up
			rotation = rotation.lerp(target_rotation, delta * 20.0)

# ===================================
# DAMAGE SYSTEM
# ===================================

func _on_body_entered(body: Node) -> void:
	if not is_held or not is_attacking:
		return
	
	var impact_force = linear_velocity.length() + angular_velocity.length()
	
	if body.has_method("take_damage"):
		# Heavy attack does more damage
		var damage_multiplier = 2.0 if attack_type == "heavy" else 1.0
		var damage_dealt = damage * damage_multiplier * (impact_force / 10.0)
		body.take_damage(damage_dealt)
		print("Hit ", body.name, " for ", damage_dealt, " damage with ", attack_type, " attack!")
