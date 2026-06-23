extends CharacterBody3D

@export_group("health settings")
@export var max_health: int = 100
var current_health: int

@export_group("misc settings")
@export var hook_available_texture: CompressedTexture2D
@export var hook_not_available_texture: CompressedTexture2D

@export var camera: Camera3D 
@export var hook_raycast: RayCast3D 
@export var crosshair: TextureRect 
@export var health_bar: ProgressBar
@export var hook_controller: HookController 

@export var mouse_sensitivity: float = 1.0 

@export_group("ui settings")
# IMPORTANTE: Confirme se o caminho do AnimationPlayer está correto na sua árvore!
@onready var animation_player: AnimationPlayer = $CameraHolder/Camera/AnimationPlayer
var is_book_open: bool = false

@export_group("movement settings")
@export var walk_speed: float = 10.0
@export var run_speed: float = 20.0
@export var hook_speed: float = 40.0
@export var jump_force: float = 10.0 
@export var max_jumps: int = 2 
@export var gravity: float = 20.0 
@export var acceleration: float = 25.0  
@export var deceleration: float = 30.0  

@export_group("control settings")
@export var max_control: float = 1.0
@export var slow_control: float = 0.05
@export var medium_control: float = 0.15
@export var fast_control: float = 0.25
@export var slow_speed: float = 15.0
@export var medium_speed: float = 20.0

@export_group("dash settings")
@export var dash_force: float = 40.0
@export var dash_cooldown: float = 1.5
var current_dash_cooldown: float = 0.0

@export_group("wallrun settings")
@export var left_wall_raycast: RayCast3D
@export var right_wall_raycast: RayCast3D
@export var wallrun_gravity_multiplier: float = 0.1
@export var walljump_side_force: float = 12.0
var is_wallrunning: bool = false
var wall_normal: Vector3 = Vector3.ZERO

@export_group("camera effects")
@export var bob_frequency: float = 16.0
@export var bob_amplitude: float = 0.3
@export var base_tilt_angle: float = 4.0
@export var hook_tilt_multiplier: float = 0.8
@export var tilt_speed: float = 8.0
@export var base_fov: float = 75.0
@export var hook_fov: float = 95.0
@export var fov_transition_speed: float = 6.0
var bob_time: float = 0.0

@export_group("combat system")
@export var attack_range: float = 3.0
var attack_hold_time: float = 0.0
var is_charging_attack: bool = false
var has_branch: bool = true

# Referências para a arma visual e o animador
@onready var weapon_mesh: MeshInstance3D = $CameraHolder/Camera/WeaponBranch
@onready var weapon_anim: AnimationPlayer = $CameraHolder/Camera/WeaponBranch/AnimationPlayer

var current_max_speed: float = 15.0
var current_control: float = 1.0
var current_jumps: int = 0

func _ready() -> void:
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera:
		camera.fov = base_fov

func handle_attack(delta: float) -> void:
	# Impede o ataque caso o jogador não possua o galho
	if not has_branch:
		return

	# Registra o momento exato em que o botão foi pressionado
	if Input.is_action_just_pressed("LMB"):
		is_charging_attack = true
		attack_hold_time = 0.0
		
		# Inicia a animação de preparação para um possível golpe forte
		if weapon_anim:
			weapon_anim.play("heavy_charge")

	# Acumula o tempo enquanto o botão permanece pressionado
	if is_charging_attack:
		attack_hold_time += delta

	# Executa o ataque quando o botão é solto
	if Input.is_action_just_released("LMB") and is_charging_attack:
		is_charging_attack = false
		
		var damage: int = 50 

		if attack_hold_time >= 0.5:
			# Define o dano pesado e toca a animação do golpe forte
			damage = 100
			if weapon_anim:
				weapon_anim.play("heavy_swing")
		else:
			# Toca a animação do golpe rápido caso o clique tenha sido curto
			if weapon_anim:
				weapon_anim.play("quick_swing")

		perform_melee_attack(damage)

func perform_melee_attack(damage: int) -> void:
	var space_state = get_world_3d().direct_space_state
	
	# Obtém o centro exato da tela para onde a mira está apontando
	var screen_center = get_viewport().size / 2.0
	var ray_origin = camera.project_ray_origin(screen_center)
	var ray_end = ray_origin + camera.project_ray_normal(screen_center) * attack_range

	# Dispara um raio invisível da câmera até a distância de ataque
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self] # Impede que o jogador acerte a si mesmo

	var result = space_state.intersect_ray(query)

	# Caso o raio atinja um inimigo, aplica o dano calculado
	if result and result.collider.is_in_group("enemies"):
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage)
	
func _physics_process(delta: float) -> void:
	# é atualizado o temporizador de recarga da esquiva
	if current_dash_cooldown > 0.0:
		current_dash_cooldown -= delta

	var movement_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	var movement_vector: Vector3 = (transform.basis * Vector3(movement_direction.x, 0.0, -movement_direction.y)).normalized()

	handle_state_speeds()
	handle_wallrun(movement_direction, delta)
	handle_dash(movement_vector)
	handle_movement_and_gravity(movement_direction, movement_vector, delta)
	handle_camera_effects(movement_direction, delta)

	handle_attack(delta)
	move_and_slide()
	update_ui()

func _unhandled_input(event: InputEvent) -> void:
	# é processada a rotação da câmera baseada no movimento do mouse
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_book_open:
		rotation_degrees.y -= event.relative.x * 0.06 * mouse_sensitivity
		camera.rotation_degrees.x -= event.relative.y * 0.06 * mouse_sensitivity
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -90.0, 90.0)
		
	# === NOVA PARTE: Detecta o botão que acabamos de criar no Input Map ===
	if event.is_action_pressed("action_toggle_book"):
		toggle_book()

func handle_state_speeds() -> void:
	# é definida a velocidade máxima baseada no estado atual
	if hook_controller.is_hook_launched and not is_on_floor():
		current_max_speed = hook_speed
	elif Input.is_action_pressed("action_run") and is_on_floor():
		current_max_speed = run_speed
	else:
		current_max_speed = walk_speed

	# é calculado o nível de controle aéreo
	if is_on_floor():
		current_control = max_control
	else:
		var current_speed: float = velocity.length()
		if current_speed < slow_speed:
			current_control = slow_control
		elif current_speed < medium_speed:
			current_control = medium_control
		else:
			current_control = fast_control

func handle_movement_and_gravity(movement_direction: Vector2, movement_vector: Vector3, delta: float) -> void:
	# Parar o personagem se o livro estiver aberto
	if is_book_open:
		movement_vector = Vector3.ZERO
		movement_direction = Vector2.ZERO

	# é aplicada a interpolação vetorial responsiva
	if movement_direction.length() > 0.0:
		velocity.x = lerpf(velocity.x, movement_vector.x * current_max_speed, acceleration * current_control * delta)
		velocity.z = lerpf(velocity.z, movement_vector.z * current_max_speed, acceleration * current_control * delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, deceleration * current_control * delta)
		velocity.z = lerpf(velocity.z, 0.0, deceleration * current_control * delta)
		
	# é restaurado o contador de pulos no solo ou deduzido um salto caso inicie uma queda
	if is_on_floor():
		current_jumps = 0
	elif current_jumps == 0:
		current_jumps = 1

	# é processada a gravidade constante em suspensão
	if not is_on_floor() and not is_wallrunning:
		velocity.y -= gravity * delta

	# é validada a execução do pulo com base no limite configurado
	if Input.is_action_just_pressed("action_jump") and not is_wallrunning and not is_book_open:
		if current_jumps < max_jumps:
			velocity.y = jump_force
			current_jumps += 1

func handle_dash(movement_vector: Vector3) -> void:
	# Bloqueia o dash se o livro estiver aberto
	if is_book_open:
		return
		
	# é aplicado o vetor de força instantânea
	if Input.is_action_just_pressed("action_dash") and current_dash_cooldown <= 0.0:
		var dash_dir: Vector3 = movement_vector
		
		if dash_dir == Vector3.ZERO:
			dash_dir = -transform.basis.z.normalized()
			
		velocity += dash_dir * dash_force
		current_dash_cooldown = dash_cooldown

func handle_wallrun(movement_direction: Vector2, delta: float) -> void:
	if not left_wall_raycast or not right_wall_raycast or is_book_open:
		return

	var is_touching_wall: bool = left_wall_raycast.is_colliding() or right_wall_raycast.is_colliding()
	var is_moving_forward: bool = movement_direction.y < 0.0

	# é ativado o estado de corrida na parede reduzindo a gravidade local
	if not is_on_floor() and is_touching_wall and is_moving_forward:
		is_wallrunning = true
		current_jumps = 0 
		
		if left_wall_raycast.is_colliding():
			wall_normal = left_wall_raycast.get_collision_normal()
		else:
			wall_normal = right_wall_raycast.get_collision_normal()

		if velocity.y < 0.0:
			velocity.y -= (gravity * wallrun_gravity_multiplier) * delta

		if Input.is_action_just_pressed("action_jump"):
			velocity.y = jump_force
			velocity += wall_normal * walljump_side_force
			is_wallrunning = false
			current_jumps = 1 
	else:
		is_wallrunning = false

func handle_camera_effects(movement_direction: Vector2, delta: float) -> void:
	var target_cam_pos: Vector3 = Vector3.ZERO

	# é calculada a oscilação estabilizada da visão com seno e cosseno
	if is_on_floor() and movement_direction.length() > 0.0 and not is_book_open:
		var speed_ratio: float = velocity.length() / walk_speed
		bob_time += delta * bob_frequency * speed_ratio
		
		target_cam_pos.y = sin(bob_time) * bob_amplitude
		target_cam_pos.x = cos(bob_time * 0.5) * bob_amplitude

	# é executada a interpolação final da posição física local da câmera
	camera.position.y = lerpf(camera.position.y, target_cam_pos.y, delta * 10.0)
	camera.position.x = lerpf(camera.position.x, target_cam_pos.x, delta * 10.0)

	# é calculada a inclinação dinâmica lateral do eixo de rotação
	var target_tilt: float = 0.0
	var target_fov: float = base_fov
	
	if hook_controller.is_hook_launched:
		var lateral_velocity: float = velocity.dot(transform.basis.x)
		target_tilt = clamp(-lateral_velocity * hook_tilt_multiplier, -30.0, 30.0)
		target_fov = hook_fov
	else:
		target_tilt = -movement_direction.x * base_tilt_angle
		
	# são interpolados os valores de rotação e campo de visão simultaneamente
	camera.rotation_degrees.z = lerpf(camera.rotation_degrees.z, target_tilt, tilt_speed * delta)
	camera.fov = lerpf(camera.fov, target_fov, fov_transition_speed * delta)

func update_ui() -> void:
	# é atualizada a renderização da interface
	if hook_raycast.is_colliding() and not hook_controller.is_hook_launched:
		crosshair.texture = hook_available_texture
	else:
		crosshair.texture = hook_not_available_texture

func take_damage(amount: int) -> void:
	current_health -= amount
	
	if health_bar:
		health_bar.value = current_health
		
	if current_health <= 0:
		die()

func equip_branch() -> void:
	# Concede ao jogador a habilidade de usar o ataque corpo a corpo
	has_branch = true
	
	# Torna o modelo do galho visível e reseta sua posição
	if weapon_mesh:
		weapon_mesh.visible = true
	if weapon_anim:
		weapon_anim.play("RESET")

func die() -> void:
	# Restarts the current scene on death
	get_tree().reload_current_scene()

# === FUNÇÃO QUE CONTROLA O LIVRO ===
# === FUNÇÃO QUE CONTROLA O LIVRO (Agora com anti-bugs!) ===
func toggle_book() -> void:
	# SEGURO DE VIDA: Se o AnimationPlayer não estiver linkado direito, avisa no console e cancela!
	if animation_player == null:
		print("🚨 [ERRO FATAL] AnimationPlayer não encontrado! O caminho '$CameraHolder/Camera/AnimationPlayer' está errado. Arraste ele de novo pro script!")
		return 

	is_book_open = !is_book_open
	
	if is_book_open:
		# Toca a animação do início ao fim (Livro abrindo)
		animation_player.play("open_book")
		
		# Solta o mouse para clicar na interface do livro
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 
	else:
		# Toca a mesma animação de trás pra frente! (Livro fechando)
		animation_player.play_backwards("open_book")
		
		# Prende o mouse de volta para controlar a câmera
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
