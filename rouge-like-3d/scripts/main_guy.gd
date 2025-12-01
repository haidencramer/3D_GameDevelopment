class_name Player extends CharacterBody3D

@export_range(1, 35, 1) var speed: float = 10
@export_range(10, 400, 1) var acceleration: float = 100
@export_range(0.1, 3.0, 0.1) var jump_height: float = 4.5
@export var turn_speed: float = 2.5
@export var mouse_sensitivity: float = 0.002
@export var pickup_range: float = 35.0

# Health variables
@export var max_health: float = 100.0
var current_health: float

# Reference to the health bar UI
var health_bar: ProgressBar

var jumping: bool = false
var backflipping: bool = false
var mouse_captured: bool = false
var is_dead: bool = false

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var walk_vel: Vector3
var grav_vel: Vector3
var jump_vel: Vector3

# Backflip parameters
@export var backflip_height: float = 6.0
@export var backflip_backward_force: float = 8.0
@export var backflip_rotation_speed: float = 720.0

# Weapon system
var held_weapon: Weapon = null
var nearby_weapons: Array[Weapon] = []

@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var anim_player: AnimationPlayer = $SpiderModel/spider/AnimationPlayer
@onready var spider_model: Node3D = $SpiderModel
@onready var hand_point: Node3D = $SpiderModel/HandPoint
@onready var pickup_area: Area3D = $PickupArea

func _enter_tree() -> void:
	# Camera must be corrected once authority is finalized
	call_deferred("_apply_camera_state")

func _ready() -> void:
	# Initialize health
	current_health = max_health
	
	# Get reference to the health bar (only for local player)
	if is_multiplayer_authority():
		health_bar = get_node("/root/LevelComplete/CanvasLayer/Control/HealthBar")
		if health_bar:
			health_bar.max_value = max_health
			health_bar.value = current_health
	
	# CRITICAL: Set player collision layers correctly
	collision_layer = 1
	collision_mask = 1
	
	print("=== PLAYER READY ===")
	print("Player ID: ", name)
	print("Is my authority: ", is_multiplayer_authority())
	print("Camera active: ", camera.current if camera else false)
	print("Player collision layer: ", collision_layer)
	print("Player collision mask: ", collision_mask)
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
	
	# Only connect pickup signals for YOUR player
	if is_multiplayer_authority() and pickup_area:
		print("Connecting pickup area signals...")
		pickup_area.body_entered.connect(_on_pickup_area_entered)
		pickup_area.body_exited.connect(_on_pickup_area_exited)
		
		# Check what's already in the area
		await get_tree().process_frame
		var bodies = pickup_area.get_overlapping_bodies()
		print("Bodies in pickup area at start: ", bodies.size())
		for body in bodies:
			print("  - ", body.name, " (", body.get_class(), ")")
			if body is Weapon:
				_on_pickup_area_entered(body)
	elif not pickup_area:
		push_error("PickupArea not found!")
	
	call_deferred("_apply_camera_state")

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
	if is_dead:
		return
	
	current_health = max(0, current_health - damage)
	update_health_bar()
	
	print("Player took ", damage, " damage. Health: ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func heal(amount: float):
	"""Heal the player"""
	if is_dead:
		return
	
	current_health = min(max_health, current_health + amount)
	update_health_bar()
	print("Player healed ", amount, ". Health: ", current_health, "/", max_health)

func update_health_bar():
	"""Update the health bar UI"""
	if health_bar:
		health_bar.value = current_health

func die():
	"""Handle player death"""
	if is_dead:
		return
	
	is_dead = true
	print("========== PLAYER DIED ==========")
	print("Current health: ", current_health)
	
	# Disable player control during death
	set_physics_process(false)
	
	# Drop weapon if holding one
	if held_weapon:
		drop_weapon()
	
	# Check if animation exists and play it
	if anim_player.has_animation("Armature|Death1"):
		print("Playing death animation: Armature|Death1")
		anim_player.play("Armature|Death1")
		await anim_player.animation_finished
		print("Death animation finished")
	else:
		push_error("Death animation 'Armature|Death1' not found!")
		print("Available animations:")
		var anim_library = anim_player.get_animation_library("")
		if anim_library:
			for anim_name in anim_library.get_animation_list():
				print("  - ", anim_name)
	
	# Wait a moment before restarting
	await get_tree().create_timer(2.0).timeout
	
	# Restart the level
	print("Reloading scene...")
	get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	
	if Input.is_action_just_pressed("jump") and is_on_floor():
		jumping = true
	
	_handle_weapon_input()
	_handle_turning(delta)
	
	velocity = _walk(delta) + _gravity(delta) + _jump(delta)
	_update_animation()
	move_and_slide()
	
	if is_multiplayer_authority():
		rpc("sync_transform", global_position, rotation)

@rpc("unreliable")
func sync_transform(pos: Vector3, rot: Vector3):
	if not is_multiplayer_authority():
		global_position = pos
		rotation = rot

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
	if not anim_player or is_dead:
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

func _apply_camera_state():
	if not camera:
		return

	if is_multiplayer_authority():
		print("I own this player. Activating my camera.")
		camera.make_current()
		capture_mouse()
	else:
		print("Not my player. Disabling this camera.")
		camera.current = false

# TESTING FUNCTIONS - Press keys to test death system
func _process(_delta):
	if not is_multiplayer_authority():
		return
	
	if Input.is_action_just_pressed("ui_down"):
		print("\n[TEST] Taking 10 damage")
		take_damage(10)
	
	if Input.is_action_just_pressed("ui_up"):
		print("\n[TEST] Healing 10 HP")
		heal(10)
	
	if Input.is_key_pressed(KEY_P):  
		print("\n[TEST] Forcing death")
		die()
