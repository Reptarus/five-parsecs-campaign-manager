# Logbook.gd
extends Control

const LOGBOOK_DIR = "user://logbook/"
var current_campaign_turn = 0
var game_state: GameState

enum ConnectionStrength { WEAK, MODERATE, STRONG }

func _ready():
	create_logbook_directory()
	$MarginContainer/VBoxContainer/EntryList.connect("item_selected", Callable(self, "_on_entry_selected"))
	$MarginContainer/VBoxContainer/NewEntryButton.connect("pressed", Callable(self, "_on_new_entry_pressed"))
	$MarginContainer/VBoxContainer/SaveEntryButton.connect("pressed", Callable(self, "_on_save_entry_pressed"))
	$MarginContainer/VBoxContainer/DeleteEntryButton.connect("pressed", Callable(self, "_on_delete_entry_pressed"))
	$MarginContainer/VBoxContainer/BackButton.connect("pressed", Callable(self, "_on_back_pressed"))
	load_existing_entries()

func create_logbook_directory():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists(LOGBOOK_DIR):
		dir.make_dir(LOGBOOK_DIR)

func load_existing_entries():
	var dir = DirAccess.open(LOGBOOK_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".txt"):
				$MarginContainer/VBoxContainer/EntryList.add_item(file_name.get_basename())
			file_name = dir.get_next()

func _on_entry_selected(index):
	var entry_name = $MarginContainer/VBoxContainer/EntryList.get_item_text(index)
	var content = load_entry(entry_name)
	$MarginContainer/VBoxContainer/EntryContent.text = content

func _on_new_entry_pressed():
	current_campaign_turn += 1
	var entry_content = generate_entry_content()
	$MarginContainer/VBoxContainer/EntryContent.text = entry_content

func _on_save_entry_pressed():
	var entry_name = "Turn_" + str(current_campaign_turn)
	var content = $MarginContainer/VBoxContainer/EntryContent.text
	save_entry(entry_name, content)
	if not $MarginContainer/VBoxContainer/EntryList.has_item(entry_name):
		$MarginContainer/VBoxContainer/EntryList.add_item(entry_name)

func _on_delete_entry_pressed():
	var selected = $MarginContainer/VBoxContainer/EntryList.get_selected_items()
	if selected.size() > 0:
		var entry_name = $MarginContainer/VBoxContainer/EntryList.get_item_text(selected[0])
		delete_entry(entry_name)
		$MarginContainer/VBoxContainer/EntryList.remove_item(selected[0])
		$MarginContainer/VBoxContainer/EntryContent.text = ""

func _on_back_pressed():
	get_node("/root/Main").load_scene("res://scenes/campaign/CampaignDashboard.tscn")

func generate_entry_content():
	# This function would generate the entry content based on the campaign turn events
	# For now, we'll use a placeholder
	return "Campaign Turn " + str(current_campaign_turn) + "\n\n" + get_random_summary()

func get_random_summary():
	var summaries = [
		"The crew ventured into the unknown, facing challenges that tested their mettle.",
		"Tensions rose as rival factions vied for control of valuable resources.",
		"An unexpected ally emerged from the shadows, offering aid in exchange for future favors.",
		"The echoes of battle faded, leaving behind both scars and valuable experience.",
		"A mysterious artifact was uncovered, its purpose and origin shrouded in secrecy."
	]
	return summaries[randi() % summaries.size()]

func save_entry(entry_name, content):
	var file = FileAccess.open(LOGBOOK_DIR + entry_name + ".txt", FileAccess.WRITE)
	file.store_string(content)
	file.close()

func load_entry(entry_name):
	var file = FileAccess.open(LOGBOOK_DIR + entry_name + ".txt", FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	return content

func delete_entry(entry_name):
	var dir = DirAccess.open(LOGBOOK_DIR)
	dir.remove(entry_name + ".txt")

# Function to be called at the end of each campaign turn
func create_new_entry(campaign_data: Dictionary) -> void:
	current_campaign_turn += 1
	var entry_content = generate_detailed_entry(campaign_data)
	save_entry("Turn_" + str(current_campaign_turn), entry_content)

func generate_detailed_entry(campaign_data: Dictionary) -> String:
	var entry = "[b]Campaign Turn {turn}[/b]\n\n".format({"turn": current_campaign_turn})
	
	# Location
	entry += "[u]Location:[/u] {location}\n\n".format({"location": campaign_data.location.name})
	
	# Crew Status
	entry += "[u]Crew Status:[/u]\n"
	for character in campaign_data.crew:
		entry += "- [b]{name}[/b]: {status}".format({"name": character.name, "status": character.status})
		if character.species in [GlobalEnums.Race.SKULKER, GlobalEnums.Race.KRAG]:
			entry += " ({species})".format({"species": GlobalEnums.Race.keys()[character.species]})
		if character.is_psionic:
			entry += " (Psionic)"
			if not character.psionic_powers.is_empty():
				entry += " - Powers: " + ", ".join(character.psionic_powers)
		entry += "\n"
	entry += "\n"
	
	# Financial Update
	entry += "[u]Financial Update:[/u]\n"
	entry += "Credits: {credits}\n".format({"credits": campaign_data.credits})
	if "credits_earned" in campaign_data:
		entry += "Credits Earned: {earned}\n".format({"earned": campaign_data.credits_earned})
	if "credits_spent" in campaign_data:
		entry += "Credits Spent: {spent}\n".format({"spent": campaign_data.credits_spent})
	entry += "\n"
	
	# Items and Equipment
	if "items_acquired" in campaign_data and campaign_data.items_acquired.size() > 0:
		entry += "[u]Items Acquired:[/u]\n"
		for item in campaign_data.items_acquired:
			entry += "- {item}".format({"item": item.name})
			if item.is_psionic_equipment:
				entry += " (Psionic Equipment)"
			elif item.type in ["Bot Upgrade", "Ship Part"]:
				entry += " (New Kit)"
			entry += "\n"
		entry += "\n"
	
	if "items_lost" in campaign_data and campaign_data.items_lost.size() > 0:
		entry += "[u]Items Lost:[/u]\n"
		for item in campaign_data.items_lost:
			entry += "- {item}\n".format({"item": item})
		entry += "\n"
	
	# Story Points and Psionic Advancement
	entry += "Story Points: {points}\n".format({"points": campaign_data.story_points})
	if "psionic_advancement" in campaign_data:
		entry += "Psionic Advancement: {advancement}\n".format({"advancement": campaign_data.psionic_advancement})
	entry += "\n"
	
	# Quests and Missions
	if "current_quest" in campaign_data:
		entry += "[u]Current Quest:[/u]\n"
		entry += _format_quest_details(campaign_data.current_quest)
		entry += "\n"
	
	if "current_mission" in campaign_data:
		entry += "[u]Current Mission:[/u]\n"
		entry += _format_mission_details(campaign_data.current_mission)
		entry += "\n"
	
	if "completed_quests" in campaign_data and campaign_data.completed_quests.size() > 0:
		entry += "[u]Completed Quests:[/u]\n"
		for quest in campaign_data.completed_quests:
			entry += "- {quest}\n".format({"quest": quest.quest_type})
		entry += "\n"
	
	# Campaign Events
	if "events" in campaign_data and campaign_data.events.size() > 0:
		entry += "[u]Campaign Events:[/u]\n"
		for event in campaign_data.events:
			entry += "- {event}\n".format({"event": event})
		entry += "\n"
	
	# Battle Summary
	if "battle_summary" in campaign_data:
		entry += "[u]Battle Summary:[/u]\n"
		entry += campaign_data.battle_summary + "\n"
		if "unique_kills" in campaign_data:
			entry += "Unique Individuals Defeated: {kills}\n".format({"kills": campaign_data.unique_kills})
		entry += "\n"
	
	# Victory Progress
	if "victory_condition" in campaign_data:
		entry += "[u]Victory Progress:[/u]\n"
		entry += _format_victory_progress(campaign_data.victory_condition)
		entry += "\n"
	
	# Connections and Factions
	if "connections" in campaign_data and campaign_data.connections.size() > 0:
		entry += "[u]Faction Connections:[/u]\n"
		for connection in campaign_data.connections:
			entry += "- {type} between {faction1} and {faction2} ({strength})\n".format({
				"type": ConnectionType.keys()[connection.type],
				"faction1": connection.faction1,
				"faction2": connection.faction2,
				"strength": ConnectionStrength.keys()[connection.strength]
			})
		entry += "\n"
	
	# Notes
	entry += "[u]Notes:[/u]\n"
	
	return entry

func _format_quest_details(quest: Quest) -> String:
	var quest_info = """
	Type: {type}
	Location: {location}
	Objective: {objective}
	Stage: {stage}
	Requirements:
	""".format({
		"type": quest.quest_type,
		"location": quest.location.name,
		"objective": quest.objective,
		"stage": quest.current_stage
	})
	
	for requirement in quest.current_requirements:
		quest_info += "- " + requirement + "\n"
	
	quest_info += "Rewards:\n"
	for reward_type in quest.reward:
		quest_info += "- {type}: {value}\n".format({"type": reward_type, "value": str(quest.reward[reward_type])})
	
	return quest_info

func _format_mission_details(mission: Mission) -> String:
	return """
	Title: {title}
	Type: {type}
	Objective: {objective}
	Difficulty: {difficulty}
	Time Limit: {time_limit} turns
	Rewards: {rewards}
	Description: {description}
	""".format({
		"title": mission.title,
		"type": Mission.Type.keys()[mission.type],
		"objective": Mission.Objective.keys()[mission.objective],
		"difficulty": mission.difficulty,
		"time_limit": mission.time_limit,
		"rewards": str(mission.rewards),
		"description": mission.description
	})

func _format_victory_progress(victory_condition: Dictionary) -> String:
	var progress = ""
	match victory_condition.type:
		"turns":
			progress = "{current}/{target} turns completed".format({
				"current": current_campaign_turn,
				"target": victory_condition.value
			})
		"quests":
			progress = "{current}/{target} quests completed".format({
				"current": game_state.completed_quests.size(),
				"target": victory_condition.value
			})
		"battles":
			progress = "{current}/{target} battles won".format({
				"current": game_state.battles_won,
				"target": victory_condition.value
			})
		"unique_kills":
			progress = "{current}/{target} unique individuals defeated".format({
				"current": game_state.unique_kills,
				"target": victory_condition.value
			})
		"character_upgrades":
			var max_upgrades = game_state.get_max_character_upgrades()
			progress = "{current}/{target} upgrades on a single character".format({
				"current": max_upgrades,
				"target": victory_condition.value
			})
		"multi_character_upgrades":
			var characters_upgraded = game_state.get_characters_with_upgrades(victory_condition.value.upgrades)
			progress = "{current}/{target} characters with {upgrades} upgrades".format({
				"current": characters_upgraded,
				"target": victory_condition.value.characters,
				"upgrades": victory_condition.value.upgrades
			})
	return progress
