extends Control

@export_group("Configurações")
@export var lista_criaturas: Array[CreatureData]
@export var slot_prefab: PackedScene # Arraste aqui o 'AtlasSlot.tscn'
@export var photobooth_scene: PackedScene # Arraste aqui o seu 'Photobooth.tscn'

@onready var grade_itens: GridContainer = $ScrollContainer/GradeItens

func _ready() -> void:
	generate_atlas()

func generate_atlas() -> void:
	# Instancia o gerador de fotos na árvore de forma invisível
	var photobooth = photobooth_scene.instantiate()
	add_child(photobooth)
	
	# Limpa a grade antes de gerar
	for child in grade_itens.get_children():
		child.queue_free()
		
	# Gera a foto e o slot para cada criatura configurada
	for creature in lista_criaturas:
		if creature.model_scene:
			# Aguarda o Photobooth gerar a textura
			var photo = await photobooth.take_snapshot(creature.model_scene, creature.isInverted)
			creature.snapshot_texture = photo
			
			# Cria o slot visual na interface
			var slot = slot_prefab.instantiate()
			grade_itens.add_child(slot)
			slot.setup(creature)
			
	# Remove o photobooth pois as fotos já estão salvas na RAM
	photobooth.queue_free()
