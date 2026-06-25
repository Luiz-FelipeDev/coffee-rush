extends CanvasLayer

@export var text_list: Array[String] = ["Bem-vindo...", "Prepare-se.", "A jornada começa agora."]
@export var typing_speed: float = 0.05
@export var next_scene_path: String = "res://game/level_01.tscn"

@onready var label: Label = $Label
@onready var skip_label: Label = $SkipLabel
@onready var color_rect: ColorRect = $ColorRect

var current_text_index: int = 0
var is_skipping: bool = false

func _ready() -> void:
	color_rect.color.a = 0.0 # Começa transparente
	_start_skip_label_pulse()
	_show_next_text()

# Faz o botão de pular pulsar na tela
func _start_skip_label_pulse() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(skip_label, "modulate:a", 0.3, 1.5)
	tween.tween_property(skip_label, "modulate:a", 0.8, 1.5)

# Captura o clique ou Enter para pular
func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("ui_accept") or event.is_action_pressed("LMB")) and not is_skipping:
		_finish_cutscene()

func _show_next_text() -> void:
	if current_text_index < text_list.size():
		_type_text(text_list[current_text_index])
	else:
		_finish_cutscene()

func _type_text(text: String) -> void:		
	label.text = ""
	for character in text:
		# Se pular no meio de uma palavra, interrompe o loop
		if is_skipping: return 
		label.text += character
		await get_tree().create_timer(typing_speed).timeout
	
	if is_skipping: return
	await get_tree().create_timer(1.0).timeout
	current_text_index += 1
	_show_next_text()

func _finish_cutscene() -> void:
	if is_skipping: return
	is_skipping = true
	
	# Esconde o aviso de skip imediatamente
	skip_label.hide()
	
	var tween = create_tween()
	# Transição de 1 segundo para preto
	tween.tween_property(color_rect, "color:a", 1.0, 1.0)
	await tween.finished
	
	# Troca de cena
	get_tree().change_scene_to_file(next_scene_path)