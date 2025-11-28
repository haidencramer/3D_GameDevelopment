extends Node3D

@export var float_height: float = 2.0        
@export var float_speed: float = 10.0          
@export var base_offset: float = 1.0          

var _time := 0.0
var _start_position := Vector3.ZERO

func _ready():
	_start_position = global_position

func _process(delta):
	_time += delta * float_speed
	var float_offset = sin(_time) * float_height
	global_position.y = _start_position.y + base_offset + float_offset
