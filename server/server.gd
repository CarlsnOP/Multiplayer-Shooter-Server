extends Node

const PORT := 7777
const MAX_CLIENTS := 64

var peer := ENetMultiplayerPeer.new()

func _ready() -> void:
	var error := peer.create_server(PORT, MAX_CLIENTS)
	
	if error != OK:
		print("Failed to start server")
		return
	
	print("Server started")
	
	multiplayer.multiplayer_peer = peer
	
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	
func _on_peer_connected(id: int) -> void:
	print("Client %d connected to server" % id)

func _on_peer_disconnected(id: int) -> void:
	print("Client %d disconnected from server" % id)
