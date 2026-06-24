extends Control

@export_group("settings")
# banco de dados com todos os recursos do jogo. o menu vai filtrar automaticamente.
@export var creature_database: Array[CreatureData]
@export var slot_prefab: PackedScene 
@export var photobooth_scene: PackedScene 

@onready var left_grid: GridContainer = $HBoxContainer/GradeEsquerda
@onready var right_grid: GridContainer = $HBoxContainer/GradeDireita

var instanced_slots: Dictionary = {}
var player_ref: CharacterBody3D = null
var is_atlas_generated: bool = false

func _ready() -> void:
	# é iniciada a rotina de preparacao do atlas visual e conexao.
	_initialize_system()

func _initialize_system() -> void:
	# é aguardado um frame para garantir que o jogador ja foi instanciado.
	await get_tree().process_frame
	
	# é buscada a referencia do jogador dinamicamente usando grupos.
	player_ref = get_tree().get_first_node_in_group("player") as CharacterBody3D
	
	if player_ref:
		# é conectado o sinal do jogador de forma segura via codigo.
		player_ref.atlas_updated.connect(_on_atlas_updated)
		
		# é verificada a existencia de dados pre-carregados para gerar o atlas imediatamente.
		if player_ref.get("atlas_registry") and not player_ref.atlas_registry.is_empty():
			_on_atlas_updated(player_ref.atlas_registry)
	else:
		push_warning("AtlasMenu: player not found in group 'player'.")

func generate_atlas(valid_entities: Array) -> void:
	# é instanciado o gerador de fotos na arvore.
	var photobooth: Node = photobooth_scene.instantiate()
	add_child(photobooth)
	
	# sao limpas ambas as grades antes da insercao.
	for child in left_grid.get_children():
		child.queue_free()
	for child in right_grid.get_children():
		child.queue_free()
		
	var counter: int = 0
		
	for creature in creature_database:
		if creature.model_scene:
			var entity_id: String = creature.get_valid_id()
			
			# é verificado se a criatura do banco de dados pertence a fase atual.
			if not valid_entities.has(entity_id):
				continue
			
			# é aguardada a geracao da textura via photobooth.
			var photo: Texture2D = await photobooth.take_snapshot(creature.model_scene, creature.is_inverted)
			creature.snapshot_texture = photo
			
			# é instanciado o prefab do slot visual.
			var slot: Node = slot_prefab.instantiate()
			
			# é distribuida a instanciacao entre as folhas do atlas.
			if counter < 4:
				left_grid.add_child(slot)
			elif counter < 8:
				right_grid.add_child(slot)
			else:
				break
			
			# sao configuradas as informacoes base do slot.
			if slot.has_method("setup"):
				slot.setup(creature)
			
			# é forcado o estado inicial para oculto.
			if slot.has_method("set_discovered"):
				slot.set_discovered(false)
			
			# é armazenado o slot no dicionario usando a id exata.
			instanced_slots[entity_id] = slot
			counter += 1
			
	# é limpada a memoria destruindo o gerador de fotos.
	photobooth.queue_free()
	
	# é marcada a flag para evitar multiplas geracoes.
	is_atlas_generated = true

func _on_atlas_updated(registry: Dictionary) -> void:
	# é gerada a interface visual na primeira vez que o sinal é recebido.
	if not is_atlas_generated:
		await generate_atlas(registry.keys())
		
	# é iterado o dicionario recebido para atualizar os slots correspondentes.
	for entity_id in registry.keys():
		if instanced_slots.has(entity_id):
			var is_discovered: bool = registry[entity_id]
			var slot_visual: Node = instanced_slots[entity_id]
			
			# é acionada a revelacao visual caso a entidade esteja descoberta.
			if slot_visual.has_method("set_discovered"):
				slot_visual.set_discovered(is_discovered)
