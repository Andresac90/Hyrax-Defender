extends Node3D
## Runs a stage: carries the camera along the rail, spawns hyrax encounters and
## resolves the player's shots.

## Order must match the weights built in _pick_threat().
enum Threat { EAGLE, LEOPARD, SNAKE, ROCK }

const HYRAX_SCENE := preload("res://scenes/actors/hyrax.tscn")
const ROCK_SCENE := preload("res://scenes/actors/falling_rock.tscn")
const PREDATOR_SCENES := {
	Threat.EAGLE: preload("res://scenes/actors/eagle.tscn"),
	Threat.LEOPARD: preload("res://scenes/actors/leopard.tscn"),
	Threat.SNAKE: preload("res://scenes/actors/snake.tscn"),
}

const TARGETS_MASK := 1 << 1  # Physics layer 2, "targets".
const SHOT_RANGE := 200.0
const MISS_FLASH_DISTANCE := 25.0
## No new encounters this close to the end of the track.
const END_QUIET_TIME := 6.0
const PROP_SPACING := 6.0

@export_group("Encounter placement")
@export var spawn_distance_min := 16.0
@export var spawn_distance_max := 24.0
@export var spawn_lateral_range := 6.0
@export var threat_delay_min := 0.4
@export var threat_delay_max := 1.0
@export var rock_drop_height := 9.0

var _stage: StageData
var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _next_encounter_time := 0.0
var _pending_shots: Array[Vector2] = []

@onready var _rail: Path3D = $Rail
@onready var _rail_follow: PathFollow3D = $Rail/RailFollow
@onready var _camera: Camera3D = $Rail/RailFollow/Camera3D
@onready var _ground: MeshInstance3D = $Ground
@onready var _props: Node3D = $Props
@onready var _actors: Node3D = $Actors
@onready var _hud: GameHUD = $HUD


func _ready() -> void:
	# Falls back to the first stage so the scene can be run directly with F6.
	_stage = GameState.stage if GameState.stage != null else GameState.STAGES[0]
	_rng.seed = _stage.rng_seed
	_apply_stage_look()
	_scatter_props()
	_next_encounter_time = _stage.first_encounter_delay
	GameState.run_ended.connect(_on_run_ended)
	GameState.start_run(_stage)


func _process(delta: float) -> void:
	if not GameState.run_active:
		return
	_elapsed += delta
	var ratio := clampf(_elapsed / _stage.duration_sec, 0.0, 1.0)
	_rail_follow.progress_ratio = ratio
	_hud.set_track_progress(ratio)

	if _elapsed >= _next_encounter_time and _elapsed < _stage.duration_sec - END_QUIET_TIME:
		_spawn_encounter()
		_next_encounter_time += _rng.randf_range(_stage.encounter_interval_min, _stage.encounter_interval_max)

	if ratio >= 1.0:
		GameState.end_run(true)


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.run_active:
		return
	if event.is_action_pressed("shoot"):
		# Ray queries are resolved in _physics_process, where the physics space is safe to read.
		_pending_shots.append(get_viewport().get_mouse_position())
	elif event.is_action_pressed("reload"):
		GameState.start_reload()


func _physics_process(_delta: float) -> void:
	for screen_position in _pending_shots:
		_fire(screen_position)
	_pending_shots.clear()


func _fire(screen_position: Vector2) -> void:
	if not GameState.try_fire():
		return
	var origin := _camera.project_ray_origin(screen_position)
	var direction := _camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * SHOT_RANGE, TARGETS_MASK)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if not hit.is_empty() and hit.collider is Shootable:
		hit.collider.on_shot(hit.position)
		_spawn_flash(hit.position)
	else:
		GameState.register_miss()
		_spawn_flash(origin + direction * MISS_FLASH_DISTANCE)


func _spawn_encounter() -> void:
	var forward := -_camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var camera_position := _camera.global_position

	var spot := camera_position \
		+ forward * _rng.randf_range(spawn_distance_min, spawn_distance_max) \
		+ right * _rng.randf_range(-spawn_lateral_range, spawn_lateral_range)
	spot.y = 0.0

	var hyrax: Hyrax = HYRAX_SCENE.instantiate()
	hyrax.exposure_time = _stage.hyrax_exposure_time
	_actors.add_child(hyrax)
	hyrax.global_position = spot
	hyrax.look_at(Vector3(camera_position.x, 0.0, camera_position.z), Vector3.UP)

	# Roll everything now so the pattern only depends on the stage seed.
	var threat := _pick_threat()
	if threat < 0:
		return
	var side := right * (1.0 if _rng.randf() < 0.5 else -1.0)
	var will_rush := _rng.randf() < _stage.rush_chance
	var delay := _rng.randf_range(threat_delay_min, threat_delay_max)
	get_tree().create_timer(delay, false).timeout.connect(_spawn_threat.bind(threat, hyrax, side, will_rush))


func _pick_threat() -> int:
	return _rng.rand_weighted(PackedFloat32Array([
		_stage.eagle_weight,
		_stage.leopard_weight,
		_stage.snake_weight,
		_stage.rock_weight,
	]))


# `prey` is untyped because the hyrax may already be freed when the timer fires.
func _spawn_threat(threat: int, prey, side: Vector3, will_rush: bool) -> void:
	if not GameState.run_active or not is_instance_valid(prey) or not prey.is_vulnerable():
		return
	var origin: Vector3 = prey.global_position

	if threat == Threat.ROCK:
		var rock: FallingRock = ROCK_SCENE.instantiate()
		_actors.add_child(rock)
		rock.global_position = origin + Vector3.UP * rock_drop_height
		rock.setup(prey)
		return

	var predator: Predator = PREDATOR_SCENES[threat].instantiate()
	_actors.add_child(predator)
	predator.global_position = origin + side * predator.spawn_side_distance + Vector3.UP * predator.spawn_height
	predator.setup(prey, _camera, will_rush)


func _spawn_flash(at: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.7)
	light.light_energy = 4.0
	light.omni_range = 4.0

	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.15
	orb_mesh.height = 0.3
	var orb_material := StandardMaterial3D.new()
	orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_material.albedo_color = Color(1.0, 1.0, 0.85)
	orb_mesh.material = orb_material
	var orb := MeshInstance3D.new()
	orb.mesh = orb_mesh
	light.add_child(orb)

	add_child(light)
	light.global_position = at
	var tween := light.create_tween().set_parallel()
	tween.tween_property(light, "light_energy", 0.0, 0.25)
	tween.tween_property(orb, "scale", Vector3.ONE * 3.0, 0.25)
	tween.chain().tween_callback(light.queue_free)


func _apply_stage_look() -> void:
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = _stage.ground_color
	_ground.material_override = ground_material


## Placeholder scenery: random rocks along both sides of the rail.
func _scatter_props() -> void:
	var prop_rng := RandomNumberGenerator.new()
	prop_rng.seed = _stage.rng_seed + 7919
	var material := StandardMaterial3D.new()
	material.albedo_color = _stage.prop_color
	var meshes: Array[PrimitiveMesh] = [BoxMesh.new(), SphereMesh.new(), PrismMesh.new()]
	for mesh in meshes:
		mesh.material = material

	var length := _rail.curve.get_baked_length()
	var offset := 0.0
	while offset < length:
		var frame := _rail.curve.sample_baked_with_rotation(offset)
		for side: float in [-1.0, 1.0]:
			if prop_rng.randf() > _stage.prop_density:
				continue
			var prop := MeshInstance3D.new()
			prop.mesh = meshes[prop_rng.randi() % meshes.size()]
			var size := prop_rng.randf_range(1.5, 6.0)
			prop.scale = Vector3(
				size * prop_rng.randf_range(0.7, 1.4),
				size * prop_rng.randf_range(0.5, 1.5),
				size * prop_rng.randf_range(0.7, 1.4))
			prop.rotation.y = prop_rng.randf() * TAU
			var prop_position := frame.origin + frame.basis.x * side * prop_rng.randf_range(9.0, 35.0)
			prop_position.y = 0.0
			_props.add_child(prop)
			prop.position = prop_position
		offset += PROP_SPACING


func _on_run_ended(_results: Dictionary) -> void:
	_pending_shots.clear()
	_actors.process_mode = Node.PROCESS_MODE_DISABLED
