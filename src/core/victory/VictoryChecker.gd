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
	# Campaign-level tallies for the p.64 conditions added below. Both are written
	# by GameStateManager (increment_unique_individual_kills /
	# record_character_upgrade); a campaign that has never recorded one simply
	# reads 0 and the condition sits at 0/N rather than silently resolving to
	# "no victory condition set", which is what these used to do.
	var _unique_kills: int = int(pd.get("unique_individuals_killed", 0))
	var _characters_upgraded_10: int = int(pd.get("characters_upgraded_10", 0))

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
		# The last eight of the seventeen conditions on Core Rules p.64. They were
		# offered by the wizard and mapped to nothing, so they resolved to NONE and
		# reported "No victory condition set" forever.
		GlobalEnums.FiveParsecsCampaignVictoryType.UNIQUE_KILLS_10:
			vc_name = "Kill 10 Unique Individuals"
			progress = _unique_kills
			required = 10
		GlobalEnums.FiveParsecsCampaignVictoryType.UNIQUE_KILLS_25:
			vc_name = "Kill 25 Unique Individuals"
			progress = _unique_kills
			required = 25
		# p.64: "For Character Upgrade Victory Conditions, the characters do not
		# have to be in the crew at the same time. If one character Upgrades 10
		# times and dies, all 10 Character Upgrades still count." So these count
		# from a campaign-level tally, never from the live roster.
		GlobalEnums.FiveParsecsCampaignVictoryType.UPGRADE_1X10:
			vc_name = "Upgrade a Character 10 Times"
			progress = _characters_upgraded_10
			required = 1
		GlobalEnums.FiveParsecsCampaignVictoryType.UPGRADE_3X10:
			vc_name = "Upgrade 3 Characters 10 Times"
			progress = _characters_upgraded_10
			required = 3
		GlobalEnums.FiveParsecsCampaignVictoryType.UPGRADE_5X10:
			vc_name = "Upgrade 5 Characters 10 Times"
			progress = _characters_upgraded_10
			required = 5
		# The three difficulty-locked variants: 50 turns, but only counted while
		# the campaign is set to that mode.
		GlobalEnums.FiveParsecsCampaignVictoryType.CHALLENGING_50:
			vc_name = "50 Turns in Challenging Mode"
			progress = turn_number if _difficulty_at_least(campaign, "challenging") else 0
			required = 50
		GlobalEnums.FiveParsecsCampaignVictoryType.HARDCORE_50:
			vc_name = "50 Turns in Hardcore Mode"
			progress = turn_number if _difficulty_at_least(campaign, "hardcore") else 0
			required = 50
		GlobalEnums.FiveParsecsCampaignVictoryType.INSANITY_50:
			vc_name = "50 Turns in Insanity Mode"
			progress = turn_number if _difficulty_at_least(campaign, "insanity") else 0
			required = 50
		_:
			vc_name = "Campaign Goal"
			progress = 0
			required = 1

	if progress >= required:
		return {"achieved": true, "message": "VICTORY! %s achieved!" % vc_name}
	else:
		return {"achieved": false, "message": "%s: %d / %d" % [vc_name, progress, required]}

static func _difficulty_at_least(campaign: Variant, mode_name: String) -> bool:
	## The three "50 turns in X mode" conditions (Core Rules p.64) only count while
	## the campaign IS that mode. campaign.difficulty is a
	## GlobalEnums.DifficultyLevel; compare by name so the deprecated
	## HARD/NIGHTMARE/ELITE values cannot accidentally satisfy one.
	if not ("difficulty" in campaign):
		return false
	var level: int = int(campaign.difficulty)
	match mode_name:
		"challenging":
			return level == GlobalEnums.DifficultyLevel.CHALLENGING
		"hardcore":
			return level == GlobalEnums.DifficultyLevel.HARDCORE
		"insanity":
			return level == GlobalEnums.DifficultyLevel.INSANITY
	return false

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
		"unique_kills_10": GlobalEnums.FiveParsecsCampaignVictoryType.UNIQUE_KILLS_10,
		"unique_kills_25": GlobalEnums.FiveParsecsCampaignVictoryType.UNIQUE_KILLS_25,
		"upgrade_1x10": GlobalEnums.FiveParsecsCampaignVictoryType.UPGRADE_1X10,
		"upgrade_3x10": GlobalEnums.FiveParsecsCampaignVictoryType.UPGRADE_3X10,
		"upgrade_5x10": GlobalEnums.FiveParsecsCampaignVictoryType.UPGRADE_5X10,
		"challenging_50": GlobalEnums.FiveParsecsCampaignVictoryType.CHALLENGING_50,
		"hardcore_50": GlobalEnums.FiveParsecsCampaignVictoryType.HARDCORE_50,
		"insanity_50": GlobalEnums.FiveParsecsCampaignVictoryType.INSANITY_50,
		# The eight the wizard offered with nowhere to land. Keys are the ones in
		# data/campaign_config.json, which matches the Core Rules p.64 list.

	}
	return _map.get(key.to_lower(), GlobalEnums.FiveParsecsCampaignVictoryType.NONE)
