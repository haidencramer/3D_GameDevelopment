extends CharacterBody2D

@export var gravity: float = 1500.0
@export var jump_force: float = -600.0
@export var run_speed: float = 200.0
@export var slash_duration: float = 0.3

var is_ducking: bool = false
var is_slashing: bool = false
var lives: int = 3
var dead: bool = false

@onready var sprite = $AnimatedSprite2D
@onready var slash_timer = $Timer

# Audio references
@onready var jump_sfx = $"../Audio/JumpSFX"
@onready var duck_sfx = $"../Audio/DuckSFX"
@onready var slash_sfx = $"../Audio/SlashSFX"

signal player_hit(lives_left)
signal player_slash

func _ready():
	sprite.play("run")
	add_to_group("player")

func _physics_process(delta):
	if dead:
		return
	
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		if not is_ducking and not is_slashing:
			sprite.play("run")
	
	handle_input()
	move_and_slide()

func handle_input():
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_ducking:
		jump()
	elif Input.is_action_just_pressed("duck") and is_on_floor() and not is_slashing:
		duck()
	elif Input.is_action_just_pressed("slash") and not is_slashing:
		slash()

func jump():
	jump_sfx.play()
	velocity.y = jump_force
	sprite.play("jump")

func duck():
	duck_sfx.play()
	is_ducking = true
	sprite.play("duck")
	await get_tree().create_timer(0.6).timeout
	is_ducking = false
	sprite.play("run")

func slash():
	slash_sfx.play()
	is_slashing = true
	sprite.play("slash")
	emit_signal("player_slash")
	slash_timer.start(slash_duration)
	await slash_timer.timeout
	is_slashing = false
	sprite.play("run")

func take_damage():
	if dead:
		return
	
	lives -= 1
	emit_signal("player_hit", lives)
	
	if lives <= 0:
		die()

func die():
	dead = true
	set_physics_process(false)
	set_process(false)
	sprite.play("death")
	await sprite.animation_finished
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
