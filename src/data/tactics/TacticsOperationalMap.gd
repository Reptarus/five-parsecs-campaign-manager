class_name TacticsOperationalMap
extends Resource

## TacticsOperationalMap - Strategic layer state for Tactics campaigns
## Tracks regions, operational zones, Army Strength, Cohesion, Player Battle Points.
## No Tactica equivalent — entirely new for Tactics gamemode.
## Source: Five Parsecs: Tactics campaign rules pp.155-168

## Zone status
enum ZoneStatus {
	CONTESTED,      # Active combat zone
	FRIENDLY,       # Under player control
	ENEMY,          # Under enemy control
	NEUTRAL,        # Not yet engaged
}

## Region type (affects combat modifiers)
enum RegionType {
	STANDARD,       # No special properties
	DEFENSIBLE,     # +1 Combat Die for defender
	CRITICAL,       # Cohesion impact on loss
	URBAN,          # Costly to lose
}

# Campaign-level tracking
@export var player_cohesion: int = 5        # Will-to-fight (0 = defeat)
@export var enemy_cohesion: int = 5         # Enemy will-to-fight (0 = victory)
@export var player_battle_points: int = 0   # PBP, 1 per tabletop win
@export var operational_turn: int = 0       # Current strategic turn

# Regions (Array of Dictionaries)
# Each: {id, name, type (RegionType), zones (Array), is_focus (bool)}
var regions: Array = []

# Zones (Array of Dictionaries)
# Each: {id, region_id, name, status (ZoneStatus),
#         player_army_strength (int), enemy_army_strength (int)}
var zones: Array = []

# Current focus zone (where next tabletop battle takes place)
@export var focus_zone_id: String = ""

# Operational orders history (Array of {turn, order_type, details})
var orders_history: Array = []


## Get a zone by ID
func get_zone(zone_id: String) -> Dictionary:
	for zone in zones:
		if zone is Dictionary and zone.get("id", "") == zone_id:
			return zone
	return {}


## Get a region by ID
func get_region(region_id: String) -> Dictionary:
	for region in regions:
		if region is Dictionary and region.get("id", "") == region_id:
			return region
	return {}


## Get all zones in a region
func get_zones_in_region(region_id: String) -> Array:
	var result: Array = []
	for zone in zones:
		if zone is Dictionary and zone.get("region_id", "") == region_id:
			result.append(zone)
	return result


## Get count of zones by status
func count_zones_by_status(status: ZoneStatus) -> int:
	var count: int = 0
	for zone in zones:
		if zone is Dictionary and zone.get("status", -1) == status:
			count += 1
	return count


## Apply a Player Battle Point (earned from tabletop victory)
func add_battle_point() -> void:
	player_battle_points += 1


## Spend PBP on a commando raid (damages enemy Army Strength in a zone)
func spend_pbp_commando_raid(zone_id: String, amount: int = 1) -> bool:
	if player_battle_points < amount:
		return false
	var zone: Dictionary = get_zone(zone_id)
	if zone.is_empty():
		return false
	player_battle_points -= amount
	var current: int = zone.get("enemy_army_strength", 0)
	zone["enemy_army_strength"] = maxi(current - 1, 0)
	return true


## Advance to next operational turn
func advance_turn() -> void:
	operational_turn += 1


## Check if player has won (enemy cohesion = 0)
func is_player_victory() -> bool:
	return enemy_cohesion <= 0


## Check if player has lost (player cohesion = 0)
func is_player_defeat() -> bool:
	return player_cohesion <= 0


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"player_cohesion": player_cohesion,
		"enemy_cohesion": enemy_cohesion,
		"player_battle_points": player_battle_points,
		"operational_turn": operational_turn,
		"focus_zone_id": focus_zone_id,
		"regions": regions.duplicate(true),
		"zones": zones.duplicate(true),
		"orders_history": orders_history.duplicate(true),
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> TacticsOperationalMap:
	var map := TacticsOperationalMap.new()
	map.player_cohesion = data.get("player_cohesion", 5)
	map.enemy_cohesion = data.get("enemy_cohesion", 5)
	map.player_battle_points = data.get("player_battle_points", 0)
	map.operational_turn = data.get("operational_turn", 0)
	map.focus_zone_id = data.get("focus_zone_id", "")
	map.regions = data.get("regions", []).duplicate(true)
	map.zones = data.get("zones", []).duplicate(true)
	map.orders_history = data.get("orders_history", []).duplicate(true)
	return map
