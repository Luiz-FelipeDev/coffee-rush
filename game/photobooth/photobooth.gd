extends Node3D

@onready var viewport: SubViewport = $SubViewport
@onready var model_container: Node3D = $SubViewport/ModelContainer
@onready var camera: Camera3D = $SubViewport/Camera3D

# Adicionamos o parâmetro "is_inverted" com valor padrão falso
func take_snapshot(model_scene: PackedScene, is_inverted: bool = false) -> Texture2D:
	# 1. Limpa o container
	for child in model_container.get_children():
		child.queue_free()
		
	# 2. Instancia a criatura no container
	var model_instance = model_scene.instantiate()
	model_container.add_child(model_instance)
	
	# === NOVA PARTE: ROTAÇÃO ===
	if is_inverted:
		model_instance.rotation_degrees.y = 180.0
	else:
		model_instance.rotation_degrees.y = 0.0
	# ===========================
	
	if camera:
		camera.current = true
		
	# 3. Chama a nossa nova função baseada na sua ideia!
	enquadrar_ortogonal(model_instance)
	
	# 4. O TRUQUE DE MESTRE DA RENDERIZAÇÃO:
	# Ligamos a renderização para ALWAYS temporariamente
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Esperamos 0.1 segundos reais (dá tempo de sobra pra GPU carregar a malha e a luz)
	await get_tree().create_timer(0.1).timeout
	
	# 5. Captura a imagem gerada
	var img = viewport.get_texture().get_image()
	
	# Desligamos o viewport para economizar processamento
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	
	# 6. Converte para uma textura utilizável na UI
	var texture = ImageTexture.create_from_image(img)
	
	return texture

func enquadrar_ortogonal(model: Node3D) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	
	var total_aabb := AABB()
	var first_mesh := true
	
	var meshes = model.find_children("*", "MeshInstance3D", true, false)
	
	for mesh in meshes:
		if mesh is MeshInstance3D:
			# A Godot 4 permite multiplicar a posição do nó (Transform) pelo tamanho dele (AABB)
			# Isso garante que vamos achar o tamanho real mesmo que o braço seja filho do tronco, etc.
			var mesh_aabb = mesh.get_aabb()
			var transform = model.global_transform.affine_inverse() * mesh.global_transform
			var transformed_aabb = transform * mesh_aabb
			
			if first_mesh:
				total_aabb = transformed_aabb
				first_mesh = false
			else:
				total_aabb = total_aabb.merge(transformed_aabb)
				
	if not first_mesh:
		# Encontra o meio exato e o tamanho do monstro
		var centro = total_aabb.get_center()
		var tamanho_maximo = max(total_aabb.size.x, max(total_aabb.size.y, total_aabb.size.z))
		
		# O PULO DO GATO: Em vez de mover o monstro, movemos a câmera!
		# Colocamos a câmera 5 metros para trás, mas exatamente na altura do centro do monstro
		camera.global_position = Vector3(centro.x, centro.y, centro.z + 5.0)
		
		# Mandamos a câmera olhar fixamente para esse centro
		camera.look_at(centro)
		
		# Ajusta a lente com margem de segurança
		var margem_respiro = 1.3
		camera.size = max(tamanho_maximo * margem_respiro, 1.0)
	else:
		# Fallback de segurança se o monstro não tiver malha 3D
		camera.global_position = Vector3(0, 1, 5)
		camera.look_at(Vector3(0, 1, 0))
		camera.size = 2.0
