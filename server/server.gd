extends Node

const PORT := 7777
const MAX_CLIENTS := 64
const MAX_LOBBIES := 1
const MAX_PLAYERS_PER_LOBBY := 2
const DISTANCE_BETWEEN_LOBBIES := 100

var peer := ENetMultiplayerPeer.new()
var lobbies : Array[Lobby] = []
var idle_clients : Array[int] = []
var lobby_spots : Array[Lobby] = []

func _ready() -> void:
	var error := peer.create_server(PORT, MAX_CLIENTS)
	
	if error != OK:
		print("Failed to start server")
		return
	
	print("Server started")
	
	multiplayer.multiplayer_peer = peer
	
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	
	lobby_spots.resize(MAX_LOBBIES)
	
func _on_peer_connected(id: int) -> void:
	idle_clients.append(id)
	print("Client %d connected to server" % id)

func _on_peer_disconnected(id: int) -> void:
	remove_client_from_lobby(id)
	idle_clients.erase(id)
	
	print("Client %d disconnected from server" % id)

func remove_client_from_lobby(client_id: int) -> void:
	var maybe_lobby = get_lobby_from_client_id(client_id)
	
	if maybe_lobby:
		maybe_lobby.remove_client(client_id)
		lobby_clients_updated(maybe_lobby)
		
		if maybe_lobby.clients.is_empty():
			lobbies.erase(maybe_lobby)
			maybe_lobby.queue_free()
			update_lobby_spots()
	
	print("Client %d disconnected from lobby" % client_id)

func update_lobby_spots() -> void:
	#Inserting new lobbies
	for lobby in lobbies:
		if lobby in lobby_spots:
			continue
		
		for i in lobby_spots.size():
			if lobby_spots[i] == null:
				lobby_spots[i] = lobby
				lobby.global_position.y = DISTANCE_BETWEEN_LOBBIES * i
				break
	
	#Deleting unused lobby spots
	for i in lobby_spots.size():
		if lobby_spots[i] != null and not lobby_spots[i] in lobbies:
			lobby_spots[i] = null

func get_lobby_from_client_id(id: int) -> Lobby:
	for lobby in lobbies:
		if lobby.clients.has(id):
			return lobby
			
	return null

#c_ means client calls this fucntion
@rpc("any_peer", "call_remote", "reliable")
func c_try_connect_client_to_lobby() -> void:
	var client_id := multiplayer.get_remote_sender_id()
	var maybe_lobby := get_non_full_lobby()
	
	if maybe_lobby:
		maybe_lobby.add_client(client_id)
		idle_clients.erase(client_id)
		lobby_clients_updated(maybe_lobby)
		
		if maybe_lobby.clients.size() >= MAX_PLAYERS_PER_LOBBY:
			lock_lobby(maybe_lobby)
		
		print("Client %d connected to lobby %s" %[client_id, maybe_lobby.name])
		return
		
	s_client_cant_connect_to_lobby.rpc_id(client_id)

func lock_lobby(lobby: Lobby) -> void:
	lobby.status = Lobby.LOCKED
	create_lobby_on_clients(lobby)

func create_lobby_on_clients(lobby: Lobby) -> void:
	for lobby_client_id in lobby.clients:
		s_create_lobby_on_clients.rpc_id(lobby_client_id, lobby.name)
@rpc("authority", "call_remote", "reliable")
func s_create_lobby_on_clients(lobby_name: String) -> void:
	pass

func get_non_full_lobby() -> Lobby:
	for lobby in lobbies:
		if lobby.status != Lobby.IDLE:
			continue
			
		if lobby.clients.size() < MAX_PLAYERS_PER_LOBBY:
			return lobby
			
	if lobbies.size() < MAX_LOBBIES:
		var new_lobby := Lobby.new()
		lobbies.append(new_lobby)
		new_lobby.name = str(new_lobby.get_instance_id())
		add_child(new_lobby)
		update_lobby_spots()
		return new_lobby
	
	print("Lobbies are full")
	return null

func lobby_clients_updated(lobby: Lobby) -> void:
	for client_id in lobby.clients:
		s_lobby_clients_updated.rpc_id(client_id, lobby.clients.size(), MAX_PLAYERS_PER_LOBBY)
@rpc("authority", "call_remote", "reliable")
func s_lobby_clients_updated(connected_clients: int, max_clients: int) -> void:
	pass

@rpc("authority", "call_remote", "reliable")
func s_client_cant_connect_to_lobby() -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func c_cancel_quickplay_search() -> void:
	var client_id := multiplayer.get_remote_sender_id()
	remove_client_from_lobby(client_id)
