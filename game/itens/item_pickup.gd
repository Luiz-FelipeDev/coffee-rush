extends Area3D

signal item_collected(item_id: StringName)

@export var item_data: ItemData

var _collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if _collected or not body.is_in_group("player") or not item_data:
		return

	_collected = true
	set_deferred("monitoring", false)

	item_collected.emit(item_data.item_id)

	# Route item usage based on type classification
	if item_data.item_type == ItemData.ItemType.EQUIPMENT:
		if body.has_method("equip_item"):
			body.equip_item(item_data)
	else:
		for effect: ItemEffect in item_data.effects:
			if effect:
				effect.apply(body)

	_remove_item()

func _remove_item() -> void:
	var root: Node = owner if owner else self
	root.queue_free()