@tool
extends Node
class_name SimplifiedDataManager

## Five Parsecs Data Manager - Simplified Resource-Based System
## Framework Bible compliant: Simple resource loading with type safety
## Replaces 50+ static variables and complex JSON loading with clean Resource system

# Core data resources - Framework Bible: simple over complex
const FiveParsecsCharacterData = preload("res://src/data/resources/FiveParsecsCharacterData.gd")
const FiveParsecsCombatDataResource = preload("res://src/data/resources/FiveParsecsCombatData.gd")  
const FiveParsecsCampaignDataResource = preload("res://src/data/resources/FiveParsecsCampaignData.gd")

# Resource paths - native Godot resources
const CHARACTER_DATA_PATH: String = "res://data/character_data.tres"
const COMBAT_DATA_PATH: String = "res://data/combat_data.tres"
const CAMPAIGN_DATA_PATH: String = "res://data/campaign_data.tres"

# Simple signals - no complex event system
signal data_loaded()
signal data_load_failed(error: String)

# Simple data holders - no static variables or complex caching
var character_data: FiveParsecsCharacterData
var combat_data: FiveParsecsCombatDataResource  
var campaign_data: FiveParsecsCampaignDataResource
var is_data_loaded: bool = false

func _ready() -> void:
	"""Initialize data system - Framework Bible: simple and direct"""
	print("SimplifiedDataManager: Starting simple resource-based initialization...")
	var success = load_data_resources()
	
	if success:
		data_loaded.emit()
		print("SimplifiedDataManager: ✅ Resource initialization successful")
	else:
		data_load_failed.emit("Failed to load resources")
		push_error("SimplifiedDataManager: ❌ Resource initialization failed")

## Simple Resource Loading - Framework Bible compliant
func load_data_resources() -> bool:
	"""Load all data using Godot's native resource system"""
	var start_time = Time.get_ticks_msec()
	
	# Load character data resource
	if ResourceLoader.exists(CHARACTER_DATA_PATH):
		character_data = load(CHARACTER_DATA_PATH)
	else:
		print("SimplifiedDataManager: Creating default character data")
		character_data = FiveParsecsCharacterData.create_default_character_data()
	
	# Load combat data resource
	if ResourceLoader.exists(COMBAT_DATA_PATH):
		combat_data = load(COMBAT_DATA_PATH)
	else:
		print("SimplifiedDataManager: Creating default combat data")
		combat_data = FiveParsecsCombatDataResource.create_default_combat_data()
	
	# Load campaign data resource
	if ResourceLoader.exists(CAMPAIGN_DATA_PATH):
		campaign_data = load(CAMPAIGN_DATA_PATH)
	else:
		print("SimplifiedDataManager: Creating default campaign data")
		campaign_data = FiveParsecsCampaignDataResource.create_default_campaign_data()
	
	# Validate all resources loaded
	var all_loaded = character_data != null and combat_data != null and campaign_data != null
	if all_loaded:
		is_data_loaded = true
		var load_time = Time.get_ticks_msec() - start_time
		print("SimplifiedDataManager: All resources loaded in %d ms" % load_time)
	
	return all_loaded

## Simple Data Access Methods - Framework Bible: direct and clear

# Character data access
func get_background_by_id(background_id: int):
	"""Get character background by ID"""
	if character_data:
		return character_data.get_background_by_id(background_id)
	return null

func get_motivation_by_id(motivation_id: int):
	"""Get character motivation by ID"""
	if character_data:
		return character_data.get_motivation_by_id(motivation_id)
	return null

func generate_random_name(species: String = "Human") -> String:
	"""Generate random character name"""
	if character_data:
		return character_data.generate_random_name(species)
	return "Character"

# Combat data access
func get_weapon_by_name(weapon_name: String):
	"""Get weapon data by name"""
	if combat_data:
		return combat_data.get_weapon_by_name(weapon_name)
	return null

func get_armor_by_name(armor_name: String):
	"""Get armor data by name"""
	if combat_data:
		return combat_data.get_armor_by_name(armor_name)
	return null

func get_combat_rules():
	"""Get combat rules"""
	if combat_data:
		return combat_data.combat_rules
	return null

# Campaign data access
func get_world_trait_by_name(trait_name: String):
	"""Get world trait by name"""
	if campaign_data:
		return campaign_data.get_world_trait_by_name(trait_name)
	return null

func get_patron_type_by_name(patron_name: String):
	"""Get patron type by name"""
	if campaign_data:
		return campaign_data.get_patron_type_by_name(patron_name)
	return null

func get_random_campaign_event():
	"""Get random campaign event"""
	if campaign_data:
		return campaign_data.get_random_campaign_event()
	return null

func calculate_upkeep_cost(crew_size: int, ship_data: Dictionary = {}) -> int:
	"""Calculate upkeep cost"""
	if campaign_data:
		return campaign_data.calculate_upkeep_cost(crew_size, ship_data)
	return crew_size

## Legacy Compatibility Methods for Migration

func get_character_creation_data() -> Dictionary:
	"""Legacy method - return character data as dictionary"""
	if not character_data:
		return {}
	
	return {
		"backgrounds": character_data.backgrounds,
		"motivations": character_data.motivations,
		"species": character_data.species
	}

func get_weapons_database() -> Dictionary:
	"""Legacy method - return weapons as dictionary"""
	if not combat_data:
		return {}
	
	var weapons_dict = {}
	for weapon in combat_data.weapons:
		weapons_dict[weapon.name] = {
			"name": weapon.name,
			"range": weapon.range,
			"damage": weapon.damage,
			"type": weapon.weapon_type
		}
	
	return weapons_dict

func get_armor_database() -> Dictionary:
	"""Legacy method - return armor as dictionary"""
	if not combat_data:
		return {}
	
	var armor_dict = {}
	for armor in combat_data.armor_types:
		armor_dict[armor.name] = {
			"name": armor.name,
			"save": armor.armor_save,
			"cost": armor.cost
		}
	
	return armor_dict

func get_world_traits_database() -> Dictionary:
	"""Legacy method - return world traits as dictionary"""
	if not campaign_data:
		return {}
	
	var traits_dict = {}
	for trait in campaign_data.world_traits:
		traits_dict[trait.name] = {
			"name": trait.name,
			"description": trait.description,
			"effects": trait.effects
		}
	
	return traits_dict

## Validation and Debug Methods

func validate_all_data() -> Array[String]:
	"""Validate all loaded data"""
	var errors: Array[String] = []
	
	if character_data:
		errors.append_array(character_data.validate_data())
	else:
		errors.append("Character data not loaded")
	
	if combat_data:
		errors.append_array(combat_data.validate_data())
	else:
		errors.append("Combat data not loaded")
	
	if campaign_data:
		errors.append_array(campaign_data.validate_data())
	else:
		errors.append("Campaign data not loaded")
	
	return errors

func get_data_status() -> Dictionary:
	"""Get current data loading status"""
	return {
		"is_loaded": is_data_loaded,
		"character_data": character_data != null,
		"combat_data": combat_data != null,
		"campaign_data": campaign_data != null,
		"validation_errors": validate_all_data().size()
	}

func reload_all_data() -> bool:
	"""Reload all data resources"""
	print("SimplifiedDataManager: Reloading all data...")
	return load_data_resources()

## Resource Creation Helpers for Development

func create_default_resources() -> void:
	"""Create default .tres resource files"""
	print("SimplifiedDataManager: Creating default resource files...")
	
	# Create character data resource
	var char_data = FiveParsecsCharacterData.create_default_character_data()
	ResourceSaver.save(char_data, CHARACTER_DATA_PATH)
	
	# Create combat data resource  
	var combat_res = FiveParsecsCombatDataResource.create_default_combat_data()
	ResourceSaver.save(combat_res, COMBAT_DATA_PATH)
	
	# Create campaign data resource
	var campaign_res = FiveParsecsCampaignDataResource.create_default_campaign_data()
	ResourceSaver.save(campaign_res, CAMPAIGN_DATA_PATH)
	
	print("SimplifiedDataManager: Default resources created")

## Static singleton access for legacy compatibility
static var instance: SimplifiedDataManager

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

static func get_instance() -> SimplifiedDataManager:
	return instance