extends Resource

# Campaign properties
var difficulty: int = 1
var name: String = "Test Campaign"
var id: String = "test_campaign"
var mission_count: int = 0
var completed_missions: Array = []

# Signals
signal campaign_state_changed(property)
signal resource_changed(resource_type, amount)
signal world_changed(world_data)

func initialize():
	difficulty = 1
	name = "Test Campaign"
	id = "test_campaign_" + str(Time.get_unix_time_from_system())
	return true

func get_difficulty():
	return difficulty
	
func set_difficulty(value: int):
	difficulty = value
	emit_signal("campaign_state_changed", "difficulty")
	
func add_enemy_experience(enemy, amount):
	if enemy and enemy.has_method("add_experience"):
		enemy.add_experience(amount)
	return true
	
func advance_difficulty():
	difficulty += 1
	emit_signal("campaign_state_changed", "difficulty")
	return true
