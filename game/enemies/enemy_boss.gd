extends "res://game/enemies/enemy_basic.gd"

enum BossState {IDLE, WANDER, GREETING, CHASING, KICKING}
var boss_state: BossState = BossState.IDLE

@export_group("boss animations")
@export var anim_dance: String = "RobotArmature|Dance"
@export var anim_no: String = "RobotArmature|No"
@export var anim_yes: String = "RobotArmature|Yes"
@export var anim_hello: String = "RobotArmature|Hello"
@export var anim_jump: String = "RobotArmature|Jump"

@export_group("boss mechanics")
# Increased significantly for Jolt realistic mass calculations
@export var minion_kick_force: float = 10000.0
@export var minion_kick_range: float = 4.0
@export var jump_force: float = 25.0
@export var jump_forward_multiplier: float = 2.5
@export var minion_seek_radius: float = 15.0
@export var stuck_threshold: float = 1.5

# Applies heavier gravity when falling to prevent floating
@export var fall_gravity_multiplier: float = 2.5 

var state_timer: float = 0.0
var jump_timer: float = 0.0
var stuck_timer: float = 0.0
var wander_direction: Vector3 = Vector3.ZERO
var is_animating_sequence: bool = false

func _ready() -> void:
    # Inherits health, group setup and ragdoll configurations
    super()
    anim_idle = "RobotArmature|Idle"
    anim_walk = "RobotArmature|Walk"
    anim_run = "RobotArmature|Run"
    anim_attack_melee = "RobotArmature|Kick"

func _physics_process(delta: float) -> void:
    if is_knocked_out:
        _monitor_ragdoll_stability()
        return

    if not is_on_floor():
        # Dynamically increases gravity if moving downwards for a heavier impact
        var current_gravity: float = gravity * fall_gravity_multiplier if velocity.y < 0 else gravity
        velocity.y -= current_gravity * delta

    # Prevents movement logic from interfering with sequenced animations (greetings/kicks)
    if is_animating_sequence:
        move_and_slide()
        return

    match boss_state:
        BossState.IDLE:
            _handle_idle(delta)
        BossState.WANDER:
            _handle_wander(delta)
        BossState.CHASING:
            _handle_chasing(delta)

    _check_minion_kick()
    move_and_slide()

func _handle_idle(delta: float) -> void:
    stuck_timer = 0.0
    velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
    velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)

    if _find_player_boss():
        _start_greeting()
        return

    state_timer -= delta
    if state_timer <= 0:
        var rng: float = randf()
        if rng < 0.3:
            _play_random_action()
        else:
            boss_state = BossState.WANDER
            state_timer = randf_range(2.0, 5.0)
            var angle: float = randf_range(0, TAU)
            wander_direction = Vector3(cos(angle), 0, sin(angle))
    else:
        if anim_player.current_animation != anim_idle:
            anim_player.play(anim_idle)

func _get_nearest_minion(max_dist: float) -> Node3D:
    var nearest: Node3D = null
    var min_dist: float = max_dist
    
    for e in get_tree().get_nodes_in_group("enemies"):
        if e == self or not is_instance_valid(e) or e.get("is_knocked_out"):
            continue
            
        var d: float = global_position.distance_to(e.global_position)
        if d < min_dist:
            min_dist = d
            nearest = e
            
    return nearest

func _handle_wander(delta: float) -> void:
    if _find_player_boss():
        _start_greeting()
        return

    var target_minion: Node3D = _get_nearest_minion(minion_seek_radius)
    
    # Actively tracks and walks towards minions if found nearby
    if target_minion:
        var dir: Vector3 = target_minion.global_position - global_position
        dir.y = 0
        if dir.length_squared() > 0.001:
            wander_direction = dir.normalized()
    else:
        state_timer -= delta
        if state_timer <= 0:
            boss_state = BossState.IDLE
            state_timer = randf_range(1.0, 3.0)
            return

    _detect_stuck_state(delta)

    velocity.x = lerpf(velocity.x, wander_direction.x * (move_speed * 0.8), acceleration * delta)
    velocity.z = lerpf(velocity.z, wander_direction.z * (move_speed * 0.8), acceleration * delta)

    if wander_direction.length_squared() > 0.001:
        var look_target: Vector3 = global_position + wander_direction
        var target_transform: Transform3D = transform.looking_at(look_target, Vector3.UP)
        quaternion = quaternion.slerp(target_transform.basis.get_rotation_quaternion(), rotation_speed * delta)

    if anim_player.current_animation != anim_walk:
        anim_player.play(anim_walk)

func _detect_stuck_state(delta: float) -> void:
    # Checks if the boss is trying to move but horizontal velocity is practically zero
    var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
    if horizontal_speed < 1.0 and is_on_floor():
        stuck_timer += delta
        if stuck_timer >= stuck_threshold:
            _break_obstacles()
    else:
        stuck_timer = 0.0

func _break_obstacles() -> void:
    var previous_state: BossState = boss_state
    boss_state = BossState.KICKING
    is_animating_sequence = true
    velocity.x = 0
    velocity.z = 0
    stuck_timer = 0.0

    anim_player.play(anim_attack_melee)
    var kick_length: float = 1.0
    if anim_player.has_animation(anim_attack_melee):
        kick_length = anim_player.get_animation(anim_attack_melee).length

    await get_tree().create_timer(kick_length * 0.4).timeout

    # Scans the area for obstacles (trees/props) to destroy
    var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var sphere: SphereShape3D = SphereShape3D.new()
    sphere.radius = 3.5
    var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
    query.shape = sphere
    query.transform = global_transform
    
    var results: Array[Dictionary] = space_state.intersect_shape(query)
    for res in results:
        var col: Node = res["collider"]
        if col is StaticBody3D:
            var parent: Node = col.get_parent()
            if parent:
                var parent_name_lower: String = parent.name.to_lower()
                var col_name_lower: String = col.name.to_lower()
                
                # Bulletproof structural bypass logic to completely guard the terrain floor mesh
                if parent.has_method("generate_terrain") or col.has_method("generate_terrain"):
                    continue
                if "terrain" in parent_name_lower or "terrain" in col_name_lower:
                    continue
                if "ground" in parent_name_lower or "ground" in col_name_lower:
                    continue
                if "chao" in parent_name_lower or "chao" in col_name_lower:
                    continue
                if parent == get_tree().current_scene or col == get_tree().current_scene:
                    continue
                if parent is Window:
                    continue
                    
                # Deletes the obstacle safely without destroying the main terrain
                parent.queue_free()

    await get_tree().create_timer(kick_length * 0.6).timeout
    is_animating_sequence = false
    boss_state = previous_state

func _play_random_action() -> void:
    is_animating_sequence = true
    var chosen_anim: String = anim_dance if randf() < 0.5 else anim_no
    anim_player.play(chosen_anim)
    
    var anim_length: float = 2.0
    if anim_player.has_animation(chosen_anim):
        anim_length = anim_player.get_animation(chosen_anim).length
        
    # Loops the dance animation 4 times for extended effect
    var loops: int = 4 if chosen_anim == anim_dance else 1
        
    await get_tree().create_timer(anim_length * loops).timeout
    is_animating_sequence = false
    state_timer = randf_range(2.0, 4.0)

func _find_player_boss() -> bool:
    var players: Array = get_tree().get_nodes_in_group("player")
    for p in players:
        # Inherits the FOV and proximity calculations from enemy_basic.gd
        if p is Node3D and _can_see_target(p):
            player = p
            return true
    return false

func _start_greeting() -> void:
    boss_state = BossState.GREETING
    is_animating_sequence = true
    velocity.x = 0
    velocity.z = 0

    var dir: Vector3 = player.global_position - global_position
    dir.y = 0
    if dir.length_squared() > 0.001:
        look_at(global_position + dir, Vector3.UP)

    anim_player.play(anim_yes)
    if anim_player.has_animation(anim_yes):
        await get_tree().create_timer(anim_player.get_animation(anim_yes).length).timeout

    anim_player.play(anim_hello)
    if anim_player.has_animation(anim_hello):
        await get_tree().create_timer(anim_player.get_animation(anim_hello).length).timeout

    is_animating_sequence = false
    boss_state = BossState.CHASING

func _handle_chasing(delta: float) -> void:
    if not is_instance_valid(player):
        boss_state = BossState.IDLE
        return

    var distance: float = global_position.distance_to(player.global_position)
    if distance > lose_target_radius * 1.5:
        player = null
        boss_state = BossState.IDLE
        return

    var dir: Vector3 = player.global_position - global_position
    dir.y = 0
    dir = dir.normalized()

    _detect_stuck_state(delta)

    if distance <= attack_range:
        velocity.x = lerpf(velocity.x, 0.0, acceleration * delta)
        velocity.z = lerpf(velocity.z, 0.0, acceleration * delta)
        anim_player.play(anim_attack_melee)
    else:
        # Random jump execution with forward leap multiplier
        jump_timer -= delta
        if jump_timer <= 0 and is_on_floor():
            velocity.y = jump_force
            velocity.x = dir.x * move_speed * jump_forward_multiplier
            velocity.z = dir.z * move_speed * jump_forward_multiplier
            jump_timer = randf_range(3.0, 5.0)
            anim_player.play(anim_jump)
        elif is_on_floor():
            velocity.x = lerpf(velocity.x, dir.x * move_speed, acceleration * delta)
            velocity.z = lerpf(velocity.z, dir.z * move_speed, acceleration * delta)
            if anim_player.current_animation != anim_jump:
                anim_player.play(anim_run)

    if dir.length_squared() > 0.001 and is_on_floor():
        var target_transform: Transform3D = transform.looking_at(global_position + dir, Vector3.UP)
        quaternion = quaternion.slerp(target_transform.basis.get_rotation_quaternion(), rotation_speed * delta)

func _check_minion_kick() -> void:
    if boss_state == BossState.GREETING or is_animating_sequence:
        return

    var nearest: Node3D = _get_nearest_minion(minion_kick_range)
    if nearest:
        _kick_minion(nearest)

func _kick_minion(minion: Node3D) -> void:
    var previous_state: BossState = boss_state
    boss_state = BossState.KICKING
    is_animating_sequence = true
    velocity.x = 0
    velocity.z = 0

    var dir: Vector3 = minion.global_position - global_position
    dir.y = 0
    if dir.length_squared() > 0.001:
        look_at(global_position + dir, Vector3.UP)

    anim_player.play(anim_attack_melee)
    
    var kick_length: float = 1.0
    if anim_player.has_animation(anim_attack_melee):
        kick_length = anim_player.get_animation(anim_attack_melee).length

    # Waits roughly until the foot makes contact physically
    await get_tree().create_timer(kick_length * 0.4).timeout

    if is_instance_valid(minion) and minion.has_method("knockout"):
        minion.knockout()
        
        # Forces physics frames to ensure the Jolt ragdoll is fully unlocked
        await get_tree().physics_frame
        await get_tree().physics_frame
        
        var bone_sim: PhysicalBoneSimulator3D = minion.get("bone_simulator")
        if bone_sim:
            # FIX 1: Prevents the boss from launching to the sky due to collision overlap
            bone_sim.physical_bones_add_collision_exception(self.get_rid())
            
            var hip: PhysicalBone3D = bone_sim.get_node_or_null("Physical Bone Hips")
            print("HIP:", hip)
            
            if hip:
                var impulse_dir: Vector3
                
                if is_instance_valid(player):
                    impulse_dir = (
                        minion.global_position -
                        global_position
                    ).normalized()
                    impulse_dir.y = 0.5 
                else:
                    impulse_dir = (-global_transform.basis.z + Vector3.UP * 0.8).normalized()

                print("CHUTANDO:", minion.name)
                print("FORCA:", impulse_dir * minion_kick_force)

                minion.apply_ragdoll_impulse(
                    impulse_dir * minion_kick_force
                )
                
                # Creates the domino effect aura around the flying minion
                _attach_projectile_aura(minion, hip)

    await get_tree().create_timer(kick_length * 0.6).timeout
    is_animating_sequence = false
    
    # Resumes previous aggression state to avoid dropping aggro
    boss_state = previous_state if previous_state == BossState.CHASING else BossState.IDLE

func _attach_projectile_aura(minion: Node3D, hip: PhysicalBone3D) -> void:
    var impact_area: Area3D = Area3D.new()
    var collision_shape: CollisionShape3D = CollisionShape3D.new()
    var sphere: SphereShape3D = SphereShape3D.new()
    
    sphere.radius = 1.5
    collision_shape.shape = sphere
    impact_area.add_child(collision_shape)
    
    # Attaches the trigger area to the minion's flying hip
    hip.add_child(impact_area)
    
    # The lambda function that causes the chain reaction
    var chain_reaction = func(body: Node3D):
        if body.is_in_group("enemies") and body != minion and not body.get("is_knocked_out"):
            if body.has_method("knockout"):
                body.knockout()
                
                # Waits briefly for the target's ragdoll to initialize safely
                await body.get_tree().create_timer(0.1).timeout
                
                var target_sim: PhysicalBoneSimulator3D = body.get("bone_simulator")
                if target_sim:
                    # Prevents the two flying minions from colliding and glitching
                    target_sim.physical_bones_add_collision_exception(minion.get_rid())
                    target_sim.physical_bones_add_collision_exception(self.get_rid())
                    
                    var target_hip: PhysicalBone3D = target_sim.get_node_or_null("Physical Bone Hips")
                    if target_hip:
                        # Transfers the momentum of the first minion to the second one
                        target_hip.apply_central_impulse(hip.linear_velocity * 1.5)

    # Connects the lambda dynamically to the area
    impact_area.body_entered.connect(chain_reaction)
    
    # Destroys the area after 3 seconds so corpses don't remain dangerous
    get_tree().create_timer(3.0).timeout.connect(impact_area.queue_free)