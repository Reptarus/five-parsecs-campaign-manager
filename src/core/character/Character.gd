extends Resource
class_name Character
## Consolidated character system following Framework Bible principles.
## Replaces CharacterManager with direct static methods and resource-based state.
##
## This consolidation eliminates Manager pattern violations while maintaining all functionality.
## All character generation logic now lives here instead of scattered across 15+ files.

## Schema version for save file migration (CRITICAL for data integrity)
@export var schema_version: int = 1

# Character Attributes
@export var name: String = ""

# Unique identifier for this character (generated automatically)
@export var character_id: String = ""

# Smart properties with migration validation and performance tracking
var _background: String = ""
var _motivation: String = ""
var _origin: String = ""
var _character_class: String = ""

# Performance optimization: Cache GlobalEnums singleton reference
@warning_ignore("untyped_declaration")
var _cached_global_enums = null

@export var background: String:
	get:
		return _background
	set(value):
		_background = _get_validated_enum_string(value, "background", "COLONIST")

@export var motivation: String:
	get:
		return _motivation
	set(value):
		_motivation = _get_validated_enum_string(value, "motivation", "SURVIVAL")

@export var origin: String:
	get:
		return _origin
	set(value):
		_origin = _get_validated_enum_string(value, "origin", "HUMAN")

@export var character_class: String:
	get:
		return _character_class
	set(value):
		_character_class = _get_validated_enum_string(value, "character_class", "BASELINE")

# Helper method for validated enum string conversion
func _get_validated_enum_string(value: Variant, enum_type: String, default: String) -> String:
	## Production-safe enum validation with defensive GlobalEnums access
	# Try cached reference first (fastest path)
	if _cached_global_enums != null:
		@warning_ignore("unsafe_method_access")
		if _cached_global_enums.has_method("to_string_value"):
			@warning_ignore("unsafe_method_access")
			return _cached_global_enums.to_string_value(enum_type, value)
	
	# Try runtime autoload access (works when game is running)
	if Engine.has_singleton("GlobalEnums"):
		_cached_global_enums = Engine.get_singleton("GlobalEnums")
		@warning_ignore("unsafe_method_access")
		if _cached_global_enums and _cached_global_enums.has_method("to_string_value"):
			@warning_ignore("unsafe_method_access")
			return _cached_global_enums.to_string_value(enum_type, value)
	
	# Fallback for development/testing
	return value if value is String else default

# Initialize smart properties with validated defaults
@warning_ignore("untyped_declaration")
func _init():
	# Generate unique character ID using timestamp + random component
	@warning_ignore("untyped_declaration")
	var timestamp = Time.get_ticks_msec()
	@warning_ignore("untyped_declaration")
	var random_component = randi() % 10000
	character_id = "char_%d_%d" % [timestamp, random_component]

	_background = "COLONIST"
	_motivation = "SURVIVAL"
	_origin = "HUMAN"
	_character_class = "BASELINE"

# Compatibility property for character_name (many files use this)
var character_name: String:
	get:
		return name
	set(value):
		name = value

# Core Stats
@export var combat: int = 0

# Bridge alias: BaseCrewMember convention uses combat_skill instead of combat
var combat_skill: int:
	get: return combat
	set(value): combat = value

@export var reactions: int = 0
@export var toughness: int = 0
@export var savvy: int = 0
@export var tech: int = 0
@export var speed: int = 4  # Movement stat - canonical per Five Parsecs rules ("Speed" in core rules)
@export var move: int = 4  # DEPRECATED: Use 'speed' instead. Alias kept for backwards compatibility.
@export var luck: int = 0    # Luck modifier for rolls

# Character State
@export var experience: int = 0
@export var credits: int = 0
@export var equipment: Array[String] = []
@export var is_captain: bool = false
@export var is_human: bool = false
@export var is_bot: bool = false
@export var is_soulless: bool = false
@export var created_at: String = ""
@export var status: String = "ACTIVE"  # ACTIVE, INJURED, RECOVERING, DEAD, MISSING, RETIRED

# Health (calculated from toughness + 2 in Five Parsecs)
@export var health: int = 5
@export var max_health: int = 5

# Injury System (Five Parsecs Core Rules p.94-95)
@export var injuries: Array[Dictionary] = []  # Each: {type: String, severity: int, recovery_turns: int, turn_sustained: int}

# Bot Upgrade System (Five Parsecs Core Rules p.98)
# Bots don't gain XP - they purchase upgrades with credits instead
@export var bot_upgrades: Array[String] = []  # IDs of installed bot upgrades

# Reaction Economy System (Five Parsecs Core Rules)
# Swift species limited to 1 reaction per round, others default to 3
@export var max_reactions_per_round: int = 3
var reactions_used_this_round: int = 0  # Reset at start of each battle round

# Implant System (Five Parsecs odds-and-ends loot table)
# Maximum 3 implants per character (rulebook limit)
@export var implants: Array[Dictionary] = []  # Each: {type: String, name: String, stat_bonus: Dictionary}

# Lifetime Statistics (Five Parsecs Campaign Tracking)
@export var lifetime_kills: int = 0              # Final blow kills
@export var lifetime_damage_dealt: int = 0       # Total damage inflicted
@export var lifetime_damage_taken: int = 0       # Total damage received
@export var battles_participated: int = 0        # Total battles fought
@export var battles_survived: int = 0            # Battles not KO'd
@export var critical_hits_landed: int = 0        # Critical successes
@export var advancement_history: Array[Dictionary] = []  # {turn, stat, old_value, new_value}

# Game-Specific Properties (merged from game/character/Character.gd)
@export var portrait_path: String = ""
@export var faction_relations: Dictionary = {}
@export var morale: int = 5
@export var credits_earned: int = 0
@export var missions_completed: int = 0

# Computed properties for injury/death status
var is_wounded: bool:
	get:
		return injuries.size() > 0

var is_dead: bool:
	get: return status == "DEAD"
	set(value):
		if value:
			status = "DEAD"
		elif status == "DEAD":
			status = "ACTIVE"

# Equipment compatibility: GameStateManager expects weapons/items arrays
var weapons: Array:
	get:
		var result: Array = []
		for item_name in equipment:
			var lower = item_name.to_lower()
			if "weapon" in lower or "rifle" in lower or "pistol" in lower or "blade" in lower or "gun" in lower:
				result.append(item_name)
		return result

var items: Array:
	get:
		var result: Array = []
		for item_name in equipment:
			var lower = item_name.to_lower()
			if not ("weapon" in lower or "rifle" in lower or "pistol" in lower or "blade" in lower or "gun" in lower):
				result.append(item_name)
		return result

var current_recovery_turns: int:
	get:
		if injuries.is_empty():
			return 0
		# Return the longest recovery time remaining
		var max_recovery: int = 0
		for injury in injuries:
			var remaining: int = injury.get("recovery_turns", 0)
			max_recovery = max(max_recovery, remaining)
		return max_recovery

# Signals for injury events
signal injury_added(injury: Dictionary)
signal injury_removed(index: int)
signal recovery_progressed(turns_remaining: int)

# Signals for implant events
signal implant_added(implant: Dictionary)
signal implant_removed(index: int)

# Signals for experience/advancement events
signal experience_changed(new_amount: int)
signal advancement_available(character: Resource)

## Add experience points to this character (called by GameState.add_crew_experience)
func add_experience(amount: int) -> void:
	experience += amount
	experience_changed.emit(experience)
	# Check if character can advance (1 XP = 1 advancement in Core Rules)
	if experience > 0:
		advancement_available.emit(self)
	print("Character %s gained %d XP (Total: %d)" % [character_name, amount, experience])

## Check if this character can spend XP to advance a stat
func can_advance() -> bool:
	return experience >= 1 and not is_bot  # Bots use credits for upgrades, not XP

## Spend 1 XP to advance a stat (returns true if successful)
func spend_xp_on_stat(stat_name: String) -> bool:
	if experience < 1:
		push_warning("Character %s has no XP to spend" % character_name)
		return false
	if is_bot:
		push_warning("Bots cannot use XP - use credits for bot upgrades instead")
		return false

	experience -= 1
	match stat_name.to_lower():
		"reactions":
			reactions += 1
		"speed":
			speed += 1
		"combat":
			combat += 1
		"toughness":
			toughness += 1
		"savvy":
			savvy += 1
		"tech":
			tech += 1
		"luck":
			luck += 1
		_:
			experience += 1  # Refund if invalid stat
			push_error("Invalid stat name for advancement: %s" % stat_name)
			return false

	# Track advancement history
	var current_turn: int = 0
	if Engine.has_singleton("GameStateManager"):
		var gsm = Engine.get_singleton("GameStateManager")
		if gsm and gsm.has_method("get_current_turn"):
			current_turn = gsm.get_current_turn()
	advancement_history.append({
		"turn": current_turn,
		"stat": stat_name,
		"new_value": get(stat_name.to_lower())
	})

	experience_changed.emit(experience)
	print("Character %s advanced %s (XP remaining: %d)" % [character_name, stat_name, experience])
	return true

#region Combat Modifier System - Equipment and Species Bonuses for Battle

## Get all active combat modifiers for battle calculations
## Returns Dictionary with all stat modifiers from equipment, implants, species, status effects
func get_combat_modifiers() -> Dictionary:
	var modifiers := {
		"combat_skill": 0,
		"reactions": 0,
		"toughness": 0,
		"savvy": 0,
		"speed": 0,
		"luck": 0,
		"hit_bonus": 0,
		"damage_bonus": 0,
		"armor_save_bonus": 0,
		"sources": []  # Track where bonuses come from for UI display
	}

	# Apply implant bonuses
	_apply_implant_bonuses(modifiers)

	# Apply bot upgrade bonuses (if applicable)
	_apply_bot_upgrade_bonuses(modifiers)

	# Apply species bonuses
	_apply_species_bonuses(modifiers)

	# Apply injury penalties
	_apply_injury_penalties(modifiers)

	return modifiers

## Apply bonuses from installed implants
func _apply_implant_bonuses(modifiers: Dictionary) -> void:
	for implant in implants:
		var stat_bonus: Dictionary = implant.get("stat_bonus", {})
		for stat_name: String in stat_bonus.keys():
			var bonus: int = stat_bonus[stat_name]
			if modifiers.has(stat_name):
				modifiers[stat_name] += bonus
				modifiers["sources"].append({
					"type": "implant",
					"name": implant.get("name", "Unknown Implant"),
					"stat": stat_name,
					"value": bonus
				})

## Apply bonuses from bot upgrades (Bots only)
func _apply_bot_upgrade_bonuses(modifiers: Dictionary) -> void:
	if origin.to_lower() != "bot" and origin.to_lower() != "soulless":
		return

	for upgrade_id: String in bot_upgrades:
		var bonus := _get_bot_upgrade_bonus(upgrade_id)
		if bonus.is_empty():
			continue

		for stat_name: String in bonus.keys():
			if modifiers.has(stat_name):
				modifiers[stat_name] += bonus[stat_name]
				modifiers["sources"].append({
					"type": "bot_upgrade",
					"name": upgrade_id,
					"stat": stat_name,
					"value": bonus[stat_name]
				})

## Get stat bonuses for a specific bot upgrade
func _get_bot_upgrade_bonus(upgrade_id: String) -> Dictionary:
	match upgrade_id.to_lower():
		"combat_protocols":
			return {"combat_skill": 1}
		"enhanced_sensors":
			return {"reactions": 1, "hit_bonus": 1}
		"reinforced_frame":
			return {"toughness": 1}
		"speed_boost":
			return {"speed": 1}
		"tactical_module":
			return {"savvy": 1}
		_:
			return {}

## Apply species-specific combat bonuses
func _apply_species_bonuses(modifiers: Dictionary) -> void:
	match origin.to_lower():
		"swift":
			# Swift: -1 to ranged attacks against them (enemy hit penalty)
			modifiers["sources"].append({
				"type": "species",
				"name": "Swift",
				"stat": "defense_vs_ranged",
				"value": 1
			})
		"stalker":
			# Stalker: +2 hit from ambush positions
			modifiers["sources"].append({
				"type": "species",
				"name": "Stalker",
				"stat": "ambush_hit_bonus",
				"value": 2
			})
		"kerin", "k'erin":
			# K'Erin: +1 brawl, handled in BattleCalculations
			modifiers["sources"].append({
				"type": "species",
				"name": "K'Erin",
				"stat": "brawl_bonus",
				"value": 1
			})
		"hulker":
			# Hulker: +2 melee damage, handled in BattleCalculations
			modifiers["sources"].append({
				"type": "species",
				"name": "Hulker",
				"stat": "melee_damage_bonus",
				"value": 2
			})
		"felinoid":
			# Felinoid: Lightning reflexes
			modifiers["reactions"] += 1
			modifiers["sources"].append({
				"type": "species",
				"name": "Felinoid",
				"stat": "reactions",
				"value": 1
			})
		"bot", "soulless":
			# Bot/Soulless: 5+ natural armor
			modifiers["sources"].append({
				"type": "species",
				"name": "Bot/Soulless",
				"stat": "natural_armor",
				"value": 5
			})
		"reptilian":
			# Reptilian: 6+ natural armor
			modifiers["sources"].append({
				"type": "species",
				"name": "Reptilian",
				"stat": "natural_armor",
				"value": 6
			})
		"insectoid":
			# Insectoid: 5+ natural armor
			modifiers["sources"].append({
				"type": "species",
				"name": "Insectoid",
				"stat": "natural_armor",
				"value": 5
			})
		"krag":
			# Krag (Compendium DLC): Cannot Dash, reroll natural 1 vs Rivals
			var _dlc_krag = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
			if _dlc_krag and _dlc_krag.is_feature_enabled(_dlc_krag.ContentFlag.SPECIES_KRAG):
				modifiers["sources"].append({
					"type": "species",
					"name": "Krag",
					"stat": "no_dash",
					"value": 1
				})
				modifiers["sources"].append({
					"type": "species",
					"name": "Krag",
					"stat": "reroll_vs_rivals",
					"value": 1
				})
		"skulker":
			# Skulker (Compendium DLC): Ignore difficult ground, low obstacles, poison resist
			var _dlc_skulker = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
			if _dlc_skulker and _dlc_skulker.is_feature_enabled(_dlc_skulker.ContentFlag.SPECIES_SKULKER):
				modifiers["sources"].append({
					"type": "species",
					"name": "Skulker",
					"stat": "ignore_difficult_ground",
					"value": 1
				})
				modifiers["sources"].append({
					"type": "species",
					"name": "Skulker",
					"stat": "ignore_low_obstacles",
					"value": 1
				})
				modifiers["sources"].append({
					"type": "species",
					"name": "Skulker",
					"stat": "poison_resist_3plus",
					"value": 3
				})

## Apply penalties from active injuries
func _apply_injury_penalties(modifiers: Dictionary) -> void:
	for injury in injuries:
		var injury_type: String = injury.get("type", "")
		var severity: int = injury.get("severity", 1)

		match injury_type.to_lower():
			"wounded":
				modifiers["combat_skill"] -= severity
				modifiers["sources"].append({
					"type": "injury",
					"name": "Wounded",
					"stat": "combat_skill",
					"value": -severity
				})
			"leg_wound":
				modifiers["speed"] -= severity
				modifiers["sources"].append({
					"type": "injury",
					"name": "Leg Wound",
					"stat": "speed",
					"value": -severity
				})
			"concussion":
				modifiers["reactions"] -= severity
				modifiers["savvy"] -= severity
				modifiers["sources"].append({
					"type": "injury",
					"name": "Concussion",
					"stat": "reactions/savvy",
					"value": -severity
				})

## Get effective combat skill including all modifiers
func get_effective_combat_skill() -> int:
	var modifiers := get_combat_modifiers()
	return combat + modifiers.get("combat_skill", 0)

## Get effective toughness including all modifiers
func get_effective_toughness() -> int:
	var modifiers := get_combat_modifiers()
	return toughness + modifiers.get("toughness", 0)

## Get effective reactions including all modifiers
func get_effective_reactions() -> int:
	var modifiers := get_combat_modifiers()
	return reactions + modifiers.get("reactions", 0)

## Get natural armor save (for species with natural armor)
func get_natural_armor_save() -> int:
	match origin.to_lower():
		"bot", "soulless", "insectoid":
			return 5  # 5+ save
		"reptilian":
			return 6  # 6+ save
		_:
			return 7  # No natural armor (7+ means impossible)

## Check if character has natural armor
func has_natural_armor() -> bool:
	return get_natural_armor_save() < 7

#endregion

# Character Generation - Direct static methods replace CharacterManager
static func generate_character(background_type: String = "") -> Character:
	## Production-ready character generation with comprehensive validation
	@warning_ignore("untyped_declaration")
	var character = Character.new()
	
	# Safe random generation using Framework Bible patterns
	character.name = _generate_name()
	character.background = background_type if not background_type.is_empty() else _generate_background()
	character.motivation = _generate_motivation()
	
	# Generate stats with proper bounds checking
	character.combat = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.reactions = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.toughness = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.savvy = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.tech = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 1)
	character.speed = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 4)
	character.move = character.speed  # Keep move and speed in sync (speed is canonical)
	character.luck = SafeTypeConverter.safe_int(_roll_dice_safe(1, 6), 0)
	
	# Initial equipment and state
	character.credits = SafeTypeConverter.safe_int(_roll_dice_safe(2, 6) * 10, 20)
	@warning_ignore("unsafe_call_argument")
	character.equipment = _generate_starting_equipment(character.background)
	character.created_at = Time.get_datetime_string_from_system()
	
	print("Character generated: %s (%s)" % [character.name, character.background])
	return character

static func generate_crew_members(count: int) -> Array[Character]:
	## Generate multiple crew members for initial crew creation
	var crew: Array[Character] = []
	count = SafeTypeConverter.safe_int(count, 4)  # Default to 4 crew members
	
	for i in range(count):
		@warning_ignore("untyped_declaration")
		var member = generate_character()
		crew.append(member)
	
	return crew

static func create_captain_from_crew(crew_member: Character) -> Character:
	## Promote crew member to captain with appropriate bonuses
	if crew_member == null:
		push_error("Cannot create captain from null crew member")
		return generate_character()  # Fallback
	
	crew_member.is_captain = true
	# Captain gets slight stat bonus
	crew_member.combat = min(crew_member.combat + 1, 6)
	crew_member.reactions = min(crew_member.reactions + 1, 6)
	
	print("Captain created: %s" % crew_member.name)
	return crew_member

# Safe dice rolling with fallback for headless mode
static func _roll_dice_safe(num_dice: int, sides: int) -> int:
	## Safe dice rolling with DiceManager fallback
	if Engine.has_singleton("DiceManager"):
		@warning_ignore("untyped_declaration")
		var dice_manager = Engine.get_singleton("DiceManager")
		if dice_manager and dice_manager.has_method("roll_dice"):
			@warning_ignore("unsafe_method_access")
			return dice_manager.roll_dice(num_dice, sides)
	
	# Fallback for headless mode or missing DiceManager
	@warning_ignore("untyped_declaration")
	var total = 0
	for i in range(num_dice):
		total += randi_range(1, sides)
	return total

# Private generation methods - all logic consolidated here
static func _generate_name(existing_names: Array = [], species: String = "human") -> String:
	# DLC: Use compendium species-specific names for non-human origins
	if species.to_lower() != "human" and species.to_lower() != "":
		var CompendiumWorldOpts = preload("res://src/data/compendium_world_options.gd")
		var comp_name: String = CompendiumWorldOpts.generate_name(species)
		if not comp_name.is_empty() and comp_name not in existing_names:
			return comp_name
	# Expanded first names (30 names) - diverse, sci-fi appropriate
	@warning_ignore("untyped_declaration")
	var first_names = [
		# Original 8
		"Alex", "Morgan", "River", "Casey", "Taylor", "Jordan", "Avery", "Riley",
		# Added 22 more diverse names
		"Sam", "Blake", "Quinn", "Drew", "Kai", "Nova", "Zara", "Rex",
		"Sky", "Vale", "Ash", "Sage", "Jax", "Luna", "Max", "Rae",
		"Phoenix", "Storm", "Ember", "Finn", "Iris", "Leo", "Mira", "Orion",
		"Piper", "Raven", "Soren", "Tara", "Vega", "Winter"
	]
	
	# Expanded last names (50 names) - using Five Parsecs JSON data
	@warning_ignore("untyped_declaration")
	var last_names = [
		# Original 8
		"Smith", "Chen", "Garcia", "Okafor", "Johansson", "Singh", "Kowalski", "Martinez",
		# From colony names (NameGenerationTables.json)
		"Ingram", "Larsen", "Greenway", "Mustaine", "Kevill", "Duplantier", 
		"Sattler", "Hetfield", "Friden", "Ryan", "Gossow", "Parkes", "Hegg",
		"Dickinson", "Shelton", "Scalzi", "Lindberg", "Willet", "Halford",
		"Baker", "Lee", "Cavalera", "Plant", "Nasic", "Bryntse",
		# From world names (NameGenerationTables.json) 
		"Samsonov", "Foch", "Pershing", "Cadorna", "Monash", "Mackensen",
		"Falkenhayn", "Byng", "Lanrezac", "Allenby", "Gough", "Currie",
		"Danilov", "Joffre", "Petain", "Brusilov", "Fuller", "Birdwood"
	]
	
	# Try to generate unique name (up to 20 attempts)
	@warning_ignore("untyped_declaration")
	var attempts = 0
	@warning_ignore("untyped_declaration", "shadowed_variable")
	var name = ""
	
	while attempts < 20:
		@warning_ignore("unsafe_call_argument", "untyped_declaration")
		var first = SafeTypeConverter.safe_array_get(first_names, randi() % first_names.size(), "Unknown")
		@warning_ignore("unsafe_call_argument", "untyped_declaration")
		var last = SafeTypeConverter.safe_array_get(last_names, randi() % last_names.size(), "Spacer")
		name = "%s %s" % [first, last]
		
		# Check if name is unique
		if not name in existing_names:
			return name
		
		attempts += 1
	
	# Fallback: add number suffix if still duplicate after 20 attempts
	return name + " " + str(randi() % 100 + 1)

static func _generate_background() -> String:
	@warning_ignore("untyped_declaration")
	var backgrounds = ["Military", "Trader", "Explorer", "Engineer", "Medic", "Pilot", "Criminal", "Scholar"]
	@warning_ignore("unsafe_call_argument")
	return SafeTypeConverter.safe_array_get(backgrounds, randi() % backgrounds.size(), "Civilian")

static func _generate_motivation() -> String:
	@warning_ignore("untyped_declaration")
	var motivations = ["Wealth", "Fame", "Revenge", "Family", "Adventure", "Knowledge", "Justice", "Survival"]
	@warning_ignore("unsafe_call_argument")
	return SafeTypeConverter.safe_array_get(motivations, randi() % motivations.size(), "Unknown")

@warning_ignore("shadowed_variable")
static func _generate_starting_equipment(background: String) -> Array[String]:
	## Generate starting equipment based on character background
	@warning_ignore("shadowed_variable")
	var equipment: Array[String] = []
	
	# Base equipment for all characters
	equipment.append("Basic Kit")
	equipment.append("Clothing")
	
	# Background-specific equipment
	match background:
		"Military":
			equipment.append("Combat Rifle")
			equipment.append("Body Armor")
		"Trader":
			equipment.append("Hand Weapon")
			equipment.append("Trade Goods")
		"Engineer":
			equipment.append("Tool Kit")
			equipment.append("Repair Kit")
		"Medic":
			equipment.append("Medical Kit")
			equipment.append("Stimms")
		"Pilot":
			equipment.append("Hand Weapon")
			equipment.append("Navigation Kit")
		_:
			equipment.append("Hand Weapon")
			equipment.append("Basic Gear")
	
	return equipment

# Validation methods
func is_valid() -> bool:
	## Validate character data integrity
	return not name.is_empty() and combat > 0 and reactions > 0 and toughness > 0

func get_display_name() -> String:
	## Safe display name with fallback
	return name if not name.is_empty() else "Unnamed Character"

func get_total_stats() -> int:
	## Calculate total stat value for balance checking
	return combat + reactions + toughness + savvy + tech + move

# ========== GAME-SPECIFIC METHODS (merged from game/character/Character.gd) ==========

func add_kill() -> void:
	## Track a kill for this character
	lifetime_kills += 1

func complete_mission(mission_credits: int = 0) -> void:
	## Track mission completion
	missions_completed += 1
	if mission_credits > 0:
		credits_earned += mission_credits

func modify_morale(amount: int) -> void:
	## Apply morale changes (clamped 0-10)
	morale = clampi(morale + amount, 0, 10)

func set_faction_relation(faction_id: String, value: int) -> void:
	faction_relations[faction_id] = value

func get_faction_relation(faction_id: String) -> int:
	return faction_relations.get(faction_id, 0)

func get_portrait() -> String:
	if portrait_path.is_empty():
		return "res://assets/portraits/default.png"
	return portrait_path

func set_portrait(path: String) -> void:
	portrait_path = path

func get_experience_summary() -> String:
	return "Level %d (%d XP)" % [experience / 100 + 1, experience]

func get_service_record() -> String:
	return "Missions: %d | Kills: %d | Credits: %d" % [missions_completed, lifetime_kills, credits_earned]

# ========== BOT UPGRADE SYSTEM (Five Parsecs p.98) ==========

func _is_bot() -> bool:
	## Check if this character is a bot (Origin.BOT)
	return origin == "BOT"

func has_bot_upgrade(upgrade_id: String) -> bool:
	## Check if bot has specific upgrade installed
	return upgrade_id in bot_upgrades

func add_bot_upgrade(upgrade_id: String) -> void:
	## Add bot upgrade to installed list (called by AdvancementSystem)
	if upgrade_id not in bot_upgrades:
		bot_upgrades.append(upgrade_id)
		print("Character %s installed bot upgrade: %s" % [name, upgrade_id])


# ========== REACTION ECONOMY SYSTEM (Five Parsecs Core Rules) ==========

func get_max_reactions() -> int:
	## Get max reactions per round, accounting for species restrictions (Swift = 1)
	# Check if Swift species via origin (origin stores species/race info)
	if _origin == "SWIFT" or _origin == "Swift" or _origin.to_lower() == "swift":
		return 1  # Swift aliens limited to 1 reaction per round

	return max_reactions_per_round


func get_reactions_remaining() -> int:
	## Get number of reactions remaining this round
	# Note: Using int(max()) for Godot 4.5 compatibility (maxi() added in 4.6)
	return int(max(0, get_max_reactions() - reactions_used_this_round))


func can_use_reaction() -> bool:
	## Check if character has reactions remaining
	return get_reactions_remaining() > 0


func spend_reaction() -> bool:
	## Spend a reaction if available. Returns true if successful.
	if not can_use_reaction():
		print("Character %s has no reactions remaining (used %d/%d)" % [
			character_name, reactions_used_this_round, get_max_reactions()
		])
		return false

	reactions_used_this_round += 1
	print("Character %s used reaction (%d/%d remaining)" % [
		character_name, get_reactions_remaining(), get_max_reactions()
	])
	return true


func reset_reactions() -> void:
	## Reset reactions for a new battle round
	reactions_used_this_round = 0


func is_swift() -> bool:
	## Check if this character is a Swift species
	return _origin == "SWIFT" or _origin == "Swift" or _origin.to_lower() == "swift"


# ========== STATUS BRIDGE (String ↔ int enum) ==========
# Maps between Character.status (String) and GameEnums.CharacterStatus (int)
# Enum ordinals: NONE=0, HEALTHY=1, INJURED=2, RECOVERING=3, DEAD=4, MISSING=5, RETIRED=6

func get_status_enum() -> int:
	match status:
		"ACTIVE": return 1  # HEALTHY
		"INJURED": return 2
		"RECOVERING": return 3
		"DEAD": return 4
		"MISSING": return 5
		"RETIRED": return 6
		_: return 0  # NONE

func set_status_from_enum(value: int) -> void:
	match value:
		0, 1: status = "ACTIVE"
		2: status = "INJURED"
		3: status = "RECOVERING"
		4: status = "DEAD"
		5: status = "MISSING"
		6: status = "RETIRED"
		_: status = "ACTIVE"


# ========== INJURY MANAGEMENT (Five Parsecs p.94-95) ==========

func add_injury(injury: Dictionary) -> void:
	## Add an injury to the character
	if not injury.has("type") or not injury.has("recovery_turns"):
		push_error("Character.add_injury: Invalid injury data - missing required fields")
		return
	injuries.append(injury)
	status = "INJURED"

func remove_injury(index: int) -> void:
	## Remove an injury by index (when fully healed)
	if index < 0 or index >= injuries.size():
		push_error("Character.remove_injury: Invalid injury index %d" % index)
		return
	injuries.remove_at(index)
	if injuries.is_empty():
		status = "ACTIVE"

func process_recovery_turn() -> void:
	## Called each campaign turn during post-battle or upkeep phase
	var healed_indices: Array[int] = []

	# Reduce recovery time for all injuries
	for i in range(injuries.size()):
		var inj_entry: Dictionary = injuries[i]
		var current_turns: int = inj_entry.get("recovery_turns", 0)
		inj_entry["recovery_turns"] = max(0, current_turns - 1)

		# Mark as healed if recovery complete
		if inj_entry["recovery_turns"] == 0:
			healed_indices.append(i)

	# Remove healed injuries (reverse order to maintain indices)
	healed_indices.reverse()
	for index in healed_indices:
		remove_injury(index)

	# Emit progress signal
	if not injuries.is_empty():
		recovery_progressed.emit(current_recovery_turns)

# ========== IMPLANT MANAGEMENT (Five Parsecs Odds & Ends Loot) ==========

const MAX_IMPLANTS: int = 3

## Implant type registry (Core Rules - Odds and Ends loot table)
const IMPLANT_TYPES: Dictionary = {
	"NEURAL_LINK": {"name": "Neural Link", "stat_bonus": {"savvy": 1}, "description": "Enhanced cognitive processing"},
	"COMBAT_REFLEX": {"name": "Combat Reflex", "stat_bonus": {"reactions": 1}, "description": "Accelerated reflexes"},
	"DERMAL_ARMOR": {"name": "Dermal Armor", "stat_bonus": {"toughness": 1}, "description": "Sub-dermal plating"},
	"MUSCLE_GRAFT": {"name": "Muscle Graft", "stat_bonus": {"speed": 1}, "description": "Synthetic muscle augmentation"},
	"TARGETING_EYE": {"name": "Targeting Eye", "stat_bonus": {"combat": 1}, "description": "Optical targeting system"},
	"LUCK_CHIP": {"name": "Luck Chip", "stat_bonus": {"luck": 1}, "description": "Neural luck optimizer", "humans_only": true}
}

## Map loot item names to implant type keys
const LOOT_TO_IMPLANT_MAP: Dictionary = {
	"Boosted Arm": "MUSCLE_GRAFT",
	"Boosted Leg": "MUSCLE_GRAFT",
	"Health Boost": "DERMAL_ARMOR",
	"Pain Suppressor": "DERMAL_ARMOR",
	"Night Sight": "TARGETING_EYE",
	"Neural Optimization": "NEURAL_LINK",
	"Combat Stimulator": "COMBAT_REFLEX",
	"Lucky Charm": "LUCK_CHIP"
}

static func create_implant_from_type(implant_type_key: String) -> Dictionary:
	## Create an implant dictionary from a type key
	if not IMPLANT_TYPES.has(implant_type_key):
		return {}
	var template: Dictionary = IMPLANT_TYPES[implant_type_key]
	return {
		"type": implant_type_key,
		"name": template.get("name", implant_type_key),
		"stat_bonus": template.get("stat_bonus", {}).duplicate(),
		"description": template.get("description", "")
	}

static func create_implant_from_loot(loot_name: String) -> Dictionary:
	## Create an implant dictionary from a loot item name
	var implant_key: String = LOOT_TO_IMPLANT_MAP.get(loot_name, "")
	if implant_key.is_empty():
		return {}
	return create_implant_from_type(implant_key)

func add_implant(implant: Dictionary) -> bool:
	## Add an implant to the character (max 3)
	if not implant.has("type") or not implant.has("name"):
		push_error("Character.add_implant: Invalid implant data - missing required fields")
		return false
	if implants.size() >= MAX_IMPLANTS:
		push_warning("Character %s already has maximum implants (%d)" % [name, MAX_IMPLANTS])
		return false
	var new_type: String = implant.get("type", "")
	for existing in implants:
		if existing.get("type", "") == new_type:
			return false
	implants.append(implant)
	return true

func remove_implant(index: int) -> void:
	## Remove an implant by index
	if index < 0 or index >= implants.size():
		push_error("Character.remove_implant: Invalid implant index %d" % index)
		return
	implants.remove_at(index)

func get_implant_bonuses() -> Dictionary:
	## Get total stat bonuses from all implants
	var total_bonuses := {}

	for impl_entry in implants:
		var stat_bonus: Dictionary = impl_entry.get("stat_bonus", {})
		for stat_name in stat_bonus:
			var bonus_value: int = stat_bonus.get(stat_name, 0)
			if total_bonuses.has(stat_name):
				total_bonuses[stat_name] += bonus_value
			else:
				total_bonuses[stat_name] = bonus_value

	return total_bonuses

func get_effective_stat(stat_name: String) -> int:
	## Get effective stat value including implant bonuses
	var base_stat := 0
	match stat_name:
		"combat":
			base_stat = combat
		"reactions":
			base_stat = reactions
		"toughness":
			base_stat = toughness
		"savvy":
			base_stat = savvy
		"tech":
			base_stat = tech
		"speed":
			base_stat = speed
		"luck":
			base_stat = luck
		_:
			push_error("Character.get_effective_stat: Unknown stat name '%s'" % stat_name)
			return 0
	var bonuses: Dictionary = get_implant_bonuses()
	var bonus: int = bonuses.get(stat_name, 0)
	return base_stat + bonus

func to_dictionary() -> Dictionary:
	## Convert Character to dictionary for UI display (dashboard/panel compatibility)
	## Includes both "id"/"name" and "character_id"/"character_name" aliases
	## so all consumers (MissionPrepComponent, CrewTaskComponent, etc.) work.
	return {
		# Dual key aliases for compatibility
		"id": character_id,
		"character_id": character_id,
		"name": name,
		"character_name": name,
		# Core identity
		"status": status,
		"background": background,
		"motivation": motivation,
		"origin": origin,
		"character_class": character_class,
		# Stats (flat)
		"combat": combat,
		"reactions": reactions,
		"toughness": toughness,
		"savvy": savvy,
		"tech": tech,
		"speed": speed,
		"luck": luck,
		# Progression
		"experience": experience,
		"credits": credits,
		"equipment": equipment.duplicate(),
		"is_captain": is_captain,
		# Health / injuries
		"health": health,
		"max_health": max_health,
		"injuries": injuries.duplicate(),
		"is_wounded": is_wounded,
		"current_recovery_turns": current_recovery_turns,
		# Augmentations
		"implants": implants.duplicate(),
		"bot_upgrades": bot_upgrades.duplicate(),
		# Lifetime statistics
		"lifetime_kills": lifetime_kills,
		"lifetime_damage_dealt": lifetime_damage_dealt,
		"lifetime_damage_taken": lifetime_damage_taken,
		"battles_participated": battles_participated,
		"battles_survived": battles_survived,
		"critical_hits_landed": critical_hits_landed,
		"advancement_history": advancement_history.duplicate(),
		# Game-specific
		"portrait_path": portrait_path,
		"faction_relations": faction_relations.duplicate(),
		"morale": morale,
		"credits_earned": credits_earned,
		"missions_completed": missions_completed
	}

	##
	## # ========== COMPREHENSIVE COMPATIBILITY LAYER ==========
	## # These methods provide compatibility for FiveParsecsCharacterGeneration calls
	## # Found in: CharacterCreator.gd, CharacterCustomizationScreen.gd, etc.
	##
	## # Enhanced generation method - supports all creation modes
	## static func generate_character_enhanced(config: Dictionary = {}) -> Character:
	## ## Enhanced character generation with full configuration support
	## @warning_ignore("untyped_declaration")
	## var character = Character.new()
	##
	## # Extract config safely using SafeTypeConverter
	## @warning_ignore("untyped_declaration")
	## var mode = SafeTypeConverter.safe_string(config.get("creation_mode", ""), "standard")
	## @warning_ignore("untyped_declaration", "shadowed_variable")
	## var background = SafeTypeConverter.safe_string(config.get("background", ""), "")
	## @warning_ignore("untyped_declaration")
	## var name_override = SafeTypeConverter.safe_string(config.get("name", ""), "")
	## @warning_ignore("untyped_declaration")
	## var existing_names = config.get("existing_names", []) if config.get("existing_names") is Array else []
	##
	## # Generate using Five Parsecs formula (2d6/3 rounded up)
	## character.reactions = ceili(randf_range(2, 12) / 3.0)
	## character.combat = ceili(randf_range(2, 12) / 3.0)
	## character.toughness = ceili(randf_range(2, 12) / 3.0)
	## character.savvy = ceili(randf_range(2, 12) / 3.0)
	## character.tech = ceili(randf_range(2, 12) / 3.0)
	## character.speed = ceili(randf_range(2, 12) / 3.0)
	## character.move = character.speed  # Keep move and speed in sync (speed is canonical)
	## character.luck = randi_range(0, 2)  # Five Parsecs starting luck: 0-2
	##
	## # Apply mode-specific bonuses
	## if mode == "captain":
	## character.is_captain = true
	## character.combat += 1
	## character.reactions += 1
	## elif mode == "veteran":
	## character.experience = 10
	## character.combat += 1
	##
	## # Set identity
	## @warning_ignore("unsafe_call_argument")
	## var char_origin: String = SafeTypeConverter.safe_string(config.get("origin", ""), "human")
	## character.name = name_override if not name_override.is_empty() else _generate_name(existing_names, char_origin)
	## character.background = background if not background.is_empty() else _generate_background()
	## character.motivation = _generate_motivation()
	## character.credits = SafeTypeConverter.safe_int(config.get("credits", 0), randi_range(20, 120))
	## character.created_at = Time.get_datetime_string_from_system()
	##
	## return character
	##
	## # Compatibility methods for gradual migration
	## static func generate_complete_character(config: Dictionary = {}) -> Character:
	## ## Compatibility: FiveParsecsCharacterGeneration.generate_complete_character()
	## push_warning("Deprecated: Use Character.generate_character_enhanced() instead")
	## return generate_character_enhanced(config)
	##
	## static func create_character(config: Dictionary = {}) -> Character:
	## ## Compatibility: FiveParsecsCharacterGeneration.create_character()
	## push_warning("Deprecated: Use Character.generate_character_enhanced() instead") 
	## return generate_character_enhanced(config)
	##
	## static func generate_random_character() -> Character:
	## ## Compatibility: Random character generation
	## return generate_character_enhanced({"creation_mode": "random"})
	##
	## # Character modification methods - found in CharacterCreator.gd
	## static func generate_character_attributes(character: Character) -> void:
	## ## Compatibility: Regenerate character attributes using Five Parsecs formula
	## if character:
	## character.reactions = ceili(randf_range(2, 12) / 3.0)
	## character.combat = ceili(randf_range(2, 12) / 3.0) 
	## character.toughness = ceili(randf_range(2, 12) / 3.0)
	## character.savvy = ceili(randf_range(2, 12) / 3.0)
	## character.tech = ceili(randf_range(2, 12) / 3.0)
	## character.speed = ceili(randf_range(2, 12) / 3.0)
	## character.move = character.speed  # Keep move and speed in sync (speed is canonical)
	## character.luck = randi_range(0, 2)
	##
	## static func apply_background_bonuses(character: Character) -> void:
	## ## Compatibility: Apply background-specific stat bonuses
	## if not character:
	## return
	##
	## match character.background:
	## "MILITARY":
	## character.combat += 1
	## character.toughness += 1
	## "TRADER":
	## character.savvy += 1
	## character.tech += 1
	## "ENGINEER":
	## character.tech += 2
	## "MEDIC":
	## character.savvy += 1
	## character.toughness += 1
	## "PILOT":
	## character.reactions += 1
	## character.speed += 1
	## character.move = character.speed  # Keep in sync
	## "SCHOLAR":
	## character.savvy += 2
	## "CRIMINAL":
	## character.reactions += 1
	## character.combat += 1
	## _:
	## # Generic background bonus
	## character.combat += 1
	##
	## static func apply_class_bonuses(character: Character) -> void:
	## ## Compatibility: Apply character class bonuses
	## if not character:
	## return
	## # Minimal implementation for emergency fix
	## character.experience += 5
	##
	## static func set_character_flags(character: Character) -> void:
	## ## Compatibility: Set character flags and status
	## if not character:
	## return
	## # Minimal implementation - just ensure valid state
	## if character.name.is_empty():
	## character.name = _generate_name([], character.origin)
	##
	## static func validate_character(character: Character) -> Dictionary:
	## ## Compatibility: Character validation
	## @warning_ignore("untyped_declaration")
	## var result = {"valid": true, "errors": []}
	##
	## if not character:
	## result.valid = false
	## @warning_ignore("unsafe_method_access")
	## result.errors.append("Character is null")
	## return result
	##
	## if character.name.is_empty():
	## result.valid = false
	## @warning_ignore("unsafe_method_access")
	## result.errors.append("Character needs a name")
	##
	## if character.combat <= 0 or character.reactions <= 0 or character.toughness <= 0:
	## result.valid = false
	## @warning_ignore("unsafe_method_access")
	## result.errors.append("Character has invalid stats")
	##
	## return result
	##
	## static func create_enhanced_character(params: Dictionary) -> Character:
	## ## Compatibility: Enhanced character creation
	## return generate_character_enhanced(params)
	##
	## # Stub methods for complex features - minimal implementation for emergency fix
	## static func generate_patrons(character: Character) -> Array:
	## ## Compatibility: Patron generation stub
	## if not character:
	## return []
	## # Return empty array for now - prevents crashes
	## return []
	##
	## static func generate_rivals(character: Character) -> Array:
	## ## Compatibility: Rival generation stub
	## if not character:
	## return []
	## # Return empty array for now - prevents crashes  
	## return []
	##
	## static func generate_starting_equipment_enhanced(character: Character) -> Dictionary:
	## ## Compatibility: Enhanced equipment generation stub
	## if not character:
	## return {}
	## # Return character's equipment as dictionary
	## @warning_ignore("untyped_declaration")
	## var equipment_dict = {}
	## for i in range(character.equipment.size()):
	## equipment_dict["item_%d" % i] = character.equipment[i]
	## return equipment_dict
	##
	## static func apply_background_effects(character: Character) -> void:
	## ## Compatibility: Background effects application
	## if not character:
	## return
	## # For emergency fix, just apply bonuses
	## apply_background_bonuses(character)
	##
	## static func apply_motivation_effects(character: Character) -> void:
	## ## Compatibility: Motivation effects application
	## if not character:
	## return
	## # Minimal implementation - add motivation-based credit bonus
	## match character.motivation:
	## "WEALTH":
	## character.credits += 20
	## "ADVENTURE":
	## character.experience += 5
	## _:
	## pass
	##
	## # ====================== CHARACTER PROPERTY MIGRATION HELPERS ======================
	## # Production-ready validation and compatibility methods for character properties
	##
	## func validate_character_properties() -> Dictionary:
	## ## Comprehensive validation of all character properties with detailed feedback
	## @warning_ignore("untyped_declaration")
	## var result = {
	## "valid": true,
	## "errors": [],
	## "warnings": [],
	## "property_status": {}
	## }
	##
	## # Validate background with defensive GlobalEnums access
	## @warning_ignore("untyped_declaration")
	## var global_enums = null
	## if Engine.has_singleton("GlobalEnums"):
	## global_enums = Engine.get_singleton("GlobalEnums")
	## @warning_ignore("unsafe_method_access")
	## if global_enums and global_enums.is_valid_background_string(_background):
	## result.property_status["background"] = "valid"
	## else:
	## result.valid = false
	## @warning_ignore("unsafe_method_access")
	## result.errors.append("Invalid background: %s" % _background)
	## result.property_status["background"] = "invalid"
	##
	## # Validate motivation
	## @warning_ignore("unsafe_method_access")
	## if global_enums and global_enums.is_valid_motivation_string(_motivation):
	## result.property_status["motivation"] = "valid"
	## else:
	## result.valid = false
	## @warning_ignore("unsafe_method_access")
	## result.errors.append("Invalid motivation: %s" % _motivation)
	## result.property_status["motivation"] = "invalid"
	##
	## # Validate origin
	## @warning_ignore("unsafe_method_access")
	## if global_enums and global_enums.is_valid_origin_string(_origin):
	## result.property_status["origin"] = "valid"
	## else:
	## result.valid = false
	## @warning_ignore("unsafe_method_access")
	## result.errors.append("Invalid origin: %s" % _origin)
	## result.property_status["origin"] = "invalid"
	##
	## # Validate character class
	## @warning_ignore("unsafe_method_access")
	## if global_enums and global_enums.is_valid_character_class_string(_character_class):
	## result.property_status["character_class"] = "valid"
	## else:
	## result.valid = false
	## @warning_ignore("unsafe_method_access")
	## result.errors.append("Invalid character class: %s" % _character_class)
	## result.property_status["character_class"] = "invalid"
	##
	## # Check for empty name
	## if name.is_empty():
	## @warning_ignore("unsafe_method_access")
	## result.warnings.append("Character has no name")
	## result.property_status["name"] = "warning"
	## else:
	## result.property_status["name"] = "valid"
	##
	## return result
	##
	## func migrate_legacy_properties(legacy_data: Dictionary) -> bool:
	## ## Migrate character from legacy enum-based format to string-based format
	## @warning_ignore("untyped_declaration")
	## var migration_successful = true
	## @warning_ignore("untyped_declaration")
	## var migration_log = []
	##
	## # Migrate background
	## if legacy_data.has("background"):
	## @warning_ignore("untyped_declaration")
	## var old_background = legacy_data.background
	## background = old_background  # This will trigger the smart setter
	## migration_log.append("Background: %s -> %s" % [old_background, _background])
	##
	## # Migrate motivation
	## if legacy_data.has("motivation"):
	## @warning_ignore("untyped_declaration")
	## var old_motivation = legacy_data.motivation
	## motivation = old_motivation  # This will trigger the smart setter
	## migration_log.append("Motivation: %s -> %s" % [old_motivation, _motivation])
	##
	## # Migrate origin
	## if legacy_data.has("origin"):
	## @warning_ignore("untyped_declaration")
	## var old_origin = legacy_data.origin
	## origin = old_origin  # This will trigger the smart setter
	## migration_log.append("Origin: %s -> %s" % [old_origin, _origin])
	##
	## # Migrate character class
	## if legacy_data.has("character_class"):
	## @warning_ignore("untyped_declaration")
	## var old_character_class = legacy_data.character_class
	## character_class = old_character_class  # This will trigger the smart setter
	## migration_log.append("Character class: %s -> %s" % [old_character_class, _character_class])
	##
	## # Validate after migration
	## @warning_ignore("untyped_declaration")
	## var validation = validate_character_properties()
	## if not validation.valid:
	## push_error("[CHARACTER] Migration validation failed: %s" % validation.errors)
	## migration_successful = false
	##
	## if OS.is_debug_build():
	## print("[CHARACTER] Migration for %s: %s" % [name, "SUCCESS" if migration_successful else "FAILED"])
	## @warning_ignore("untyped_declaration")
	## for log_entry in migration_log:
	## print("  %s" % log_entry)
	##
	## return migration_successful
	##
	## func get_property_health() -> Dictionary:
	## ## Get health status of character properties for monitoring
	## @warning_ignore("untyped_declaration")
	## var global_enums = null
	## if Engine.has_singleton("GlobalEnums"):
	## global_enums = Engine.get_singleton("GlobalEnums")
	## @warning_ignore("untyped_declaration", "shadowed_variable")
	## var health = {
	## "status": "healthy",
	## "properties": {
	## "background": {"value": _background, "valid": global_enums and global_enums.is_valid_background_string(_background)},
	## "motivation": {"value": _motivation, "valid": global_enums and global_enums.is_valid_motivation_string(_motivation)},
	## "origin": {"value": _origin, "valid": global_enums and global_enums.is_valid_origin_string(_origin)},
	## "character_class": {"value": _character_class, "valid": global_enums and global_enums.is_valid_character_class_string(_character_class)}
	## },
	## "character_name": name
	## }
	##
	## # Check if any property is invalid
	## for prop_name in health.properties:
	## if not health.properties[prop_name].valid:
	## health.status = "degraded"
	## break
	##
	## return health
	##
	## # Emergency rollback methods
	## func rollback_to_defaults():
	## ## Emergency rollback to safe default values
	## push_warning("[CHARACTER] Rolling back %s to default values" % name)
	##
	## _background = "COLONIST" 
	## _motivation = "SURVIVAL"
	## _origin = "HUMAN"
	## _character_class = "BASELINE"
	##
	## print("[CHARACTER] %s rolled back to defaults" % name)
	##
	## func force_property_validation():
	## ## Force re-validation of all properties through smart setters
	## var temp_background = _background
	## var temp_motivation = _motivation
	## var temp_origin = _origin
	## var temp_character_class = _character_class
	##
	## # Trigger smart setters to re-validate
	## background = temp_background
	## motivation = temp_motivation
	## origin = temp_origin
	## character_class = temp_character_class
	##
	## print("[CHARACTER] Forced validation completed for %s" % name)
	##
	## # Legacy compatibility methods for gradual migration
	## func get_background_enum() -> int:
	## ## Get background as enum value for legacy compatibility
	## var global_enums = null
	## if Engine.has_singleton("GlobalEnums"):
	## global_enums = Engine.get_singleton("GlobalEnums")
	## return global_enums.from_string_value("background", _background) if global_enums else 0
	##
	## func get_motivation_enum() -> int:
	## ## Get motivation as enum value for legacy compatibility
	## var global_enums = null
	## if Engine.has_singleton("GlobalEnums"):
	## global_enums = Engine.get_singleton("GlobalEnums")
	## return global_enums.from_string_value("motivation", _motivation) if global_enums else 0
	##
	## func get_origin_enum() -> int:
	## ## Get origin as enum value for legacy compatibility
	## var global_enums = null
	## if Engine.has_singleton("GlobalEnums"):
	## global_enums = Engine.get_singleton("GlobalEnums")
	## return global_enums.from_string_value("origin", _origin) if global_enums else 0
	##
	## func get_character_class_enum() -> int:
	## ## Get character class as enum value for legacy compatibility
	## var global_enums = null
	## if Engine.has_singleton("GlobalEnums"):
	## global_enums = Engine.get_singleton("GlobalEnums")
	## return global_enums.from_string_value("character_class", _character_class) if global_enums else 0
	##
	## # ====================== NATIVE SERIALIZATION METHODS ======================
	## # Production-ready serialization with enhanced CampaignSerializer integration
	##
	## func serialize() -> Dictionary:
	## ##
	## Native character serialization using enhanced serialization system
	## Provides full compatibility with CampaignSerializer format and migration support
	## ##
	## var global_enums = null
	## if Engine.has_singleton("GlobalEnums"):
	## global_enums = Engine.get_singleton("GlobalEnums")
	## var start_time = Time.get_ticks_usec()
	##
	## # Use CampaignSerializer for enhanced property serialization
	## var serialized_data = {
	## "type": "Character", # Match CampaignSerializer.SerializationType.CHARACTER
	## "version": "2.0",
	## "id": get_instance_id(),
	## "name": name,
	## "character_name": name, # Compatibility alias
	## "class_name": get_class(),
	##
	## # Enhanced property serialization with dual-value support
	## "character_class": _serialize_enhanced_property("character_class", _character_class),
	## "background": _serialize_enhanced_property("background", _background),
	## "origin": _serialize_enhanced_property("origin", _origin),
	## "motivation": _serialize_enhanced_property("motivation", _motivation),
	##
	## # Core stats
	## "stats": {
	## "combat": combat,
	## "reactions": reactions,
	## "toughness": toughness,
	## "savvy": savvy,
	## "tech": tech,
	## "speed": speed
	## },
	##
	## # Character state and progression
	## "experience": experience,
	## "credits": credits,
	## "equipment": equipment.duplicate(),
	## "is_captain": is_captain,
	## "created_at": created_at,
	## "status": status,
	##
	## # Injury system (Five Parsecs p.94-95)
	## "injuries": injuries.duplicate(),
	##
	## # Implant system (Five Parsecs odds-and-ends loot)
	## "implants": implants.duplicate(),
	##
	## # Bot upgrade system (Five Parsecs p.98)
	## "bot_upgrades": bot_upgrades.duplicate(),
	##
	## # Reaction economy system (Five Parsecs Core Rules)
	## "max_reactions_per_round": max_reactions_per_round,
	## "is_swift": is_swift(),
	##
	## # Lifetime Statistics (Five Parsecs Campaign Tracking)
	## "lifetime_kills": lifetime_kills,
	## "lifetime_damage_dealt": lifetime_damage_dealt,
	## "lifetime_damage_taken": lifetime_damage_taken,
	## "battles_participated": battles_participated,
	## "battles_survived": battles_survived,
	## "critical_hits_landed": critical_hits_landed,
	## "advancement_history": advancement_history.duplicate(),
	##
	## # Game-specific properties
	## "portrait_path": portrait_path,
	## "faction_relations": faction_relations.duplicate(),
	## "morale": morale,
	## "credits_earned": credits_earned,
	## "missions_completed": missions_completed,
	##
	## # Serialization metadata
	## "serialization_timestamp": Time.get_ticks_msec(),
	## "serialization_version": "enhanced_v2"
	## }
	##
	## # Performance tracking
	## var end_time = Time.get_ticks_usec()
	## var duration = end_time - start_time
	##
	## if OS.is_debug_build() and global_enums and global_enums.MIGRATION_FLAGS.get("log_performance", false):
	## print("[CHARACTER] Serialization for %s: %d μs" % [name, duration])
	##
	## return serialized_data
	##
	## func to_dictionary() -> Dictionary:
	## ## Convert Character to dictionary for UI display (dashboard compatibility)
	## return {
	## "character_name": name,
	## "name": name,  # Alias for compatibility
	## "status": status,
	## "background": background,
	## "motivation": motivation,
	## "origin": origin,
	## "character_class": character_class,
	## "combat": combat,
	## "reactions": reactions,
	## "toughness": toughness,
	## "savvy": savvy,
	## "tech": tech,
	## "speed": speed,
	## "luck": luck,
	## "experience": experience,
	## "credits": credits,
	## "equipment": equipment.duplicate(),
	## "is_captain": is_captain,
	## "health": health,
	## "max_health": max_health,
	## "injuries": injuries.duplicate(),
	## "is_wounded": is_wounded,
	## "current_recovery_turns": current_recovery_turns,
	## "implants": implants.duplicate(),
	## "bot_upgrades": bot_upgrades.duplicate(),
	## "is_bot": _is_bot(),
	## # Lifetime Statistics
	## "lifetime_kills": lifetime_kills,
	## "lifetime_damage_dealt": lifetime_damage_dealt,
	## "lifetime_damage_taken": lifetime_damage_taken,
	## "battles_participated": battles_participated,
	## "battles_survived": battles_survived,
	## "critical_hits_landed": critical_hits_landed,
	## "advancement_history": advancement_history.duplicate(),
	## # Game-specific
	## "portrait_path": portrait_path,
	## "faction_relations": faction_relations.duplicate(),
	## "morale": morale,
	## "credits_earned": credits_earned,
	## "missions_completed": missions_completed
	## }
	##
	## static func deserialize(data: Dictionary) -> Character:
	## ##
	## Native character deserialization with enhanced migration support
	## Handles all legacy formats and provides automatic property migration
	## ##
	## if data.is_empty():
	## push_error("[CHARACTER] Cannot deserialize empty data")
	## return null
	##
	## var global_enums = null
	## if Engine.has_singleton("GlobalEnums"):
	## global_enums = Engine.get_singleton("GlobalEnums")
	## var start_time = Time.get_ticks_usec()
	##
	## var character = Character.new()
	##
	## # Basic properties with safe fallbacks
	## character.name = data.get("name", data.get("character_name", "Unknown Character"))
	##
	## # Enhanced property deserialization with auto-migration
	## character._character_class = _deserialize_enhanced_property("character_class", data.get("character_class", data.get("class", "BASELINE")))
	## character._background = _deserialize_enhanced_property("background", data.get("background", "COLONIST"))
	## character._origin = _deserialize_enhanced_property("origin", data.get("origin", "HUMAN"))
	## character._motivation = _deserialize_enhanced_property("motivation", data.get("motivation", "SURVIVAL"))
	##
	## # Stats with safe defaults - handle both nested and top-level formats
	## var stats = data.get("stats", {})
	## if stats.is_empty():
	## # Top-level format (GameStateManager uses this)
	## character.combat = data.get("combat", 1)
	## character.reactions = data.get("reactions", data.get("reaction", 1))
	## character.toughness = data.get("toughness", 3)
	## character.savvy = data.get("savvy", 1)
	## character.tech = data.get("tech", 1)
	## character.speed = data.get("speed", data.get("move", 4))
	## character.move = character.speed  # Keep move and speed in sync (speed is canonical)
	## character.luck = data.get("luck", 0)
	## else:
	## # Nested format (legacy compatibility)
	## character.combat = stats.get("combat", 1)
	## character.reactions = stats.get("reactions", stats.get("reaction", 1))
	## character.toughness = stats.get("toughness", 3)
	## character.savvy = stats.get("savvy", 1)
	## character.tech = stats.get("tech", 1)
	## character.speed = stats.get("speed", stats.get("move", 4))
	## character.move = character.speed  # Keep move and speed in sync (speed is canonical)
	## character.luck = stats.get("luck", 0)
	##
	## # Character state
	## character.experience = data.get("experience", 0)
	## character.credits = data.get("credits", 0)
	##
	## # Handle typed array equipment (GDScript 2.0 requires proper typing)
	## var equipment_data = data.get("equipment", [])
	## character.equipment.clear()
	## for item in equipment_data:
	## if item is String:
	## character.equipment.append(item)
	##
	## character.is_captain = data.get("is_captain", false)
	## character.created_at = data.get("created_at", Time.get_datetime_string_from_system())
	## character.status = data.get("status", "ACTIVE")
	##
	## # Injury system (Five Parsecs p.94-95)
	## var injuries_data = data.get("injuries", [])
	## character.injuries.clear()
	## for injury in injuries_data:
	## if injury is Dictionary:
	## character.injuries.append(injury)
	##
	## # Implant system (Five Parsecs odds-and-ends loot)
	## var implants_data = data.get("implants", [])
	## character.implants.clear()
	## for implant in implants_data:
	## if implant is Dictionary:
	## character.implants.append(implant)
	##
	## # Bot upgrade system (Five Parsecs p.98)
	## var bot_upgrades_data = data.get("bot_upgrades", [])
	## character.bot_upgrades.clear()
	## for upgrade_id in bot_upgrades_data:
	## if upgrade_id is String:
	## character.bot_upgrades.append(upgrade_id)
	##
	## # Reaction economy system (Five Parsecs Core Rules)
	## # Swift species auto-detected by origin, but max_reactions can be overridden
	## character.max_reactions_per_round = data.get("max_reactions_per_round", 3)
	## # Note: reactions_used_this_round is NOT persisted - resets each battle
	##
	## # Lifetime Statistics (Five Parsecs Campaign Tracking)
	## character.lifetime_kills = data.get("lifetime_kills", 0)
	## character.lifetime_damage_dealt = data.get("lifetime_damage_dealt", 0)
	## character.lifetime_damage_taken = data.get("lifetime_damage_taken", 0)
	## character.battles_participated = data.get("battles_participated", 0)
	## character.battles_survived = data.get("battles_survived", 0)
	## character.critical_hits_landed = data.get("critical_hits_landed", 0)
	## var advancement_history_data = data.get("advancement_history", [])
	## character.advancement_history.clear()
	## for entry in advancement_history_data:
	## if entry is Dictionary:
	## character.advancement_history.append(entry)
	##
	## # Game-specific properties
	## character.portrait_path = data.get("portrait_path", "")
	## var faction_data = data.get("faction_relations", {})
	## character.faction_relations = faction_data.duplicate() if faction_data is Dictionary else {}
	## character.morale = data.get("morale", 5)
	## character.credits_earned = data.get("credits_earned", 0)
	## character.missions_completed = data.get("missions_completed", 0)
	##
	## # Performance tracking
	## var end_time = Time.get_ticks_usec()
	## var duration = end_time - start_time
	##
	## if OS.is_debug_build() and global_enums and global_enums.MIGRATION_FLAGS.get("log_performance", false):
	## print("[CHARACTER] Deserialization for %s: %d μs" % [character.name, duration])
	##
	## return character
	##
	## # Enhanced property serialization helpers
	## func _serialize_enhanced_property(property_name: String, value: String) -> Dictionary:
	## ## Serialize character property using enhanced format with dual values
	## var global_enums = null
	## if Engine.has_singleton("GlobalEnums"):
	## global_enums = Engine.get_singleton("GlobalEnums")
	## if not global_enums:
	## return {"format": "raw", "value": value}
	##
	## var validated_int = global_enums.from_string_value(property_name, value)
	## var is_valid = not value.is_empty() and value != "UNKNOWN"
	##
	## return {
	## "format": "enhanced_v2",
	## "string_value": value,
	## "int_value": validated_int,
	## "is_valid": is_valid,
	## "property": property_name,
	## "version": "2.0"
	## }
	##
	## static func _deserialize_enhanced_property(property_name: String, serialized_data: Variant) -> String:
	## ## Deserialize character property with auto-migration from any format
	## var global_enums = null
	## if Engine.has_singleton("GlobalEnums"):
	## global_enums = Engine.get_singleton("GlobalEnums")
	##
	## # When GlobalEnums not available, handle strings directly (already in correct format)
	## if not global_enums:
	## # If data is already a string, return it (GameStateManager generates valid strings)
	## if serialized_data is String and not serialized_data.is_empty():
	## return serialized_data.to_upper()
	## # Safe defaults for other cases (int/dict/empty)
	## match property_name:
	## "character_class": return "BASELINE"
	## "background": return "COLONIST"
	## "origin": return "HUMAN"
	## "motivation": return "SURVIVAL"
	## _: return "UNKNOWN"
	##
	## var result = ""
	##
	## # Handle different formats
	## if serialized_data is Dictionary:
	## var format = serialized_data.get("format", "legacy")
	## if format == "enhanced_v2":
	## result = serialized_data.get("string_value", "")
	## if result.is_empty():
	## # Fallback to int value migration
	## var int_val = serialized_data.get("int_value", -1)
	## if int_val >= 0:
	## result = global_enums.to_string_value(property_name, int_val)
	## else:
	## # Legacy format migration
	## var old_value = serialized_data.get("value", 0)
	## result = global_enums.to_string_value(property_name, old_value)
	## elif serialized_data is int:
	## # Direct int migration
	## result = global_enums.to_string_value(property_name, serialized_data)
	## elif serialized_data is String:
	## # Direct string (validate)
	## result = global_enums.to_string_value(property_name, serialized_data)
	##
	## # Final validation with safe defaults
	## if result.is_empty() or result == "UNKNOWN":
	## match property_name:
	## "character_class": return "BASELINE"
	## "background": return "COLONIST"
	## "origin": return "HUMAN" 
	## "motivation": return "SURVIVAL"
	## _: return "UNKNOWN"
	##
	## return result
	##
	## ## FIX 2: Campaign Creation Data Initialization
	##
	## func initialize_from_creation_data(creation_data: Dictionary) -> void:
	## ## Initialize character from campaign creation data structure
	## print("Character: Initializing from creation data...")
	##
	## # Basic character info
	## name = creation_data.get("character_name", creation_data.get("name", "Unknown"))
	##
	## # Character properties using the validated enum system
	## background = creation_data.get("background", "COLONIST")
	## motivation = creation_data.get("motivation", "SURVIVAL")
	## origin = creation_data.get("origin", "HUMAN")
	## character_class = creation_data.get("character_class", creation_data.get("class", "BASELINE"))
	##
	## # Stats - handle both nested and top-level formats
	## var stats = creation_data.get("stats", {})
	## if not stats.is_empty():
	## combat = stats.get("combat", 1)
	## reactions = stats.get("reactions", stats.get("reaction", 1))
	## toughness = stats.get("toughness", 3)
	## savvy = stats.get("savvy", 1)
	## tech = stats.get("tech", 1)
	## move = stats.get("move", stats.get("speed", 4))
	## speed = stats.get("speed", stats.get("move", 4))
	## luck = stats.get("luck", 0)
	## else:
	## # Top-level stats format
	## combat = creation_data.get("combat", 1)
	## reactions = creation_data.get("reactions", creation_data.get("reaction", 1))
	## toughness = creation_data.get("toughness", 3)
	## savvy = creation_data.get("savvy", 1)
	## tech = creation_data.get("tech", 1)
	## move = creation_data.get("move", creation_data.get("speed", 4))
	## speed = creation_data.get("speed", creation_data.get("move", 4))
	## luck = creation_data.get("luck", 0)
	##
	## # Equipment
	## var equipment_data = creation_data.get("equipment", [])
	## equipment.clear()
	## for item in equipment_data:
	## if item is String:
	## equipment.append(item)
	##
	## # Captain status
	## is_captain = creation_data.get("is_captain", false)
	##
	## # Status field - handle both numeric and string formats
	## var status_value = creation_data.get("status", "ACTIVE")
	## if status_value is int:
	## # NONE=0 or HEALTHY=1 both map to ACTIVE; DEAD=4 maps to DEAD; others to INJURED
	## if status_value <= 1:
	## status = "ACTIVE"
	## elif status_value == 4:
	## status = "DEAD"
	## else:
	## status = "INJURED"
	## else:
	## status = status_value
	##
	## print("Character: Initialized '%s' (class: %s, background: %s)" % [name, character_class, background])
	##
func _deserialize_enhanced_property(property_name: String, serialized_data: Variant) -> String:
	## Deserialize character property with safe defaults
	if serialized_data is String and not serialized_data.is_empty():
		return serialized_data.to_upper()
	if serialized_data is int:
		return str(serialized_data)
	match property_name:
		"character_class": return "BASELINE"
		"background": return "COLONIST"
		"origin": return "HUMAN"
		"motivation": return "SURVIVAL"
		_: return "UNKNOWN"

func from_dictionary(data: Dictionary) -> void:
	## This is called by Campaign.gd and other systems to restore character state
	if data.is_empty():
		push_error("[CHARACTER] Cannot initialize from empty dictionary")
		return

	# Basic properties
	name = data.get("name", data.get("character_name", "Unknown Character"))
	character_id = data.get("character_id", character_id)  # Keep existing if not provided

	# Character properties with enum validation
	_character_class = _deserialize_enhanced_property("character_class", data.get("character_class", data.get("class", "BASELINE")))
	_background = _deserialize_enhanced_property("background", data.get("background", "COLONIST"))
	_origin = _deserialize_enhanced_property("origin", data.get("origin", "HUMAN"))
	_motivation = _deserialize_enhanced_property("motivation", data.get("motivation", "SURVIVAL"))

	# Stats - handle both nested and top-level formats
	var stats = data.get("stats", {})
	if not stats.is_empty():
		combat = stats.get("combat", 1)
		reactions = stats.get("reactions", stats.get("reaction", 1))
		toughness = stats.get("toughness", 3)
		savvy = stats.get("savvy", 1)
		tech = stats.get("tech", 1)
		move = stats.get("move", stats.get("speed", 4))
		speed = stats.get("speed", stats.get("move", 4))
		luck = stats.get("luck", 0)
	else:
		# Top-level format (GameStateManager uses this)
		combat = data.get("combat", 1)
		reactions = data.get("reactions", data.get("reaction", 1))
		toughness = data.get("toughness", 3)
		savvy = data.get("savvy", 1)
		tech = data.get("tech", 1)
		move = data.get("move", data.get("speed", 4))
		speed = data.get("speed", data.get("move", 4))
		luck = data.get("luck", 0)

	# Character state
	experience = data.get("experience", 0)
	credits = data.get("credits", 0)

	# Equipment (typed array)
	var equipment_data = data.get("equipment", [])
	equipment.clear()
	for item in equipment_data:
		if item is String:
			equipment.append(item)

	is_captain = data.get("is_captain", false)
	created_at = data.get("created_at", Time.get_datetime_string_from_system())

	# Status - handle both numeric and string formats
	var status_value = data.get("status", "ACTIVE")
	if status_value is int:
		# NONE=0 or HEALTHY=1 both map to ACTIVE; DEAD=4 maps to DEAD; others to INJURED
		if status_value <= 1:
			status = "ACTIVE"
		elif status_value == 4:
			status = "DEAD"
		else:
			status = "INJURED"
	else:
		status = status_value

	# Injuries (Five Parsecs p.94-95)
	var injuries_data = data.get("injuries", [])
	injuries.clear()
	for injury in injuries_data:
		if injury is Dictionary:
			injuries.append(injury)

	# Implants
	var implants_data = data.get("implants", [])
	implants.clear()
	for implant in implants_data:
		if implant is Dictionary:
			implants.append(implant)

	# Bot upgrades (Five Parsecs p.98)
	var bot_upgrades_data = data.get("bot_upgrades", [])
	bot_upgrades.clear()
	for upgrade in bot_upgrades_data:
		if upgrade is Dictionary:
			# Extract string ID from Dictionary (bot_upgrades is Array[String])
			var upgrade_id = upgrade.get("id", upgrade.get("name", ""))
			if upgrade_id is String and not upgrade_id.is_empty():
				bot_upgrades.append(upgrade_id)
		elif upgrade is String:
			bot_upgrades.append(upgrade)

	# Lifetime Statistics (Five Parsecs Campaign Tracking)
	lifetime_kills = data.get("lifetime_kills", 0)
	lifetime_damage_dealt = data.get("lifetime_damage_dealt", 0)
	lifetime_damage_taken = data.get("lifetime_damage_taken", 0)
	battles_participated = data.get("battles_participated", 0)
	battles_survived = data.get("battles_survived", 0)
	critical_hits_landed = data.get("critical_hits_landed", 0)
	var advancement_history_data = data.get("advancement_history", [])
	advancement_history.clear()
	for entry in advancement_history_data:
		if entry is Dictionary:
			advancement_history.append(entry)

	# Game-specific properties
	portrait_path = data.get("portrait_path", "")
	var faction_data = data.get("faction_relations", {})
	faction_relations = faction_data.duplicate() if faction_data is Dictionary else {}
	morale = data.get("morale", 5)
	credits_earned = data.get("credits_earned", 0)
	missions_completed = data.get("missions_completed", 0)
