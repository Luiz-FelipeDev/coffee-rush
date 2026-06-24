extends CanvasLayer

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	# Esconde o menu assim que o jogo começa
	hide()
	
	# Conecta os sinais de clique dos botões às funções
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Pega a referência da cena que está ativa na tela no momento
		var current_scene = get_tree().current_scene
		
		# Garante que a cena existe e checa se o caminho do arquivo dela termina com "world.tscn"
		if current_scene and current_scene.scene_file_path.ends_with("world.tscn"):
			toggle_pause()

func toggle_pause() -> void:
	var is_paused: bool = not get_tree().paused
	get_tree().paused = is_paused
	
	# Busca o nó do jogador na fase atual
	var player: Node = get_tree().get_first_node_in_group("player")
	
	if is_paused:
		show() # Mostra o menu de pausa
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# O "radar": Encontra tudo que for de interface (Control) dentro do jogador e esconde
		if player:
			for ui_element in player.find_children("*", "Control"):
				ui_element.hide()
				
	else:
		hide() # Esconde o menu de pausa
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
		# O "radar": Encontra a interface do jogador de novo e mostra na tela
		if player:
			for ui_element in player.find_children("*", "Control"):
				ui_element.show()

# ==========================================
# FUNÇÕES DOS BOTÕES
# ==========================================

func _on_resume_pressed() -> void:
	# Simplesmente chama a função de alternar, que vai despausar e esconder o menu
	toggle_pause()

func _on_restart_pressed() -> void:
	# 1. Garante que o motor do jogo saia do estado de pausa
	get_tree().paused = false
	
	# 2. Esconde o menu global da tela
	hide()
	
	# 3. Prende o mouse novamente para o controlador 3D funcionar
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 4. Recarrega a fase
	get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Garante que a mira suma antes de voltar para o menu principal
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		for ui_element in player.find_children("*", "Control"):
			ui_element.hide()
			
	get_tree().change_scene_to_file("res://game/title_screen/title_screen.tscn")

func _on_quit_pressed() -> void:
	# Encerra o jogo e fecha a janela
	get_tree().quit()
