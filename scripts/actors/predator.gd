class_name Predator
extends Shootable
## A predator that stalks a hyrax. Tag it with a flash-pellet and it flees.
## Some predators break off and rush the screen instead: tag them before
## rush_time_limit runs out or the player loses a life.

enum State { STALKING, RUSHING, FLEEING }

const CATCH_DISTANCE := 0.5

@export var speed := 4.0
@export var points := 100
@export var rush_points := 200
@export var can_rush := true
@export var rush_time_limit := 1.6
@export var flies := false
## Height above the hyrax this predator strikes at.
@export var strike_height := 0.3

@export_group("Spawn offset from prey")
@export var spawn_side_distance := 10.0
@export var spawn_height := 0.0

var state := State.STALKING

var _prey: Hyrax
var _camera: Camera3D
var _will_rush := false
var _rush_trigger_distance := 0.0
var _rush_from := Vector3.ZERO
var _rush_elapsed := 0.0


## Call after the predator is in the tree and positioned.
func setup(prey: Hyrax, camera: Camera3D, will_rush: bool) -> void:
	_prey = prey
	_camera = camera
	_will_rush = will_rush and can_rush
	# Rushers break off halfway to their prey.
	_rush_trigger_distance = global_position.distance_to(_strike_point()) * 0.5
	prey.resolved.connect(_on_prey_resolved)


func _physics_process(delta: float) -> void:
	match state:
		State.STALKING:
			_stalk(delta)
		State.RUSHING:
			_rush(delta)


func on_shot(_hit_position: Vector3) -> void:
	if state == State.FLEEING:
		return
	GameState.register_tag(rush_points if state == State.RUSHING else points)
	_flee()


func _stalk(delta: float) -> void:
	if not is_instance_valid(_prey):
		_flee()
		return
	var goal := _strike_point()
	_face(goal)
	global_position = global_position.move_toward(goal, speed * delta)
	var distance := global_position.distance_to(goal)
	if _will_rush and distance <= _rush_trigger_distance:
		_start_rush()
	elif distance <= CATCH_DISTANCE:
		_prey.capture()
		_flee()


func _start_rush() -> void:
	state = State.RUSHING
	_rush_from = global_position
	_rush_elapsed = 0.0
	_prey.resolved.disconnect(_on_prey_resolved)
	GameState.notify_rush()


func _rush(delta: float) -> void:
	_rush_elapsed += delta
	var t := clampf(_rush_elapsed / rush_time_limit, 0.0, 1.0)
	var goal := _camera.global_position - _camera.global_basis.z * 1.5 + Vector3.DOWN * 0.4
	_face(goal)
	# Ease in so the lunge accelerates toward the screen.
	global_position = _rush_from.lerp(goal, t * t)
	if t >= 1.0:
		GameState.take_damage()
		queue_free()


func _flee() -> void:
	if state == State.FLEEING:
		return
	state = State.FLEEING
	disable_hits()
	var away := global_position - _camera.global_position
	away.y = 0.0
	away = away.normalized() * 6.0
	if flies:
		away += Vector3.UP * 6.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "global_position", global_position + away, 0.6)
	tween.tween_property(self, "scale", Vector3.ONE * 0.05, 0.6).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


func _on_prey_resolved(_hyrax: Hyrax) -> void:
	# The hyrax escaped or was taken by something else; nothing left to hunt.
	if state == State.STALKING:
		_flee()


func _strike_point() -> Vector3:
	return _prey.global_position + Vector3.UP * strike_height


func _face(target: Vector3) -> void:
	var flat := Vector3(target.x, global_position.y, target.z)
	if global_position.distance_squared_to(flat) > 0.0025:
		look_at(flat, Vector3.UP)
