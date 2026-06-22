extends VBoxContainer

@onready var foto_rect: TextureRect = $Foto
@onready var nome_label: Label = $NomeLabel

func setup(data: CreatureData) -> void:
	# Define a foto que o Photobooth gerou
	foto_rect.texture = data.snapshot_texture
	
	if data.is_discovered:
		nome_label.text = data.creature_name
		# Volta a foto para a cor original (Branco = sem alteração)
		foto_rect.modulate = Color.WHITE
	else:
		nome_label.text = "???"
		# Transforma a foto em uma silhueta (Pinta tudo de preto)
		foto_rect.modulate = Color.BLACK
