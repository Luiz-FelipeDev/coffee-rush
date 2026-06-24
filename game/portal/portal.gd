extends Area3D

@onready var anim_player: AnimationPlayer = $"../AnimationPlayer"

func _ready() -> void:
	# é iniciada a animacao de cena assim que o portal nasce.
	if anim_player and anim_player.has_animation("Scene"):
		anim_player.play("Scene")
	
	# é conectado o sinal de colisao fisicamente via codigo.
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# é verificado se quem tocou no portal foi o jogador.
	if body.is_in_group("player"):
		var game_manager: Node = get_tree().get_first_node_in_group("game_manager")
		
		# é acionado o comando de avanco de dimensao no gerenciador.
		if game_manager and game_manager.has_method("advance_dimension"):
			game_manager.advance_dimension()
