extends Resource
class_name TutorialState

enum TutorialTrack {
	STORY_TRACK,
	QUICK_START,
	ADVANCED,
	BATTLE
}

@export var current_track: TutorialTrack
@export var current_step: String = "introduction"
@export var completed_steps: Array[String] = []
@export var is_active: bool = false
@export var can_skip: bool = true

# Track-specific state
@export var story_progress: Dictionary = {}
@export var battle_progress: Dictionary = {}
@export var disabled_features: Array[String] = []

func mark_step_complete(step_id: String) -> void:
	if step_id not in completed_steps:
		completed_steps.append(step_id)

func is_step_completed(step_id: String) -> bool:
	return step_id in completed_steps

func reset() -> void:
	current_step = "introduction"
	completed_steps.clear()
	is_active = false
	story_progress.clear()
	battle_progress.clear()