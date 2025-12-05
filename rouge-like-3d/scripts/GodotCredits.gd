# res://scripts/Credits.gd
extends Control

const section_time := 2.0
const line_time := 0.3
const base_speed := 100
const speed_up_multiplier := 10.0
const title_color := Color.RED
var scroll_speed := base_speed
var speed_up := false
@onready var line := $CreditsContainer/Line
@onready var credits_container := $CreditsContainer
var started := false
var finished := false
var section
var section_next := true
var section_timer := 0.0
var line_timer := 0.0
var curr_line := 0
var lines := []
var credits = [
	[
		"A game by:",
		"",
		"Haiden Cramer",
		"",
		"Logan Boyer",
		"",
		"Eric Frazer",
		"",
		"JD Bennett",
	],[
		"Programming",
		"",
		"Haiden Cramer",
		"",
		"Logan Boyer",
		"",
		"Eric Frazer",
		"",
		"JD Bennett",
	],[
		"Assets",
		"",
		"Village:",
		"Fertil Soil Productions",
		"",
		"trees:",
		"Elegant Crow",
		"",
	],[
		"Tools used",
		"",
		"Developed with Godot Engine",
		"",
		"https://godotengine.org/license",
	],[
		"Special thanks",
		"",
		"Sam Luther",
	]
]

func _ready():
	# Hide the template line
	line.visible = false
	
	# Find and play spider animation
	var spider = $Node3D/spider
	if spider:
		var anim_player = spider.get_node_or_null("AnimationPlayer")
		if anim_player and anim_player.has_animation("Armature|Walk"):
			anim_player.play("Armature|Walk")
			print("Spider animation started")
	
	# Start at bottom of screen
	var viewport_height = get_viewport().get_visible_rect().size.y
func _process(delta):
	var current_scroll_speed = base_speed * delta
	
	if section_next:
		section_timer += delta * speed_up_multiplier if speed_up else delta
		if section_timer >= section_time:
			section_timer -= section_time
			
			if credits.size() > 0:
				started = true
				section = credits.pop_front()
				curr_line = 0
				add_line()
	else:
		line_timer += delta * speed_up_multiplier if speed_up else delta
		if line_timer >= line_time:
			line_timer -= line_time
			add_line()
	
	if speed_up:
		current_scroll_speed *= speed_up_multiplier
	
	if lines.size() > 0:
		for l in lines:
			l.position.y -= current_scroll_speed
			# Remove lines that scroll off the top
			if l.position.y < -100:
				lines.erase(l)
				l.queue_free()
	elif started:
		finish()

func finish():
	if not finished:
		finished = true
		get_tree().change_scene_to_file("res://scenes/MainMenuUI.tscn")

func add_line():
	var new_line = line.duplicate()
	new_line.visible = true
	new_line.text = section.pop_front()
	
	# Position at bottom of screen
	var viewport_height = get_viewport().get_visible_rect().size.y
	new_line.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 100, viewport_height)
	
	lines.append(new_line)
	
	if curr_line == 0:
		new_line.add_theme_color_override("font_color", title_color)
	
	credits_container.add_child(new_line)
	
	if section.size() > 0:
		curr_line += 1
		section_next = false
	else:
		section_next = true

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		finish()
	if event.is_action_pressed("ui_down") and !event.is_echo():
		speed_up = true
	if event.is_action_released("ui_down") and !event.is_echo():
		speed_up = false
