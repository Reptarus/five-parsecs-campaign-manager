extends Node

## Planet Data Persistence Manager for Five Parsecs Campaign Manager  
## Handles world data storage, progression tracking, and cross-turn persistence

# Safe imports
# GlobalEnums available as autoload singleton
const WorldGenerator = preload("res://src/core/campaign/WorldGenerator.gd")

## Planet data structure for persistence
class PlanetData:
	var id: String
	var name: String
	var type: String
	var type_name: String
	var traits: Array[String] = []

	# Progression tracking
	var discovered_on_turn: int = 0
	var last_visited_turn: int = 0
	var visit_count: int = 0
	var missions_completed: int = 0

	var contact_ids: Array[String] = []

	# Removed 2026-10-29: danger_level, locations, special_features,
	# resources_extracted, active/temporary modifiers, world_events,
	# market_conditions, trade_opportunities and price_modifiers. Core Rules p.72
	# gives a world a trait and a licence roll, and nothing else. The per-turn
	# "world event" D6 behind world_events was printed on three screens ("Local
	# unrest penalizes all crew tasks by -1") while nothing applied it.
	# deserialize() ignores the keys an older save still carries.

	# Per-planet faction state (Compendium pp.110-117)
	var faction_data: Dictionary = {}
	
	func _init(planet_id: String = ""):
		id = planet_id if planet_id != "" else "planet_" + str(Time.get_unix_time_from_system())
		
	func serialize() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"type": type,
			"type_name": type_name,
			"traits": traits,
			"discovered_on_turn": discovered_on_turn,
			"last_visited_turn": last_visited_turn,
			"visit_count": visit_count,
			"missions_completed": missions_completed,
			"contact_ids": contact_ids,
			"faction_data": faction_data.duplicate(true),
		}
	
	func deserialize(data: Dictionary) -> void:
		id = data.get("id", "")
		name = data.get("name", "")
		type = data.get("type", "")
		type_name = data.get("type_name", "")
		# Typed arrays use .assign(): JSON-parsed arrays are UNTYPED, so a plain `=` into
		# these Array[String] props aborts load (Godot 4.6).
		traits.assign(data.get("traits", []))
		discovered_on_turn = data.get("discovered_on_turn", 0)
		last_visited_turn = data.get("last_visited_turn", 0)
		visit_count = data.get("visit_count", 0)
		missions_completed = data.get("missions_completed", 0)
		contact_ids.assign(data.get("contact_ids", []))
		faction_data = data.get("faction_data", {})

## Planet Data Manager Signals
signal planet_discovered(planet_data: PlanetData)
signal planet_visited(planet_id: String, visit_count: int)
signal planet_data_updated(planet_id: String, update_type: String)

## Data storage
var visited_planets: Dictionary = {} # planet_id -> PlanetData
var current_planet_id: String = ""
var travel_history: Array[Dictionary] = []
var world_generator: WorldGenerator = null

func _ready() -> void:
	world_generator = WorldGenerator.new()

## Generate or retrieve planet data
func get_or_generate_planet(planet_id: String = "", campaign_turn: int = 0) -> PlanetData:
	# If no ID provided, generate new planet
	if planet_id == "":
		return _generate_new_planet(campaign_turn)
	
	# Return existing planet if already visited
	if visited_planets.has(planet_id):
		var planet = visited_planets[planet_id]
		_update_planet_visit(planet, campaign_turn)
		return planet
	
	# Generate planet with specific ID (for testing/forced generation)
	return _generate_new_planet(campaign_turn, planet_id)

## Generate a new planet using WorldGenerator
func _generate_new_planet(campaign_turn: int, forced_id: String = "") -> PlanetData:
	var world_data = world_generator.generate_world(campaign_turn)
	
	var planet = PlanetData.new(forced_id if forced_id != "" else world_data.id)
	planet.name = world_data.name
	planet.type = world_data.type
	planet.type_name = world_data.type_name
	# .assign() copies into PlanetData's TYPED Array[String]. WorldGenerator returns an
	# UNTYPED traits array; a plain `=` aborts this function in Godot 4.6
	# ("Invalid assignment ... value of type 'Array'").
	planet.traits.assign(world_data.traits)
	planet.discovered_on_turn = campaign_turn
	planet.last_visited_turn = campaign_turn
	planet.visit_count = 1
	
	
	# Store planet
	visited_planets[planet.id] = planet

	self.planet_discovered.emit(planet)

	return planet

## Create a colony world for a Compendium species (Krag/Skulker)
## Loads colony data from data/compendium/species.json and applies forced traits
func create_colony_world(species_id: String, campaign_turn: int) -> PlanetData:
	var species_json: Dictionary = _load_compendium_species_data(species_id)
	var colony_data: Dictionary = species_json.get("colony_world", {})
	if colony_data.is_empty():
		return null

	var planet_id := "colony_%s_%d" % [species_id, Time.get_unix_time_from_system()]
	var planet := PlanetData.new(planet_id)
	planet.name = "%s Colony" % species_id.capitalize()
	planet.type = "COLONY_WORLD"
	planet.type_name = "%s Colony World" % species_id.capitalize()
	planet.discovered_on_turn = campaign_turn
	planet.last_visited_turn = campaign_turn
	planet.visit_count = 1

	# Apply forced traits (Compendium p.15/p.17)
	for trait_id: String in colony_data.get("forced_traits", []):
		planet.traits.append(trait_id)

	# Roll additional traits if specified (Skulker: +1 random)
	if colony_data.get("second_trait", "") == "rolled_normally":
		var rolled_trait: String = _roll_random_trait()
		# Compendium p.17: "Alien species restricted" = no result
		if colony_data.get("alien_restricted_override", "") == "no_result":
			if rolled_trait == "alien_species_restricted":
				rolled_trait = ""
		if not rolled_trait.is_empty():
			planet.traits.append(rolled_trait)

	visited_planets[planet.id] = planet
	planet_discovered.emit(planet)
	return planet

## Load species data from Compendium JSON
func _load_compendium_species_data(species_id: String) -> Dictionary:
	var file := FileAccess.open("res://data/compendium/species.json", FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data: Dictionary = json.data if json.data is Dictionary else {}
	return data.get(species_id, {})

## Roll a random world trait ID from the trait pool
func _roll_random_trait() -> String:
	var file := FileAccess.open("res://data/world_traits.json", FileAccess.READ)
	if not file:
		return ""
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return ""
	# world_traits.json is a DICTIONARY with a "world_traits" key. The old line
	# here was `json.data if json.data is Array else []`, which is therefore
	# ALWAYS the empty array — so this function returned "" every single time it
	# was called and no planet ever gained a trait through this path.
	if not json.data is Dictionary:
		return ""
	var trait_list: Array = json.data.get("world_traits", [])

	# Core Rules p.73 is a D100 table with weighted ranges (Fog is 97-100, Haze
	# is 1-3), not a uniform pick. The old flatten-then-pick_random gave Fog and
	# Warzone the same 1-in-42 chance where the book gives Fog four times the
	# odds of Warzone.
	var roll: int = randi_range(1, 100)
	for entry in trait_list:
		if not entry is Dictionary:
			continue
		var r: Array = entry.get("roll_range", [])
		if r.size() == 2 and roll >= int(r[0]) and roll <= int(r[1]):
			return str(entry.get("id", ""))
	return ""

## Update planet visit data
func _update_planet_visit(planet: PlanetData, campaign_turn: int) -> void:
	planet.last_visited_turn = campaign_turn
	planet.visit_count += 1
	
	# Record travel history
	var travel_record = {
		"planet_id": planet.id,
		"planet_name": planet.name,
		"turn": campaign_turn,
		"visit_number": planet.visit_count
	}
	travel_history.append(travel_record)
	
	self.planet_visited.emit(planet.id, planet.visit_count)

## Set current planet
func set_current_planet(planet_id: String) -> void:
	current_planet_id = planet_id

## Create or refresh the current world FROM a campaign world_data dict and mark it
## current. This is the canonical bridge from campaign.world_data (the game's
## source of truth) into the galaxy-map store — called on load-backfill, campaign
## creation, and travel arrival (via the world_changed signal) so the Galaxy Log
## and World Log reflect the REAL world instead of a randomly-generated one.
func upsert_current_world(world_data: Dictionary, campaign_turn: int = -1) -> String:
	if world_data == null or world_data.is_empty():
		return ""
	var pid: String = str(world_data.get("id", ""))
	if pid.is_empty():
		pid = "world_%d" % Time.get_unix_time_from_system()
	if not visited_planets.has(pid):
		var planet := PlanetData.new(pid)
		# Map fields defensively. PlanetData.traits is Array[String]; normalize so a
		# future world_data shape can't abort the typed .assign().
		planet.name = str(world_data.get("name", "Unknown World"))
		planet.type = str(world_data.get("type", ""))
		planet.type_name = str(world_data.get("type_name", ""))
		planet.traits.assign(_normalize_string_array(world_data.get("traits", [])))
		var disc: int = int(world_data.get("discovered_on_turn", 0))
		if disc <= 0 and campaign_turn >= 0:
			disc = campaign_turn
		planet.discovered_on_turn = disc
		planet.last_visited_turn = campaign_turn if campaign_turn >= 0 else disc
		planet.visit_count = max(1, int(world_data.get("visit_count", 1)))
		visited_planets[pid] = planet
		# Breadcrumb entry for the Galaxy Log travel path.
		travel_history.append({
			"planet_id": pid,
			"planet_name": planet.name,
			"turn": (campaign_turn if campaign_turn >= 0 else disc),
			"visit_number": planet.visit_count,
		})
		planet_discovered.emit(planet)
	else:
		# HEAL an existing entry whose descriptive fields drifted from world_data.
		# Legacy saves seeded PDM via the old finalization's random get_or_generate_planet,
		# so the Galaxy Log showed a fabricated name while campaign.world_data (the
		# authoritative current-world source) held the real one. world_data wins.
		# Progression/history (visit_count, discovered_on_turn, breadcrumbs) is untouched.
		var existing: PlanetData = visited_planets[pid]
		var new_name: String = str(world_data.get("name", existing.name))
		if new_name != "" and new_name != existing.name:
			existing.name = new_name
			existing.type = str(world_data.get("type", existing.type))
			existing.type_name = str(world_data.get("type_name", existing.type_name))
			existing.traits.assign(_normalize_string_array(
				world_data.get("traits", existing.traits)))
			planet_data_updated.emit(pid, "world_synced")
	set_current_planet(pid)
	return pid

func _normalize_string_array(v) -> Array:
	## Coerce an untyped array to plain strings (extract id/name from dict entries).
	var out: Array = []
	if v is Array:
		for e in v:
			if e is Dictionary:
				out.append(str(e.get("id", e.get("name", ""))))
			else:
				out.append(str(e))
	return out

## Get current planet data
func get_current_planet() -> PlanetData:
	if current_planet_id != "" and visited_planets.has(current_planet_id):
		return visited_planets[current_planet_id]
	return null

## Complete mission on planet
func complete_mission(planet_id: String, _mission_data: Dictionary) -> void:
	if not visited_planets.has(planet_id):
		return
	
	var planet = visited_planets[planet_id]
	planet.missions_completed += 1

	# NO EXPLORATION ACCRUAL. "Exploration progress" is not a mechanic in the Core
	# Rules or the Compendium — the term appears in neither book, no rule consumed
	# the value, and `exploration_progress_updated` had zero listeners. It read
	# `mission_data["exploration_value"]`, a key no producer anywhere ever wrote,
	# so it defaulted to a flat 0.1 per mission and displayed a world as "100%
	# explored" after ten missions: a completion bar for a completion mechanic
	# that does not exist. Removed Aug 2026 under the fabricated-data rule along
	# with both of its display sites. Do not re-add.

	# NO RESOURCE ACCRUAL either. It summed `mission_data["resources_gained"]`, a key
	# no producer writes, into a "resources_extracted" stat neither book has. Removed
	# 2026-10-29 with the rest of the invented world model (see WorldGenerator).

	self.planet_data_updated.emit(planet_id, "mission_completed")

## Get available contacts on planet
func get_planet_contacts(planet_id: String) -> Array[String]:
	if not visited_planets.has(planet_id):
		return []
	
	return visited_planets[planet_id].contact_ids.duplicate()

## Add contact to planet
func add_contact_to_planet(planet_id: String, contact_id: String) -> void:
	if not visited_planets.has(planet_id):
		return
	
	var planet: PlanetData = visited_planets[planet_id]
	if contact_id not in planet.contact_ids:
		planet.contact_ids.append(contact_id)

## Remove contact from planet (Core Rules p.69: reinstatement on return visits)
func remove_contact_from_planet(planet_id: String, contact_id: String) -> void:
	if not visited_planets.has(planet_id):
		return
	var planet: PlanetData = visited_planets[planet_id]
	var idx: int = planet.contact_ids.find(contact_id)
	if idx >= 0:
		planet.contact_ids.remove_at(idx)
		planet_data_updated.emit(planet_id, "contact_removed")

## Store faction state for a planet (Compendium pp.110-117: factions are per-planet)
func store_faction_data(planet_id: String, data: Dictionary) -> void:
	if visited_planets.has(planet_id):
		visited_planets[planet_id].faction_data = data.duplicate(true)

## Get stored faction state for a planet
func get_faction_data(planet_id: String) -> Dictionary:
	if visited_planets.has(planet_id):
		return visited_planets[planet_id].faction_data.duplicate(true)
	return {}

## Get planet statistics
func get_planet_stats(planet_id: String) -> Dictionary:
	if not visited_planets.has(planet_id):
		return {}
	
	var planet = visited_planets[planet_id]
	# `name` is what PatronRivalManager._planet_name() reads. It was never in this
	# dictionary, so every Patron and Rival's home world printed blank.
	return {
		"name": planet.name,
		"visit_count": planet.visit_count,
		"missions_completed": planet.missions_completed,
		"contact_count": planet.contact_ids.size(),
	}

## Serialize all planet data
func serialize_all() -> Dictionary:
	var serialized_planets = {}
	for planet_id in visited_planets:
		serialized_planets[planet_id] = visited_planets[planet_id].serialize()
	
	return {
		"visited_planets": serialized_planets,
		"current_planet_id": current_planet_id,
		"travel_history": travel_history
	}

## Deserialize planet data
func deserialize_all(data: Dictionary) -> void:
	visited_planets.clear()
	travel_history.clear()
	
	var planets_data = data.get("visited_planets", {})
	for planet_id in planets_data:
		var planet = PlanetData.new()
		planet.deserialize(planets_data[planet_id])
		visited_planets[planet_id] = planet
	
	current_planet_id = data.get("current_planet_id", "")
	var raw_history: Array = data.get("travel_history", [])
	travel_history.clear()
	for entry in raw_history:
		if entry is Dictionary:
			travel_history.append(entry)

## Get debug info
func get_debug_info() -> Dictionary:
	return {
		"total_planets": visited_planets.size(),
		"current_planet": current_planet_id,
		"travel_history_length": travel_history.size(),
		"total_missions_completed": _calculate_total_missions(),
		"most_visited_planet": _get_most_visited_planet()
	}

func _calculate_total_missions() -> int:
	var total = 0
	for planet in visited_planets.values():
		total += planet.missions_completed
	return total

func _get_most_visited_planet() -> String:
	var max_visits = 0
	var most_visited = ""

	for planet in visited_planets.values():
		if planet.visit_count > max_visits:
			max_visits = planet.visit_count
			most_visited = planet.name

	return most_visited

## Check if planet was previously visited
func has_visited_planet(planet_id: String) -> bool:
	return visited_planets.has(planet_id)

## Get list of all visited planet IDs
func get_visited_planets() -> Array[String]:
	var ids: Array[String] = []
	for key in visited_planets.keys():
		ids.append(key)
	return ids

## Get contacts on a planet filtered by prefix (patron_ or rival_)
func get_planet_patrons(planet_id: String) -> Array[String]:
	var patrons: Array[String] = []
	for contact_id in get_planet_contacts(planet_id):
		if contact_id.begins_with("patron_"):
			patrons.append(contact_id)
	return patrons

func get_planet_rivals(planet_id: String) -> Array[String]:
	var rivals: Array[String] = []
	for contact_id in get_planet_contacts(planet_id):
		if contact_id.begins_with("rival_"):
			rivals.append(contact_id)
	return rivals

