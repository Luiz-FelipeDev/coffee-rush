extends Control

@export var background_images: Array[Texture2D] = []

@onready var bg_texture_rect: TextureRect = $Bg
# MUDANÇA AQUI: Trocamos $ por % para achar o nó em qualquer lugar da cena
@onready var fade_rect: ColorRect = %FadeRect 

var is_transitioning: bool = false

func _ready() -> void:
	if fade_rect:
		fade_rect.color = Color.BLACK
		fade_rect.color.a = 1.0
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 0.0, 0.8)
		await tween.finished
		
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if background_images.size() > 0:
		var random_bg = background_images.pick_random()
		bg_texture_rect.texture = random_bg

func _on_start_btn_pressed() -> void:
	if is_transitioning: return
	is_transitioning = true
	
	# Proteção extra: só mexe no filtro se o fade_rect realmente existir
	if fade_rect:
		fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var tween = create_tween()
		tween.tween_property(fade_rect, "color:a", 1.0, 0.8)
		await tween.finished
	
	get_tree().change_scene_to_file("res://game/cutscenes/CutsceneManager.tscn")

func _on_credits_btn_pressed() -> void:
	if is_transitioning: return
	get_tree().change_scene_to_file("res://game/title_screen/credits/credits_screen.tscn")

func _on_quit_btn_pressed() -> void:
	if is_transitioning: return
	get_tree().quit()
