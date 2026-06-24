extends VBoxContainer

@onready var foto_rect: TextureRect = $Foto
@onready var nome_label: Label = $NomeLabel

# é armazenada a referencia do recurso para uso dinamico
var slot_data: CreatureData

func setup(data: CreatureData) -> void:
	slot_data = data
	
	# é definida a foto gerada previamente pelo photobooth
	foto_rect.texture = slot_data.snapshot_texture
	
	# é forçada a atualizacao inicial baseada no status atual do dado
	set_discovered(slot_data.is_discovered)

func set_discovered(is_discovered: bool) -> void:
	if is_discovered:
		# é revelada a foto em cores originais e o nome real
		nome_label.text = slot_data.creature_name
		foto_rect.modulate = Color.WHITE
	else:
		# é ocultada a informacao gerando uma silhueta
		nome_label.text = "?"
		foto_rect.modulate = Color.BLACK
