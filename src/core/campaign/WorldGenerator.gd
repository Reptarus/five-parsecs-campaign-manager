@tool
extends Node

## World Generator for Five Parsecs From Home: a new world's name and its World
## Trait (Core Rules p.72).
##
## New World Arrival (p.72) is four steps: Rivals follow on a 1D6 5+, Patrons stay
## behind unless Persistent, the world needs a Freelancer License on a 1D6 5-6, and
## then ONE World Trait from the p.72 D100 table. The first three change campaign
## state and are resolved by NewWorldArrival and InterdictionRule. This file makes
## the world itself.
##
## Until 2026-10-29 it also rolled a danger level, a tech level, a D10 government,
## a population scale, two or three "locations" and a list of "special features",
## all citing "p.80-86". Those pages are the Trade and Exploration tables, Job
## Offers and the turn example. Neither book has any of those fields, and the
## screens that printed them (creation step 6, the dashboard, the planet detail,
## the world briefing, the Galaxy Log hex) printed invented numbers. Do not re-add.
const GameDataManager = preload("res://src/core/managers/GameDataManager.gd")

# Signal declarations
signal world_generated(world_data: Dictionary)

# Data files
const WORLD_TRAITS_PATH = "res://data/world_traits.json"
const HouseRulesHelperRef = preload("res://src/core/systems/HouseRulesHelper.gd")

# Loaded data
var _world_traits: Array = []
var _data_manager: Object

func _init() -> void:
	_data_manager = GameDataManager.get_instance()
	GameDataManager.ensure_data_loaded()
	_load_data()

func _ready() -> void:
	pass

## Load all required data from JSON files
func _load_data() -> void:
	var trait_data = _data_manager.load_json_file(WORLD_TRAITS_PATH)
	if trait_data and trait_data.has("world_traits"):
		_world_traits = trait_data["world_traits"]
	else:
		push_error("Failed to load world traits data")

## Generate a new world: a name and its World Trait (Core Rules p.72).
func generate_world(campaign_turn: int = 1) -> Dictionary:
	var planet_type = _generate_planet_type()
	var traits = _generate_planetary_traits(planet_type)
	# Cosmetic world-type label, derived from the trait-based world (NOT a biome).
	var type_label = _derive_world_type_label(traits)
	var world_data = {
		"id": "world_" + str(Time.get_unix_time_from_system()),
		"name": _generate_planet_name(planet_type),
		"type": type_label.get("id", "standard"),
		"type_name": type_label.get("name", "Standard World"),
		"traits": traits,
		"discovered_on_turn": campaign_turn,
	}
	world_generated.emit(world_data)
	return world_data

## NOTE (2026-06-02 strict biome removal): returns a neutral stub. Five Parsecs world
## generation is TRAIT-BASED (Core Rules "World Traits Table"); there is NO biome "planet
## type" table in the Core Rulebook or Compendium (verified via PDF). planet_types.json was
## deleted. The cosmetic world-type LABEL is now derived from the generated traits in
## generate_world() via _derive_world_type_label(). This stub exists only so the downstream
## name generator keeps its fallback behavior.
func _generate_planet_type() -> Dictionary:
	return {"id": "standard", "name": "Standard World"}

## Derive a cosmetic world-type label from the world's traits (no biome concept). Uses the
## first trait, formatted for display: e.g. "frontier_world" -> "Frontier World".
func _derive_world_type_label(traits: Array) -> Dictionary:
	if traits.is_empty():
		return {"id": "standard", "name": "Standard World"}
	var first: String = str(traits[0])
	var parts: Array[String] = []
	for w in first.split("_"):
		if w.length() > 0:
			parts.append(w.substr(0, 1).to_upper() + w.substr(1))
	return {"id": first, "name": " ".join(parts)}

## Generate a planet name
func _generate_planet_name(planet_type: Dictionary) -> String:
	# Generate a name based on planet type
	var base_names = planet_type.get("name_prefixes", ["Alpha", "Beta", "Gamma", "Delta"])
	var suffixes = planet_type.get("name_suffixes", ["Prime", "II", "III", "Major", "Minor"])
	
	var base_name = base_names[randi() % base_names.size()]
	var suffix = suffixes[randi() % suffixes.size()]
	
	return base_name + " " + suffix

## Generate the world's trait (Core Rules p.72)
func _generate_planetary_traits(planet_type: Dictionary) -> Array:
	## Core Rules p.72, verbatim: "World Traits — Roll D100 on the following
	## table to determine what trait applies to the world."
	##
	## ONE trait, and a WEIGHTED roll. This used to take `1 + randi() % 2` traits
	## and pick each one uniformly at random from the list, which is wrong twice:
	## worlds got up to double the traits the book gives them, and the D100
	## roll_range weights sitting in data/world_traits.json were ignored, so Haze
	## (1-3, a 3% band) came up as often as a 12% one.
	##
	## Mandatory traits from the planet type are kept: those are a property of the
	## world type rather than a result of the p.72 roll.
	var traits = []
	var available_traits = _world_traits.duplicate()

	# Add any mandatory traits for this planet type
	var mandatory_traits = planet_type.get("mandatory_traits", [])
	for trait_id in mandatory_traits:
		traits.append(trait_id)
		# Remove from available to avoid duplicates
		for i in range(available_traits.size() - 1, -1, -1):
			if available_traits[i].get("id") == trait_id:
				available_traits.remove_at(i)
				break

	var rolled: String = _roll_world_trait(available_traits)
	if not rolled.is_empty():
		traits.append(rolled)
		# WILD GALAXY, optional rule, Core Rules p.73, verbatim: "If you prefer a
		# more chaotic and wild place to adventure, you may opt to roll twice for
		# each world you visit. If the results would seem to contradict, ignore
		# the second roll."
		#
		# The second roll is a fresh, INDEPENDENT D100 over the same table — the
		# first result is deliberately NOT removed from `available_traits`, since
		# removing it would re-weight every remaining roll_range band and the
		# book says "roll twice", not "roll on the remainder".
		#
		# The only contradiction resolved here is a straight duplicate. Whether
		# two DIFFERENT traits contradict is a judgement the book leaves to the
		# player ("would SEEM to contradict"), and there is no contradiction
		# table printed anywhere — inventing one would be fabricating game data.
		if HouseRulesHelperRef.is_enabled("wild_galaxy"):
			var second: String = _roll_world_trait(available_traits)
			if not second.is_empty() and second != rolled:
				traits.append(second)

	return traits

func _roll_world_trait(available_traits: Array) -> String:
	## Single D100 against the table's roll_range bands (Core Rules p.72).
	if available_traits.is_empty():
		return ""
	var roll: int = randi_range(1, 100)
	for entry in available_traits:
		if not entry is Dictionary:
			continue
		var band: Array = entry.get("roll_range", [])
		if band.size() == 2 and roll >= int(band[0]) and roll <= int(band[1]):
			return str(entry.get("id", ""))
	# The roll landed in a band belonging to a mandatory trait already applied,
	# or the table is short — take the nearest remaining band rather than
	# returning a traitless world.
	var best: String = ""
	var best_distance: int = 1 << 30
	for entry in available_traits:
		if not entry is Dictionary:
			continue
		var band2: Array = entry.get("roll_range", [])
		if band2.size() != 2:
			continue
		var distance: int = mini(absi(roll - int(band2[0])), absi(roll - int(band2[1])))
		if distance < best_distance:
			best_distance = distance
			best = str(entry.get("id", ""))
	return best

## Get a list of all available world traits
func get_world_traits() -> Array:
	return _world_traits.duplicate()
