class_name Player extends CharacterBody3D

@export_range(1, 35, 1) var speed: float = 10
@export_range(10, 400, 1) var acceleration: float = 100
@export_range(0.1, 3.0, 0.1) var jump_height: float = 4.5
@export var turn_speed: float = 2.5
@export var mouse_sensitivity: float = 0.002
@export var pickup_range: float = 35.0  # Increased to match scene distances
# Health variables
@export var max_health: float = 100.0
var current_health: float

# Reference to the health bar UI
var health_bar: ProgressBar

var jumping: bool = false
var backflipping: bool = false
var mouse_captured: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var walk_vel: Vector3
var grav_vel: Vector3
var jump_vel: Vector3

# Backflip parameters
@export var backflip_height: float = 6.0
@export var backflip_backward_force: float = 8.0
@export var backflip_rotation_speed: float = 720.0  # degrees per second

# Weapon system
var held_weapon: Weapon = null
var nearby_weapons: Array[Weapon] = []

@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var anim_player: AnimationPlayer = $SpiderModel/spider/AnimationPlayer
@onready var spider_model: Node3D = $SpiderModel
@onready var hand_point: Node3D = $SpiderModel/HandPoint
@onready var pickup_area: Area3D = $PickupArea

func _ready() -> void:
	# Initialize health
	current_health = max_health
	
	# Get reference to the health bar (assuming it's in a CanvasLayer)
	health_bar = get_node("/root/Main/CanvasLayer/Control/HealthBar")
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	capture_mouse()
	
	print("=== PLAYER READY ===")
	print("Hand point exists: ", hand_point != null)
	print("Pickup area exists: ", pickup_area != null)
	
	if anim_player:
		anim_player.animation_finished.connect(_on_animation_finished)
		var anim_library = anim_player.get_animation_library("")
		if anim_library:
			for anim_name in anim_library.get_animation_list():
				var animation = anim_library.get_animation(anim_name)
				if animation:
					animation.loop_mode = Animation.LOOP_LINEAR
	
	# Connect pickup area signals with debugging
	if pickup_area:
		print("Connecting pickup area signals...")
		pickup_area.body_entered.connect(_on_pickup_area_entered)
		pickup_area.body_exited.connect(_on_pickup_area_exited)
		
		# Check what's already in the area
		await get_tree().process_frame  # Wait one frame
		var bodies = pickup_area.get_overlapping_bodies()
		print("Bodies in pickup area at start: ", bodies.size())
		for body in bodies:
			print("  - ", body.name, " (", body.get_class(), ")")
			if body is Weapon:
				_on_pickup_area_entered(body)
	else:
		push_error("PickupArea not found!")

func _on_animation_finished(anim_name: String) -> void:
	if anim_player and anim_player.current_animation == anim_name:
		var is_moving = abs(Input.get_axis(&"move_down", &"move_up")) > 0.1
		if anim_name == "Armature|Walk" and is_moving:
			anim_player.play(anim_name)
		elif anim_name == "Armature|Idle" and not is_moving:
			anim_player.play(anim_name)
		elif anim_name == "Armature|Jump" and not is_on_floor():
			anim_player.play(anim_name)

func take_damage(damage: float):
	"""Called when the player takes damage"""
	current_health = max(0, current_health - damage)
	update_health_bar()
	
	# Optional: Add visual/audio feedback
	print("Player took ", damage, " damage. Health: ", current_health, "/", max_health)
	
	# Check if player is dead
	if current_health <= 0:
		die()

func heal(amount: float):
	"""Heal the player"""
	current_health = min(max_health, current_health + amount)
	update_health_bar()

func update_health_bar():
	"""Update the health bar UI"""
	if health_bar:
		health_bar.value = current_health

func die():
	"""Handle player death"""
	print("Player died!")
	# Add your death logic here (restart level, show game over screen, etc.)
	# For example:
	# get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jumping = true
	
	_handle_weapon_input()
	_handle_turning(delta)
	
	velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	_update_animation()
	move_and_slide()

func _handle_weapon_input() -> void:
	# E key - pickup weapon (or drop if holding one)
	if Input.is_action_just_pressed("pickup_weapon"):
		print("\n=== E KEY PRESSED ===")
		print("Currently holding weapon: ", held_weapon != null)
		print("Nearby weapons count: ", nearby_weapons.size())
		
		if held_weapon:
			drop_weapon()
		else:
			pickup_nearest_weapon()
	
	# Q key - drop weapon
	if Input.is_action_just_pressed("drop_weapon"):
		print("\n=== Q KEY PRESSED ===")
		if held_weapon:
			drop_weapon()
		else:
			print("Not holding any weapon to drop")

func pickup_nearest_weapon() -> void:
	print("Attempting to pick up weapon...")
	print("Nearby weapons: ", nearby_weapons.size())
	
	if nearby_weapons.is_empty():
		print("ERROR: No weapons nearby!")
		
		# Debug: manually check area
		if pickup_area:
			var bodies = pickup_area.get_overlapping_bodies()
			print("DEBUG: Bodies in area: ", bodies.size())
			for body in bodies:
				print("  - ", body.name, " is Weapon: ", body is Weapon)
		return
	
	# Find closest weapon
	var closest_weapon: Weapon = null
	var closest_distance: float = INF
	
	for weapon in nearby_weapons:
		if not is_instance_valid(weapon):
			print("Invalid weapon in list, skipping")
			continue
		
		if weapon.is_held:
			print("Weapon ", weapon.weapon_name, " is already held")
			continue
		
		var distance = global_position.distance_to(weapon.global_position)
		print("Weapon: ", weapon.weapon_name, " Distance: ", distance)
		
		if distance < closest_distance:
			closest_distance = distance
			closest_weapon = weapon
	
	# Pick it up if in range
	if closest_weapon:
		print("Closest weapon: ", closest_weapon.weapon_name, " at distance: ", closest_distance)
		
		if closest_distance <= pickup_range:
			held_weapon = closest_weapon
			held_weapon.pickup(self, hand_point)
			print("SUCCESS: Picked up ", held_weapon.weapon_name)
		else:
			print("ERROR: Weapon too far (", closest_distance, " > ", pickup_range, ")")
	else:
		print("ERROR: No valid weapon found")

func drop_weapon() -> void:
	if held_weapon:
		print("Dropping weapon: ", held_weapon.weapon_name)
		var dropped_weapon = held_weapon
		held_weapon = null
		dropped_weapon.drop()
		print("SUCCESS: Weapon dropped")

func _on_pickup_area_entered(body: Node3D) -> void:
	print("\n=== BODY ENTERED PICKUP AREA ===")
	print("Body name: ", body.name)
	print("Body class: ", body.get_class())
	print("Is Weapon: ", body is Weapon)
	
	if body is Weapon:
		var weapon = body as Weapon
		print("Weapon name: ", weapon.weapon_name)
		print("Is held: ", weapon.is_held)
		
		if not weapon.is_held and not nearby_weapons.has(weapon):
			nearby_weapons.append(weapon)
			print("SUCCESS: Added to nearby weapons. Total: ", nearby_weapons.size())
		else:
			print("Weapon already in list or is held")

func _on_pickup_area_exited(body: Node3D) -> void:
	print("\n=== BODY EXITED PICKUP AREA ===")
	print("Body name: ", body.name)
	
	if body is Weapon:
		nearby_weapons.erase(body)
		print("Removed from nearby weapons. Total: ", nearby_weapons.size())

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
	
func _process(_delta):
	if Input.is_action_just_pressed("ui_down"):
		take_damage(10)  # Test damage
	if Input.is_action_just_pressed("ui_up"):
		heal(10)  # Test healing
