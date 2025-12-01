extends Node3D
#MainMultiScript.gd
const PLAYER_SCENE = preload("res://scenes/player.tscn")
@onready var arena = $Arena
@onready var spawn_points = $SpawnPoints
var players_spawned = {}
func _ready():
	print("=== MAIN SCENE READY ===")
	print("Multiplayer unique ID: ", multiplayer.get_unique_id())
	print("Is server: ", multiplayer.is_server())
	print("Connected peers: ", multiplayer.get_peers())

	# Connect multiplayer signals
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

	# Wait a frame for multiplayer to stabilize
	await get_tree().process_frame

	# Spawn all existing players (for late joiners)
	for id in multiplayer.get_peers():
		print("Spawning existing peer: ", id)
		spawn_player(id)

	# Spawn ourselves
	print("Spawning myself: ", multiplayer.get_unique_id())
	spawn_player(multiplayer.get_unique_id())
func _on_player_connected(id: int):
	print("New player connected: ", id)
	spawn_player(id)
func _on_player_disconnected(id: int):
	print("Player disconnected: ", id)
	if players_spawned.has(id):
		players_spawned[id].queue_free()
		players_spawned.erase(id)
func spawn_player(id: int):
	if players_spawned.has(id):
		print("WARNING: Player ", id, " already spawned!")
		return

	print("=== SPAWNING PLAYER === ", id)

	var player = PLAYER_SCENE.instantiate()
	player.name = str(id)

	# ✔️ IMPORTANT: Set authority BEFORE adding to tree
	player.set_multiplayer_authority(id)

	# ✔️ NOW add to scene
	arena.add_child(player)

	# ✔️ NOW you can set spawn transform
	player.global_position = get_spawn_position(players_spawned.size())

	players_spawned[id] = player

func get_spawn_position(index: int) -> Vector3:
	# Spread players out so they don't overlap
	var radius = 5.0
	var angle = (index * TAU) / 4.0
	return Vector3(cos(angle) * radius, 2.0, sin(angle) * radius)
