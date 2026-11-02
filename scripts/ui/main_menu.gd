extends Control
## Title screen. Picking a stage drops the player straight into the action.

const LEVEL_SCENE := "res://scenes/game/level.tscn"

@onready var _stage_list: VBoxContainer = $Center/VBox/StageList
@onready var _quit_button: Button = $Center/VBox/QuitButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for stage: StageData in GameState.STAGES:
		var button := Button.new()
		button.text = "%s      Best: %d" % [stage.display_name, HighScores.get_best(stage.id)]
		button.tooltip_text = stage.description
		button.custom_minimum_size = Vector2(560, 72)
		button.add_theme_font_size_override("font_size", 32)
		button.pressed.connect(_start_stage.bind(stage))
		_stage_list.add_child(button)
	_quit_button.pressed.connect(get_tree().quit)
	if _stage_list.get_child_count() > 0:
		_stage_list.get_child(0).grab_focus()


func _start_stage(stage: StageData) -> void:
	GameState.stage = stage
	get_tree().change_scene_to_file(LEVEL_SCENE)
