extends Control

# Exporta um array para você arrastar as imagens lá no Inspetor
@export var background_images: Array[Texture2D] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# PROTEÇÃO: Garante que o jogo desongele se veio de uma partida pausada
	get_tree().paused = false
	
	# PROTEÇÃO: Força o mouse a ficar visível, ignorando qualquer comando do jogador antigo
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
  
# Pega a referência do TextureRect de fundo
@onready var bg_texture_rect: TextureRect = $Bg

func _ready() -> void:
	# Verifica se o array não está vazio para evitar erros
	if background_images.size() > 0:
		# Pega uma imagem aleatória da lista e aplica no TextureRect
		var random_bg = background_images.pick_random()
		bg_texture_rect.texture = random_bg

func _on_start_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://game/world/world.tscn")

func _on_credits_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://game/title_screen/credits/credits_screen.tscn")

func _on_quit_btn_pressed() -> void:
	get_tree().quit()
