class_name TacticsSpecies
extends Resource

## TacticsSpecies - Species/faction identity for Tactics army lists
## Replaces AoF Faction: drops stat modifiers (species traits are on units directly).
## Adds species_traits array for species-wide abilities.
## Source: Five Parsecs: Tactics rulebook pp.49-80

enum PowerLevel {
	MAJOR,          # 7 Major Powers (Humans, Ferals, Hulkers, etc.)
	MINOR,          # 7 Minor Powers (Serian, Swift, Keltrin, etc.)
	CREATURE,       # 6 Creature types (Swarm, Razor Lizard, etc.)
}

# Identity
@export var species_id: String = ""
@export var species_name: String = ""
@export var description: String = ""
@export var power_level: PowerLevel = PowerLevel.MAJOR

# Species-wide traits (applied to all units of this species)
var species_traits: Array = []  # Array of TacticsSpecialRule

# Cross-reference to 5PFH species (for character transfer)
@export var fph_species_id: String = ""  # e.g., "human", "feral", "kerin"


## Check if species has a specific trait
func has_trait(trait_name: String) -> bool:
	for t in species_traits:
		if t is TacticsSpecialRule and t.matches(trait_name):
			return true
	return false


## Get trait display string
func get_traits_display() -> String:
	var names: Array[String] = []
	for t in species_traits:
		if t is TacticsSpecialRule:
			names.append(t.get_display_name())
	if names.is_empty():
		return "None"
	return ", ".join(names)


## Create from a dictionary (JSON hydration)
static func from_dict(data: Dictionary) -> TacticsSpecies:
	var species := TacticsSpecies.new()
	species.species_id = data.get("species_id", data.get("id", ""))
	species.species_name = data.get("species_name", data.get("name", ""))
	species.description = data.get("description", "")
	species.fph_species_id = data.get("fph_species_id", "")

	var level_str: String = data.get("power_level", "major")
	species.power_level = _level_from_string(level_str)

	var raw_traits: Array = data.get("traits", data.get("species_traits", []))
	for raw in raw_traits:
		if raw is String:
			var rule := TacticsSpecialRule.from_string(raw)
			rule.rule_type = TacticsSpecialRule.RuleType.SPECIES
			species.species_traits.append(rule)
		elif raw is Dictionary:
			species.species_traits.append(TacticsSpecialRule.from_dict(raw))

	return species


## Serialize to dictionary
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"species_id": species_id,
		"species_name": species_name,
		"power_level": PowerLevel.keys()[power_level].to_lower(),
	}
	if not description.is_empty():
		data["description"] = description
	if not fph_species_id.is_empty():
		data["fph_species_id"] = fph_species_id

	var trait_list: Array = []
	for t in species_traits:
		if t is TacticsSpecialRule:
			trait_list.append(t.to_dict())
	if not trait_list.is_empty():
		data["traits"] = trait_list

	return data


static func _level_from_string(level_str: String) -> PowerLevel:
	match level_str.to_lower():
		"major": return PowerLevel.MAJOR
		"minor": return PowerLevel.MINOR
		"creature": return PowerLevel.CREATURE
		_: return PowerLevel.MAJOR
