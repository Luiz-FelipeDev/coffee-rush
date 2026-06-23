extends Area3D

signal chest_opened

@export_group("Loot Configuration")
@export var possible_items: Array[PackedScene]

@export_group("effects")
@export var smoke_particles: GPUParticles3D

@export_group("animation")
@export var animation_player: AnimationPlayer
@export var open_animation_name: StringName = "open"

@export_group("loot")
@export var item_scenes: Array[PackedScene]
@export var item_spawn_marker: Marker3D
@export var min_launch_force: float = 2.0
@export var max_launch_force: float = 4.0

@export_group("interaction")
@export var interaction_action: StringName = "action_interact"

@export_group("ui")
@export var interact_prompt: Label3D

var is_open: bool = false
var has_been_looted: bool = false
var player_in_range: bool = false
var ray_material: ShaderMaterial

func _ready() -> void:
		
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
		rng.randf_range(0, 0), # variação lateral
		rng.randf_range(4.5, 16.5), # lança o item alto
		rng.randf_range(0.5, 2.5) # lança sempre para frente (eixo Z positivo)
	).normalized()
	
	var force: float = rng.randf_range(min_launch_force, max_launch_force)
	
	if item_instance is RigidBody3D:
		item_instance.apply_impulse(random_dir * force)
	else:
		# Kinematic fallback trajectory
		# Multiplicamos o target_offset por 1.5 para "jogar" o item mais longe
		var target_offset: Vector3 = random_dir * (force * 1.5)
		var target_position: Vector3 = spawn_pos + Vector3(target_offset.x, 0.0, target_offset.z)
		var peak_height: float = spawn_pos.y + (force * 1) # Altura do pico do salto
		
		# Tween horizontal (X e Z) roda em paralelo durante toda a duração do arco
		var horizontal_tween: Tween = create_tween().set_parallel(true)
		horizontal_tween.tween_property(item_instance, "global_position:x", target_position.x, 0.5).set_trans(Tween.TRANS_LINEAR)
		horizontal_tween.tween_property(item_instance, "global_position:z", target_position.z, 0.5).set_trans(Tween.TRANS_LINEAR)
		
		# Tween vertical (sobe e desce) roda separado, simultâneo ao horizontal, formando a parábola
		var vertical_tween: Tween = create_tween()
		vertical_tween.tween_property(item_instance, "global_position:y", peak_height, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		vertical_tween.tween_property(item_instance, "global_position:y", target_position.y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# Callback function executed by the AnimationPlayer track
func trigger_smoke_burst() -> void:
	if smoke_particles:
		smoke_particles.emitting = true
