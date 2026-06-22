class_name CreatureData
extends Resource

@export var creature_name: String = "Criatura Desconhecida"
@export var model_scene: PackedScene # Seu arquivo .glb ou .tscn do monstro
@export var is_discovered: bool = false
@export var dimension_id: String = "Dimensao_1"
@export var isInverted: bool = false
# Guardará a foto gerada pelo Photobooth na memória RAM
var snapshot_texture: Texture2D
