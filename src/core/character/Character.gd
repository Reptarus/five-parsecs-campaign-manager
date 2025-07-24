@tool
extends "res://src/base/character/character_base.gd"
class_name Character

## Main Character class for Five Parsecs Campaign Manager
##
## This is the single, consolidated character class that includes all
## Five Parsecs specific functionality. It extends BaseCharacter and adds
## all game-specific features in one place.

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

# Five Parsecs specific character properties
var character_class: int = GlobalEnums.CharacterClass.NONE
var origin: int = GlobalEnums.Origin.NONE
var background: int = GlobalEnums.Background.NONE
var motivation: int = GlobalEnums.Motivation.NONE

# Additional Five Parsecs stats
var savvy: int = 0
var luck: int = 0
var training: int = GlobalEnums.Training.NONE

# Equipment specific to Five Parsecs
var weapons: Array[Resource] = [] # Weapon resources
var armor: Array[Resource] = [] # Armor resources
var items: Array[Resource] = [] # Item resources

# Character type flags for Five Parsecs
var is_bot: bool = false
var is_soulless: bool = false
var is_human: bool = false
var is_captain: bool = false # Captain status for crew management

# Additional traits for Five Parsecs
var traits: Array[String] = []

# Five Parsecs relationships and connections
var patrons: Array = [] # Array[Dictionary] - Patron relationships
var rivals: Array = [] # Array[Dictionary] - Rival relationships
var personal_equipment: Dictionary = {} # Enhanced equipment system
var character_relationships: Dictionary = {} # Additional relationships

# Character advancement tracking
var credits_earned: int = 0
var missions_completed: int = 0
var experience_gained: int = 0

# Game-specific properties
var portrait_path: String = ""
var faction_relations: Dictionary = {}
var morale: int = 5
var kills: int = 0
var action_points: int = 2
var max_action_points: int = 2
var is_stunned: bool = false
var has_moved: bool = false
var has_attacked: bool = false
var current_cover: int = 0
var attack_range: float = 10.0
var attack_power: int = 3
var accuracy: int = 65 # Percentage
var defense: int = 3
var evasion: int = 10 # Percentage
var is_defeated: bool = false
var position: Vector2 = Vector2.ZERO

func _init() -> void:
	super._init()
	# Set a default character class as the character type
	character_type = GlobalEnums.CharacterClass.SOLDIER

# Override character_name property to provide access
var character_name: String:
	get: return _character_name
	set(_value):
		_character_name = _value

# Maximum values for stats (extending the base stats)
const MAX_STATS = {
	"reaction": 6,
	"combat": 5,
	"speed": 8,
	"savvy": 5,
	"toughness": 6,
	"luck": 1 # Humans can have 3
}

## Five Parsecs specific methods

## Roll for a stat check using appropriate dice
func roll_stat_check(stat_name: String, difficulty: int = 0) -> bool:
	var stat_value: int = 0
	match stat_name.to_lower():
		"reaction": stat_value = reaction
		"combat": stat_value = combat
		"toughness": stat_value = toughness
		"speed": stat_value = speed
		"savvy": stat_value = savvy
		"luck": stat_value = luck

	# Roll dice logic here
	var roll = randi() % 6 + 1 # Simulate d6 roll
	return roll + stat_value >= difficulty

## Apply training benefits
func apply_training_benefits() -> void:
	match training:
		GlobalEnums.Training.PILOT:
			combat += 1
		GlobalEnums.Training.MEDICAL:
			savvy += 1
		GlobalEnums.Training.SPECIALIST:
			reaction += 1
		# Add other training types as needed

## Check if character can use a specific weapon type
func can_use_weapon_type(weapon_type: int) -> bool:
	match weapon_type:
		GlobalEnums.WeaponType.HEAVY:
			return character_class == GlobalEnums.CharacterClass.SOLDIER
		GlobalEnums.WeaponType.SPECIAL:
			return character_class == GlobalEnums.CharacterClass.ENGINEER
		_:
			return true

## Generate a display description for the character
func get_character_description() -> String:
	var desc: String = "%s - %s %s" % [
		character_name,
		GlobalEnums.CharacterClass.keys()[character_class],
		GlobalEnums.Origin.keys()[origin]
	]

	if is_wounded:
		desc += " (Wounded)"
	elif is_dead:
		desc += " (Dead)"

	return desc

## Apply Five Parsecs specific status effects
func apply_campaign_effect(effect_type: int, duration: int = 1) -> void:
	var effect = {
		"id": "campaign_effect_%s" % effect_type,
		"type": effect_type,
		"duration": duration
	}
	apply_status_effect(effect)

## Process character recovery between campaign turns
func process_recovery() -> bool:
	var recovered: bool = false
	if is_wounded and not is_dead:
		# Roll recovery check
		var recovery_roll = randi() % 6 + 1 + toughness
		if recovery_roll >= 6:
			is_wounded = false
			health = maxi(1, max_health / 2.0)
			recovered = true

	# Process status effects
	for i: int in range(status_effects.size() - 1, -1, -1):
		var effect = status_effects[i]
		if effect.has("duration"):
			effect.duration -= 1
			if effect.duration <= 0:
				status_effects.remove_at(i)

	return recovered

## Add a trait to the character
func add_trait(trait_name: String) -> void:
	if not trait_name in traits:
		traits.append(trait_name)

## Check if character has a specific trait
func has_trait(trait_name: String) -> bool:
	return trait_name in traits

## Get character customization completeness level (0.0 - 1.0)
func get_customization_completeness() -> float:
	var completeness_score = 0.0
	var total_criteria = 8.0 # Total customization criteria
	
	# Basic info completeness (3 criteria)
	if character_name and not character_name.is_empty():
		completeness_score += 1.0
	if background > 0:
		completeness_score += 1.0
	if motivation > 0:
		completeness_score += 1.0
	
	# Attributes completeness (2 criteria)
	if combat >= 0 and toughness >= 3: # Valid attribute ranges
		completeness_score += 1.0
	if max_health == toughness + 2: # Proper health calculation
		completeness_score += 1.0
	
	# Relationships completeness (2 criteria)
	if patrons.size() > 0 or rivals.size() > 0:
		completeness_score += 1.0
	if traits.size() > 0:
		completeness_score += 1.0
	
	# Equipment completeness (1 criterion)
	if personal_equipment.size() > 0 or credits_earned > 0:
		completeness_score += 1.0
	
	return completeness_score / total_criteria

## Get character summary for display
func get_character_summary() -> Dictionary:
	return {
		"name": character_name,
		"background": GlobalEnums.Background.keys()[background] if background > 0 else "None",
		"motivation": GlobalEnums.Motivation.keys()[motivation] if motivation > 0 else "None",
		"class": GlobalEnums.CharacterClass.keys()[character_class] if character_class > 0 else "None",
		"stats": {
			"combat": combat,
			"reaction": reaction,
			"toughness": toughness,
			"speed": speed,
			"savvy": savvy,
			"luck": luck
		},
		"health": "%d/%d" % [health, max_health],
		"traits": traits,
		"equipment": personal_equipment
	}

## Game-specific methods

## Track a kill for this character
func add_kill() -> void:
	kills += 1
	# Award experience for kills
	add_experience(10)

## Track mission completion
func complete_mission(credits: int = 0) -> void:
	missions_completed += 1
	if credits > 0:
		credits_earned += credits
	# Award experience for mission completion
	add_experience(50)

## Apply morale changes
func modify_morale(amount: int) -> void:
	morale = clampi(morale + amount, 0, 10)
	# Handle morale effects
	if morale <= 2:
		apply_status_effect({
			"id": "low_morale",
			"type": "debuff",
			"duration": 2,
			"effects": {
				"combat": - 1
			}
		})
	elif morale >= 8:
		apply_status_effect({
			"id": "high_morale",
			"type": "buff",
			"duration": 2,
			"effects": {
				"reaction": 1
			}
		})

## Set faction relations
func set_faction_relation(faction_id: String, _value: int) -> void:
	faction_relations[faction_id] = _value

## Get faction relation
func get_faction_relation(faction_id: String) -> int:
	return faction_relations.get(faction_id, 0)

## Get character portrait path
func get_portrait() -> String:
	if portrait_path.is_empty():
		# Return default portrait based on character class
		return "res://assets/portraits/default_%s.png" % GlobalEnums.CharacterClass.keys()[character_class].to_lower()
	return portrait_path

## Set character portrait
func set_portrait(path: String) -> void:
	portrait_path = path

## Get character experience summary
func get_experience_summary() -> String:
	var summary: String = "Level %d (%d/%d XP)" % [
		level,
		experience,
		level * 100 # XP needed for next level
	]
	return summary

## Get character's service record summary
func get_service_record() -> String:
	var record: String = "Missions: %d | Kills: %d | Credits: %d" % [
		missions_completed,
		kills,
		credits_earned
	]
	return record

## Get morale value
func get_morale() -> int:
	return morale

## Initialize managers (for compatibility)
func initialize_managers(_game_state_manager: Variant) -> void:
	# Game-specific initialization if needed
	pass

## Unit status functions
func is_unit_active() -> bool:
	return not is_defeated and not is_stunned and action_points > 0

func check_if_defeated() -> bool:
	return is_defeated

func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(health) / float(max_health)

## Movement functions
func get_movement_range() -> int:
	if is_wounded:
		return max(1, speed - 1)
	return speed

func move_to(new_position: Vector2) -> void:
	if action_points <= 0 or has_moved:
		return

	# Set new position
	position = new_position

	# Consume action point
	spend_action_point()
	has_moved = true

## Combat functions
func get_attack_range() -> float:
	return attack_range

func calculate_hit_chance(target: Character) -> float:
	var base_chance = float(accuracy) / 100.0

	# Apply modifiers
	if target.current_cover > 0:
		# Cover reduces hit chance
		base_chance -= float(target.current_cover) * 0.1

	if target.evasion > 0:
		# Evasion reduces hit chance
		base_chance -= float(target.evasion) / 100.0

	# Clamp the _value
	return clampf(base_chance, 0.1, 0.95)

func calculate_damage(target: Character) -> int:
	var base_damage = attack_power

	# Apply armor reduction
	var damage_after_armor = max(1, base_damage - target.armor)

	# Apply any other modifiers here

	return damage_after_armor

func attack(target: Character) -> bool:
	if action_points <= 0 or has_attacked:
		return false

	# Check if hit
	var hit_chance = calculate_hit_chance(target)
	var hit_roll = randf()

	if hit_roll <= hit_chance:
		# Hit successful
		var damage = calculate_damage(target)
		target.take_damage(damage, self)

		# Consume action point
		spend_action_point()
		has_attacked = true

		return true
	else:
		# Miss
		# Consume action point
		spend_action_point()
		has_attacked = true

		return false

func take_damage(amount: int, source: Character = null) -> void:
	var actual_damage = clampi(amount, 0, health)

	# Apply damage
	health -= actual_damage

	# Check if defeated
	if health <= 0:
		health = 0
		is_defeated = true
	elif health <= max_health / 3.0 and not is_wounded:
		# Become wounded at 1 / 3.0 health
		is_wounded = true

func heal(amount: int) -> void:
	var old_health = health
	health = clampi(health + amount, 0, max_health)

	# Check if no longer wounded
	if is_wounded and health > max_health / 3.0:
		is_wounded = false

## Action point management
func spend_action_point() -> void:
	if action_points > 0:
		action_points -= 1

func reset_action_points() -> void:
	action_points = max_action_points
	has_moved = false
	has_attacked = false

## Other functions
func reset_for_new_turn() -> void:
	reset_action_points()

	# Remove stun
	if is_stunned:
		is_stunned = false
func restore() -> void:
	health = max_health
	is_defeated = false
	is_wounded = false
	is_stunned = false
	reset_action_points()

## Serialize character data to Dictionary
func serialize() -> Dictionary:
	var data = {}
	# Base character data
	data["character_id"] = character_id
	data["character_name"] = character_name
	data["character_type"] = character_type
	data["level"] = level
	data["experience"] = experience
	data["health"] = health
	data["max_health"] = max_health
	data["reaction"] = reaction
	data["combat"] = combat
	data["toughness"] = toughness
	data["speed"] = speed
	data["is_active"] = is_active
	data["is_wounded"] = is_wounded
	data["is_dead"] = is_dead
	data["status_effects"] = status_effects
	data["equipment_slots"] = equipment_slots
	data["skills"] = skills
	data["abilities"] = skills
	
	# Five Parsecs specific data
	data["portrait_path"] = portrait_path
	data["faction_relations"] = faction_relations
	data["morale"] = morale
	data["credits_earned"] = credits_earned
	data["missions_completed"] = missions_completed
	data["kills"] = kills
	data["character_class"] = character_class
	data["origin"] = origin
	data["background"] = background
	data["motivation"] = motivation
	data["savvy"] = savvy
	data["luck"] = luck
	data["training"] = training
	data["traits"] = traits
	data["patrons"] = patrons
	data["rivals"] = rivals
	data["personal_equipment"] = personal_equipment
	data["character_relationships"] = character_relationships
	data["is_bot"] = is_bot
	data["is_soulless"] = is_soulless
	data["is_human"] = is_human
	data["is_captain"] = is_captain
	return data

## Deserialize character data from Dictionary
func deserialize(data: Dictionary) -> void:
	# Base character data
	character_id = data.get("character_id", "")
	character_name = data.get("character_name", "")
	character_type = data.get("character_type", 0)
	level = data.get("level", 1)
	experience = data.get("experience", 0)
	health = data.get("health", 10)
	max_health = data.get("max_health", 10)
	reaction = data.get("reaction", 0)
	combat = data.get("combat", 0)
	toughness = data.get("toughness", 0)
	speed = data.get("speed", 0)
	is_wounded = data.get("is_wounded", false)
	is_dead = data.get("is_dead", false)
	status_effects = data.get("status_effects", [])
	equipment_slots = data.get("equipment_slots", {})
	skills = data.get("skills", [])
	abilities = data.get("abilities", [])
	
	# Five Parsecs specific data
	portrait_path = data.get("portrait_path", "")
	faction_relations = data.get("faction_relations", {})
	morale = data.get("morale", 5)
	credits_earned = data.get("credits_earned", 0)
	missions_completed = data.get("missions_completed", 0)
	kills = data.get("kills", 0)
	character_class = data.get("character_class", GlobalEnums.CharacterClass.NONE)
	origin = data.get("origin", GlobalEnums.Origin.NONE)
	background = data.get("background", GlobalEnums.Background.NONE)
	motivation = data.get("motivation", GlobalEnums.Motivation.NONE)
	savvy = data.get("savvy", 0)
	luck = data.get("luck", 0)
	training = data.get("training", GlobalEnums.Training.NONE)
	traits = data.get("traits", [])
	patrons = data.get("patrons", [])
	rivals = data.get("rivals", [])
	personal_equipment = data.get("personal_equipment", {})
	character_relationships = data.get("character_relationships", {})
	is_bot = data.get("is_bot", false)
	is_soulless = data.get("is_soulless", false)
	is_human = data.get("is_human", false)
	is_captain = data.get("is_captain", false)
