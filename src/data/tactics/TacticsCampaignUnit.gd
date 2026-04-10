class_name TacticsCampaignUnit
extends Resource

## TacticsCampaignUnit - Persistent unit in a Tactics campaign roster
## Tracks campaign progression: Campaign Points, veteran skills, casualties.
## Simplified from AoF CampaignUnit: drops dual-scale, squad pool, wounds.
## Source: Five Parsecs: Tactics campaign rules pp.155-172

# Campaign progression constants (Tactics rulebook p.160)
const CP_PER_BATTLE := 1
const CP_PER_VICTORY := 1
const CP_PER_SECONDARY_OBJECTIVE := 1

# Identity
@export var unit_id: String = ""
@export var custom_name: String = ""
@export var base_unit_id: String = ""       # References TacticsUnitProfile.unit_id
@export var species_id: String = ""         # Which species book this unit belongs to

# Campaign Stats
@export var campaign_points: int = 0        # CP earned (spent on upgrades)
@export var campaign_points_spent: int = 0  # CP already used
@export var battles_fought: int = 0
@export var battles_won: int = 0
@export var objectives_completed: int = 0

# Veteran Skills (acquired via CP spending)
var veteran_skills: Array = []  # Array of TacticsSpecialRule (type=VETERAN)

# Casualties / Attrition
@export var models_lost_total: int = 0      # Cumulative losses
@export var models_lost_current: int = 0    # Losses in current battle (reset post-battle)
@export var is_destroyed: bool = false       # Unit wiped out entirely

# Selected upgrades (persisted from roster construction)
var selected_upgrade_ids: Array = []  # Array of String (upgrade IDs)

# Model count (may differ from base if losses/reinforcements)
@export var current_models: int = 5


## Get available CP (earned minus spent)
func get_available_cp() -> int:
	return campaign_points - campaign_points_spent


## Check if unit can acquire a veteran skill
func can_acquire_skill() -> bool:
	return get_available_cp() > 0 and not is_destroyed


## Add a veteran skill (costs CP)
func add_veteran_skill(skill: TacticsSpecialRule, cost: int = 1) -> bool:
	if get_available_cp() < cost:
		return false
	# Check for duplicates
	for existing in veteran_skills:
		if existing is TacticsSpecialRule and existing.matches(skill.rule_name):
			return false
	veteran_skills.append(skill)
	campaign_points_spent += cost
	return true


## Record a battle result
func record_battle(won: bool, secondary_completed: bool = false) -> void:
	battles_fought += 1
	campaign_points += CP_PER_BATTLE
	if won:
		battles_won += 1
		campaign_points += CP_PER_VICTORY
	if secondary_completed:
		objectives_completed += 1
		campaign_points += CP_PER_SECONDARY_OBJECTIVE
	# Reset per-battle losses
	models_lost_current = 0


## Apply casualties from a battle
func apply_casualties(models_lost: int) -> void:
	models_lost_current = models_lost
	models_lost_total += models_lost
	current_models = maxi(current_models - models_lost, 0)
	if current_models <= 0:
		is_destroyed = true


## Reinforce unit (add replacement models up to base count)
func reinforce(models_added: int, base_count: int) -> int:
	var space: int = base_count - current_models
	var added: int = mini(models_added, space)
	current_models += added
	return added


## Get display name
func get_display_name() -> String:
	if not custom_name.is_empty():
		return custom_name
	return base_unit_id.replace("_", " ").capitalize()


## Generate a unique ID
static func generate_id() -> String:
	return "tcu_%d_%d" % [Time.get_unix_time_from_system(), randi() % 10000]


## Create from a roster entry (at campaign start)
static func from_roster_entry(entry: TacticsRosterEntry, species: String) -> TacticsCampaignUnit:
	var _Self = load("res://src/data/tactics/TacticsCampaignUnit.gd")
	var unit = _Self.new()
	unit.unit_id = generate_id()
	unit.species_id = species
	unit.custom_name = entry.get_display_name()

	if entry.base_profile:
		unit.base_unit_id = entry.base_profile.unit_id
		unit.current_models = entry.model_count if entry.model_count > 0 else entry.base_profile.base_models

	for upgrade in entry.selected_upgrades:
		if upgrade is TacticsUpgradeOption:
			unit.selected_upgrade_ids.append(upgrade.upgrade_id)

	return unit


## Serialize to dictionary (for save files)
func to_dict() -> Dictionary:
	var data: Dictionary = {
		"unit_id": unit_id,
		"custom_name": custom_name,
		"base_unit_id": base_unit_id,
		"species_id": species_id,
		"campaign_points": campaign_points,
		"campaign_points_spent": campaign_points_spent,
		"battles_fought": battles_fought,
		"battles_won": battles_won,
		"objectives_completed": objectives_completed,
		"models_lost_total": models_lost_total,
		"current_models": current_models,
		"is_destroyed": is_destroyed,
	}

	if not selected_upgrade_ids.is_empty():
		data["selected_upgrades"] = selected_upgrade_ids.duplicate()

	var skill_list: Array = []
	for skill in veteran_skills:
		if skill is TacticsSpecialRule:
			skill_list.append(skill.to_dict())
	if not skill_list.is_empty():
		data["veteran_skills"] = skill_list

	return data


## Deserialize from dictionary (for save load)
static func from_dict(data: Dictionary) -> TacticsCampaignUnit:
	var _Self = load("res://src/data/tactics/TacticsCampaignUnit.gd")
	var unit = _Self.new()
	unit.unit_id = data.get("unit_id", "")
	unit.custom_name = data.get("custom_name", "")
	unit.base_unit_id = data.get("base_unit_id", "")
	unit.species_id = data.get("species_id", "")
	unit.campaign_points = data.get("campaign_points", 0)
	unit.campaign_points_spent = data.get("campaign_points_spent", 0)
	unit.battles_fought = data.get("battles_fought", 0)
	unit.battles_won = data.get("battles_won", 0)
	unit.objectives_completed = data.get("objectives_completed", 0)
	unit.models_lost_total = data.get("models_lost_total", 0)
	unit.current_models = data.get("current_models", 5)
	unit.is_destroyed = data.get("is_destroyed", false)

	var upgrade_ids: Array = data.get("selected_upgrades", [])
	for uid in upgrade_ids:
		if uid is String:
			unit.selected_upgrade_ids.append(uid)

	var raw_skills: Array = data.get("veteran_skills", [])
	for raw in raw_skills:
		if raw is Dictionary:
			unit.veteran_skills.append(TacticsSpecialRule.from_dict(raw))

	return unit
