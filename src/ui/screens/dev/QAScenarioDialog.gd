extends Window

## QA Scenarios — jump a loaded campaign to a state that is expensive to play to.
##
## DEBUG BUILDS ONLY. The dashboard entry point is gated on OS.is_debug_build(),
## which is the honest gate: a release export physically cannot open this, so
## there is no "hidden unlock gesture" that can be found by a player or left on
## by accident. Remote-deploy QA builds ARE debug builds, so the tablet gets it.
##
## This dialog is presentation only. Every mutation happens in
## QAScenarioLoader.apply(), which routes through the same owner setters the
## Campaign Editor uses — see that file's header for why fixtures are deltas and
## not save files, and for why nothing here jumps the PHASE.

const QAScenarioLoaderRef = preload("res://src/core/qa/QAScenarioLoader.gd")
const DialogStylesRef = preload("res://src/ui/components/common/DialogStyles.gd")
# UIColors is a class_name (src/ui/components/base/UIColors.gd) — referenced directly.

signal scenario_applied(id: String, receipt: Dictionary)

var _campaign: Variant = null
var _scenarios: Array = []
var _list: ItemList = null
var _detail: RichTextLabel = null
var _apply_button: Button = null
## False when the loaded campaign is not a 5PFH core — see
## campaign_supports_scenarios(). The fixtures load either way, so an empty
## list in the wrong mode stays distinguishable from a missing data/ folder.
var _scenarios_supported: bool = true

## Rolls the seam can force, with the row each one is needed for.
##
## `key` is matched case-insensitively as a SUBSTRING of the live roll context,
## which is why "Character Event" reaches a roll made as
## "Character Event: <crew name>".
##
## `target` is the value that reaches the row QA is actually chasing, so the
## tester does not have to look the table up on the device.
const FORCEABLE_ROLLS: Array[Dictionary] = [
	{"key": "Rival Attack Type", "sides": 10, "target": 1,
		"note": "T9-48 - 1 = AMBUSH, the only battle that forbids Seize (p.91)"},
	{"key": "Exploration Table", "sides": 100, "target": 51,
		"note": "T9-47 - 51-53 \"I don't have a gambling problem!\" (discard 1 item)"},
	{"key": "Trade Table", "sides": 100, "target": 76,
		"note": "T9-47 - 76-78 \"A chance to unload some stuff\" (sell at 2cr)"},
	{"key": "Character Event", "sides": 100, "target": 88,
		"note": "T9-51 - 88-91 item damaged, 92-94 item lost (pp.128-130)"},
	# T11-19b. The CAMPAIGN event is a different roll from the CHARACTER event
	# above and lives on a different step (p.125 step 12 vs step 13); it was the
	# one the seam did not reach, which is why T11-25 and T11-35 could not be
	# walked. 21-23 is Old Nemesis, 89-91 is Got Noticed. Neither key is a
	# substring of the other, so the two cannot consume each other's queue.
	{"key": "Campaign Event", "sides": 100, "target": 21,
		"note": "T11-25 - 21-23 Old Nemesis; T11-35 - 89-91 Got Noticed (needs an active Quest)"},
	{"key": "Mission Objective", "sides": 10, "target": 1, "note": "p.89 objective"},
	{"key": "Danger Pay", "sides": 10, "target": 1, "note": "p.83"},
	{"key": "Battlefield Find", "sides": 100, "target": 1, "note": "pp.120-121"},
	{"key": "Loot Category", "sides": 100, "target": 1, "note": "pp.131-134"},
	{"key": "Notable Sight", "sides": 100, "target": 1, "note": "p.88"},
	# --- Bug Hunt (Compendium). Every key below has a LIVE producer in src/
	# today, and that is the standing rule for this block: a row whose key
	# matches no roll is worse than a missing row, because the tester queues a
	# value, nothing consumes it, and they conclude the rule is broken when it
	# never ran. The post-battle rows were held back for exactly that reason
	# and landed with BugHuntPostBattleResolver (Sprint 1 Phase 5).
	#
	# No collision with the 5PFH keys above — every Bug Hunt key begins
	# "Bug Hunt", which no 5PFH context contains, and no 5PFH
	# key is a substring of a Bug Hunt context. Within this block no key is a
	# prefix of another, which matters because _take_forced returns on the
	# FIRST queued key that matches, in insertion order (DiceManager.gd:104).
	#
	# Where a PAIR decides a threshold, both dice are offered: _forced_results
	# is key -> FIFO, so several keys can be armed at once.
	{"key": "Bug Hunt Enlistment: die 1", "sides": 6, "target": 6,
		"note": "p.212 - 2D6 + Combat Skill >= 7; queue die 2 to pin the total"},
	{"key": "Bug Hunt Enlistment: die 2", "sides": 6, "target": 1,
		"note": "p.212 - 6+1 lands exactly ON the boundary; 1+1 forces a refusal"},
	{"key": "Bug Hunt Special Assignment die 1", "sides": 6, "target": 6,
		"note": "p.183 - 2D6 vs the assignment's own target (Marksman training 9+)"},
	{"key": "Bug Hunt Special Assignment die 2", "sides": 6, "target": 6,
		"note": "p.183 - 12 clears every row, incl. Officer training course 11+"},
	{"key": "Bug Hunt Support die 1", "sides": 6, "target": 6,
		"note": "pp.188-189 - 2D6 vs the option's target (Fire team 7+)"},
	{"key": "Bug Hunt Support die 2", "sides": 6, "target": 6,
		"note": "pp.188-189 - 12 clears every support option"},
	{"key": "Bug Hunt Priority: die 1", "sides": 6, "target": 1,
		"note": "p.187 - Priority is the LOWER of 2D6, so one 1 pins it at 1"},
	{"key": "Bug Hunt Priority: die 2", "sides": 6, "target": 6,
		"note": "p.187 - queue BOTH as 6 to force the maximum Priority"},
	{"key": "Bug Hunt Objective: type", "sides": 6, "target": 6,
		"note": "p.185 - objective types are matched on the d6 value"},
	{"key": "Bug Hunt Signals: count", "sides": 6, "target": 6,
		"note": "p.208 - optional rule; 6 clears the 4+ threshold"},
	{"key": "Bug Hunt Tactical Location: type", "sides": 6, "target": 6,
		"note": "p.191 - 1 Distract, 2-3 Block, 4-5 Neutralize, 6 Delay"},
	{"key": "Bug Hunt Commendation: die 1", "sides": 6, "target": 6,
		"note": "p.172 - each 6 of the 2D6 is +1 XP and +1 Reputation"},
	# Not a threshold pair - each 6 scores on its own - so this is not covered
	# by the "both dice when a pair decides a threshold" rule above. It is here
	# because without it the commendation cannot be made DETERMINISTIC: die 2
	# stays free and the character walks away with 1 or 2 XP at random.
	{"key": "Bug Hunt Commendation: die 2", "sides": 6, "target": 1,
		"note": "p.172 - queue 6/1 for exactly one commendation, 6/6 for two"},
	{"key": "Bug Hunt Origin", "sides": 100, "target": 1,
		"note": "p.171 - 01-09 Core systems world (+1 Reputation)"},
	{"key": "Bug Hunt Basic Training", "sides": 100, "target": 1,
		"note": "p.171 - 01-15 Ground forces (Infantry): +1 Combat, +1 Toughness"},
	{"key": "Bug Hunt Service History", "sides": 100, "target": 26,
		"note": "p.172 - 26-40 fringe-space patrol*, a Combat Operation, so the "
			+ "commendation 2D6 is reachable (01-10 is not starred)"},
	# --- Bug Hunt post-battle (BugHuntPostBattleResolver, Compendium pp.201-206).
	#
	# The resolver deliberately renames every SUB-roll so that no context
	# contains another row's key. The character pick under Military Life used
	# to read "Bug Hunt Military Life: character" and ran BEFORE the row roll,
	# so a value queued for the table was eaten by the pick and the row stayed
	# random - the seam would have looked broken while working exactly as
	# documented. Sub-rolls are "Bug Hunt Subject Pick", "Bug Hunt Recovery
	# Time" and "Bug Hunt Brawl"; keep it that way when adding a table.
	#
	# The one context that DOES still contain a parent key is intentional:
	# "Bug Hunt Military Life (extra roll 2)" inherits the Military Life queue,
	# FIFO, so a tester can pin several rolls in order with one key.
	{"key": "Bug Hunt Court Martial", "sides": 6, "target": 1,
		"note": "p.201 - only rolled on 0 weighted objectives; 1 removes the leader"},
	{"key": "Bug Hunt Casualty", "sides": 100, "target": 1,
		"note": "p.202 - 01-05 Gruesome fate: dead, all carried equipment lost"},
	{"key": "Bug Hunt Recovery Time", "sides": 6, "target": 6,
		"note": "p.202 - the Sick Bay column; a 1D3 is rolled as ceil(1D6/2), so 6 = 3"},
	{"key": "Bug Hunt Muster Out", "min": 2, "sides": 12, "target": 12,
		"note": "p.203 - 2D6 vs the row's target (9 at 8-9 missions, 5 at 14); "
			+ "12 musters on every row"},
	{"key": "Bug Hunt Reputation", "sides": 6, "target": 5,
		"note": "p.203 - 1D6 per completed objective, 5-6 = +1 Reputation"},
	{"key": "Bug Hunt Operational Progress", "sides": 100, "target": 100,
		"note": "p.205 - with a positive modifier this rolls over 100 into the "
			+ "Parade row, the only way a Bug Hunt campaign is WON"},
	{"key": "Bug Hunt Military Life", "sides": 100, "target": 16,
		"note": "p.206 - 16-20 Time in the Brig: -1 Reputation and miss the next mission"},
	{"key": "Bug Hunt Brawl", "sides": 6, "target": 1,
		"note": "p.206 - the 01-05 Got in a fight check; a 1 fails it into Sick Bay"},
	{"key": "Bug Hunt Subject Pick", "sides": 100, "target": 1,
		"note": "pp.205-206 - WHICH character a per-character table lands on; "
			+ "not rolled at all when only one candidate is eligible"},
	# --- Tactics (TacticsOperationalTurn, TacticsPostBattlePanel, TacticsCampaignCore).
	# Every key begins "Tactics", which no 5PFH or Bug Hunt context contains, and no
	# key here is a substring of another Tactics context. A zone or region CHOICE is
	# rolled on D6s too (TacticsOperationalTurn._pick re-rolls faces above the count),
	# so a 1 always picks the first candidate. A pool rolls one D6 per die under the
	# same key, in order: your dice first, then the enemy's.
	{"key": "Tactics Opening Initiative", "sides": 6, "target": 6,
		"note": "p.94 - who attacks first when the war opens"},
	{"key": "Tactics Opening Focus", "sides": 6, "target": 1,
		"note": "p.94 - which opening Zone becomes the Operational Focus"},
	{"key": "Tactics Operational Combat", "sides": 6, "target": 6,
		"note": "p.97 - Combat Dice, highest die wins; your pool rolls first"},
	{"key": "Tactics Operational Orders", "sides": 6, "target": 1,
		"note": "p.98 - 1D6 per faction on the Operational Orders table"},
	{"key": "Tactics Order Target", "sides": 6, "target": 1,
		"note": "p.98 - which Zone an order lands on"},
	{"key": "Tactics Attack Target", "sides": 6, "target": 1,
		"note": "p.98 - which adjacent region an Attack order strikes"},
	{"key": "Tactics Commando Raid", "sides": 6, "target": 6,
		"note": "p.99 - a 6 costs the target 1 Army Strength; any 1-2 loses the PBP"},
	{"key": "Tactics Army Strength", "sides": 6, "target": 6,
		"note": "p.95 - a new Zone's Army Strength (2D6 keep the highest when connected)"},
	{"key": "Tactics New Focus", "sides": 6, "target": 1,
		"note": "p.99 Step 7 - which Zone becomes the new Focus"},
	{"key": "Tactics Weakest Army", "sides": 6, "target": 1,
		"note": "p.99 Step 6 - the tie-break among equally weak armies"},
	{"key": "Tactics Unit Losses", "sides": 6, "target": 1,
		"note": "p.106 - a completely destroyed unit's loss roll"},
	{"key": "Tactics Story Event", "sides": 100, "target": 93,
		"note": "pp.102-104 - 93-96 New Front Opens (an Operational effect)"},
	{"key": "Tactics Campaign Points", "sides": 6, "target": 6,
		"note": "pp.106-107 - 3D6 drop the lowest; queue all three to pin the award"},
	# --- Planetfall (PlanetfallColonyCrisis, PlanetfallAutoResolveDialog). Every key
	# begins "Planetfall" and none is a substring of another Planetfall context; the
	# generic resolver contexts are "Planetfall D100/D6/2D6/D3", which none of these
	# contain. Morale rows need Morale at -10 or worse after Step 11's adjustments.
	{"key": "Planetfall Enemy Activity", "sides": 100, "target": 91,
		"note": "p.62 - 91-00 Raid: Colony Damage = sectors occupied + 1"},
	{"key": "Planetfall Colony Event", "sides": 100, "target": 6,
		"note": "p.63 - 06-10 Catastrophic malfunction: 1 Colony Damage that cannot be mitigated"},
	{"key": "Planetfall Colony Defenses", "sides": 6, "target": 1,
		"note": "p.62 - one D6 per Colony Defense point; 4+ negates 1 raid damage"},
	{"key": "Planetfall Morale Incident", "sides": 100, "target": 76,
		"note": "p.90 - 76-00 Political strife (a Crisis check); 26-35 Sabotage"},
	{"key": "Planetfall Crisis Check", "min": 2, "sides": 12, "target": 2,
		"note": "p.89 - at or below Political Upheaval enters a Crisis"},
	{"key": "Planetfall Crisis Outcome", "min": 2, "sides": 12, "target": 2,
		"note": "p.90 - 2-3 High tensions (a second check can end the campaign)"},
	{"key": "Planetfall Integrity Failure", "min": 3, "sides": 18, "target": 3,
		"note": "pp.87-88 - 3D6 at Integrity -3 or worse; 18 slays a character"},
	{"key": "Planetfall Sabotage", "sides": 6, "target": 6,
		"note": "p.90 - the 1D6 Colony Damage of Sabotage (cannot be mitigated)"},
	{"key": "Planetfall Colonist Demands", "sides": 6, "target": 6,
		"note": "p.90 - 1D6+Savvy per supervisor; 5+ satisfies the demands"},
	{"key": "Planetfall Psionic Cohesion", "sides": 6, "target": 5,
		"note": "p.105 - 5-6 keeps a Loyalty level that would be lost"},
	{"key": "Planetfall Injury", "sides": 100, "target": 1,
		"note": "p.66 - Step 9 or an Integrity Failure injury roll; 01-20 Dead"},
	{"key": "Planetfall Grunt Casualty", "sides": 6, "target": 1,
		"note": "p.66 - one grunt casualty; 1-2 lost to the colony"},
	{"key": "Planetfall Post-Mission Find", "sides": 100, "target": 61,
		"note": "p.134 - 61-70 Hints of planetary history (+1 RP with a scientist)"},
	{"key": "Planetfall Summit", "sides": 6, "target": 3,
		"note": "p.160 - one Summit vote per character, then the population; 3 Loyalty"},
	{"key": "Planetfall Unity Response", "sides": 6, "target": 6,
		"note": "p.161 - Independence, two dice; queue 6 then 6 for Recognized status"},
	{"key": "Planetfall War Colony", "sides": 6, "target": 6,
		"note": "p.161 - War round, the colony's die (the lower side takes War Fatigue)"},
	{"key": "Planetfall Ascension", "sides": 6, "target": 1,
		"note": "p.162 - one die per character; 1 perishes, 5-6 earn ascension energy"},
	{"key": "Planetfall Nomad Struggles", "sides": 6, "target": 6,
		"note": "p.163 - Isolation, two dice; 8-12 is 1 Wisdom, 3 Wisdom founds the tribe"},
	{"key": "Planetfall Step 17 Event", "sides": 100, "target": 1,
		"note": "pp.70-71 - Step 17, plus 2 after the 1st Milestone (p.156 misprints p.170)"},
	{"key": "Planetfall Evolution Slot", "sides": 10, "target": 1,
		"note": "p.158 - which of the 10 encounter entries a Milestone evolves"},
	{"key": "Planetfall Lifeform Evolution", "sides": 100, "target": 41,
		"note": "pp.159-160 - 41-50 Dramatic transformations; a duplicate rerolls"},
	{"key": "Planetfall Calamity Check", "sides": 6, "target": 1,
		"note": "p.165 - at or below the Calamity Points, a Calamity strikes"},
	{"key": "Planetfall Calamity Table", "sides": 100, "target": 1,
		"note": "p.165 - 01-11 Swarm Infestation"},
	{"key": "Planetfall Mission Data", "sides": 6, "target": 1,
		"note": "p.169 - at or below the Mission Data held, a Breakthrough"},
	{"key": "Planetfall Final Breakthrough", "sides": 100, "target": 1,
		"note": "p.169 - the Fourth Breakthrough's D100"},
	{"key": "Planetfall Condition Slot", "sides": 100, "target": 1,
		"note": "p.110 - which of the 10 Campaign Condition entries a mission draws; 01-15 is entry 1"},
	{"key": "Planetfall Battlefield Condition", "sides": 100, "target": 1,
		"note": "pp.110-113 - Master Condition table for a blank entry or a p.157 replacement; 01-08 Visibility limits"},
	{"key": "Planetfall Condition Detail", "sides": 100, "target": 1,
		"note": "pp.110-113 - a condition's secondary roll"},
	{"key": "Planetfall Replacement Roll", "min": 2, "sides": 12, "target": 9,
		"note": "p.69 Step 13 - 2-6 none, 7-8 a random class, 9-12 your choice"},
	{"key": "Planetfall Replacement Class", "sides": 6, "target": 5,
		"note": "p.69 - 1-2 trooper, 3-4 scientist, 5-6 scout"},
	{"key": "Planetfall R&R Return", "sides": 6, "target": 1,
		"note": "p.70 R&R, Disloyal - 1-2 they do not return, 6 Committed"},
	{"key": "Planetfall Friendship", "sides": 6, "target": 5,
		"note": "p.71 Making friends - 5+ a level of Loyalty (one die each)"},
	{"key": "Planetfall Supply Ship", "sides": 6, "target": 6,
		"note": "p.64 Supply ship - two dice, the priority takes the higher"},
	{"key": "Planetfall Report XP", "sides": 6, "target": 6,
		"note": "p.64 Report on progress - the XP the picked character earns"},
	{"key": "Planetfall Virus Infection", "sides": 6, "target": 1,
		"note": "p.64 Hostile virus - a natural 1 is infected (one die each)"},
	{"key": "Planetfall Virus Recovery", "sides": 3, "target": 3,
		"note": "p.64 Hostile virus - 1D3 turns in Sick Bay per victim"},
	{"key": "Planetfall Erase Lifeform", "sides": 10, "target": 1,
		"note": "p.64 Animal migrations - D10 picks the entry to erase"},
	{"key": "Planetfall Erase Condition", "sides": 10, "target": 1,
		"note": "p.64 Changing climate - D10 picks the entry to erase"},
	{"key": "Planetfall Slyn Aggression", "min": 2, "sides": 12, "target": 3,
		"note": "pp.117/121/125 after deploying - 2-4 (Scout Down! 2-3) the Slyn attack"},
	{"key": "Planetfall Slyn Encounter Size", "sides": 6, "target": 5,
		"note": "p.153 - 1-4: 6 Slyn in 3 pairs, 5-6: 8 in 4 pairs"},
	{"key": "Planetfall Contact Reveal", "sides": 6, "target": 6,
		"note": "p.42 - 1-2 false alarm, 3 two new Contacts, 4-5 one Lifeform, 6 two"},
	{"key": "Planetfall Lifeform Encounter", "sides": 100, "target": 1,
		"note": "p.146 - the first hostile reveal picks the mission's creature"},
	{"key": "Planetfall Tougher Specimens", "sides": 6, "target": 5,
		"note": "p.160 Tougher Specimens - 5-6: +1 KP"},
	{"key": "Planetfall Tactical Enemy Type", "sides": 100, "target": 88,
		"note": "p.149 - 88-95 K'Erin landing party"},
	{"key": "Planetfall Enemy Number D3", "sides": 3, "target": 3,
		"note": "p.149 Number - each D3 of a 2D3+3 or 1D3+N formula"},
	{"key": "Planetfall Enemy Number D6", "sides": 6, "target": 6,
		"note": "p.149 Number - the D6 of a 1D6+3 formula"},
	{"key": "Planetfall Enemy Grunt Weapons", "sides": 6, "target": 1,
		"note": "p.151 - 1 scrap gun ... 4-6 military rifle"},
	{"key": "Planetfall Enemy Specialist Weapons", "sides": 6, "target": 5,
		"note": "p.151 - 5-6 rattle gun"},
	{"key": "Planetfall Enemy Leader Weapons", "sides": 6, "target": 1,
		"note": "p.151 - 1 shatter axe"},
	{"key": "Planetfall Lifeform Mobility", "sides": 100, "target": 100,
		"note": "p.146 Step 1 Mobility"},
	{"key": "Planetfall Lifeform Combat Skill", "sides": 100, "target": 100,
		"note": "p.147 Step 2a Combat Skill"},
	{"key": "Planetfall Lifeform Strike Power", "sides": 100, "target": 100,
		"note": "p.147 Step 2b Strike Power"},
	{"key": "Planetfall Lifeform Special Attack", "sides": 100, "target": 1,
		"note": "p.147 Step 2c - rolled when 2a/2b end in 0 or 5"},
	{"key": "Planetfall Lifeform Defense", "sides": 100, "target": 100,
		"note": "p.147 Step 3 Defensive Abilities"},
	{"key": "Planetfall Lifeform Unique Ability", "sides": 100, "target": 1,
		"note": "p.148 Step 4 Unique Ability"},
]

var _roll_picker: OptionButton = null
var _roll_value: SpinBox = null
var _roll_status: Label = null


## Is `campaign` a core the 5PFH fixtures can safely be applied to?
##
## Guard on the OWNER, not on a mode flag (T11-49). The discriminator is
## `crew_data`, measured across the four cores: FiveParsecs 24 occurrences,
## BugHunt / Planetfall / Tactics 0 each.
##
## ⚠ This is not belt-and-braces. QAScenarioLoader.apply() reaches
## _apply_counters() (QAScenarioLoader.gd:105) with NO campaign argument; it
## routes through GameStateManager, whose setters write to
## GameState.current_campaign (GameStateManager.gd:111-123) and not to the
## campaign this dialog was handed. GameState._try_auto_load_last_campaign()
## loads a campaign at every launch, so in a Bug Hunt session that target is
## the player's 5PFH save: applying a fixture would move credits, supplies,
## story points and reputation in a campaign that is not even on screen, with
## nothing visible happening on either. A silent cross-campaign write is worse
## than a crash, so this refuses rather than best-efforts.
static func campaign_supports_scenarios(campaign: Variant) -> bool:
	if campaign is Dictionary:
		return campaign.has("crew_data")
	if campaign is Object:
		return "crew_data" in campaign
	return false


## The detail-pane text for a campaign the fixtures cannot be applied to.
##
## Static so a case can assert the wording names the MODE problem without
## building the dialog.
static func unsupported_campaign_text() -> String:
	return ("[color=#ff9a52]The QA fixtures are 5PFH-only.[/color]\n\n"
		+ "Every file in res://data/qa_scenarios/ is a delta against a "
		+ "[code]crew_data[/code] campaign, and applying one writes through "
		+ "GameStateManager to whichever campaign GameState currently holds — "
		+ "which in this mode is not the one on screen.\n\n"
		+ "Forcing a roll below is safe in every mode, and is what this "
		+ "dialog is for here.")


## Open over `parent` against `campaign`. Returns null (and does nothing) when no
## campaign is loaded — a scenario is a DELTA, so there must be something to
## apply it to.
static func open(parent: Node, campaign: Variant) -> Window:
	if parent == null or campaign == null:
		push_warning("QAScenarioDialog: no campaign loaded — nothing to apply to.")
		return null
	# Bare `new()` here is correct and verified (test_dialog_script_and_its_static_factory
	# _actually_load, isolated Aug 8 2026). The documented Godot 4.6 trap is
	# `ClassName.new()` inside a static func, which needs a `class_name` identifier to
	# resolve and fails with "Identifier not found"; this script has no class_name and
	# refers to itself implicitly, so it is fine. If you ever add a `class_name` here,
	# do NOT switch to `ClassName.new()` — use `load(<path>).new()`.
	var dlg := new()
	dlg.set_campaign(campaign)
	parent.add_child(dlg)
	# Ratio, never a fixed size. The first version used popup_centered() against a
	# hard-coded 900x620 and was verified on desktop at the tablet's PORTRAIT
	# geometry (800x1280): the scenario list was clipped off the left edge and the
	# Apply button off the right, so the dialog's only two controls were both
	# unreachable. popup_centered_ratio() sizes against the parent viewport, so it
	# is correct in portrait and landscape and on any device.
	dlg.popup_centered_ratio(0.92)
	return dlg


## Set before the dialog enters the tree. A public setter rather than a direct
## field poke from open(): _ready() reads it, so the assignment must happen first.
func set_campaign(campaign: Variant) -> void:
	_campaign = campaign


func _init() -> void:
	title = "QA Scenarios (debug build)"
	# No fixed size here — open() calls popup_centered_ratio(), which sizes against
	# the parent viewport. A Vector2i set at _init() would fight it and, worse, is
	# what clipped both controls off-screen in portrait.
	unresizable = false
	close_requested.connect(queue_free)


func _ready() -> void:
	# Load the fixtures either way. An empty list because the campaign is the
	# wrong mode and an empty list because the export filter dropped
	# data/qa_scenarios/ are different faults, so they must stay tellable apart.
	_scenarios = QAScenarioLoaderRef.load_all()
	_scenarios_supported = campaign_supports_scenarios(_campaign)
	_build_ui()
	if _scenarios_supported and not _scenarios.is_empty():
		_list.select(0)
		_on_selected(0)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UIColors.SPACING_MD)
	add_child(margin)

	# T11-15 - a ScrollContainer between the margin and the content, so soft-keyboard
	# avoidance has something to move.
	#
	# KeyboardAvoidance has two strategies. The good one appends headroom to a
	# ScrollContainer and scrolls the focused field clear; the fallback MOVES THE
	# WINDOW, and that one has a hard ceiling - a window cannot go above the top of
	# the screen, so it can only surrender the gap it already sits below it.
	# Measured on the tablet: this dialog asked for 511.3px of avoidance and had 64px
	# to give, leaving the field under the keyboard. This dialog had no
	# ScrollContainer at all, which is the ONLY reason it took the fallback.
	#
	# horizontal_scroll_mode DISABLED: a form must not scroll sideways, and a
	# disabled axis propagates its child's minimum rather than absorbing it, which is
	# what keeps the dialog's own width honest.
	var _kb_scroll := ScrollContainer.new()
	_kb_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_kb_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kb_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_kb_scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", UIColors.SPACING_SM)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# T11-39. size_flags_VERTICAL is load-bearing and was missing, which disabled
	# the whole scenario feature on deploy #21: the dialog opened with the forced-roll
	# row and ~900px of empty space where the list and detail pane belong.
	#
	# Godot 4.6, gui_containers.html: a ScrollContainer "accepts a single child node
	# and adds scrollbars if the child node's size exceeds the container's
	# dimensions. BOTH VERTICAL AND HORIZONTAL SIZE OPTIONS ARE RESPECTED." With only
	# the horizontal flag set, the scroll sized this VBox to its MINIMUM height, so
	# `split` below could claim no leftover space no matter what its own flags said -
	# and _list carried custom_minimum_size.y = 0, so the collapse went all the way to
	# nothing rather than merely looking cramped.
	#
	# This regression arrived with the T11-15 ScrollContainer wrapper. That fix was
	# detection-proven and desk-green; what no test asserted was that the list was
	# still VISIBLE afterwards. A fix can solve its own finding and break its
	# neighbour - test_qa_scenario_dialog_shows_its_list now pins it.
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kb_scroll.add_child(root)

	var blurb := Label.new()
	blurb.text = ("Applies a state DELTA to the loaded campaign through the normal owner "
		+ "setters, then hands back. It does not jump the phase — enter the turn normally.")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# COLOR_TEXT_MUTED, not TEXT_MUTED. UIColors' short-alias block defines only
	# TEXT_PRIMARY / TEXT_SECONDARY / TEXT_DISABLED, and referencing a member that
	# does not exist is a PARSE error — which fails the whole script at load and
	# takes every file that preloads it down too. That is what blanked the Campaign
	# Dashboard on device: process alive, logcat clean, nothing on screen.
	blurb.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	root.add_child(blurb)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", UIColors.SPACING_SM)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	_list = ItemList.new()
	# T11-39: a real minimum HEIGHT, not just width. The 0 here is what turned a
	# missing size flag into an invisible feature rather than a cramped one - inside
	# a ScrollContainer nothing else establishes a floor. 240 shows ~4 scenarios (all
	# four fixtures fit) and still leaves room on a phone in portrait.
	_list.custom_minimum_size = Vector2(280, 240)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(_on_selected)
	split.add_child(_list)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = false
	_detail.scroll_active = true
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(_detail)

	if _scenarios_supported:
		for s in _scenarios:
			_list.add_item(str(s.get("name", s.get("id", "?"))))

	# Three states, and they need different fixes: wrong mode, a data/ folder
	# the export filter dropped, or a real list. Never collapse the first two.
	if not _scenarios_supported:
		_detail.text = unsupported_campaign_text()
	elif _scenarios.is_empty():
		_detail.text = ("[color=#ff9a52]No fixtures found in res://data/qa_scenarios/."
			+ "[/color]\n\nThis usually means the export filter dropped the folder — "
			+ "verify by unzipping the APK, not by trusting the build log.")

	_build_forced_roll_section(root)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", UIColors.SPACING_SM)
	root.add_child(buttons)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStylesRef.style_secondary_button(close_btn)
	close_btn.pressed.connect(queue_free)
	buttons.add_child(close_btn)

	_apply_button = Button.new()
	_apply_button.text = "Apply Scenario"
	_apply_button.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	_apply_button.disabled = _scenarios.is_empty() or not _scenarios_supported
	DialogStylesRef.style_primary_button(_apply_button)
	_apply_button.pressed.connect(_on_apply_pressed)
	buttons.add_child(_apply_button)


## Force the next roll on a book table.
##
## WHY: three fixes have been stuck desk-verified since 2026-08-14 purely because
## no in-app tool can reach their row - Rival AMBUSH is a D10 of 1, and the two
## crew-task rows are 3-in-100 each (docs/qa/PICKUP_2026-08-14.md section 3).
## Widening the shipped roll_range was declined twice, because it means testing a
## build whose rules data differs from ship. This changes no data: the table is
## read exactly as shipped, only the die is pinned.
##
## This one does NOT route through QAScenarioLoader, and that is deliberate. The
## loader applies campaign-state DELTAS from JSON fixtures through owner setters;
## a queued die is neither campaign state nor a fixture, so putting it there would
## blur the one rule that keeps fixtures safe across a schema_version bump.
func _build_forced_roll_section(root: VBoxContainer) -> void:
	var sep := HSeparator.new()
	root.add_child(sep)

	var heading := Label.new()
	heading.text = "Force the next roll (debug only)"
	root.add_child(heading)

	# HFlowContainer, not HBox: this dialog is used on the tablet in PORTRAIT, and
	# a fixed row of four controls is exactly what put the original Apply button
	# off-screen. Flow wraps instead of clipping.
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", UIColors.SPACING_SM)
	row.add_theme_constant_override("v_separation", UIColors.SPACING_SM)
	root.add_child(row)

	_roll_picker = OptionButton.new()
	_roll_picker.custom_minimum_size = Vector2(260, UIColors.TOUCH_TARGET_MIN)
	# add_item() WITHOUT an explicit id: passing -1 stores the INDEX as the id,
	# which silently collides once the list is ever reordered. Selection is read
	# back as an index into FORCEABLE_ROLLS instead.
	for entry: Dictionary in FORCEABLE_ROLLS:
		_roll_picker.add_item("%s (%s)" % [str(entry["key"]), die_label(entry)])
	_roll_picker.item_selected.connect(_on_roll_context_selected)
	row.add_child(_roll_picker)

	_roll_value = SpinBox.new()
	_roll_value.min_value = 1
	_roll_value.max_value = 10
	_roll_value.step = 1
	_roll_value.custom_minimum_size = Vector2(110, UIColors.TOUCH_TARGET_MIN)
	row.add_child(_roll_value)

	var queue_btn := Button.new()
	queue_btn.text = "Queue Roll"
	queue_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStylesRef.style_secondary_button(queue_btn)
	queue_btn.pressed.connect(_on_queue_roll_pressed)
	row.add_child(queue_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)
	DialogStylesRef.style_secondary_button(clear_btn)
	clear_btn.pressed.connect(_on_clear_rolls_pressed)
	row.add_child(clear_btn)

	_roll_status = Label.new()
	_roll_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# COLOR_TEXT_MUTED, not TEXT_MUTED - see the blurb above for what that costs.
	_roll_status.add_theme_color_override("font_color", UIColors.COLOR_TEXT_MUTED)
	root.add_child(_roll_status)

	_roll_picker.select(0)
	_on_roll_context_selected(0)


## The lowest value this row's die can produce. Absent means 1, which is every
## D6 / D10 / D100 row. 2D6 is the one hook whose floor is 2, and offering a 1
## there would queue a value DiceManager._take_forced (:102-121) DISCARDS -- the
## tester would read "Queued 1" and then watch a random roll.
static func roll_min(entry: Dictionary) -> int:
	return int(entry.get("min", 1))


## "D100" / "2D6": the die as the book names it, derived from the range rather
## than stored, so a row cannot claim one die and force another.
static func die_label(entry: Dictionary) -> String:
	var lo: int = roll_min(entry)
	var hi: int = int(entry["sides"])
	if lo == 1:
		return "D%d" % hi
	if lo == 2 and hi == 12:
		return "2D6"
	return "%d-%d" % [lo, hi]


## The DiceManager autoload, or null. This dialog IS in the tree, so the plain
## lookup is safe here (unlike MissionTableManager, which is detached).
func _dice_manager() -> Node:
	return get_node_or_null("/root/DiceManager")


func _on_roll_context_selected(idx: int) -> void:
	if idx < 0 or idx >= FORCEABLE_ROLLS.size():
		return
	var entry: Dictionary = FORCEABLE_ROLLS[idx]
	_roll_value.max_value = int(entry["sides"])
	_roll_value.min_value = roll_min(entry)
	_roll_value.value = int(entry["target"])
	_refresh_roll_status(str(entry["note"]))


func _on_queue_roll_pressed() -> void:
	var idx: int = _roll_picker.get_selected()
	if idx < 0 or idx >= FORCEABLE_ROLLS.size():
		return
	var entry: Dictionary = FORCEABLE_ROLLS[idx]
	var dm: Node = _dice_manager()
	if dm == null or not dm.has_method("queue_forced_result"):
		_refresh_roll_status("DiceManager unavailable - nothing queued.")
		return
	# T11-43. A Godot SpinBox parses its LineEdit text into `.value` only on
	# focus-loss or submit, so a value TYPED and immediately followed by a button
	# press is read at its pre-edit value: the walk typed 89 and queued 21, the
	# figure the dropdown had auto-filled. apply() commits the pending text first.
	# ⚠ This matters more than a debug nit reads: the whole point of the seam is
	# to reach a table row that cannot otherwise be reached, so a silently wrong
	# value arms a completely different rule and the tester verifies the wrong one.
	if _roll_value.has_method("apply"):
		_roll_value.apply()
	var value: int = int(_roll_value.value)
	if not dm.queue_forced_result(str(entry["key"]), value):
		# The seam refuses in a release build. Say so rather than implying success.
		_refresh_roll_status("Refused - forced rolls are debug-build only.")
		return
	_refresh_roll_status("Queued %d for the next \"%s\" roll. %s" % [
		value, str(entry["key"]), str(entry["note"])])


func _on_clear_rolls_pressed() -> void:
	var dm: Node = _dice_manager()
	if dm != null and dm.has_method("clear_forced_results"):
		dm.clear_forced_results()
	_refresh_roll_status("Cleared.")


func _refresh_roll_status(message: String) -> void:
	if _roll_status == null:
		return
	var pending: String = ""
	var dm: Node = _dice_manager()
	if dm != null and dm.has_method("get_forced_results"):
		var queued: Dictionary = dm.get_forced_results()
		if not queued.is_empty():
			var parts: Array[String] = []
			for key: String in queued.keys():
				parts.append("%s=%s" % [key, str(queued[key])])
			pending = "  [pending: %s]" % ", ".join(parts)
	_roll_status.text = message + pending


func _on_selected(idx: int) -> void:
	if idx < 0 or idx >= _scenarios.size():
		return
	var s: Dictionary = _scenarios[idx]
	var parts: Array[String] = []
	parts.append("[b][font_size=20]%s[/font_size][/b]" % str(s.get("name", "")))
	parts.append(str(s.get("summary", "")))

	var unlocks: Array = s.get("unlocks", [])
	if not unlocks.is_empty():
		parts.append("\n[b]Unlocks[/b]")
		for u in unlocks:
			parts.append("  • %s" % str(u))

	var note := str(s.get("note", ""))
	if not note.is_empty():
		parts.append("\n[b]Note[/b]\n%s" % note)

	_detail.text = "\n".join(parts)


func _on_apply_pressed() -> void:
	# Defensive: the button is already disabled in this state. Kept because a
	# disabled button is a UI fact, not an invariant, and the cost of getting
	# this wrong is a silent write into a campaign that is not on screen.
	if not _scenarios_supported:
		push_warning("QAScenarioDialog: fixtures are 5PFH-only; refusing to apply.")
		return
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return
	var s: Dictionary = _scenarios[sel[0]]
	var receipt: Dictionary = QAScenarioLoaderRef.apply(s, _campaign)

	# Show what actually happened rather than a bare "done". A scenario that
	# silently skipped half its setup is worse than no scenario at all: the tester
	# believes they are in a state they are not, and then files findings against it.
	var applied: Array = receipt.get("applied", [])
	var warnings: Array = receipt.get("warnings", [])
	var lines: Array[String] = ["[b]%s applied[/b]\n" % str(s.get("name", ""))]
	if applied.is_empty():
		lines.append("[color=#ff9a52]Nothing was applied.[/color]")
	for a in applied:
		lines.append("[color=#6ee7a0]✓[/color] %s" % str(a))
	if not warnings.is_empty():
		lines.append("\n[b][color=#ff9a52]Warnings[/color][/b]")
		for w in warnings:
			lines.append("[color=#ff9a52]![/color] %s" % str(w))
	lines.append("\nClose this and use the dashboard normally — the campaign is now in "
		+ "that state. Save if you want it on disk.")
	_detail.text = "\n".join(lines)

	scenario_applied.emit(str(s.get("id", "")), receipt)
