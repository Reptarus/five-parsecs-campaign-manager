class_name PlanetfallAugmentationSystem
extends RefCounted

## Manages Planetfall genetic augmentation purchases.
## Cost = number of augmentations already owned + 1.
## Max 1 purchase per campaign turn.
## Applies to all current and future characters (except Bots/Soulless).
## Source: Planetfall p.105

var _augmentations: Array = []
var _cost_formula: String = ""
var _max_per_turn: int = 1
var _excludes: Array = []
var _loaded: bool = false


func _init() -> void:
	_load_data()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_data() -> void:
	var path := "res://data/planetfall/augmentations.json"
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallAugmentationSystem: JSON not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	if json.data is not Dictionary:
		return
	var data: Dictionary = json.data
	_augmentations = data.get("augmentations", [])
	_cost_formula = data.get("cost_formula", "augmentations_owned + 1")
	_max_per_turn = data.get("max_per_turn", 1)
	_excludes = data.get("excludes", [])
	_loaded = not _augmentations.is_empty()


## ============================================================================
## QUERIES
## ============================================================================

func get_all_augmentations() -> Array:
	return _augmentations.duplicate()


func get_augmentation(augmentation_id: String) -> Dictionary:
	for aug in _augmentations:
		if aug is Dictionary and aug.get("id", "") == augmentation_id:
			return aug.duplicate()
	return {}


func get_available_augmentations(campaign: Resource) -> Array:
	## Returns augmentations not yet purchased by this campaign.
	var owned: Array = _get_owned_ids(campaign)
	var available: Array = []
	for aug in _augmentations:
		if aug is Dictionary:
			var aug_id: String = aug.get("id", "")
			if not aug_id.is_empty() and not owned.has(aug_id):
				available.append(aug.duplicate())
	return available


func get_augmentation_cost(campaign: Resource) -> int:
	## Cost = number of augmentations already owned + 1 (Planetfall p.105).
	var owned_count: int = _get_owned_ids(campaign).size()
	return owned_count + 1


func can_augment(campaign: Resource, augmentation_id: String) -> bool:
	## Check if campaign can purchase this augmentation.
	if not campaign:
		return false
	var owned: Array = _get_owned_ids(campaign)
	if owned.has(augmentation_id):
		return false
	var cost: int = get_augmentation_cost(campaign)
	var ap: int = campaign.augmentation_points if "augmentation_points" in campaign else 0
	return ap >= cost


func has_purchased_this_turn(campaign: Resource) -> bool:
	## Check if an augmentation was already purchased this turn.
	## Uses a transient flag in research_data.
	if not campaign or not "research_data" in campaign:
		return false
	var rd: Dictionary = campaign.research_data
	return rd.get("augmentation_purchased_this_turn", false)


## ============================================================================
## MUTATION
## ============================================================================

func apply_augmentation(
		campaign: Resource,
		augmentation_id: String) -> Dictionary:
	## Purchase an augmentation. Deducts AP, adds to owned list.
	## Returns {success: bool, augmentation: Dictionary, cost: int, error: String}.
	if not campaign:
		return {"success": false, "error": "No campaign"}
	if has_purchased_this_turn(campaign):
		return {"success": false, "error": "Already purchased an augmentation this turn"}

	var aug: Dictionary = get_augmentation(augmentation_id)
	if aug.is_empty():
		return {"success": false, "error": "Unknown augmentation: %s" % augmentation_id}

	var owned: Array = _get_owned_ids(campaign)
	if owned.has(augmentation_id):
		return {"success": false, "error": "Already owned: %s" % augmentation_id}

	var cost: int = get_augmentation_cost(campaign)
	var ap: int = campaign.augmentation_points if "augmentation_points" in campaign else 0
	if ap < cost:
		return {
			"success": false,
			"error": "Not enough AP (%d available, %d required)" % [ap, cost]
		}

	# Deduct AP
	campaign.augmentation_points -= cost

	# Add to owned list
	if not campaign.research_data.has("augmentations_owned"):
		campaign.research_data["augmentations_owned"] = []
	campaign.research_data["augmentations_owned"].append(augmentation_id)

	# Mark purchased this turn
	campaign.research_data["augmentation_purchased_this_turn"] = true

	# Apply immediate campaign effects (milestone, story points)
	var effect: Dictionary = aug.get("effect", {})
	if effect.has("milestone"):
		if campaign.has_method("add_milestone"):
			campaign.add_milestone()
	if effect.has("story_points"):
		if campaign.has_method("add_story_points"):
			campaign.add_story_points(effect.get("story_points", 0))

	return {"success": true, "augmentation": aug, "cost": cost}


func clear_turn_flag(campaign: Resource) -> void:
	## Called at turn start to reset the per-turn purchase flag.
	if campaign and "research_data" in campaign:
		campaign.research_data["augmentation_purchased_this_turn"] = false


## ============================================================================
## PRIVATE
## ============================================================================

func _get_owned_ids(campaign: Resource) -> Array:
	if not campaign or not "research_data" in campaign:
		return []
	var rd: Dictionary = campaign.research_data
	return rd.get("augmentations_owned", [])


func is_loaded() -> bool:
	return _loaded
