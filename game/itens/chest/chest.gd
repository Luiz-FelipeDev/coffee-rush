extends Area3D

signal chest_opened

@export_group("animation")
@export var animation_player: AnimationPlayer
@export var open_animation_name: StringName = "open"

@export_group("loot")
@export var item_scenes: Array[PackedScene]
@export var item_spawn_marker: Marker3D
@export var min_launch_force: float = 2.0
@export var max_launch_force: float = 4.0

@export_group("light effect")
@export var light_ray_mesh: MeshInstance3D
@export var beam_rise_duration: float = 0.15
@export var beam_hold_duration: float = 0.4
@export var beam_fade_duration: float = 0.5

@export_group("interaction")
@export var interaction_action: StringName = "action_interact"

@export_group("ui")
@export var interact_prompt: Label3D

var is_open: bool = false
var has_been_looted: bool = false
var player_in_range: bool = false
var ray_material: ShaderMaterial

func _ready() -> void:
	if light_ray_mesh:
		ray_material = light_ray_mesh.material_override
		light_ray_mesh.visible = false
		
	if animation_player:
		# Forces the animation to frame 0.0 and stops it to guarantee a closed state
		animation_player.play(open_animation_name)
		animation_player.seek(0.0, true)
		animation_player.stop()
		
	# Connects directly to the Area3D native signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	# Ignores input completely if the chest is already open
	if not player_in_range or is_open:
		return
		
	if event.is_action_pressed(interaction_action):
		open_chest()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		# Shows the prompt only if the chest is closed
		if interact_prompt and not is_open:
			interact_prompt.visible = true

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		# Hides the prompt when the player leaves the area
		if interact_prompt:
			interact_prompt.visible = false

func open_chest() -> void:
	if is_open or not animation_player:
		return
		
	is_open = true
	
	# Hides the prompt the moment the player opens the chest
	if interact_prompt:
		interact_prompt.visible = false
		
	animation_player.play(open_animation_name)

# Called by the Call Method Track on the frame the lid finishes opening
func _on_chest_opened() -> void:
	chest_opened.emit()
	if not has_been_looted:
		has_been_looted = true
		_spawn_random_item()
		_play_loot_beam()

func _spawn_random_item() -> void:
	if item_scenes.is_empty():
		return
		
	var random_scene: PackedScene = item_scenes.pick_random()
	var item_instance: Node3D = random_scene.instantiate()
	
	get_tree().current_scene.add_child(item_instance)
	
	var spawn_pos: Vector3 = item_spawn_marker.global_position if item_spawn_marker else global_position + Vector3.UP * 0.5
	item_instance.global_position = spawn_pos
	
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	
	var random_dir: Vector3 = Vector3(
		rng.randf_range(-1.0, 1.0), # Aumentado de 0.5 para 1.0 (maior variação lateral)
		rng.randf_range(4.5, 6.5),   # Aumentado de 1.0-1.5 para 2.5-3.5 (muito mais alto)
		rng.randf_range(0.5, 1.5)    # Alterado para lançar sempre para frente (eixo Z positivo)
	).normalized()
	
	var force: float = rng.randf_range(min_launch_force, max_launch_force)
	
	if item_instance is RigidBody3D:
		item_instance.apply_impulse(random_dir * force)
	else:
		# Kinematic fallback trajectory
		# Multiplicamos o target_offset por 1.5 para "jogar" o item mais longe
		var target_offset: Vector3 = random_dir * (force * 1.5) 
		var target_position: Vector3 = spawn_pos + Vector3(target_offset.x, target_offset.z, target_offset.z)
		var peak_height: float = spawn_pos.y + (force * 1) # Altura do 	pico do salto
		
		# Move X and Z in parallel
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(item_instance, "global_position:x", target_position.x, 0.5).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(item_instance, "global_position:z", target_position.z, 0.5).set_trans(Tween.TRANS_LINEAR)
		
		# Move Y (up then down) in sequence on the same tween
		tween.set_parallel(false)
		tween.tween_property(item_instance, "global_position:y", peak_height, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(item_instance, "global_position:y", target_position.y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# Adicione esta variável no topo do seu script, junto com as outras
var loot_tween: Tween

func _play_loot_beam() -> void:
	if not light_ray_mesh or not ray_material:
		return
	
	# Cancel any existing animation before starting a new one
	if loot_tween and loot_tween.is_valid():
		loot_tween.kill()

	# Reset visual state
	ray_material.set_shader_parameter("beam_intensity", 0.0)
	light_ray_mesh.scale.y = 0.0
	light_ray_mesh.visible = true
	
	# Create and store the new tween
	loot_tween = create_tween()
	
	# Rise animation
	loot_tween.tween_property(light_ray_mesh, "scale:y", 1.0, beam_rise_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	loot_tween.parallel().tween_method(
		func(v: float) -> void: ray_material.set_shader_parameter("beam_intensity", v),
		0.0, 1.0, beam_rise_duration
	)
	
	# Hold
	loot_tween.tween_interval(beam_hold_duration)
	
	# Fade out
	loot_tween.tween_method(
		func(v: float) -> void: ray_material.set_shader_parameter("beam_intensity", v),
		1.0, 0.0, beam_fade_duration
	)
	
	# Clean up
	loot_tween.tween_callback(func() -> void: light_ray_mesh.visible = false)

