extends Resource
class_name ItemData

enum ItemType { PASSIVE, EQUIPMENT }

@export var item_id: StringName = ""
@export var display_name: String = ""
@export var item_type: ItemType = ItemType.PASSIVE
@export var effects: Array[ItemEffect] = []