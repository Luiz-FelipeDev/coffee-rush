# speed_boost_effect.gd
extends ItemEffect
class_name SpeedBoostEffect

@export var bonus_multiplier: float = 0.5  # +50% de velocidade

func apply(player: Node) -> void:
	var status: StatusEffectManager = player.get_node_or_null("StatusEffectManager")
	if status:
		status.add_speed_bonus(bonus_multiplier, duration)
