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

@export_group("scannable items")
@export var global_scannable_items: Array[PackedScene]
@export var scannables_per_biome: int = 4

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

@export_group("enemy spawn rules")
@export var enemy_count: int = 80
@export var enemy_min_distance_from_player: float = 30.0
@export var boss_min_distance_from_player: float = 50.0

@export_group("portal & progression")
@export var portal_scene: PackedScene
@export var title_screen_scene: PackedScene
@export var portal_min_distance: float = 60.0

@export_subgroup("randomization control")
@export var world_seed: int = 0

# ========================================================== #
# CONTROLE DE PROGRESSÃO GLOBAL (ESTÁTICO)
# ========================================================== #

# sao criadas variaveis estaticas que sobrevivem ao recarregamento da cena.
static var remaining_biomes: Array[BiomeData] = []
static var remaining_items: Array[PackedScene] = []
static var active_biome_items: Array[PackedScene] = []
static var persistent_current_biome: BiomeData = null

static var is_game_started: bool = false
static var is_dimension_jump: bool = true

# variaveis de controle local da sessao atual.
var portal_spawned: bool = false
var player_node: Node3D = null

# ========================================================== #
# INICIALIZAÇÃO E LOOP
# ========================================================== #

func _ready() -> void:
	add_to_group("game_manager")
	generate_seed()
	
	# é inicializado o banco de dados de progressao apenas na primeira execucao.
	if not is_game_started:
		remaining_biomes = available_biomes.duplicate()
		remaining_items = global_scannable_items.duplicate()
		is_game_started = true
	
	# é feito o sorteio de uma nova dimensao apenas quando o portal é cruzado.
	if is_dimension_jump:
		_setup_new_dimension()
		
	# é recuperado o bioma salvo na memoria global para a cena atual.
	current_biome = persistent_current_biome

	if terrain_generator:
		if current_biome:
			terrain_generator.grass_color = current_biome.grass_color
			terrain_generator.sand_color = current_biome.sand_color
			
			if world_environment and world_environment.environment and world_environment.environment.sky:
				var sky_mat: ProceduralSkyMaterial = world_environment.environment.sky.sky_material as ProceduralSkyMaterial
				if sky_mat:
					sky_mat.sky_top_color = current_biome.sky_top_color
					sky_mat.sky_horizon_color = current_biome.sky_horizon_color

		terrain_generator.terrain_generated.connect(_on_terrain_generated)
		terrain_generator.generate_terrain()

func _process(_delta: float) -> void:
	# é monitorado o estado de conclusao da fase para invocar o portal.
	if player_node and not portal_spawned:
		if player_node.get("is_level_finished"):
			spawn_portal()
			portal_spawned = true

func _setup_new_dimension() -> void:
	# é sorteado um bioma que ainda nao foi visitado.
	if not remaining_biomes.is_empty():
		var biome_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		biome_rng.seed = world_seed
		var random_index: int = biome_rng.randi_range(0, remaining_biomes.size() - 1)
		
		persistent_current_biome = remaining_biomes[random_index]
		remaining_biomes.remove_at(random_index)
	
	# sao separados os itens escaneaveis exclusivos desta dimensao.
	active_biome_items.clear()
	var items_to_spawn: int = min(scannables_per_biome, remaining_items.size())
	var item_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	item_rng.randomize()
	
	for i in range(items_to_spawn):
		var random_item_index: int = item_rng.randi_range(0, remaining_items.size() - 1)
		active_biome_items.append(remaining_items[random_item_index])
		remaining_items.remove_at(random_item_index)
		
	is_dimension_jump = false

func advance_dimension() -> void:
	if remaining_biomes.is_empty():
		# é resetado o jogo e redirecionado para o menu caso as dimensoes acabem.
		is_game_started = false
		is_dimension_jump = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		if title_screen_scene:
			get_tree().change_scene_to_packed(title_screen_scene)
		else:
			push_warning("Title Screen não configurada no GameManager!")
	else:
		# é ativada a flag de pulo e recarregada a cena base para gerar novo mundo.
		is_dimension_jump = true
		get_tree().reload_current_scene()

func _on_terrain_generated() -> void:
	await get_tree().physics_frame
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = world_seed
	var occupied_positions: Array[Vector3] = []
	
	if current_biome:
		await spawn_surface_props(rng, current_biome.tree_scenes, tree_count, min_tree_scale, max_tree_scale, occupied_positions)
		
	await spawn_surface_props(rng, surface_rock_scenes, surface_rock_count, min_surface_scale, max_surface_scale, occupied_positions)
	await spawn_surface_props(rng, chest_scenes, chest_count, 1.0, 1.0, occupied_positions)
	
	spawn_floating_rocks(rng)
	await spawn_surface_props(rng, branch_scenes, 20, 0.8, 1.2, occupied_positions)
	
	var player_pos: Vector3 = spawn_player()

	spawn_enemies(rng, occupied_positions, player_pos)
	spawn_boss(rng, occupied_positions, player_pos)
	
	var spawned_items_ids: Array[String] = spawn_unique_scannables(rng, occupied_positions)
	var scan_targets: Array[String] = []
	
	scan_targets.append_array(spawned_items_ids)
	
	if current_biome:
		if current_biome.get("enemy_scenes"):
			for scene in current_biome.enemy_scenes:
				if scene:
					var target_name: String = scene.resource_path.get_file().get_basename()
					if not scan_targets.has(target_name):
						scan_targets.append(target_name)
				
		if current_biome.get("boss_scene") and current_biome.boss_scene:
			var boss_name: String = current_biome.boss_scene.resource_path.get_file().get_basename()
			if not scan_targets.has(boss_name):
				scan_targets.append(boss_name)
			
	if player_node and player_node.has_method("initialize_atlas"):
		player_node.initialize_atlas(scan_targets)

# ========================================================== #
# FUNÇÕES DE CONFIGURAÇÃO
# ========================================================== #

func generate_seed() -> void:
	if world_seed == 0:
		var matriculas: Array[int] = [540353, 580410, 535946, 571390, 571518, 540863, 565732]
		var temp_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		temp_rng.randomize() 
		
		if temp_rng.randf() <= 0.5:
			world_seed = matriculas.pick_random()
		else:
			world_seed = temp_rng.randi_range(100000, 999999)

# ========================================================== #
# GERAÇÃO DO TERRENO E PROPS
# ========================================================== #
func spawn_unique_scannables(rng: RandomNumberGenerator, occupied_positions: Array[Vector3]) -> Array[String]:
	var spawned_ids: Array[String] = []
	
	if active_biome_items.is_empty():
		return spawned_ids

	var space_state: PhysicsDirectSpaceState3D = terrain_generator.get_world_3d().direct_space_state
	var half_size: float = terrain_generator.island_size / 2.0
	var max_height: float = terrain_generator.height_multiplier + 20.0

	for item_scene in active_biome_items:
		if not item_scene:
			continue

		var attempts: int = 0
		var max_attempts: int = 50
		var placed: bool = false

		while not placed and attempts < max_attempts:
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
					
					if not is_too_close:
						var prop_instance: Node3D = item_scene.instantiate()
						add_child(prop_instance)
						prop_instance.global_position = hit_position
						prop_instance.quaternion = Quaternion(Vector3.UP, hit_normal)
						prop_instance.rotate_object_local(Vector3.UP, rng.randf_range(0.0, TAU))

						# é definida a escala fixa de 2.0 em todos os eixos para facilitar o debug visual.
						prop_instance.scale = Vector3(2.0, 2.0, 2.0)
						
						prop_instance.add_to_group("scannables")
						occupied_positions.append(hit_position)
						
						spawned_ids.append(item_scene.resource_path.get_file().get_basename())
						placed = true
						
	return spawned_ids
	
func spawn_portal() -> void:
	if not portal_scene:
		push_warning("Portal Scene não referenciada no GameManager!")
		return
		
	var space_state: PhysicsDirectSpaceState3D = terrain_generator.get_world_3d().direct_space_state
	var half_size: float = terrain_generator.island_size / 2.0
	var max_height: float = terrain_generator.height_multiplier + 20.0
	
	var player_pos_2d: Vector2 = Vector2(player_node.global_position.x, player_node.global_position.z)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	
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
				
				# é garantido que o portal nascera longe do jogador atual.
				if hit_pos_2d.distance_to(player_pos_2d) >= portal_min_distance:
					var portal_instance: Node3D = portal_scene.instantiate()
					add_child(portal_instance)
					portal_instance.global_position = hit_position
					portal_instance.quaternion = Quaternion(Vector3.UP, hit_normal)
					
					# é buscado o tocador de animacao responsavel pelo surgimento e executado o efeito visual.
					var appear_anim: AnimationPlayer = portal_instance.get_node_or_null("AnimationPlayer2")
					if appear_anim:
						appear_anim.play("apper")
						
					return
					
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
		if attempts % 20 == 0:
			await get_tree().process_frame
			
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

	player.add_to_group("player")
	player_node = player

	var safe_spawn_height: float = terrain_generator.height_multiplier + spawn_height_offset
	var final_pos: Vector3 = Vector3(0, safe_spawn_height, 0)
	
	player.global_position = final_pos
	return final_pos

func spawn_enemies(rng: RandomNumberGenerator, occupied_positions: Array[Vector3], player_pos: Vector3) -> void:
	if not current_biome or not current_biome.get("enemy_scenes") or current_biome.enemy_scenes.is_empty() or enemy_count <= 0:
		return

	var space_state: PhysicsDirectSpaceState3D = terrain_generator.get_world_3d().direct_space_state
	var half_size: float = terrain_generator.island_size / 2.0
	var max_height: float = terrain_generator.height_multiplier + 20.0

	var enemies_planted: int = 0
	var attempts: int = 0
	var max_attempts: int = enemy_count * 15

	var player_spawn_pos_2d: Vector2 = Vector2(player_pos.x, player_pos.z)
	
	var color_options: Array[String] = ["ff0000", "006400", "00ffff", "ff9900", "8a2be2"]
	var paintable_mobs: Array[String] = ["enemy_basic", "enemy_large"]

	while enemies_planted < enemy_count and attempts < max_attempts:
		attempts += 1
		if attempts % 20 == 0:
			await get_tree().process_frame

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

				var random_enemy_scene: PackedScene = current_biome.enemy_scenes.pick_random()
				
				if not random_enemy_scene:
					continue
					
				var enemy_instance: Node3D = random_enemy_scene.instantiate()
				add_child(enemy_instance)
				enemy_instance.global_position = hit_position

				var random_index: int = rng.randi_range(0, color_options.size() - 1)
				var chosen_color: String = color_options[random_index]

				if enemy_instance.has_method("apply_color"):
					enemy_instance.apply_color(Color(chosen_color), paintable_mobs)

				occupied_positions.append(hit_position)
				enemies_planted += 1

func spawn_boss(rng: RandomNumberGenerator, occupied_positions: Array[Vector3], player_pos: Vector3) -> void:
	if not current_biome or not current_biome.get("boss_scene") or not current_biome.boss_scene:
		return

	var space_state: PhysicsDirectSpaceState3D = terrain_generator.get_world_3d().direct_space_state
	var half_size: float = terrain_generator.island_size / 2.0
	var max_height: float = terrain_generator.height_multiplier + 20.0
	var player_spawn_pos_2d: Vector2 = Vector2(player_pos.x, player_pos.z)

	var attempts: int = 0
	var max_attempts: int = 200

	while attempts < max_attempts:
		attempts += 1
		if attempts % 20 == 0:
			await get_tree().process_frame

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

				var boss_instance: Node3D = current_biome.boss_scene.instantiate()
				add_child(boss_instance)
				boss_instance.global_position = hit_position
				occupied_positions.append(hit_position)
				return
				
func _unhandled_input(event: InputEvent) -> void:
	# é acionado o modo de depuracao apertando a tecla "P" para forcar o nascimento do portal.
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		if player_node and not portal_spawned:
			print("🐛 debug: portal invocado manualmente!")
			spawn_portal()
			portal_spawned = true
