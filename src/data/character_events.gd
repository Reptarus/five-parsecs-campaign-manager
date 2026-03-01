extends RefCounted
## Character Phase Event Data (Five Parsecs character events table)
## Extracted from CharacterPhasePanel.gd for data separation and reuse.

const EVENT_TABLE: Array[Dictionary] = [
	{"type": "NOTHING", "description": "Nothing eventful happens.", "weight": 30},
	{"type": "PERSONAL_GROWTH", "description": "Personal growth - gains +1 to a random stat.", "weight": 15},
	{"type": "NEW_CONTACT", "description": "Makes a new contact who may become a patron.", "weight": 10},
	{"type": "EQUIPMENT_FIND", "description": "Finds a useful piece of equipment.", "weight": 10},
	{"type": "TRAINING", "description": "Spends time training - gains 1 XP.", "weight": 15},
	{"type": "CREW_BOND", "description": "Bonds with another crew member - crew morale improves.", "weight": 10},
	{"type": "MINOR_TROUBLE", "description": "Gets into minor trouble - loses 1d6 credits.", "weight": 10},
]

static func roll_event() -> Dictionary:
	var total_weight := 0
	for entry in EVENT_TABLE:
		total_weight += entry.weight
	var roll = randi() % total_weight
	var cumulative := 0
	for entry in EVENT_TABLE:
		cumulative += entry.weight
		if roll < cumulative:
			return entry
	return EVENT_TABLE[0]
