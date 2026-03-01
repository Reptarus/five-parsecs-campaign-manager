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
	var resources: Dictionary = campaign.resources if "resources" in campaign else {}
	var battle_stats: Dictionary = campaign.battle_stats if "battle_stats" in campaign else {}

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
			progress = resources.get("credits", 0)
			required = 10000
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K:
			vc_name = "Wealthy (50,000 Credits)"
			progress = resources.get("credits", 0)
			required = 50000
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			vc_name = "Rich (100,000 Credits)"
			progress = resources.get("credits", 0)
			required = 100000
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_THRESHOLD:
			vc_name = "Famous (Reputation 20)"
			progress = resources.get("reputation", 0)
			required = 20
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10:
			vc_name = "Known (Reputation 10)"
			progress = resources.get("reputation", 0)
			required = 10
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			vc_name = "Famous (Reputation 20)"
			progress = resources.get("reputation", 0)
			required = 20
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3:
			vc_name = "Quest Starter (3 Quests)"
			progress = campaign.completed_missions.size() if "completed_missions" in campaign else 0
			required = 3
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5:
			vc_name = "Quest Seeker (5 Quests)"
			progress = campaign.completed_missions.size() if "completed_missions" in campaign else 0
			required = 5
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			vc_name = "Quest Master (10 Quests)"
			progress = campaign.completed_missions.size() if "completed_missions" in campaign else 0
			required = 10
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20:
			vc_name = "Seasoned Crew (20 Battles)"
			progress = battle_stats.get("battles_won", 0)
			required = 20
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50:
			vc_name = "Veteran Crew (50 Battles)"
			progress = battle_stats.get("battles_won", 0)
			required = 50
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100:
			vc_name = "Legendary Crew (100 Battles)"
			progress = battle_stats.get("battles_won", 0)
			required = 100
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_COMPLETE:
			vc_name = "Story Complete"
			progress = 0
			required = 1
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10:
			vc_name = "Story Builder (10 Story Points)"
			progress = resources.get("story_points", 0)
			required = 10
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20:
			vc_name = "Story Master (20 Story Points)"
			progress = resources.get("story_points", 0)
			required = 20
		_:
			vc_name = "Campaign Goal"
			progress = 0
			required = 1

	if progress >= required:
		return {"achieved": true, "message": "VICTORY! %s achieved!" % vc_name}
	else:
		return {"achieved": false, "message": "%s: %d / %d" % [vc_name, progress, required]}
