# strength_effect.gd
extends ItemEffect
class_name StrengthEffect

@export var bonus_multiplier: float = 1.0  # +100% de dano

func apply(player: Node) -> void:
	var status: StatusEffectManager = player.get_node_or_null("StatusEffectManager")
	if status:
		status.add_damage_bonus(bonus_multiplier, duration)