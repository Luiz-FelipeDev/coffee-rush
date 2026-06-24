extends CanvasLayer

@export var text_list: Array[String] = ["Bem-vindo...", "Prepare-se.", "A jornada começa agora."]
@export var typing_speed: float = 0.05
@export var next_scene_path: String = "res://game/world/world.tscn"

@onready var label: Label = $Label
@onready var skip_label: Label = $SkipLabel
@onready var color_rect: ColorRect = $ColorRect

var current_text_index: int = 0
var is_skipping: bool = false

func _ready() -> void:
	color_rect.color = Color.BLACK
	color_rect.color.a = 1.0 
	
	_start_skip_label_pulse()
	_show_next_text()

func _start_skip_label_pulse() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(skip_label, "modulate:a", 0.3, 1.5)
	tween.tween_property(skip_label, "modulate:a", 0.8, 1.5)

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
		if is_skipping: return 
		label.text += character
		await get_tree().create_timer(typing_speed).timeout
	
	if is_skipping: return
	await get_tree().create_timer(2.0).timeout 
	current_text_index += 1
	_show_next_text()

func _finish_cutscene() -> void:
	if is_skipping: return
	is_skipping = true
	
	skip_label.hide()
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.tween_property(skip_label, "modulate:a", 0.0, 1.0)
	
	await tween.finished
	await get_tree().create_timer(1.5).timeout
	
	get_tree().change_scene_to_file(next_scene_path)
