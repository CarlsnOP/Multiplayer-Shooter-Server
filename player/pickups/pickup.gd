extends Node3D
class_name Pickup


enum PickupTypes {
	HealthPickup,
	GrenadePickup
}


@export var pickup_type := PickupTypes.HealthPickup
@export var cooldown_time := 10.0


@onready var cooldown_timer: Timer = %CooldownTimer


var lobby: Lobby
var is_picked := false


func _ready() -> void:
	cooldown_timer.wait_time = cooldown_time

func _on_area_3d_body_entered(player: PlayerServerReal) -> void:
	if is_picked:
		return
	
	match pickup_type:
		PickupTypes.HealthPickup:
			if player.current_health < player.MAX_HEALTH:
				player.change_health(75)
				
		PickupTypes.GrenadePickup:
			player.update_grenades_left(player.grenades_left + 1)
	
	picked_up(player)

func picked_up(player: PlayerServerReal) -> void:
	is_picked = true
	cooldown_timer.start()
	lobby.pickup_cooldown_started(name)
	lobby.play_pickup_fx(player.name.to_int(), pickup_type)

func _on_cooldown_timer_timeout() -> void:
	is_picked = false
	lobby.pickup_cooldown_ended(name)
