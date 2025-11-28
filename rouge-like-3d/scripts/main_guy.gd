class_name Player extends CharacterBody3D

@export var speed: float = 10.0
@export var turn_speed: float = 2.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var mouse_captured: bool = false

@onready var camera_pivot: Node3D = $CameraPivot
@onready var anim_player: AnimationPlayer = $SpiderModel/spider/AnimationPlayer

func _ready() -> void:
	# DON'T capture mouse for now - let's test without it
	# capture_mouse()
	
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)
		var anim_library = anim_player.get_animation_library("")
		if anim_library:
			for anim_name in anim_library.get_animation_list():
				var animation = anim_library.get_animation(anim_name)
				if animation:
					animation.loop_mode = Animation.LOOP_LINEAR

func _on_animation_finished(anim_name: String) -> void:
	if anim_player:
		anim_player.play(anim_name)

func _physics_process(delta: float) -> void:
	# Use direct key detection instead of input actions
	var key_w = Input.is_key_pressed(KEY_W)
	var key_s = Input.is_key_pressed(KEY_S)
	var key_a = Input.is_key_pressed(KEY_A)
	var key_d = Input.is_key_pressed(KEY_D)
	
	print("Keys: W=", key_w, " S=", key_s, " A=", key_a, " D=", key_d)
	
	# === ROTATION with A and D ===
	if key_a:
		rotation.y += turn_speed * delta
		print("ROTATING LEFT")
	
	if key_d:
		rotation.y -= turn_speed * delta
		print("ROTATING RIGHT")
	
	# === MOVEMENT with W and S ===
	var move_direction = Vector3.ZERO
	
	if key_w:
		move_direction = -global_transform.basis.z
		print("MOVING FORWARD")
	
	if key_s:
		move_direction = global_transform.basis.z
		print("MOVING BACKWARD")
	
	# Apply movement
	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	# Jump
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = sqrt(4 * 1.0 * gravity)
	
	# Update animations
	var is_moving = move_direction != Vector3.ZERO
	_update_animation(is_moving)
	
	move_and_slide()

func _update_animation(is_moving: bool) -> void:
	if not anim_player:
		return
	
	var current_anim = anim_player.current_animation
	
	if not is_on_floor():
		if anim_player.has_animation("Armature|Jump") and current_anim != "Armature|Jump":
			anim_player.play("Armature|Jump")
	elif is_moving:
		if anim_player.has_animation("Armature|Walk") and current_anim != "Armature|Walk":
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
