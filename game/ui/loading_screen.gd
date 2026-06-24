extends CanvasLayer

# tela de loading simples (overlay + spinner).
# e registrada como autoload (singleton global), por isso continua existindo
# mesmo quando a cena atual e troca da title_screen para a world.tscn --
# diferente de um node normal, que seria destruido na troca de cena.
#
# uso:
#   LoadingScreen.show_loading()              -- antes do change_scene_to_file
#   LoadingScreen.hide_loading()               -- quando o world terminar de gerar

@onready var label: Label = $CenterContainer/VBoxContainer/Label


func _ready() -> void:
	# e garantido que o overlay fique sempre acima de qualquer outra UI
	layer = 128
	visible = false


func show_loading(text: String = "Carregando...") -> void:
	if label:
		label.text = text
	visible = true


func hide_loading() -> void:
	visible = false
