class_name StageData
extends Resource
## Tuning and look for one stage. Create new stages as .tres files in res://data/stages/.

@export var id: StringName = &"stage"
@export var display_name := "Stage"
@export_multiline var description := ""
## Same seed = same spawn pattern every run, so players can learn it.
@export var rng_seed := 1
## Time for the camera to travel the whole rail (the GDD targets 3–5 minutes).
@export var duration_sec := 180.0

@export_group("Pacing")
@export var first_encounter_delay := 2.0
@export var encounter_interval_min := 2.5
@export var encounter_interval_max := 4.0
## How long a hyrax stays out before escaping safely.
@export var hyrax_exposure_time := 4.5

@export_group("Threats")
@export var eagle_weight := 1.0
@export var leopard_weight := 1.0
@export var snake_weight := 1.0
@export var rock_weight := 0.5
## Chance that a leopard or snake breaks off and rushes the screen.
@export_range(0.0, 1.0) var rush_chance := 0.15

@export_group("Look")
@export var ground_color := Color(0.62, 0.5, 0.36)
@export var prop_color := Color(0.5, 0.42, 0.36)
@export_range(0.0, 1.0) var prop_density := 0.6
