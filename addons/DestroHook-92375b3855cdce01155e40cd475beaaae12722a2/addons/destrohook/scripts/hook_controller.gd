@icon("res://addons/destrohook/textures/hook.png")
class_name HookController
extends Node

@export_group("controls")
@export var launch_action_name: String = "RMB"
@export var thrust_action_name: String = "action_jump"

@export_group("references")
@export var hook_scene: PackedScene 
@export var player_body: CharacterBody3D 
@export var hook_raycast: RayCast3D 
@export var hook_source: Node3D 

@export_group("settings")
@export var hook_max_range: float = 60.0 
@export var auto_pull_speed: float = 30.0 
@export var thrust_mult: float = 1.0 
@export var stiffness: float = 6.0 
@export var damping: float = 2.0 

var rest_length: float = 0.0
var is_hook_launched: bool = false
var hook_model: Node3D = null
var hook_target_normal: Vector3 = Vector3.ZERO
var hook_target_node: Marker3D = null

signal hook_launched()
signal hook_attached()
signal hook_detached()

func _ready() -> void:
	# é ajustado dinamicamente o comprimento do sensor de colisão para respeitar o alcance máximo estabelecido
	if hook_raycast:
		var current_dir: Vector3 = hook_raycast.target_position.normalized()
		if current_dir == Vector3.ZERO:
			current_dir = Vector3(0.0, 0.0, -1.0)
		hook_raycast.target_position = current_dir * hook_max_range

func _physics_process(delta: float) -> void:
	# é verificado o clique inicial para lançar o gancho
	if Input.is_action_just_pressed(launch_action_name):
		hook_launched.emit()
		if not is_hook_launched:
			launch_hook()
			
	# é verificada a soltura do botão para desconectar o gancho automaticamente
	if Input.is_action_just_released(launch_action_name):
		if is_hook_launched:
			retract_hook()
	
	# é processada a física elástica caso o gancho esteja conectado
	if is_hook_launched:
		handle_hook(delta)

func launch_hook() -> void:
	# é evitada a execução caso o raio não atinja nenhum objeto
	if not hook_raycast.is_colliding():
		return
	
	is_hook_launched = true
	hook_attached.emit()
	
	# é criado um marcador no ponto exato da colisão
	var body: Node3D = hook_raycast.get_collider()
	hook_target_node = Marker3D.new()
	body.add_child(hook_target_node)
	hook_target_node.global_position = hook_raycast.get_collision_point()
	
	# é calculado o vetor reverso da visão para inclinar a ponta do gancho na direção do tiro
	hook_target_normal = (hook_raycast.global_position - hook_target_node.global_position).normalized()
	
	# é definido o tamanho inicial da corda como a distância exata até o alvo
	rest_length = (hook_target_node.global_position - player_body.global_position).length()
	
	# é instanciada a malha visual do gancho
	hook_model = hook_scene.instantiate()
	add_child(hook_model)

func retract_hook() -> void:
	is_hook_launched = false
	
	# são destruídos os nós temporários de forma segura
	if hook_target_node:
		hook_target_node.queue_free()
	if hook_model:
		hook_model.queue_free()
	
	hook_detached.emit()

func handle_hook(delta: float) -> void:
	var pull_vector: Vector3 = (hook_target_node.global_position - player_body.global_position).normalized()
	var distance: float = (hook_target_node.global_position - player_body.global_position).length()
	
	# é reduzido o comprimento da corda gradativamente para puxar o jogador
	rest_length = max(0.0, rest_length - (auto_pull_speed * delta))
	
	# é calculada a força da mola elástica sem multiplicadores explosivos
	var spring_force_magnitude: float = stiffness * (distance - rest_length)
	if spring_force_magnitude < 0.0:
		spring_force_magnitude = 0.0
		
	# é calculada a força de amortecimento estrutural
	var relative_velocity: Vector3 = -player_body.velocity
	var damping_force_magnitude: float = damping * relative_velocity.dot(pull_vector)
	var total_force: Vector3 = (spring_force_magnitude + damping_force_magnitude) * pull_vector
	
	# é aplicado um impulso extra direcional caso o botão de pulo seja pressionado
	if Input.is_action_pressed(thrust_action_name):
		player_body.velocity += pull_vector * thrust_mult * delta * 60.0
		
	# é aplicada a força resultante na física do jogador
	player_body.velocity += total_force * delta
	
	# é atualizada a posição da malha visual do gancho
	var source_position: Vector3 = player_body.global_position
	if hook_source:
		source_position = hook_source.global_position
	
	hook_model.extend_from_to(source_position, hook_target_node.global_position, hook_target_normal, delta)
