class_name FallingRock
extends Shootable
## A loose rock tumbling toward a hyrax. Shoot it apart before it lands.

const IMPACT_RADIUS := 1.2
const GROUND_HEIGHT := 0.5

@export var fall_acceleration := 4.0
@export var points := 50

var _prey: Hyrax
var _fall_speed := 0.0
var _done := false

@onready var _mesh: Node3D = $Mesh


func setup(prey: Hyrax) -> void:
	_prey = prey


func _physics_process(delta: float) -> void:
	if _done:
		return
	_fall_speed += fall_acceleration * delta
	global_position.y -= _fall_speed * delta
	_mesh.rotate_x(delta * 4.0)
	if global_position.y <= GROUND_HEIGHT:
		_land()


func on_shot(_hit_position: Vector3) -> void:
	if _done:
		return
	GameState.register_tag(points)
	_break_apart()


func _land() -> void:
	if is_instance_valid(_prey) and _prey.is_vulnerable():
		var offset := _prey.global_position - global_position
		offset.y = 0.0
		if offset.length() <= IMPACT_RADIUS:
			_prey.capture()
	_break_apart()


func _break_apart() -> void:
	_done = true
	disable_hits()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.15)
	tween.tween_callback(queue_free)
