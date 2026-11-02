class_name Shootable
extends Area3D
## Base for anything a flash-pellet can hit. Keep collision on layer 2 ("targets").


## Called by the level when a shot ray hits this target.
func on_shot(_hit_position: Vector3) -> void:
	pass


## Stops this target from intercepting further shots (e.g. while fleeing).
func disable_hits() -> void:
	set_deferred("collision_layer", 0)
