class_name TutorialProgress
extends Resource

# Track completion status
@export var completed_steps: Array[String] = []
@export var completed_tracks: Array[String] = []
@export var current_progress: Dictionary = {}

# Track achievements and milestones
@export var achievements: Dictionary = {
    "first_battle_won": false,
    "first_story_completed": false,
    "first_crew_member_upgraded": false,
    "first_quest_completed": false
}

# Track tutorial statistics
@export var battles_fought: int = 0
@export var story_missions_completed: int = 0
@export var crew_upgrades: int = 0
@export var credits_earned: int = 0

func save_progress() -> void:
	ResourceSaver.save(self, "res://Resources/GameData/TutorialProgress.tres")

func complete_step(step_id: String) -> void:
	if not step_id in completed_steps:
		completed_steps.append(step_id)
		save_progress()

func complete_track(track_id: String) -> void:
	if not track_id in completed_tracks:
		completed_tracks.append(track_id)
		# Update achievements
		match track_id:
			"story_track":
				achievements["first_story_completed"] = true
			"battle":
				achievements["first_battle_won"] = true
		save_progress()

func update_stats(stat_type: String, value: int = 1) -> void:
	match stat_type:
		"battles":
			battles_fought += value
		"story_missions":
			story_missions_completed += value
		"upgrades":
			crew_upgrades += value
		"credits":
			credits_earned += value
	save_progress()

func is_achievement_unlocked(achievement_id: String) -> bool:
	return achievements.get(achievement_id, false) 