class_name Weapon extends RigidBody3D

@export var weapon_name: String = "Weapon"
@export var damage: float = 10.0
@export var weight: float = 1.0

@export var angular_drag: float = 5.0
@export var swing_force_multiplier: float = 50.0

var grip_point: Node3D
var is_held: bool = false
var holder: Node3D = null

var last_mouse_position: Vector2 = Vector2.ZERO
var mouse_velocity: Vector2 = Vector2.ZERO

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
		_update_held_position()
		_apply_mouse_swing(delta)

func set_pickup_mode(enabled: bool) -> void:
	if enabled:
		collision_layer = 1
		collision_mask = 1
		freeze = false
		gravity_scale = 1.0
	else:
		collision_layer = 2
		collision_mask = 4
		freeze = false
		gravity_scale = 0.0

func pickup(holder_node: Node3D, hand_point: Node3D) -> void:
	is_held = true
	holder = holder_node
	set_pickup_mode(false)
	global_position = hand_point.global_position
	print("Picked up: ", weapon_name)

func drop() -> void:
	var drop_vel = Vector3.ZERO
	if holder and holder is CharacterBody3D:
		drop_vel = holder.velocity

	is_held = false
	set_pickup_mode(true)

	linear_velocity = drop_vel
	holder = null

	print("Dropped: ", weapon_name)

func _update_held_position() -> void:
	if not grip_point or not holder:
		return
	
	var hand_point = holder.get_node_or_null("HandPoint")
	if not hand_point:
		return
	
	var grip_offset = grip_point.position
	var target_position = hand_point.global_position - (global_transform.basis * grip_offset)
	
	var lock_strength = 20.0
	linear_velocity = (target_position - global_position) * lock_strength

func _apply_mouse_swing(delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	
	var current_mouse = get_viewport().get_mouse_position()
	
	if last_mouse_position != Vector2.ZERO:
		mouse_velocity = (current_mouse - last_mouse_position) / delta
		
		var camera = get_viewport().get_camera_3d()
		if camera:
			var cam_right = camera.global_transform.basis.x
			var cam_up = camera.global_transform.basis.y
			
			var torque = (cam_up * mouse_velocity.x - cam_right * mouse_velocity.y) * swing_force_multiplier * delta
			apply_torque(torque)
	
	last_mouse_position = current_mouse

func _on_body_entered(body: Node) -> void:
	if not is_held:
		return
	
	var impact_force = linear_velocity.length() + angular_velocity.length()
	
	if body.has_method("take_damage"):
		var damage_dealt = damage * (impact_force / 10.0)
		body.take_damage(damage_dealt)
		print("Hit ", body.name, " for ", damage_dealt, " damage!")
