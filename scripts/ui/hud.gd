class_name GameHUD
extends CanvasLayer
## In-game HUD plus the pause and results panels. Listens to GameState signals.

const MAIN_MENU_SCENE := "res://scenes/menus/main_menu.tscn"

var _warning_tween: Tween
var _damage_tween: Tween

@onready var _score_label: Label = $ScoreLabel
@onready var _combo_label: Label = $ComboLabel
@onready var _lives_label: Label = $LivesLabel
@onready var _ammo_label: Label = $AmmoLabel
@onready var _reload_label: Label = $ReloadLabel
@onready var _warning_label: Label = $WarningLabel
@onready var _track_progress: ProgressBar = $TrackProgress
@onready var _damage_flash: ColorRect = $DamageFlash
@onready var _crosshair: Crosshair = $Crosshair
@onready var _pause_panel: Control = $PausePanel
@onready var _resume_button: Button = $PausePanel/Margin/VBox/ResumeButton
@onready var _pause_restart_button: Button = $PausePanel/Margin/VBox/RestartButton
@onready var _pause_menu_button: Button = $PausePanel/Margin/VBox/MenuButton
@onready var _results_panel: Control = $ResultsPanel
@onready var _results_title: Label = $ResultsPanel/Margin/VBox/Title
@onready var _results_stats: Label = $ResultsPanel/Margin/VBox/Stats
@onready var _retry_button: Button = $ResultsPanel/Margin/VBox/RetryButton
@onready var _results_menu_button: Button = $ResultsPanel/Margin/VBox/MenuButton


func _ready() -> void:
	GameState.score_changed.connect(_on_score_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.ammo_changed.connect(_on_ammo_changed)
	GameState.reload_state_changed.connect(_on_reload_state_changed)
	GameState.damaged.connect(_on_damaged)
	GameState.rush_started.connect(_on_rush_started)
	GameState.run_ended.connect(_on_run_ended)

	_resume_button.pressed.connect(_set_paused.bind(false))
	_pause_restart_button.pressed.connect(_restart)
	_pause_menu_button.pressed.connect(_go_to_menu)
	_retry_button.pressed.connect(_restart)
	_results_menu_button.pressed.connect(_go_to_menu)

	_pause_panel.hide()
	_results_panel.hide()
	_warning_label.hide()
	_set_gameplay_cursor(true)


func _process(_delta: float) -> void:
	_crosshair.position = get_viewport().get_mouse_position()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and GameState.run_active:
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_track_progress(ratio: float) -> void:
	_track_progress.value = ratio


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause_panel.visible = paused
	_set_gameplay_cursor(not paused)
	if paused:
		_resume_button.grab_focus()


func _set_gameplay_cursor(gameplay: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if gameplay else Input.MOUSE_MODE_VISIBLE
	_crosshair.visible = gameplay


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_score_changed(score: int) -> void:
	_score_label.text = str(score)


func _on_combo_changed(combo: int, multiplier: int) -> void:
	_combo_label.text = "x%d   combo %d" % [multiplier, combo]


func _on_lives_changed(lives: int) -> void:
	_lives_label.text = "LIVES  %d" % lives


func _on_ammo_changed(ammo: int, max_ammo: int) -> void:
	_ammo_label.text = "AMMO  %d / %d" % [ammo, max_ammo]
	_crosshair.empty = ammo == 0
	_update_reload_prompt()


func _on_reload_state_changed(_reloading: bool) -> void:
	_update_reload_prompt()


func _update_reload_prompt() -> void:
	if GameState.reloading:
		_reload_label.text = "RELOADING..."
		_reload_label.show()
	elif GameState.ammo == 0:
		_reload_label.text = "RELOAD!   Right-click / Space"
		_reload_label.show()
	else:
		_reload_label.hide()


func _on_damaged() -> void:
	if _damage_tween:
		_damage_tween.kill()
	_damage_flash.color.a = 0.45
	_damage_tween = create_tween()
	_damage_tween.tween_property(_damage_flash, "color:a", 0.0, 0.4)


func _on_rush_started() -> void:
	if _warning_tween:
		_warning_tween.kill()
	_warning_label.modulate.a = 1.0
	_warning_label.show()
	_warning_tween = create_tween()
	_warning_tween.tween_interval(0.9)
	_warning_tween.tween_property(_warning_label, "modulate:a", 0.0, 0.3)
	_warning_tween.tween_callback(_warning_label.hide)


func _on_run_ended(results: Dictionary) -> void:
	_set_gameplay_cursor(false)
	_warning_label.hide()
	_reload_label.hide()

	_results_title.text = "STAGE CLEAR!" if results.cleared else "COLONY OVERRUN"
	var lines := PackedStringArray([
		results.stage_name,
		"",
		"Score:  %d" % results.score,
		"Accuracy:  %d%%   (+%d)" % [roundi(results.accuracy * 100.0), results.accuracy_bonus],
		"Best combo:  %d   (+%d)" % [results.max_combo, results.combo_bonus],
		"Hyraxes saved:  %d / %d   (+%d)" % [results.saved, results.spawned, results.save_bonus],
		"",
		"FINAL SCORE:  %d" % results.final_score,
	])
	if results.rank == 0:
		lines.append("NEW HIGH SCORE!")
	elif results.rank > 0:
		lines.append("#%d on the board   (best %d)" % [results.rank + 1, results.best])
	else:
		lines.append("Best:  %d" % results.best)
	_results_stats.text = "\n".join(lines)
	_results_panel.show()
	_retry_button.grab_focus()
