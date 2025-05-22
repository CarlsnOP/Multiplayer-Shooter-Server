extends Node3D
class_name Lobby


const WORLD_STATE_SEND_FRAME := 3


enum {
	IDLE,
	LOCKED,
	GAME
}


var status := IDLE
var client_data := {}
var ready_clients : Array[int] = []
var world_state := {"ps": {}, "t": 0} #ps = player state, t = time


func _ready() -> void:
	set_physics_process(false)

func _physics_process(delta) -> void:
	if Engine.get_physics_frames() % WORLD_STATE_SEND_FRAME == 0:
		
		world_state.t = floori(Time.get_unix_time_from_system() * 1000)
		
		for client_id in client_data.keys():
			s_send_world_state.rpc_id(client_id, world_state)

@rpc("authority", "call_remote", "unreliable_ordered")
func s_send_world_state(new_world_state: Dictionary) -> void:
	pass

func add_client(id: int, player_name: String) -> void:
	client_data[id] = {"display_name": player_name}

func remove_client(id: int) -> void:
	client_data.erase(id)

@rpc("any_peer", "call_remote", "reliable")
func c_lock_client() -> void:
	var client_id := multiplayer.get_remote_sender_id()
	
	if not client_id in client_data.keys() or client_id in ready_clients:
		return
	
	ready_clients.append(client_id)
	
	for maybe_ready_client in client_data.keys():
		if not maybe_ready_client in ready_clients:
			return
	
	start_loading_map()
	ready_clients.clear()
	
func start_loading_map() -> void:
	var map = load("res://maps/server_map.tscn").instantiate()
	map.name = "Map"
	add_child(map, true)
	
	for ready_client in ready_clients:
		s_start_loading_map.rpc_id(ready_client)
@rpc("authority", "call_remote", "reliable")
func s_start_loading_map() -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func c_map_ready() -> void:
	var client_id := multiplayer.get_remote_sender_id()
	
	if not client_id in client_data.keys() or client_id in ready_clients:
		return
	
	ready_clients.append(client_id)
	
	for maybe_ready_client in client_data.keys():
		if not maybe_ready_client in ready_clients:
			return
	
	for ready_client_id in ready_clients:
		s_start_weapon_selection.rpc_id(client_id)
	
	ready_clients.clear()
	
	#spawn_players()
	#
	#await get_tree().create_timer(1).timeout
	#
	#for ready_client_id in ready_clients:
		#s_start_match.rpc_id(ready_client_id)
	#
	#ready_clients.clear()
	#set_physics_process(true)

func spawn_players() -> void:
	var spawn_points := get_tree().get_nodes_in_group("SpawnPoints")
	var blue_spawn_points: Array[Node3D] = []
	var red_spawn_points: Array[Node3D] = []
	
	for spawn_point in spawn_points:
		if spawn_point.name.begins_with("Blue"):
			blue_spawn_points.append(spawn_point)
			
		elif spawn_point.name.begins_with("Red"):
			red_spawn_points.append(spawn_point)
	
	ready_clients.shuffle()
	
	for i in ready_clients.size():
		var team := 0
		var spawn_tform := Transform3D.IDENTITY
		
		if i % 2 == 0:
			team = 0
			spawn_tform = blue_spawn_points[0].transform
			blue_spawn_points.pop_front()
			
		else:
			team = 1
			spawn_tform = red_spawn_points[0].transform
			red_spawn_points.pop_front()
			
		var player: CharacterBody3D = preload("res://player/player_server.tscn").instantiate()
		player.name = str(ready_clients[i])
		player.global_transform = spawn_tform
		add_child(player, true)
		
		for ready_client_id in ready_clients:
			s_spawn_player.rpc_id(
			ready_client_id,
			ready_clients[i],
			spawn_tform,
			team,
			client_data.get(ready_clients[i]).display_name,
			client_data.get(ready_clients[i]).weapon_id,
			)

@rpc("authority", "call_remote", "reliable")
func s_spawn_player(client_id: int, spawn_tfrom: Transform3D, team: int, player_name: String, weapon_id: int) -> void:
	pass
	
@rpc("authority", "call_remote", "reliable")
func s_start_match() -> void:
	pass
	
@rpc("any_peer", "call_remote", "unreliable_ordered")
func c_send_player_state(player_state: Dictionary) -> void:
	world_state.ps[multiplayer.get_remote_sender_id()] = player_state

@rpc("authority", "call_remote", "reliable")
func s_start_weapon_selection() -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func c_weapon_selected(weapon_id: int) -> void:
	var client_id := multiplayer.get_remote_sender_id()
	
	if not client_id in client_data.keys() or client_id in ready_clients:
		return
	
	ready_clients.append(client_id)
	client_data[client_id].weapon_id = weapon_id
	
	for maybe_ready_client in client_data.keys():
		if not maybe_ready_client in ready_clients:
			return
	
	spawn_players()
	
	await get_tree().create_timer(1).timeout
	
	for ready_client_id in ready_clients:
		s_start_match.rpc_id(ready_client_id)
	
	ready_clients.clear()
	set_physics_process(true)

@rpc("any_peer", "call_remote", "unreliable")
func c_shot_fired(time_stamp: int, player_data: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	
	for client_id in client_data.keys():
		if client_id != sender_id:
			s_play_shoot_fx.rpc_id(client_id, sender_id)

@rpc("authority", "call_remote", "unreliable")
func s_play_shoot_fx(target_client_id: int) -> void:
	pass
