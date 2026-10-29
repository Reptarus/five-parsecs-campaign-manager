extends RefCounted

## The Planetfall campaign map: pp.50-54 (the grid, the home sector, Investigation Sites,
## the enemy's occupied sectors and Strongpoint), pp.59-62 (Scout Reports, Enemy
## Information, Ancient Signs, Enemy Activity) and each mission's Map Location and
## Campaign Factors (pp.115-133).
##
## Until 2026-10-28 the map was a stub. Creation wrote `sectors: {}` and nothing wrote a
## sector again, so an Exploration had no Resource to reduce, a Raid read an
## `occupied_sectors` list that stayed empty (every Raid did exactly 1 damage), and every
## mission's `map_requirement` had zero readers.
##
## THE ONE WRITER of map state: campaign.map_data and the map keys on each Tactical Enemy
## (occupied_sectors, strongpoint_sector, boss_located, boss_sector). Every die goes
## through DiceManager under a context the QA seam can force. Effects that are not map
## state (XP, Morale, an injury roll, Colony Damage, Enemy Information) come back as ops
## for PlanetfallPhaseManager._apply_stability_ops(), the colony's own single writer.
##
## A sector is keyed "r,c" with a 0-based row and column, and shown 1-based ("R3 C7")
## because p.52 numbers the rows and columns for the dice.

const ColonyCrisisScript := preload("res://src/core/systems/PlanetfallColonyCrisis.gd")

const SCOUT_DISCOVERY_PATH := "res://data/planetfall/scout_discovery.json"
const EXPEDITION_TYPES_PATH := "res://data/planetfall/expedition_types.json"

## p.53: "mark 10 sectors on the map as Investigation Sites".
const INVESTIGATION_SITES := 10
## p.52: "The default is a 6 x 6 grid".
const DEFAULT_SIZE := 6
## p.52: "The top left adjacent square is numbered 1 and you then just count clockwise
## around the target." [row, col] offsets for D8 results 1-8.
const D8_OFFSETS := [[-1, -1], [-1, 0], [-1, 1], [0, 1], [1, 1], [1, 0], [1, -1], [0, -1]]
## A die rolled until it lands somewhere legal gives up after this many tries and picks
## among the legal answers instead, so a nearly full map cannot loop.
const MAX_REROLLS := 64

const ROW_DIE := "Planetfall Map Row"
const COL_DIE := "Planetfall Map Column"
const ADJACENT_DIE := "Planetfall Map Adjacent"
const PICK_DIE := "Planetfall Map Pick"
const EXPLORE_RESOURCE_DIE := "Planetfall Explore Resource"
const EXPLORE_HAZARD_DIE := "Planetfall Explore Hazard"
const ANCIENT_SIGN_DIE := "Planetfall Ancient Sign"
const ENEMY_INFO_DIE := "Planetfall Enemy Information"
const CONTESTED_DIE := "Planetfall Contested Sector"
const DISCOVERY_DIE := "Planetfall Scout Discovery"
const OBJECTIVE_DIE := "Planetfall Exploration Objective"
const RECON_DIE := "Planetfall Recon Marker"
const HUNT_DIE := "Planetfall Hunt Hazard"
const DEFENSES_DIE := "Planetfall Colony Defenses"

## The Final Breakthrough id (mission_data_breakthroughs.json) behind p.171's Hazard -1.
const SEMI_LIVING_ORGANISM := "semi_living_organism"

## The debrief question each mission's Campaign Factors need answered, and its page.
## Missions not listed read only `won`.
const OBJECTIVE_PROMPTS := {
	"investigation": "Discovery markers completed (p.116: 1 or more clears the site)",
	"scouting": "Recon markers investigated (p.117: each rolls 1D6, a 6 adds +1 Resource)",
	"exploration": "Objectives completed (p.118: each rolls 1D6 on the sector)",
	"science": "Samples collected (p.119: each rolls 1D6 for Research; any lowers the Resource)",
	"hunt": "Lifeform samples obtained (p.121: two authorize Bio-Analysis of the creature)",
	"patrol": "Objectives completed (p.122: 1 or more raises Colony Morale by 1)",
	"skirmish": "Objectives completed (p.124: both clear the enemy from the sector)",
	"delve": "Artifact acquired: 1, or 0 (p.133: the Ancient Site is removed)",
}

## The most a debrief may declare for a mission whose book page fixes the count.
const OBJECTIVE_CAPS := {"delve": 1, "patrol": 3, "skirmish": 2}

static var _discovery_cache: Array = []


## ============================================================================
## GEOMETRY (p.52)
## ============================================================================

static func key(r: int, c: int) -> String:
	return "%d,%d" % [r, c]


## [row, col] of a key, or [-1, -1].
static func coords(sector_key: String) -> Array:
	var parts: PackedStringArray = sector_key.split(",")
	if parts.size() != 2:
		return [-1, -1]
	return [int(parts[0]), int(parts[1])]


static func label(sector_key: String) -> String:
	var rc: Array = coords(sector_key)
	return "R%d C%d" % [int(rc[0]) + 1, int(rc[1]) + 1]


static func rows(md: Dictionary) -> int:
	var g: Variant = md.get("grid_size", [])
	return maxi(int(g[0]), 1) if g is Array and (g as Array).size() >= 2 else DEFAULT_SIZE


static func cols(md: Dictionary) -> int:
	var g: Variant = md.get("grid_size", [])
	return maxi(int(g[1]), 1) if g is Array and (g as Array).size() >= 2 else DEFAULT_SIZE


static func in_bounds(md: Dictionary, sector_key: String) -> bool:
	var rc: Array = coords(sector_key)
	return (int(rc[0]) >= 0 and int(rc[0]) < rows(md) and int(rc[1]) >= 0 \
			and int(rc[1]) < cols(md))


static func home_key(md: Dictionary) -> String:
	var h: Variant = md.get("home_sector", [])
	if h is Array and (h as Array).size() >= 2:
		return key(int(h[0]), int(h[1]))
	return ""


## The sector a D8 result points at from `sector_key`, or "" off the map.
static func neighbor(md: Dictionary, sector_key: String, d8: int) -> String:
	if d8 < 1 or d8 > 8:
		return ""
	var rc: Array = coords(sector_key)
	var off: Array = D8_OFFSETS[d8 - 1]
	var n: String = key(int(rc[0]) + int(off[0]), int(rc[1]) + int(off[1]))
	return n if in_bounds(md, n) else ""


static func adjacent_keys(md: Dictionary, sector_key: String) -> Array:
	var out: Array = []
	for d in range(1, 9):
		var n: String = neighbor(md, sector_key, d)
		if n != "":
			out.append(n)
	return out


## Squares apart, counting a diagonal as one (adjacency on p.52 includes diagonals).
static func distance(a: String, b: String) -> int:
	var ra: Array = coords(a)
	var rb: Array = coords(b)
	return maxi(absi(int(ra[0]) - int(rb[0])), absi(int(ra[1]) - int(rb[1])))


static func all_keys(md: Dictionary) -> Array:
	var out: Array = []
	for r in range(rows(md)):
		for c in range(cols(md)):
			out.append(key(r, c))
	return out


## ============================================================================
## SECTORS (pp.53-54)
## ============================================================================

## A sector's record, or {} for one nothing is known about. Fields: investigation,
## explored, resource, hazard, exploited, ancient_sign, ancient_site, site_mission_data.
static func sector(md: Dictionary, sector_key: String) -> Dictionary:
	var all: Variant = md.get("sectors", {})
	var s: Variant = (all as Dictionary).get(sector_key, {}) if all is Dictionary else {}
	return s if s is Dictionary else {}


static func _sector_for_write(campaign: Resource, sector_key: String) -> Dictionary:
	var md: Dictionary = campaign.map_data
	if not md.get("sectors") is Dictionary:
		md["sectors"] = {}
	var all: Dictionary = md["sectors"]
	if not all.get(sector_key) is Dictionary:
		all[sector_key] = {}
	return all[sector_key]


## Sectors carrying a Calamity flag ("anomaly" p.165, "swarm" p.167), in map order.
static func flagged(md: Dictionary, flag: String) -> Array:
	return all_keys(md).filter(func(k: String) -> bool:
		return bool(sector(md, k).get(flag, false)))


static func set_flag(campaign: Resource, sector_key: String, flag: String, on: bool) -> void:
	var s: Dictionary = _sector_for_write(campaign, sector_key)
	if on:
		s[flag] = true
	else:
		s.erase(flag)


## +`amount` Resource on a sector. An Explored or Exploited sector gains it now, and one
## with Resources again is Explored (p.169 allows the same of a Breakthrough); a sector
## not yet explored keeps it until it is (explore() reads it). Returns a line, no cite.
static func raise_resource(campaign: Resource, sector_key: String, amount: int) -> String:
	var s: Dictionary = _sector_for_write(campaign, sector_key)
	if bool(s.get("explored", false)):
		s["resource"] = int(s.get("resource", 0)) + amount
		s["exploited"] = int(s.resource) <= 0
		return "%s Resource +%d, now %d" % [label(sector_key), amount, int(s.resource)]
	s["resource_bonus"] = int(s.get("resource_bonus", 0)) + amount
	return "%s Resource +%d once it is explored" % [label(sector_key), amount]


## "unexplored", "explored" or "exploited" (p.54).
static func status(md: Dictionary, sector_key: String) -> String:
	var s: Dictionary = sector(md, sector_key)
	if bool(s.get("exploited", false)):
		return "exploited"
	return "explored" if bool(s.get("explored", false)) else "unexplored"


static func set_explored(campaign: Resource, sector_key: String, resource: int,
		hazard: int) -> void:
	var s: Dictionary = _sector_for_write(campaign, sector_key)
	s["explored"] = true
	s["resource"] = maxi(resource, 0)
	s["hazard"] = maxi(hazard, 0)
	# p.54: "Once Resources reach 0, the sector's status changes to Exploited".
	s["exploited"] = resource <= 0


## p.118: the Resource lowered by Exploration and Science; at 0 the sector is Exploited.
static func reduce_resource(campaign: Resource, sector_key: String, amount: int) -> int:
	var s: Dictionary = _sector_for_write(campaign, sector_key)
	var left: int = maxi(int(s.get("resource", 0)) - amount, 0)
	s["resource"] = left
	if left <= 0 and bool(s.get("explored", false)):
		s["exploited"] = true
	return left


## ============================================================================
## THE ENEMY ON THE MAP (pp.50-51)
## ============================================================================

static func _enemies(campaign: Resource) -> Array:
	if campaign == null or not "tactical_enemies" in campaign:
		return []
	return campaign.tactical_enemies


static func _enemy(campaign: Resource, idx: int) -> Dictionary:
	var all: Array = _enemies(campaign)
	if idx < 0 or idx >= all.size() or not all[idx] is Dictionary:
		return {}
	return all[idx]


## Where an enemy's located Strongpoint and tracked Boss are, for a screen to mark:
## {strongpoint, boss}, "" for each that is not known.
static func enemy_marks(campaign: Resource, idx: int) -> Dictionary:
	var e: Dictionary = _enemy(campaign, idx)
	return {
		"strongpoint": str(e.get("strongpoint_sector", ""))
				if bool(e.get("strongpoint_located", false)) else "",
		"boss": str(e.get("boss_sector", "")) if bool(e.get("boss_located", false)) else "",
	}


static func is_active(campaign: Resource, idx: int) -> bool:
	var e: Dictionary = _enemy(campaign, idx)
	return not e.is_empty() and not bool(e.get("defeated", false))


static func active_indices(campaign: Resource) -> Array:
	var out: Array = []
	for i in range(_enemies(campaign).size()):
		if is_active(campaign, i):
			out.append(i)
	return out


static func enemy_name(campaign: Resource, idx: int) -> String:
	var e: Dictionary = _enemy(campaign, idx)
	var t: Variant = e.get("type", {})
	return str((t as Dictionary).get("name", "Tactical Enemy")) if t is Dictionary \
			else "Tactical Enemy"


## The sectors one enemy holds, as keys.
static func held_by(campaign: Resource, idx: int) -> Array:
	var e: Dictionary = _enemy(campaign, idx)
	var out: Array = []
	var held: Variant = e.get("occupied_sectors", [])
	if held is Array:
		for k in held:
			if not str(k) in out:
				out.append(str(k))
	return out


## The active enemy holding a sector, or -1. A defeated enemy holds nothing (p.51).
static func occupant(campaign: Resource, sector_key: String) -> int:
	for i in active_indices(campaign):
		if held_by(campaign, i).has(sector_key):
			return i
	return -1


static func is_occupied(campaign: Resource, sector_key: String) -> bool:
	return occupant(campaign, sector_key) >= 0


## Mark a sector held by `idx`, taking it from any other enemy that held it.
static func occupy(campaign: Resource, idx: int, sector_key: String) -> void:
	var e: Dictionary = _enemy(campaign, idx)
	if e.is_empty():
		return
	var other: int = occupant(campaign, sector_key)
	if other >= 0 and other != idx:
		release(campaign, other, sector_key)
	var held: Array = held_by(campaign, idx)
	if not held.has(sector_key):
		held.append(sector_key)
	e["occupied_sectors"] = held


static func release(campaign: Resource, idx: int, sector_key: String) -> void:
	var e: Dictionary = _enemy(campaign, idx)
	if e.is_empty():
		return
	var held: Array = held_by(campaign, idx)
	held.erase(sector_key)
	e["occupied_sectors"] = held


## pp.156-157: a Tactical Enemy emerges in "a random map sector" that "cannot be in or
## adjacent to your colony"; the 2nd and 3rd also keep clear of "a sector held by another
## enemy". Returns the sector, or "" when the map has none to give.
static func emerge(campaign: Resource, idx: int, clear_of_enemies: bool) -> String:
	var md: Dictionary = campaign.map_data
	var hk: String = home_key(md)
	var others: Array = []
	for i in active_indices(campaign):
		if i != idx:
			others.append_array(held_by(campaign, i))
	var valid := func(k: String) -> bool:
		if hk != "" and distance(k, hk) <= 1:
			return false
		for o in others:
			if (clear_of_enemies and distance(k, str(o)) <= 1) or k == str(o):
				return false
		return true
	var k: String = random_sector_where(md, valid)
	if k != "":
		occupy(campaign, idx, k)
	return k


## ============================================================================
## DICE (p.52)
## ============================================================================

static func _dice() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/DiceManager") \
		if loop is SceneTree else null


static func _die(sides: int, context: String) -> int:
	var dm := _dice()
	if dm == null:
		return randi_range(1, sides)
	match sides:
		3:
			return int(dm.roll_d3(context))
		6:
			return int(dm.roll_d6(context))
		8:
			return int(dm.roll_d8(context))
		10:
			return int(dm.roll_d10(context))
		100:
			return int(dm.roll_d100(context))
	return _pick(sides, context) + 1


## A uniform 0-based index into `count` things: the smallest die that covers the count,
## rerolled while it is too high.
static func _pick(count: int, context: String) -> int:
	if count <= 1:
		return 0
	var sides: int = 3 if count <= 3 else 6 if count <= 6 else 8 if count <= 8 \
			else 10 if count <= 10 else 100
	for _i in range(MAX_REROLLS):
		var roll: int = _die(sides, context)
		if roll <= count:
			return roll - 1
	return 0


## The same forceable uniform pick, for another system's "randomly select" (p.93's
## Research Applications: "Use any appropriate die type").
static func pick_index(count: int, context: String) -> int:
	return _pick(count, context)


## p.52: "if your grid is 8 x 10, you would roll a D8 and D10".
static func random_sector(md: Dictionary) -> String:
	return key(_die(rows(md), ROW_DIE) - 1, _die(cols(md), COL_DIE) - 1)


## Random sectors until `valid` accepts one; "" when no sector on the map is valid.
static func random_sector_where(md: Dictionary, valid: Callable) -> String:
	var legal: Array = all_keys(md).filter(valid)
	if legal.is_empty():
		return ""
	for _i in range(MAX_REROLLS):
		var k: String = random_sector(md)
		if valid.call(k):
			return k
	return str(legal[_pick(legal.size(), PICK_DIE)])


## p.52: "If you need to pick a random sector adjacent to an existing one a D8 can be
## rolled." Rerolled while it points off the map or at a sector `valid` refuses.
## Returns {key, d8}, or {} when no adjacent sector is valid.
static func random_adjacent(md: Dictionary, from_key: String, valid: Callable) -> Dictionary:
	var legal: Array = []
	for d in range(1, 9):
		var n: String = neighbor(md, from_key, d)
		if n != "" and valid.call(n):
			legal.append(d)
	if legal.is_empty():
		return {}
	for _i in range(MAX_REROLLS):
		var d8: int = _die(8, ADJACENT_DIE)
		if legal.has(d8):
			return {"key": neighbor(md, from_key, d8), "d8": d8}
	var picked: int = int(legal[_pick(legal.size(), PICK_DIE)])
	return {"key": neighbor(md, from_key, picked), "d8": picked}


## ============================================================================
## CAMPAIGN SETUP (pp.52-53)
## ============================================================================

## How many Investigation Sites a new map gets: 10 (p.53) plus the expedition's own
## (p.52 Corporate Funded: "2 additional Investigation Sites"), read from the data file.
static func site_count_for(expedition_type: String) -> int:
	var extra: int = 0
	if FileAccess.file_exists(EXPEDITION_TYPES_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXPEDITION_TYPES_PATH))
		if parsed is Dictionary:
			for e in (parsed as Dictionary).get("entries", []):
				if e is Dictionary and str(e.get("type", "")) == expedition_type:
					extra = int((e.get("bonus", {}) as Dictionary).get(
							"extra_investigation_sites", 0)) if e.get("bonus") is Dictionary else 0
	return INVESTIGATION_SITES + extra


## Build a new map: the grid, the home sector, and `site_count` Investigation Sites.
## `home` is the player's pick (p.53 "Pick a home sector (or roll randomly)"); [] rolls.
static func generate(campaign: Resource, grid_rows: int, grid_cols: int, home: Array,
		site_count: int) -> Array:
	var md: Dictionary = {"grid_size": [maxi(grid_rows, 1), maxi(grid_cols, 1)],
			"sectors": {}, "generated": true}
	campaign.map_data = md
	var hk: String = ""
	if home.size() >= 2 and in_bounds(md, key(int(home[0]), int(home[1]))):
		hk = key(int(home[0]), int(home[1]))
	else:
		hk = random_sector(md)
	var hrc: Array = coords(hk)
	md["home_sector"] = [int(hrc[0]), int(hrc[1])]
	var lines: Array = ["Home sector: %s." % label(hk)]
	var placed: Array = []
	for _i in range(maxi(site_count, 0)):
		var site: String = place_investigation_site(campaign)
		if site != "":
			placed.append(label(site))
	lines.append("%d Investigation Sites: %s (p.53)." % [placed.size(), ", ".join(placed)])
	return lines


## p.53: "Determine the sectors randomly, but if you roll a sector that already has been
## selected, pick any empty sector adjacent instead." The home sector is selected too.
static func place_investigation_site(campaign: Resource) -> String:
	var md: Dictionary = campaign.map_data
	var hk: String = home_key(md)
	var taken := func(k: String) -> bool:
		return k == hk or bool(sector(md, k).get("investigation", false))
	var free := func(k: String) -> bool:
		return not taken.call(k)
	if all_keys(md).filter(free).is_empty():
		return ""
	for _i in range(MAX_REROLLS):
		var chosen: String = random_sector(md)
		if taken.call(chosen):
			chosen = str(random_adjacent(md, chosen, free).get("key", ""))
		if chosen != "":
			_sector_for_write(campaign, chosen)["investigation"] = true
			return chosen
	var fallback: String = random_sector_where(md, free)
	if fallback != "":
		_sector_for_write(campaign, fallback)["investigation"] = true
	return fallback


## Every save before 2026-10-28 has a map that was never built: keep its grid and home,
## turn any listed Investigation Sites into sector marks (rolling a full set when none
## were listed), and put each Tactical Enemy already on the campaign onto the map.
## Idempotent: a built map returns [] untouched.
static func ensure_map(campaign: Resource) -> Array:
	if campaign == null or not "map_data" in campaign:
		return []
	var md: Dictionary = campaign.map_data
	if bool(md.get("generated", false)):
		return []
	var listed: Array = md.get("investigation_sites", []) \
			if md.get("investigation_sites") is Array else []
	var home: Array = md.get("home_sector", []) if md.get("home_sector") is Array else []
	var expedition: String = str(campaign.expedition_type) if "expedition_type" in campaign \
			else ""
	var lines: Array = generate(campaign, rows(md), cols(md), home,
			0 if not listed.is_empty() else site_count_for(expedition))
	var md2: Dictionary = campaign.map_data
	for site in listed:
		if site is Array and (site as Array).size() >= 2:
			var k: String = key(int(site[0]), int(site[1]))
			if in_bounds(md2, k) and k != home_key(md2):
				_sector_for_write(campaign, k)["investigation"] = true
	var placed_one: bool = false
	for i in active_indices(campaign):
		if held_by(campaign, i).is_empty():
			var at: String = emerge(campaign, i, placed_one)
			placed_one = true
			if at != "":
				lines.append("%s holds %s." % [enemy_name(campaign, i), label(at)])
	return lines


## ============================================================================
## SCOUTING (pp.59-61)
## ============================================================================

## p.60 Scout Explore: "Roll 2D6 twice and pick the lowest score each time. The first
## score is the Resource Level of the sector, the second score is the Hazard Level". "If
## you roll a double 4, double 5, or double 6 when Exploring, the sector also contains an
## Ancient Sign."
static func roll_explore() -> Dictionary:
	var r1: int = _die(6, EXPLORE_RESOURCE_DIE)
	var r2: int = _die(6, EXPLORE_RESOURCE_DIE)
	var h1: int = _die(6, EXPLORE_HAZARD_DIE)
	var h2: int = _die(6, EXPLORE_HAZARD_DIE)
	return {
		"resource": mini(r1, r2), "hazard": mini(h1, h2), "dice": [r1, r2, h1, h2],
		"ancient_sign": (r1 == r2 and r1 >= 4) or (h1 == h2 and h1 >= 4),
	}


## Explore a sector as p.60 generates it "normally". `resource_bonus` is a Scouting
## Mission's Recon 6s (p.117). Returns the lines.
static func explore(campaign: Resource, sector_key: String, resource_bonus: int = 0) -> Array:
	var roll: Dictionary = roll_explore()
	var dice: Array = roll.dice
	var held: int = int(sector(campaign.map_data, sector_key).get("resource_bonus", 0))
	var resource: int = int(roll.resource) + resource_bonus + held
	var hazard: int = maxi(int(roll.hazard) - hazard_reduction(campaign), 0)
	set_explored(campaign, sector_key, resource, hazard)
	if held > 0:
		_sector_for_write(campaign, sector_key).erase("resource_bonus")
	var lines: Array = ["%s explored: Resource %d, Hazard %d (2D6 %d,%d and %d,%d, lowest each%s%s%s)."
			% [label(sector_key), resource, hazard, dice[0], dice[1], dice[2], dice[3],
			", +%d Recon" % resource_bonus if resource_bonus > 0 else "",
			", +%d held for it (p.166)" % held if held > 0 else "",
			", Hazard -1 Semi-living Organism" if hazard_reduction(campaign) > 0 else ""]]
	if bool(roll.ancient_sign):
		mark_ancient_sign(campaign, sector_key)
		lines.append("A double on the dice: %s also holds an Ancient Sign (p.60)."
				% label(sector_key))
	return lines


## Sectors Scout Explore may pick: "not enemy occupied, and which has not already been
## Exploited" (p.60), and not infested: "The Swarm prevents all access" (p.167).
static func explore_targets(campaign: Resource) -> Array:
	var md: Dictionary = campaign.map_data
	return all_keys(md).filter(func(k: String) -> bool:
		return (not is_occupied(campaign, k) and status(md, k) != "exploited"
				and not _infested(md, k)))


## An "A" on the map (p.53): "Completing any mission in the sector awards the Ancient
## Sign" (p.59).
static func mark_ancient_sign(campaign: Resource, sector_key: String) -> void:
	_sector_for_write(campaign, sector_key)["ancient_sign"] = true


## p.61: "Each time you obtain an Ancient Sign, you may roll 1D6. On a roll equal to or
## below the number of Ancient Signs you have so far, you succeed in locating an Ancient
## Site". "Once you successfully locate a site, all Signs you currently have are
## discarded", and several in one turn "are tested one at a time".
static func obtain_ancient_signs(campaign: Resource, count: int) -> Array:
	if campaign == null or not "ancient_signs" in campaign:
		return []
	var lines: Array = []
	var turn: int = int(campaign.campaign_turn) if "campaign_turn" in campaign else 0
	for _i in range(maxi(count, 0)):
		campaign.ancient_signs.append({"turn": turn})
		var held: int = campaign.ancient_signs.size()
		var roll: int = _die(6, ANCIENT_SIGN_DIE)
		if roll <= held:
			var site: String = place_ancient_site(campaign)
			campaign.ancient_signs.clear()
			lines.append("Ancient Sign: 1D6 %d against %d Sign(s). An Ancient Site is located at "
					% [roll, held] + "%s; the Signs are discarded (p.61)." % label(site))
		else:
			lines.append("Ancient Sign: 1D6 %d against %d Sign(s). Not there yet (p.61)."
					% [roll, held])
	return lines


## p.61: "Randomly pick a map sector the Site is inside. It can even be within your
## colony." `mission_data` marks a Site from the First Mission Data Breakthrough (p.169:
## "Fully exploring each of these Sites awards you 1 point of Mission Data").
static func place_ancient_site(campaign: Resource, mission_data: int = 0) -> String:
	var md: Dictionary = campaign.map_data
	var k: String = random_sector_where(md, func(s: String) -> bool:
		return not bool(sector(md, s).get("ancient_site", false)))
	if k == "":
		return ""
	var s: Dictionary = _sector_for_write(campaign, k)
	s["ancient_site"] = true
	if mission_data > 0:
		s["site_mission_data"] = mission_data
	return k


## p.171 Semi-living Organism: "Reduce all current and future Hazard levels on the map by
## -1." The "future" half is this, read off the Breakthrough the campaign rolled.
static func hazard_reduction(campaign: Resource) -> int:
	if campaign == null or not "final_breakthrough" in campaign:
		return 0
	return 1 if str(campaign.final_breakthrough) == SEMI_LIVING_ORGANISM else 0


## p.169 Mission Data Breakthroughs act on the map; PlanetfallMissionDataSystem names the
## actions and this places them. Returns the lines.
static func apply_breakthrough_actions(campaign: Resource, actions: Array) -> Array:
	var lines: Array = []
	if campaign == null or not "map_data" in campaign:
		return lines
	ensure_map(campaign)
	var md: Dictionary = campaign.map_data
	for a in actions:
		if not a is Dictionary:
			continue
		var count: int = int(a.get("count", 0))
		match str(a.get("action", "")):
			# First (p.169): "the location of 2 Ancient Sites. Place them randomly on your
			# map. Fully exploring each of these Sites awards you 1 point of Mission Data".
			# Final 01-10 Ancient Colony (p.169): "Add 2 Ancient Sites ... in random sectors."
			"place_ancient_sites":
				for _i in range(count):
					var k: String = place_ancient_site(campaign, int(a.get("md_per_site", 0)))
					if k != "":
						lines.append("An Ancient Site is located at %s (p.169)." % label(k))
			# Second (p.169): "Randomly select four map sectors. Each of them that is not
			# currently Explored is Explored immediately. Then increase the current Resource
			# value by +2. This can turn an Exploited sector into an Explored sector."
			"explore_random_sectors":
				var bonus: int = int(a.get("resource_bonus", 0))
				var picked: Array = []
				for _i in range(mini(count, all_keys(md).size())):
					var k: String = random_sector_where(md, func(s: String) -> bool:
						return not picked.has(s))
					if k == "":
						break
					picked.append(k)
					if status(md, k) == "unexplored":
						lines.append_array(explore(campaign, k))
					var s: Dictionary = _sector_for_write(campaign, k)
					s["resource"] = int(s.get("resource", 0)) + bonus
					s["exploited"] = int(s["resource"]) <= 0
					lines.append("%s: Resource +%d, now %d (p.169)." % [label(k), bonus,
							int(s["resource"])])
			# Third (p.169): "Randomly select two sectors, marking them for Investigation."
			"mark_investigation_sectors":
				var hk: String = home_key(md)
				for _i in range(count):
					var k: String = random_sector_where(md, func(s: String) -> bool:
						return s != hk and not bool(sector(md, s).get("investigation", false)))
					if k == "":
						break
					_sector_for_write(campaign, k)["investigation"] = true
					lines.append("%s is marked for Investigation (p.169)." % label(k))
			# Final 61-70 Semi-living Organism (p.171): the "current" half.
			"reduce_all_hazard_levels":
				var by: int = int(a.get("amount", 1))
				var touched: int = 0
				for k in all_keys(md):
					var s: Dictionary = sector(md, k)
					if bool(s.get("explored", false)) and int(s.get("hazard", 0)) > 0:
						_sector_for_write(campaign, k)["hazard"] = maxi(
								int(s.get("hazard", 0)) - by, 0)
						touched += 1
				lines.append("Every Hazard level on the map drops by %d (%d sector(s)) (p.171)."
						% [by, touched])
	return lines


## pp.60-61 Process Enemy Information, once per turn at Step 3: "For each enemy for which
## you have gathered Enemy Information, roll 1D6 ... If the roll is equal to or below the
## number of Enemy Information, you have tracked down one of their Bosses". At 6 "you
## ... can always opt to carry out the Strike". A Boss tracked last turn and not struck
## is lost (p.61 "you can try again in future campaign turns"), so every enemy is reset
## first. "Once you have captured a Boss, there is no need to collect Enemy Information
## for that enemy any longer." The Boss sits in "which enemy held sector ... this turn".
static func process_enemy_information(campaign: Resource) -> Array:
	var lines: Array = []
	for i in active_indices(campaign):
		var e: Dictionary = _enemy(campaign, i)
		e["boss_located"] = false
		e.erase("boss_sector")
		if bool(e.get("strongpoint_located", false)):
			continue
		var info: int = campaign.get_enemy_info_count(i) \
				if campaign.has_method("get_enemy_info_count") else 0
		if info <= 0:
			continue
		var tracked: bool = info >= 6
		var roll: int = 0
		if not tracked:
			roll = _die(6, ENEMY_INFO_DIE)
			tracked = roll <= info
		if not tracked:
			lines.append("%s: 1D6 %d against %d Enemy Information. Its Boss is not found (p.61)."
					% [enemy_name(campaign, i), roll, info])
			continue
		var held: Array = held_by(campaign, i)
		var at: String = str(held[_pick(held.size(), PICK_DIE)]) if not held.is_empty() else ""
		e["boss_located"] = true
		e["boss_sector"] = at
		lines.append("%s: %s Its Boss is in %s this turn; you may Strike (pp.61, 127)." % [
				enemy_name(campaign, i),
				"6 Enemy Information, the Strike is always open." if roll == 0
				else "1D6 %d against %d Enemy Information." % [roll, info],
				label(at) if at != "" else "an unknown sector"])
	return lines


## The p.59 Scout Discovery table, from data/planetfall/scout_discovery.json.
static func discovery_table() -> Array:
	if _discovery_cache.is_empty() and FileAccess.file_exists(SCOUT_DISCOVERY_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCOUT_DISCOVERY_PATH))
		if parsed is Dictionary:
			_discovery_cache = (parsed as Dictionary).get("entries", [])
	return _discovery_cache


static func discovery_for(roll: int) -> Dictionary:
	for e in discovery_table():
		if e is Dictionary and roll >= int(e.get("min", 0)) and roll <= int(e.get("max", 0)):
			return (e as Dictionary).duplicate(true)
	return {}


static func roll_discovery() -> Dictionary:
	var roll: int = _die(100, DISCOVERY_DIE)
	var entry: Dictionary = discovery_for(roll)
	entry["roll"] = roll
	return entry


## What a Discovery result needs from the player before it can apply: "sector" (p.59
## Exploration report: "Select any sector that has not yet been Explored"), "enemy" (Recon
## patrol: "select one", asked only when there is a choice), "scout_down" (escape on foot
## or play the mission, asked only when a scout was assigned), or "".
static func discovery_choice(campaign: Resource, entry: Dictionary, scout_id: String) -> String:
	match str(entry.get("effect", "")):
		"exploration_report":
			return "sector" if not unexplored_keys(campaign).is_empty() else ""
		"recon_patrol":
			return "enemy" if active_indices(campaign).size() > 1 else ""
		"scout_down":
			return "scout_down" if scout_id != "" else ""
	return ""


static func unexplored_keys(campaign: Resource) -> Array:
	var md: Dictionary = campaign.map_data
	return all_keys(md).filter(func(k: String) -> bool:
		return status(md, k) == "unexplored")


## Apply one p.59 Scout Discovery result. `choice`: sector (key), enemy_index, scout_down
## ("escape" or "mission"). Returns {lines, ops}.
static func apply_discovery(campaign: Resource, entry: Dictionary, scout_id: String,
		choice: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"lines": [], "ops": []}
	var md: Dictionary = campaign.map_data
	match str(entry.get("effect", "")):
		"good_practice":
			if scout_id != "":
				out.ops.append({"op": "xp", "character_id": scout_id,
						"amount": int(entry.get("scout_xp", 0))})
				out.lines.append("The assigned scout earns +%d XP (p.59)."
						% int(entry.get("scout_xp", 0)))
		"sos_signal":
			campaign.offer_mission("rescue", {})
			out.lines.append("You may play a Rescue Mission this turn. Choose any other mission "
					+ "and Colony Morale drops by %d (p.59)." % absi(int(entry.get(
					"morale_if_declined", 0))))
		"scout_down":
			_scout_down(campaign, entry, scout_id, str(choice.get("scout_down", "")), out)
		"exploration_report":
			var target: String = str(choice.get("sector", ""))
			var options: Array = unexplored_keys(campaign)
			if not options.has(target):
				target = str(options[0]) if not options.is_empty() else ""
			if target == "":
				out.lines.append("Every sector is already Explored (p.59).")
			else:
				out.lines.append_array(explore(campaign, target))
		"recon_patrol":
			var active: Array = active_indices(campaign)
			if active.is_empty():
				out.lines.append("No Tactical Enemies on the map: no event (p.59).")
			else:
				var idx: int = int(choice.get("enemy_index", active[0]))
				if not active.has(idx):
					idx = int(active[0])
				out.ops.append({"op": "enemy_info", "enemy_index": idx,
						"amount": int(entry.get("enemy_information", 1))})
				out.lines.append("+1 Enemy Information on %s (p.59)." % enemy_name(campaign, idx))
		"ancient_sign":
			var k: String = random_sector(md)
			mark_ancient_sign(campaign, k)
			out.lines.append("An Ancient Sign is marked in %s. Complete any mission there to "
					% label(k) + "obtain it (p.59).")
		"revised_survey":
			out.lines.append_array(_revised_survey(campaign, random_sector(md)))
		_:
			out.lines.append("The scouts find nothing (p.59).")
	return out


## p.59 Revised survey: "If it is not yet Explored, generate Resource and Hazard levels
## normally. If it is Explored but not yet Exploited, increase the Resource level by +1.
## If it has already been Exploited, generate new Resource and Hazard levels. You can
## Exploit it again."
static func _revised_survey(campaign: Resource, k: String) -> Array:
	var md: Dictionary = campaign.map_data
	match status(md, k):
		"explored":
			var s: Dictionary = _sector_for_write(campaign, k)
			s["resource"] = int(s.get("resource", 0)) + 1
			return ["Revised survey of %s: Resource +1, now %d (p.59)."
					% [label(k), int(s["resource"])]]
		"exploited":
			return ["Revised survey of %s, already Exploited: new levels (p.59)." % label(k)] \
					+ explore(campaign, k)
	return ["Revised survey of %s (p.59):" % label(k)] + explore(campaign, k)


## p.59 Scout Down!: with a scout assigned, "escape on foot" (an injury roll, "+2 XP if
## they survive") or play the mission to rescue them; with none, "the crash left no
## survivors", and the mission may still be played for "+1 Colony Morale".
static func _scout_down(campaign: Resource, entry: Dictionary, scout_id: String,
		pick: String, out: Dictionary) -> void:
	if scout_id == "":
		campaign.offer_mission("scout_down", {"scout_id": "",
				"dedication_morale": int(entry.get("dedication_morale", 0))})
		out.lines.append("No scout was assigned: the crash left no survivors. You may still "
				+ "play Scout Down! this turn for +%d Colony Morale (p.59)."
				% int(entry.get("dedication_morale", 0)))
		return
	if pick == "escape":
		var who: Dictionary = {}
		for c in campaign.roster:
			if c is Dictionary and str(c.get("id", "")) == scout_id:
				who = c
		var receipt: Dictionary = ColonyCrisisScript.new().injury_roll_receipt(who)
		out.lines.append_array(receipt.get("lines", []))
		out.ops.append_array(receipt.get("ops", []))
		var died: bool = false
		for op in receipt.get("ops", []):
			if op is Dictionary and str(op.get("op", "")) == "slain":
				died = true
		if not died:
			out.ops.append({"op": "xp", "character_id": scout_id,
					"amount": int(entry.get("scout_xp", 0))})
			out.lines.append("The scout makes it back on foot: +%d XP (p.59)."
					% int(entry.get("scout_xp", 0)))
		return
	campaign.offer_mission("scout_down", {"scout_id": scout_id})
	out.lines.append("Play Scout Down! this turn to rescue the scout (p.59).")


## ============================================================================
## ENEMY ACTIVITY (p.62)
## ============================================================================

## The map half of one Enemy Activity result for enemy `idx`. Returns {lines, raids}: the
## Raid count includes an expansion or relocation into the colony, which p.62 turns into
## a Raid. Patrol and Attack record this turn's mission offer.
static func apply_enemy_activity(campaign: Resource, idx: int, activity: String) -> Dictionary:
	match activity:
		"patrol":
			campaign.offer_mission("strike", {"enemy_index": idx, "patrol": true})
			return {"raids": 0, "lines": ["You may play a Strike Mission this turn to track down "
					+ "its Leader for 1 Enemy Information (p.62)."]}
		"relocate":
			return relocate(campaign, idx)
		"occupy":
			return expand(campaign, idx, 1)
		"rapid_expansion":
			return expand(campaign, idx, 2)
		"attack":
			campaign.offer_mission("pitched_battle", {"enemy_index": idx, "forced": true})
			return {"raids": 0, "lines": ["Play the Pitched Battle mission this turn; if you "
					+ "lose, roll on the Campaign Consequences table (pp.62, 127)."]}
		"raid":
			return {"raids": 1, "lines": []}
	return {"raids": 0, "lines": []}


## p.62 Occupy: "The enemy expands into a random adjacent sector ... randomly select an
## existing sector and then pick an unoccupied adjacent sector. If this would be your
## colony, treat this result as a 'Raid' result instead. If this would be a sector
## occupied by another enemy, randomly determine who gains control". Rapid expansion:
## "two adjacent sectors are occupied". `colony_is_raid` false (the p.156 Milestone
## expansion, which has no Raid clause) leaves the colony out of the choice instead.
static func expand(campaign: Resource, idx: int, count: int,
		colony_is_raid: bool = true) -> Dictionary:
	var out: Dictionary = {"raids": 0, "lines": []}
	var md: Dictionary = campaign.map_data
	var hk: String = home_key(md)
	var name: String = enemy_name(campaign, idx)
	for _n in range(count):
		var held: Array = held_by(campaign, idx)
		if held.is_empty():
			var at: String = emerge(campaign, idx, false)
			out.lines.append("%s takes %s." % [name, label(at)] if at != ""
					else "%s finds no sector to take." % name)
			continue
		var not_mine := func(k: String) -> bool:
			return not held_by(campaign, idx).has(k) and (colony_is_raid or k != hk)
		var sources: Array = held.filter(func(h: String) -> bool:
			return not adjacent_keys(md, h).filter(not_mine).is_empty())
		if sources.is_empty():
			out.lines.append("%s has no room left to expand." % name)
			break
		var src: String = str(sources[_pick(sources.size(), PICK_DIE)])
		var dest: String = str(random_adjacent(md, src, not_mine).get("key", ""))
		if dest == hk:
			out["raids"] += 1
			out.lines.append("%s's expansion would reach your colony: it is a Raid instead (p.62)."
					% name)
			continue
		var other: int = occupant(campaign, dest)
		if other >= 0:
			var roll: int = _die(6, CONTESTED_DIE)
			if roll >= 4:
				occupy(campaign, idx, dest)
				out.lines.append("%s takes %s from %s (1D6 %d) (p.62)."
						% [name, label(dest), enemy_name(campaign, other), roll])
			else:
				out.lines.append("%s holds %s against %s (1D6 %d) (p.62)."
						% [enemy_name(campaign, other), label(dest), name, roll])
			continue
		occupy(campaign, idx, dest)
		out.lines.append("%s occupies %s (p.62)." % [name, label(dest)])
	return out


## p.62 Relocate: "Randomly pick an enemy-occupied sector. They move to a random adjacent
## unoccupied sector. If the selected sector is your colony, they launch a Raid ... and
## move in the opposite direction."
static func relocate(campaign: Resource, idx: int) -> Dictionary:
	var out: Dictionary = {"raids": 0, "lines": []}
	var md: Dictionary = campaign.map_data
	var hk: String = home_key(md)
	var name: String = enemy_name(campaign, idx)
	var held: Array = held_by(campaign, idx)
	if held.is_empty():
		out.lines.append("%s holds no sector to move from." % name)
		return out
	var src: String = str(held[_pick(held.size(), PICK_DIE)])
	var free := func(k: String) -> bool:
		return occupant(campaign, k) < 0
	var adj: Dictionary = random_adjacent(md, src, free)
	if adj.is_empty():
		out.lines.append("%s cannot move out of %s." % [name, label(src)])
		return out
	var dest: String = str(adj.key)
	if dest == hk:
		out["raids"] += 1
		var back: String = neighbor(md, src, ((int(adj.d8) + 3) % 8) + 1)
		if back != "" and back != hk and free.call(back):
			release(campaign, idx, src)
			occupy(campaign, idx, back)
			out.lines.append("%s moves on your colony: a Raid, then it withdraws from %s to %s "
					% [name, label(src), label(back)] + "(p.62).")
		else:
			out.lines.append("%s moves on your colony: a Raid; it cannot withdraw and stays in %s "
					% [name, label(src)] + "(p.62).")
		return out
	release(campaign, idx, src)
	occupy(campaign, idx, dest)
	out.lines.append("%s moves from %s to %s (p.62)." % [name, label(src), label(dest)])
	return out


## p.62 Raid: "Colony Damage equal to the number of map sectors this enemy occupies +1
## ... If you have Colony Defenses, roll D6s equal to the number of defenses you have.
## Every die rolling a 4+ negates a point of damage." Returns {damage, base, mitigated}.
static func raid_damage(campaign: Resource, idx: int) -> Dictionary:
	var base: int = held_by(campaign, idx).size() + 1
	var defenses: int = int(campaign.colony_defenses) if "colony_defenses" in campaign else 0
	var mitigated: int = 0
	for _i in range(maxi(defenses, 0)):
		if _die(6, DEFENSES_DIE) >= 4:
			mitigated += 1
	return {"base": base, "mitigated": mitigated, "damage": maxi(base - mitigated, 0)}


## ============================================================================
## MISSIONS: MAP LOCATION (pp.115-130)
## ============================================================================

## Where a mission may be played, as [{key, enemy_index, label, patrol}]. An
## enemy-occupied sector is "inaccessible to your personnel" for any mission not fought
## against that enemy (p.50), and a Rescue or Scout Down! needs this turn's offer (p.59).
## The colony sector is the Pitched Battle's; the field missions are played outside it.
static func mission_sites(campaign: Resource, mission: Dictionary) -> Array:
	var md: Dictionary = campaign.map_data
	var hk: String = home_key(md)
	var mission_id: String = str(mission.get("id", ""))
	var out: Array = []
	var field := func(k: String) -> bool:
		return k != hk and not is_occupied(campaign, k) and not _infested(md, k)
	match str(mission.get("map_requirement", "")):
		"sector_marked_for_investigation":
			_add_sites(out, all_keys(md).filter(func(k: String) -> bool:
				return field.call(k) and bool(sector(md, k).get("investigation", false))))
		"unexplored_sector":
			_add_sites(out, all_keys(md).filter(func(k: String) -> bool:
				return (field.call(k) and status(md, k) == "unexplored"
						and not bool(sector(md, k).get("investigation", false)))))
		"explored_not_exploited_sector":
			_add_sites(out, all_keys(md).filter(func(k: String) -> bool:
				return field.call(k) and status(md, k) == "explored"))
		"resource_value_1_or_more":
			_add_sites(out, all_keys(md).filter(func(k: String) -> bool:
				return (field.call(k) and status(md, k) == "explored"
						and int(sector(md, k).get("resource", 0)) >= 1)))
		"within_4_sectors_of_colony":
			_add_sites(out, _near_home(campaign, 4).filter(field))
		"within_2_sectors_not_enemy_occupied":
			_add_sites(out, _near_home(campaign, 2).filter(field))
		"within_3_sectors_of_colony":
			if not campaign.get_mission_offer("rescue").is_empty():
				_add_sites(out, _near_home(campaign, 3).filter(field))
		"any_unexplored_sector":
			if not campaign.get_mission_offer("scout_down").is_empty():
				_add_sites(out, all_keys(md).filter(func(k: String) -> bool:
					return field.call(k) and status(md, k) == "unexplored"))
		"colony_sector":
			var attack: Dictionary = campaign.get_mission_offer("pitched_battle")
			if not attack.is_empty() and hk != "":
				var swarm: bool = bool(attack.get("swarm", false))
				out.append({"key": hk, "enemy_index": int(attack.get("enemy_index", -1)),
						"swarm": swarm, "label": "%s (your colony): %s attacks" % [label(hk),
						"the Swarm" if swarm
						else enemy_name(campaign, int(attack.get("enemy_index", -1)))]})
		"enemy_occupied_sector":
			for i in active_indices(campaign):
				for k in held_by(campaign, i):
					out.append({"key": k, "enemy_index": i,
							"label": "%s: held by %s" % [label(k), enemy_name(campaign, i)]})
			# p.167: "To defeat the Swarm ... This uses the Skirmish mission."
			if mission_id == "skirmish":
				for k in flagged(md, "swarm"):
					out.append({"key": str(k), "enemy_index": -1, "swarm": true,
							"label": "%s: infested by the Swarm (p.167)" % label(str(k))})
		"adjacent_to_enemy_sector":
			out.append_array(_strike_sites(campaign))
		"enemy_strongpoint_located":
			for i in active_indices(campaign):
				var e: Dictionary = _enemy(campaign, i)
				var sp: String = str(e.get("strongpoint_sector", ""))
				if bool(e.get("strongpoint_located", false)) and sp != "":
					out.append({"key": sp, "enemy_index": i, "label":
							"%s: %s Strongpoint" % [label(sp), enemy_name(campaign, i)]})
		"ancient_site_located":
			_add_sites(out, all_keys(md).filter(func(k: String) -> bool:
				return (not is_occupied(campaign, k) and not _infested(md, k)
						and bool(sector(md, k).get("ancient_site", false)))))
		_:
			if mission_id != "":
				_add_sites(out, all_keys(md).filter(field))
	return out


## Why a mission cannot be played, by its Map Location. The page cited is the mission's
## own (its Map Location entry), read from the mission data.
const UNAVAILABLE_REASONS := {
	"sector_marked_for_investigation": "No reachable sector is marked for Investigation",
	"unexplored_sector": "No reachable sector is left unexplored",
	"explored_not_exploited_sector": "No reachable sector is Explored and not yet Exploited",
	"resource_value_1_or_more": "No reachable Explored sector has a Resource value of 1 or more",
	"within_4_sectors_of_colony": "No reachable sector lies within 4 sectors of the colony",
	"within_2_sectors_not_enemy_occupied": "No reachable sector lies within 2 sectors of the colony",
	"within_3_sectors_of_colony": "Played only when this turn's Scout Discovery calls for a Rescue",
	"any_unexplored_sector": "Played only when this turn's Scout Discovery downs a scout",
	"colony_sector": "Played only when an enemy Attacks the colony",
	"enemy_occupied_sector": "No Tactical Enemy holds a sector",
	"adjacent_to_enemy_sector": "Needs a tracked Boss or this turn's enemy Patrol",
	"enemy_strongpoint_located": "No enemy Strongpoint has been located",
	"ancient_site_located": "No Ancient Site has been located",
}


## Whether a mission can be played this turn, why not, and where:
## {available, reason, sites}. pp.64-65 tie each mission to its Map Location, and an
## enemy Attack (p.62, "Play the Pitched Battle mission this campaign turn") leaves the
## Pitched Battle as the turn's only mission.
static func mission_availability(campaign: Resource, mission: Dictionary) -> Dictionary:
	if campaign == null or not "map_data" in campaign:
		return {"available": false, "reason": "The colony has no map yet.", "sites": []}
	var mission_id: String = str(mission.get("id", ""))
	var attack: Dictionary = campaign.get_mission_offer("pitched_battle") \
			if campaign.has_method("get_mission_offer") else {}
	if mission_id != "pitched_battle" and bool(attack.get("forced", false)):
		if bool(attack.get("swarm", false)):
			return {"available": false, "sites": [], "reason":
					"The Swarm has reached the colony: the Pitched Battle must be played this "
					+ "turn (p.167)."}
		return {"available": false, "sites": [], "reason":
				"%s is attacking the colony: the Pitched Battle must be played this turn (p.62)."
				% enemy_name(campaign, int(attack.get("enemy_index", -1)))}
	var sites: Array = mission_sites(campaign, mission)
	if not sites.is_empty():
		return {"available": true, "reason": "", "sites": sites}
	var why: String = str(UNAVAILABLE_REASONS.get(str(mission.get("map_requirement", "")),
			"No sector on the map meets this mission's Map Location"))
	var page: int = int(mission.get("page", 0))
	return {"available": false, "sites": [],
			"reason": "%s (p.%d)." % [why, page] if page > 0 else why + "."}


static func _add_sites(out: Array, keys: Array) -> void:
	for k in keys:
		out.append({"key": str(k), "enemy_index": -1, "label": _site_label(str(k))})


static func _site_label(k: String) -> String:
	return label(k)


static func _infested(md: Dictionary, k: String) -> bool:
	return bool(sector(md, k).get("swarm", false))


static func _near_home(campaign: Resource, reach: int) -> Array:
	var md: Dictionary = campaign.map_data
	var hk: String = home_key(md)
	if hk == "":
		return []
	return all_keys(md).filter(func(k: String) -> bool:
		return distance(k, hk) <= reach)


## p.127 Strike: "Adjacent to any enemy-occupied sector", once a Boss is tracked (p.61) or
## in answer to this turn's Patrol (p.62). A tracked Boss is struck from beside the
## sector it is in; "you can Strike only one of them during a given campaign turn".
static func _strike_sites(campaign: Resource) -> Array:
	var md: Dictionary = campaign.map_data
	var hk: String = home_key(md)
	var out: Array = []
	var free := func(k: String) -> bool:
		return k != hk and not is_occupied(campaign, k) and not _infested(md, k)
	var patrol: Dictionary = campaign.get_mission_offer("strike")
	for i in active_indices(campaign):
		var e: Dictionary = _enemy(campaign, i)
		var is_patrol: bool = not patrol.is_empty() and int(patrol.get("enemy_index", -1)) == i
		if not bool(e.get("boss_located", false)) and not is_patrol:
			continue
		var around: Array = [str(e.get("boss_sector", ""))] \
				if bool(e.get("boss_located", false)) and str(e.get("boss_sector", "")) != "" \
				else held_by(campaign, i)
		var seen: Array = []
		for h in around:
			for k in adjacent_keys(md, str(h)):
				if free.call(k) and not seen.has(k):
					seen.append(k)
		if seen.is_empty():
			for h in held_by(campaign, i):
				for k in adjacent_keys(md, str(h)):
					if free.call(k) and not seen.has(k):
						seen.append(k)
		var boss: bool = bool(e.get("boss_located", false))
		for k in seen:
			out.append({"key": k, "enemy_index": i, "patrol": not boss,
					"label": "%s: %s %s" % [label(k), enemy_name(campaign, i),
					"Boss" if boss else "patrol (its Leader)"]})
	var site: String = weapon_site(campaign)
	if site != "":
		out.append({"key": site, "enemy_index": -1, "weapon_site": true,
				"label": "%s: the super weapon site, held by a scouting force (p.165)"
				% label(site)})
	return out


## p.165: "Tracking down the weapon site requires an Enemy Information roll (see page
## 60) ... If no Tactical Enemies are on the map currently, randomly roll on the Tactical
## Enemies table to determine what you end up fighting." While a Tactical Enemy builds the
## weapon, the p.60 roll that tracks down its Boss opens the Strike, and a won Strike on
## it ends the Calamity (PlanetfallCalamitySystem.after_mission). With no builder on the
## map there is no Enemy Information to roll against, so the tracking roll cannot be
## made; the app opens the site to a Strike against the scouting force instead, the one
## reading under which this Calamity can end. The site's sector, or "".
static func weapon_site(campaign: Resource) -> String:
	if campaign == null or not "active_calamities" in campaign:
		return ""
	for cal in campaign.active_calamities:
		if not cal is Dictionary or bool(cal.get("resolved", false)) \
				or str(cal.get("id", "")) != "enemy_super_weapon":
			continue
		var p: Variant = cal.get("progress", {})
		if not p is Dictionary:
			return ""
		var idx: int = int((p as Dictionary).get("enemy_index", -1))
		if idx >= 0 and is_active(campaign, idx):
			return ""
		return str((p as Dictionary).get("site_sector", ""))
	return ""


## ============================================================================
## MISSIONS: CAMPAIGN FACTORS (pp.115-133), applied at Step 12
## ============================================================================

## Each mission's Campaign Factors on the map, plus the Ancient Sign a completed mission
## collects (p.59). `result` is the normalized battle result: mission_id, sector, won,
## objectives_completed, tactical_enemy_index, boss_present. Returns {lines, ops}.
static func apply_mission_factors(campaign: Resource, result: Dictionary) -> Dictionary:
	var out: Dictionary = {"lines": [], "ops": []}
	if campaign == null or not "map_data" in campaign:
		return out
	var md: Dictionary = campaign.map_data
	var k: String = str(result.get("sector", ""))
	var won: bool = bool(result.get("won", false))
	var objectives: int = maxi(int(result.get("objectives_completed", 0)), 0)
	var idx: int = int(result.get("tactical_enemy_index", -1))
	var at: String = label(k) if k != "" else "the mission sector"
	match str(result.get("mission_id", "")):
		"investigation":
			if k != "" and objectives >= 1:
				_sector_for_write(campaign, k)["investigation"] = false
				out.lines.append("%s is no longer an Investigation site (p.116)." % at)
		"scouting":
			if k != "":
				var bonus: int = 0
				for _i in range(objectives):
					if _die(6, RECON_DIE) == 6:
						bonus += 1
				out.lines.append_array(explore(campaign, k, bonus))
		"exploration":
			if k != "":
				_exploration_factors(campaign, k, objectives, out)
		"science":
			if k != "" and objectives > 0:
				var left: int = reduce_resource(campaign, k, 1)
				out.lines.append("Samples taken: %s Resource -1, now %d%s (p.119)." % [at, left,
						"; the sector is Exploited" if left <= 0 else ""])
		"hunt":
			var hazard: int = int(sector(md, k).get("hazard", 0)) if k != "" else 0
			if hazard > 0:
				var roll: int = _die(6, HUNT_DIE)
				if roll >= 5:
					_sector_for_write(campaign, k)["hazard"] = hazard - 1
					out.lines.append("Hunt: 1D6 %d, %s Hazard -1, now %d (p.121)."
							% [roll, at, hazard - 1])
				else:
					out.lines.append("Hunt: 1D6 %d, %s Hazard unchanged (p.121)." % [roll, at])
		"skirmish":
			if k != "" and objectives >= 2:
				_skirmish_clear(campaign, k, out)
		"scout_down":
			var offer: Dictionary = campaign.get_mission_offer("scout_down")
			if k != "" and status(md, k) == "unexplored":
				out.lines.append_array(explore(campaign, k))
			if won and str(offer.get("scout_id", "")) == "":
				out.ops.append({"op": "morale_adjust", "amount": 1})
				out.lines.append("The scout is not on your roster: +1 Colony Morale for saving "
						+ "them (p.126).")
		"strike":
			if is_active(campaign, idx):
				_strike_factors(campaign, idx, won, bool(result.get("boss_present", false)), out)
		"assault":
			if is_active(campaign, idx):
				_assault_factors(campaign, idx, won, out)
		"delve":
			if k != "" and objectives >= 1 and bool(sector(md, k).get("ancient_site", false)):
				var s: Dictionary = _sector_for_write(campaign, k)
				var md_bonus: int = int(s.get("site_mission_data", 0))
				s["ancient_site"] = false
				s.erase("site_mission_data")
				out.lines.append("The Artifact is acquired: the Ancient Site at %s is removed "
						% at + "(p.133).")
				# p.169 First Breakthrough: "Fully exploring each of these Sites awards you
				# 1 point of Mission Data". The phase manager notes it (one entry point).
				if md_bonus > 0:
					out.ops.append({"op": "mission_data", "amount": md_bonus,
							"source": "the Site at %s (p.169)" % at})
	if k != "" and won and bool(sector(md, k).get("ancient_sign", false)):
		_sector_for_write(campaign, k)["ancient_sign"] = false
		out.lines.append("The mission in %s collects its Ancient Sign (p.59)." % at)
		out.lines.append_array(obtain_ancient_signs(campaign, 1))
	return out


## p.118: "Roll 1D6 for each Objective you complete. Every 1 increases the Hazard level by
## +1 point. Every 2 has no effect. Every 3-6 reduces the Resource value of the sector by
## -1 point. Once the Resources reach 0, the sector is Exploited".
static func _exploration_factors(campaign: Resource, k: String, objectives: int,
		out: Dictionary) -> void:
	var rolls: Array = []
	for _i in range(objectives):
		var roll: int = _die(6, OBJECTIVE_DIE)
		rolls.append(roll)
		var s: Dictionary = _sector_for_write(campaign, k)
		if roll == 1:
			s["hazard"] = int(s.get("hazard", 0)) + 1
		elif roll >= 3:
			reduce_resource(campaign, k, 1)
	if rolls.is_empty():
		return
	var s2: Dictionary = sector(campaign.map_data, k)
	out.lines.append("Exploration of %s, 1D6 per Objective %s: Resource %d, Hazard %d%s (p.118)."
			% [label(k), str(rolls), int(s2.get("resource", 0)), int(s2.get("hazard", 0)),
			"; the sector is Exploited" if bool(s2.get("exploited", false)) else ""])


## p.124: "If you complete both Objectives, the enemy will no longer occupy this map
## sector. If this was their last sector, they move to a random adjacent sector ... you
## cannot destroy the final map sector occupied by a particular enemy without playing the
## Assault mission."
static func _skirmish_clear(campaign: Resource, k: String, out: Dictionary) -> void:
	var holder: int = occupant(campaign, k)
	if holder < 0:
		return
	var md: Dictionary = campaign.map_data
	var name: String = enemy_name(campaign, holder)
	if held_by(campaign, holder).size() > 1:
		release(campaign, holder, k)
		out.lines.append("%s is driven out of %s (p.124)." % [name, label(k)])
		return
	var hk: String = home_key(md)
	var adj: Dictionary = random_adjacent(md, k, func(s: String) -> bool:
		return s != hk and occupant(campaign, s) < 0)
	if adj.is_empty():
		out.lines.append("%s has nowhere to go and keeps %s, its last sector (p.124)."
				% [name, label(k)])
		return
	release(campaign, holder, k)
	occupy(campaign, holder, str(adj.key))
	out.lines.append("%s is driven out of its last sector and moves to %s (p.124)."
			% [name, label(str(adj.key))])


## p.128 Strike rewards: "If you secure the data from a Boss, you now know the location
## of the enemy Strongpoint. If you secure the data from a Leader, you receive one
## additional Enemy Information." p.51: the Strongpoint "is placed in a random sector
## occupied by the enemy in question".
static func _strike_factors(campaign: Resource, idx: int, won: bool, boss: bool,
		out: Dictionary) -> void:
	var e: Dictionary = _enemy(campaign, idx)
	e["boss_located"] = false
	e.erase("boss_sector")
	if not won:
		return
	if boss:
		var held: Array = held_by(campaign, idx)
		var sp: String = str(held[_pick(held.size(), PICK_DIE)]) if not held.is_empty() else ""
		e["strongpoint_located"] = sp != ""
		e["strongpoint_sector"] = sp
		out.lines.append("The Boss's data gives up the %s Strongpoint: %s (pp.51, 128)."
				% [enemy_name(campaign, idx), label(sp) if sp != "" else "no sector held"])
	else:
		out.ops.append({"op": "enemy_info", "enemy_index": idx, "amount": 1})
		out.lines.append("The Leader's data: +1 Enemy Information on %s (p.128)."
				% enemy_name(campaign, idx))


## pp.51, 129: a won Assault "destroys that enemy", "all occupied sectors are abandoned
## immediately", Colony Morale +5, and the Strongpoint sector may be rolled "as if it had
## just been Explored". A failed one leaves the Strongpoint "at full strength" and "a
## random map sector adjacent to the enemy Strongpoint becomes immediately occupied".
static func _assault_factors(campaign: Resource, idx: int, won: bool, out: Dictionary) -> void:
	var e: Dictionary = _enemy(campaign, idx)
	var sp: String = str(e.get("strongpoint_sector", ""))
	var name: String = enemy_name(campaign, idx)
	if won:
		campaign.mark_enemy_defeated(idx)
		out.ops.append({"op": "morale_adjust", "amount": 5})
		out.lines.append("The Strongpoint falls: %s is removed from the campaign, its sectors "
				% name + "are abandoned and Colony Morale rises by 5 (pp.51, 129).")
		if sp != "":
			out.lines.append_array(explore(campaign, sp))
		return
	if sp == "":
		return
	var md: Dictionary = campaign.map_data
	var hk: String = home_key(md)
	var adj: Dictionary = random_adjacent(md, sp, func(s: String) -> bool:
		return s != hk and occupant(campaign, s) < 0)
	if adj.is_empty():
		out.lines.append("The Assault fails; every sector around the %s Strongpoint is already "
				% name + "held (p.129).")
		return
	occupy(campaign, idx, str(adj.key))
	out.lines.append("The Assault fails: %s occupies %s beside its Strongpoint (pp.51, 129)."
			% [name, label(str(adj.key))])
