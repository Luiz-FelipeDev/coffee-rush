extends Area3D

func _on_body_entered(body: Node3D) -> void:
	# TEXTO DE TESTE: Se a física estiver funcionando, isso VAI aparecer no console
	print("📢 Algo atravessou o portal! Nome do objeto: ", body.name)
	
	# Verifica se quem encostou na porta pertence ao grupo do jogador
	if body.is_in_group("player"):
		print("🌀 Entrando no portal! Gerando nova ilha...")
		get_tree().change_scene_to_file("res://game/world/world.tscn")
