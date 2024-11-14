extends Resource
class_name TutorialContent

const TUTORIAL_STEPS := {
	"introduction": {
		"title": "Welcome to Five Parsecs",
		"content": "Welcome to Five Parsecs From Home! Let's learn the basic mechanics.",
		"next_step": "crew_creation",
		"can_skip": true
	},
	"crew_creation": {
		"title": "Creating Your Crew",
		"content": "First, let's create your initial crew members. You'll need a balanced team.",
		"next_step": "mission_setup",
		"required_actions": ["character_created", "crew_named"]
	},
	"mission_setup": {
		"title": "Mission Setup",
		"content": "Now we'll learn how to prepare for missions and understand the basics of deployment.",
		"next_step": "combat_basics",
		"required_actions": ["mission_accepted"]
	},
	"combat_basics": {
		"title": "Combat Basics",
		"content": "Time to learn the fundamental combat mechanics. We'll start with a simple encounter.",
		"next_step": "completion",
		"required_actions": ["battle_completed"]
	},
	"completion": {
		"title": "Tutorial Complete",
		"content": "Congratulations! You've completed the basic tutorial. Ready to start your adventure?",
		"next_step": "",
		"can_skip": false
	}
}

func get_step_content(step_id: String) -> Dictionary:
	if step_id in TUTORIAL_STEPS:
		var content = TUTORIAL_STEPS[step_id]
		content["id"] = step_id
		return content
	return {} 