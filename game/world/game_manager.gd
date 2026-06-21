extends Node

@export var player_scene: PackedScene
@export var terrain_generator: MeshInstance3D
@export var world_environment: WorldEnvironment 
@export var spawn_height_offset: float = 10.0

@export_group("biome configuration")
@export var current_biome: BiomeData

@export_group("surface generation rules")
@export var min_spawn_height: float = 12.0 
@export var max_slope_angle: float = 0.8 
@export var minimum_prop_spacing: float = 4.5 

@export_group("flora generation")
@export var tree_count: int = 150
@export var min_tree_scale: float = 0.8
@export var max_tree_scale: float = 2.5

@export_group("surface rocks generation")
@export var surface_rock_scenes: Array[PackedScene]
@export var surface_rock_count: int = 40
@export var min_surface_scale: float = 0.5
@export var max_surface_scale: float = 1.5

@export_group("floating clusters generation")
@export var floating_rock_scenes: Array[PackedScene]
@export var floating_cluster_count: int = 6
@export var max_floating_spawn_radius: float = 80.0
@export var rocks_per_cluster: int = 4
@export var cluster_radius: float = 15.0
@export var min_floating_height: float = 40.0
@export var max_floating_height: float = 80.0
@export var min_floating_scale: float = 2.0
@export var max_floating_scale: float = 8.0

@export_group("enemy generation")
@export var enemy_scene: PackedScene
@export var enemy_count: int = 120
@export var enemy_min_distance_from_player: float = 25.0

@export_subgroup("randomization control")
@export var world_seed: int = 98765

func _ready() -> void:
	# é verificada a dependência do gerador de terreno
	if terrain_generator:
		# são transferidas as propriedades visuais do bioma antes da execução
		if current_biome:
			terrain_generator.grass_color = current_biome.grass_color
			terrain_generator.sand_color = current_biome.sand_color
			
			if world_environment and world_environment.environment and world_environment.environment.sky:
				var sky_mat: ProceduralSkyMaterial = world_environment.environment.sky.sky_material as ProceduralSkyMaterial
				if sky_mat:
					sky_mat.sky_top_color = current_biome.sky_top_color
					sky_mat.sky_horizon_color = current_biome.sky_horizon_color

		# é conectado o sinal e iniciada a geração
		terrain_generator.terrain_generated.connect(_on_terrain_generated)
		terrain_generator.generate_terrain()

func _on_terrain_generated() -> void:
	# é aguardado um frame físico para registro global
	await get_tree().physics_frame
	
	# é instanciado o gerador de números local
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed
	
	# é criado o registro espacial para impedir sobreposição de objetos
	var occupied_positions: Array[Vector3] = []
	
	# é garantida a geração da flora apenas se houver bioma definido
	if current_biome:
		spawn_surface_props(rng, current_biome.tree_scenes, tree_count, min_tree_scale, max_tree_scale, occupied_positions)
		
	# são gerados os elementos globais na mesma lista de verificação de espaço
	spawn_surface_props(rng, surface_rock_scenes, surface_rock_count, min_surface_scale, max_surface_scale, occupied_positions)
	spawn_floating_rocks(rng)
	
	# é gerado o jogador por último
	spawn_player()

	# são gerados os inimigos após o jogador, para que seja possível
	# garantir uma distância mínima segura entre eles e o ponto de spawn
	spawn_enemies(rng, occupied_positions)

func spawn_surface_props(rng: RandomNumberGenerator, prop_scenes: Array[PackedScene], count: int, min_scale: float, max_scale: float, occupied_positions: Array[Vector3]) -> void:
	# é evitada a execução de listas vazias
	if prop_scenes.is_empty() or count <= 0:
		return

	# é acessado o espaço físico 3d através do terreno
	var space_state: PhysicsDirectSpaceState3D = terrain_generator.get_world_3d().direct_space_state
	var half_size: float = terrain_generator.island_size / 2.0
	var max_height: float = terrain_generator.height_multiplier + 20.0

	var props_planted: int = 0
	var attempts: int = 0
	
	# são aumentadas as tentativas para compensar a validação de espaço rigorosa
	var max_attempts: int = count * 15 

	# é executado o laço de posicionamento no solo
	while props_planted < count and attempts < max_attempts:
		attempts += 1

		var rand_x: float = rng.randf_range(-half_size, half_size)
		var rand_z: float = rng.randf_range(-half_size, half_size)

		var ray_origin: Vector3 = Vector3(rand_x, max_height, rand_z)
		var ray_end: Vector3 = Vector3(rand_x, -50.0, rand_z)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result: Dictionary = space_state.intersect_ray(query)

		if result:
			var hit_position: Vector3 = result["position"]
			var hit_normal: Vector3 = result["normal"]

			if hit_position.y >= min_spawn_height and hit_normal.dot(Vector3.UP) >= max_slope_angle:
				
				# é verificada a distância horizontal para todos os objetos já plantados
				var hit_pos_2d: Vector2 = Vector2(hit_position.x, hit_position.z)
				var is_too_close: bool = false
				
				for pos in occupied_positions:
					var occupied_pos_2d: Vector2 = Vector2(pos.x, pos.z)
					if hit_pos_2d.distance_to(occupied_pos_2d) < minimum_prop_spacing:
						is_too_close = true
						break
				
				# é ignorado o local caso esteja muito perto de outro objeto
				if is_too_close:
					continue

				var random_scene: PackedScene = prop_scenes.pick_random()
				var prop_instance: Node3D = random_scene.instantiate()

				add_child(prop_instance)
				prop_instance.global_position = hit_position
				prop_instance.quaternion = Quaternion(Vector3.UP, hit_normal)
				prop_instance.rotate_object_local(Vector3.UP, rng.randf_range(0.0, TAU))

				# é sorteada e aplicada a escala independente da superfície
				var random_scale: float = rng.randf_range(min_scale, max_scale)
				prop_instance.scale = Vector3(random_scale, random_scale, random_scale)

				# é registrado o local validado para impedir sobreposição
				occupied_positions.append(hit_position)
				props_planted += 1

func spawn_floating_rocks(rng: RandomNumberGenerator) -> void:
	# é evitada a execução se não houver modelos aéreos configurados
	if floating_rock_scenes.is_empty() or floating_cluster_count <= 0:
		return

	# é obtida a altura máxima absoluta do terreno para servir como base do céu
	var base_sky_height: float = terrain_generator.height_multiplier

	# é executado o laço para criação de clusters confinados a uma área circular central
	for i: int in range(floating_cluster_count):
		
		# é sorteado um ângulo de direção em radianos
		var angle: float = rng.randf_range(0.0, TAU)
		
		# é calculada a distância radial compensando a área com raiz quadrada para evitar aglomeração
		var distance: float = sqrt(rng.randf_range(0.0, 1.0)) * max_floating_spawn_radius
		
		# são convertidas as coordenadas polares de volta para cartesianas e adicionada a elevação relativa
		var cluster_center_x: float = cos(angle) * distance
		var cluster_center_z: float = sin(angle) * distance
		var cluster_center_y: float = base_sky_height + rng.randf_range(min_floating_height, max_floating_height)
		var cluster_center: Vector3 = Vector3(cluster_center_x, cluster_center_y, cluster_center_z)

		# são instanciados os objetos ao redor do centro do cluster
		for j: int in range(rocks_per_cluster):
			var offset_x: float = rng.randf_range(-cluster_radius, cluster_radius)
			var offset_y: float = rng.randf_range(-cluster_radius / 2.0, cluster_radius / 2.0)
			var offset_z: float = rng.randf_range(-cluster_radius, cluster_radius)
			var spawn_pos: Vector3 = cluster_center + Vector3(offset_x, offset_y, offset_z)

			var random_scene: PackedScene = floating_rock_scenes.pick_random()
			var prop_instance: Node3D = random_scene.instantiate()

			add_child(prop_instance)
			prop_instance.global_position = spawn_pos
			prop_instance.rotate_y(rng.randf_range(0.0, TAU))

			# é sorteada e aplicada a escala para objetos flutuantes
			var random_scale: float = rng.randf_range(min_floating_scale, max_floating_scale)
			prop_instance.scale = Vector3(random_scale, random_scale, random_scale)

			# é criada a animação de flutuação atrelada dinamicamente ao objeto instanciado
			var hover_amplitude: float = rng.randf_range(1.0, 2.5)
			var hover_duration: float = rng.randf_range(2.0, 4.0)
			var start_y: float = spawn_pos.y
			var up_y: float = start_y + hover_amplitude
			
			# é gerado o tween diretamente na instância
			var tween: Tween = prop_instance.create_tween().set_loops()
			tween.tween_property(prop_instance, "global_position:y", up_y, hover_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(prop_instance, "global_position:y", start_y, hover_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func spawn_player() -> void:
	if not player_scene:
		push_error("player_scene not assigned in GameManager")
		return

	var player: Node3D = player_scene.instantiate()
	add_child(player)

	# e adicionado ao grupo "player" para que qualquer inimigo possa
	# encontra-lo instantaneamente via get_tree().get_nodes_in_group("player")
	player.add_to_group("player")

	var safe_spawn_height: float = terrain_generator.height_multiplier + spawn_height_offset
	player.global_position = Vector3(0.0, safe_spawn_height, 0.0)

func spawn_enemies(rng: RandomNumberGenerator, occupied_positions: Array[Vector3]) -> void:
	# é evitada a execução caso a cena do inimigo não tenha sido configurada
	if not enemy_scene or enemy_count <= 0:
		return

	# é reutilizado o mesmo espaço físico 3d e os mesmos limites do terreno
	# já calculados para árvores e rochas, garantindo consistência total
	var space_state: PhysicsDirectSpaceState3D = terrain_generator.get_world_3d().direct_space_state
	var half_size: float = terrain_generator.island_size / 2.0
	var max_height: float = terrain_generator.height_multiplier + 20.0

	var enemies_planted: int = 0
	var attempts: int = 0
	var max_attempts: int = enemy_count * 15

	# é definida a posição de spawn do jogador (origem do mundo) como
	# referência de distância mínima, para que nenhum inimigo nasça em
	# cima do jogador logo no início
	var player_spawn_pos_2d: Vector2 = Vector2.ZERO
	


	while enemies_planted < enemy_count and attempts < max_attempts:
		attempts += 1

		var rand_x: float = rng.randf_range(-half_size, half_size)
		var rand_z: float = rng.randf_range(-half_size, half_size)

		var ray_origin: Vector3 = Vector3(rand_x, max_height, rand_z)
		var ray_end: Vector3 = Vector3(rand_x, -50.0, rand_z)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result: Dictionary = space_state.intersect_ray(query)

		if result:
			var hit_position: Vector3 = result["position"]
			var hit_normal: Vector3 = result["normal"]

			# são reaproveitadas as mesmas regras de altura mínima e
			# inclinação máxima usadas para a flora e as rochas
			if hit_position.y >= min_spawn_height and hit_normal.dot(Vector3.UP) >= max_slope_angle:

				var hit_pos_2d: Vector2 = Vector2(hit_position.x, hit_position.z)

				# é garantida uma distância segura em relação ao ponto de
				# spawn do jogador, evitando uma emboscada injusta no início
				if hit_pos_2d.distance_to(player_spawn_pos_2d) < enemy_min_distance_from_player:
					continue

				# é verificada a distância horizontal para todos os objetos
				# já plantados (árvores, rochas e outros inimigos)
				var is_too_close: bool = false
				for pos in occupied_positions:
					var occupied_pos_2d: Vector2 = Vector2(pos.x, pos.z)
					if hit_pos_2d.distance_to(occupied_pos_2d) < minimum_prop_spacing:
						is_too_close = true
						break

				if is_too_close:
					continue

				var enemy_instance: Node3D = enemy_scene.instantiate()

				var color_options: Array[String] = [
					#"ff0000",  # Vermelho
					#"006400",  # Verde escuro
					#"00ffff",  # Ciano
					"ff9900",  # Laranja
					#"8a2be2"   # Roxo
				]
				
				# Sorteio do índice
				var random_index: int = rng.randi_range(0, color_options.size() - 1)
				var chosen_color: String = color_options[random_index]

				# Passamos a cor escolhida para o inimigo
				if enemy_instance.has_method("apply_color"):
					#enemy_instance.apply_color("8a2be2")
					enemy_instance.apply_color(chosen_color)
				# -----------------------------------------

				add_child(enemy_instance)
				enemy_instance.global_position = hit_position

				# é registrado o local validado para impedir sobreposição
				occupied_positions.append(hit_position)
				enemies_planted += 1
