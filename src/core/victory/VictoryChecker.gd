extends RefCounted
## Centralized victory condition checking logic.
## Extracted from EndPhasePanel.check_victory() for reuse.

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Check victory conditions for a campaign.
## Returns {achieved: bool, message: String}
static func check_victory(campaign: Variant, turn_number: int = 0) -> Dictionary:
	if not campaign:
		return {"achieved": false, "message": ""}

	# Read victory condition — supports both enum int and dict-based formats
	var vc: int = 0
	if campaign.has_method("get_victory_condition"):
		vc = campaign.get_victory_condition()
	elif "victory_conditions" in campaign and campaign.victory_conditions is Dictionary:
		# Dict-based format from ExpandedConfigPanel: {"selected_conditions": {...}, ...}
		# or direct format: {"type": int}
		var vcd: Dictionary = campaign.victory_conditions
		if vcd.has("type") and vcd["type"] is int:
			vc = vcd["type"]
		elif vcd.has("selected_conditions") and vcd["selected_conditions"] is Dictionary:
			# Use first selected condition — map string key to enum
			var sc: Dictionary = vcd["selected_conditions"]
			if not sc.is_empty():
				vc = _map_condition_key_to_enum(sc.keys()[0])
		elif not vcd.is_empty():
			# Direct dict with condition keys (legacy/simple format)
			vc = _map_condition_key_to_enum(vcd.keys()[0])
	if vc == GlobalEnums.FiveParsecsCampaignVictoryType.NONE:
		return {"achieved": false, "message": "No victory condition set"}

	var progress := 0
	var required := 1
	var vc_name := "Campaign Goal"
	# Read from FiveParsecsCampaignCore's actual data structure:
	# - credits/reputation/story_points are direct properties on campaign
	# - battles_won/missions_completed are in progress_data dict
	var pd: Dictionary = campaign.progress_data if "progress_data" in campaign else {}
	var _credits: int = campaign.credits if "credits" in campaign else pd.get("credits", 0)
	var _reputation: int = campaign.reputation if "reputation" in campaign else pd.get("reputation", 0)
	var _story_points: int = campaign.story_points if "story_points" in campaign else pd.get("story_points", 0)
	var _battles_won: int = pd.get("battles_won", 0)
	var _missions_completed: int = pd.get("missions_completed", 0)
	# Also check completed_missions array if it exists (quest-style tracking)
	if "completed_missions" in campaign and campaign.completed_missions is Array:
		_missions_completed = maxi(_missions_completed, campaign.completed_missions.size())

	match vc:
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20:
			vc_name = "Short Campaign (20 Turns)"
			progress = turn_number
			required = 20
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50:
			vc_name = "Standard Campaign (50 Turns)"
			progress = turn_number
			required = 50
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100:
			vc_name = "Epic Campaign (100 Turns)"
			progress = turn_number
			required = 100
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_THRESHOLD:
			vc_name = "Wealthy (10,000 Credits)"
			progress = _credits
			required = 10000
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K:
			vc_name = "Wealthy (50,000 Credits)"
			progress = _credits
			required = 50000
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			vc_name = "Rich (100,000 Credits)"
			progress = _credits
			required = 100000
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_THRESHOLD:
			vc_name = "Famous (Reputation 20)"
			progress = _reputation
			required = 20
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10:
			vc_name = "Known (Reputation 10)"
			progress = _reputation
			required = 10
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			vc_name = "Famous (Reputation 20)"
			progress = _reputation
			required = 20
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3:
			vc_name = "Quest Starter (3 Quests)"
			progress = _missions_completed
			required = 3
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5:
			vc_name = "Quest Seeker (5 Quests)"
			progress = _missions_completed
			required = 5
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			vc_name = "Quest Master (10 Quests)"
			progress = _missions_completed
			required = 10
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20:
			vc_name = "Seasoned Crew (20 Battles)"
			progress = _battles_won
			required = 20
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50:
			vc_name = "Veteran Crew (50 Battles)"
			progress = _battles_won
			required = 50
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100:
			vc_name = "Legendary Crew (100 Battles)"
			progress = _battles_won
			required = 100
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE:
			vc_name = "Story Complete"
			progress = 0
			required = 1
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10:
			vc_name = "Story Builder (10 Story Points)"
			progress = _story_points
			required = 10
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20:
			vc_name = "Story Master (20 Story Points)"
			progress = _story_points
			required = 20
		_:
			vc_name = "Campaign Goal"
			progress = 0
			required = 1

	if progress >= required:
		return {"achieved": true, "message": "VICTORY! %s achieved!" % vc_name}
	else:
		return {"achieved": false, "message": "%s: %d / %d" % [vc_name, progress, required]}

## Map string condition keys (from ExpandedConfigPanel) to enum values
static func _map_condition_key_to_enum(key: String) -> int:
	var _map := {
		"turns_20": GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20,
		"turns_50": GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50,
		"turns_100": GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100,
		"wealth": GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_THRESHOLD,
		"credits_threshold": GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_THRESHOLD,
		"credits_50k": GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K,
		"credits_100k": GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K,
		"reputation": GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_THRESHOLD,
		"reputation_10": GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10,
		"reputation_20": GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20,
		"quests_3": GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3,
		"quests_5": GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5,
		"quests_10": GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10,
		"battles_20": GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20,
		"battles_50": GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50,
		"battles_100": GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100,
		"story_complete": GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE,
		"story_points_10": GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10,
		"story_points_20": GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20,
	}
	return _map.get(key.to_lower(), GlobalEnums.FiveParsecsCampaignVictoryType.NONE)
