extends PanelContainer

@onready var result_banner: Label = %ResultBanner
@onready var turns_label: Label = %TurnsLabel
@onready var enemies_label: Label = %EnemiesLabel
@onready var mvp_label: Label = %MVPLabel
@onready var quest_container: VBoxContainer = %QuestContainer
@onready var story_points_label: Label = %StoryPointsLabel
@onready var rumors_container: VBoxContainer = %RumorsContainer

var game_state_manager: Node

func _ready() -> void:
	game_state_manager = get_node("/root/GameStateManager")
	update_mission_summary()

func update_mission_summary() -> void:
	var mission = game_state_manager.game_state.current_mission
	var victory = mission.is_completed()
	
	# Update result banner
	result_banner.text = "MISSION " + ("SUCCESSFUL" if victory else "FAILED")
	result_banner.add_theme_color_override("font_color", 
		Color(0.2, 1, 0.2) if victory else Color(1, 0.2, 0.2))
	
	# Update battle statistics
	turns_label.text = "Battle Duration: %d Turns" % mission.turn_count
	enemies_label.text = "Enemies Defeated: %d" % game_state_manager.game_state.enemies_defeated_count
	
	# Find MVP
	var mvp = _determine_mvp()
	mvp_label.text = "MVP: %s (%d kills)" % [mvp.name, mvp.battle_kills]
	
	# Update quest progress
	_update_quest_progress()
	
	# Update story points
	var points_earned = _calculate_story_points(victory)
	story_points_label.text = "Story Points Earned: +%d" % points_earned
	game_state_manager.game_state.story_points += points_earned
	
	# Update rumors
	_update_rumors()

func _determine_mvp() -> CrewMember:
	var crew = game_state_manager.get_crew()
	var highest_kills = 0
	var mvp = crew[0]
	
	for member in crew:
		if member.battle_kills > highest_kills:
			highest_kills = member.battle_kills
			mvp = member
	
	return mvp

func _update_quest_progress() -> void:
	var active_quests = game_state_manager.game_state.active_quests
	if active_quests.is_empty():
		quest_container.hide()
		return
		
	quest_container.show()
	for quest in active_quests:
		if quest.has_updates:
			var progress = quest.get_progress_percentage()
			quest_container.get_node("QuestProgress").value = progress
			quest_container.get_node("QuestStatus").text = quest.get_current_objective()

func _calculate_story_points(victory: bool) -> int:
	var base_points = 1
	if victory:
		base_points += 1
	if game_state_manager.game_state.enemies_defeated_count > 5:
		base_points += 1
	return base_points

func _update_rumors() -> void:
	var rumors = game_state_manager.game_state.rumors
	if rumors.is_empty():
		rumors_container.hide()
		return
		
	rumors_container.show()
	var rumors_list = rumors_container.get_node("RumorsList")
	rumors_list.clear()
	for rumor in rumors:
		rumors_list.append_text("• " + rumor + "\n")
