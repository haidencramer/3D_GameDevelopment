class_name Player extends CharacterBody3D

@export_range(1, 35, 1) var speed: float = 10 # m/s
@export_range(10, 400, 1) var acceleration: float = 100 # m/s^2
@export_range(0.1, 3.0, 0.1) var jump_height: float = 1 # m
@export var turn_speed: float = 2.5  # How fast character turns with A/D
@export var mouse_sensitivity: float = 0.002  # Mouse look sensitivity

var jumping: bool = false
var mouse_captured: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var walk_vel: Vector3 # Walking velocity 
var grav_vel: Vector3 # Gravity velocity 
var jump_vel: Vector3 # Jumping velocity

@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var anim_player: AnimationPlayer = $SpiderModel/spider/AnimationPlayer
@onready var spider_model: Node3D = $SpiderModel

func _ready() -> void:
	capture_mouse()
	
	# Connect to animation finished signal to manually loop
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)
		
		# Try to force loop mode on animations
		var anim_library = anim_player.get_animation_library("")
		if anim_library:
			for anim_name in anim_library.get_animation_list():
				var animation = anim_library.get_animation(anim_name)
				if animation:
					animation.loop_mode = Animation.LOOP_LINEAR

func _on_animation_finished(anim_name: String) -> void:
	# Manually restart animation if it should be looping
	if anim_player and anim_player.current_animation == anim_name:
		var is_moving = abs(Input.get_axis(&"move_down", &"move_up")) > 0.1
		if anim_name == "Armature|Walk" and is_moving:
			anim_player.play(anim_name)
		elif anim_name == "Armature|Idle" and not is_moving:
			anim_player.play(anim_name)
		elif anim_name == "Armature|Jump" and not is_on_floor():
			anim_player.play(anim_name)



func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed(&"jump") and is_on_floor(): 
		jumping = true
	
	# Handle A/D turning
	_handle_turning(delta)
	
	# Calculate movement
	velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	
	# Handle animations
	_update_animation()
	
	move_and_slide()

func _handle_turning(delta: float) -> void:
	# A/D keys turn the character (rotate around Y axis)
	if Input.is_action_pressed(&"move_left"):
		spider_model.rotation.y += turn_speed * delta  # Turn left (positive rotation)
		print("Turning LEFT - Rotation Y: ", rotation.y)
	if Input.is_action_pressed(&"move_right"):
		spider_model.rotation.y -= turn_speed * delta  # Turn right (negative rotation)
		print("Turning RIGHT - Rotation Y: ", spider_model.rotation.y)
	camera_pivot.rotation.y = spider_model.rotation.y
func _walk(delta: float) -> Vector3:
	# W/S for forward/backward movement relative to character facing
	var forward_input = Input.get_axis(&"move_down", &"move_up")
	
	print("Forward input: ", forward_input, " | Walk velocity: ", walk_vel.length())
	
	if forward_input != 0:
		# Move in the direction the character is facing
		var forward = -spider_model.transform.basis.z
		var walk_dir = forward.normalized()
		walk_vel = walk_vel.move_toward(walk_dir * speed * forward_input, acceleration * delta)
	else:
		# Decelerate when no input
		walk_vel = walk_vel.move_toward(Vector3.ZERO, acceleration * delta)
	
	return walk_vel

func _update_animation() -> void:
	if not anim_player:
		return
	
	var current_anim = anim_player.current_animation
	var is_moving = abs(Input.get_axis(&"move_down", &"move_up")) > 0.1
	
	# Check animation state priority: Jump > Walk > Idle
	if not is_on_floor():
		if anim_player.has_animation("Armature|Jump"):
			if current_anim != "Armature|Jump":
				anim_player.play("Armature|Jump")
	elif is_moving:
		if anim_player.has_animation("Armature|Walk"):
			if current_anim != "Armature|Walk":
				anim_player.play("Armature|Walk")
			anim_player.speed_scale = 1.0
	else:
		if anim_player.has_animation("Armature|Idle"):
			if current_anim != "Armature|Idle":
				anim_player.play("Armature|Idle")
		elif anim_player.has_animation("Armature|Walk"):
			if current_anim != "Armature|Walk":
				anim_player.play("Armature|Walk")
			anim_player.speed_scale = 0.3

func capture_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true

func release_mouse() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false

func _gravity(delta: float) -> Vector3:
	grav_vel = Vector3.ZERO if is_on_floor() else grav_vel.move_toward(Vector3(0, velocity.y - gravity, 0), gravity * delta)
	return grav_vel

func _jump(delta: float) -> Vector3:
	if jumping:
		if is_on_floor(): 
			jump_vel = Vector3(0, sqrt(4 * jump_height * gravity), 0)
		jumping = false
		return jump_vel
	jump_vel = Vector3.ZERO if is_on_floor() or is_on_ceiling_only() else jump_vel.move_toward(Vector3.ZERO, gravity * delta)
	return jump_vel
	
#Camera control via mouse input

#func _unhandled_input(event: InputEvent) -> void:
	#if event is InputEventMouseMotion and mouse_captured:
		#camera_pivot.rotation.y -= event.relative.x * mouse_sensitivity
		#
		#camera_pivot.rotation.x -= event.relative.y * mouse_sensitivity
		#
		#camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))
		
