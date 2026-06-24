extends CharacterBody3D

@onready var status_manager: StatusEffectManager = $StatusEffectManager
@onready var vhs_glitch: ColorRect = $HUD/PostProcessingLayer/ColorRect

signal atlas_updated(registry: Dictionary)

@export_group("stealth settings")
@export var crouch_speed: float = 4.0
@export var crouch_camera_y_drop: float = -0.6
var is_crouching: bool = false

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
@onready var animation_player: AnimationPlayer = $CameraHolder/Camera/AnimationPlayer
var is_book_open: bool = false

@export_group("binoculos settings")
@export var zoom_fov: float = 30.0 
@export var lente_ui: ColorRect 
@export var anim_binoculo: AnimationPlayer 
var is_scanning: bool = false
var is_zoomed: bool = false 

@export_group("atlas system")
@export var scan_ui_label: Label 
@export var required_scan_time: float = 2.0
var atlas_registry: Dictionary = {}
var current_scan_target: Node3D = null
var current_scan_time: float = 0.0
var total_entities_to_scan: int = 0
var scanned_entities_count: int = 0
var is_level_finished: bool = false

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
var has_branch: bool = false 
var equipped_item: ItemData = null

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

	trigger_power_on_glitch()

func trigger_power_on_glitch() -> void:
	if not is_instance_valid(vhs_glitch) or not vhs_glitch.material:
		return

	# é forçado um estado limpo antes de animar -- o material pode estar em
	# cache com valores deixados pelo tween de morte da execucao anterior
	# (reload_current_scene NAO recria o ShaderMaterial do zero).
	vhs_glitch.material.set_shader_parameter("crt_power_off", 1.0)
	vhs_glitch.material.set_shader_parameter("glitch_intensity", 1.0)
	vhs_glitch.material.set_shader_parameter("pixel_size", 1.0)

	var tween: Tween = create_tween()

	# a tela "liga" -- a linha fina (crt_power_off = 1.0) se expande até a
	# imagem cheia (crt_power_off = 0.0)
	tween.tween_property(
		vhs_glitch.material,
		"shader_parameter/crt_power_off",
		0.0,
		0.6
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# pico de ruido acompanhando o ligamento, assentando em 1.0 (idle)
	tween.parallel().tween_property(
		vhs_glitch.material,
		"shader_parameter/glitch_intensity",
		1.0,
		0.6
	).from(8.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func initialize_atlas(entities_list: Array[String]) -> void:
	# é resetado o registro do atlas para a nova fase.
	atlas_registry.clear()
	scanned_entities_count = 0
	is_level_finished = false
	total_entities_to_scan = entities_list.size()

	# é populado o dicionario com as entidades definidas como nao descobertas.
	for entity_name in entities_list:
		atlas_registry[entity_name] = false
	
	# é populada a interface inicial com dados vazios/desconhecidos.
	atlas_updated.emit(atlas_registry)
		
	print("atlas initialized with ", total_entities_to_scan, " entities.")

func handle_scanning(delta: float) -> void:
	# é interrompida a execucao caso o binoculo nao esteja ativo ou a fase ja tenha acabado.
	if not is_scanning or not is_zoomed or is_level_finished:
		_reset_scan_state()
		return

	var collider: Node3D = hook_raycast.get_collider() as Node3D

	# é validado se o objeto mirado é um inimigo.
	if collider and collider.is_in_group("enemies"):
		
		# é extraido o id da entidade diretamente da cena original para evitar bugs de numeracao de instanciacao.
		var entity_id: String = collider.scene_file_path.get_file().get_basename()
		
		# é verificado se a entidade pertence ao bioma e se ainda nao foi descoberta.
		if atlas_registry.has(entity_id) and not atlas_registry[entity_id]:
			
			# é reiniciado o temporizador se o jogador mudar de alvo.
			if current_scan_target != collider:
				current_scan_target = collider
				current_scan_time = 0.0
				
			# é incrementado o tempo de foco no alvo.
			current_scan_time += delta
			
			# é calculada e formatada a porcentagem para a interface.
			var progress: int = int((current_scan_time / required_scan_time) * 100)
			_update_scan_ui("< ESCANEANDO... >" + str(progress) + "%")
			
			# é efetivada a descoberta caso o tempo seja atingido.
			if current_scan_time >= required_scan_time:
				_register_discovery(entity_id)
		else:
			_update_scan_ui("< SALVO NO ATLAS > ")
			current_scan_time = 0.0
	else:
		# é resetado o estado se olhar para o cenario.
		_reset_scan_state()
		_update_scan_ui("< SCANNER FUNCIONANDO >")

func _register_discovery(entity_id: String) -> void:
	# é marcada a entidade como descoberta no dicionario.
	atlas_registry[entity_id] = true
	scanned_entities_count += 1
	current_scan_time = 0.0
	current_scan_target = null
	
	_update_scan_ui("discovered: " + entity_id + "!")
	print("atlas updated: ", entity_id)
	
	# é emitido o sinal passando o dicionario atualizado para a interface.
	atlas_updated.emit(atlas_registry)
	
	# é validada a condicao de vitoria da fase.
	if scanned_entities_count >= total_entities_to_scan:
		is_level_finished = true
		_update_scan_ui("< DIMENSÃO COMPLETA! SAIA DAQUI! >")
		print("all entities found. level finished flag set to true.")

func _reset_scan_state() -> void:
	# sao limpos os dados de escaneamento atual.
	current_scan_target = null
	current_scan_time = 0.0

func _update_scan_ui(text_message: String) -> void:
	# é atualizado o componente de texto da interface, se ele existir.
	if scan_ui_label:
		scan_ui_label.text = text_message

func handle_attack(delta: float) -> void:
	if not has_branch or is_book_open or is_scanning:
		return

	if Input.is_action_just_pressed("LMB"):
		is_charging_attack = true
		attack_hold_time = 0.0
		
		if weapon_anim:
			weapon_anim.play("heavy_charge")

	if is_charging_attack:
		attack_hold_time += delta

	if Input.is_action_just_released("LMB") and is_charging_attack:
		is_charging_attack = false
		
		var damage: int = 50

		if attack_hold_time >= 0.5:
			damage = 100
			if weapon_anim:
				weapon_anim.play("heavy_swing")
		else:
			if weapon_anim:
				weapon_anim.play("quick_swing")

		if status_manager:
			damage = int(damage * status_manager.damage_multiplier)

		perform_melee_attack(damage)

func perform_melee_attack(damage: int) -> void:
	var space_state = get_world_3d().direct_space_state
	var screen_center = get_viewport().size / 2.0
	var ray_origin = camera.project_ray_origin(screen_center)
	var ray_end = ray_origin + camera.project_ray_normal(screen_center) * attack_range

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self] 

	var result = space_state.intersect_ray(query)

	if result and result.collider.is_in_group("enemies"):
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage)
	
func _physics_process(delta: float) -> void:
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
	handle_scanning(delta)
	
	move_and_slide()
	handle_crouch()
	update_ui()

func equip_item(item: ItemData) -> void:
	equipped_item = item
	print("New equipment stored: ", item.display_name)

func use_equipped_item() -> void:
	if not equipped_item:
		print("No equipment available to trigger.")
		return
		
	print("Activating equipment: ", equipped_item.display_name)
	for effect in equipped_item.effects:
		if effect:
			effect.apply(self)
	
	equipped_item = null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_book_open:
		rotation_degrees.y -= event.relative.x * 0.06 * mouse_sensitivity
		camera.rotation_degrees.x -= event.relative.y * 0.06 * mouse_sensitivity
		camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -90.0, 90.0)
		
	if event.is_action_pressed("action_toggle_book"):
		toggle_book()

	if event.is_action_pressed("action_use_item"):
		use_equipped_item()
		
	if event.is_action_pressed("action_scan"):
		toggle_binoculos()

func handle_state_speeds() -> void:
	if hook_controller.is_hook_launched and not is_on_floor():
		current_max_speed = hook_speed
	elif is_crouching:
		current_max_speed = crouch_speed
	elif Input.is_action_pressed("action_run") and is_on_floor():
		current_max_speed = run_speed
	else:
		current_max_speed = walk_speed

	if status_manager:
		current_max_speed *= status_manager.speed_multiplier

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
	if is_book_open:
		movement_vector = Vector3.ZERO
		movement_direction = Vector2.ZERO

	if movement_direction.length() > 0.0:
		velocity.x = lerpf(velocity.x, movement_vector.x * current_max_speed, acceleration * current_control * delta)
		velocity.z = lerpf(velocity.z, movement_vector.z * current_max_speed, acceleration * current_control * delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, deceleration * current_control * delta)
		velocity.z = lerpf(velocity.z, 0.0, deceleration * current_control * delta)
		
	if is_on_floor():
		current_jumps = 0
	elif current_jumps == 0:
		current_jumps = 1

	if not is_on_floor() and not is_wallrunning:
		velocity.y -= gravity * delta

	var total_jumps: int = max_jumps
	if status_manager:
		total_jumps += status_manager.extra_jumps

	if Input.is_action_just_pressed("action_jump") and not is_wallrunning and not is_book_open:
		if current_jumps < total_jumps:
			velocity.y = jump_force
			current_jumps += 1

func handle_dash(movement_vector: Vector3) -> void:
	if is_book_open:
		return
		
	if Input.is_action_just_pressed("action_dash") and current_dash_cooldown <= 0.0:
		var dash_dir: Vector3 = movement_vector
		
		if dash_dir == Vector3.ZERO:
			dash_dir = - transform.basis.z.normalized()
			
		velocity += dash_dir * dash_force
		current_dash_cooldown = dash_cooldown

func handle_wallrun(movement_direction: Vector2, delta: float) -> void:
	if not left_wall_raycast or not right_wall_raycast or is_book_open:
		return

	var is_touching_wall: bool = left_wall_raycast.is_colliding() or right_wall_raycast.is_colliding()
	var is_moving_forward: bool = movement_direction.y < 0.0

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

	# Applies smooth vertical offset when stealthing
	if is_crouching:
		target_cam_pos.y = crouch_camera_y_drop

	# é calculada a oscilação estabilizada da visão com seno e cosseno
	if is_on_floor() and movement_direction.length() > 0.0 and not is_book_open:
		var speed_ratio: float = velocity.length() / walk_speed
		bob_time += delta * bob_frequency * speed_ratio
		
		target_cam_pos.y += sin(bob_time) * bob_amplitude
		target_cam_pos.x = cos(bob_time * 0.5) * bob_amplitude

	camera.position.y = lerpf(camera.position.y, target_cam_pos.y, delta * 10.0)
	camera.position.x = lerpf(camera.position.x, target_cam_pos.x, delta * 10.0)

	var target_tilt: float = 0.0
	var target_fov: float = base_fov
	
	if is_zoomed:
		target_fov = zoom_fov
		target_tilt = - movement_direction.x * base_tilt_angle
	elif hook_controller.is_hook_launched:
		var lateral_velocity: float = velocity.dot(transform.basis.x)
		target_tilt = clamp(-lateral_velocity * hook_tilt_multiplier, -30.0, 30.0)
		target_fov = hook_fov
	else:
		target_tilt = - movement_direction.x * base_tilt_angle
		
	camera.rotation_degrees.z = lerpf(camera.rotation_degrees.z, target_tilt, tilt_speed * delta)
	camera.fov = lerpf(camera.fov, target_fov, fov_transition_speed * delta)

func update_ui() -> void:
	if hook_raycast.is_colliding() and not hook_controller.is_hook_launched:
		crosshair.texture = hook_available_texture
	else:
		crosshair.texture = hook_not_available_texture

func take_damage(amount: int) -> void:
	if status_manager and status_manager.is_invincible:
		return

	current_health -= amount

	if health_bar:
		health_bar.value = current_health

	if current_health <= 0:
		die()
	else:
		trigger_damage_glitch(amount)

func trigger_damage_glitch(amount: int) -> void:
	if not is_instance_valid(vhs_glitch) or not vhs_glitch.material:
		return

	# normaliza o dano relativo a vida maxima (evita divisao por zero se max_health for 0)
	var damage_ratio: float = clampf(float(amount) / float(max(max_health, 1)), 0.0, 1.0)
	var peak_glitch: float = lerpf(3.0, 9.0, damage_ratio)
	var glitch_duration: float = 0.4 + damage_ratio * 0.3

	var tween: Tween = create_tween()

	tween.tween_property(
		vhs_glitch.material,
		"shader_parameter/glitch_intensity",
		1.0,
		glitch_duration
	).from(peak_glitch).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# hits pesados (>60% do dano relativo) ganham um burst extra de pixelizacao em paralelo
	if damage_ratio > 0.6:
		var peak_pixel: float = lerpf(3.0, 7.0, damage_ratio)
		tween.parallel().tween_property(
			vhs_glitch.material,
			"shader_parameter/pixel_size",
			1.0,
			0.25
		).from(peak_pixel).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func die() -> void:
	if not is_instance_valid(vhs_glitch) or not vhs_glitch.material:
		get_tree().reload_current_scene()
		return
		
	var tween: Tween = create_tween()
	
	# Rapidly spikes the static noise right before the screen dies
	tween.tween_property(
		vhs_glitch.material,
		"shader_parameter/glitch_intensity",
		10.0,
		0.1
	)
	
	# Triggers the CRT TV shutdown effect over 0.5 seconds
	tween.tween_property(
		vhs_glitch.material,
		"shader_parameter/crt_power_off",
		1.0,
		0.5
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	# Waits for the shutdown animation to finish before reloading
	await tween.finished
	get_tree().reload_current_scene()

func equip_branch() -> void:
	has_branch = true
	if weapon_mesh:
		weapon_mesh.visible = true
	if weapon_anim:
		weapon_anim.play("RESET")
func toggle_book() -> void:
	if animation_player == null:
		print("🚨 [ERRO FATAL] AnimationPlayer não encontrado!")
		return
		
	if is_scanning:
		return

	is_book_open = !is_book_open
	
	if is_book_open:
		animation_player.play("open_book")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		animation_player.play_backwards("open_book")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_binoculos() -> void:
	if is_book_open:
		return

	is_scanning = !is_scanning 
	
	if is_scanning:
		if anim_binoculo:
			anim_binoculo.play("put_on")
			await anim_binoculo.animation_finished
			
		if is_scanning: 
			if lente_ui:
				lente_ui.show()
			is_zoomed = true 
	else:
		is_zoomed = false 
		
		if lente_ui:
			lente_ui.hide()
			
		if anim_binoculo:
			anim_binoculo.play_backwards("put_on")
	  
func handle_crouch() -> void:
	# Activates stealth mode while the key is held and the player is grounded
	if Input.is_action_pressed("action_stealth") and is_on_floor():
		is_crouching = true
	else:
		is_crouching = false
