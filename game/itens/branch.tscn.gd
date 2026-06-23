#branch.tscn.gd

extends Area3D

var _is_collected: bool = false

func _ready() -> void:
	# Connects the collision signal dynamically
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return
		
	# Checks if the colliding body belongs to the player group
	if body.is_in_group("player"):
		_is_collected = true
		
		# Calls the equip function if it exists on the player
		if body.has_method("equip_branch"):
			body.equip_branch()
		
		# Removes the item from the ground
		queue_free()