extends Node
## Global run state (autoload "GameState").
## Owns score, combo, lives, ammo and run statistics so the level, actors and HUD
## talk through signals instead of referencing each other directly.

signal score_changed(score: int)
signal combo_changed(combo: int, multiplier: int)
signal lives_changed(lives: int)
signal ammo_changed(ammo: int, max_ammo: int)
signal reload_state_changed(reloading: bool)
signal damaged
signal rush_started
signal run_ended(results: Dictionary)

const STAGES := [
	preload("res://data/stages/canyon.tres"),
	preload("res://data/stages/scrubland.tres"),
	preload("res://data/stages/rocky_outcrop.tres"),
]

const MAX_LIVES := 3
const MAX_AMMO := 6
const RELOAD_TIME := 0.8
## Every Nth hyrax lost to a predator or rock costs a life.
const CAPTURES_PER_LIFE := 3
const COMBO_PER_MULTIPLIER := 5
const MAX_MULTIPLIER := 8

const SAVE_POINTS := 50
const SPOOK_PENALTY := 100

# End-of-run bonuses (accuracy, highest combo, total hyraxes saved).
const ACCURACY_BONUS := 2000
const COMBO_BONUS := 25
const SAVE_BONUS := 100

var stage: StageData
var run_active := false
var score := 0
var combo := 0
var max_combo := 0
var lives := MAX_LIVES
var ammo := MAX_AMMO
var reloading := false
var shots_fired := 0
var shots_hit := 0
var hyraxes_spawned := 0
var hyraxes_saved := 0
var hyraxes_captured := 0

# Incremented every run so a reload started in an old run can't finish in a new one.
var _run_id := 0


func start_run(new_stage: StageData) -> void:
	stage = new_stage
	_run_id += 1
	run_active = true
	score = 0
	combo = 0
	max_combo = 0
	lives = MAX_LIVES
	ammo = MAX_AMMO
	reloading = false
	shots_fired = 0
	shots_hit = 0
	hyraxes_spawned = 0
	hyraxes_saved = 0
	hyraxes_captured = 0
	score_changed.emit(score)
	combo_changed.emit(combo, get_multiplier())
	lives_changed.emit(lives)
	ammo_changed.emit(ammo, MAX_AMMO)
	reload_state_changed.emit(reloading)


func get_multiplier() -> int:
	return mini(1 + floori(float(combo) / COMBO_PER_MULTIPLIER), MAX_MULTIPLIER)


func get_accuracy() -> float:
	return 0.0 if shots_fired == 0 else float(shots_hit) / shots_fired


## Spends one flash-pellet. Returns false if the player can't shoot right now.
func try_fire() -> bool:
	if not run_active or reloading or ammo <= 0:
		return false
	ammo -= 1
	shots_fired += 1
	ammo_changed.emit(ammo, MAX_AMMO)
	return true


func start_reload() -> void:
	if not run_active or reloading or ammo == MAX_AMMO:
		return
	reloading = true
	reload_state_changed.emit(true)
	var run := _run_id
	await get_tree().create_timer(RELOAD_TIME, false).timeout
	if run != _run_id or not run_active:
		return
	reloading = false
	ammo = MAX_AMMO
	reload_state_changed.emit(false)
	ammo_changed.emit(ammo, MAX_AMMO)


## A shot that hit nothing.
func register_miss() -> void:
	if run_active:
		_break_combo()


## A predator or hazard was tagged.
func register_tag(points: int) -> void:
	if not run_active:
		return
	shots_hit += 1
	_add_combo()
	_add_score(points * get_multiplier())


func register_hyrax_spawned() -> void:
	if run_active:
		hyraxes_spawned += 1


func register_hyrax_saved() -> void:
	if not run_active:
		return
	hyraxes_saved += 1
	_add_combo()
	_add_score(SAVE_POINTS * get_multiplier())


## The player shot a hyrax and scared it off.
func register_hyrax_spooked() -> void:
	if not run_active:
		return
	_break_combo()
	_add_score(-SPOOK_PENALTY)


func register_hyrax_captured() -> void:
	if not run_active:
		return
	hyraxes_captured += 1
	_break_combo()
	if hyraxes_captured % CAPTURES_PER_LIFE == 0:
		_lose_life()


## A rushing predator reached the screen.
func take_damage() -> void:
	if not run_active:
		return
	_break_combo()
	damaged.emit()
	_lose_life()


func notify_rush() -> void:
	if run_active:
		rush_started.emit()


func end_run(cleared: bool) -> void:
	if not run_active:
		return
	run_active = false
	var accuracy := get_accuracy()
	var accuracy_bonus := roundi(accuracy * ACCURACY_BONUS)
	var combo_bonus := max_combo * COMBO_BONUS
	var save_bonus := hyraxes_saved * SAVE_BONUS
	var final_score := score + accuracy_bonus + combo_bonus + save_bonus
	var rank := HighScores.submit(stage.id, final_score)
	run_ended.emit({
		"stage_name": stage.display_name,
		"cleared": cleared,
		"score": score,
		"accuracy": accuracy,
		"accuracy_bonus": accuracy_bonus,
		"max_combo": max_combo,
		"combo_bonus": combo_bonus,
		"saved": hyraxes_saved,
		"spawned": hyraxes_spawned,
		"save_bonus": save_bonus,
		"final_score": final_score,
		"rank": rank,
		"best": HighScores.get_best(stage.id),
	})


func _add_score(amount: int) -> void:
	score = maxi(score + amount, 0)
	score_changed.emit(score)


func _add_combo() -> void:
	combo += 1
	max_combo = maxi(max_combo, combo)
	combo_changed.emit(combo, get_multiplier())


func _break_combo() -> void:
	if combo == 0:
		return
	combo = 0
	combo_changed.emit(combo, get_multiplier())


func _lose_life() -> void:
	lives = maxi(lives - 1, 0)
	lives_changed.emit(lives)
	if lives == 0:
		end_run(false)
