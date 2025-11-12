class_name FPCM_VictoryDescriptions
extends Resource

# GlobalEnums available as autoload singleton

var _CAMPAIGN_DESCRIPTIONS: Dictionary = {
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20: "Play 20 campaign turns",
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50: "Play 50 campaign turns",
	GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100: "Play 100 campaign turns",
	GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20: "Fight 20 battles",
	GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50: "Fight 50 battles",
	GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100: "Fight 100 battles",
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3: "Complete 3 story quests",
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5: "Complete 5 story quests",
	GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10: "Complete 10 story quests",
	GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10: "Accumulate 10 story points",
	GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20: "Accumulate 20 story points",
	GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K: "Accumulate 50,000 credits",
	GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K: "Accumulate 100,000 credits",
	GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10: "Achieve reputation level 10",
	GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20: "Achieve reputation level 20",
	GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL: "Keep your original character alive",
	GlobalEnums.FiveParsecsCampaignVictoryType.CREW_SIZE_10: "Reach crew size of 10"
}

var _MISSION_DESCRIPTIONS: Dictionary = {
	GlobalEnums.MissionVictoryType.ELIMINATION: "Eliminate all enemy forces",
	GlobalEnums.MissionVictoryType.EXTRACTION: "Reach extraction point"
	# Add other mission victory descriptions
}

static func get_campaign_description(victory_type: int) -> String:
	match victory_type:
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_20:
			return "Play 20 campaign turns"
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_50:
			return "Play 50 campaign turns"
		GlobalEnums.FiveParsecsCampaignVictoryType.TURNS_100:
			return "Play 100 campaign turns"
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20:
			return "Fight 20 battles"
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50:
			return "Fight 50 battles"
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100:
			return "Fight 100 battles"
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3:
			return "Complete 3 story quests"
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5:
			return "Complete 5 story quests"
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			return "Complete 10 story quests"
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_10:
			return "Accumulate 10 story points"
		GlobalEnums.FiveParsecsCampaignVictoryType.STORY_POINTS_20:
			return "Accumulate 20 story points"
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K:
			return "Accumulate 50,000 credits"
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			return "Accumulate 100,000 credits"
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10:
			return "Achieve reputation level 10"
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			return "Achieve reputation level 20"
		GlobalEnums.FiveParsecsCampaignVictoryType.CHARACTER_SURVIVAL:
			return "Keep your original character alive"
		GlobalEnums.FiveParsecsCampaignVictoryType.CREW_SIZE_10:
			return "Reach crew size of 10"
		_:
			return "Unknown victory condition"

static func get_mission_description(victory_type: int) -> String:
	match victory_type:
		GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_3, GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_5, GlobalEnums.FiveParsecsCampaignVictoryType.QUESTS_10:
			return "Story mission objective"
		GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_50K, GlobalEnums.FiveParsecsCampaignVictoryType.CREDITS_100K:
			return "Wealth accumulation objective"
		GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_10, GlobalEnums.FiveParsecsCampaignVictoryType.REPUTATION_20:
			return "Reputation building objective"
		GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_20, GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_50, GlobalEnums.FiveParsecsCampaignVictoryType.BATTLES_100:
			return "Combat mission objective"
		_:
			return "Standard mission objective"