extends Node
class_name CrewRelationshipManager

signal relationship_added(char1: Character, char2: Character, relationship_type: String)
signal relationship_removed(char1: Character, char2: Character)

const RELATIONSHIP_TYPES = {
	"HIRED": "Hired by",
	"MOTIVATION": "Shares motivation with",
	"AUTHORITY": "In trouble with authorities together",
	"ENEMY": "Common enemy with",
	"CAUSE": "Shares common cause with",
	"BAR": "Met in a bar",
	"JOB": "Worked previous job with",
	"PROTECTION": "Mutual protection pact",
	"WAR": "War buddies with"
}

const CREW_CHARACTERISTICS = {
	"ROGUES": "Lovable rogues",
	"PROFESSIONALS": "Consummate professionals", 
	"OUTLAWS": "Cut-throat outlaws",
	"DEFENDERS": "Defenders of the down-trodden",
	"REBELS": "Hardened rebels",
	"SCUM": "Starport scum",
	"BANDITS": "Somewhat honorable bandits",
	"MERCENARY": "In it for the credits",
	"DREAMERS": "Living the dream"
}

var relationships: Dictionary = {}  # Dictionary of Character pairs to relationship type
var crew_characteristic: String = ""
var crew_meeting_story: String = ""

func add_relationship(char1: Character, char2: Character, relationship_type: String) -> void:
	var pair_key = _get_pair_key(char1, char2)
	relationships[pair_key] = relationship_type
	relationship_added.emit(char1, char2, relationship_type)

func remove_relationship(char1: Character, char2: Character) -> void:
	var pair_key = _get_pair_key(char1, char2)
	if relationships.has(pair_key):
		relationships.erase(pair_key)
		relationship_removed.emit(char1, char2)

func get_relationship(char1: Character, char2: Character) -> String:
	var pair_key = _get_pair_key(char1, char2)
	return relationships.get(pair_key, "")

func get_all_relationships(character: Character) -> Array:
	var char_relationships = []
	for pair_key in relationships:
		var chars = _split_pair_key(pair_key)
		if chars[0] == character or chars[1] == character:
			char_relationships.append({
				"character": chars[0] if chars[1] == character else chars[1],
				"relationship": relationships[pair_key]
			})
	return char_relationships

func roll_crew_characteristic() -> String:
	var roll = randi() % 100 + 1
	if roll <= 12: return CREW_CHARACTERISTICS.ROGUES
	elif roll <= 21: return CREW_CHARACTERISTICS.PROFESSIONALS
	elif roll <= 28: return CREW_CHARACTERISTICS.OUTLAWS
	elif roll <= 34: return CREW_CHARACTERISTICS.DEFENDERS
	elif roll <= 48: return CREW_CHARACTERISTICS.REBELS
	elif roll <= 58: return CREW_CHARACTERISTICS.SCUM
	elif roll <= 72: return CREW_CHARACTERISTICS.BANDITS
	elif roll <= 87: return CREW_CHARACTERISTICS.MERCENARY
	else: return CREW_CHARACTERISTICS.DREAMERS

func roll_meeting_story() -> String:
	var roll = randi() % 100 + 1
	if roll <= 10: return "Hired by a random member of the group"
	elif roll <= 20: return "Pursuit of random group member's motivation"
	elif roll <= 30: return "Being in trouble with the authorities"
	elif roll <= 40: return "A common enemy"
	elif roll <= 50: return "A common cause or belief"
	elif roll <= 65: return "A random meeting in a bar"
	elif roll <= 75: return "A previous job"
	elif roll <= 90: return "Mutual protection in a hostile universe"
	else: return "Being old war buddies"

func generate_initial_relationships(crew_members: Array) -> void:
	# Roll for overall crew characteristic and meeting story
	crew_characteristic = roll_crew_characteristic()
	crew_meeting_story = roll_meeting_story()
	
	# Generate relationships between crew members
	for i in range(crew_members.size()):
		for j in range(i + 1, crew_members.size()):
			var char1 = crew_members[i]
			var char2 = crew_members[j]
			
			# Roll for relationship type
			var relationship_types = RELATIONSHIP_TYPES.values()
			var random_relationship = relationship_types[randi() % relationship_types.size()]
			add_relationship(char1, char2, random_relationship)

func _get_pair_key(char1: Character, char2: Character) -> String:
	# Create a consistent key for a pair of characters
	var id1 = char1.get_instance_id()
	var id2 = char2.get_instance_id()
	return str(min(id1, id2)) + "_" + str(max(id1, id2))

func _split_pair_key(pair_key: String) -> Array:
	var ids = pair_key.split("_")
	return [instance_from_id(int(ids[0])), instance_from_id(int(ids[1]))]

func serialize() -> Dictionary:
	var serialized_relationships = {}
	for pair_key in relationships:
		serialized_relationships[pair_key] = relationships[pair_key]
	
	return {
		"relationships": serialized_relationships,
		"crew_characteristic": crew_characteristic,
		"crew_meeting_story": crew_meeting_story
	}

func deserialize(data: Dictionary) -> void:
	relationships.clear()
	for pair_key in data.get("relationships", {}):
		relationships[pair_key] = data["relationships"][pair_key]
	
	crew_characteristic = data.get("crew_characteristic", "")
	crew_meeting_story = data.get("crew_meeting_story", "") 