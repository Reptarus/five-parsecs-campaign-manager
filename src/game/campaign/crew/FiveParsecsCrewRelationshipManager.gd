@tool
class_name FiveParsecsCrewRelationshipManager
extends BaseCrewRelationshipManager

const FiveParsecsCrewMember = preload("res://src/game/campaign/crew/FiveParsecsCrewMember.gd")

# Five Parsecs specific relationship types
enum RelationshipType {
	FRIENDS = 0,
	RIVALS = 1,
	FAMILY = 2,
	PARTNERS = 3,
	MENTOR_STUDENT = 4,
	COMRADES = 5,
	UNEASY_ALLIES = 6,
	FORMER_ENEMIES = 7,
	BUSINESS_ASSOCIATES = 8,
	STRANGERS = 9
}

# Five Parsecs specific crew characteristics
enum CrewCharacteristic {
	MERCENARY = 0,
	EXPLORERS = 1,
	TRADERS = 2,
	SALVAGERS = 3,
	BOUNTY_HUNTERS = 4,
	REBELS = 5,
	SMUGGLERS = 6,
	RESEARCHERS = 7,
	PRIVATEERS = 8,
	COLONISTS = 9
}

func _init() -> void:
	# Initialize the relationship types dictionary
	RELATIONSHIP_TYPES = {
		RelationshipType.FRIENDS: "Friends",
		RelationshipType.RIVALS: "Rivals",
		RelationshipType.FAMILY: "Family",
		RelationshipType.PARTNERS: "Partners",
		RelationshipType.MENTOR_STUDENT: "Mentor and Student",
		RelationshipType.COMRADES: "Comrades",
		RelationshipType.UNEASY_ALLIES: "Uneasy Allies",
		RelationshipType.FORMER_ENEMIES: "Former Enemies",
		RelationshipType.BUSINESS_ASSOCIATES: "Business Associates",
		RelationshipType.STRANGERS: "Strangers"
	}
	
	# Initialize the crew characteristics dictionary
	CREW_CHARACTERISTICS = {
		CrewCharacteristic.MERCENARY: "Mercenary",
		CrewCharacteristic.EXPLORERS: "Explorers",
		CrewCharacteristic.TRADERS: "Traders",
		CrewCharacteristic.SALVAGERS: "Salvagers",
		CrewCharacteristic.BOUNTY_HUNTERS: "Bounty Hunters",
		CrewCharacteristic.REBELS: "Rebels",
		CrewCharacteristic.SMUGGLERS: "Smugglers",
		CrewCharacteristic.RESEARCHERS: "Researchers",
		CrewCharacteristic.PRIVATEERS: "Privateers",
		CrewCharacteristic.COLONISTS: "Colonists"
	}

func roll_crew_characteristic() -> String:
	var roll = randi() % 10
	return CREW_CHARACTERISTICS[roll]

func roll_meeting_story() -> String:
	var stories = [
		"Met during a bar fight on Nexus Prime",
		"Survivors of a colony attack",
		"Former military unit gone rogue",
		"Assembled by a mysterious patron",
		"Escaped prisoners from a labor camp",
		"Crew of a salvage operation gone wrong",
		"Graduates from the same academy",
		"Brought together by a shared enemy",
		"Survivors of a ship crash",
		"Former rivals who joined forces"
	]
	
	return stories[randi() % stories.size()]

func generate_initial_relationships(crew_members: Array) -> void:
	# Call the base implementation
	super.generate_initial_relationships(crew_members)
	
	# Add Five Parsecs specific relationship logic
	_apply_characteristic_effects(crew_members)

func _apply_characteristic_effects(crew_members: Array) -> void:
	# Apply effects based on crew characteristic
	match crew_characteristic:
		CREW_CHARACTERISTICS[CrewCharacteristic.MERCENARY]:
			# Mercenaries have more business-like relationships
			_adjust_relationships_for_mercenaries(crew_members)
		CREW_CHARACTERISTICS[CrewCharacteristic.EXPLORERS]:
			# Explorers have more adventurous bonds
			_adjust_relationships_for_explorers(crew_members)
		CREW_CHARACTERISTICS[CrewCharacteristic.BOUNTY_HUNTERS]:
			# Bounty hunters have more competitive relationships
			_adjust_relationships_for_bounty_hunters(crew_members)
		CREW_CHARACTERISTICS[CrewCharacteristic.REBELS]:
			# Rebels have stronger comradery
			_adjust_relationships_for_rebels(crew_members)
		CREW_CHARACTERISTICS[CrewCharacteristic.SMUGGLERS]:
			# Smugglers have more secretive relationships
			_adjust_relationships_for_smugglers(crew_members)

func _adjust_relationships_for_mercenaries(crew_members: Array) -> void:
	# Mercenaries tend to have more business-like relationships
	for i in range(crew_members.size()):
		for j in range(i + 1, crew_members.size()):
			var char1 = crew_members[i]
			var char2 = crew_members[j]
			
			# 50% chance to make the relationship business-like
			if randf() < 0.5:
				add_relationship(char1, char2, RELATIONSHIP_TYPES[RelationshipType.BUSINESS_ASSOCIATES])

func _adjust_relationships_for_explorers(crew_members: Array) -> void:
	# Explorers tend to have stronger bonds from shared adventures
	for i in range(crew_members.size()):
		for j in range(i + 1, crew_members.size()):
			var char1 = crew_members[i]
			var char2 = crew_members[j]
			
			# 40% chance to make them friends
			if randf() < 0.4:
				add_relationship(char1, char2, RELATIONSHIP_TYPES[RelationshipType.FRIENDS])
			# 20% chance to make them comrades
			elif randf() < 0.2:
				add_relationship(char1, char2, RELATIONSHIP_TYPES[RelationshipType.COMRADES])

func _adjust_relationships_for_bounty_hunters(crew_members: Array) -> void:
	# Bounty hunters tend to have more competitive relationships
	for i in range(crew_members.size()):
		for j in range(i + 1, crew_members.size()):
			var char1 = crew_members[i]
			var char2 = crew_members[j]
			
			# 30% chance to make them rivals
			if randf() < 0.3:
				add_relationship(char1, char2, RELATIONSHIP_TYPES[RelationshipType.RIVALS])
			# 20% chance to make them former enemies
			elif randf() < 0.2:
				add_relationship(char1, char2, RELATIONSHIP_TYPES[RelationshipType.FORMER_ENEMIES])

func _adjust_relationships_for_rebels(crew_members: Array) -> void:
	# Rebels tend to have stronger comradery
	for i in range(crew_members.size()):
		for j in range(i + 1, crew_members.size()):
			var char1 = crew_members[i]
			var char2 = crew_members[j]
			
			# 50% chance to make them comrades
			if randf() < 0.5:
				add_relationship(char1, char2, RELATIONSHIP_TYPES[RelationshipType.COMRADES])

func _adjust_relationships_for_smugglers(crew_members: Array) -> void:
	# Smugglers tend to have more secretive relationships
	for i in range(crew_members.size()):
		for j in range(i + 1, crew_members.size()):
			var char1 = crew_members[i]
			var char2 = crew_members[j]
			
			# 30% chance to make them uneasy allies
			if randf() < 0.3:
				add_relationship(char1, char2, RELATIONSHIP_TYPES[RelationshipType.UNEASY_ALLIES])
			# 20% chance to make them business associates
			elif randf() < 0.2:
				add_relationship(char1, char2, RELATIONSHIP_TYPES[RelationshipType.BUSINESS_ASSOCIATES])

func get_relationship_description(char1, char2) -> String:
	var relationship = get_relationship(char1, char2)
	
	if relationship.is_empty():
		return "No relationship"
	
	# Get character names
	var name1 = char1.character_name if char1.has("character_name") else "Character 1"
	var name2 = char2.character_name if char2.has("character_name") else "Character 2"
	
	# Generate description based on relationship type
	match relationship:
		RELATIONSHIP_TYPES[RelationshipType.FRIENDS]:
			return "%s and %s are close friends who trust each other implicitly." % [name1, name2]
		RELATIONSHIP_TYPES[RelationshipType.RIVALS]:
			return "%s and %s are rivals who constantly try to outdo each other." % [name1, name2]
		RELATIONSHIP_TYPES[RelationshipType.FAMILY]:
			return "%s and %s are family members who look out for each other." % [name1, name2]
		RELATIONSHIP_TYPES[RelationshipType.PARTNERS]:
			return "%s and %s are partners who work exceptionally well together." % [name1, name2]
		RELATIONSHIP_TYPES[RelationshipType.MENTOR_STUDENT]:
			return "%s is mentoring %s, passing on valuable knowledge and skills." % [name1, name2]
		RELATIONSHIP_TYPES[RelationshipType.COMRADES]:
			return "%s and %s are comrades who have fought side by side many times." % [name1, name2]
		RELATIONSHIP_TYPES[RelationshipType.UNEASY_ALLIES]:
			return "%s and %s are uneasy allies who work together out of necessity." % [name1, name2]
		RELATIONSHIP_TYPES[RelationshipType.FORMER_ENEMIES]:
			return "%s and %s were once enemies but now work together despite their past." % [name1, name2]
		RELATIONSHIP_TYPES[RelationshipType.BUSINESS_ASSOCIATES]:
			return "%s and %s have a strictly professional relationship." % [name1, name2]
		RELATIONSHIP_TYPES[RelationshipType.STRANGERS]:
			return "%s and %s barely know each other and keep their distance." % [name1, name2]
		_:
			return "%s and %s have a complex relationship." % [name1, name2]

func evolve_relationship(char1, char2, event_type: String) -> void:
	# Evolve relationships based on events
	var current_relationship = get_relationship(char1, char2)
	var new_relationship = current_relationship
	
	match event_type:
		"combat_success":
			# Successful combat tends to strengthen bonds
			if current_relationship == RELATIONSHIP_TYPES[RelationshipType.STRANGERS]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.BUSINESS_ASSOCIATES]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.BUSINESS_ASSOCIATES]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.COMRADES]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.UNEASY_ALLIES]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.COMRADES]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.RIVALS]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.UNEASY_ALLIES]
		"combat_failure":
			# Failed combat can strain relationships
			if current_relationship == RELATIONSHIP_TYPES[RelationshipType.BUSINESS_ASSOCIATES]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.STRANGERS]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.COMRADES]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.UNEASY_ALLIES]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.FRIENDS]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.COMRADES]
		"saved_life":
			# Saving someone's life creates strong bonds
			if current_relationship == RELATIONSHIP_TYPES[RelationshipType.STRANGERS]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.UNEASY_ALLIES]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.BUSINESS_ASSOCIATES]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.COMRADES]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.RIVALS]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.UNEASY_ALLIES]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.UNEASY_ALLIES]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.FRIENDS]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.FORMER_ENEMIES]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.COMRADES]
		"betrayal":
			# Betrayal damages relationships severely
			if current_relationship == RELATIONSHIP_TYPES[RelationshipType.BUSINESS_ASSOCIATES]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.RIVALS]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.COMRADES]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.FORMER_ENEMIES]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.FRIENDS]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.RIVALS]
			elif current_relationship == RELATIONSHIP_TYPES[RelationshipType.PARTNERS]:
				new_relationship = RELATIONSHIP_TYPES[RelationshipType.FORMER_ENEMIES]
	
	# Update the relationship if it changed
	if new_relationship != current_relationship:
		add_relationship(char1, char2, new_relationship)

func serialize() -> Dictionary:
	var data = super.serialize()
	
	# Add Five Parsecs specific data
	# (None needed at this time, but the function is here for future expansion)
	
	return data

func deserialize(data: Dictionary) -> void:
	super.deserialize(data)
	
	# Process Five Parsecs specific data
	# (None needed at this time, but the function is here for future expansion) 