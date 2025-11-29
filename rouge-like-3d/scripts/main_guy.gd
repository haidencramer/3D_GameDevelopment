class_name Player extends CharacterBody3D

@export_range(1, 35, 1) var speed: float = 10
@export_range(10, 400, 1) var acceleration: float = 100
@export_range(0.1, 3.0, 0.1) var jump_height: float = 4.5
@export var turn_speed: float = 2.5
@export var mouse_sensitivity: float = 0.002
@export var pickup_range: float = 3.0

var jumping: bool = false
var mouse_captured: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var walk_vel: Vector3
var grav_vel: Vector3
var jump_vel: Vector3

# Weapon system
var held_weapon: Weapon = null
var nearby_weapons: Array[Weapon] = []

@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var anim_player: AnimationPlayer = $SpiderModel/spider/AnimationPlayer
@onready var spider_model: Node3D = $SpiderModel
@onready var hand_point: Node3D = $HandPoint
@onready var pickup_area: Area3D = $PickupArea

func _ready() -> void:
	capture_mouse()
	
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)
		var anim_library = anim_player.get_animation_library("")
		if anim_library:
			for anim_name in anim_library.get_animation_list():
				var animation = anim_library.get_animation(anim_name)
				if animation:
					animation.loop_mode = Animation.LOOP_LINEAR
	
	if pickup_area:
		pickup_area.body_entered.connect(_on_pickup_area_entered)
		pickup_area.body_exited.connect(_on_pickup_area_exited)

func _on_animation_finished(anim_name: String) -> void:
	if anim_player and anim_player.current_animation == anim_name:
		var is_moving = abs(Input.get_axis(&"move_down", &"move_up")) > 0.1
		if anim_name == "Armature|Walk" and is_moving:
			anim_player.play(anim_name)
		elif anim_name == "Armature|Idle" and not is_moving:
			anim_player.play(anim_name)
		elif anim_name == "Armature|Jump" and not is_on_floor():
			anim_player.play(anim_name)

#func _physics_process(delta: float) -> void:
	#if Input.is_action_just_pressed("jump") and is_on_floor():
		#jumping = true
	#
	#_handle_weapon_input()
	#_handle_turning(delta)
	#
	#velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	#_update_animation()
	#move_and_slide()
	
func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jumping = true
	
	# DEBUG: Test if E key is being detected at all
	if Input.is_key_pressed(KEY_E):
		print("E key detected!")
	
	# DEBUG: Check if pickup_weapon action exists
	if Input.is_action_just_pressed("pickup_weapon"):
		print("pickup_weapon action triggered!")
		print("Nearby weapons: ", nearby_weapons.size())
	
	_handle_weapon_input()
	_handle_turning(delta)
	
	velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	_update_animation()
	move_and_slide()
	


# -----------------------------
# WEAPON INPUT FIXED
# -----------------------------
#func _handle_weapon_input() -> void:
	#if Input.is_action_just_pressed("pickup_weapon"):
		#if held_weapon:
			#drop_weapon()
		#else:
			#pickup_nearest_weapon()
#
	#if Input.is_action_just_pressed("drop_weapon") and held_weapon:
		#drop_weapon()
		
func _handle_weapon_input() -> void:
	# Use direct key check instead of action
	if Input.is_key_pressed(KEY_E):
		if held_weapon:
			drop_weapon()
		else:
			pickup_nearest_weapon()
	
	if Input.is_action_just_pressed("drop_weapon") and held_weapon:
		drop_weapon()

#func pickup_nearest_weapon() -> void:
	#if nearby_weapons.is_empty():
		#print("No weapons nearby")
		#return
	#
	#var closest_weapon: Weapon = null
	#var closest_distance: float = INF
	#
	#for weapon in nearby_weapons:
		#if not is_instance_valid(weapon):
			#continue
		#
		#var distance = global_position.distance_to(weapon.global_position)
		#if distance < closest_distance:
			#closest_distance = distance
			#closest_weapon = weapon
	#
	#if closest_weapon and closest_distance <= pickup_range:
		#held_weapon = closest_weapon
		#held_weapon.pickup(self, hand_point)
		#print("Picked up: ", held_weapon.weapon_name)
		
func pickup_nearest_weapon() -> void:
	if nearby_weapons.is_empty():
		print("No weapons nearby")
		return
	
	# Just grab the first weapon in range (PickupArea already filtered by distance)
	var weapon_to_pickup = nearby_weapons[0]
	
	if is_instance_valid(weapon_to_pickup):
		held_weapon = weapon_to_pickup
		held_weapon.pickup(self, hand_point)
		nearby_weapons.erase(weapon_to_pickup)  # Remove from nearby list
		print("Picked up: ", held_weapon.weapon_name)

func drop_weapon() -> void:
	if held_weapon:
		held_weapon.drop()
		held_weapon = null
		print("Dropped weapon")

func _on_pickup_area_entered(body: Node3D) -> void:
	if body is Weapon:
		nearby_weapons.append(body)
		print("Weapon in range: ", body.weapon_name)

func _on_pickup_area_exited(body: Node3D) -> void:
	if body is Weapon:
		nearby_weapons.erase(body)
		print("Weapon out of range: ", body.weapon_name)

# ------ movement unchanged ------
func _handle_turning(delta: float) -> void:
	if Input.is_action_pressed(&"move_left"):
		spider_model.rotation.y += turn_speed * delta
	if Input.is_action_pressed(&"move_right"):
		spider_model.rotation.y -= turn_speed * delta
	camera_pivot.rotation.y = spider_model.rotation.y

func _walk(delta: float) -> Vector3:
	var forward_input = Input.get_axis(&"move_down", &"move_up")
	
	if forward_input != 0:
		var forward = -spider_model.transform.basis.z
		var walk_dir = forward.normalized()
		walk_vel = walk_vel.move_toward(walk_dir * speed * forward_input, acceleration * delta)
	else:
		walk_vel = walk_vel.move_toward(Vector3.ZERO, acceleration * delta)
	
	return walk_vel

func _update_animation() -> void:
	if not anim_player:
		return
	
	var current_anim = anim_player.current_animation
	var is_moving = abs(Input.get_axis(&"move_down", &"move_up")) > 0.1
	
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
