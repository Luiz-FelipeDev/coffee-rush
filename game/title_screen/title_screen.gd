extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# PROTEÇÃO: Garante que o jogo desongele se veio de uma partida pausada
	get_tree().paused = false
	
	# PROTEÇÃO: Força o mouse a ficar visível, ignorando qualquer comando do jogador antigo
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_btn_pressed() -> void:
	LoadingScreen.show_loading()
	get_tree().change_scene_to_file("res://game/world/world.tscn")


func _on_quit_btn_pressed() -> void:
	get_tree().quit()


func _on_credits_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://game/title_screen/credits/credits_screen.tscn")
