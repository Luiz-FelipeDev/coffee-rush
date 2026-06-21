class_name BiomeData
extends Resource

@export_group("visual parameters")
@export var grass_color: Color = Color("3b7d22")
@export var sand_color: Color = Color("d4c38e")
@export var water_color: Color = Color("0066cc")
@export var sky_top_color: Color = Color("388ce2") 
@export var sky_horizon_color: Color = Color("71b2f0") 

@export_group("flora")
@export var tree_scenes: Array[PackedScene]
