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
	EntryType.BATTLE: UIColors.COLOR_RED,
	EntryType.STORY: UIColors.COLOR_PURPLE,
	EntryType.MILESTONE: UIColors.COLOR_AMBER,
	EntryType.INJURY: UIColors.COLOR_AMBER,
	EntryType.PAYMENT: UIColors.COLOR_EMERALD,
	EntryType.LOOT: Color("#FBBF24"),
	EntryType.EXPERIENCE: UIColors.COLOR_CYAN,
	EntryType.CAMPAIGN_EVENT: Color("#A78BFA"),
	EntryType.CHARACTER_EVENT: Color("#EC4899"),
	EntryType.GALACTIC_WAR: UIColors.COLOR_RED,
	EntryType.RECOVERY: Color("#34D399"),
	EntryType.EVENT: UIColors.COLOR_TEXT_SECONDARY,
	EntryType.PURCHASE: Color("#84CC16"),
	EntryType.CUSTOM: UIColors.COLOR_BLUE,
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
	Mood.TRIUMPH: UIColors.COLOR_EMERALD,
	Mood.DEFEAT: UIColors.COLOR_RED,
	Mood.NEUTRAL: UIColors.COLOR_TEXT_SECONDARY,
	Mood.SOMBER: UIColors.COLOR_TEXT_MUTED,
	Mood.EXCITING: UIColors.COLOR_AMBER,
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

## T11-44. Moods that exist ONLY in already-persisted journal entries.
##
## Eight producer sites used to write these five spellings. Every one fell through
## MOOD_STRING_TO_ENUM to Mood.NEUTRAL, so the entry rendered with the wrong label
## AND the wrong colour - silently, because validate_entry() only push_warning()s.
## The producers are fixed; this map exists for the entries those producers already
## WROTE INTO SAVE FILES, which no source change can reach.
##
## ⚠ Deliberately SEPARATE from MOOD_STRING_TO_ENUM rather than merged into it.
## MOOD_STRING_TO_ENUM is the authoring vocabulary that
## `scripts/lint_journal_vocabulary.py` enforces on new code; folding these in would
## make "positive" legal to write again and quietly re-open the finding. Old data is
## tolerated, new code is not - which is why is_canonical_mood() below does NOT
## consult this map.
##
## Each mapping is grounded in what the entries actually said, not in the word:
##   positive     "<name> Returns" (+XP, +Loot roll) / "Lost Item Found!"
##   negative     "Lost Item Gone for Good" / "<name> Has Left the Crew"
##   informative  Introductory Campaign milestones and mechanic unlocks
##   discovery    Traveler's Gift (a Quest lead) / Manipulator Insight (+SP)
##   bittersweet  "A Bitter Day" - held the field, lost a comrade (p.67)
const MOOD_LEGACY_ALIASES: Dictionary = {
	"positive": Mood.TRIUMPH,
	"negative": Mood.DEFEAT,
	"informative": Mood.NEUTRAL,
	"discovery": Mood.EXCITING,
	"bittersweet": Mood.SOMBER,
}

const TAGS: Dictionary = {
	"stars_of_the_story": {"label": "Stars of the Story", "color": UIColors.COLOR_PURPLE},
	"emergency": {"label": "Emergency", "color": UIColors.COLOR_RED},
	"post_battle": {"label": "Post-Battle", "color": UIColors.COLOR_AMBER},
	"battle": {"label": "Battle", "color": UIColors.COLOR_RED},
	"dashboard": {"label": "Dashboard", "color": UIColors.COLOR_CYAN},
	"evacuation": {"label": "Evacuation", "color": Color("#FBBF24")},
	"injury": {"label": "Injury", "color": UIColors.COLOR_AMBER},
	"recruitment": {"label": "Recruitment", "color": UIColors.COLOR_EMERALD},
	"combat": {"label": "Combat", "color": UIColors.COLOR_RED},
	"finance": {"label": "Finance", "color": UIColors.COLOR_EMERALD},
	"elite_rank": {"label": "Elite Rank", "color": UIColors.COLOR_AMBER},
	"campaign_setup": {"label": "Campaign Setup", "color": Color("#A78BFA")},
	"red_zone": {"label": "Red Zone", "color": UIColors.COLOR_RED},
	"black_zone": {"label": "Black Zone", "color": UIColors.COLOR_TERTIARY},
	"milestone": {"label": "Milestone", "color": UIColors.COLOR_AMBER},
	"story_track": {"label": "Story Track", "color": UIColors.COLOR_PURPLE},
	"travel": {"label": "Travel", "color": UIColors.COLOR_CYAN},
	"world_arrival": {"label": "World Arrival", "color": Color("#34D399")},
	"world_departure": {"label": "World Departure", "color": UIColors.COLOR_TEXT_MUTED},
	"rival": {"label": "Rival", "color": UIColors.COLOR_RED},
	"patron": {"label": "Patron", "color": UIColors.COLOR_EMERALD},
	"ship": {"label": "Ship", "color": UIColors.COLOR_BLUE},
	# Ship debt is a named Core Rules p.76 mechanic with its own interest and
	# seizure rules, so it earns a tag rather than being folded into "finance".
	# Emitted by CampaignPhaseManager._process_ship_debt(); it warned on every
	# debt-bearing turn because this sweep predated that producer.
	"debt": {"label": "Debt", "color": UIColors.COLOR_TERTIARY},
	"advancement": {"label": "Advancement", "color": Color("#34D399")},
	"kill": {"label": "Kill", "color": UIColors.COLOR_RED},
	"death": {"label": "Death", "color": UIColors.COLOR_TERTIARY},

	# Vocabulary the producers ACTUALLY emit. 44 of the 54 distinct tags in
	# src/ were absent here, and validate_entry() push_warning()s on every
	# unlisted tag — so nearly every journal entry logged several warnings,
	# burying genuine ones in an alpha bug report. Extracted mechanically from
	# all "tags": [...] literals, then labelled/coloured against the palette above.
	"victory": {"label": "Victory", "color": UIColors.COLOR_EMERALD},
	"defeat": {"label": "Defeat", "color": UIColors.COLOR_TERTIARY},
	"held_field": {"label": "Held the Field", "color": UIColors.COLOR_AMBER},
	"bitter_day": {"label": "A Bitter Day", "color": UIColors.COLOR_RED},
	"loot": {"label": "Loot", "color": UIColors.COLOR_AMBER},
	"payment": {"label": "Payment", "color": UIColors.COLOR_EMERALD},
	"rewards": {"label": "Rewards", "color": UIColors.COLOR_EMERALD},
	"invasion": {"label": "Invasion", "color": UIColors.COLOR_RED},
	"galactic_war": {"label": "Galactic War", "color": UIColors.COLOR_RED},
	"campaign_event": {"label": "Campaign Event", "color": Color("#A78BFA")},
	"character_event": {"label": "Character Event", "color": Color("#A78BFA")},
	"quest": {"label": "Quest", "color": UIColors.COLOR_PURPLE},
	"story_points": {"label": "Story Points", "color": UIColors.COLOR_PURPLE},
	"upkeep": {"label": "Upkeep", "color": UIColors.COLOR_EMERALD},
	# Second sweep (Aug 8 2026). The first sweep extracted tags from `"tags": [...]`
	# literals ANYWHERE in src/, which over-matches — most such literals are weapon,
	# terrain and mission taxonomies with nothing to do with the journal. Narrowing
	# to dicts actually passed to create_entry() found 19 names still missing, each
	# push_warning()ing on every entry that used it. `scripts/lint_journal_vocabulary.py`
	# now guards this set so the next one is caught before it ships.
	"captain": {"label": "Captain", "color": UIColors.COLOR_AMBER},
	"connection": {"label": "Connection", "color": UIColors.COLOR_CYAN},
	"expanded_connections": {"label": "Expanded Connections", "color": UIColors.COLOR_CYAN},
	"expanded_quests": {"label": "Expanded Quests", "color": UIColors.COLOR_PURPLE},
	"crew": {"label": "Crew", "color": UIColors.COLOR_EMERALD},
	"recruit": {"label": "Recruit", "color": UIColors.COLOR_EMERALD},
	"training": {"label": "Training", "color": Color("#34D399")},
	"illegal": {"label": "Illegal", "color": UIColors.COLOR_RED},
	"interdiction": {"label": "Interdiction", "color": UIColors.COLOR_RED},
	"license": {"label": "License", "color": UIColors.COLOR_AMBER},
	"notable_sight": {"label": "Notable Sight", "color": Color("#FBBF24")},
	"onboard_items": {"label": "On-board Items", "color": UIColors.COLOR_BLUE},
	"penalty": {"label": "Penalty", "color": UIColors.COLOR_RED},
	"reward": {"label": "Reward", "color": UIColors.COLOR_EMERALD},
	"rumor": {"label": "Rumor", "color": UIColors.COLOR_PURPLE},
	"salvage": {"label": "Salvage", "color": Color("#FBBF24")},
	"scrapper": {"label": "Scrapper", "color": Color("#FBBF24")},
	"world": {"label": "World", "color": Color("#34D399")},
	"world_trait": {"label": "World Trait", "color": Color("#34D399")},

	"trading": {"label": "Trading", "color": UIColors.COLOR_EMERALD},
	"departure": {"label": "Departure", "color": UIColors.COLOR_TEXT_MUTED},
	"return": {"label": "Return", "color": UIColors.COLOR_CYAN},
	"completion": {"label": "Completion", "color": Color("#34D399")},
	"unlock": {"label": "Unlock", "color": UIColors.COLOR_AMBER},
	"introductory_campaign": {"label": "Introductory Campaign", "color": Color("#A78BFA")},
	"experience": {"label": "Experience", "color": Color("#34D399")},
	"recovery": {"label": "Recovery", "color": UIColors.COLOR_AMBER},
	"medical_bay": {"label": "Medical Bay", "color": UIColors.COLOR_AMBER},
	"crew_dismissed": {"label": "Crew Dismissed", "color": UIColors.COLOR_TEXT_MUTED},
	"business_elsewhere": {"label": "Business Elsewhere", "color": UIColors.COLOR_TEXT_MUTED},
	"item_recovery": {"label": "Item Recovery", "color": UIColors.COLOR_AMBER},
	"species_ability": {"label": "Species Ability", "color": UIColors.COLOR_PURPLE},
	"strange_character": {"label": "Strange Character", "color": UIColors.COLOR_PURPLE},
	"psionics": {"label": "Psionics", "color": UIColors.COLOR_PURPLE},
	"feeler": {"label": "Feeler", "color": UIColors.COLOR_PURPLE},
	"swift": {"label": "Swift", "color": UIColors.COLOR_PURPLE},
	"traveler": {"label": "Traveler", "color": UIColors.COLOR_PURPLE},
	"unity_agent": {"label": "Unity Agent", "color": UIColors.COLOR_PURPLE},
	"manipulator": {"label": "Manipulator", "color": UIColors.COLOR_PURPLE},
	"ship_component": {"label": "Ship Component", "color": UIColors.COLOR_BLUE},
	"component": {"label": "Component", "color": UIColors.COLOR_BLUE},
	"installation": {"label": "Installation", "color": UIColors.COLOR_BLUE},
	"improved_shielding": {"label": "Improved Shielding", "color": UIColors.COLOR_BLUE},
	"bug_hunt": {"label": "Bug Hunt", "color": Color("#84CC16")},
	"planetfall": {"label": "Planetfall", "color": Color("#34D399")},
	"tactics": {"label": "Tactics", "color": UIColors.COLOR_BLUE},
	"compendium": {"label": "Compendium", "color": Color("#A78BFA")},
	"expanded_database": {"label": "Expanded Database", "color": Color("#A78BFA")},
	"d100": {"label": "D100 Roll", "color": UIColors.COLOR_TEXT_MUTED},
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

const DEFAULT_TYPE_COLOR := UIColors.COLOR_TEXT_SECONDARY
const DEFAULT_TAG_COLOR := UIColors.COLOR_TEXT_SECONDARY

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

## T11-44. THE single mood lookup. There used to be three copies of
## `MOOD_STRING_TO_ENUM.get(x, NEUTRAL)` in this file, so teaching the reader about
## the legacy spellings meant remembering all three - the shape that produced three
## disagreeing species-name implementations (T11-31).
static func resolve_mood(m) -> int:
	if m is int:
		return m
	var s: String = str(m)
	if MOOD_STRING_TO_ENUM.has(s):
		return MOOD_STRING_TO_ENUM[s]
	return MOOD_LEGACY_ALIASES.get(s, Mood.NEUTRAL)

static func mood_to_color(m) -> Color:
	return MOOD_COLORS.get(resolve_mood(m), MOOD_COLORS[Mood.NEUTRAL])

static func mood_to_label(m) -> String:
	return MOOD_LABELS.get(resolve_mood(m), "Neutral")

static func mood_from_string(s: String) -> int:
	return resolve_mood(s)

## ⚠ Deliberately does NOT consult MOOD_LEGACY_ALIASES - see the note there. A
## legacy mood RENDERS correctly but is not canonical to WRITE.
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
	# T11-44. A KNOWN legacy spelling is not a warning: it comes off disk, it renders
	# correctly through resolve_mood(), and warning would spam the log once per loaded
	# entry for data that is already handled. New code cannot introduce one - that is
	# the lint's job, statically, where it can be fixed. An UNKNOWN mood still warns.
	if not m.is_empty() and not MOOD_STRING_TO_ENUM.has(m) \
			and not MOOD_LEGACY_ALIASES.has(m):
		push_warning("Journal entry has non-canonical mood: '%s'" % m)
		ok = false
	var tags: Array = data.get("tags", [])
	for tag_value in tags:
		var tag_str: String = str(tag_value)
		if not TAGS.has(tag_str):
			push_warning("Journal entry has non-canonical tag: '%s'" % tag_str)
			ok = false
	return ok
