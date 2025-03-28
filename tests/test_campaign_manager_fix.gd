@tool
extends SceneTree

const CampaignManagerScript = preload("res://src/core/managers/CampaignManager.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const StoryQuestDataScript = preload("res://src/core/story/StoryQuestData.gd")

func _init():
	print("Testing CampaignManager serialization fix...")
	
	# Create a campaign manager
	var campaign_manager = Node.new()
	campaign_manager.set_script(CampaignManagerScript)
	
	# Create a game state
	var game_state = load("res://src/core/state/GameState.gd").new()
	campaign_manager.game_state = game_state
	
	# Create test missions
	var missions = []
	for i in range(3):
		var mission = StoryQuestDataScript.create_mission(GameEnums.MissionType.PATROL)
		mission.mission_id = "test_mission_" + str(i)
		mission.name = "Test Mission " + str(i)
		mission.description = "Test description " + str(i)
		mission.is_active = i == 1 # Make one active
		mission.is_completed = i == 2 # Make one completed
		missions.append(mission)
	
	# Test serialization
	print("Testing mission serialization...")
	var serialized = campaign_manager._serialize_missions(missions)
	print("Serialized " + str(missions.size()) + " missions successfully")
	
	# Test deserialization
	print("Testing mission deserialization...")
	var deserialized = campaign_manager._deserialize_missions(serialized)
	print("Deserialized " + str(deserialized.size()) + " missions successfully")
	
	# Verify data
	print("Verifying mission data integrity...")
	for i in range(deserialized.size()):
		var original = missions[i]
		var restored = deserialized[i]
		
		assert(original.mission_id == restored.mission_id, "Mission ID mismatch")
		assert(original.name == restored.name, "Mission name mismatch")
		assert(original.is_active == restored.is_active, "Mission active state mismatch")
		assert(original.is_completed == restored.is_completed, "Mission completion state mismatch")
	
	print("All tests passed!")
	quit()   