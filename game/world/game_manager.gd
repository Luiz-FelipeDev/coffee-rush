#game_manager.gd

extends Node

@export var player_scene: PackedScene
@export var terrain_generator: MeshInstance3D
@export var world_environment: WorldEnvironment 
@export var spawn_height_offset: float = 10.0

@export_group("biome configuration")
@export var current_biome: BiomeData
@export var available_biomes: Array[BiomeData]

@export_group("surface generation rules")
@export var min_spawn_height: float = 12.0 
@export var max_slope_angle: float = 0.8 
@export var minimum_prop_spacing: float = 4.5
@export var branch_scenes: Array[PackedScene]

@export_group("flora generation")
@export var tree_count: int = 150
@export var min_tree_scale: float = 0.8
@export var max_tree_scale: float = 2.5

@export_group("surface rocks generation")
@export var surface_rock_scenes: Array[PackedScene]
@export var surface_rock_count: int = 40
@export var min_surface_scale: float = 0.5
@export var max_surface_scale: float = 1.5

@export_group("chest generation")
@export var chest_scenes: Array[PackedScene]
@export var chest_count: int = 40

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
@export var enemy_scenes: Array[PackedScene]
@export var enemy_count: int = 80
@export var enemy_min_distance_from_player: float = 30.0

@export_subgroup("randomization control")
#@export var world_seed: int = 98765
@export var world_seed: int = 0

# caminho de spawn próprio e separado para o boss
@export_group("boss")
@export var boss_scene: PackedScene
@export var boss_min_distance_from_player: float = 50.0


# ========================================================== #
# INICIALIZAÇÃO
# ========================================================== #

func _ready() -> void:
	# Chama a função que cuida de toda a lógica da seed
	generate_seed()
	
	if not available_biomes.is_empty():
		var biome_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		biome_rng.seed = world_seed
		var random_index: int = biome_rng.randi_range(0, available_biomes.size() - 1)
		current_biome = available_biomes[random_index]

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
	
	# Spawns chests globally using a fixed scale to preserve Kenney asset proportions
	spawn_surface_props(rng, chest_scenes, chest_count, 1.0, 1.0, occupied_positions)
	
	spawn_floating_rocks(rng)
	spawn_surface_props(rng, branch_scenes, 20, 0.8, 1.2, occupied_positions)
	
	# é gerado o jogador e guardada a sua posição no mundo
	var player_pos: Vector3 = spawn_player()

	# são gerados os inimigos recebendo a posição do jogador como referência
	spawn_enemies(rng, occupied_positions, player_pos)
	spawn_boss(rng, occupied_positions, player_pos)

# ========================================================== #
# FUNÇÕES DE CONFIGURAÇÃO
# ========================================================== #

func generate_seed() -> void:
	# Só faz o sorteio se a seed estiver em 0 no Inspector
	if world_seed == 0:
		var matriculas: Array[int] = [540353, 580410, 535946, 571390, 571518, 540863, 565732]
		var temp_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		temp_rng.randomize() 
		
		# Sorteia um número de 0.0 a 1.0. Se for menor ou igual a 0.5 (50%), usa a matrícula
		if temp_rng.randf() <= 0.5:
			world_seed = matriculas.pick_random()
		else:
			# Sorteia qualquer número de 6 dígitos (de 100.000 até 999.999)
			world_seed = temp_rng.randi_range(100000, 999999)

# ========================================================== #
# GERAÇÃO DO TERRENO E PROPS
# ========================================================== #

func spawn_surface_props(rng: RandomNumberGenerator, prop_scenes: Array[PackedScene], count: int, min_scale: float, max_scale: float, occupied_positions: Array[Vector3]) -> void:
	if prop_scenes.is_empty() or count <= 0:
		return

	var space_state: PhysicsDirectSpaceState3D = terrain_generator.get_world_3d().direct_space_state
	var half_size: float = terrain_generator.island_size / 2.0
	var max_height: float = terrain_generator.height_multiplier + 20.0

	var props_planted: int = 0
	var attempts: int = 0
	var max_attempts: int = count * 15 

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
				
				var hit_pos_2d: Vector2 = Vector2(hit_position.x, hit_position.z)
				var is_too_close: bool = false
				
				for pos in occupied_positions:
					var occupied_pos_2d: Vector2 = Vector2(pos.x, pos.z)
					if hit_pos_2d.distance_to(occupied_pos_2d) < minimum_prop_spacing:
						is_too_close = true
						break
				
				if is_too_close:
					continue

				var random_scene: PackedScene = prop_scenes.pick_random()
				var prop_instance: Node3D = random_scene.instantiate()

				add_child(prop_instance)
				prop_instance.global_position = hit_position
				prop_instance.quaternion = Quaternion(Vector3.UP, hit_normal)
				prop_instance.rotate_object_local(Vector3.UP, rng.randf_range(0.0, TAU))

				var random_scale: float = rng.randf_range(min_scale, max_scale)
				prop_instance.scale = Vector3(random_scale, random_scale, random_scale)

				occupied_positions.append(hit_position)
				props_planted += 1


func spawn_floating_rocks(rng: RandomNumberGenerator) -> void:
	if floating_rock_scenes.is_empty() or floating_cluster_count <= 0:
		return

	var base_sky_height: float = terrain_generator.height_multiplier

	for i: int in range(floating_cluster_count):
		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = sqrt(rng.randf_range(0.0, 1.0)) * max_floating_spawn_radius
		
		var cluster_center_x: float = cos(angle) * distance
		var cluster_center_z: float = sin(angle) * distance
		var cluster_center_y: float = base_sky_height + rng.randf_range(min_floating_height, max_floating_height)
		var cluster_center: Vector3 = Vector3(cluster_center_x, cluster_center_y, cluster_center_z)

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

			var random_scale: float = rng.randf_range(min_floating_scale, max_floating_scale)
			prop_instance.scale = Vector3(random_scale, random_scale, random_scale)

			var hover_amplitude: float = rng.randf_range(1.0, 2.5)
			var hover_duration: float = rng.randf_range(2.0, 4.0)
			var start_y: float = spawn_pos.y
			var up_y: float = start_y + hover_amplitude
			
			var tween: Tween = prop_instance.create_tween().set_loops()
			tween.tween_property(prop_instance, "global_position:y", up_y, hover_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(prop_instance, "global_position:y", start_y, hover_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ========================================================== #
# GERAÇÃO DE ENTIDADES (JOGADOR E INIMIGOS)
# ========================================================== #

func spawn_player() -> Vector3:
	if not player_scene:
		push_error("player_scene not assigned in GameManager")
		return Vector3.ZERO

	var player: Node3D = player_scene.instantiate()
	add_child(player)

	# é adicionado ao grupo "player" para facilitar o acesso global
	player.add_to_group("player")

	# é definida a posição do jogador
	var safe_spawn_height: float = terrain_generator.height_multiplier + spawn_height_offset
	var final_pos: Vector3 = Vector3(0, safe_spawn_height, 0)
	
	player.global_position = final_pos
	return final_pos


func spawn_enemies(rng: RandomNumberGenerator, occupied_positions: Array[Vector3], player_pos: Vector3) -> void:
	if enemy_scenes.is_empty() or enemy_count <= 0:
		return

	var space_state: PhysicsDirectSpaceState3D = terrain_generator.get_world_3d().direct_space_state
	var half_size: float = terrain_generator.island_size / 2.0
	var max_height: float = terrain_generator.height_multiplier + 20.0

	var enemies_planted: int = 0
	var attempts: int = 0
	var max_attempts: int = enemy_count * 15

	# é extraída a posição 2D do jogador baseada no parâmetro recebido
	var player_spawn_pos_2d: Vector2 = Vector2(player_pos.x, player_pos.z)
	
	# a lista de cores é mantida fora do laço para otimização de memória
	var color_options: Array[String] = [
		"ff0000",  # Vermelho
		"006400",  # Verde escuro
		"00ffff",  # Ciano
		"ff9900",   # Laranja
		"8a2be2"   # Roxo
	]
	
	var paintable_mobs: Array[String] = ["enemy_basic", "enemy_large"]

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

			if hit_position.y >= min_spawn_height and hit_normal.dot(Vector3.UP) >= max_slope_angle:

				var hit_pos_2d: Vector2 = Vector2(hit_position.x, hit_position.z)

				if hit_pos_2d.distance_to(player_spawn_pos_2d) < enemy_min_distance_from_player:
					continue

				var is_too_close: bool = false
				for pos in occupied_positions:
					var occupied_pos_2d: Vector2 = Vector2(pos.x, pos.z)
					if hit_pos_2d.distance_to(occupied_pos_2d) < minimum_prop_spacing:
						is_too_close = true
						break

				if is_too_close:
					continue

				# Instantiation and configuration
				var random_enemy_scene: PackedScene = enemy_scenes.pick_random()
				var enemy_instance: Node3D = random_enemy_scene.instantiate()
				add_child(enemy_instance)
				enemy_instance.global_position = hit_position

				# Random color application with authorization list
				var random_index: int = rng.randi_range(0, color_options.size() - 1)
				var chosen_color: String = color_options[random_index]

				if enemy_instance.has_method("apply_color"):
					enemy_instance.apply_color(Color(chosen_color), paintable_mobs)

				occupied_positions.append(hit_position)
				enemies_planted += 1


func spawn_boss(rng: RandomNumberGenerator, occupied_positions: Array[Vector3], player_pos: Vector3) -> void:
	# tenta até 200 vezes achar um ponto válido (longe do jogador, 
	#sem sobrepor outro objeto) e, ao conseguir, instancia o Boss uma única vez 
	
	
	if not boss_scene:
		return

	var space_state: PhysicsDirectSpaceState3D = terrain_generator.get_world_3d().direct_space_state
	var half_size: float = terrain_generator.island_size / 2.0
	var max_height: float = terrain_generator.height_multiplier + 20.0
	var player_spawn_pos_2d: Vector2 = Vector2(player_pos.x, player_pos.z)

	var attempts: int = 0
	var max_attempts: int = 200

	while attempts < max_attempts:
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
				var hit_pos_2d: Vector2 = Vector2(hit_position.x, hit_position.z)

				if hit_pos_2d.distance_to(player_spawn_pos_2d) < boss_min_distance_from_player:
					continue

				var is_too_close: bool = false
				for pos in occupied_positions:
					var occupied_pos_2d: Vector2 = Vector2(pos.x, pos.z)
					if hit_pos_2d.distance_to(occupied_pos_2d) < minimum_prop_spacing:
						is_too_close = true
						break

				if is_too_close:
					continue

				var boss_instance: Node3D = boss_scene.instantiate()
				add_child(boss_instance)
				boss_instance.global_position = hit_position
				occupied_positions.append(hit_position)
				return
