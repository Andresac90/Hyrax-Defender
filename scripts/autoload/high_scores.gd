extends Node
## Local high-score board (autoload "HighScores"), stored per stage in user://.

const SAVE_PATH := "user://highscores.cfg"
const SECTION := "scores"
const MAX_ENTRIES := 5

var _config := ConfigFile.new()


func _ready() -> void:
	# A missing file just means no scores yet.
	_config.load(SAVE_PATH)


func get_scores(stage_id: StringName) -> Array:
	return _config.get_value(SECTION, String(stage_id), [])


func get_best(stage_id: StringName) -> int:
	var scores := get_scores(stage_id)
	return scores[0] if not scores.is_empty() else 0


## Records a score and returns its 0-based rank, or -1 if it didn't make the board.
func submit(stage_id: StringName, score: int) -> int:
	var scores := get_scores(stage_id).duplicate()
	scores.append(score)
	scores.sort()
	scores.reverse()
	scores = scores.slice(0, MAX_ENTRIES)
	_config.set_value(SECTION, String(stage_id), scores)
	_config.save(SAVE_PATH)
	return scores.find(score)
