class_name CreatureData
extends Resource

@export var creature_name: String = "Criatura Desconhecida"
@export var model_scene: PackedScene 
@export var is_discovered: bool = false
@export var dimension_id: String = "Dimensao_1"
@export var is_inverted: bool = false
@export var entity_id: String = ""

# é armazenada a textura na memoria ram
var snapshot_texture: Texture2D

func get_valid_id() -> String:
	# é retornado o id inserido manualmente, caso exista
	if entity_id != "":
		return entity_id
		
	# é gerado o id automaticamente a partir do nome do arquivo da cena
	if model_scene != null:
		return model_scene.resource_path.get_file().get_basename()
		
	# é retornado um fallback de prevencao contra null pointers
	return "unknown_entity"
