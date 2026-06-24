extends ItemEffect
class_name HealEffect

## Valor de cura fixo
@export var heal_amount: int = 25

func apply(player: Node) -> void:
	var status: StatusEffectManager = player.get_node_or_null("StatusEffectManager")
	if status:
		status.heal(heal_amount)
