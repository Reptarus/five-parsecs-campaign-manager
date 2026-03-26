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

# Psionic Power (Five Parsecs Core Rules p.35)
# Precursor characters begin with one randomly determined Psionic Power
@export var psionic_power: String = ""  # Power ID from psionic_powers.json, empty if none
@export var psionic_power_enhanced: bool = false  # True if power enhanced via 6 XP training (Core Rules p.101)

# Class-based traits from CharacterGeneration.apply_class_bonuses()
@export var traits: Array[String] = []

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
func add_trait(trait_name: String) -> void:
	if trait_name not in traits:
		traits.append(trait_name)

func has_trait(trait_name: String) -> bool:
	return trait_name in traits

func add_experience(amount: int) -> void:
	experience += amount
	experience_changed.emit(experience)
	# Check if character can advance (1 XP = 1 advancement in Core Rules)
	if experience > 0:
		advancement_available.emit(self)
	pass # XP gained

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
	pass # Stat advanced
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

## Get effective savvy including all modifiers
func get_effective_savvy() -> int:
	var modifiers := get_combat_modifiers()
	return savvy + modifiers.get("savvy", 0)

## Get effective speed including all modifiers
func get_effective_speed() -> int:
	var modifiers := get_combat_modifiers()
	return speed + modifiers.get("speed", 0)

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
	
	pass # Character generated
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
	## Generate background via d100 roll (Core Rules pp.24-25)
	var roll: int = randi() % 100 + 1
	# D100 background table — exact ranges from book
	var table: Array = [
		[4, "Peaceful, High-Tech Colony"], [9, "Giant, Overcrowded City"],
		[13, "Low-Tech Colony"], [17, "Mining Colony"],
		[21, "Military Brat"], [25, "Space Station"],
		[29, "Military Outpost"], [34, "Drifter"],
		[39, "Lower Megacity Class"], [42, "Wealthy Merchant Family"],
		[46, "Frontier Gang"], [49, "Religious Cult"],
		[52, "War-Torn Hell-Hole"], [55, "Tech Guild"],
		[59, "Subjugated Colony"], [64, "Long-Term Space Mission"],
		[68, "Research Outpost"], [72, "Primitive World"],
		[76, "Orphan Utility Program"], [80, "Isolationist Enclave"],
		[84, "Comfortable Megacity"], [89, "Industrial World"],
		[93, "Bureaucrat"], [97, "Wasteland Nomads"],
		[100, "Alien Culture"],
	]
	for entry in table:
		if roll <= entry[0]:
			return entry[1]
	return "Drifter"

static func _generate_motivation() -> String:
	## Generate motivation via d100 roll (Core Rules p.26)
	var roll: int = randi() % 100 + 1
	var table: Array = [
		[8, "Wealth"], [14, "Fame"], [19, "Glory"],
		[26, "Survival"], [32, "Escape"], [39, "Adventure"],
		[44, "Truth"], [49, "Technology"], [56, "Discovery"],
		[63, "Loyalty"], [69, "Revenge"], [74, "Romance"],
		[79, "Faith"], [84, "Political"], [90, "Power"],
		[95, "Order"], [100, "Freedom"],
	]
	for entry in table:
		if roll <= entry[0]:
			return entry[1]
	return "Survival"

@warning_ignore("shadowed_variable")
static func _generate_starting_equipment(background: String) -> Array[String]:
	## Generate starting equipment based on character background
	## Starting rolls are per Core Rules pp.24-25
	@warning_ignore("shadowed_variable")
	var equipment: Array[String] = []
	equipment.append("Basic Kit")
	# Backgrounds that grant starting rolls
	var bg_lower: String = background.to_lower()
	if "low-tech" in bg_lower or "lower megacity" in bg_lower \
		or "primitive" in bg_lower or "wasteland" in bg_lower:
		equipment.append("Low-tech Weapon")
	elif "war-torn" in bg_lower:
		equipment.append("Military Weapon")
	elif "tech guild" in bg_lower or "alien culture" in bg_lower:
		equipment.append("High-tech Weapon")
	elif "space station" in bg_lower or "drifter" in bg_lower \
		or "industrial" in bg_lower:
		equipment.append("Gear")
	elif "subjugated" in bg_lower or "research" in bg_lower:
		equipment.append("Gadget")
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
		return false

	reactions_used_this_round += 1
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

const MAX_IMPLANTS: int = 2

## Implant data loaded from implants.json (Core Rules p.55)
## Bots and Soulless cannot use implants. Once applied, cannot be damaged or removed.
static var _implants_data: Array = []
static var _implants_loaded: bool = false

static func _ensure_implants_loaded() -> void:
	if _implants_loaded:
		return
	_implants_loaded = true
	var path := "res://data/implants.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("Character: Could not open %s" % path)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	if json.data is Dictionary:
		_implants_data = json.data.get("Implants", {}).get("types", [])

static func create_implant_from_type(implant_type_key: String) -> Dictionary:
	## Create an implant dictionary from a type key (loads from JSON)
	_ensure_implants_loaded()
	var key_lower := implant_type_key.to_lower()
	for entry in _implants_data:
		if entry is Dictionary and entry.get("id", "") == key_lower:
			return {
				"type": implant_type_key,
				"name": entry.get("name", implant_type_key),
				"stat_bonus": entry.get("stat_bonus", {}).duplicate(),
				"description": entry.get("description", "")
			}
	return {}

static func create_implant_from_loot(loot_name: String) -> Dictionary:
	## Create an implant dictionary from a loot item name (loads from JSON)
	_ensure_implants_loaded()
	for entry in _implants_data:
		if entry is Dictionary and entry.get("name", "") == loot_name:
			return {
				"type": entry.get("id", "").to_upper(),
				"name": entry.get("name", loot_name),
				"stat_bonus": entry.get("stat_bonus", {}).duplicate(),
				"description": entry.get("description", "")
			}
	return {}

func add_implant(implant: Dictionary) -> bool:
	## Add an implant to the character (max 2, Core Rules p.55)
	## WARNING: Psionics lose all powers permanently when given any implant (Core Rules p.96)
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
	# Core Rules p.96: Psionics lose abilities permanently if given any implant
	if psionic_power != "":
		push_warning("Character %s: Implant removes psionic power '%s'" % [
			character_name, psionic_power])
		psionic_power = ""
		psionic_power_enhanced = false
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
		"psionic_power": psionic_power,
		"psionic_power_enhanced": psionic_power_enhanced,
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
		"missions_completed": missions_completed,
		"traits": traits.duplicate()
	}

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

	# Psionic Power (Precursor origin, Core Rules p.17)
	psionic_power = data.get("psionic_power", "")
	psionic_power_enhanced = data.get("psionic_power_enhanced", false)

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

	# Traits (from class bonuses)
	var traits_data = data.get("traits", [])
	traits.clear()
	for t in traits_data:
		if t is String:
			traits.append(t)
