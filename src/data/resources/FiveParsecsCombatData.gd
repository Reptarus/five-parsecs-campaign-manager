extends Resource
class_name FiveParsecsCombatDataResource

## Five Parsecs Combat Data Resource
## Consolidated weapon, armor, and combat rules using Godot Resources  
## Framework Bible compliant: Simple, type-safe combat data
## Replaces complex JSON files with native Godot resources

# Weapon and equipment data
@export var weapons: Array[WeaponData] = []
@export var armor_types: Array[ArmorData] = []
@export var equipment: Array[EquipmentData] = []

# Combat rules and constants
@export var combat_rules: CombatRules
@export var terrain_effects: Array[TerrainEffect] = []
@export var status_effects: Array[StatusEffect] = []

# Mission and battlefield data
@export var mission_templates: Array[MissionTemplate] = []
@export var enemy_types: Array[EnemyType] = []
@export var deployment_patterns: Array[DeploymentPattern] = []

## Weapon Data Resource
class WeaponData extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var weapon_type: String = ""  # "pistol", "rifle", "heavy", "melee"
	@export var range: int = 24
	@export var damage: int = 1
	@export var shots: int = 1
	@export var traits: Array[String] = []
	@export var cost: int = 0
	@export var availability: String = "common"
	@export var actions_required: int = 1

## Armor Data Resource
class ArmorData extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var armor_save: int = 6  # d6 roll needed to save
	@export var coverage: String = "full"  # "full", "partial", "shield"
	@export var movement_penalty: int = 0
	@export var cost: int = 0
	@export var availability: String = "common"

## Equipment Data Resource
class EquipmentData extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var equipment_type: String = ""  # "gear", "consumable", "tool"
	@export var effect: String = ""
	@export var uses: int = -1  # -1 for unlimited
	@export var cost: int = 0
	@export var availability: String = "common"

## Combat Rules Resource
class CombatRules extends Resource:
	# Movement rules
	@export var base_movement: int = 6
	@export var dash_movement: int = 12
	@export var difficult_terrain_penalty: int = 2
	
	# Combat rules
	@export var base_hit_chance: int = 4  # Need 4+ on d6
	@export var cover_modifier: int = -1
	@export var height_advantage: int = 1
	@export var point_blank_bonus: int = 1
	@export var long_range_penalty: int = -1
	
	# Action system
	@export var actions_per_turn: int = 2
	@export var move_action_cost: int = 1
	@export var shoot_action_cost: int = 1
	@export var aim_action_cost: int = 1
	
	# Health and damage
	@export var base_health: int = 1
	@export var toughness_health_bonus: int = 1  # +1 health per 2 toughness
	@export var unconscious_threshold: int = 0
	@export var death_threshold: int = -3

## Terrain Effect Resource
class TerrainEffect extends Resource:
	@export var terrain_type: String = ""
	@export var name: String = ""
	@export var movement_modifier: int = 0
	@export var cover_bonus: int = 0
	@export var line_of_sight_blocking: bool = false
	@export var special_rules: Array[String] = []

## Status Effect Resource
class StatusEffect extends Resource:
	@export var name: String = ""
	@export var description: String = ""
	@export var duration: int = 1  # Turns
	@export var effects: Dictionary = {}  # stat_name: modifier
	@export var removes_on: String = ""  # "turn_start", "turn_end", "action"

## Mission Template Resource
class MissionTemplate extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var mission_type: String = ""  # "patrol", "defend", "retrieve"
	@export var objectives: Array[String] = []
	@export var deployment_type: String = "standard"
	@export var terrain_requirements: Dictionary = {}
	@export var enemy_count_formula: String = "crew_size"
	@export var special_rules: Array[String] = []

## Enemy Type Resource
class EnemyType extends Resource:
	@export var id: int = 0
	@export var name: String = ""
	@export var description: String = ""
	@export var stats: Dictionary = {}  # stat_name: value
	@export var weapons: Array[String] = []
	@export var armor: String = ""
	@export var special_abilities: Array[String] = []
	@export var ai_behavior: String = "aggressive"
	@export var threat_level: int = 1

## Deployment Pattern Resource  
class DeploymentPattern extends Resource:
	@export var name: String = ""
	@export var description: String = ""
	@export var crew_zone: String = "left_edge"
	@export var enemy_zone: String = "right_edge"
	@export var special_deployment: Dictionary = {}

## Data Access Methods - Simple and Fast

func get_weapon_by_name(weapon_name: String) -> WeaponData:
	"""Get weapon by name"""
	for weapon in weapons:
		if weapon.name == weapon_name:
			return weapon
	return null

func get_weapon_by_id(weapon_id: int) -> WeaponData:
	"""Get weapon by ID"""
	for weapon in weapons:
		if weapon.id == weapon_id:
			return weapon
	return null

func get_armor_by_name(armor_name: String) -> ArmorData:
	"""Get armor by name"""
	for armor in armor_types:
		if armor.name == armor_name:
			return armor
	return null

func get_equipment_by_name(equipment_name: String) -> EquipmentData:
	"""Get equipment by name"""
	for item in equipment:
		if item.name == equipment_name:
			return item
	return null

func get_mission_template_by_type(mission_type: String) -> MissionTemplate:
	"""Get random mission template of specified type"""
	var matching_templates: Array[MissionTemplate] = []
	for template in mission_templates:
		if template.mission_type == mission_type:
			matching_templates.append(template)
	
	if matching_templates.is_empty():
		return null
	
	return matching_templates[randi() % matching_templates.size()]

func get_enemy_type_by_name(enemy_name: String) -> EnemyType:
	"""Get enemy type by name"""
	for enemy in enemy_types:
		if enemy.name == enemy_name:
			return enemy
	return null

func get_terrain_effect(terrain_type: String) -> TerrainEffect:
	"""Get terrain effect by type"""
	for effect in terrain_effects:
		if effect.terrain_type == terrain_type:
			return effect
	return null

func get_weapons_by_type(weapon_type: String) -> Array[WeaponData]:
	"""Get all weapons of specified type"""
	var matching_weapons: Array[WeaponData] = []
	for weapon in weapons:
		if weapon.weapon_type == weapon_type:
			matching_weapons.append(weapon)
	return matching_weapons

func get_random_weapon(weapon_type: String = "") -> WeaponData:
	"""Get random weapon, optionally filtered by type"""
	var available_weapons = weapons if weapon_type.is_empty() else get_weapons_by_type(weapon_type)
	
	if available_weapons.is_empty():
		return null
	
	return available_weapons[randi() % available_weapons.size()]

func get_random_enemy_type(threat_level: int = -1) -> EnemyType:
	"""Get random enemy type, optionally filtered by threat level"""
	var available_enemies = enemy_types
	
	if threat_level > 0:
		available_enemies = []
		for enemy in enemy_types:
			if enemy.threat_level == threat_level:
				available_enemies.append(enemy)
	
	if available_enemies.is_empty():
		return null
	
	return available_enemies[randi() % available_enemies.size()]

## Validation Methods

func validate_data() -> Array[String]:
	"""Validate combat data integrity"""
	var errors: Array[String] = []
	
	# Check weapons
	if weapons.is_empty():
		errors.append("No weapons defined")
	else:
		for weapon in weapons:
			if weapon.name.is_empty():
				errors.append("Weapon %d has no name" % weapon.id)
			if weapon.range <= 0:
				errors.append("Weapon %s has invalid range" % weapon.name)
	
	# Check armor
	if armor_types.is_empty():
		errors.append("No armor types defined")
	else:
		for armor in armor_types:
			if armor.name.is_empty():
				errors.append("Armor %d has no name" % armor.id)
			if armor.armor_save < 2 or armor.armor_save > 6:
				errors.append("Armor %s has invalid save value" % armor.name)
	
	# Check combat rules
	if not combat_rules:
		errors.append("No combat rules defined")
	elif combat_rules.base_movement <= 0:
		errors.append("Invalid base movement in combat rules")
	
	return errors

func is_valid() -> bool:
	"""Check if combat data is valid"""
	return validate_data().is_empty()

## Factory Methods for Default Data

static func create_default_combat_data() -> FiveParsecsCombatDataResource:
	"""Create combat data with Five Parsecs defaults"""
	var data = FiveParsecsCombatDataResource.new()
	
	data.weapons = _create_default_weapons()
	data.armor_types = _create_default_armor()
	data.equipment = _create_default_equipment()
	data.combat_rules = _create_default_combat_rules()
	data.terrain_effects = _create_default_terrain_effects()
	data.mission_templates = _create_default_mission_templates()
	data.enemy_types = _create_default_enemy_types()
	
	return data

static func _create_default_weapons() -> Array[WeaponData]:
	"""Create Five Parsecs default weapons"""
	var weapon_list: Array[WeaponData] = []
	
	# Pistols
	var scrap_pistol = WeaponData.new()
	scrap_pistol.id = 0
	scrap_pistol.name = "Scrap Pistol"
	scrap_pistol.weapon_type = "pistol"
	scrap_pistol.range = 8
	scrap_pistol.damage = 1
	scrap_pistol.cost = 2
	weapon_list.append(scrap_pistol)
	
	var hand_cannon = WeaponData.new()
	hand_cannon.id = 1
	hand_cannon.name = "Hand Cannon"
	hand_cannon.weapon_type = "pistol"
	hand_cannon.range = 8
	hand_cannon.damage = 2
	hand_cannon.cost = 8
	weapon_list.append(hand_cannon)
	
	# Rifles
	var colony_rifle = WeaponData.new()
	colony_rifle.id = 2
	colony_rifle.name = "Colony Rifle"
	colony_rifle.weapon_type = "rifle"
	colony_rifle.range = 24
	colony_rifle.damage = 1
	colony_rifle.cost = 5
	weapon_list.append(colony_rifle)
	
	var military_rifle = WeaponData.new()
	military_rifle.id = 3
	military_rifle.name = "Military Rifle"
	military_rifle.weapon_type = "rifle"
	military_rifle.range = 24
	military_rifle.damage = 2
	military_rifle.cost = 12
	weapon_list.append(military_rifle)
	
	# Heavy weapons
	var blast_rifle = WeaponData.new()
	blast_rifle.id = 4
	blast_rifle.name = "Blast Rifle"
	blast_rifle.weapon_type = "heavy"
	blast_rifle.range = 16
	blast_rifle.damage = 2
	blast_rifle.traits = ["Area"]
	blast_rifle.cost = 15
	weapon_list.append(blast_rifle)
	
	return weapon_list

static func _create_default_armor() -> Array[ArmorData]:
	"""Create Five Parsecs default armor"""
	var armor_list: Array[ArmorData] = []
	
	var flak_screen = ArmorData.new()
	flak_screen.id = 0
	flak_screen.name = "Flak Screen"
	flak_screen.armor_save = 6
	flak_screen.cost = 4
	armor_list.append(flak_screen)
	
	var combat_armor = ArmorData.new()
	combat_armor.id = 1
	combat_armor.name = "Combat Armor"
	combat_armor.armor_save = 5
	combat_armor.movement_penalty = -1
	combat_armor.cost = 10
	armor_list.append(combat_armor)
	
	var battle_suit = ArmorData.new()
	battle_suit.id = 2
	battle_suit.name = "Battle Suit"
	battle_suit.armor_save = 4
	battle_suit.movement_penalty = -2
	battle_suit.cost = 20
	armor_list.append(battle_suit)
	
	return armor_list

static func _create_default_equipment() -> Array[EquipmentData]:
	"""Create Five Parsecs default equipment"""
	var equipment_list: Array[EquipmentData] = []
	
	var stim_pack = EquipmentData.new()
	stim_pack.id = 0
	stim_pack.name = "Stim-pack"
	stim_pack.equipment_type = "consumable"
	stim_pack.effect = "Heal 1 wound"
	stim_pack.uses = 1
	stim_pack.cost = 3
	equipment_list.append(stim_pack)
	
	var scanner = EquipmentData.new()
	scanner.id = 1
	scanner.name = "Scanner"
	scanner.equipment_type = "tool"
	scanner.effect = "Detect enemies within 12 inches"
	scanner.cost = 8
	equipment_list.append(scanner)
	
	return equipment_list

static func _create_default_combat_rules() -> CombatRules:
	"""Create Five Parsecs combat rules"""
	var rules = CombatRules.new()
	rules.base_movement = 6
	rules.dash_movement = 12
	rules.base_hit_chance = 4
	rules.cover_modifier = -1
	rules.height_advantage = 1
	rules.point_blank_bonus = 1
	rules.long_range_penalty = -1
	rules.actions_per_turn = 2
	return rules

static func _create_default_terrain_effects() -> Array[TerrainEffect]:
	"""Create default terrain effects"""
	var effects: Array[TerrainEffect] = []
	
	var cover = TerrainEffect.new()
	cover.terrain_type = "cover"
	cover.name = "Cover"
	cover.cover_bonus = 1
	effects.append(cover)
	
	var difficult = TerrainEffect.new()
	difficult.terrain_type = "difficult"
	difficult.name = "Difficult Ground"
	difficult.movement_modifier = -2
	effects.append(difficult)
	
	var blocking = TerrainEffect.new()
	blocking.terrain_type = "blocking"
	blocking.name = "Blocking Terrain"
	blocking.line_of_sight_blocking = true
	effects.append(blocking)
	
	return effects

static func _create_default_mission_templates() -> Array[MissionTemplate]:
	"""Create default mission templates"""
	var templates: Array[MissionTemplate] = []
	
	var patrol = MissionTemplate.new()
	patrol.id = 0
	patrol.name = "Patrol Mission"
	patrol.mission_type = "patrol"
	patrol.objectives = ["Eliminate all enemies"]
	patrol.enemy_count_formula = "crew_size"
	templates.append(patrol)
	
	var defend = MissionTemplate.new()
	defend.id = 1
	defend.name = "Defend Position"
	defend.mission_type = "defend"
	defend.objectives = ["Hold position for 6 turns"]
	defend.deployment_type = "defensive"
	templates.append(defend)
	
	return templates

static func _create_default_enemy_types() -> Array[EnemyType]:
	"""Create default enemy types"""
	var enemies: Array[EnemyType] = []
	
	var raider = EnemyType.new()
	raider.id = 0
	raider.name = "Raider"
	raider.stats = {"Combat": 1, "Toughness": 1, "Speed": 6}
	raider.weapons = ["Scrap Pistol"]
	raider.ai_behavior = "aggressive"
	raider.threat_level = 1
	enemies.append(raider)
	
	var enforcer = EnemyType.new()
	enforcer.id = 1
	enforcer.name = "Security Enforcer"
	enforcer.stats = {"Combat": 2, "Toughness": 2, "Speed": 6}
	enforcer.weapons = ["Military Rifle"]
	enforcer.armor = "Combat Armor"
	enforcer.ai_behavior = "tactical"
	enforcer.threat_level = 2
	enemies.append(enforcer)
	
	return enemies