@tool
extends RefCounted
class_name ResourceMigrationAdapter

## Resource Migration Adapter for Five Parsecs
## Converts legacy JSON data files to new Godot Resource system
## Framework Bible compliant: Simple conversion with validation
## Handles migration from 23+ JSON files to 3 .tres resources

const FiveParsecsCharacterData = preload("res://src/data/resources/FiveParsecsCharacterData.gd")
const FiveParsecsCombatDataResource = preload("res://src/data/resources/FiveParsecsCombatData.gd")
const FiveParsecsCampaignDataResource = preload("res://src/data/resources/FiveParsecsCampaignData.gd")

# Legacy JSON file paths to migrate
const LEGACY_JSON_PATHS = {
	"character_data": "res://data/character_creation_data.json",
	"backgrounds": "res://data/character_backgrounds.json",
	"motivations": "res://data/character_motivations.json",
	"species": "res://data/character_species.json",
	"weapons": "res://data/weapons.json",
	"armor": "res://data/armor.json",
	"equipment": "res://data/equipment_database.json",
	"world_traits": "res://data/world_traits.json",
	"planet_types": "res://data/planet_types.json",
	"victory_conditions": "res://data/victory_conditions.json",
	"patron_types": "res://data/patron_types.json",
	"rival_types": "res://data/rival_types.json",
	"trade_goods": "res://data/trade_goods.json",
	"mission_templates": "res://data/mission_templates.json",
	"enemy_types": "res://data/enemy_types.json"
}

# Output resource paths
const OUTPUT_PATHS = {
	"character_data": "res://data/character_data.tres",
	"combat_data": "res://data/combat_data.tres",
	"campaign_data": "res://data/campaign_data.tres"
}

## Main Migration Entry Point

static func migrate_all_json_to_resources() -> bool:
	"""Migrate all legacy JSON files to new resource system"""
	print("ResourceMigrationAdapter: Starting migration of JSON files to resources...")
	
	var character_data = _migrate_character_data()
	var combat_data = _migrate_combat_data()
	var campaign_data = _migrate_campaign_data()
	
	# Save resources
	var success = true
	success = success and _save_resource(character_data, OUTPUT_PATHS.character_data)
	success = success and _save_resource(combat_data, OUTPUT_PATHS.combat_data)
	success = success and _save_resource(campaign_data, OUTPUT_PATHS.campaign_data)
	
	if success:
		print("ResourceMigrationAdapter: ✅ Migration completed successfully")
	else:
		print("ResourceMigrationAdapter: ❌ Migration failed")
	
	return success

## Character Data Migration

static func _migrate_character_data() -> FiveParsecsCharacterData:
	"""Migrate character-related JSON files to character data resource"""
	print("ResourceMigrationAdapter: Migrating character data...")
	
	var character_data = FiveParsecsCharacterData.new()
	
	# Migrate backgrounds
	var backgrounds_json = _load_json_safe(LEGACY_JSON_PATHS.get("backgrounds", ""))
	character_data.backgrounds = _convert_backgrounds(backgrounds_json)
	
	# Migrate motivations
	var motivations_json = _load_json_safe(LEGACY_JSON_PATHS.get("motivations", ""))
	character_data.motivations = _convert_motivations(motivations_json)
	
	# Migrate species
	var species_json = _load_json_safe(LEGACY_JSON_PATHS.get("species", ""))
	character_data.species = _convert_species(species_json)
	
	# Create default data if JSON files don't exist
	if character_data.backgrounds.is_empty():
		character_data = FiveParsecsCharacterData.create_default_character_data()
	
	print("ResourceMigrationAdapter: Character data migrated - %d backgrounds, %d motivations, %d species" %
		[character_data.backgrounds.size(), character_data.motivations.size(), character_data.species.size()])
	
	return character_data

static func _convert_backgrounds(json_data: Dictionary) -> Array[FiveParsecsCharacterData.CharacterBackground]:
	"""Convert JSON backgrounds to resource format"""
	var backgrounds: Array[FiveParsecsCharacterData.CharacterBackground] = []
	
	if json_data.has("backgrounds"):
		for bg_data in json_data.backgrounds:
			var background = FiveParsecsCharacterData.CharacterBackground.new()
			background.id = bg_data.get("id", 0)
			background.name = bg_data.get("name", "")
			background.description = bg_data.get("description", "")
			background.stat_modifiers = bg_data.get("stat_modifiers", {})
			background.starting_equipment = bg_data.get("starting_equipment", [])
			background.credits_bonus = bg_data.get("credits_bonus", 0)
			backgrounds.append(background)
	
	return backgrounds

static func _convert_motivations(json_data: Dictionary) -> Array[FiveParsecsCharacterData.CharacterMotivation]:
	"""Convert JSON motivations to resource format"""
	var motivations: Array[FiveParsecsCharacterData.CharacterMotivation] = []
	
	if json_data.has("motivations"):
		for mot_data in json_data.motivations:
			var motivation = FiveParsecsCharacterData.CharacterMotivation.new()
			motivation.id = mot_data.get("id", 0)
			motivation.name = mot_data.get("name", "")
			motivation.description = mot_data.get("description", "")
			motivation.mechanical_benefit = mot_data.get("mechanical_benefit", "")
			motivations.append(motivation)
	
	return motivations

static func _convert_species(json_data: Dictionary) -> Array[FiveParsecsCharacterData.CharacterSpecies]:
	"""Convert JSON species to resource format"""
	var species_list: Array[FiveParsecsCharacterData.CharacterSpecies] = []
	
	if json_data.has("species"):
		for species_data in json_data.species:
			var species = FiveParsecsCharacterData.CharacterSpecies.new()
			species.id = species_data.get("id", 0)
			species.name = species_data.get("name", "")
			species.description = species_data.get("description", "")
			species.base_stats = species_data.get("base_stats", {})
			species.special_abilities = species_data.get("special_abilities", [])
			species.movement_speed = species_data.get("movement_speed", 6)
			species_list.append(species)
	
	return species_list

## Combat Data Migration

static func _migrate_combat_data() -> FiveParsecsCombatDataResource:
	"""Migrate combat-related JSON files to combat data resource"""
	print("ResourceMigrationAdapter: Migrating combat data...")
	
	var combat_data = FiveParsecsCombatDataResource.new()
	
	# Migrate weapons
	var weapons_json = _load_json_safe(LEGACY_JSON_PATHS.get("weapons", ""))
	combat_data.weapons = _convert_weapons(weapons_json)
	
	# Migrate armor
	var armor_json = _load_json_safe(LEGACY_JSON_PATHS.get("armor", ""))
	combat_data.armor_types = _convert_armor(armor_json)
	
	# Migrate equipment
	var equipment_json = _load_json_safe(LEGACY_JSON_PATHS.get("equipment", ""))
	combat_data.equipment = _convert_equipment(equipment_json)
	
	# Migrate enemy types
	var enemies_json = _load_json_safe(LEGACY_JSON_PATHS.get("enemy_types", ""))
	combat_data.enemy_types = _convert_enemy_types(enemies_json)
	
	# Create defaults if JSON files don't exist
	if combat_data.weapons.is_empty():
		combat_data = FiveParsecsCombatDataResource.create_default_combat_data()
	
	print("ResourceMigrationAdapter: Combat data migrated - %d weapons, %d armor types, %d equipment, %d enemies" %
		[combat_data.weapons.size(), combat_data.armor_types.size(), combat_data.equipment.size(), combat_data.enemy_types.size()])
	
	return combat_data

static func _convert_weapons(json_data: Dictionary) -> Array[FiveParsecsCombatDataResource.CombatWeaponData]:
	"""Convert JSON weapons to resource format"""
	var weapons: Array[FiveParsecsCombatDataResource.CombatWeaponData] = []
	
	if json_data.has("weapons"):
		for weapon_data in json_data.weapons:
			var weapon = FiveParsecsCombatDataResource.CombatWeaponData.new()
			weapon.id = weapon_data.get("id", 0)
			weapon.name = weapon_data.get("name", "")
			weapon.weapon_type = weapon_data.get("type", "rifle")
			weapon.weapon_range = weapon_data.get("range", 24)
			weapon.damage = weapon_data.get("damage", 1)
			weapon.cost = weapon_data.get("cost", 1)
			weapon.traits = weapon_data.get("traits", [])
			weapons.append(weapon)
	
	return weapons

static func _convert_armor(json_data: Dictionary) -> Array[FiveParsecsCombatDataResource.CombatArmorData]:
	"""Convert JSON armor to resource format"""
	var armor_list: Array[FiveParsecsCombatDataResource.CombatArmorData] = []
	
	if json_data.has("armor"):
		for armor_data in json_data.armor:
			var armor = FiveParsecsCombatDataResource.CombatArmorData.new()
			armor.id = armor_data.get("id", 0)
			armor.name = armor_data.get("name", "")
			armor.armor_save = armor_data.get("save", 6)
			armor.cost = armor_data.get("cost", 1)
			armor.movement_penalty = armor_data.get("movement_penalty", 0)
			armor_list.append(armor)
	
	return armor_list

static func _convert_equipment(json_data: Dictionary) -> Array[FiveParsecsCombatDataResource.EquipmentData]:
	"""Convert JSON equipment to resource format"""
	var equipment_list: Array[FiveParsecsCombatDataResource.EquipmentData] = []
	
	if json_data.has("equipment"):
		for eq_data in json_data.equipment:
			var equipment = FiveParsecsCombatDataResource.EquipmentData.new()
			equipment.id = eq_data.get("id", 0)
			equipment.name = eq_data.get("name", "")
			equipment.equipment_type = eq_data.get("type", "gear")
			equipment.effect = eq_data.get("effect", "")
			equipment.cost = eq_data.get("cost", 1)
			equipment.uses = eq_data.get("uses", -1)
			equipment_list.append(equipment)
	
	return equipment_list

static func _convert_enemy_types(json_data: Dictionary) -> Array[FiveParsecsCombatDataResource.EnemyType]:
	"""Convert JSON enemy types to resource format"""
	var enemies: Array[FiveParsecsCombatDataResource.EnemyType] = []
	
	if json_data.has("enemy_types"):
		for enemy_data in json_data.enemy_types:
			var enemy = FiveParsecsCombatDataResource.EnemyType.new()
			enemy.id = enemy_data.get("id", 0)
			enemy.name = enemy_data.get("name", "")
			enemy.stats = enemy_data.get("stats", {})
			enemy.weapons = enemy_data.get("weapons", [])
			enemy.ai_behavior = enemy_data.get("ai_behavior", "aggressive")
			enemy.threat_level = enemy_data.get("threat_level", 1)
			enemies.append(enemy)
	
	return enemies

## Campaign Data Migration

static func _migrate_campaign_data() -> FiveParsecsCampaignDataResource:
	"""Migrate campaign-related JSON files to campaign data resource"""
	print("ResourceMigrationAdapter: Migrating campaign data...")
	
	var campaign_data = FiveParsecsCampaignDataResource.new()
	
	# Migrate world traits
	var world_traits_json = _load_json_safe(LEGACY_JSON_PATHS.get("world_traits", ""))
	campaign_data.world_traits = _convert_world_traits(world_traits_json)
	
	# Migrate planet types
	var planet_types_json = _load_json_safe(LEGACY_JSON_PATHS.get("planet_types", ""))
	campaign_data.planet_types = _convert_planet_types(planet_types_json)
	
	# Migrate patron types
	var patron_types_json = _load_json_safe(LEGACY_JSON_PATHS.get("patron_types", ""))
	campaign_data.patron_types = _convert_patron_types(patron_types_json)
	
	# Migrate trade goods
	var trade_goods_json = _load_json_safe(LEGACY_JSON_PATHS.get("trade_goods", ""))
	campaign_data.trade_goods = _convert_trade_goods(trade_goods_json)
	
	# Create defaults if JSON files don't exist
	if campaign_data.world_traits.is_empty():
		campaign_data = FiveParsecsCampaignDataResource.create_default_campaign_data()
	
	print("ResourceMigrationAdapter: Campaign data migrated - %d world traits, %d planet types, %d patron types" %
		[campaign_data.world_traits.size(), campaign_data.planet_types.size(), campaign_data.patron_types.size()])
	
	return campaign_data

static func _convert_world_traits(json_data: Dictionary) -> Array[FiveParsecsCampaignDataResource.WorldTrait]:
	"""Convert JSON world traits to resource format"""
	var traits: Array[FiveParsecsCampaignDataResource.WorldTrait] = []
	
	if json_data.has("world_traits"):
		for trait_data in json_data.world_traits:
			var world_trait = FiveParsecsCampaignDataResource.WorldTrait.new()
			world_trait.id = trait_data.get("id", 0)
			world_trait.name = trait_data.get("name", "")
			world_trait.description = trait_data.get("description", "")
			world_trait.effects = trait_data.get("effects", {})
			world_trait.trade_modifiers = trait_data.get("trade_modifiers", {})
			traits.append(world_trait)
	
	return traits

static func _convert_planet_types(json_data: Dictionary) -> Array[FiveParsecsCampaignDataResource.PlanetType]:
	"""Convert JSON planet types to resource format"""
	var planets: Array[FiveParsecsCampaignDataResource.PlanetType] = []
	
	if json_data.has("planet_types"):
		for planet_data in json_data.planet_types:
			var planet = FiveParsecsCampaignDataResource.PlanetType.new()
			planet.id = planet_data.get("id", 0)
			planet.name = planet_data.get("name", "")
			planet.description = planet_data.get("description", "")
			planet.tech_level = planet_data.get("tech_level", 3)
			planet.population_density = planet_data.get("population_density", "moderate")
			planets.append(planet)
	
	return planets

static func _convert_patron_types(json_data: Dictionary) -> Array[FiveParsecsCampaignDataResource.PatronType]:
	"""Convert JSON patron types to resource format"""
	var patrons: Array[FiveParsecsCampaignDataResource.PatronType] = []
	
	if json_data.has("patron_types"):
		for patron_data in json_data.patron_types:
			var patron = FiveParsecsCampaignDataResource.PatronType.new()
			patron.id = patron_data.get("id", 0)
			patron.name = patron_data.get("name", "")
			patron.patron_type = patron_data.get("type", "corporate")
			patron.mission_types = patron_data.get("mission_types", [])
			patron.payment_modifier = patron_data.get("payment_modifier", 1.0)
			patrons.append(patron)
	
	return patrons

static func _convert_trade_goods(json_data: Dictionary) -> Array[FiveParsecsCampaignDataResource.TradeGood]:
	"""Convert JSON trade goods to resource format"""
	var goods: Array[FiveParsecsCampaignDataResource.TradeGood] = []
	
	if json_data.has("trade_goods"):
		for good_data in json_data.trade_goods:
			var good = FiveParsecsCampaignDataResource.TradeGood.new()
			good.id = good_data.get("id", 0)
			good.name = good_data.get("name", "")
			good.base_value = good_data.get("base_value", 1)
			good.volatility = good_data.get("volatility", 0.2)
			good.legality = good_data.get("legality", "legal")
			goods.append(good)
	
	return goods

## Utility Methods

static func _load_json_safe(file_path: String) -> Dictionary:
	"""Safely load JSON file"""
	if not FileAccess.file_exists(file_path):
		print("ResourceMigrationAdapter: JSON file not found: ", file_path)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("ResourceMigrationAdapter: Could not open file: ", file_path)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		print("ResourceMigrationAdapter: JSON parse error in: ", file_path)
		return {}
	
	return json.data

static func _save_resource(resource: Resource, file_path: String) -> bool:
	"""Save resource to file"""
	var error = ResourceSaver.save(resource, file_path)
	if error != OK:
		push_error("ResourceMigrationAdapter: Failed to save resource: " + file_path)
		return false
	
	print("ResourceMigrationAdapter: Saved resource: ", file_path)
	return true

## Migration Validation

static func validate_migration() -> Dictionary:
	"""Validate that migration was successful"""
	var validation_result = {
		"success": true,
		"errors": [],
		"warnings": [],
		"stats": {}
	}
	
	# Check if resource files exist
	for resource_name in OUTPUT_PATHS:
		var path = OUTPUT_PATHS[resource_name]
		if not ResourceLoader.exists(path):
			validation_result.errors.append("Resource file missing: " + path)
			validation_result.success = false
	
	# Load and validate each resource
	var character_data = load(OUTPUT_PATHS.character_data) as FiveParsecsCharacterData
	if character_data:
		var char_errors = character_data.validate_data()
		validation_result.errors.append_array(char_errors)
		validation_result.stats["character_backgrounds"] = character_data.backgrounds.size()
		validation_result.stats["character_motivations"] = character_data.motivations.size()
	else:
		validation_result.errors.append("Failed to load character data resource")
		validation_result.success = false
	
	var combat_data = load(OUTPUT_PATHS.combat_data) as FiveParsecsCombatDataResource
	if combat_data:
		var combat_errors = combat_data.validate_data()
		validation_result.errors.append_array(combat_errors)
		validation_result.stats["weapons"] = combat_data.weapons.size()
		validation_result.stats["armor_types"] = combat_data.armor_types.size()
	else:
		validation_result.errors.append("Failed to load combat data resource")
		validation_result.success = false
	
	var campaign_data = load(OUTPUT_PATHS.campaign_data) as FiveParsecsCampaignDataResource
	if campaign_data:
		var campaign_errors = campaign_data.validate_data()
		validation_result.errors.append_array(campaign_errors)
		validation_result.stats["world_traits"] = campaign_data.world_traits.size()
		validation_result.stats["patron_types"] = campaign_data.patron_types.size()
	else:
		validation_result.errors.append("Failed to load campaign data resource")
		validation_result.success = false
	
	if validation_result.errors.size() > 0:
		validation_result.success = false
	
	return validation_result

## Command Line Interface for Migration

static func run_migration_from_cli() -> void:
	"""Run migration from command line or editor"""
	print("=== Five Parsecs Resource Migration ===")
	print("Converting JSON files to .tres resources...")
	
	var success = migrate_all_json_to_resources()
	
	if success:
		print("\n=== Validating Migration ===")
		var validation = validate_migration()
		
		if validation.success:
			print("✅ Migration completed successfully!")
			print("Stats:", validation.stats)
		else:
			print("❌ Migration validation failed:")
			for error in validation.errors:
				print("  - ", error)
	else:
		print("❌ Migration failed!")
	
	print("=== Migration Complete ===")

## Editor-only migration helper
func _init():
	if Engine.is_editor_hint():
		print("ResourceMigrationAdapter initialized. Call run_migration_from_cli() to start migration.")