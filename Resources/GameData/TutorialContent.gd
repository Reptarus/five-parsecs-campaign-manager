class_name TutorialContent
extends Resource

@export var tutorial_steps: Dictionary = {
	"quick_start": {
		"intro": {
			"title": "Welcome to the Tutorial",
			"content": "Let's get started with the basics.",
			"next_step": "movement"
		},
		"movement": {
			"title": "Basic Movement",
			"content": "Learn how to move your character.",
			"next_step": "combat"
		},
		"combat": {
			"title": "Combat Basics",
			"content": "Learn the combat system.",
			"next_step": null
		}
	},
	"advanced": {
		"intro": {
			"title": "Advanced Tutorial",
			"content": "Let's dive into advanced mechanics.",
			"next_step": "tactics"
		},
		"tactics": {
			"title": "Advanced Tactics",
			"content": "Learn advanced tactical moves.",
			"next_step": null
		}
	}
}

func get_step_content(step_id: String) -> Dictionary:
	for track in tutorial_steps:
		if step_id in tutorial_steps[track]:
			return tutorial_steps[track][step_id]
	return {} 
