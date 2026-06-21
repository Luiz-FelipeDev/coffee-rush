extends CharacterBody3D

# script de ia simples para o inimigo basico.
# o inimigo procura o jogador no grupo "player", e caso esteja dentro do
# raio de deteccao, persegue-o em linha reta. como o terreno e gerado
# proceduralmente em tempo de execucao (sem navmesh), o inimigo usa um
# raycast vertical -- a mesma tecnica usada pelo game_manager para plantar
# arvores -- para "grudar" no chao a cada frame fisico.

enum EnemyRole { MELEE, RANGED }
@export var role: EnemyRole = EnemyRole.MELEE

@export_group("deteccao")
@export var detection_radius: float = 20.0
@export var lose_target_radius: float = 30.0 

@export_group("combate")
@export var attack_range: float = 2.5
@export var aim_range: float = 15.0
@export var shoot_range: float = 10.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.5

@export_group("movimento")
@export var move_speed: float = 6.0
@export var acceleration: float = 10.0
@export var rotation_speed: float = 5.0
@export var gravity: float = 20.0

@export_group("navegacao no terreno")
# distancia maxima que o raycast de chao varre acima/abaixo do inimigo.
@export var ground_probe_height: float = 5.0
@export var ground_probe_depth: float = 10.0
# inclinacao maxima de terreno que o inimigo consegue subir (1.0 = totalmente plano)
@export var max_slope_dot: float = 0.6

@onready var anim_player = $EnemyModel/AnimationPlayer

var player: Node3D = null
var _space_state: PhysicsDirectSpaceState3D
var _time_since_last_attack: float = 0.0

func _ready() -> void:
	# e adicionado a um grupo proprio para facilitar contagem/gerenciamento futuro
	add_to_group("enemies")
	_space_state = get_world_3d().direct_space_state

func _physics_process(delta: float) -> void:
	
	_time_since_last_attack += delta
		
	if not is_instance_valid(player):
		_find_player()

	if is_instance_valid(player):
		_chase_player(delta)
	else:
		_apply_gravity_only(delta)

	move_and_slide()

func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var closest: Node3D = null
	var closest_dist: float = detection_radius

	for p: Node in players:
		if p is Node3D:
			var dist: float = global_position.distance_to(p.global_position)
			if dist <= closest_dist:
				closest = p
				closest_dist = dist

	player = closest

func _chase_player(delta: float) -> void:
	var distance: float = global_position.distance_to(player.global_position)

	# e perdido o alvo caso ele fuja para muito longe, liberando o inimigo
	# para procurar novamente (e parar de seguir um jogador inalcancavel)
	if distance > lose_target_radius:
		player = null
		_apply_gravity_only(delta)
		return

	var direction: Vector3 = (player.global_position - global_position)
	direction.y = 0.0
	direction = direction.normalized()

	var current_anim: String = "CharacterArmature|Idle"
	var is_attacking: bool = false
	var should_move: bool = true

	if role == EnemyRole.MELEE:
		if distance <= attack_range:
			should_move = false
			current_anim = "CharacterArmature|Punch"
			is_attacking = true
		else:
			current_anim = "CharacterArmature|Walk"
	elif role == EnemyRole.RANGED:
		if distance <= attack_range:
			should_move = false
			current_anim = "CharacterArmature|Punch"
			is_attacking = true
		elif distance <= shoot_range:
			current_anim = "CharacterArmature|Run_Gun_Shoot"
			is_attacking = true
		elif distance <= aim_range:
			current_anim = "CharacterArmature|Run_Gun"
		else:
			current_anim = "CharacterArmature|Run"

	if should_move:
		# e aplicada a aceleracao horizontal em direcao ao jogador
		var target_velocity: Vector3 = direction * move_speed
		velocity.x = lerpf(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = lerpf(velocity.z, target_velocity.z, acceleration * delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)

	# e rotacionado o corpo do inimigo suavemente para encarar o alvo
	if direction.length_squared() > 0.001:
		var target_transform: Transform3D = transform.looking_at(global_position + direction, Vector3.UP)
		quaternion = quaternion.slerp(target_transform.basis.get_rotation_quaternion(), rotation_speed * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if anim_player:
		anim_player.play(current_anim)

func _apply_gravity_only(delta: float) -> void:
	# e desacelerado o movimento horizontal quando nao ha alvo para perseguir
	velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
	velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if anim_player:
		anim_player.play("CharacterArmature|Idle")

#func _stick_to_ground(delta: float) -> void:
	## e disparado um raycast vertical para encontrar a altura real do terreno
	## logo abaixo do inimigo, permitindo que ele suba e desca o relevo
	## procedural sem atravessar o chao nem flutuar sobre ele
	#var ray_origin: Vector3 = global_position + Vector3.UP * ground_probe_height
	#var ray_end: Vector3 = global_position - Vector3.UP * ground_probe_depth
#
	#var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	#query.collide_with_bodies = true
	## e excluido o proprio corpo da consulta para nao colidir consigo mesmo
	#query.exclude = [self]
#
	#var result: Dictionary = _space_state.intersect_ray(query)
#
	#if result:
		#var hit_position: Vector3 = result["position"]
		#var hit_normal: Vector3 = result["normal"]
#
		## e ignorada a "colagem" caso a superficie seja ingreme demais para subir
		#if hit_normal.dot(Vector3.UP) >= max_slope_dot:
			#var height_diff: float = hit_position.y - global_position.y
#
			## e suavizado o ajuste vertical para evitar tremulacao em terrenos irregulares
			#if abs(height_diff) > 0.01:
				#global_position.y = lerpf(global_position.y, hit_position.y, 15.0 * delta)
				#velocity.y = 0.0
				#
				
func apply_color(new_color: Color) -> void:
	# ATENÇÃO: Substitua o caminho abaixo pelo caminho exato da sua malha 3D
	# Segure Ctrl (ou Cmd) e arraste a malha do painel Scene para cá para colar o caminho certo.
	var mesh_instance: MeshInstance3D = $EnemyModel/RootNode/CharacterArmature/Skeleton3D/Enemy
	
	if mesh_instance:
		# Pega o material atual do inimigo (slot 0)
		var original_material: Material = mesh_instance.get_active_material(0)
		
		if original_material:
			# DUPLICA o material para torná-lo único para este inimigo instanciado
			var unique_material: StandardMaterial3D = original_material.duplicate()
			
			# Altera a cor
			unique_material.albedo_color = new_color
			
			# Aplica o material exclusivo de volta na malha
			mesh_instance.set_surface_override_material(0, unique_material)

func perform_attack() -> void:
	if not player or not is_instance_valid(player):
		return
		
	var dist: float = global_position.distance_to(player.global_position)
	var can_hit: bool = false
	
	if role == EnemyRole.MELEE and dist <= attack_range:
		can_hit = true
	elif role == EnemyRole.RANGED and dist <= shoot_range:
		can_hit = true
		
	if can_hit and player.has_method("take_damage"):
		player.take_damage(attack_damage)
