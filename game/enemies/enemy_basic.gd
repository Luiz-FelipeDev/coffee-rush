extends CharacterBody3D

# é definido um script de ia simples para o inimigo basico.
# é procurado o jogador no grupo "player", e caso esteja dentro do
# raio de deteccao, é perseguido em linha reta. como o terreno é gerado
# proceduralmente em tempo de execucao (sem navmesh), é usado um
# raycast vertical para alinhar ao chao a cada frame fisico.

enum EnemyRole {MELEE, RANGED}
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
# é definida a distancia maxima que o raycast de chao varre acima e abaixo.
@export var ground_probe_height: float = 5.0
@export var ground_probe_depth: float = 10.0
# é definida a inclinacao maxima de terreno que pode ser subida.
@export var max_slope_dot: float = 0.6

@export_group("saúde e ragdoll")
@export var max_health: int = 100

# é alterada a inicializacao da saude para zero para permitir heranca no respawn.
var current_health: int = 0
var is_knocked_out: bool = false
var player: Node3D = null
var _space_state: PhysicsDirectSpaceState3D

@onready var enemy_model: Node3D = $EnemyModel
@onready var anim_player: AnimationPlayer = $EnemyModel/AnimationPlayer
@onready var skeleton: Skeleton3D = $EnemyModel/RootNode/CharacterArmature/Skeleton3D
@onready var main_collider: CollisionShape3D = $CollisionShape3D

# é referenciado o nó responsável por simular e parar o ragdoll.
@onready var bone_simulator: PhysicalBoneSimulator3D = skeleton.get_node_or_null("PhysicalBoneSimulator3D")

@export_group("ragdoll failsafe")
# é definida a velocidade maxima aceitavel antes de considerar falha fisica.
@export var max_ragdoll_velocity: float = 100.0

func _ready() -> void:
	# é adicionado a um grupo proprio para facilitar gerenciamento futuro.
	add_to_group("enemies")
	_space_state = get_world_3d().direct_space_state
	
	# é aplicada a saude maxima apenas se for um spawn original.
	if current_health <= 0:
		current_health = max_health

	if not bone_simulator:
		push_warning("EnemyBasic: PhysicalBoneSimulator3D não encontrado sob o Skeleton3D.")
	else:
		# é impedido que os ossos físicos colidam com o próprio characterbody3d.
		bone_simulator.physical_bones_add_collision_exception(get_rid())

func _physics_process(delta: float) -> void:
	# é interrompida toda a lógica de física e perseguição caso o inimigo esteja desmaiado.
	if is_knocked_out:
		_monitor_ragdoll_stability()
		return
		
	if not is_instance_valid(player):
		_find_player()

	if is_instance_valid(player):
		_chase_player(delta)
	else:
		_apply_gravity_only(delta)

	move_and_slide()

func _monitor_ragdoll_stability() -> void:
	if not bone_simulator:
		return
		
	# é calculado o quadrado do limite uma unica vez para otimizar o loop.
	var velocity_limit_sq: float = max_ragdoll_velocity * max_ragdoll_velocity
		
	# é iterado sobre todos os ossos para verificar anomalias de inercia.
	for child in bone_simulator.get_children():
		var physical_bone: PhysicalBone3D = child as PhysicalBone3D
		if physical_bone:
			# é extraida a magnitude quadrada das velocidades linear e angular.
			var lin_vel_sq: float = physical_bone.linear_velocity.length_squared()
			var ang_vel_sq: float = physical_bone.angular_velocity.length_squared()
			
			# é interceptada a anomalia instantaneamente se a energia for extrema.
			if lin_vel_sq > velocity_limit_sq or ang_vel_sq > velocity_limit_sq:
				_trigger_ragdoll_failsafe()
				return

func _trigger_ragdoll_failsafe() -> void:
	# é abortada a simulacao imediatamente para conter a deformacao visual.
	bone_simulator.physical_bones_stop_simulation()
	
	if enemy_model:
		# é ocultado o modelo comprometido da tela.
		enemy_model.hide()
		
	# é instanciado um clone limpo do inimigo a partir da cena original.
	var clone: Node = load(scene_file_path).instantiate()
	
	# é repassada a saude atual para que o clone continue o combate no mesmo estado.
	clone.current_health = current_health
	
	# é copiada a transformacao global para manter a posicao exata do mapa.
	clone.global_transform = global_transform
	
	# é inserido o clone na arvore com seguranca apos o termino do calculo fisico.
	get_parent().call_deferred("add_child", clone)
		
	# é despachada a entidade original quebrada da memoria.
	queue_free()

func _find_player() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var closest: Node3D = null
	var closest_dist: float = detection_radius

	# é calculada a distancia para encontrar o jogador mais proximo.
	for p: Node in players:
		if p is Node3D:
			var dist: float = global_position.distance_to(p.global_position)
			if dist <= closest_dist:
				closest = p
				closest_dist = dist

	player = closest

func _chase_player(delta: float) -> void:
	var distance: float = global_position.distance_to(player.global_position)

	# é perdido o alvo caso a distancia seja maior que o limite de fuga.
	if distance > lose_target_radius:
		player = null
		_apply_gravity_only(delta)
		return

	# é normalizada a direcao ignorando o eixo vertical.
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
		# é aplicada a aceleracao horizontal em direcao ao alvo.
		var target_velocity: Vector3 = direction * move_speed
		velocity.x = lerpf(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = lerpf(velocity.z, target_velocity.z, acceleration * delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)

	# é rotacionado o corpo do inimigo suavemente para o jogador.
	if direction.length_squared() > 0.001:
		var target_transform: Transform3D = transform.looking_at(global_position + direction, Vector3.UP)
		quaternion = quaternion.slerp(target_transform.basis.get_rotation_quaternion(), rotation_speed * delta)

	# é aplicada a gravidade caso esteja caindo.
	if not is_on_floor():
		velocity.y -= gravity * delta

	if anim_player:
		# é reproduzida a animacao calculada para a situacao atual.
		anim_player.play(current_anim)

func _apply_gravity_only(delta: float) -> void:
	# é desacelerado o movimento horizontal quando nao ha perseguicao ativa.
	velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
	velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if anim_player:
		anim_player.play("CharacterArmature|Idle")
				
func apply_color(new_color: Color, allowed_mobs: Array[String]) -> void:
	# é obtido o nome exato do arquivo da cena atual.
	var current_mob_name: String = scene_file_path.get_file().get_basename()
	
	# é abortada a pintura caso o mob atual não esteja na lista.
	if not current_mob_name in allowed_mobs:
		return
		
	var target_skeleton: Skeleton3D = find_child("Skeleton3D", true, false)
	if not target_skeleton:
		return
		
	# é duplicado o material original para aplicar a nova cor de forma unica.
	for child in target_skeleton.get_children():
		if child is MeshInstance3D:
			var original_material: Material = child.get_active_material(0)
			if original_material:
				var unique_material: StandardMaterial3D = original_material.duplicate()
				unique_material.albedo_color = new_color
				child.set_surface_override_material(0, unique_material)

func take_damage(amount: int) -> void:
	# é ignorado o dano caso o inimigo já esteja desmaiado.
	if is_knocked_out:
		return

	# é contabilizado o dano na vida atual.
	current_health -= amount
	
	# é acionado o nocaute caso a vida zere.
	if current_health <= 0:
		knockout()

func knockout() -> void:
	is_knocked_out = true
	
	if anim_player:
		# é desativado o gerenciamento da animacao para prevenir conflitos fisicos.
		anim_player.active = false
		anim_player.stop()
		
	# é desabilitada a colisao principal.
	main_collider.disabled = true
	
	if bone_simulator:
		# são limpos os overrides para soltar os ossos completamente.
		skeleton.clear_bones_global_pose_override()
		
		for child in bone_simulator.get_children():
			var physical_bone: PhysicalBone3D = child as PhysicalBone3D
			if physical_bone:
				# é zerada a velocidade linear e angular para anular inercia residual.
				physical_bone.linear_velocity = Vector3.ZERO
				physical_bone.angular_velocity = Vector3.ZERO
				
		# é acionada a simulacao ragdoll do motor jolt.
		bone_simulator.physical_bones_start_simulation()
		# é resetada a interpolacao para que nao ocorra estiramento na transicao.
		skeleton.reset_physics_interpolation()

	await get_tree().create_timer(5.0).timeout
	recover()

func recover() -> void:
	if not bone_simulator:
		return
		
	var hip_bone: PhysicalBone3D = bone_simulator.get_node_or_null("Hips")
	var target_position: Vector3 = global_position
	
	if hip_bone:
		# é extraida apenas a coordenada horizontal do quadril caido.
		target_position.x = hip_bone.global_position.x
		target_position.z = hip_bone.global_position.z
		
	# é parada a simulacao ragdoll.
	bone_simulator.physical_bones_stop_simulation()
	
	# é aguardado um frame fisico garantindo que o jolt libere as malhas.
	await get_tree().physics_frame
	
	# é restaurado o esqueleto para a pose estrutural base.
	skeleton.clear_bones_global_pose_override()
	
	if hip_bone:
		# é realocado o node raiz precisamente onde o corpo parou.
		global_position = target_position
		
	# é forçada a atualizacao hierarquica do engine.
	skeleton.force_update_transform()

	if anim_player:
		anim_player.active = true
		# é acionada a animacao de impacto terrestre.
		anim_player.play("CharacterArmature|Jump_Land")
		
	if enemy_model:
		# é rotacionado o corpo visual inteiro para a posicao deitada.
		enemy_model.rotation.x = deg_to_rad(-90.0)
		
		# é atualizada a interpolacao estritamente apos a nova rotacao deitada.
		skeleton.reset_physics_interpolation()
		
		var anim_length: float = 1.0 
		
		# é capturado o tempo exato da animacao para sincronizar o tween.
		if anim_player.has_animation("CharacterArmature|Jump_Land"):
			anim_length = anim_player.get_animation("CharacterArmature|Jump_Land").length
		
		var tween: Tween = create_tween()
		
		# é executado o giro suave de -90 a 0 graus de forma sincronizada.
		tween.tween_property(enemy_model, "rotation:x", 0.0, anim_length)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
			
		tween.tween_callback(_on_recovery_finished)
	else:
		_on_recovery_finished()

func _on_recovery_finished() -> void:
	if enemy_model:
		# é assegurado o alinhamento perpendicular final do modelo visual.
		enemy_model.rotation.x = 0.0
		
	if anim_player:
		# é retomada a rotina da pose de descanso.
		anim_player.play("CharacterArmature|Idle")
		
	# são reestabelecidos os status vitais e fisicos.
	current_health = max_health
	main_collider.disabled = false
	is_knocked_out = false
	
func perform_attack() -> void:
	if not player or not is_instance_valid(player):
		return
		
	var dist: float = global_position.distance_to(player.global_position)
	var can_hit: bool = false
	
	# é validada a condicao de ataque baseada no perfil operacional do inimigo.
	if role == EnemyRole.MELEE and dist <= attack_range:
		can_hit = true
	elif role == EnemyRole.RANGED and dist <= shoot_range:
		can_hit = true
		
	if can_hit and player.has_method("take_damage"):
		# é computado o golpe no oponente.
		player.take_damage(attack_damage)
