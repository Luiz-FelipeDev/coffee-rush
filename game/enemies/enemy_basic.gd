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
@export var ground_probe_height: float = 5.0
@export var ground_probe_depth: float = 10.0
@export var max_slope_dot: float = 0.6

@export_group("nomes de animacao")
@export var anim_idle: String = "CharacterArmature|Idle"
@export var anim_walk: String = "CharacterArmature|Walk"
@export var anim_run: String = "CharacterArmature|Run"
@export var anim_attack_melee: String = "CharacterArmature|Punch"
@export var anim_aim: String = "CharacterArmature|Run_Gun"
@export var anim_shoot: String = "CharacterArmature|Run_Gun_Shoot"

@onready var anim_player = $EnemyModel/AnimationPlayer

var player: Node3D = null
var _space_state: PhysicsDirectSpaceState3D
var _time_since_last_attack: float = 0.0

func _ready() -> void:
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

	if distance > lose_target_radius:
		player = null
		_apply_gravity_only(delta)
		return

	var direction: Vector3 = (player.global_position - global_position)
	direction.y = 0.0
	direction = direction.normalized()

	var current_anim: String = anim_idle
	var is_attacking: bool = false
	var should_move: bool = true

	if role == EnemyRole.MELEE:
		if distance <= attack_range:
			should_move = false
			current_anim = anim_attack_melee
			is_attacking = true
		else:
			current_anim = anim_walk
	elif role == EnemyRole.RANGED:
		if distance <= attack_range:
			should_move = false
			current_anim = anim_attack_melee
			is_attacking = true
		elif distance <= shoot_range:
			current_anim = anim_shoot
			is_attacking = true
		elif distance <= aim_range:
			current_anim = anim_aim
		else:
			current_anim = anim_run

	if should_move:
		var target_velocity: Vector3 = direction * move_speed
		velocity.x = lerpf(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = lerpf(velocity.z, target_velocity.z, acceleration * delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
		velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)

	if direction.length_squared() > 0.001:
		var target_transform: Transform3D = transform.looking_at(global_position + direction, Vector3.UP)
		quaternion = quaternion.slerp(target_transform.basis.get_rotation_quaternion(), rotation_speed * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if anim_player:
		anim_player.play(current_anim)

func _apply_gravity_only(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
	velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta

	if anim_player:
		anim_player.play(anim_idle)

func apply_color(new_color: Color) -> void:
	var mesh_instance: MeshInstance3D = $EnemyModel/RootNode/CharacterArmature/Skeleton3D/Enemy

	if mesh_instance:
		var original_material: Material = mesh_instance.get_active_material(0)

		if original_material:
			var unique_material: StandardMaterial3D = original_material.duplicate()
			unique_material.albedo_color = new_color
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
