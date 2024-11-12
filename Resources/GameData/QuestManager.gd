class_name QuestManager
extends Node

signal quest_added(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_failed(quest: Quest)
signal quest_stage_advanced(quest: Quest, new_stage: int)
signal rumor_discovered(quest: Quest)

@onready var game_state: GameStateManager = get_node("/root/GameStateManager")
var active_quests: Array[Quest] = []
var completed_quests: Array[Quest] = []
var failed_quests: Array[Quest] = []

func _ready() -> void:
	if !is_instance_valid(game_state):
		game_state = get_node("/root/GameStateManager") as GameStateManager

func generate_new_quest() -> Quest:
	var new_quest = Quest.new().generate_quest(game_state)
	add_quest(new_quest)
	return new_quest

func add_quest(quest: Quest) -> void:
	active_quests.append(quest)
	quest.quest_stage_changed.connect(_on_quest_stage_advanced.bind(quest))
	quest.rumor_discovered.connect(_on_rumor_discovered.bind(quest))
	quest_added.emit(quest)

func update_quests() -> void:
	var current_turn = game_state.current_turn
	for quest in active_quests:
		if quest.is_expired(current_turn):
			_on_quest_failed(quest)
		elif quest.is_active():
			quest.advance_stage()

func _on_quest_stage_advanced(new_stage: int, quest: Quest) -> void:
	print("Quest stage advanced: %s - Stage: %d" % [quest.title, new_stage])
	quest_stage_advanced.emit(quest, new_stage)
	if new_stage > quest.current_requirements.size():
		_on_quest_completed(quest)

func _on_rumor_discovered(quest: Quest) -> void:
	rumor_discovered.emit(quest)

func _on_quest_completed(quest: Quest) -> void:
	active_quests.erase(quest)
	completed_quests.append(quest)
	quest.complete()
	quest_completed.emit(quest)

func _on_quest_failed(quest: Quest) -> void:
	active_quests.erase(quest)
	failed_quests.append(quest)
	quest.fail()
	quest_failed.emit(quest)

func get_active_quests() -> Array[Quest]:
	return active_quests

func get_completed_quests() -> Array[Quest]:
	return completed_quests

func get_failed_quests() -> Array[Quest]:
	return failed_quests

func serialize() -> Dictionary:
	return {
		"active_quests": active_quests.map(func(q): return q.serialize()),
		"completed_quests": completed_quests.map(func(q): return q.serialize()),
		"failed_quests": failed_quests.map(func(q): return q.serialize())
	}

func deserialize(data: Dictionary) -> void:
	active_quests = data["active_quests"].map(func(q): return Quest.deserialize(q))
	completed_quests = data["completed_quests"].map(func(q): return Quest.deserialize(q))
	failed_quests = data["failed_quests"].map(func(q): return Quest.deserialize(q))
	for quest in active_quests:
		quest.quest_stage_changed.connect(_on_quest_stage_advanced.bind(quest))
		quest.rumor_discovered.connect(_on_rumor_discovered.bind(quest))
