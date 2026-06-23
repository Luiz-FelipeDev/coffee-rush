# invisibility_effect.gd
extends ItemEffect
class_name InvisibilityEffect

func apply(player: Node) -> void:
	var status: StatusEffectManager = player.get_node_or_null("StatusEffectManager")
	if status:
		status.add_invisibility(duration)