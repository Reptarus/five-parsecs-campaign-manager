class_name PlanetfallMilestoneSystem
extends RefCounted

## Tracks milestone progression and applies milestone effects.
## 7 milestones required for End Game. Each triggers lifeform evolution
## and additional replacement. Milestones earned from Buildings, Research,
## Augmentations, and Alien Artifacts.
## Source: Planetfall pp.156-160

var _milestone_data: Dictionary = {}
var _milestones: Array = []
var _tech_grants: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	_milestone_data = _load_json("res://data/planetfall/milestone_effects.json")
	_milestones = _milestone_data.get("milestones", [])
	_tech_grants = _milestone_data.get("tech_that_grants_milestones", {})
	_loaded = not _milestones.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallMilestoneSystem: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallMilestoneSystem: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## MILESTONE EFFECTS
## ============================================================================

func get_milestone_effects(index: int) -> Array:
	## Returns the effects array for the given milestone number (1-7).
	for milestone in _milestones:
		if milestone is Dictionary and milestone.get("index", 0) == index:
			return milestone.get("effects", [])
	return []


func apply_milestone(campaign: Resource, milestone_index: int) -> Dictionary:
	## Apply all effects for this milestone to the campaign.
	## Does NOT create sub-systems — returns what needs to happen so the
	## caller can orchestrate (e.g., TurnController creates enemy generators).
	## Returns a summary dict of actions taken and actions needed.
	var result: Dictionary = {
		"milestone": milestone_index,
		"effects_applied": [],
		"actions_needed": []
	}

	if not campaign:
		return result

	var effects: Array = get_milestone_effects(milestone_index)

	for effect in effects:
		if effect is not Dictionary:
			continue
		var etype: String = effect.get("type", "")

		match etype:
			"story_points":
				var amount: int = effect.get("amount", 0)
				if campaign.has_method("add_story_points"):
					campaign.add_story_points(amount)
				result["effects_applied"].append("+%d Story Points" % amount)

			"colony_integrity":
				var amount: int = effect.get("amount", 0)
				if campaign.has_method("adjust_integrity"):
					campaign.adjust_integrity(amount)
				result["effects_applied"].append("+%d Colony Integrity" % amount)

			"augmentation_points":
				var amount: int = effect.get("amount", 0)
				if "augmentation_points" in campaign:
					campaign.augmentation_points += amount
				result["effects_applied"].append("+%d Augmentation Points" % amount)

			"grunts":
				var amount: int = effect.get("amount", 0)
				if campaign.has_method("gain_grunts"):
					campaign.gain_grunts(amount)
				result["effects_applied"].append("+%d grunts" % amount)

			"ancient_sign":
				var amount: int = effect.get("amount", 0)
				if "ancient_signs" in campaign:
					for _i in range(amount):
						campaign.ancient_signs.append({})
				result["effects_applied"].append("+%d Ancient Sign(s)" % amount)

			"mission_data":
				var amount: int = effect.get("amount", 0)
				result["actions_needed"].append({
					"action": "add_mission_data",
					"amount": amount
				})

			"calamity_points":
				var amount: int = effect.get("amount", 0)
				if "calamity_points" in campaign:
					campaign.calamity_points += amount
				result["actions_needed"].append({
					"action": "check_calamity",
					"calamity_points_added": amount
				})

			"tactical_enemy_emerges":
				result["actions_needed"].append({
					"action": "create_tactical_enemy"
				})

			"character_events":
				var count: int = effect.get("count", 0)
				result["actions_needed"].append({
					"action": "roll_character_events",
					"count": count
				})

			"colony_event":
				result["actions_needed"].append({
					"action": "roll_colony_event"
				})

			"enemy_expansion":
				result["actions_needed"].append({
					"action": "expand_enemies"
				})

			"enemy_activity_roll":
				result["actions_needed"].append({
					"action": "roll_enemy_activity"
				})

			"tactical_enemy_buff":
				result["actions_needed"].append({
					"action": "buff_tactical_enemies",
					"description": effect.get("description", "")
				})

			"tactical_enemy_specialist_buff":
				result["actions_needed"].append({
					"action": "buff_tactical_specialists",
					"description": effect.get("description", "")
				})

			"enemy_activity_all":
				result["actions_needed"].append({
					"action": "enemy_activity_all_enemies",
					"description": effect.get("description", "")
				})

			"replace_condition":
				result["actions_needed"].append({
					"action": "replace_condition"
				})

			"slyn_tracking_begins":
				if "slyn_victories" in campaign:
					# Reset tracking from this point
					campaign.slyn_victories = 0
				result["effects_applied"].append("Slyn victory tracking begins")

			"endgame_launches":
				if "game_phase" in campaign:
					campaign.game_phase = "endgame"
				result["effects_applied"].append("End Game launches!")

	# Every milestone also triggers evolution + replacement
	result["actions_needed"].append({"action": "roll_lifeform_evolution"})
	result["actions_needed"].append({"action": "additional_replacement"})

	# Increment milestone count
	if campaign.has_method("add_milestone"):
		campaign.add_milestone()

	return result


## ============================================================================
## MILESTONE CHECKING
## ============================================================================

func check_tech_grants_milestone(tech_type: String, tech_id: String) -> bool:
	## Check if a building/research/augmentation/artifact grants a milestone.
	var grant_list: Array = _tech_grants.get(tech_type, [])
	return tech_id in grant_list


func get_milestone_granting_tech() -> Dictionary:
	## Returns the full tech_that_grants_milestones dict for UI display.
	return _tech_grants.duplicate(true)


func get_progress_summary(campaign: Resource) -> Dictionary:
	if not campaign:
		return {}
	var completed: int = campaign.milestones_completed if "milestones_completed" in campaign else 0
	return {
		"completed": completed,
		"total_required": _milestone_data.get("total_required", 7),
		"endgame_eligible": completed >= 7,
		"next_milestone": completed + 1 if completed < 7 else 0,
		"next_effects": get_milestone_effects(completed + 1) if completed < 7 else []
	}


## ============================================================================
## CALAMITY CHECK
## ============================================================================

func check_calamity_trigger(campaign: Resource) -> bool:
	## Planetfall p.165 — Roll 1D6, if <= calamity_points, a Calamity occurs.
	## Subtract the roll from calamity_points.
	if not campaign or not "calamity_points" in campaign:
		return false
	var points: int = campaign.calamity_points
	if points <= 0:
		return false
	var roll: int = randi_range(1, 6)
	if roll <= points:
		campaign.calamity_points -= roll
		return true
	return false


func is_loaded() -> bool:
	return _loaded
