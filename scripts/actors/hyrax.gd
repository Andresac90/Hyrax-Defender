class_name Hyrax
extends Shootable
## A rock hyrax that pops out to forage, then darts back to safety.
## Never shoot it: a stray flash-pellet spooks it and breaks the combo.

## Emitted once when the hyrax leaves play (escaped, captured or spooked).
signal resolved(hyrax: Hyrax)

@export var exposure_time := 4.5

var _gone := false

@onready var _body: Node3D = $Body


func _ready() -> void:
	GameState.register_hyrax_spawned()
	_body.position.y = -1.0
	create_tween().tween_property(_body, "position:y", 0.0, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(exposure_time, false).timeout.connect(_on_exposure_timeout)


func is_vulnerable() -> bool:
	return not _gone


func capture() -> void:
	if not _resolve():
		return
	GameState.register_hyrax_captured()
	var tween := create_tween()
	tween.tween_property(_body, "scale", Vector3.ONE * 0.01, 0.2)
	tween.tween_callback(queue_free)


func on_shot(_hit_position: Vector3) -> void:
	if not _resolve():
		return
	GameState.register_hyrax_spooked()
	_duck_away()


func _on_exposure_timeout() -> void:
	if not _resolve():
		return
	GameState.register_hyrax_saved()
	_duck_away()


func _resolve() -> bool:
	if _gone:
		return false
	_gone = true
	disable_hits()
	resolved.emit(self)
	return true


func _duck_away() -> void:
	var tween := create_tween()
	tween.tween_property(_body, "position:y", -1.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
