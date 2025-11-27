extends CharacterBody3D
@export var speed = 14
@export var fall_acceleration = 75
@onready var camera = %Camera3D # Replace with the correct path to your Camera3D
var camera_angle_v = 0.0
var target_velocity = Vector3.ZERO
func _physics_process(delta):
	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("ui_up"):
		input_dir += -global_transform.basis.z
	if Input.is_action_pressed("ui_down"):
		input_dir += global_transform.basis.z
	if Input.is_action_pressed("ui_left"):
		input_dir += -global_transform.basis.x
	if Input.is_action_pressed("ui_right"):
		input_dir += global_transform.basis.x
	var direction = input_dir.normalized()
	# Ground Velocity
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed
	if not is_on_floor(): # If in the air, fall towards the floor. Literally gravity
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)
	velocity = target_velocity
	move_and_slide()
# Continued on next page ...
func _input(event):
	if event is InputEventMouseMotion:
	# Rotate around the Y-axis (yaw)
		rotate_y(-event.relative.x * .002)
		# Rotate around the X-axis (pitch) with clamping
		var change_v = -event.relative.y * .002
		camera_angle_v += change_v
		# Clamp vertical camera angle to prevent flipping (e.g., -90 to 90 degrees)
		# You can adjust the limits as needed
		var min_angle = deg_to_rad(-89.0)
		var max_angle = deg_to_rad(89.0)
		camera_angle_v = clamp(camera_angle_v, min_angle, max_angle)
		# Apply the rotation to the camera (or its parent pivot)
