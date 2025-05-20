extends Node3D
class_name Lobby


enum {
	IDLE,
	LOCKED,
	GAME
}


var status := IDLE
var clients : Array[int] = []
var ready_clients : Array[int] = []

func add_client(id: int) -> void:
	clients.append(id)

func remove_client(id: int) -> void:
	clients.erase(id)

@rpc("any_peer", "call_remote", "reliable")
func c_lock_client() -> void:
	var client_id := multiplayer.get_remote_sender_id()
	
	if not client_id in clients or client_id in ready_clients:
		return
	
	ready_clients.append(client_id)
	
	for maybe_ready_client in clients:
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
	
	if not client_id in clients or client_id in ready_clients:
		return
	
	ready_clients.append(client_id)
	
	for maybe_ready_client in clients:
		if not maybe_ready_client in ready_clients:
			return
	
	for ready_client_id in ready_clients:
		s_start_match.rpc_id(ready_client_id)
	
	ready_clients.clear()
	
@rpc("authority", "call_remote", "reliable")
func s_start_match() -> void:
	pass
	
	
	
	
