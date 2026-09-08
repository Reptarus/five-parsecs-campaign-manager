class_name TacticsOperationalMap
extends Resource

## TacticsOperationalMap - Strategic layer state for Tactics campaigns
## Tracks regions, operational zones, Army Strength, Cohesion, Player Battle Points.
## No Tactica equivalent — entirely new for Tactics gamemode.
## Source: Five Parsecs: Tactics **pp.92-100** — "THE OPERATIONAL SYSTEM" in the
## Campaign Play chapter (Cohesion, the Map, Operational Zones, Army Strength, the
## Operational Turn at p.96, Commando Raids, Player Battle Points, and
## Special Regions at p.100).
## ⚠ CITE CORRECTED 2026-09-04 from "pp.155-168", which is the **Lifeforms
## bestiary** chapter — 63 pages off. docs/rules/tactics_source.txt marks raw page N
## with the PRINTED number on the next line (offset raw-2), verified at three points:
## raw 94 -> p.92 "THE OPERATIONAL SYSTEM", raw 157 -> p.155 "Lifeforms/Hulkers",
## raw 170 -> p.168 "Lifeforms/CREATURES".
##
## ⚠ CORRECTED AGAIN 2026-09-07: this said "the **8-step** Operational Turn". The
## book's own summary list on p.96 does stop at eight — but the body carries a ninth
## section, **"Step 9: Adjust Cohesion scores" (p.99)**, and that step is the campaign's
## END CONDITION: a region lost costs 1 Cohesion, 0 Cohesion defeats a faction, and the
## campaign is won when one faction remains. Building a turn loop from the summary list
## alone yields one that can never finish, which is what happened — `is_player_victory()`
## and `is_player_defeat()` below implement Step 9 and had no caller for months.
##
## The RULES (dice pools, tables, caps) live in
## `src/core/campaign/TacticsOperationalRules.gd`, read from
## `data/tactics/tactics_campaign_config.json`. This Resource is the STATE.

const TacticsOperationalRulesRef = preload(
	"res://src/core/campaign/TacticsOperationalRules.gd")

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


## Apply a Player Battle Point (earned from tabletop victory).
##
## ⚠ p.96 caps this and the cap was MISSING until 2026-09-07: "a specific army cannot
## gain more than 2 PBP in a single operational turn, and cannot have more than 3 saved
## up overall. Any excess points are discarded without any effects." The per-turn cap
## belongs to the awarding step (TacticsOperationalRules.award_battle_points), which
## sees the whole turn's battles; the SAVED cap belongs here, because this is the field.
## Returns the number actually banked, so a caller can report what was discarded.
func add_battle_point(count: int = 1) -> int:
	var cap: int = TacticsOperationalRulesRef.max_saved_battle_points()
	var before: int = player_battle_points
	player_battle_points = mini(player_battle_points + maxi(count, 0), cap)
	return player_battle_points - before


## Spend PBP on a commando raid against a zone — Tactics **p.99**, Step 5.
##
## ⚠ This used to spend the points and deduct exactly 1 Army Strength, which is not the
## rule: the book requires a D6 PER POINT COMMITTED, where any 1-2 loses ALL the points
## committed against that region, every 6 costs the target 1 Army Strength, and that
## damage lands even when the points are lost. A guaranteed hit made raids strictly
## better than the printed rule.
##
## `rng` is injectable so a test can seed it. Returns the raid receipt from
## TacticsOperationalRules.resolve_commando_raid() plus "spent"/"zone_id", or {} if the
## raid could not be attempted at all — an empty result means "nothing happened", which
## is different from a raid that rolled badly.
func spend_pbp_commando_raid(
		zone_id: String, amount: int = 1,
		rng: RandomNumberGenerator = null) -> Dictionary:
	if amount <= 0 or player_battle_points < amount:
		return {}
	var zone: Dictionary = get_zone(zone_id)
	if zone.is_empty():
		return {}

	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()

	var receipt: Dictionary = TacticsOperationalRulesRef.resolve_commando_raid(
		amount, gen)
	# The points are committed either way; "pbp_lost" reports whether they were
	# additionally forfeited, which the book distinguishes from simply being spent.
	player_battle_points -= amount
	var damage: int = int(receipt.get("army_strength_damage", 0))
	if damage > 0:
		var current: int = zone.get("enemy_army_strength", 0)
		zone["enemy_army_strength"] = maxi(current - damage, 0)
	receipt["spent"] = amount
	receipt["zone_id"] = zone_id
	return receipt


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
	var _Self = load("res://src/data/tactics/TacticsOperationalMap.gd")
	var map = _Self.new()
	map.player_cohesion = data.get("player_cohesion", 5)
	map.enemy_cohesion = data.get("enemy_cohesion", 5)
	map.player_battle_points = data.get("player_battle_points", 0)
	map.operational_turn = data.get("operational_turn", 0)
	map.focus_zone_id = data.get("focus_zone_id", "")
	map.regions = data.get("regions", []).duplicate(true)
	map.zones = data.get("zones", []).duplicate(true)
	map.orders_history = data.get("orders_history", []).duplicate(true)
	return map
