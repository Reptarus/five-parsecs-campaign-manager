extends Resource
class_name TutorialState

@export var current_step: String = "introduction"
@export var completed_steps: Array[String] = []
@export var tutorial_type: String = ""
@export var is_active: bool = false

func mark_step_complete(step_id: String) -> void:
	if step_id not in completed_steps:
		completed_steps.append(step_id)

func is_step_completed(step_id: String) -> bool:
	return step_id in completed_steps

func reset() -> void:
	current_step = "introduction"
	completed_steps.clear()
	is_active = false 