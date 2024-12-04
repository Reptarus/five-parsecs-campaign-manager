class_name TutorialContent
extends Resource

# Tutorial tracks based on Core Rules
@export var tutorial_tracks: Dictionary = {
	"story_track": {
		"name": "Story Track Tutorial",
		"description": "Learn the narrative elements of Five Parsecs",
		"steps": {
			"introduction": {
				"title": "Story Track Introduction",
				"content": "Welcome to the Story Track system...",
				"required_actions": ["view_story_track"],
				"next_step": "basic_concepts"
			},
			"basic_concepts": {
				"title": "Basic Story Concepts",
				"content": "Story Points and Rumors...",
				"required_actions": ["view_story_points", "view_rumors"],
				"next_step": "first_mission"
			},
			"first_mission": {
				"title": "Your First Story Mission",
				"content": "Time to undertake your first story mission...",
				"required_actions": ["complete_story_mission"],
				"next_step": null
			}
		}
	},
	"quick_start": {
		"name": "Quick Start Tutorial",
		"description": "Learn the basic mechanics",
		"steps": {
			"introduction": {
				"title": "Welcome to Five Parsecs",
				"content": "Let's learn the basic mechanics...",
				"required_actions": ["view_basics"],
				"next_step": "crew_creation"
			},
			# Additional quick start steps...
		}
	}
	# Additional tracks...
}

func get_track_content(track_id: String) -> Dictionary:
	return tutorial_tracks.get(track_id, {})

func get_step_content(track_id: String, step_id: String) -> Dictionary:
	var track = get_track_content(track_id)
	return track.get("steps", {}).get(step_id, {}) 
