class_name JournalEntryTypes
extends RefCounted

## Canonical taxonomy for CampaignJournal entries.
##
## Why: prior to v0.9.7 each consumer hand-rolled its own type/mood/tag set,
## leading to 14 emitted entry types vs 6 documented vs 4 colored by Dashboard.
## This class is the single source of truth. Producers may still pass raw
## strings ("type": "battle") for backward compatibility — validate_entry()
## warns but never rejects.

enum EntryType {
	BATTLE,
	STORY,
	MILESTONE,
	INJURY,
	PAYMENT,
	LOOT,
	EXPERIENCE,
	CAMPAIGN_EVENT,
	CHARACTER_EVENT,
	GALACTIC_WAR,
	RECOVERY,
	EVENT,
	PURCHASE,
	CUSTOM,
}

const TYPE_LABELS: Dictionary = {
	EntryType.BATTLE: "Battle",
	EntryType.STORY: "Story",
	EntryType.MILESTONE: "Milestone",
	EntryType.INJURY: "Injury",
	EntryType.PAYMENT: "Payment",
	EntryType.LOOT: "Loot",
	EntryType.EXPERIENCE: "Experience",
	EntryType.CAMPAIGN_EVENT: "Campaign Event",
	EntryType.CHARACTER_EVENT: "Character Event",
	EntryType.GALACTIC_WAR: "Galactic War",
	EntryType.RECOVERY: "Recovery",
	EntryType.EVENT: "Event",
	EntryType.PURCHASE: "Purchase",
	EntryType.CUSTOM: "Custom",
}

const TYPE_COLORS: Dictionary = {
	EntryType.BATTLE: Color("#EF4444"),
	EntryType.STORY: Color("#8B5CF6"),
	EntryType.MILESTONE: Color("#F59E0B"),
	EntryType.INJURY: Color("#D97706"),
	EntryType.PAYMENT: Color("#10B981"),
	EntryType.LOOT: Color("#FBBF24"),
	EntryType.EXPERIENCE: Color("#06B6D4"),
	EntryType.CAMPAIGN_EVENT: Color("#A78BFA"),
	EntryType.CHARACTER_EVENT: Color("#EC4899"),
	EntryType.GALACTIC_WAR: Color("#DC2626"),
	EntryType.RECOVERY: Color("#34D399"),
	EntryType.EVENT: Color("#9CA3AF"),
	EntryType.PURCHASE: Color("#84CC16"),
	EntryType.CUSTOM: Color("#3B82F6"),
}

const TYPE_ICONS: Dictionary = {
	EntryType.BATTLE: "[B]",
	EntryType.STORY: "[S]",
	EntryType.MILESTONE: "[M]",
	EntryType.INJURY: "[!]",
	EntryType.PAYMENT: "[$]",
	EntryType.LOOT: "[L]",
	EntryType.EXPERIENCE: "[XP]",
	EntryType.CAMPAIGN_EVENT: "[CE]",
	EntryType.CHARACTER_EVENT: "[CH]",
	EntryType.GALACTIC_WAR: "[GW]",
	EntryType.RECOVERY: "[R]",
	EntryType.EVENT: "[E]",
	EntryType.PURCHASE: "[P]",
	EntryType.CUSTOM: "[N]",
}

const STRING_TO_TYPE: Dictionary = {
	"battle": EntryType.BATTLE,
	"story": EntryType.STORY,
	"milestone": EntryType.MILESTONE,
	"injury": EntryType.INJURY,
	"payment": EntryType.PAYMENT,
	"loot": EntryType.LOOT,
	"experience": EntryType.EXPERIENCE,
	"campaign_event": EntryType.CAMPAIGN_EVENT,
	"character_event": EntryType.CHARACTER_EVENT,
	"galactic_war": EntryType.GALACTIC_WAR,
	"recovery": EntryType.RECOVERY,
	"event": EntryType.EVENT,
	"purchase": EntryType.PURCHASE,
	"custom": EntryType.CUSTOM,
}

const TYPE_TO_STRING: Dictionary = {
	EntryType.BATTLE: "battle",
	EntryType.STORY: "story",
	EntryType.MILESTONE: "milestone",
	EntryType.INJURY: "injury",
	EntryType.PAYMENT: "payment",
	EntryType.LOOT: "loot",
	EntryType.EXPERIENCE: "experience",
	EntryType.CAMPAIGN_EVENT: "campaign_event",
	EntryType.CHARACTER_EVENT: "character_event",
	EntryType.GALACTIC_WAR: "galactic_war",
	EntryType.RECOVERY: "recovery",
	EntryType.EVENT: "event",
	EntryType.PURCHASE: "purchase",
	EntryType.CUSTOM: "custom",
}

enum Mood {
	TRIUMPH,
	DEFEAT,
	NEUTRAL,
	SOMBER,
	EXCITING,
}

const MOOD_LABELS: Dictionary = {
	Mood.TRIUMPH: "Triumph",
	Mood.DEFEAT: "Defeat",
	Mood.NEUTRAL: "Neutral",
	Mood.SOMBER: "Somber",
	Mood.EXCITING: "Exciting",
}

const MOOD_COLORS: Dictionary = {
	Mood.TRIUMPH: Color("#10B981"),
	Mood.DEFEAT: Color("#EF4444"),
	Mood.NEUTRAL: Color("#9CA3AF"),
	Mood.SOMBER: Color("#6B7280"),
	Mood.EXCITING: Color("#F59E0B"),
}

const MOOD_STRING_TO_ENUM: Dictionary = {
	"triumph": Mood.TRIUMPH,
	"defeat": Mood.DEFEAT,
	"neutral": Mood.NEUTRAL,
	"somber": Mood.SOMBER,
	"exciting": Mood.EXCITING,
	"relieved": Mood.NEUTRAL,
	"desperate": Mood.SOMBER,
	"triumphant": Mood.TRIUMPH,
}

const TAGS: Dictionary = {
	"stars_of_the_story": {"label": "Stars of the Story", "color": Color("#8B5CF6")},
	"emergency": {"label": "Emergency", "color": Color("#EF4444")},
	"post_battle": {"label": "Post-Battle", "color": Color("#F59E0B")},
	"battle": {"label": "Battle", "color": Color("#EF4444")},
	"dashboard": {"label": "Dashboard", "color": Color("#06B6D4")},
	"evacuation": {"label": "Evacuation", "color": Color("#FBBF24")},
	"injury": {"label": "Injury", "color": Color("#D97706")},
	"recruitment": {"label": "Recruitment", "color": Color("#10B981")},
	"combat": {"label": "Combat", "color": Color("#EF4444")},
	"finance": {"label": "Finance", "color": Color("#10B981")},
	"elite_rank": {"label": "Elite Rank", "color": Color("#F59E0B")},
	"campaign_setup": {"label": "Campaign Setup", "color": Color("#A78BFA")},
	"red_zone": {"label": "Red Zone", "color": Color("#DC2626")},
	"black_zone": {"label": "Black Zone", "color": Color("#1F2937")},
	"milestone": {"label": "Milestone", "color": Color("#F59E0B")},
	"story_track": {"label": "Story Track", "color": Color("#8B5CF6")},
	"travel": {"label": "Travel", "color": Color("#06B6D4")},
	"world_arrival": {"label": "World Arrival", "color": Color("#34D399")},
	"world_departure": {"label": "World Departure", "color": Color("#6B7280")},
	"rival": {"label": "Rival", "color": Color("#EF4444")},
	"patron": {"label": "Patron", "color": Color("#10B981")},
	"ship": {"label": "Ship", "color": Color("#3B82F6")},
	"advancement": {"label": "Advancement", "color": Color("#34D399")},
	"kill": {"label": "Kill", "color": Color("#EF4444")},
	"death": {"label": "Death", "color": Color("#1F2937")},
}

enum MilestoneCategory {
	STORY_TRACK,
	RIVAL_ESTABLISHED,
	PATRON_ALLIED,
	RED_ZONE_LICENSE,
	PLANET_ARRIVAL,
	PLANET_DEPARTURE,
	TRAVEL_EVENT,
	RIVAL_FOLLOWED,
	CAMPAIGN_SETUP,
}

const MILESTONE_CATEGORY_STRINGS: Dictionary = {
	MilestoneCategory.STORY_TRACK: "story_track",
	MilestoneCategory.RIVAL_ESTABLISHED: "rival_established",
	MilestoneCategory.PATRON_ALLIED: "patron_allied",
	MilestoneCategory.RED_ZONE_LICENSE: "red_zone_license",
	MilestoneCategory.PLANET_ARRIVAL: "planet_arrival",
	MilestoneCategory.PLANET_DEPARTURE: "planet_departure",
	MilestoneCategory.TRAVEL_EVENT: "travel_event",
	MilestoneCategory.RIVAL_FOLLOWED: "rival_followed",
	MilestoneCategory.CAMPAIGN_SETUP: "campaign_setup",
}

const DEFAULT_TYPE_COLOR := Color("#9CA3AF")
const DEFAULT_TAG_COLOR := Color("#9CA3AF")

static func type_from_string(s: String) -> int:
	return STRING_TO_TYPE.get(s, EntryType.CUSTOM)

static func type_to_string(t: int) -> String:
	return TYPE_TO_STRING.get(t, "custom")

static func type_to_color(t) -> Color:
	if t is int:
		return TYPE_COLORS.get(t, DEFAULT_TYPE_COLOR)
	var s: String = str(t)
	if STRING_TO_TYPE.has(s):
		return TYPE_COLORS[STRING_TO_TYPE[s]]
	return DEFAULT_TYPE_COLOR

static func type_to_label(t) -> String:
	if t is int:
		return TYPE_LABELS.get(t, "Unknown")
	var s: String = str(t)
	if STRING_TO_TYPE.has(s):
		return TYPE_LABELS[STRING_TO_TYPE[s]]
	return "Unknown"

static func type_to_icon(t) -> String:
	if t is int:
		return TYPE_ICONS.get(t, "*")
	var s: String = str(t)
	if STRING_TO_TYPE.has(s):
		return TYPE_ICONS[STRING_TO_TYPE[s]]
	return "*"

static func is_canonical_type(s: String) -> bool:
	return STRING_TO_TYPE.has(s)

static func get_all_type_strings() -> Array[String]:
	var out: Array[String] = []
	for s in STRING_TO_TYPE.keys():
		out.append(s)
	return out

static func mood_to_color(m) -> Color:
	var em: int = m if m is int else MOOD_STRING_TO_ENUM.get(str(m), Mood.NEUTRAL)
	return MOOD_COLORS.get(em, MOOD_COLORS[Mood.NEUTRAL])

static func mood_to_label(m) -> String:
	var em: int = m if m is int else MOOD_STRING_TO_ENUM.get(str(m), Mood.NEUTRAL)
	return MOOD_LABELS.get(em, "Neutral")

static func mood_from_string(s: String) -> int:
	return MOOD_STRING_TO_ENUM.get(s, Mood.NEUTRAL)

static func is_canonical_mood(s: String) -> bool:
	return MOOD_STRING_TO_ENUM.has(s)

static func tag_color(tag: String) -> Color:
	return TAGS.get(tag, {}).get("color", DEFAULT_TAG_COLOR)

static func tag_label(tag: String) -> String:
	return TAGS.get(tag, {}).get("label", tag.capitalize().replace("_", " "))

static func is_canonical_tag(tag: String) -> bool:
	return TAGS.has(tag)

static func get_all_tag_keys() -> Array[String]:
	var out: Array[String] = []
	for k in TAGS.keys():
		out.append(k)
	return out

static func validate_entry(data: Dictionary) -> bool:
	## Soft-validate a journal entry. Warns on non-canonical fields but never
	## rejects — backwards compatible with existing string-typed producers.
	## Returns true if entry is fully canonical (no warnings).
	var ok := true
	var t: String = str(data.get("type", ""))
	if not t.is_empty() and not STRING_TO_TYPE.has(t):
		push_warning("Journal entry has non-canonical type: '%s'" % t)
		ok = false
	var m: String = str(data.get("mood", ""))
	if not m.is_empty() and not MOOD_STRING_TO_ENUM.has(m):
		push_warning("Journal entry has non-canonical mood: '%s'" % m)
		ok = false
	var tags: Array = data.get("tags", [])
	for tag_value in tags:
		var tag_str: String = str(tag_value)
		if not TAGS.has(tag_str):
			push_warning("Journal entry has non-canonical tag: '%s'" % tag_str)
			ok = false
	return ok
