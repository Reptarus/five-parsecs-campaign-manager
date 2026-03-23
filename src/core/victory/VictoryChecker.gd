extends RefCounted
## Centralized victory condition checking logic.
## Extracted from EndPhasePanel.check_victory() for reuse.

const GlobalEnums = preload("res://src/core/systems/GlobalEnums.gd")

## Check victory conditions for a campaign.
## Returns {achieved: bool, message: String}
static func check_victory(campaign: Variant, turn_number: int = 0) -> Dictionary:
	if not campaign:
		return {"achieved": false, "message": ""}

	var vc: int = campaign.get_victory_condition() if campaign.has_method("get_victory_condition") else 0
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
