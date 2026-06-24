extends Control

@export var background_images: Array[Texture2D] = []
@export var change_interval: float = 4.0 # Intervalo de troca das imagens em segundos
@export var fade_duration: float = 1.2 # Duração da transição fade-in/fade-out

@onready var bg_texture_rect: TextureRect = $Bg
# MUDANÇA AQUI: Trocamos $ por % para achar o nó em qualquer lugar da cena
@onready var fade_rect: ColorRect = $FadeRect 

var is_transitioning: bool = false
var current_bg_index: int = 0
var bg_fade_temp: TextureRect

func _ready() -> void:
	if fade_rect:
		# Começa o jogo 100% preto
		fade_rect.visible = true
		fade_rect.modulate.a = 1.0
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Revela o menu (Fade-in)
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 0.0, 0.8)
		# Só libera os botões quando terminar de clarear
		tween.tween_callback(func(): fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE)

	if background_images.size() > 0:
		var random_bg = background_images.pick_random()
		bg_texture_rect.texture = random_bg
		
		# Cria um TextureRect temporário para fazer o cross-fade (transição suave)
		bg_fade_temp = bg_texture_rect.duplicate() as TextureRect
		bg_fade_temp.name = "BgTemp"
		bg_fade_temp.modulate.a = 0.0
		# Insere ele logo acima do Bg principal, mas abaixo da interface de botões
		bg_texture_rect.get_parent().add_child(bg_fade_temp)
		bg_fade_temp.get_parent().move_child(bg_fade_temp, bg_texture_rect.get_index() + 1)
		
		current_bg_index = background_images.find(random_bg)
		if current_bg_index == -1:
			current_bg_index = 0
			
		_start_background_cycle()

func _start_background_cycle() -> void:
	if background_images.size() <= 1:
		return
		
	while true:
		await get_tree().create_timer(change_interval).timeout
		
		if not is_inside_tree() or is_transitioning:
			break
			
		# Seleciona a próxima imagem
		current_bg_index = (current_bg_index + 1) % background_images.size()
		var next_texture = background_images[current_bg_index]
		
		# Configura a textura temporária e inicia o fade-in dela
		bg_fade_temp.texture = next_texture
		bg_fade_temp.modulate.a = 0.0
		
		var tween = create_tween()
		tween.tween_property(bg_fade_temp, "modulate:a", 1.0, fade_duration)
		await tween.finished
		
		if not is_inside_tree() or is_transitioning:
			break
			
		# Quando terminar a transição, define a textura no Bg principal e reseta o temporário
		bg_texture_rect.texture = next_texture
		bg_fade_temp.modulate.a = 0.0

func _on_start_btn_pressed() -> void:
	if is_transitioning: return
	is_transitioning = true
	
	if fade_rect:
		# Bloqueia cliques repetidos cobrindo a tela
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var tween = create_tween()
		# Força a opacidade a voltar para 1.0 (Preto total) em 0.8 segundos
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
		
		# Comando mágico: o código vai pausar AQUI até o retângulo ficar totalmente preto
		await tween.finished
	
	# Só agora, com tudo escuro, a cena é trocada de forma invisível para o jogador
	get_tree().change_scene_to_file("res://game/cutscenes/CutsceneManager.tscn")
	if is_transitioning: return
	is_transitioning = true
	
	if fade_rect:
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Faz a tela escurecer suavemente (Fade-out)
		var tween = create_tween()
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.8)
		
		# Só muda de cena quando o Tween terminar 100%
		tween.tween_callback(func(): 
			get_tree().change_scene_to_file("res://game/cutscenes/CutsceneManager.tscn")
		)
	
	get_tree().change_scene_to_file("res://game/cutscenes/CutsceneManager.tscn")

func _on_credits_btn_pressed() -> void:
	if is_transitioning: return
	get_tree().change_scene_to_file("res://game/title_screen/credits/credits_screen.tscn")

func _on_quit_btn_pressed() -> void:
	if is_transitioning: return
	get_tree().quit()
