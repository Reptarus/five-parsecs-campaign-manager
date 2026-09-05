extends WorldPhaseComponent
class_name CrewTaskComponent

## Crew Task Component - Single Responsibility
## Extracted from WorldPhaseUI monolith to handle Five Parsecs crew task rules only
## Implements Core Rules pp.76-82 - Crew task assignment and resolution

const RulesHelpText = preload("res://src/data/rules_help_text.gd")
const ItemChoicePopupScript = preload("res://src/ui/components/dialogs/ItemChoicePopup.gd")
const GrenadeCombinationPopupScript = preload("res://src/ui/components/dialogs/GrenadeCombinationPopup.gd")
const CrewTaskEventDialogScript = preload("res://src/ui/components/dialogs/CrewTaskEventDialog.gd")
## p.78 Train: "resolve that immediately" — the picker that makes it immediate.
const CharacterUpgradeDialogScript = preload(
	"res://src/ui/components/dialogs/CharacterUpgradeDialog.gd")
## Compendium p.112 "The Benefits of Loyalty" — the six Faction favors.
const FactionFavorServiceRef = preload("res://src/core/systems/FactionFavorService.gd")
const NARRATIVE_SCREEN_PATH := "res://src/ui/screens/narrative/NarrativeScreen.gd"

# Five Parsecs dependencies
const WorldPhaseResources = preload("res://src/core/world_phase/WorldPhaseResources.gd")
const DiceManager = preload("res://src/core/managers/DiceManager.gd")
## The pp.28-29 creation tables (Low-Tech Weapon / Gear / Gadget), which several
## Trade Table entries cite by page. One roller, shared with campaign creation.
const StartingEquipmentGeneratorClass = preload(
	"res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
## The p.131 Loot Table's third roll ("finally the exact item in question").
## Shared so the Trade Table's "Something interesting" (p.79 roll 45-48) rolls
## the same distribution the post-battle path does.
const LootTableResolverClass = preload("res://src/core/equipment/LootTableResolver.gd")
const OnboardItemServiceRef = preload("res://src/core/equipment/OnboardItemService.gd")
const WorldTraitEffectsClass = preload("res://src/core/world/WorldTraitEffects.gd")
const DepartureObligationClass = preload("res://src/core/world/DepartureObligation.gd")
const FringeWorldStrifeRef = preload("res://src/core/world/FringeWorldStrife.gd")
const CompendiumTogglesRef = preload("res://src/data/compendium_difficulty_toggles.gd")
const ExpandedQuestRef = preload("res://src/core/campaign/ExpandedQuestProgression.gd")
const AdvancementSystemRef = preload(
	"res://src/core/character/advancement/AdvancementSystem.gd")

## Compendium p.79 row 29-38: "A special Work on the Quest crew task becomes
## available. This has no effect other than to help complete this step." It is
## NOT a standing option and so is deliberately absent from crew_tasks.json —
## it exists only while that row is the Quest's pending step, and disappears the
## moment the sixth task is performed.
const QUEST_WORK_TASK := {
	"id": "work_on_the_quest",
	"name": "Work on the Quest",
	"description": "Compendium p.79: grind away at the current Quest step. "
		+ "No other effect. Six of these complete the step and earn 1 Quest Rumor.",
	"dice_target": 0,
	"max_crew": 6,
	"credit_bonus": 0,
	"success_reward": "Progress toward the current Quest step",
	"failure_penalty": "None",
	"resolution_type": "automatic",
}

# Design system constants


# UI Components
@onready var crew_task_container: VBoxContainer = %CrewTaskContainer
@onready var crew_member_list: ItemList = %CrewMemberList
@onready var available_tasks_list: ItemList = %AvailableTasksList
@onready var assign_task_button: Button = %AssignTaskButton
@onready var resolve_all_button: Button = %ResolveAllButton
@onready var progress_container: VBoxContainer = %ProgressContainer
@onready var help_button: Button = %HelpButton

# Crew task state
var crew_data: Array = []
var assigned_tasks: Dictionary = {} # crew_member_id -> task_data
var completed_tasks: Array = []
var all_tasks_resolved: bool = false

# Choice popup state — tracks pending item choices from task results
var _pending_choice_results: Array = [] # Queue of {result, item_string, options}
var _choice_popup: Window = null
var _auto_resolve_mode: bool = false

# Event queue — interactive dialog for each crew task result
var _event_queue: Array[Dictionary] = []
var _current_event_dialog: Window = null

# Five Parsecs crew tasks — loaded from data/crew_tasks.json (Core Rules pp.76-82)
var available_crew_tasks: Array[Dictionary] = []

func _load_crew_tasks() -> void:
	var path := "res://data/crew_tasks.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("CrewTaskComponent: Failed to open crew_tasks.json at %s" % path)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("CrewTaskComponent: Failed to parse crew_tasks.json: %s" % json.get_error_message())
		return
	var data: Dictionary = json.data
	var tasks: Array = data.get("tasks", [])
	available_crew_tasks.clear()
	for task: Dictionary in tasks:
		available_crew_tasks.append({
			"id": task.get("id", ""),
			"name": task.get("name", ""),
			"description": task.get("description", ""),
			"dice_target": int(task.get("dice_target", 0)),
			"max_crew": int(task.get("max_crew", 2)),
			"credit_bonus": int(task.get("credit_bonus_max", 0)),
			"success_reward": task.get("success_reward", ""),
			"failure_penalty": task.get("failure_penalty", "None"),
			"resolution_type": task.get("resolution_type", "dice_roll"),
			# Compendium p.112 "Call In a Favor": "requires a crew task, and can
			# ONLY BE DONE BY YOUR CAPTAIN", "once per campaign turn". Carried
			# through here rather than special-cased by id at the gate — a rule
			# keyed on a hardcoded string is one rename away from silently off.
			"captain_only": bool(task.get("captain_only", false)),
			"once_per_campaign_turn": bool(task.get("once_per_campaign_turn", false)),
			"dlc_flag": str(task.get("dlc_flag", "")),
		})

# Track crew per task for multi-assignment
var task_assignments: Dictionary = {} # task_id -> Array of crew_ids
var credits_spent_on_tasks: Dictionary = {} # task_id -> credits spent
## p.78 dice branch: "A score of 6 or higher allows A new recruit to be added" —
## one recruit for the whole attempt, not one per crew member sent.
var _group_recruit_resolved: bool = false
## p.77/p.78 credit-spend control, rebuilt with the task list.
var _credit_spend_row: HBoxContainer = null


func _ready() -> void:
	name = "CrewTaskComponent"
	_load_crew_tasks()
	super._ready()
	# Portrait: stack the crew + task panes vertically (r14).
	_register_responsive_box($CrewTaskContainer/AssignmentContainer)

func _subscribe_to_events() -> void:
	_subscribe(CampaignTurnEventBus.TurnEvent.PHASE_STARTED, _on_phase_started)
	_subscribe(CampaignTurnEventBus.TurnEvent.AUTOMATION_TOGGLED, _on_automation_toggled)

func _connect_ui_signals() -> void:
	## Connect UI signals
	if assign_task_button:
		assign_task_button.pressed.connect(_on_assign_task_pressed)
	if resolve_all_button:
		resolve_all_button.pressed.connect(_on_resolve_all_pressed)
	if crew_member_list:
		crew_member_list.item_selected.connect(_on_crew_member_selected)
		# Sprint 26.4: Ensure 48px minimum touch target for mobile
		crew_member_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	if available_tasks_list:
		available_tasks_list.item_selected.connect(_on_task_selected)
		# Sprint 26.4: Ensure 48px minimum touch target for mobile
		available_tasks_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	if help_button:
		help_button.pressed.connect(_on_help_button_pressed)

func _on_help_button_pressed() -> void:
	## Show crew tasks help dialog
	_show_help_dialog("Crew Tasks", RulesHelpText.get_tooltip("crew_tasks"))

func _setup_initial_state() -> void:
	## Initialize component state
	assigned_tasks.clear()
	completed_tasks.clear()
	all_tasks_resolved = false
	_populate_available_tasks()

## Public API: Initialize crew tasks phase
func initialize_crew_tasks(crew: Array) -> void:
	## Initialize crew tasks phase with current crew data
	crew_data = crew.duplicate()
	assigned_tasks.clear()
	completed_tasks.clear()
	all_tasks_resolved = false

	_populate_crew_list()
	_populate_available_tasks()
	_update_ui_state()
	# Clear the TASK RESULTS panel too. Clearing completed_tasks alone leaves the
	# previous turn's dynamically-built result labels on screen (progress_container
	# is only rebuilt by _update_progress_display, which shows nothing when empty),
	# so turn 2 showed turn 1's "Trade -> Luxury trinket" until the next resolve.
	_update_progress_display()
	
	# Publish phase started event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_STARTED, {
			"crew_size": crew_data.size()
		})

func _populate_crew_list() -> void:
	## Populate crew member list UI - excludes Sick Bay crew
	if not crew_member_list:
		return

	crew_member_list.clear()
	for i in range(crew_data.size()):
		var crew_member = crew_data[i]
		var crew_name = _member_get(crew_member, "character_name", "Crew Member %d" % (i + 1))

		# Sick Bay, p.76 upkeep lockout, and the pp.128-130 Character Event blocks.
		# This list previously checked Sick Bay ONLY, so crew who had refused to
		# work for lack of upkeep — and characters who had outright left — showed
		# up enabled and assignable.
		var block_reason: String = _task_block_reason(crew_member)
		if not block_reason.is_empty():
			crew_member_list.add_item("%s [%s]" % [crew_name, block_reason])
			crew_member_list.set_item_disabled(crew_member_list.item_count - 1, true)
			continue

		var task_status = ""
		var crew_id: String = crew_key(crew_member)  # see crew_key(): T9-40

		if crew_id in assigned_tasks:
			var assigned_task = assigned_tasks[crew_id]
			task_status = " [%s]" % assigned_task.task.name.to_upper()

		crew_member_list.add_item(crew_name + task_status)

func _task_block_reason(crew_member) -> String:
	## Why this crew member cannot take a task this turn, or "" if they can.
	##
	## THIS LOGIC USED TO BE UNREACHABLE. It lived in _get_eligible_crew(), which
	## had ZERO callers repo-wide, while the two LIVE paths — _populate_crew_list()
	## and _on_assign_task_pressed() — checked only Sick Bay. Two book rules were
	## therefore inert:
	##
	##   p.76 "For each credit you are short, one crew member will refuse to do
	##   any jobs for you this campaign turn." The player was shown a dialog
	##   naming the crew who refuse, and then those exact characters appeared
	##   enabled and could be assigned with full effect.
	##
	##   pp.128-130 Character Events writing skip_tasks / unavailable / departed —
	##   a character who has left the crew could still be sent to Trade.
	##
	## Returning a REASON rather than a bool so the list can tell the player why a
	## name is greyed out; a silent disable reads as a bug.
	var is_in_sick_bay = _member_get(crew_member, "in_sick_bay", false) \
		or _member_get(crew_member, "status", "") == "injured"
	# Time to Burn (Core Rules p.130): extra_action allows tasks even in Sick Bay.
	var has_extra_action := false
	for eff in _member_get(crew_member, "status_effects", []):
		if str(eff.get("type", "")) == "extra_action":
			has_extra_action = true
			break
	if is_in_sick_bay and not has_extra_action:
		return "SICK BAY"
	# Core Rules p.76, verbatim: "If this was their last campaign turn in Sick
	# Bay, they can rejoin the crew for battle, but CANNOT PERFORM A TASK this
	# campaign turn."
	#
	# So leaving Sick Bay is a two-step release, and only the first step had ever
	# been implemented: the countdown cleared in_sick_bay and the character walked
	# straight into Crew Tasks the same turn, worth one extra Explore/Trade/Patron
	# roll on every single recovery. `recovered_this_turn` is stamped by the turn
	# rollover when the last injury clears, and cleared at the START of the next
	# rollover so it lasts exactly one turn.
	#
	# Deliberately checked AFTER extra_action: p.130 "Time to Burn" lets a
	# character act even in Sick Bay, so it certainly covers one who has just left.
	if _member_get(crew_member, "recovered_this_turn", false) and not has_extra_action:
		return "JUST RECOVERED"
	# Upkeep lockout: crew refuses jobs if upkeep not fully paid (Core Rules p.76)
	if _member_get(crew_member, "locked_out_this_turn", false):
		return "REFUSING WORK"
	# Character Event restrictions (Core Rules pp.128-130)
	for eff in _member_get(crew_member, "status_effects", []):
		match str(eff.get("type", "")):
			"skip_tasks":
				return "UNAVAILABLE"
			"unavailable":
				return "UNAVAILABLE"
			"departed":
				return "DEPARTED"
	return ""


func _get_eligible_crew() -> Array:
	## Crew who may be assigned a task this turn.
	var eligible: Array = []
	for crew_member in crew_data:
		if _task_block_reason(crew_member).is_empty():
			eligible.append(crew_member)
	return eligible

## THE key for `assigned_tasks`. Every site that reads or writes that Dictionary
## must go through here.
##
## T9-40 (tablet, Aug 13 2026): three sites derived it three incompatible ways —
## `character_id` else `"crew_%d"` (assign, :214/:464), `id` else `character_id`
## (the stranded check), and `id` else `character_name` (deferred events). On a
## campaign created before `character_id` was serialised — the April save on the
## test tablet, and every alpha tester carrying one — assign keyed `"crew_0"`
## while the stranded check looked up `"2873092675"`, so EVERY crew member was
## always reported as having no task. That made the confirm dialog fire on every
## single resolve, which is what turned T9-39 from an edge case into a blocker.
##
## The positional fallback was the worse half: `_get_eligible_crew()` is a
## FILTERED subset of `crew_data`, so with one crew member in Sick Bay
## `crew_data[2]` and `eligible[2]` are different people and `"crew_2"` silently
## means two different characters depending on which list you came from. A key
## into a shared Dictionary must never depend on position.
##
## Order: character_id, then id, then a name-derived key so a member carrying
## neither is still assignable. The `name:` prefix keeps that last case from
## colliding with a real id.
static func crew_key(member) -> String:
	var cid: String = str(_member_get(member, "character_id", ""))
	if not cid.is_empty():
		return cid
	var mid: String = str(_member_get(member, "id", ""))
	if not mid.is_empty():
		return mid
	var nm: String = str(_member_get(member, "character_name",
		_member_get(member, "name", "")))
	return "name:%s" % nm if not nm.is_empty() else ""


## Largest a modal may be on this viewport, and the fix for T9-39.
##
## The resolve-tasks ConfirmationDialog was built with a bare autowrapping Label
## and `popup_centered()` with no size, so it sized to content: measured on the
## tablet at taller than the whole 1600px screen, with "Resolve anyway" and
## "Go back and assign" off the bottom edge. The World Phase could not be
## advanced at all by touch — the only way through was a hardware ENTER key,
## which a tablet does not have.
##
## Kept static and pure so it can be asserted without standing up a Window.
static func confirm_dialog_size(viewport: Vector2) -> Vector2i:
	# 0.8 leaves the dialog visibly inside the screen on every device tested;
	# the floors keep it usable if the viewport is reported as tiny.
	var w: float = maxf(280.0, viewport.x * 0.8)
	var h: float = maxf(200.0, viewport.y * 0.8)
	return Vector2i(int(w), int(h))


static func _member_get(member, key: String, default = null):
	## Type-safe crew-member field access. Crew members are canonically Dictionaries
	## (crew_data["members"]), but a stray Character Resource must never silently abort
	## this panel: Dictionary.get(key, default) is a 2-arg call, while Object.get(key)
	## takes a single arg, so the 2-arg form aborts the whole function on a Resource
	## (the new-campaign Crew Tasks soft-lock). This handles both shapes safely.
	if member is Dictionary:
		return member.get(key, default)
	if member is Object:
		if key in member:
			return member.get(key)
		return default
	return default

func _strife_blocked_tasks() -> Array:
	## Crew-task ids closed by an active Fringe World Strife effect on this world
	## (Compendium pp.149-150). Returns [] when the option is off, the world is
	## stable, or nothing is currently in force.
	var pdm = get_node_or_null("/root/PlanetDataManager")
	var gs = get_node_or_null("/root/GameState")
	if pdm == null or gs == null:
		return []
	var campaign = gs.get_current_campaign() if gs.has_method("get_current_campaign") else null
	if campaign == null:
		return []
	return FringeWorldStrifeRef.blocked_crew_tasks(campaign, str(pdm.current_planet_id))


## Add or remove the Compendium p.79 "Work on the Quest" task to match the
## Quest's current state. Re-evaluated on every repopulate rather than loaded
## once, because the row that creates it is rolled mid-campaign and the task must
## vanish the turn the sixth one is performed.
func _sync_quest_work_task() -> void:
	var gs = get_node_or_null("/root/GameState")
	var campaign = gs.get_current_campaign() if gs and gs.has_method(
		"get_current_campaign") else null
	var wanted: bool = ExpandedQuestRef.quest_task_available(campaign)
	var index: int = -1
	for i in range(available_crew_tasks.size()):
		if str(available_crew_tasks[i].get("id", "")) == QUEST_WORK_TASK["id"]:
			index = i
			break
	if wanted and index < 0:
		available_crew_tasks.append(QUEST_WORK_TASK.duplicate(true))
	elif not wanted and index >= 0:
		available_crew_tasks.remove_at(index)
		task_assignments.erase(QUEST_WORK_TASK["id"])


func _populate_available_tasks() -> void:
	## Populate available tasks list UI with Core Rules info
	if not available_tasks_list:
		return

	_sync_quest_work_task()
	var strife_blocked: Array = _strife_blocked_tasks()
	available_tasks_list.clear()
	for task in available_crew_tasks:
		# Compendium p.112: the favor task exists only where the crew has Loyalty
		# to spend, and only once per campaign turn. Listing it otherwise would
		# offer a task that can only ever report "nobody has time for you".
		if not _favor_task_offerable(task):
			continue
		var task_text = task.name
		var task_id = task.get("id", "")

		# Show resolution type
		match task.resolution_type:
			"dice_roll":
				task_text += " (%d+)" % task.dice_target
			"automatic":
				task_text += " (Auto)"
			"table_roll":
				task_text += " (Table)"
			"repair":
				task_text += " (Repair)"
			"faction_favor":
				task_text += " (Captain, D6 vs Loyalty %d)" % _best_faction_loyalty()

		# Show current crew count and full indicator
		var assigned_count = task_assignments.get(task_id, []).size()
		if assigned_count >= task.max_crew:
			task_text += " [FULL %d/%d]" % [assigned_count, task.max_crew]
		elif assigned_count > 0:
			task_text += " [%d/%d crew]" % [assigned_count, task.max_crew]

		# Credits already committed to this task (Core Rules p.77/p.78).
		var spent: int = int(credits_spent_on_tasks.get(task_id, 0))
		if spent > 0:
			task_text += " [+%d cr]" % spent

		if task_id in strife_blocked:
			task_text += "  [CLOSED — Strife]"

		available_tasks_list.add_item(task_text)

		# Tooltip with description
		available_tasks_list.set_item_tooltip(available_tasks_list.item_count - 1, task.description)
		if task_id in strife_blocked:
			available_tasks_list.set_item_disabled(available_tasks_list.item_count - 1, true)

	_build_credit_spend_row()


func _build_credit_spend_row() -> void:
	## p.77 Find a Patron: "After rolling, you may opt to spend credits. Each
	## credit earns a +1 bonus." p.78 says the same for Track and Repair Your Kit.
	##
	## THERE WAS NO WAY TO SPEND. spend_credits_on_task() had zero callers — no
	## control existed anywhere — so the book's main World Phase credit sink did
	## not exist and credits simply accumulated. (It would also have refused every
	## call and, if it had not, applied a -1 penalty; both fixed alongside this.)
	if available_tasks_list == null:
		return
	var parent: Node = available_tasks_list.get_parent()
	if parent == null:
		return

	if _credit_spend_row and is_instance_valid(_credit_spend_row):
		_credit_spend_row.queue_free()
	_credit_spend_row = HBoxContainer.new()
	_credit_spend_row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = "Spend credits for +1 each on the selected task:"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_credit_spend_row.add_child(label)

	var btn := Button.new()
	btn.text = "+1 cr"
	btn.accessibility_name = "Spend 1 credit for a +1 bonus on the selected task"
	btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	btn.pressed.connect(_on_spend_credit_pressed)
	_credit_spend_row.add_child(btn)

	parent.add_child(_credit_spend_row)
	parent.move_child(_credit_spend_row,
		mini(available_tasks_list.get_index() + 1, parent.get_child_count() - 1))


func _on_spend_credit_pressed() -> void:
	var selected: PackedInt32Array = available_tasks_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	if index >= available_crew_tasks.size():
		return
	var task_id: String = str(available_crew_tasks[index].get("id", ""))
	if task_id.is_empty():
		return
	if spend_credits_on_task(task_id, 1):
		_populate_available_tasks()
	else:
		var notif: Node = get_node_or_null("/root/NotificationManager")
		if notif and notif.has_method("show_warning"):
			notif.show_warning(
				"Cannot spend credits on that task (Core Rules pp.77-78).")

## Task Assignment
func _on_assign_task_pressed() -> void:
	## Handle task assignment button press with max_crew support
	var selected_crew = crew_member_list.get_selected_items()
	var selected_task = available_tasks_list.get_selected_items()

	if selected_crew.is_empty() or selected_task.is_empty():
		return

	var crew_index = selected_crew[0]
	var task_index = selected_task[0]

	if crew_index >= crew_data.size() or task_index >= available_crew_tasks.size():
		return

	var crew_member = crew_data[crew_index]
	var task = available_crew_tasks[task_index]
	var crew_id: String = crew_key(crew_member)  # see crew_key(): T9-40
	var task_id = task.get("id", "task_%d" % task_index)

	# Sick Bay (p.76), the upkeep lockout (p.76) and the Character Event blocks
	# (pp.128-130). Previously only Sick Bay was checked here, so a locked-out or
	# departed character could still be assigned by selecting them directly.
	var assign_block: String = _task_block_reason(crew_member)
	if not assign_block.is_empty():
		push_warning("CrewTaskComponent: %s cannot be assigned (%s)" % [
			crew_member.get("character_name", "Crew"), assign_block])
		return

	# Compendium p.112, verbatim: calling in a favor "requires a crew task, and
	# CAN ONLY BE DONE BY YOUR CAPTAIN". Refused at assignment as well as at
	# resolution — the resolver's check is the rule, this one is so the player
	# finds out before they have spent the assignment.
	if bool(task.get("captain_only", false)) \
			and not bool(_member_get(crew_member, "is_captain", false)):
		push_warning("CrewTaskComponent: %s is captain-only (Compendium p.112)"
			% task.get("name", task_id))
		return

	# Compendium pp.149-150 Fringe World Strife, the two rows that close crew
	# actions on this world:
	#   Hooligans: "You cannot perform any Explore or Trade crew actions during
	#               the next campaign turn."
	#   Economic Collapse: "For now, you cannot take Trade actions."
	if task_id in _strife_blocked_tasks():
		push_warning(
			"CrewTaskComponent: %s is unavailable — Fringe World Strife"
			% task.get("name", task_id))
		return

	# Mutant: cannot Recruit or Find a Patron (Core Rules p.21)
	# str() guard: legacy saves store crew "origin" as a numeric enum (e.g. 7.0) and
	# carry no "species_id", so the raw value can be a float — .to_lower() crashed.
	var crew_species: String = str(crew_member.get(
		"species_id", crew_member.get("origin", ""))).to_lower()
	if crew_species == "mutant" and task_id in [
		"recruit", "find_patron"]:
		var task_name: String = task.get("name", task_id)
		push_warning(
			"CrewTaskComponent: Mutant %s cannot perform %s"
			+ " (Core Rules p.21)"
			% [crew_member.get("character_name", "Crew"),
			task_name])
		return

	# Check if crew already assigned
	if crew_id in assigned_tasks:
		push_warning("CrewTaskComponent: %s already has a task assigned" % crew_member.get("character_name", "Crew"))
		return

	# Check max_crew limit
	if not task_id in task_assignments:
		task_assignments[task_id] = []

	# "Travel restricted — No more than one crew member may take the Explore
	# option each campaign turn" (Core Rules p.74 World Trait). A per-world cap
	# that overrides the task's own max_crew, and was flavour text.
	var effective_max: int = int(task.max_crew)
	if task_id == "explore":
		var explore_cap: int = WorldTraitEffectsClass.explore_task_cap(
			_current_world_traits())
		if explore_cap >= 0:
			effective_max = mini(effective_max, explore_cap)

	if task_assignments[task_id].size() >= effective_max:
		var task_name: String = task.get("name", task_id)
		push_warning("CrewTaskComponent: %s is full (%d/%d crew)" % [task_name, task_assignments[task_id].size(), effective_max])
		# Refresh task list to show updated capacity indicators
		_populate_available_tasks()
		return

	# Assign task
	assigned_tasks[crew_id] = {
		"crew_member": crew_member,
		"task": task,
		"task_id": task_id,
		"assigned_time": Time.get_unix_time_from_system(),
		"resolved": false
	}

	# Track in task_assignments for multi-crew
	task_assignments[task_id].append(crew_id)

	pass # Task assigned to crew member

	# Update UI
	_populate_crew_list()
	_populate_available_tasks()
	_update_ui_state()

	# Publish assignment event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_ASSIGNED, {
			"crew_id": crew_id,
			"crew_name": crew_member.get("character_name", "Unknown"),
			"task_name": task.name,
			"task_id": task_id,
			"crew_on_task": task_assignments[task_id].size()
		})

## Crew who COULD still take a task but have not been given one. Resolving now
## burns their turn: the step locks to "All Tasks Resolved" and Assign Task goes
## disabled, so there is no way back. Core Rules pp.77-78 give each crew member one
## task per turn, and the panel's own subtitle says so.
func _unassigned_eligible_crew() -> Array[String]:
	var names: Array[String] = []
	for crew_member in _get_eligible_crew():
		var crew_id: String = crew_key(crew_member)  # see crew_key(): T9-40
		if crew_id.is_empty() or crew_id in assigned_tasks:
			continue
		names.append(str(_member_get(crew_member, "name",
			_member_get(crew_member, "character_name", "Crew"))))
	return names


## Whether resolving now must ASK first. Pure decision seam, so the gate can be
## pinned without standing up the whole resolution pipeline (which touches credits,
## the event queue and the journal, and whose fixture requirements have nothing to
## do with the question being asked).
##
## NEVER prompt on an automated path. Both automated callers
## (_on_automation_toggled, complete_crew_task_phase) set _auto_resolve_mode, call
## the handler, and clear it on the NEXT LINE — so a dialog there would return
## immediately, the flag would be false again by the time the player answered, and
## the eventual resolution would silently run in interactive mode picking different
## outcomes. Force-completing a phase is also not a moment when a modal can be
## answered.
static func should_confirm_resolve_all(auto_mode: bool, stranded_count: int) -> bool:
	return not auto_mode and stranded_count > 0


## Task Resolution - Five Parsecs dice mechanics
func _on_resolve_all_pressed() -> void:
	## Resolve all assigned crew tasks using Five Parsecs rules
	if assigned_tasks.is_empty():
		return

	# W2-04: on device, three of six crew were still unassigned when the step
	# resolved, and it locked immediately — Mars Stark, Finn Mendez and Nyx Ward
	# each permanently lost a turn action to one tap, with no warning and no undo.
	# Ask first. Gate is here rather than inside _resolve_all_tasks() so every other
	# caller of the resolution path (auto-processing included) is unaffected.
	var stranded := _unassigned_eligible_crew()
	if not should_confirm_resolve_all(_auto_resolve_mode, stranded.size()):
		_resolve_all_tasks()
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Resolve without them?"
	dialog.ok_button_text = "Resolve anyway"
	dialog.cancel_button_text = "Go back and assign"

	# The text goes in dialog_text — the built-in label — NOT a Control added with
	# add_child().
	#
	# T10-01, measured on the tablet 2026-09-04: this dialog rendered as a bare grey
	# panel with the two buttons and NOTHING else. No title, no crew list, no rule.
	# The body region (900,000 px) held exactly ONE luminance value. So the player
	# was asked to confirm an irreversible action with zero information about it.
	#
	# Cause, per the Godot 4.6 docs: AcceptDialog is a Window, and
	# Window.wrap_controls defaults to FALSE — "you need to call
	# child_controls_changed() manually". The previous version (the T9-39 fix)
	# add_child()'d a ScrollContainer wrapping this Label and never called it, so
	# the subtree never got a layout pass and drew at zero size.
	#
	# dialog_text is what the other ~20 dialogs in src/ use, all of which render
	# correctly on device; CampaignScreenBase._show_pending_transfers_dialog() does
	# the identical header-plus-bulleted-list shape this way. Reusing it also fixes
	# T9-39 more robustly than the ScrollContainer did: with wrap_controls false the
	# window will not grow to its content at all, and popup_centered() below still
	# pins the frame — and therefore the buttons — inside the viewport.
	# AcceptDialog's built-in label does NOT wrap by default, so the longest line
	# sets the window width. Measured on the tablet after the dialog_text fix: the
	# frame grew past the 1600px screen and clipped both the rule sentence ("Once
	# tasks r...") and the "Resolve anyway" button, which popup_centered's explicit
	# size cannot claw back because the label's minimum width wins.
	dialog.dialog_autowrap = true
	dialog.dialog_text = ("%d crew have no task and will lose their action for this turn:\n\n%s"
		+ "\n\nEach crew member can perform one task per turn (Core Rules pp.77-78)."
		+ " Once tasks resolve, this cannot be undone.") % [
			stranded.size(), "  • " + "\n  • ".join(stranded)]

	add_child(dialog)
	dialog.confirmed.connect(_resolve_all_tasks)
	dialog.close_requested.connect(dialog.queue_free)
	var vp: Viewport = get_viewport()
	dialog.popup_centered(confirm_dialog_size(
		vp.get_visible_rect().size if vp != null else Vector2(800, 600)))


func _resolve_all_tasks() -> void:
	if assigned_tasks.is_empty():
		return

	# p.78's dice branch grants ONE recruit however many crew were sent, but the
	# loop below resolves once per crew member — so the grant is guarded per pass.
	_group_recruit_resolved = false
	
	pass # Resolving crew tasks
	
	var resolution_results: Array = []
	
	# Compendium p.32 "Money is Tight": "Taking Find a Patron or Repair Your Kit
	# actions costs 1 credit." Charged once per crew member sent, at resolution,
	# so a task the player assigns and then unassigns costs nothing.
	var task_surcharge: int = 0
	for crew_id in assigned_tasks:
		var task_data = assigned_tasks[crew_id]
		if task_data.resolved:
			continue
		task_surcharge += CompendiumTogglesRef.crew_task_surcharge(
			str(task_data.get("task_id", "")))
	if task_surcharge > 0:
		var gsm_surcharge: Node = get_node_or_null("/root/GameStateManager")
		if gsm_surcharge and gsm_surcharge.has_method("modify_credits"):
			gsm_surcharge.modify_credits(-task_surcharge)

	for crew_id in assigned_tasks:
		var task_data = assigned_tasks[crew_id]
		if task_data.resolved:
			continue # Skip already resolved tasks

		var result = _resolve_single_task(crew_id, task_data)
		resolution_results.append(result)
		
		# Mark as resolved
		task_data.resolved = true
		task_data.result = result
	
	# Trade Table rolls the crew did not have to spend a task on. Two rules grant
	# them, and both routed nowhere before this:
	#   "Company Store — Roll on the Trade Table (p.79)" (Core Rules p.84, the
	#   Benefits Subtable, paid out on a successful Patron job)
	#   "Free trade zone — You receive one free Trade roll each campaign turn"
	#   (p.74 World Trait)
	# They resolve through THIS pipeline rather than a second copy of it, so the
	# 100-row table, its runtime sub-rolls and the event-queue payout stay in one
	# place — the awards were rewritten once already and must not fork.
	for free_result in _resolve_free_trade_rolls():
		resolution_results.append(free_result)

	# The PAID extra rolls, bought before Resolve All was pressed. Same pipeline as
	# the free ones for the same reason — one copy of the 100-row table.
	for paid_result in _resolve_paid_trade_rolls():
		resolution_results.append(paid_result)

	# Core Rules p.125 Merchant school, verbatim: "When this crew member Trades,
	# you may reroll one Trade roll each campaign turn. The new roll must be
	# accepted and if the new roll offers a choice of whether to buy an item, you
	# must accept. You may roll up ALL eligible Trade rolls BEFORE choosing what to
	# reroll." This is exactly that moment: every Trade roll for the turn now
	# exists and NOTHING has been paid out — the event queue below applies effects.
	await _offer_merchant_reroll(resolution_results)

	# Update completion state
	all_tasks_resolved = _check_all_tasks_resolved()
	completed_tasks = resolution_results

	_update_progress_display()
	_update_ui_state()

	# Build event queue — each result becomes an interactive dialog
	_build_event_queue()
	_process_event_queue()

## ── Core Rules p.125 Merchant school ──────────────────────────────────────
##
## THE GAP THIS FILLS. `AdvancementSystem._apply_training_benefits()` recorded the
## course as `character.set("has_merchant_training", true)` — a property Character
## does not declare, so a silent no-op — and it was reached only from
## `purchase_training()`, which has ZERO callers. Nothing anywhere read the flag.
## Paying 10 XP for Merchant school bought literally nothing.
##
## The live grant path is `Character.add_training()`, whose SSOT is
## `acquired_training`, so eligibility is read through
## `AdvancementSystem.member_has_training()`.
##
## WHICH ROLLS ARE ELIGIBLE. "When this crew member Trades" is the trigger; "one
## Trade roll" is the object; and "you may roll up all eligible Trade rolls before
## choosing what to reroll" only makes sense if there is a CHOICE — so any Trade
## roll made this campaign turn is a candidate, provided a Merchant-trained crew
## member Traded. Recorded as a reading rather than chosen silently.
const MERCHANT_REROLL_KEY := "merchant_reroll_used_turn"


func _active_campaign():
	var gs: Node = get_node_or_null("/root/GameState")
	if gs == null:
		return null
	return gs.get_current_campaign() if gs.has_method("get_current_campaign") \
		else null


func _merchant_traded_this_turn() -> bool:
	for crew_id in assigned_tasks:
		var task_data: Dictionary = assigned_tasks[crew_id]
		if str(task_data.get("task_id", "")) != "trade":
			continue
		if AdvancementSystemRef.member_has_training(
				task_data.get("crew_member", {}), "merchant"):
			return true
	return false


func _merchant_reroll_available() -> bool:
	if not _merchant_traded_this_turn():
		return false
	var campaign = _active_campaign()
	if campaign == null or not ("progress_data" in campaign):
		return false
	# "each campaign turn" — one per turn, not one per merchant.
	var turn: int = int(campaign.progress_data.get("turns_played", 0))
	return int(campaign.progress_data.get(MERCHANT_REROLL_KEY, -1)) != turn


func _mark_merchant_reroll_used() -> void:
	var campaign = _active_campaign()
	if campaign == null or not ("progress_data" in campaign):
		return
	campaign.progress_data[MERCHANT_REROLL_KEY] = int(
		campaign.progress_data.get("turns_played", 0))


func _offer_merchant_reroll(results: Array) -> void:
	if not _merchant_reroll_available():
		return
	var trade_indices: Array[int] = []
	for i in range(results.size()):
		if str((results[i] as Dictionary).get("task_id", "")) == "trade":
			trade_indices.append(i)
	if trade_indices.is_empty():
		return

	var dialog := ConfirmationDialog.new()
	dialog.title = "Merchant School — Reroll (Core Rules p.125)"
	dialog.ok_button_text = "Reroll Selected"
	dialog.cancel_button_text = "Keep All"
	var vbox := VBoxContainer.new()
	var note := Label.new()
	note.text = ("Pick ONE Trade roll to reroll. The new roll MUST be accepted —"
		+ "\nif it offers a choice of whether to buy, you must accept."
		+ "\nOne reroll per campaign turn.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(note)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 200)
	for idx in trade_indices:
		var r: Dictionary = results[idx]
		list.add_item("%s — %s" % [
			str(r.get("crew_name", "Crew")), str(r.get("details", ""))])
	list.select(0)
	vbox.add_child(list)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered(Vector2i(560, 360))

	var confirmed := false
	dialog.confirmed.connect(func() -> void: confirmed = true)
	await dialog.visibility_changed
	while dialog.visible:
		await dialog.visibility_changed

	var chosen_rows: PackedInt32Array = list.get_selected_items()
	var chosen: int = trade_indices[0] if chosen_rows.is_empty() \
		else trade_indices[chosen_rows[0]]
	dialog.queue_free()
	if not confirmed:
		return

	# "The new roll must be accepted" — the old result is REPLACED outright, not
	# compared. Re-resolved through _resolve_table_task so the reroll goes down the
	# same 100-row path with the same sub-rolls as the original.
	var target: Dictionary = results[chosen]
	var before: String = str(target.get("details", ""))
	_resolve_table_task(target, {"id": "trade", "name": "Trade"}, {})
	target["merchant_rerolled"] = true
	_mark_merchant_reroll_used()
	print_verbose("Merchant school reroll (p.125): %s -> %s"
		% [before, str(target.get("details", ""))])


func _finalize_task_resolution() -> void:
	## Complete task resolution — items/credits/effects already applied by event queue.
	## Just publish the completion event and update display.
	_update_progress_display()

	# Publish completion event
	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.CREW_TASK_RESOLVED, {
			"results": completed_tasks,
			"all_resolved": all_tasks_resolved
		})

func _resolve_single_task(crew_id: String, task_data: Dictionary) -> Dictionary:
	## Resolve a single crew task using Five Parsecs Core Rules
	var crew_member: Dictionary = task_data.crew_member
	var task: Dictionary = task_data.task
	var task_id: String = task_data.get("task_id", "")

	var result: Dictionary = {
		"crew_id": crew_id,
		"crew_name": crew_member.get("character_name", "Unknown"),
		"task_name": task.name,
		"task_id": task_id,
		"roll": 0,
		"modified_roll": 0,
		"target": task.dice_target,
		"success": false,
		"reward": "None",
		"penalty": "None",
		"details": ""
	}

	# Handle by resolution type (Core Rules pp.76-82)
	match task.resolution_type:
		"automatic":
			result = _resolve_automatic_task(result, task, crew_member)
		"dice_roll":
			result = _resolve_dice_task(result, task, task_id, crew_member)
		"table_roll":
			result = _resolve_table_task(result, task, crew_member)
		"repair":
			result = _resolve_repair_task(result, task, crew_member)
		"faction_favor":
			result = _resolve_faction_favor_task(result, crew_member)

	var status = "SUCCESS" if result.success else "FAILED"
	pass # Task resolved

	return result

func _resolve_automatic_task(result: Dictionary, task: Dictionary, crew_member: Dictionary) -> Dictionary:
	## Resolve automatic tasks (Train, Decoy)
	result.success = true
	result.reward = task.success_reward

	match task.id:
		"train":
			# On-board item, Teach-bot (Core Rules p.58): "A character engaging
			# in the Train crew task will earn 1D6 additional XP. Single-use."
			# Rolled and consumed in one call so the item cannot be spent twice
			# or spent without paying out.
			var bonus_xp: int = OnboardItemServiceRef.consume_teach_bot(_active_campaign())
			var total_xp: int = 1 + bonus_xp
			if bonus_xp > 0:
				result.details = "+%d XP awarded (+1 Train, +%d Teach-bot 1D6 — bot used up)" \
					% [total_xp, bonus_xp]
			else:
				result.details = "+1 XP awarded"
			_apply_xp_to_character(crew_member, total_xp, "train_task")
			# p.78, the clause that makes Train a decision rather than a deposit:
			# "If this means they may make a Character Upgrade (see 'Experience and
			# Character Upgrades', p.123), resolve that immediately." Without this
			# the XP sat unspent until the player happened to open the post-battle
			# advancement step, and "immediately" never happened.
			if _offer_immediate_upgrade(crew_member):
				result.details += " — Character Upgrade available now (p.78)"
		"decoy":
			result.details = "Crew unavailable for battle, -1 enemy deployment"
		"work_on_the_quest":
			# Compendium p.79: "This has no effect other than to help complete
			# this step. Once a total of 6 such tasks have been performed by your
			# crew, receive 1 Quest Rumor." No roll, no reward but the counter.
			result.details = _record_quest_work()

	return result


## Tick the p.79 "Work on the Quest" counter and pay the Rumor on the sixth.
## Returns the line shown in the task result.
func _record_quest_work() -> String:
	var gs = get_node_or_null("/root/GameState")
	var campaign = gs.get_current_campaign() if gs and gs.has_method(
		"get_current_campaign") else null
	if campaign == null:
		return "No active campaign."
	var outcome: Dictionary = ExpandedQuestRef.record_quest_task(campaign)
	if bool(outcome.get("rumor_awarded", false)) and gs.has_method("add_quest_rumor"):
		gs.add_quest_rumor()
	return str(outcome.get("message", "Work on the Quest."))

func _resolve_dice_task(result: Dictionary, task: Dictionary, task_id: String, crew_member: Dictionary) -> Dictionary:
	## Resolve dice roll tasks (Find Patron, Recruit, Track)
	var roll: int = randi() % 6 + 1
	var modified_roll: int = roll

	# On-board item, Mk II translator (Core Rules p.58): "When rolling to
	# Recruit, you may roll an additional D6."
	#
	# An EXTRA DIE, not +1 — and the book means it. Against p.78's 6+ target the
	# two are not interchangeable: a second die is a second chance at the whole
	# roll. Keep the better of the dice; "you may" makes it optional and never
	# taking the worse one is the only sensible exercise of that option.
	var translator_note: String = ""
	if task_id == "recruit":
		var extra_dice: int = OnboardItemServiceRef.recruit_extra_dice(_active_campaign())
		for _d in range(extra_dice):
			var second: int = randi() % 6 + 1
			if second > roll:
				roll = second
			modified_roll = roll
		if extra_dice > 0:
			translator_note = "Mk II Translator: extra D6, kept %d" % roll

	# Apply crew count bonus (Core Rules: +N for N crew members on task)
	#
	# NOTE this is a plain ASSIGNMENT, not an append — anything written to
	# result.details above it is destroyed. The translator note is therefore held
	# in a local and appended below rather than set at its own site.
	var crew_on_task = task_assignments.get(task_id, []).size()
	if crew_on_task > 0:
		modified_roll += crew_on_task
		result.details = "+%d for %d crew" % [crew_on_task, crew_on_task]
	if not translator_note.is_empty():
		result.details = translator_note if str(result.details).is_empty() \
			else str(result.details) + ", " + translator_note

	# Credits spent for a bonus (Core Rules p.77 Find a Patron: "After rolling,
	# you may opt to spend credits. Each credit earns a +1 bonus." p.78 Track and
	# Repair say the same before the roll.)
	#
	# credit_bonus_max = -1 in data/crew_tasks.json is the documented NO-CAP
	# sentinel — its sibling credit_bonus_note reads "Each credit spent = +1 (no
	# cap stated)". This line read it as a maximum and computed
	# mini(credits_spent, -1) = -1, so spending credits would have applied a
	# PENALTY. It never fired only because the spender was unreachable.
	var credits_spent = credits_spent_on_tasks.get(task_id, 0)
	if credits_spent > 0:
		var cap: int = int(task.get("credit_bonus", 0))
		var bonus: int = credits_spent if cap < 0 else mini(credits_spent, cap)
		modified_roll += bonus
		result.details += ", +%d for %d credits" % [bonus, credits_spent]

	# Character bonus (Savvy, etc.)
	var character_bonus: int = crew_member.get("task_bonus", 0) as int
	if character_bonus > 0:
		modified_roll += character_bonus
		result.details += ", +%d skill" % character_bonus

	# Empath: +1 to Recruit and Find Patron tasks (Core Rules p.22)
	# Lost permanently if character has any implants
	var crew_species: String = crew_member.get("species_id", "").to_lower()
	if crew_species == "empath" and crew_member.get("implants", []).is_empty():
		if task_id in ["recruit", "find_patron"]:
			modified_roll += 1
			result.details += ", +1 Empath"

	# --- Task-specific rules (Core Rules pp.77-78) ---

	# Story Event override (Core Rules Appendix V). Event 1 p.153: "One character
	# must be sent to look for a Patron this campaign turn. Do not roll for
	# success." Events 3 and 6: "cannot seek Patron" / "There is no point seeking
	# out a Patron this campaign turn." All three were displayed by
	# StoryPhasePanel and enforced nowhere, so the search resolved normally and
	# could hand the player a Patron the book says they do not get.
	#
	# Track is barred the same way by Events 1, 2 and 3 ("you cannot Track
	# Rivals"). p.78: a 6+ "located a Rival of your choice, allowing you to fight
	# a battle against them this campaign turn" — exactly the thing those events
	# forbid, so the roll must not happen at all.
	if task.id == "track":
		if bool(_story_turn_mods().get("cannot_track_rivals", false)):
			result.roll = roll
			result.modified_roll = 0
			result.success = false
			result.reward = ""
			result.details = "Story Event: you cannot Track Rivals this " \
				+ "campaign turn (Core Rules Appendix V)."
			return result

	if task.id == "find_patron":
		var story_mods: Dictionary = _story_turn_mods()
		if bool(story_mods.get("patron_auto_fail", false)) \
				or bool(story_mods.get("cannot_seek_patron", false)):
			result.roll = roll
			result.modified_roll = 0
			result.success = false
			result.reward = ""
			result.details = "Story Event: the search turns up nothing " \
				+ "(Core Rules Appendix V)."
			return result

	# Find Patron: +1 per existing Patron contact, 6+ = two patrons
	if task.id == "find_patron":
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm:
			var patrons = gsm.get_patrons()
			if patrons.size() > 0:
				modified_roll += patrons.size()
				result.details += ", +%d patron(s)" % patrons.size()

	# Recruit (Core Rules p.78), verbatim: "If your crew has fewer than 6 members
	# currently, you can automatically recruit a new character for each crew member
	# sent Recruiting (until you are back to 6 members). If you have 6 or more crew
	# members, roll a D6, adding the number of crew members sent to recruit. A
	# score of 6 or higher allows a new recruit to be added."
	#
	# BOTH BRANCHES USED TO ADD NOBODY. The task printed "Automatic recruit (crew
	# below 6)" or the dice line and returned — _apply_recruit() is reached only
	# from the event-queue RECRUIT case, which is built solely from `table_result`
	# rewards (Trade / Exploration), and a dice result never carries one. So a crew
	# reduced to 3 by casualties could never rebuild; the only way to gain a
	# character was a lucky table roll.
	#
	# The two branches are NOT symmetrical and the resolution loop runs once per
	# crew member: the automatic branch is "for each crew member sent", which the
	# per-member loop gives naturally, but the dice branch is ONE roll for the
	# group granting ONE recruit, so it is guarded to fire only once per turn.
	if task.id == "recruit":
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm and gsm.get_crew_size() < 6:
			result.roll = roll
			result.modified_roll = 0
			result.success = true
			# "until you are back to 6 members" — re-checked per member, so a
			# crew of 5 sending three recruiters still stops at 6.
			_apply_recruit()
			result.reward = "Automatic recruit (crew below 6)"
			result.details = "Crew size < 6: auto-recruit"
			return result

	result.roll = roll
	# World Trait roll bonuses (Core Rules pp.73-74). Applied here, after every
	# other modifier and before the success comparison, so they show up in the
	# same detail string the player reads.
	var _wt: Array = _current_world_traits()
	if task.id == "recruit":
		var recruit_bonus: int = WorldTraitEffectsClass.recruit_roll_bonus(_wt)
		if recruit_bonus != 0:
			modified_roll += recruit_bonus
			result.details += ", +%d world (Easy recruiting)" % recruit_bonus
	elif task.id == "find_patron":
		var patron_bonus: int = WorldTraitEffectsClass.patron_search_bonus(_wt)
		if patron_bonus != 0:
			modified_roll += patron_bonus
			result.details += ", +%d world trait" % patron_bonus

	result.modified_roll = modified_roll
	result.success = modified_roll >= task.dice_target

	if task.id == "recruit" and result.success:
		if _group_recruit_resolved:
			result.reward = "No further recruits (one per attempt, p.78)"
		else:
			_group_recruit_resolved = true
			_apply_recruit()
			result.reward = "New recruit joins the crew"

	# Find a Patron (Core Rules p.77), verbatim:
	#   "If the result is a 5 or higher, you've found a Patron to hire you for a
	#    JOB (see p.83). If the result is a 6 or higher, you've found two, and may
	#    choose either job."
	#   "If ONE job is offered, it will always be a random, EXISTING Patron. If
	#    TWO jobs are offered, one will be a random, existing Patron, the other
	#    will be from a NEW Patron."
	#
	# TWO things were wrong here. (1) Both branches created NEW Patrons — the 5+
	# result is supposed to draw work from a contact you already have, and never
	# creates anyone. (2) Neither branch produced a JOB OFFER; it added contacts
	# and stopped. Meanwhile JobOfferComponent handed every Patron on the list a
	# fresh job every single turn with no roll at all, so this task gated nothing
	# and the whole p.77 roll was decoration. The entitlement recorded here is
	# what JobOfferComponent now consumes.
	if task.id == "find_patron":
		if modified_roll >= 6:
			result.success = true
			result.reward = "Found 2 job offers (one existing Patron, one new)"
			_grant_patron_job_offers(2)
		elif modified_roll >= 5:
			result.success = true
			result.reward = "Found 1 job offer (an existing Patron)"
			_grant_patron_job_offers(1)

	# Track: "6+ locates a Rival of your choice, allowing you to fight a battle
	# against them this campaign turn" (Core Rules p.78). WHICH Rival is the
	# player's decision, so a successful roll opens a picker rather than the app
	# choosing. Until this existed the task resolved, printed a success line and
	# recorded nothing — so progress_data["tracked_rivals"] stayed empty and the
	# p.119 "+1 if you Tracked them down" Rival-removal modifier could never
	# apply, no matter how the player played the World Phase.
	if task.id == "track" and result.success:
		call_deferred("_prompt_track_rival_choice", result)

	if result.success:
		if result.reward == "None" or result.reward == "":
			result.reward = task.success_reward
		result.details = "Roll %d → %d vs %d. %s" % [roll, modified_roll, task.dice_target, result.details]
	else:
		result.penalty = task.failure_penalty
		result.details = "Roll %d → %d vs %d. %s" % [roll, modified_roll, task.dice_target, result.details]

	return result

func _prompt_track_rival_choice(result: Dictionary) -> void:
	## Core Rules p.78 Track: the player picks WHICH Rival was located.
	## Writes straight to progress_data["tracked_rivals"] at pick time rather than
	## relying on the task result being read later — the result is also stamped so
	## RivalEncounterCheck.tracked_rival_ids_from_tasks() sees it either way.
	var gs = get_node_or_null("/root/GameState")
	if gs == null or gs.current_campaign == null:
		return
	var campaign = gs.current_campaign
	var rivals: Array = []
	if "rivals" in campaign and campaign.rivals is Array:
		rivals = campaign.rivals
	if rivals.is_empty():
		return

	var RivalCheck = load("res://src/core/campaign/RivalEncounterCheck.gd")
	var popup := PopupMenu.new()
	popup.name = "TrackRivalPopup"
	add_child(popup)
	for i in range(rivals.size()):
		popup.add_item(RivalCheck.rival_name_of(rivals[i]), i)
	popup.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < rivals.size():
			var rid: String = RivalCheck.rival_id_of(rivals[id])
			var rname: String = RivalCheck.rival_name_of(rivals[id])
			result["rival_id"] = rid
			result["details"] = str(result.get("details", "")) + " Located %s." % rname
			if "progress_data" in campaign:
				var tracked: Array = campaign.progress_data.get("tracked_rivals", [])
				if not (tracked is Array):
					tracked = []
				if rid not in tracked:
					tracked.append(rid)
				campaign.progress_data["tracked_rivals"] = tracked
			var journal = get_node_or_null("/root/CampaignJournal")
			if journal and journal.has_method("create_entry"):
				journal.create_entry({
					"type": "event",
					"auto_generated": true,
					"title": "Rival located",
					"description": "Tracked down %s. You may fight them this campaign turn, and gain +1 to chase them off after the battle (Core Rules pp.78, 119)." % rname,
					"tags": ["rival", "upkeep"],
				})
		popup.queue_free()
	)
	popup.popup_centered()

func _story_turn_mods() -> Dictionary:
	## Campaign-turn restrictions for the current Story Event, or {} on a normal
	## turn. Core Rules Appendix V — each event lists its own under "The Campaign
	## Turn". They are parsed into StoryEvent.campaign_turn_mods and, until now,
	## only ever rendered as text by StoryPhasePanel.
	var cpm: Node = get_node_or_null("/root/CampaignPhaseManager")
	if cpm == null or not cpm.has_method("get_story_turn_mods"):
		return {}
	return cpm.get_story_turn_mods()

## p.77 Find a Patron paid out as JOB OFFERS, which is what the book actually
## awards ("you've found a Patron to hire you for a job").
##
## `count` is 1 (a 5+) or 2 (a 6+). Records an entitlement in progress_data that
## JobOfferComponent consumes when it builds this turn's offer list, and creates
## a NEW Patron only for the second of two offers — p.77 is explicit that the
## first is always "a random, EXISTING Patron".
##
## DOCUMENTED READING, not an invention: if the crew has no existing Patrons at
## all there is no "random existing Patron" to draw from, and the book does not
## address that case. Taking it as a new Patron is the only reading under which a
## successful roll still produces the job the same sentence promises; refusing to
## produce anything would make the task fail after succeeding.
## Add ONE Patron to the contact list, with no job offer attached.
##
## This is a different rule from p.77 Find a Patron below, and keeping them apart
## matters: the Trade and Exploration tables have results that read "gain a
## Patron" (the CrewTaskEventDialog GAIN_PATRON event), which grants a CONTACT.
## Whether that contact ever offers work is then decided by the p.77 roll like
## any other contact. Merging the two would hand out free jobs through the back
## door and undo the gate.
## Core Rules p.74, verbatim: "Corporate state — ... Failing a mission means being
## BLACKLISTED and you cannot get Patrons here again."
##
## Written post-battle by RivalPatronResolver._apply_corporate_blacklist(); this is
## the gate it exists for. Without a reader the blacklist would be a key nothing
## consults — the exact producer/consumer half-wiring this audit is about.
func _patron_blacklisted() -> bool:
	var campaign = _active_campaign()
	if campaign == null or not ("progress_data" in campaign):
		return false
	if not (campaign.progress_data is Dictionary):
		return false
	var listed: Variant = campaign.progress_data.get("patron_blacklist_planets", [])
	if not (listed is Array) or (listed as Array).is_empty():
		return false
	var pdm: Node = get_node_or_null("/root/PlanetDataManager")
	if pdm == null or not ("current_planet_id" in pdm):
		return false
	return str(pdm.current_planet_id) in (listed as Array)


## "Corporate state — Patrons are always Corporations" (p.74). Stamped on the
## patron record at creation so every later reader — the offer summary, the
## journal, the dashboard — agrees on what kind of employer this is.
func _apply_forced_patron_type(patron_data: Dictionary) -> Dictionary:
	var forced: String = WorldTraitEffectsClass.forced_patron_type(
		_current_world_traits())
	if forced.is_empty():
		return patron_data
	patron_data["type"] = forced
	patron_data["patron_type"] = forced
	return patron_data


func _add_patron_contact() -> void:
	var campaign = _active_campaign()
	if campaign == null or not ("patrons" in campaign) or not (campaign.patrons is Array):
		return
	if _patron_blacklisted():
		return
	var pjm = PatronJobManager.new()
	var contact_result: Dictionary = pjm.roll_patron_contact()
	var patron_data: Dictionary = contact_result.get("patron", {})
	if patron_data.is_empty():
		patron_data = {
			"id": "patron_" + str(randi() % 100000),
			"name": "Local Contact",
			"tier": "minor",
			"relationship": 0,
		}
	campaign.patrons.append(_apply_forced_patron_type(patron_data))
	pjm.free()


func _grant_patron_job_offers(count: int) -> void:
	var campaign = _active_campaign()
	if campaign == null or not ("progress_data" in campaign):
		return
	# p.74 Corporate state: a blacklisted crew "cannot get Patrons here again", so
	# a successful p.77 roll finds nobody willing to hire them on this world.
	if _patron_blacklisted():
		return

	var existing: Array = []
	if "patrons" in campaign and campaign.patrons is Array:
		existing = campaign.patrons

	var new_patrons_needed: int = 0
	if count >= 2:
		new_patrons_needed = 1          # "the other will be from a new Patron"
	if existing.is_empty():
		new_patrons_needed = count      # nothing to draw an existing offer from

	if new_patrons_needed > 0:
		var pjm = PatronJobManager.new()
		for _i in range(new_patrons_needed):
			var contact_result: Dictionary = pjm.roll_patron_contact()
			var patron_data: Dictionary = contact_result.get("patron", {})
			if patron_data.is_empty():
				patron_data = {
					"id": "patron_" + str(randi() % 100000),
					"name": "Local Contact",
					"tier": "minor",
					"relationship": 0,
				}
			if "patrons" in campaign and campaign.patrons is Array:
				campaign.patrons.append(_apply_forced_patron_type(patron_data))
		pjm.free()

	# The entitlement. Accumulated rather than assigned: several crew members may
	# be sent to Find a Patron and each resolves through this function, and the
	# player may also re-enter the step. JobOfferComponent zeroes it once spent.
	var pd: Dictionary = campaign.progress_data
	pd["patron_offers_owed"] = int(pd.get("patron_offers_owed", 0)) + count

## Free Trade Table rolls owed to the crew this turn, resolved as ordinary Trade
## results so the event queue pays them out exactly like a crew-assigned Trade.
##
## Sources: the p.84 "Company Store" Benefit banks one per successful Patron job
## into progress_data["pending_free_trade_rolls"]; the p.74 "Free trade zone"
## World Trait grants one every turn on that world. The banked count is consumed
## here — the trait's is not, because it recurs.
func _resolve_free_trade_rolls() -> Array:
	var out: Array = []
	var gs = get_node_or_null("/root/GameState")
	var campaign = gs.current_campaign if gs else null
	if campaign == null or not "progress_data" in campaign:
		return out

	var banked: int = int(campaign.progress_data.get("pending_free_trade_rolls", 0))
	var from_trait: int = WorldTraitEffectsClass.free_trade_rolls_per_turn(
		_current_world_traits())
	var total: int = banked + from_trait
	if total <= 0:
		return out

	for i in range(total):
		var source: String = "Company Store (p.84)" if i < banked else "Free trade zone (p.74)"
		var result: Dictionary = {
			"crew_id": "",
			"crew_name": source,
			"task_name": "Free Trade Roll",
			"task_id": "trade",
			"roll": 0,
			"modified_roll": 0,
			"success": true,
			"details": "",
			"reward": "",
		}
		_resolve_table_task(result, {"id": "trade", "name": "Trade"}, {})
		out.append(result)

	# Only the BANKED rolls are spent. Leaving them would pay the same Company
	# Store benefit again every turn for the rest of the campaign.
	campaign.progress_data["pending_free_trade_rolls"] = 0
	return out


## ── Paid extra Trade rolls (Core Rules p.78 + the p.74 Busy Markets trait) ──
##
## p.78, verbatim: "For each crew member Trading, roll once on the Trade Table
## (see p.79) to see what presents itself. You can get additional rolls by
## spending 3 credits each. AT LEAST ONE CREW MEMBER MUST BE TRADING to permit
## this expenditure."
##
## p.73, verbatim: "Busy markets — Each campaign turn, you may spend 2 credits
## ONCE to roll on the Trade Table (p.79)."
##
## THE GAP: credits could not buy anything in the World step. The p.78 clause had
## no UI at all, and `WorldTraitEffects.extra_trade_roll_cost()` implemented Busy
## Markets and had ZERO callers. Two separate purchases with different prices,
## different limits and different preconditions, so they are counted separately —
## merging them would silently let the Busy Markets roll bypass p.78's
## someone-must-be-Trading gate.
const EXTRA_TRADE_ROLL_COST := 3

var _paid_trade_rolls: int = 0
var _busy_market_roll_bought: bool = false
var _buy_trade_button: Button = null
var _busy_market_button: Button = null


## p.78's precondition, checked rather than assumed: without a crew member on the
## Trade task there is nothing to buy an ADDITIONAL roll in addition TO.
func _someone_is_trading() -> bool:
	for task_data: Variant in assigned_tasks.values():
		if task_data is Dictionary \
				and str((task_data as Dictionary).get("task_id", "")) == "trade":
			return true
	return false


func _busy_market_cost() -> int:
	return WorldTraitEffectsClass.extra_trade_roll_cost(_current_world_traits())


func _busy_market_used_this_turn() -> bool:
	if _busy_market_roll_bought:
		return true
	var campaign = _active_campaign()
	if campaign == null or not ("progress_data" in campaign):
		return false
	if not (campaign.progress_data is Dictionary):
		return false
	# Persisted as well as held in memory: the player can leave and re-enter the
	# step, and "once per campaign turn" has to survive that.
	return int(campaign.progress_data.get("busy_markets_roll_used_turn", -1)) \
		== _campaign_turn_number()


func _campaign_turn_number() -> int:
	var campaign = _active_campaign()
	if campaign == null or not ("progress_data" in campaign):
		return 0
	var pd: Variant = campaign.progress_data
	return int((pd as Dictionary).get("turns_played", 0)) if pd is Dictionary else 0


func _refresh_trade_purchase_buttons() -> void:
	var bar: Node = resolve_all_button.get_parent() if resolve_all_button else null
	if bar == null:
		return
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	var credits: int = int(gsm.get_credits()) if gsm and gsm.has_method("get_credits") else 0

	# p.78 — 3 credits each, unlimited, gated on someone Trading.
	var can_buy: bool = not all_tasks_resolved and _someone_is_trading() \
		and credits >= EXTRA_TRADE_ROLL_COST
	if _buy_trade_button == null or not is_instance_valid(_buy_trade_button):
		_buy_trade_button = Button.new()
		_buy_trade_button.name = "BuyTradeRollButton"
		_buy_trade_button.custom_minimum_size.y = TOUCH_TARGET_MIN
		_buy_trade_button.tooltip_text = (
			"Core Rules p.78: additional Trade Table rolls cost 3 credits each. "
			+ "At least one crew member must be Trading.")
		_buy_trade_button.pressed.connect(_on_buy_trade_roll)
		bar.add_child(_buy_trade_button)
	_buy_trade_button.text = "Buy Trade Roll (%d cr)%s" % [
		EXTRA_TRADE_ROLL_COST,
		"  ×%d" % _paid_trade_rolls if _paid_trade_rolls > 0 else ""]
	_buy_trade_button.disabled = not can_buy
	_buy_trade_button.visible = _someone_is_trading() and not all_tasks_resolved

	# p.73 Busy markets — a DIFFERENT price, once per turn, and the book does not
	# tie it to the Trade task, so it is offered on its own terms.
	var bm_cost: int = _busy_market_cost()
	var bm_available: bool = bm_cost >= 0 and not all_tasks_resolved \
		and not _busy_market_used_this_turn()
	if bm_available:
		if _busy_market_button == null or not is_instance_valid(_busy_market_button):
			_busy_market_button = Button.new()
			_busy_market_button.name = "BusyMarketRollButton"
			_busy_market_button.custom_minimum_size.y = TOUCH_TARGET_MIN
			_busy_market_button.tooltip_text = (
				"Core Rules p.73 Busy markets: once per campaign turn you may spend "
				+ "%d credits to roll on the Trade Table." % bm_cost)
			_busy_market_button.pressed.connect(_on_buy_busy_market_roll)
			bar.add_child(_busy_market_button)
		_busy_market_button.text = "Busy Markets Roll (%d cr)" % bm_cost
		_busy_market_button.disabled = credits < bm_cost
	elif _busy_market_button != null and is_instance_valid(_busy_market_button):
		_busy_market_button.get_parent().remove_child(_busy_market_button)
		_busy_market_button.queue_free()
		_busy_market_button = null


func _on_buy_trade_roll() -> void:
	if all_tasks_resolved or not _someone_is_trading():
		return
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("get_credits"):
		return
	if int(gsm.get_credits()) < EXTRA_TRADE_ROLL_COST:
		return
	gsm.modify_credits(-EXTRA_TRADE_ROLL_COST)
	_paid_trade_rolls += 1
	_refresh_trade_purchase_buttons()


func _on_buy_busy_market_roll() -> void:
	var cost: int = _busy_market_cost()
	if cost < 0 or all_tasks_resolved or _busy_market_used_this_turn():
		return
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm == null or not gsm.has_method("get_credits"):
		return
	if int(gsm.get_credits()) < cost:
		return
	gsm.modify_credits(-cost)
	_busy_market_roll_bought = true
	var campaign = _active_campaign()
	if campaign != null and "progress_data" in campaign \
			and campaign.progress_data is Dictionary:
		campaign.progress_data["busy_markets_roll_used_turn"] = _campaign_turn_number()
	_refresh_trade_purchase_buttons()


## Resolve the rolls the player paid for, through the SAME pipeline as the free
## ones. Consumed here so a re-press of Resolve All cannot pay them out twice.
func _resolve_paid_trade_rolls() -> Array:
	var out: Array = []
	var total: int = _paid_trade_rolls + (1 if _busy_market_roll_bought else 0)
	if total <= 0:
		return out

	for i in range(total):
		var source: String = "Extra Trade roll (p.78, 3 cr)" if i < _paid_trade_rolls \
			else "Busy markets (p.73, %d cr)" % _busy_market_cost()
		var result: Dictionary = {
			"crew_id": "",
			"crew_name": source,
			"task_name": "Purchased Trade Roll",
			"task_id": "trade",
			"roll": 0,
			"modified_roll": 0,
			"success": true,
			"details": "",
			"reward": "",
		}
		_resolve_table_task(result, {"id": "trade", "name": "Trade"}, {})
		out.append(result)

	_paid_trade_rolls = 0
	_busy_market_roll_bought = false
	return out


## ── Call In a Favor (Compendium p.112 "The Benefits of Loyalty") ────────────
##
## "Your captain may try to call in a favor once per campaign turn. This requires
## a crew task, and can only be done by your captain."
##
## THE GAP: `FactionSystem.attempt_faction_favor()` was correct and complete and
## had ZERO callers, because the crew task the book requires did not exist. Every
## Loyalty point the crew earned was unspendable and all six favors unreachable.

func _faction_system() -> Node:
	return get_node_or_null("/root/FactionSystem")


## The Faction with the most Loyalty — the one a favor call is worth making to.
## Returns "" when there is none worth asking.
func _best_faction_for_favor() -> String:
	var fs: Node = _faction_system()
	if fs == null or not fs.has_method("get_all_factions"):
		return ""
	var best_id: String = ""
	var best_loyalty: int = 0
	for fid: Variant in fs.get_all_factions().keys():
		var loyalty: int = int(fs.get_faction_loyalty(str(fid)))
		if loyalty > best_loyalty:
			best_loyalty = loyalty
			best_id = str(fid)
	return best_id


func _best_faction_loyalty() -> int:
	var fid: String = _best_faction_for_favor()
	if fid.is_empty():
		return 0
	var fs: Node = _faction_system()
	return int(fs.get_faction_loyalty(fid)) if fs else 0


## Should the favor task appear in the list at all? Non-favor tasks always pass.
func _favor_task_offerable(task: Dictionary) -> bool:
	if str(task.get("resolution_type", "")) != "faction_favor":
		return true
	# p.112 is inside the Compendium's Expanded Factions chapter.
	var dlc: Node = get_node_or_null("/root/DLCManager")
	if dlc and dlc.has_method("is_feature_enabled"):
		var flag: int = int(dlc.ContentFlag.get(str(task.get("dlc_flag", "")), -1))
		if flag < 0 or not dlc.is_feature_enabled(flag):
			return false
	if _best_faction_loyalty() <= 0:
		return false
	return not FactionFavorServiceRef.favor_used_this_turn(
		_active_campaign(), _campaign_turn_number())


func _resolve_faction_favor_task(
	result: Dictionary, crew_member: Dictionary
) -> Dictionary:
	## p.112: "can only be done by your CAPTAIN." Enforced here as well as in the
	## assignment UI — a gate that lives only in the widget is one rebuild away
	## from being bypassed.
	if not bool(_member_get(crew_member, "is_captain", false)):
		result.success = false
		result.details = "Only your captain can call in a favor (Compendium p.112)."
		return result

	var campaign = _active_campaign()
	var turn: int = _campaign_turn_number()
	if FactionFavorServiceRef.favor_used_this_turn(campaign, turn):
		result.success = false
		result.details = "A favor has already been called in this campaign turn (p.112)."
		return result

	var faction_id: String = _best_faction_for_favor()
	var fs: Node = _faction_system()
	if faction_id.is_empty() or fs == null or not fs.has_method("attempt_faction_favor"):
		result.success = false
		result.details = "No Faction owes you anything yet (p.112)."
		return result

	# The roll, the Loyalty spend and the six-favor list all live in FactionSystem;
	# this only runs the task and applies the choice.
	var outcome: Dictionary = fs.attempt_faction_favor(faction_id)
	FactionFavorServiceRef.mark_favor_used(campaign, turn)
	result.roll = int(outcome.get("roll", 0))
	result.modified_roll = result.roll

	if not bool(outcome.get("success", false)):
		result.success = false
		# "If the roll is higher than the Loyalty score, nobody has time for you
		# ('...but we do appreciate your business!'). Your Loyalty score remains
		# unchanged."
		result.details = "Rolled %d — nobody has time for you, and your Loyalty is unchanged (p.112)." \
			% result.roll
		return result

	result.success = true
	result.reward = "Loyalty -%d; choose a favor" % int(outcome.get("loyalty_spent", 0))
	result.details = "Rolled %d against Loyalty — a favor is owed (p.112)." % result.roll
	# "You can choose the favor AFTER ROLLING" — so the picker opens now, not
	# before the die.
	_offer_faction_favor(faction_id, result.roll)
	return result


func _faction_influence(faction_id: String) -> int:
	var fs: Node = _faction_system()
	if fs == null or not fs.has_method("get_all_factions"):
		return 0
	var f: Variant = fs.get_all_factions().get(faction_id, {})
	return int((f as Dictionary).get("influence", 0)) if f is Dictionary else 0


func _offer_faction_favor(faction_id: String, roll: int) -> void:
	var options: Array = FactionFavorServiceRef.favor_options(
		roll, _faction_influence(faction_id))
	var labels: Array = []
	var id_by_label: Dictionary = {}
	for opt: Dictionary in options:
		labels.append(str(opt["label"]))
		id_by_label[str(opt["label"])] = str(opt["id"])

	var popup: Window = ItemChoicePopupScript.new()
	if popup == null:
		return
	popup.title = "Call In a Favor (Compendium p.112)"
	add_child(popup)
	popup.item_chosen.connect(
		func(chosen: String) -> void:
			_apply_faction_favor(str(id_by_label.get(chosen, "")), roll, faction_id))
	popup.show_choices(
		"Rolled %d — the Faction owes you. Choose your favor." % roll,
		labels, "Call It In")


func _apply_faction_favor(favor_id: String, roll: int, faction_id: String) -> void:
	if favor_id.is_empty():
		return
	var campaign = _active_campaign()
	var outcome: Dictionary = FactionFavorServiceRef.apply_favor(
		campaign, favor_id, roll, _faction_influence(faction_id))

	# Credits and Quest Rumors are owned by singletons, so the service returns
	# them as data and they are applied here (the data-ownership table).
	var credits: int = int(outcome.get("credits", 0))
	if credits > 0:
		var gsm: Node = get_node_or_null("/root/GameStateManager")
		if gsm and gsm.has_method("modify_credits"):
			gsm.modify_credits(credits)
	var rumors: int = int(outcome.get("rumors", 0))
	if rumors > 0:
		var gs: Node = get_node_or_null("/root/GameState")
		if gs and gs.has_method("add_quest_rumor"):
			for _i in range(rumors):
				gs.add_quest_rumor()
	# "Arrange a meeting — Roll up a new crew member using the start-of-campaign
	# process. They will assist you for one mission."
	if bool(outcome.get("spawn_temp_crew", false)):
		_apply_recruit()

	_journal_note(str(outcome.get("detail", "")))
	var notif: Node = get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("show_success"):
		notif.show_success(str(outcome.get("detail", "Favor called in.")))


func _resolve_table_task(result: Dictionary, task: Dictionary, crew_member: Dictionary) -> Dictionary:
	## Resolve table roll tasks (Trade, Explore)
	##
	## This is the ONLY live D100 into data/trade_table.json and
	## data/exploration_table.json. (DataManager.get_trade_result /
	## get_exploration_result are commented out in full and their only callers
	## are in the dead phases/WorldPhase.gd - do not follow that trail.)
	##
	## Routed through DiceManager so the roll is recorded and so the debug-only
	## QA seam can force a specific row: the "I don't have a gambling problem!"
	## (explore 51-53) and "A chance to unload some stuff" (trade 76-78) rows are
	## 3-in-100 each and were unreachable on device (T9-47).
	var roll_context: String = "Trade Table"
	if str(task.get("id", "")) == "explore":
		roll_context = "Exploration Table"
	var d100_roll: int = _roll_task_d100(roll_context)
	result.roll = d100_roll
	result.modified_roll = d100_roll
	result.success = true # Table rolls always "succeed" - just determine outcome

	var table_result: Dictionary = {}
	match task.id:
		"trade":
			table_result = _get_trade_table_result(d100_roll)
			result.details = "Trade Table roll: %d - %s" % [d100_roll, table_result.name]
			result.reward = table_result.effect
			result.table_result = table_result # Store full result for UI
		"explore":
			table_result = _get_exploration_table_result(d100_roll)
			result.details = "Exploration Table roll: %d - %s" % [d100_roll, table_result.name]
			result.reward = table_result.effect
			result.table_result = table_result # Store full result for UI

	# Cache deferred events if result has a trigger
	if table_result.has("deferred_trigger") and table_result.deferred_trigger != "":
		var crew_id: String = crew_key(crew_member)  # see crew_key(): T9-40
		_cache_deferred_event(
			table_result.deferred_trigger,
			table_result.name,
			crew_id,
			table_result
		)

	return result

## Trait ids for the world the crew is working on (Core Rules pp.73-75). Three
## traits modify crew-task rolls and were flavour text: "Easy recruiting — Add
## +1 to the roll when Recruiting", "Opportunities — Add +1 to the roll when
## searching for Patrons" (and "Corporate state — +2 when rolling to find a
## Patron"), and "Technical knowledge — Add +1 to all Repair attempts".
func _current_world_traits() -> Array:
	var gs = get_node_or_null("/root/GameState")
	if not gs:
		return []
	return WorldTraitEffectsClass.traits_for_current_world(gs.current_campaign)

func _resolve_repair_task(result: Dictionary, task: Dictionary, crew_member: Dictionary) -> Dictionary:
	## Resolve repair tasks (Core Rules p.78)
	## Roll 1D6 + Savvy. Engineer +1. Spare parts (credits) +1 each. 6+ = repaired. Natural 1 = unfixable.
	var roll: int = randi() % 6 + 1
	var modified_roll: int = roll
	var detail_parts: Array = []

	# Add Savvy ability score
	var savvy: int = crew_member.get("savvy", 0) as int
	if savvy != 0:
		modified_roll += savvy
		detail_parts.append("+%d Savvy" % savvy)

	# "Technical knowledge — Add +1 to all Repair attempts" (Core Rules p.73).
	var tech_bonus: int = WorldTraitEffectsClass.repair_roll_bonus(
		_current_world_traits())
	if tech_bonus != 0:
		modified_roll += tech_bonus
		detail_parts.append("+%d world (Technical knowledge)" % tech_bonus)

	# "Add +1 if the character is an Engineer" (Core Rules p.78).
	#
	# Engineer is a SPECIES (data/character_species.json primary_aliens id
	# "engineer"), stored in species_id — not a CharacterClass. Reading
	# character_class here meant the one crew type the book singles out for this
	# job never got the bonus, so their repair chance was identical to a baseline
	# human's. The sibling Empath check in _resolve_dice_task reads species_id
	# correctly; this one did not.
	#
	# str() guard: legacy saves store "origin" as a numeric enum (e.g. 7.0) and
	# carry no species_id, so the raw value can be a float and .to_lower() aborts.
	var crew_species: String = str(crew_member.get(
		"species_id", crew_member.get("origin", ""))).to_lower()
	if crew_species == "engineer":
		modified_roll += 1
		detail_parts.append("+1 Engineer")

	# Credit spending for spare parts (+1 per credit)
	#
	# NOT the same rule as the Spare Parts on-board ITEM below. p.78 lets you buy
	# spare parts with credits at +1 each; p.58 is a physical item in the Stash
	# that also grants +1. Both exist and both apply — do not merge them.
	var task_id: String = result.get("task_id", "repair_kit")
	var credits_spent: int = credits_spent_on_tasks.get(task_id, 0)
	if credits_spent > 0:
		modified_roll += credits_spent
		detail_parts.append("+%d spare parts" % credits_spent)
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm:
			gsm.remove_credits(credits_spent)

	# On-board items (Core Rules p.58): Repair Bot "+1 to all Repair attempts";
	# Spare parts "Add +1 when making a Repair attempt. If the roll is a natural
	# 1, the Spare Parts are used up and must be erased from your roster."
	var repair_campaign = _active_campaign()
	var onboard_repair: Dictionary = OnboardItemServiceRef.repair_bonus(repair_campaign)
	var onboard_bonus: int = int(onboard_repair.get("value", 0))
	if onboard_bonus != 0:
		modified_roll += onboard_bonus
		for src in onboard_repair.get("sources", []):
			detail_parts.append(str(src))

	result.roll = roll
	result.modified_roll = modified_roll
	result.target = 6

	var modifier_text = ", ".join(detail_parts) if detail_parts.size() > 0 else ""
	var roll_text = "Roll %d" % roll
	if modifier_text != "":
		roll_text += " %s" % modifier_text

	# THE ITEM ITSELF WAS NEVER TOUCHED. Every branch below set a reward STRING and
	# nothing else — no damaged-item picker, no write of any condition — so a
	# broken weapon stayed broken forever while the panel reported "Item repaired"
	# every single time. The only application code lived in the dead
	# src/core/campaign/phases/WorldPhase.gd.
	var target: Dictionary = _first_damaged_target(crew_member)
	var damaged: String = str(target.get("name", ""))

	# "If you have had items destroyed, you can attempt to Repair them" (p.78) —
	# with nothing damaged there is nothing to fix, and claiming otherwise is the
	# bug this replaces.
	if damaged.is_empty():
		result.success = false
		result.reward = "Nothing damaged to repair"
		result.details = "%s — no damaged items on this character or in the stash" % roll_text
		return result

	# Natural 1 always fails AND the item becomes unfixable.
	#
	# DOCUMENTED READING, not a silent choice. p.78 bullet two reads verbatim:
	# "A natural 1 always fails this roll. A failed roll means the item is beyond
	# fixing." Taken literally the second sentence destroys the item on ANY
	# failure, which would make Repair Your Kit a one-shot gamble rather than a
	# retryable task. Read here as the natural-1 case only, because (a) the two
	# sentences sit in ONE bullet and the second most plausibly restates the
	# first, and (b) the designer FAQ has no entry on it, so the harsher reading
	# would be inventing a rule. Revisit if errata ever addresses it.
	if roll == 1:
		_resolve_damaged_target(crew_member, target, false)
		# p.58 Spare parts: "If the roll is a natural 1, the Spare Parts are used
		# up and must be erased from your roster." Keyed on the natural roll, not
		# the modified total.
		if bool(onboard_repair.get("spare_parts", false)):
			if OnboardItemServiceRef.consume(repair_campaign, "spare_parts"):
				detail_parts.append("Spare Parts used up")
				roll_text += " (Spare Parts used up)"
		result.success = false
		result.reward = "CRITICAL FAIL — %s is beyond repair" % damaged
		result.details = "%s = %d vs 6. Natural 1: UNFIXABLE" % [roll_text, modified_roll]
	elif modified_roll >= 6:
		_resolve_damaged_target(crew_member, target, true)
		result.success = true
		result.reward = "%s repaired" % damaged
		result.details = "%s = %d vs 6. Repaired!" % [roll_text, modified_roll]
	else:
		result.success = false
		result.reward = "Repair failed — try again next turn"
		result.details = "%s = %d vs 6. Failed" % [roll_text, modified_roll]

	return result


func _stash_items() -> Array:
	## The ship stash: campaign.equipment_data["equipment"] per the data-ownership
	## table. Returns the LIVE array so a repair writes through to the campaign.
	##
	## is_inside_tree() guard: an absolute get_node() from a detached node ERRORS
	## and unwinds the CALLER, so without this a `.new()`-constructed component
	## (tests, probes) would abort inside _first_damaged_target and silently
	## report "nothing damaged" for gear the character is visibly carrying.
	if not is_inside_tree():
		return []
	var gs = get_node_or_null("/root/GameState")
	if not gs or gs.current_campaign == null:
		return []
	var campaign = gs.current_campaign
	var data: Variant = null
	if campaign is Dictionary:
		data = campaign.get("equipment_data", null)
	elif "equipment_data" in campaign:
		data = campaign.equipment_data
	if not (data is Dictionary):
		return []
	var items: Variant = data.get("equipment", null)
	return items if items is Array else []


func _first_damaged_target(crew_member) -> Dictionary:
	## p.78 Repair Your Kit: "If you have had items destroyed, you can attempt to
	## Repair them." The book draws no line between gear a character carries and
	## gear in the Stash, and BOTH can now be damaged, so both are searched.
	##
	## Damage has two representations because the two containers are different
	## shapes, and each was chosen to match readers that already existed:
	##   carried — a status_effects entry {type: "item_damaged", damaged_item:
	##             <name>} on the owner. Written by Character Events (p.129
	##             "Don't Make Them Like They Used To"), travel events (p.71
	##             Accident) and, since the p.122 fix, the Injury Table.
	##   stash   — `damaged: true` on the item dict. Written by Campaign Event
	##             45-48 (p.127) and already read by the "[DAMAGED]" suffix in
	##             Assign Equipment and the sell-list exclusion in Purchase Items.
	##
	## Carried gear is checked first: the acting character's own broken weapon is
	## the more urgent fix, and it is what the p.78 wording most directly evokes.
	for eff in _member_get(crew_member, "status_effects", []):
		if str(eff.get("type", "")) != "item_damaged":
			continue
		var item_name: String = str(eff.get("damaged_item", "")).strip_edges()
		if not item_name.is_empty():
			return {"name": item_name, "source": "character"}

	return _first_damaged_in_stash(_stash_items())


static func _first_damaged_in_stash(stash: Array) -> Dictionary:
	for i in range(stash.size()):
		var entry: Variant = stash[i]
		# Was `entry.get("damaged")` only, so p.131 damaged Loot (which the
		# resolver marked `needs_repair`) was invisible to Repair Your Kit —
		# a fifth of all loot arrived broken and could never be fixed.
		if EquipmentTransferService.is_item_damaged(entry):
			var stash_name: String = str(entry.get("name", "")).strip_edges()
			if not stash_name.is_empty():
				return {"name": stash_name, "source": "stash", "index": i}
	return {}


func _resolve_damaged_target(crew_member, target: Dictionary, repaired: bool) -> void:
	## Clear the damage. On a natural 1 the item is "beyond fixing" (p.78), so it
	## leaves the game entirely rather than sitting in the list forever.
	if str(target.get("source", "")) == "stash":
		_resolve_damaged_stash_item(_stash_items(), target, repaired)
		return
	_resolve_damaged_item(crew_member, str(target.get("name", "")), repaired)


static func _resolve_damaged_stash_item(
		stash: Array, target: Dictionary, repaired: bool) -> void:
	var idx: int = int(target.get("index", -1))
	var item_name: String = str(target.get("name", ""))
	# The index was captured before the roll; re-verify rather than trust it, since
	# a stash mutation in between would repair or delete the wrong item.
	if idx < 0 or idx >= stash.size() \
			or not (stash[idx] is Dictionary) \
			or str(stash[idx].get("name", "")) != item_name:
		idx = -1
		for i in range(stash.size()):
			if stash[i] is Dictionary and str(stash[i].get("name", "")) == item_name \
					and EquipmentTransferService.is_item_damaged(stash[i]):
				idx = i
				break
	if idx < 0:
		return
	if repaired:
		# p.78: "the item is repaired and is usable again." Both damage spellings
		# must be cleared or the item stays broken to half its readers.
		stash[idx]["damaged"] = false
		stash[idx].erase("needs_repair")
		stash[idx].erase("damage_source")
		if str(stash[idx].get("quality", "")) == "damaged":
			stash[idx]["quality"] = "standard"
		var repaired_name: String = str(stash[idx].get("name", ""))
		if str(stash[idx].get("description", "")).ends_with(" (needs Repair)"):
			stash[idx]["description"] = repaired_name
	else:
		stash.remove_at(idx)


func _resolve_damaged_item(crew_member, item_name: String, repaired: bool) -> void:
	## Clear the item_damaged marker. On a natural 1 the item is "beyond fixing",
	## so it also leaves the character's kit.
	##
	## crew_data holds the SAME Dictionary references as campaign
	## crew_data["members"] (GameState.get_active_crew() returns the live array and
	## initialize_crew_tasks() takes a SHALLOW duplicate), so mutating the member
	## here writes through to the campaign.
	var effects = _member_get(crew_member, "status_effects", [])
	if effects is Array:
		for i in range(effects.size() - 1, -1, -1):
			var eff = effects[i]
			if eff is Dictionary and str(eff.get("type", "")) == "item_damaged" \
					and str(eff.get("damaged_item", "")) == item_name:
				effects.remove_at(i)
				break

	if repaired:
		return

	# Beyond fixing: remove it from the character's equipment. Character.equipment
	# is Array[String] of item names, so match on the name.
	var equipment = _member_get(crew_member, "equipment", [])
	if equipment is Array:
		for i in range(equipment.size() - 1, -1, -1):
			var entry = equipment[i]
			var entry_name: String = str(entry.get("name", "")) \
				if entry is Dictionary else str(entry)
			if entry_name == item_name:
				equipment.remove_at(i)
				break

## D100 through the DiceManager autoload when present, so crew-task table
## rolls appear in the roll history and can be forced by the debug QA seam.
## Behaviour-neutral: roll_d100() is a single randi_range(1, 100) draw, the
## same one this used to make inline.
func _roll_task_d100(context: String) -> int:
	var dm: Node = get_node_or_null("/root/DiceManager")
	if dm != null and dm.has_method("roll_d100"):
		return int(dm.roll_d100(context))
	return randi() % 100 + 1

func _get_trade_table_result(roll: int) -> Dictionary:
	## Get result from Trade Table (Core Rules p.79) — loaded from JSON via DataManager
	var dm: Node = get_node_or_null("/root/DataManager")
	if dm and dm.has_method("get_trade_table_result"):
		var json_result: Dictionary = dm.get_trade_table_result(roll)
		if not json_result.is_empty():
			var result: Dictionary = _build_result_from_json(json_result)
			_apply_runtime_rolls_trade(result, roll)
			return result
	# Fallback: return minimal result if DataManager unavailable
	push_warning("CrewTaskComponent: DataManager unavailable for trade table lookup (roll %d)" % roll)
	return {"name": "Unknown Trade Result", "effect": "DataManager unavailable", "credits": 0, "xp": 0, "items": [], "story_points": 0, "deferred_trigger": "", "single_use": false, "requires_roll": false, "roll_info": ""}

func _get_exploration_table_result(roll: int) -> Dictionary:
	## Get result from Exploration Table (Core Rules p.80) — loaded from JSON via DataManager
	var dm: Node = get_node_or_null("/root/DataManager")
	if dm and dm.has_method("get_exploration_table_result"):
		var json_result: Dictionary = dm.get_exploration_table_result(roll)
		if not json_result.is_empty():
			var result: Dictionary = _build_result_from_json(json_result)
			_apply_runtime_rolls_exploration(result, roll)
			return result
	push_warning("CrewTaskComponent: DataManager unavailable for exploration table lookup (roll %d)" % roll)
	return {"name": "Unknown Exploration Result", "effect": "DataManager unavailable", "credits": 0, "xp": 0, "items": [], "story_points": 0, "deferred_trigger": "", "single_use": false, "requires_roll": false, "roll_info": "", "sick_bay_turns": 0, "rumor": false, "rival": false, "patron": false}

func _build_result_from_json(json_entry: Dictionary) -> Dictionary:
	## Convert a JSON table entry into the standard result Dictionary format
	var result: Dictionary = {
		"name": str(json_entry.get("name", "")),
		"effect": str(json_entry.get("effect", "")),
		"credits": json_entry.get("credits", 0) as int,
		"xp": json_entry.get("xp", 0) as int,
		"items": [],
		"story_points": json_entry.get("story_points", 0) as int,
		"deferred_trigger": str(json_entry.get("deferred_trigger", "")),
		"single_use": json_entry.get("single_use", false),
		"requires_roll": json_entry.get("requires_roll", false),
		"roll_info": str(json_entry.get("roll_info", "")),
		# Exploration-specific fields
		"sick_bay_turns": json_entry.get("sick_bay_turns", 0) as int,
		"rumor": json_entry.get("rumor", false),
		"rival": json_entry.get("rival", false),
		"patron": json_entry.get("patron", false),
	}
	# Copy items array (JSON stores as Array of Strings)
	var json_items: Array = json_entry.get("items", [])
	for item in json_items:
		result.items.append(str(item))

	# Pass through metadata fields for event processing
	# These drive species immunity, purchases, bonuses, and narrative effects
	for key in ["immune_species", "recruit", "track_rival", "kerin_bonus",
			"precursor_bonus", "engineer_bonus", "buy_rumors", "buy_weapons",
			"pay_or_lose"]:
		if json_entry.has(key):
			result[key] = json_entry[key]

	return result

func _apply_runtime_rolls_trade(result: Dictionary, roll: int) -> void:
	## Apply runtime dice rolls for Trade Table entries that have dynamic outcomes
	## These entries have requires_roll=true and need actual dice resolution
	var entry_name: String = result.get("name", "")

	# ── Entries that send you to ANOTHER table (Core Rules pp.79-80) ──────────
	#
	# Six entries — rolls 1-3, 7-9, 45-48, 79-81, 82-86 and 87-91, so 23 results
	# in 100 — awarded literally nothing. Their JSON rows carry `requires_roll`
	# and no `items`, and none of them had a case in this match, so the dialog
	# printed "Roll once on the Loot Table (p.131)" as flavour text and the crew
	# came home empty-handed. Roughly one Trade action in four was a visible
	# no-op, which is the single most common thing a crew does in the World step.
	#
	# The "(random...)" strings are the established convention consumed by
	# _resolve_random_loot() -> _add_item_to_stash(); "damaged" in the string is
	# what flags an item as needing Repair. Nothing new is invented here — the
	# resolution machinery already existed, these entries just never reached it.
	match entry_name:
		"A personal weapon":
			# p.79 roll 1-3: "Roll once on the Low Tech Weapon Table (p.28)."
			result.items = ["Low Tech Weapon (random)"]
		"Find something useful":
			# p.79 roll 7-9: "Roll once on the Gear Table (p.29)."
			result.items = ["Gear Table (random)"]
		"Something interesting":
			# p.79 roll 45-48: "Roll once on the Loot Table (p.131)."
			result.items = ["Loot (random)"]
		"A lot of blinking lights":
			# p.80 roll 79-81: "Roll once on the Gear subsection of the Loot
			# Table (p.132)." A DIFFERENT table from the p.29 Gear Table above.
			result.items = ["Gear Loot (random)"]
		"Gently used":
			# p.80 roll 82-86: same Gear subsection, "The item is damaged and
			# needs Repair."
			result.items = ["Gear Loot (random, damaged)"]
		"Pre-owned":
			# p.80 roll 87-91: Loot Table, "The item is damaged and needs Repair."
			result.items = ["Loot (random, damaged)"]

	match entry_name:
		"Worthless trinket", "Useless trinket":
			var d6: int = randi() % 6 + 1
			if d6 == 6:
				result.story_points = 1
				result.effect += " - Rolled %d: SUCCESS!" % d6
			else:
				result.effect += " - Rolled %d: No luck" % d6
		"Contraband":
			var d6: int = randi() % 6 + 1
			result.credits = d6
			if d6 >= 4:
				result.effect = "Earned %d credits, but gained a Rival!" % d6
				result.rival = true
			else:
				result.effect = "Earned %d credits safely" % d6
		"Tourist garbage":
			var d6: int = randi() % 6 + 1
			if d6 >= 5:
				result.story_points = 1
				result.effect += " - Rolled %d: +1 story point!" % d6
			else:
				result.effect += " - Rolled %d: Worthless" % d6
		"Fuel":
			# D6 roll happens in the dialog (ROLL_FOR_CREDITS) — don't pre-roll
			result.effect = "Roll D6 for credits worth of fuel to offset travel costs"
		"Odd device":
			var d6: int = randi() % 6 + 1
			result.credits = -1
			if d6 == 6:
				result.items = ["Loot (random)"]
				result.effect = "Paid 1 credit - Rolled %d: It works!" % d6
			else:
				result.effect = "Paid 1 credit - Rolled %d: Complete garbage" % d6
		"Starship repair parts":
			# D6 roll happens in the dialog (ROLL_FOR_CREDITS) — don't pre-roll
			result.effect = "Roll D6 for credits worth of Hull Point repair parts"

func _apply_runtime_rolls_exploration(result: Dictionary, roll: int) -> void:
	## Apply runtime dice rolls for Exploration Table entries with dynamic outcomes
	var entry_name: String = result.get("name", "")

	match entry_name:
		"I know a good deal":
			# Recursively roll on trade table
			var trade_roll: int = randi() % 100 + 1
			var trade_result: Dictionary = _get_trade_table_result(trade_roll)
			result.name = "Good Deal: " + trade_result.name
			result.effect = trade_result.effect
			result.credits = trade_result.credits
			result.xp = trade_result.xp
			result.items = trade_result.items
			result.story_points = trade_result.story_points
		"Had a nice chat":
			var d6: int = randi() % 6 + 1
			if d6 >= 5:
				result.story_points = 1
				result.effect = "Nice chat - Rolled %d: +1 story point!" % d6
			else:
				result.effect = "Nice chat - Rolled %d: Pleasant but unproductive" % d6
		"Possible bargain":
			var d6: int = randi() % 6 + 1
			if d6 == 6:
				result.items = ["Loot (random)"]
				result.effect = "Traded weapon - Rolled %d: Got something good!" % d6
			else:
				result.credits = 1
				result.effect = "Traded weapon - Rolled %d: Got 1 credit" % d6
		"Completely lost":
			var d6: int = randi() % 6 + 1
			if d6 >= 4:
				result.effect = "Got lost - Rolled %d: Found way back in time" % d6
			else:
				result.effect = "Got lost - Rolled %d: Unable to participate in battle" % d6
		"Tech fanatic":
			var d6: int = randi() % 6 + 1
			if d6 >= 5:
				result.effect = "Tech help - Rolled %d: Item repaired for free!" % d6
			else:
				result.effect = "Tech help - Rolled %d: No luck with repair" % d6
		"Get in a bad fight":
			var turns: int = (randi() % 3) + 1
			result.sick_bay_turns = turns
			result.effect = "Bad fight - %d turns in Sick Bay, lose one item" % turns

## Deferred Event System - cache events for future triggers
func _get_current_turn_number() -> int:
	var cpm = get_node_or_null("/root/CampaignPhaseManager")
	if cpm and cpm.has_method("get_turn_number"):
		return cpm.get_turn_number()
	return 0

func _cache_deferred_event(trigger_type: String, event_name: String, crew_id: String, effect: Dictionary) -> void:
	## Cache a deferred event that will trigger on a future condition.
	##
	## Trigger types from Core Rules:
	## - NEW_PLANET: Triggers when crew arrives at new planet
	## - NEXT_TURN: Triggers at start of next campaign turn
	## - THIS_BATTLE: Triggers during next battle
	## - ON_QUEST: Triggers when undertaking a quest
	## - ON_RECRUIT: Triggers when recruiting crew
	## - PERSISTENT: Remains until used (trade goods, spare parts)
	var game_state = get_node_or_null("/root/GameState")
	if not game_state or not game_state.current_campaign:
		push_warning("Cannot cache deferred event - no GameState")
		return

	var campaign = game_state.current_campaign
	if not campaign:
		push_warning("Cannot cache deferred event - no campaign")
		return

	# Create event structure
	var event: Dictionary = {
		"id": str(Time.get_unix_time_from_system()) + "_" + str(randi() % 1000),
		"trigger_type": trigger_type,
		"event_name": event_name,
		"crew_id": crew_id,
		"effect": effect.duplicate(true),
		"turn_created": _get_current_turn_number(),
		"expires_turn": null, # null = never expires
		"consumed": false
	}

	# Handle expiration for certain trigger types
	if trigger_type == "NEXT_TURN":
		event.expires_turn = event.turn_created + 1

	# Add to campaign pending events via progress_data
	if "progress_data" in campaign:
		if not campaign.progress_data.has("pending_events"):
			campaign.progress_data["pending_events"] = []
		campaign.progress_data["pending_events"].append(event)
		pass # Cached deferred event
	elif campaign is Dictionary:
		if not campaign.has("pending_events"):
			campaign["pending_events"] = []
		campaign["pending_events"].append(event)
		pass # Cached deferred event (dict)
	else:
		push_warning("Cannot cache deferred event - no progress_data on campaign")

func _check_all_tasks_resolved() -> bool:
	## Check if all assigned tasks have been resolved
	for task_data: Dictionary in assigned_tasks.values():
		if not task_data.get("resolved", false):
			return false
	return true

func _calculate_success_rate() -> float:
	## Calculate success rate of completed tasks
	if completed_tasks.is_empty():
		return 0.0
	
	var successful_tasks: int = 0
	for result: Dictionary in completed_tasks:
		if result.get("success", false):
			successful_tasks += 1
	
	return float(successful_tasks) / float(completed_tasks.size()) * 100.0

## UI Updates
func _update_ui_state() -> void:
	## Update UI state based on current task assignments
	if assign_task_button:
		assign_task_button.disabled = all_tasks_resolved

	if resolve_all_button:
		resolve_all_button.disabled = assigned_tasks.is_empty() or all_tasks_resolved
		if all_tasks_resolved:
			resolve_all_button.text = "All Tasks Resolved"
		else:
			resolve_all_button.text = "Resolve All Tasks (%d)" % assigned_tasks.size()

	# p.78's paid extra Trade rolls and the p.73 Busy Markets roll. Refreshed from
	# HERE rather than only at build time because both gates move as the player
	# assigns tasks: the p.78 button must appear the moment someone is put on Trade.
	_refresh_trade_purchase_buttons()

	# Lock selection lists after resolution (no ItemList.disabled — use mouse_filter)
	if crew_member_list:
		crew_member_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if all_tasks_resolved else Control.MOUSE_FILTER_STOP
		crew_member_list.modulate.a = 0.5 if all_tasks_resolved else 1.0
	if available_tasks_list:
		available_tasks_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if all_tasks_resolved else Control.MOUSE_FILTER_STOP
		available_tasks_list.modulate.a = 0.5 if all_tasks_resolved else 1.0

func _update_progress_display() -> void:
	## Update progress display with task results
	if not progress_container:
		return

	# Clear existing progress display
	for child in progress_container.get_children():
		child.queue_free()

	# Summary header
	if completed_tasks.size() > 0:
		var success_count: int = 0
		var total_credits: int = 0
		var total_xp: int = 0
		for r in completed_tasks:
			if r.get("success", false):
				success_count += 1
			if r.has("table_result"):
				total_credits += r.table_result.get("credits", 0) as int
				total_xp += r.table_result.get("xp", 0) as int

		var summary_text = "Results: %d/%d succeeded" % [success_count, completed_tasks.size()]
		if total_credits > 0:
			summary_text += "  |  +%d credits" % total_credits
		if total_xp > 0:
			summary_text += "  |  +%d XP" % total_xp

		var summary_label = Label.new()
		summary_label.text = summary_text
		summary_label.add_theme_font_size_override("font_size", _scaled_font(16))
		if success_count == completed_tasks.size():
			summary_label.modulate = Color(0.063, 0.725, 0.506) # Emerald
		elif success_count > 0:
			summary_label.modulate = Color(0.851, 0.467, 0.024) # Orange
		else:
			summary_label.modulate = Color(0.863, 0.149, 0.149) # Red
		progress_container.add_child(summary_label)

		var summary_sep = HSeparator.new()
		summary_sep.modulate = Color(0.4, 0.6, 0.8)
		progress_container.add_child(summary_sep)

	# Show individual results
	for result in completed_tasks:
		var result_container = VBoxContainer.new()

		# Main result line
		var result_label = Label.new()
		var status_text = "✓" if result.success else "✗"
		var color = UIColors.COLOR_EMERALD if result.success else UIColors.COLOR_RED

		result_label.text = "%s %s - %s" % [
			status_text,
			result.crew_name,
			result.task_name
		]
		result_label.modulate = color
		result_container.add_child(result_label)

		# Show table result details for Trade/Explore tasks
		if result.has("table_result"):
			var table_data = result.table_result

			# Result name and effect
			var detail_label = Label.new()
			detail_label.text = "   → %s" % table_data.name
			detail_label.modulate = Color(0.8, 0.8, 1.0) # Light blue
			result_container.add_child(detail_label)

			var effect_label = Label.new()
			effect_label.text = "      %s" % table_data.effect
			effect_label.modulate = Color(0.7, 0.7, 0.7) # Gray
			effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			result_container.add_child(effect_label)

			# Show rewards summary
			var rewards: Array = []
			if table_data.get("credits", 0) > 0:
				rewards.append("+%d credits" % table_data.credits)
			if table_data.get("xp", 0) > 0:
				rewards.append("+%d XP" % table_data.xp)
			if table_data.get("story_points", 0) > 0:
				rewards.append("+%d story point" % table_data.story_points)
			if table_data.get("items", []).size() > 0:
				for item in table_data.items:
					rewards.append(item)
			if table_data.get("rumor", false):
				rewards.append("Quest Rumor")
			if table_data.get("patron", false):
				rewards.append("Patron Job")
			if table_data.get("rival", false):
				rewards.append("Rival (danger!)")
			if table_data.get("sick_bay_turns", 0) > 0:
				rewards.append("%d turns in Sick Bay" % table_data.sick_bay_turns)

			if rewards.size() > 0:
				var reward_label = Label.new()
				reward_label.text = "      Rewards: %s" % ", ".join(rewards)
				reward_label.modulate = Color(1.0, 0.9, 0.5) # Gold
				result_container.add_child(reward_label)
		else:
			# Standard result for non-table tasks
			if result.details != "":
				var detail_label = Label.new()
				detail_label.text = "   %s" % result.details
				detail_label.modulate = Color(0.7, 0.7, 0.7)
				result_container.add_child(detail_label)

			if result.reward != "None" and result.reward != "":
				var reward_label = Label.new()
				reward_label.text = "   Reward: %s" % result.reward
				reward_label.modulate = Color(1.0, 0.9, 0.5)
				result_container.add_child(reward_label)

		progress_container.add_child(result_container)

		# Add separator
		var separator = HSeparator.new()
		separator.modulate = Color(0.3, 0.3, 0.3)
		progress_container.add_child(separator)

## Choice Popup Flow — handles item choices from Trade/Explore task results

func _is_choice_item(item_string: String) -> bool:
	## Check if an item string contains OR-separated choices
	return " OR " in item_string

func _is_grenade_combination(item_string: String) -> bool:
	## Check if an item is the grenade combination special case
	return "Grenades" in item_string and ("Frakk" in item_string or "Dazzle" in item_string)

func _needs_player_input(item_string: String) -> bool:
	## Check if an item requires any form of player input (choice or grenade picker)
	return _is_choice_item(item_string) or _is_grenade_combination(item_string)

func _parse_choice_options(item_string: String) -> Array:
	## Split "A OR B OR C" into ["A", "B", "C"]
	var parts: Array = []
	for part in item_string.split(" OR "):
		parts.append(part.strip_edges())
	return parts

func _show_next_choice_popup() -> void:
	## Show the next pending choice popup, or finalize if none remain
	if _pending_choice_results.is_empty():
		_finalize_task_resolution()
		return

	var choice_data: Dictionary = _pending_choice_results[0]
	var choice_type: String = choice_data.get("type", "item_choice")

	# Auto-resolve mode: pick defaults without showing popup
	if _auto_resolve_mode:
		if choice_type == "grenade_combo":
			_on_grenades_chosen(3, 0, choice_data)
		else:
			var opts: Array = choice_data.get("options", [])
			var first: String = opts[0] if opts.size() > 0 else ""
			if not first.is_empty():
				_on_choice_made(first, choice_data)
			else:
				_pending_choice_results.erase(choice_data)
				_show_next_choice_popup()
		return

	if choice_type == "grenade_combo":
		var popup: Window = GrenadeCombinationPopupScript.new()
		popup.grenades_chosen.connect(
			_on_grenades_chosen.bind(choice_data)
		)
		add_child(popup)
		_choice_popup = popup
		popup.show_grenade_picker()
	else:
		var popup: Window = ItemChoicePopupScript.new()
		popup.item_chosen.connect(_on_choice_made.bind(choice_data))
		add_child(popup)
		_choice_popup = popup
		var result_name: String = ""
		if choice_data.result.has("table_result"):
			result_name = choice_data.result.table_result.get("name", "")
		popup.show_choices(
			result_name, choice_data.get("options", [])
		)

func _on_choice_made(item_name: String, choice_data: Dictionary) -> void:
	## Handle player's item choice — add to stash and advance queue
	_add_item_to_stash(item_name)

	# Replace "A OR B OR C" with chosen item name in the result for display
	var items: Array = choice_data.result.table_result.get("items", [])
	var idx: int = items.find(choice_data.item_string)
	if idx >= 0:
		items[idx] = item_name

	_pending_choice_results.erase(choice_data)
	_choice_popup = null
	_update_progress_display()
	_show_next_choice_popup()

func _on_grenades_chosen(
	frakk: int, dazzle: int, choice_data: Dictionary
) -> void:
	## Handle grenade combination choice — add grenades to stash
	for i in range(frakk):
		_add_item_to_stash("Frakk Grenade")
	for i in range(dazzle):
		_add_item_to_stash("Dazzle Grenade")

	# Update display text
	var items: Array = choice_data.result.table_result.get("items", [])
	var idx: int = items.find(choice_data.item_string)
	var summary: String = ""
	if frakk > 0:
		summary += "%dx Frakk" % frakk
	if dazzle > 0:
		if not summary.is_empty():
			summary += " + "
		summary += "%dx Dazzle" % dazzle
	if idx >= 0:
		items[idx] = summary

	_pending_choice_results.erase(choice_data)
	_choice_popup = null
	_update_progress_display()
	_show_next_choice_popup()

func _add_consumable_credits(pool_key: String, amount: int) -> void:
	## Store special-purpose credits in campaign progress_data.
	## Core Rules p.79: Fuel = offset travel costs. Repair parts = Hull Point repairs.
	## These are consumed when the relevant cost is paid, not general credits.
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.campaign or not "progress_data" in gs.campaign:
		# Fallback: add as general credits if no progress_data
		var gsm = get_node_or_null("/root/GameStateManager")
		if gsm:
			gsm.add_credits(amount)
		return
	var current: int = int(gs.campaign.progress_data.get(pool_key, 0))
	gs.campaign.progress_data[pool_key] = current + amount

func _add_item_to_stash(item_name: String) -> void:
	## Add an item to the ship stash via EquipmentManager
	## Resolves "(random)" items via loot table rolls first
	var equip_mgr: Node = get_node_or_null("/root/EquipmentManager")
	if not equip_mgr or not equip_mgr.has_method("add_equipment"):
		push_warning(
			"CrewTaskComponent: No EquipmentManager for '%s'" % item_name
		)
		return

	# Handle quantity prefixes like "2x Stim-pack"
	var quantity: int = 1
	var clean_name: String = item_name
	if item_name.begins_with("2x ") or item_name.begins_with("3x "):
		quantity = item_name.substr(0, 1).to_int()
		clean_name = item_name.substr(3)

	# Resolve random loot items
	if "(random" in clean_name:
		var is_damaged: bool = "damaged" in clean_name
		var resolved: Array = _resolve_random_loot(clean_name)
		for resolved_name in resolved:
			var item_dict: Dictionary = _lookup_equipment_from_db(
				equip_mgr, resolved_name
			)
			item_dict["id"] = "task_reward_%d_%d" % [
				Time.get_ticks_msec(), randi() % 10000
			]
			if is_damaged:
				item_dict["condition"] = "damaged"
			equip_mgr.add_equipment(item_dict)
		return

	# Standard item addition (with quantity support)
	for i in range(quantity):
		var item_dict: Dictionary = _lookup_equipment_from_db(
			equip_mgr, clean_name
		)
		item_dict["id"] = "task_reward_%d_%d" % [
			Time.get_ticks_msec(), randi() % 10000
		]
		if not equip_mgr.add_equipment(item_dict):
			push_warning(
				"CrewTaskComponent: Failed to add '%s' to stash"
				% clean_name
			)

func _lookup_equipment_from_db(
	equip_mgr: Node, item_name: String
) -> Dictionary:
	## Search EquipmentManager's loaded DB arrays by name
	for db_list in [
		equip_mgr._db_weapons,
		equip_mgr._db_armor,
		equip_mgr._db_gear
	]:
		for item in db_list:
			if item is Dictionary and item.get("name", "") == item_name:
				return item.duplicate()
	# Fallback: minimal dict for items not in DB
	return {"name": item_name}

## Loot Table Resolution — rolls on loot_tables.json subtables

var _loot_tables_cache: Dictionary = {}

func _get_loot_tables() -> Dictionary:
	## Load and cache loot_tables.json
	if not _loot_tables_cache.is_empty():
		return _loot_tables_cache
	var path := "res://data/loot_tables.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("CrewTaskComponent: Cannot open loot_tables.json")
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("CrewTaskComponent: Failed to parse loot_tables.json")
		return {}
	file.close()
	if json.data is Dictionary:
		_loot_tables_cache = json.data
	return _loot_tables_cache

func _resolve_random_loot(item_string: String) -> Array:
	## Resolve a "(random)" item string into actual item names
	## Returns Array of item name strings
	var tables: Dictionary = _get_loot_tables()
	if tables.is_empty():
		return [item_string] # Can't resolve, return as-is

	var all_tables: Dictionary = tables.get("tables", {})

	# Determine which subtable to roll on
	if item_string.begins_with("Gear Loot") or item_string == "Gear (random)":
		return [_roll_on_subtable(all_tables.get("gear_subtable", []))]
	elif item_string.begins_with("Gadget"):
		# p.29 Gadget Table — its own 22-row D100 table in gear_database.json, and
		# the only thing "Roll on the Gadget Table" (exploration_table.json) can
		# mean. This used to merge the LOOT table's gun_mods + gun_sights lists
		# and pick uniformly from the 13 results — the wrong table, and no D100
		# on it either. Same mistake, same fix, as the two branches below.
		return _roll_creation_table("gadget", item_string)
	elif item_string.begins_with("Low Tech Weapon"):
		# Core Rules p.28 has its OWN Low-Tech Weapon Table, and the Trade Table
		# (p.79, roll 1-3) points at that one by page number. This used to pull a
		# melee weapon out of the LOOT table's melee_weapons subtable instead, so
		# "A personal weapon" handed over a Power Claw, Suppression Maul, Glare
		# Sword or Ripper Sword — the wrong table entirely, and a far better item
		# than the book's Handgun / Scrap Pistol / Colony Rifle / Shotgun / Blade.
		return _roll_creation_table("low_tech_weapon", item_string)
	elif item_string.begins_with("Gear Table"):
		# p.29 Gear Table — also its own table, distinct from the p.132 Gear
		# subsection of the Loot Table that "Gear Loot" above resolves.
		return _roll_creation_table("gear", item_string)
	else:
		# Full loot table: roll D100 on main, then roll on subtable
		return _roll_main_loot_table(all_tables)

## Roll once on one of the CHARACTER-CREATION D100 tables in gear_database.json
## (Core Rules pp.28-29: Low-Tech Weapon, Military Weapon, High-Tech Weapon,
## Gear, Gadget). These are a different set of tables from the post-battle Loot
## Table in loot_tables.json, and several Trade Table entries cite them by page.
## Reuses StartingEquipmentGenerator so there is one roller per table, not two.
func _roll_creation_table(table_name: String, fallback: String) -> Array:
	var dice_manager: Node = get_node_or_null("/root/DiceManager")
	var rolled: Array = StartingEquipmentGeneratorClass.generate_bonus_equipment(
		[table_name], dice_manager)
	var names: Array = []
	for item in rolled:
		var item_name: String = str(item.get("name", "")) if item is Dictionary else str(item)
		if not item_name.is_empty():
			names.append(item_name)
	return names if not names.is_empty() else [fallback]

func _roll_main_loot_table(all_tables: Dictionary) -> Array:
	## Roll on the main loot table and resolve to actual items
	var main_table: Array = all_tables.get("main_loot", [])
	var roll: int = randi() % 100 + 1
	var category: String = ""
	var count: int = 1

	for entry in main_table:
		if entry is Dictionary:
			var r: Array = entry.get("roll_range", [0, 0])
			if r.size() >= 2 and roll >= (r[0] as int) and roll <= (r[1] as int):
				category = str(entry.get("category", ""))
				count = entry.get("count", 1) as int
				break

	var results: Array = []
	match category:
		"WEAPON", "DAMAGED_WEAPONS":
			var sub: Array = all_tables.get("weapon_subtable", [])
			for i in range(count):
				results.append(_roll_on_subtable(sub))
		"GEAR", "DAMAGED_GEAR":
			var sub: Array = all_tables.get("gear_subtable", [])
			for i in range(count):
				results.append(_roll_on_subtable(sub))
		"ODDS_AND_ENDS":
			var sub: Array = all_tables.get("odds_and_ends_subtable", [])
			results.append(_roll_on_subtable(sub))
		"REWARDS":
			# Rewards give credits/rumors, not equipment items
			var sub: Array = all_tables.get("rewards_subtable", [])
			var reward: Dictionary = _roll_on_reward_subtable(sub)
			if reward.get("credits", 0) > 0:
				var gsm: Node = get_node_or_null("/root/GameStateManager")
				if gsm and gsm.has_method("add_credits"):
					gsm.add_credits(reward.credits)
			# Rewards don't produce stash items
			return []
		_:
			return ["Loot (unknown category)"]

	return results

func _roll_on_subtable(subtable: Array) -> String:
	## Roll D100 to pick the subtable, then delegate the book's THIRD roll
	## (p.131 "and finally the exact item in question") to the canonical
	## resolver. This used to pick uniformly from the subtable's flat name list,
	## which is the same defect LootTableResolver had — one rule, three
	## implementations, all wrong the same way. There is one now.
	var roll: int = randi() % 100 + 1
	for entry in subtable:
		if entry is Dictionary:
			var r: Array = entry.get("roll_range", [0, 0])
			if r.size() >= 2 and roll >= (r[0] as int) and roll <= (r[1] as int):
				var rolled: String = LootTableResolverClass.roll_item_in(entry)
				if not rolled.is_empty():
					return rolled
				var item: String = str(entry.get("item", ""))
				if not item.is_empty():
					return item
	return "Unknown Loot"

func _roll_on_reward_subtable(subtable: Array) -> Dictionary:
	## Roll on reward subtable — returns credits/rumors dict
	var roll: int = randi() % 100 + 1
	for entry in subtable:
		if entry is Dictionary:
			var r: Array = entry.get("roll_range", [0, 0])
			if r.size() >= 2 and roll >= (r[0] as int) and roll <= (r[1] as int):
				return entry.duplicate()
	return {}

## Event Handlers
func _on_crew_member_selected(index: int) -> void:
	## Handle crew member selection
	_update_ui_state()

func _on_task_selected(index: int) -> void:
	## Handle task selection
	_update_ui_state()

func _on_phase_started(data: Dictionary) -> void:
	## Handle phase started events
	var phase_name = data.get("phase_name", "")
	if phase_name == "crew_tasks":
		pass

func _on_automation_toggled(data: Dictionary) -> void:
	## Handle automation toggle - auto-assign and resolve tasks
	## When automated, choice items auto-pick the first option (no popup shown)
	var automation_enabled = data.get("enabled", false)
	if automation_enabled and not assigned_tasks.is_empty():
		_auto_resolve_mode = true
		_on_resolve_all_pressed()
		_auto_resolve_mode = false

## Public API for integration
func are_tasks_completed() -> bool:
	## Check if all crew tasks are completed
	return all_tasks_resolved and not assigned_tasks.is_empty()

func is_tasks_completed() -> bool:
	## Alias for are_tasks_completed() - matches controller API
	return are_tasks_completed()

func get_blocker_hint() -> String:
	## Human-readable reason this step can't advance yet ("" if it can).
	if are_tasks_completed():
		return ""
	if assigned_tasks.is_empty():
		return "Assign at least one crew task, then \"Resolve All Tasks\"."
	if not all_tasks_resolved:
		return "Tap \"Resolve All Tasks\" to resolve your %d assigned task(s)." % assigned_tasks.size()
	return ""

func get_task_results() -> Array:
	## Get results of all completed tasks
	return completed_tasks.duplicate()

func get_assigned_task_count() -> int:
	## Get number of currently assigned tasks
	return assigned_tasks.size()

func reset_crew_tasks() -> void:
	## Reset crew tasks for new turn
	assigned_tasks.clear()
	completed_tasks.clear()
	task_assignments.clear()
	credits_spent_on_tasks.clear()
	all_tasks_resolved = false
	_populate_crew_list()
	_populate_available_tasks()
	_update_ui_state()

func complete_crew_task_phase() -> void:
	## Mark the crew task phase as complete and publish event
	if not all_tasks_resolved and not assigned_tasks.is_empty():
		_auto_resolve_mode = true # Auto-pick choices when force-completing
		_on_resolve_all_pressed()
		_auto_resolve_mode = false

	# Don't publish phase completion if events are still pending
	if not _event_queue.is_empty() or _current_event_dialog != null:
		push_warning("CrewTaskComponent: Cannot complete phase — events still pending")
		return

	if event_bus:
		event_bus.publish_event(CampaignTurnEventBus.TurnEvent.PHASE_COMPLETED, {
			"phase_name": "crew_tasks",
			"tasks_completed": completed_tasks.size(),
			"success_rate": _calculate_success_rate()
		})


static func credit_spend_allowed(cap: int, already_spent: int, amount: int) -> bool:
	## Whether `amount` more credits may be committed to a task.
	##
	## data/crew_tasks.json uses credit_bonus_max = -1 as a NO-CAP sentinel — its
	## sibling credit_bonus_note reads "Each credit spent = +1 (no cap stated)",
	## matching p.77's "Each credit earns a +1 bonus" with no ceiling given. The
	## caller used to test `if max_bonus <= 0: return false`, which caught the
	## sentinel and refused EVERY spend, so the book's main World Phase credit
	## sink did not exist. 0 still means the task takes no credits at all.
	##
	## Static and pure so it can be tested without the component in the tree —
	## spend_credits_on_task() resolves /root/GameStateManager, and an absolute
	## path lookup from a detached node errors and aborts the whole function.
	if amount <= 0:
		return false
	if cap == 0:
		return false
	if cap < 0:
		return true
	return already_spent + amount <= cap


func spend_credits_on_task(task_id: String, amount: int) -> bool:
	## Spend credits on a task for bonus modifier
	# Get task info
	var task: Dictionary = {}
	for t in available_crew_tasks:
		if t.get("id", "") == task_id:
			task = t
			break

	if task.is_empty():
		return false

	var max_bonus: int = int(task.get("credit_bonus", 0))
	var current_spent = credits_spent_on_tasks.get(task_id, 0)
	var total = current_spent + amount

	if not credit_spend_allowed(max_bonus, current_spent, amount):
		return false

	# Check GameStateManager has enough credits and deduct
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager:
		var available_credits = game_state_manager.get_credits()
		if available_credits < amount:
			push_warning("CrewTaskComponent: Not enough credits (%d available, need %d)" % [available_credits, amount])
			return false
		if not game_state_manager.remove_credits(amount):
			return false

	credits_spent_on_tasks[task_id] = total
	pass # Credits spent on task
	return true

## Helper function to apply XP to a character
## Core Rules p.78, Train: "If this means they may make a Character Upgrade ...
## resolve that immediately."
##
## Returns true when an upgrade is genuinely affordable, so the caller can say so
## in the task result even if the dialog is dismissed. Returns false — and pops
## nothing — otherwise: a single Train earns 1 XP and the cheapest p.123 upgrade
## costs 5, so most turns cross no threshold at all, and a dialog that appeared
## every turn to say "nothing affordable" would be worse than the bug this fixes.
func _offer_immediate_upgrade(crew_member: Dictionary) -> bool:
	var live: Dictionary = _live_crew_dict(crew_member)
	if live.is_empty():
		return false
	if not CharacterUpgradeDialogScript.has_upgrade_available(live):
		return false

	var dialog = CharacterUpgradeDialogScript.new()
	get_tree().root.add_child(dialog)
	dialog.upgrade_resolved.connect(
		func(_stat: String, summary: String) -> void:
			var who: String = str(live.get("name", live.get("character_name", "Crew")))
			_journal_note("%s trained: %s" % [who, summary]))
	dialog.show_for(live)
	return true


## The crew entry the campaign actually owns.
##
## `crew_data` normally holds the SAME Dictionary references as
## campaign.crew_data["members"], but _apply_xp_to_character deliberately re-looks
## the character up by id rather than trusting that — so this does too. An entry
## that resolves to a Character Resource returns {} rather than a converted copy:
## CharacterAdvancementService.advance_stat() mutates a Dictionary in place, and
## running it on a copy would show the player an upgrade that is thrown away.
func _live_crew_dict(crew_member: Dictionary) -> Dictionary:
	var character_id: String = str(crew_member.get("id",
		crew_member.get("character_id", "")))
	if character_id.is_empty():
		return {}
	var campaign = _active_campaign()
	if campaign == null or not campaign.has_method("get_crew_member_by_id"):
		return {}
	var entry: Variant = campaign.get_crew_member_by_id(character_id)
	return entry if entry is Dictionary else {}


func _journal_note(text: String) -> void:
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if journal == null or not journal.has_method("create_entry"):
		return
	journal.create_entry({
		"type": "character_event",
		"auto_generated": true,
		"title": "Character Upgrade",
		"description": text,
		"tags": ["training", "advancement"],
	})


func _apply_xp_to_character(crew_member: Dictionary, amount: int, source: String) -> void:
	## Apply XP to a character and persist to GameStateManager
	var character_id = crew_member.get("id", "")
	if character_id.is_empty():
		character_id = crew_member.get("character_id", "")

	if character_id.is_empty():
		push_warning("CrewTaskComponent: Cannot apply XP - no character ID found")
		return

	var game_state = get_node_or_null("/root/GameState")
	if not game_state or not game_state.current_campaign:
		push_warning("CrewTaskComponent: Cannot apply XP - no GameState")
		return

	var campaign = game_state.current_campaign
	if not campaign:
		push_warning("CrewTaskComponent: Cannot apply XP - no campaign")
		return

	# Find character in crew and apply XP
	# Try direct lookup first (FiveParsecsCampaignCore has get_crew_member_by_id)
	if campaign.has_method("get_crew_member_by_id"):
		var character = campaign.get_crew_member_by_id(character_id)
		if character:
			var current_xp = 0
			if character is Object and character.has_method("add_experience"):
				current_xp = character.experience if "experience" in character else 0
				character.add_experience(amount)
			elif character is Object and "experience" in character:
				current_xp = character.experience if character.experience else 0
				character.experience = current_xp + amount
			elif character is Dictionary:
				current_xp = character.get("experience", 0)
				character["experience"] = current_xp + amount
			pass # XP applied to character
			return

	# Fallback: iterate crew list
	var crew = []
	if campaign.has_method("get_crew_members"):
		crew = campaign.get_crew_members()
	elif campaign is Dictionary:
		crew = campaign.get("crew", [])

	for character in crew:
		# Sprint 26.3: Character-Everywhere - check Object/Character first
		var char_id = ""
		if character is Object and "character_id" in character:
			char_id = character.character_id
		elif character is Object and "id" in character:
			char_id = character.id
		elif character is Dictionary:
			char_id = character.get("id", character.get("character_id", ""))

		if char_id == character_id:
			# Sprint 26.3: Character-Everywhere - handle Character objects first
			# Sprint 27.4: Cleaned up dead xp code path - canonical property is 'experience'
			var current_xp = 0
			if character is Object and character.has_method("add_experience"):
				current_xp = character.experience if "experience" in character else 0
				character.add_experience(amount)
			elif character is Object and "experience" in character:
				current_xp = character.experience if character.experience else 0
				character.experience = current_xp + amount
			elif character is Dictionary:
				current_xp = character.get("experience", 0)
				character["experience"] = current_xp + amount

			pass # XP applied to character
			return

	push_warning("CrewTaskComponent: Character %s not found in crew" % character_id)

# ══════════════════════════════════════════════════════════════════════
# EVENT QUEUE SYSTEM — Interactive dialogs for crew task results
# ══════════════════════════════════════════════════════════════════════

func _build_event_queue() -> void:
	## Scan completed_tasks and build event descriptors for each table result.
	## Each descriptor drives a CrewTaskEventDialog instance.
	_event_queue.clear()

	for result in completed_tasks:
		if not result.has("table_result"):
			continue

		var tr: Dictionary = result.table_result
		var crew_id: String = str(result.get("crew_id", ""))
		var crew_name: String = str(result.get("crew_name", ""))
		var task_type: String = str(result.get("task_name", ""))
		var crew_member = _get_crew_member_by_id(crew_id)

		# Base event data shared by all types
		var base := {
			"crew_id": crew_id,
			"crew_name": crew_name,
			"crew_member": crew_member,
			"task_type": task_type,
			"event_name": tr.get("name", "Event"),
			"effect_text": tr.get("effect", ""),
			"table_result": tr,
			"result_ref": result,
		}

		# Check species immunity first
		if _check_species_immunity(tr, crew_member):
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.IMMUNE
			_event_queue.append(event)
			continue

		# Detect event type(s) from result fields — build events in order
		var events: Array[Dictionary] = _classify_result(base, tr, crew_member)
		_event_queue.append_array(events)

func _classify_result(base: Dictionary, tr: Dictionary, crew_member) -> Array[Dictionary]:
	## Classify a single table result into one or more event descriptors.
	var events: Array[Dictionary] = []
	var event_name: String = str(tr.get("name", ""))

	# ── Deferred events (show info badge, already cached by _resolve_table_task) ──
	var deferred: String = str(tr.get("deferred_trigger", ""))
	if not deferred.is_empty():
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.DEFERRED
		event["deferred_trigger"] = deferred
		events.append(event)
		return events # Deferred events don't have immediate effects

	# ── Runtime roll events (requires_roll=true, already resolved by _apply_runtime_rolls) ──
	# These were pre-rolled — show the result in the dialog
	var requires_roll: bool = tr.get("requires_roll", false)

	# ── Check for specific named events with complex behavior ──
	match event_name:
		"A chance to unload some stuff":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.SELL_WEAPONS
			event["credits_per_item"] = 2
			event["equipment"] = _get_crew_weapons(crew_member)
			events.append(event)
			return events

		"Gambling problem":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.DISCARD_ITEM
			event["equipment"] = _get_crew_equipment(crew_member)
			events.append(event)
			return events

		"Get in a bad fight":
			# Compound: sick bay + discard
			var sick_event := base.duplicate()
			sick_event["type"] = CrewTaskEventDialog.EventType.SICK_BAY
			sick_event["sick_bay_turns"] = tr.get("sick_bay_turns", 1)
			events.append(sick_event)
			var discard_event := base.duplicate()
			discard_event["type"] = CrewTaskEventDialog.EventType.DISCARD_ITEM
			discard_event["equipment"] = _get_crew_equipment(crew_member)
			discard_event["event_name"] = "Get in a bad fight — Lose an item"
			events.append(discard_event)
			return events

		"Contraband":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ROLL_FOR_CREDITS_RISK
			events.append(event)
			return events

		"Possible bargain":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ITEM_TRADE
			event["trade_type"] = "weapon"
			event["equipment"] = _get_crew_weapons(crew_member)
			events.append(event)
			return events

		"Alien merchant":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ITEM_TRADE
			event["trade_type"] = "item"
			event["equipment"] = _get_crew_equipment(crew_member)
			events.append(event)
			return events

		"This place is rather nice, really":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.PAY_OR_LOSE
			event["pay_or_lose_data"] = tr.get("pay_or_lose", {"cost": "1 story point", "penalty": "crew member leaves"})
			events.append(event)
			return events

		"Tech fanatic":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.TECH_FANATIC
			var char_class: String = _get_crew_class(crew_member)
			event["is_engineer"] = char_class.to_lower() == "engineer"
			var equip: Array = _get_crew_equipment(crew_member)
			if equip.size() > 0:
				event["random_damaged_item"] = equip[randi() % equip.size()]
			events.append(event)
			return events

		"Completely lost":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.SKILL_CHECK
			event["stat_name"] = "Savvy"
			event["stat_modifier"] = _get_crew_stat(crew_member, "savvy")
			event["success_threshold"] = 4
			event["failure_text"] = "Lost — will miss the battle this turn"
			events.append(event)
			return events

		"Odd device":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.CONDITIONAL_PURCHASE
			event["purchase_cost"] = 1
			events.append(event)
			return events

		"Don't usually see these for sale":
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.CONDITIONAL_PURCHASE
			event["purchase_cost"] = 3
			events.append(event)
			return events

	# ── Check for buy_rumors / buy_weapons metadata ──
	if tr.has("buy_rumors"):
		var buy_data: Dictionary = tr.get("buy_rumors", {})
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.BUY_RUMORS
		event["max_quantity"] = buy_data.get("max", 3)
		event["cost_each"] = buy_data.get("cost_each", 2)
		events.append(event)
		return events

	if tr.has("buy_weapons"):
		var buy_data: Dictionary = tr.get("buy_weapons", {})
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.BUY_WEAPONS
		event["max_quantity"] = buy_data.get("max_rolls", 3)
		event["cost_each"] = buy_data.get("cost_each", 3)
		events.append(event)
		return events

	# ── Check for items with OR choices ──
	var items: Array = tr.get("items", [])
	for item_str in items:
		var s: String = str(item_str)
		if "Grenades" in s and ("Frakk" in s or "Dazzle" in s):
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.GRENADE_COMBO
			events.append(event)
			return events
		elif " OR " in s:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.CHOICE_ITEM
			event["choice_options"] = _parse_choice_options(s)
			event["choice_item_string"] = s
			events.append(event)
			return events

	# ── Items with (random) — roll on table ──
	for item_str in items:
		var s: String = str(item_str)
		if "(random" in s:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ROLL_ON_TABLE
			event["items_to_resolve"] = [s]
			events.append(event)
			return events

	# ── Roll-based events ──
	if requires_roll:
		var credits: int = tr.get("credits", 0)
		var sp: int = tr.get("story_points", 0)

		# Events where the dialog IS the roll (not pre-rolled)
		if event_name in ["Fuel", "Starship repair parts"]:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ROLL_FOR_CREDITS
			events.append(event)
			return events

		# Pre-resolved roll events — show results
		if credits != 0 and sp == 0:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ROLL_FOR_CREDITS
			event["credits"] = credits
			events.append(event)
		elif sp != 0 or event_name in ["Worthless trinket", "Useless trinket", "Tourist garbage", "Had a nice chat"]:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.ROLL_FOR_BONUS
			event["story_points"] = sp
			events.append(event)
		else:
			var event := base.duplicate()
			event["type"] = CrewTaskEventDialog.EventType.INFO_ONLY
			events.append(event)
		# Also check for rival flag from roll results (e.g., contraband)
		if tr.get("rival", false):
			var rival_event := base.duplicate()
			rival_event["type"] = CrewTaskEventDialog.EventType.GAIN_RIVAL
			rival_event["event_name"] = event_name + " — Rival"
			events.append(rival_event)
		return events

	# ── Simple non-choice items — roll on table silently ──
	if items.size() > 0:
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.ROLL_ON_TABLE
		event["items_to_resolve"] = items
		events.append(event)
		return events

	# ── Narrative flags ──
	if tr.get("recruit", false):
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.RECRUIT
		events.append(event)
		return events

	if tr.get("patron", false):
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_PATRON
		events.append(event)
		return events

	if tr.get("rival", false):
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_RIVAL
		event["kerin_bonus"] = str(tr.get("kerin_bonus", ""))
		events.append(event)
		return events

	if tr.get("rumor", false):
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_RUMOR
		event["precursor_bonus"] = str(tr.get("precursor_bonus", ""))
		events.append(event)
		return events

	if tr.get("sick_bay_turns", 0) > 0:
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.SICK_BAY
		event["sick_bay_turns"] = tr.get("sick_bay_turns", 1)
		events.append(event)
		return events

	# ── Static resource gains ──
	var credits: int = tr.get("credits", 0)
	var xp: int = tr.get("xp", 0)
	var sp: int = tr.get("story_points", 0)

	if credits > 0:
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_CREDITS
		event["credits"] = credits
		events.append(event)
	if xp > 0:
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_XP
		event["xp"] = xp
		events.append(event)
	if sp > 0:
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.GAIN_STORY_POINT
		event["story_points"] = sp
		events.append(event)

	# If nothing matched, show as info only
	if events.is_empty():
		var event := base.duplicate()
		event["type"] = CrewTaskEventDialog.EventType.INFO_ONLY
		events.append(event)

	return events

# ── Event Queue Processing ────────────────────────────────────────────

func _process_event_queue() -> void:
	## Start processing the event queue — shows first dialog
	if _event_queue.is_empty():
		_finalize_task_resolution()
		return
	_show_next_event_dialog()

func _show_next_event_dialog() -> void:
	## Pop front of queue and show dialog, or finalize if empty
	# Clean up any lingering dialog to avoid exclusive window conflicts
	if _current_event_dialog and is_instance_valid(_current_event_dialog):
		_current_event_dialog.queue_free()
		_current_event_dialog = null

	if _event_queue.is_empty():
		_finalize_task_resolution()
		return

	var event_data: Dictionary = _event_queue.pop_front()

	# Auto-resolve mode: skip dialogs, apply defaults
	if _auto_resolve_mode:
		_auto_resolve_event(event_data)
		_show_next_event_dialog()
		return

	# Narrative-mode branch (default ON): present outcome-independent
	# "acknowledge" events as a full-screen NarrativeScreen beat. Interactive
	# events (rolls/choices/pickers/trades) fall through to CrewTaskEventDialog,
	# which is the engine that produces the outcome dict _on_event_completed
	# needs. Routing those richer types through the narrative layer is the A3 sprint.
	var ev_type: int = event_data.get(
		"type", CrewTaskEventDialog.EventType.INFO_ONLY)
	if _narrative_events_enabled() and _is_narrative_friendly_event(ev_type):
		_present_crew_event_via_narrative(event_data)
		return

	var dialog: Window = CrewTaskEventDialogScript.new()
	dialog.event_completed.connect(_on_event_completed.bind(event_data))
	add_child(dialog)
	_current_event_dialog = dialog
	dialog.show_event(event_data)

func _on_event_completed(outcome: Dictionary, event_data: Dictionary) -> void:
	## Apply game state changes based on event outcome, then process next event
	if _current_event_dialog and is_instance_valid(_current_event_dialog):
		_current_event_dialog.queue_free()
	_current_event_dialog = null
	var event_type: int = event_data.get("type", CrewTaskEventDialog.EventType.INFO_ONLY)
	var crew_member = event_data.get("crew_member")
	var gsm = get_node_or_null("/root/GameStateManager")

	match event_type:
		CrewTaskEventDialog.EventType.GAIN_CREDITS:
			var credits: int = event_data.get("credits", 0)
			if credits > 0 and gsm:
				gsm.add_credits(credits)

		CrewTaskEventDialog.EventType.GAIN_XP:
			var xp: int = event_data.get("xp", 0)
			if xp > 0:
				_apply_xp_to_character(
					event_data.get("table_result", {}),
					xp,
					"crew_task_event"
				)

		CrewTaskEventDialog.EventType.GAIN_STORY_POINT:
			var sp: int = event_data.get("story_points", 0)
			if sp > 0 and gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(sp)

		CrewTaskEventDialog.EventType.ROLL_FOR_BONUS:
			var sp: int = outcome.get("story_points", 0)
			if sp > 0 and gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(sp)

		CrewTaskEventDialog.EventType.ROLL_FOR_CREDITS:
			var credits: int = outcome.get("credits", 0)
			var event_name_str: String = str(event_data.get("event_name", ""))
			if credits > 0:
				if event_name_str == "Fuel":
					# Core Rules p.79: Fuel offsets travel costs, not general credits
					_add_consumable_credits("fuel_credits", credits)
				elif event_name_str == "Starship repair parts":
					# Core Rules p.79: Repair parts only for Hull Point damage
					_add_consumable_credits("repair_part_credits", credits)
				elif gsm:
					gsm.add_credits(credits)

		CrewTaskEventDialog.EventType.ROLL_FOR_CREDITS_RISK:
			if not outcome.get("declined", false):
				var credits: int = outcome.get("credits", 0)
				if credits > 0 and gsm:
					gsm.add_credits(credits)
				# Rival is handled by the roll — check if roll >= 4
				# The dialog stores this in the outcome
				if outcome.get("rival", false):
					_apply_rival(event_data)

		CrewTaskEventDialog.EventType.ROLL_ON_TABLE:
			# Resolve loot items and add to stash
			var items_to_resolve: Array = event_data.get("items_to_resolve", [])
			for item_str in items_to_resolve:
				_add_item_to_stash(str(item_str))

		CrewTaskEventDialog.EventType.CONDITIONAL_PURCHASE:
			if outcome.get("purchased", false):
				var cost: int = event_data.get("purchase_cost", 0)
				if gsm:
					gsm.remove_credits(cost)
				# Roll on loot table (the dialog signals roll_requested)
				_add_item_to_stash("Loot (random)")

		CrewTaskEventDialog.EventType.CHOICE_ITEM:
			var item_name: String = str(outcome.get("item_name", ""))
			if not item_name.is_empty():
				_add_item_to_stash(item_name)

		CrewTaskEventDialog.EventType.GRENADE_COMBO:
			var frakk: int = outcome.get("frakk", 0)
			var dazzle: int = outcome.get("dazzle", 0)
			for i in range(frakk):
				_add_item_to_stash("Frakk Grenade")
			for i in range(dazzle):
				_add_item_to_stash("Dazzle Grenade")

		CrewTaskEventDialog.EventType.DISCARD_ITEM:
			var discarded: String = str(outcome.get("discarded_item", ""))
			if not discarded.is_empty():
				_remove_from_crew_equipment(crew_member, discarded)

		CrewTaskEventDialog.EventType.SELL_WEAPONS:
			var sold: Array = outcome.get("sold_items", [])
			for item in sold:
				_remove_from_crew_equipment(crew_member, str(item))
			var credits: int = outcome.get("credits", 0)
			if credits > 0 and gsm:
				gsm.add_credits(credits)

		CrewTaskEventDialog.EventType.SICK_BAY:
			var turns: int = event_data.get("sick_bay_turns", 1)
			_apply_sick_bay(crew_member, turns)

		CrewTaskEventDialog.EventType.GAIN_RIVAL:
			_apply_rival(event_data)

		CrewTaskEventDialog.EventType.GAIN_RUMOR:
			_apply_rumor(event_data, outcome)

		CrewTaskEventDialog.EventType.GAIN_PATRON:
			_add_patron_contact()

		CrewTaskEventDialog.EventType.RECRUIT:
			if outcome.get("recruit", false):
				_apply_recruit()

		CrewTaskEventDialog.EventType.BUY_RUMORS:
			var qty: int = outcome.get("quantity", 0)
			var total_cost: int = outcome.get("total_cost", 0)
			if total_cost > 0 and gsm:
				gsm.remove_credits(total_cost)
			for i in range(qty):
				_apply_rumor(event_data, {})

		CrewTaskEventDialog.EventType.BUY_WEAPONS:
			var qty: int = outcome.get("quantity", 0)
			var total_cost: int = outcome.get("total_cost", 0)
			if total_cost > 0 and gsm:
				gsm.remove_credits(total_cost)
			for i in range(qty):
				var weapon: String = _roll_on_military_weapons_table()
				_add_item_to_stash(weapon)

		CrewTaskEventDialog.EventType.SKILL_CHECK:
			if not outcome.get("success", true):
				# Failed skill check — apply penalty
				if crew_member:
					if crew_member is Dictionary:
						crew_member["misses_battle"] = true
					elif "misses_battle" in crew_member:
						crew_member.misses_battle = true

		CrewTaskEventDialog.EventType.ITEM_TRADE:
			if outcome.get("traded", false):
				var traded_item: String = str(outcome.get("traded_item", ""))
				if not traded_item.is_empty():
					_remove_from_crew_equipment(crew_member, traded_item)
				# Roll result handled by dialog → roll_requested
				# For "Possible bargain": roll already determined credits vs loot
				var credits: int = outcome.get("credits", 0)
				if credits > 0 and gsm:
					gsm.add_credits(credits)

		CrewTaskEventDialog.EventType.PAY_OR_LOSE:
			# Core Rules p.82, 97-100 "This place is rather nice, really":
			# "WHEN YOU ARE READY TO LEAVE THIS WORLD, unless it is being
			# Invaded, you must pay 1 story point or this crew member will decide
			# to stay behind. If they do, you can keep their equipment, though."
			#
			# T9-42: none of that happened here. `modify_story_progress(-1)`
			# clamps at 0, so at 0 story points the charge was a silent no-op and
			# the dialog still reported "Paid the cost" — the crew member was kept
			# for free. It was also charged NOW rather than at departure, with no
			# Invasion exemption, and `_remove_crew_member()` took the character's
			# equipment with them.
			#
			# The obligation is now recorded and settled at the single departure
			# chokepoint (UpkeepPhaseComponent._on_travel_pressed), where the
			# Invasion state is actually known. The player's answer here is a
			# PRE-COMMITMENT: it decides whether they intend to pay, and departure
			# decides whether they can.
			var obligation_id: String = str(event_data.get("crew_id", ""))
			if obligation_id.is_empty():
				obligation_id = crew_key(crew_member)  # see crew_key(): T9-40
			var obligation_name: String = str(_member_get(
				crew_member, "character_name", _member_get(
					crew_member, "name", "Crew member")))
			var gs_for_p82 = get_node_or_null("/root/GameState")
			var campaign_for_p82 = (gs_for_p82.current_campaign
				if gs_for_p82 else null)
			if campaign_for_p82:
				DepartureObligationClass.record(
					campaign_for_p82, obligation_id, obligation_name,
					bool(outcome.get("paid", false)))

		CrewTaskEventDialog.EventType.TECH_FANATIC:
			if outcome.get("engineer_bonus", false):
				_apply_xp_to_character(
					event_data.get("table_result", {}),
					2,
					"tech_fanatic_engineer"
				)
			# Damage/repair handled by dialog outcome

	_update_progress_display()
	# Defer to next frame so queue_free() clears the old exclusive dialog first
	call_deferred("_show_next_event_dialog")

# ── NarrativeScreen integration (Phase 4 — Crew task events) ──────────
# Toggle: SettingsManager.are_narrative_events_enabled() (default ON). Only
# outcome-independent events are routed here (see _is_narrative_friendly_event);
# their state is applied by _on_event_completed from event_data, so an empty
# outcome is correct. Interactive events keep using CrewTaskEventDialog.

func _narrative_events_enabled() -> bool:
	# Route through GameStateManager so per-campaign override is honored
	# (May 29 2026). Falls back to SettingsManager directly if GSM is absent.
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("are_narrative_events_enabled"):
		return bool(gsm.are_narrative_events_enabled())
	var settings = get_node_or_null("/root/SettingsManager")
	return settings != null \
		and settings.has_method("are_narrative_events_enabled") \
		and settings.are_narrative_events_enabled()


func _is_narrative_friendly_event(event_type: int) -> bool:
	# "Acknowledge" events whose state mutation reads from event_data (not the
	# dialog's outcome dict). Verified against the _on_event_completed dispatch.
	match event_type:
		CrewTaskEventDialog.EventType.INFO_ONLY, \
		CrewTaskEventDialog.EventType.GAIN_CREDITS, \
		CrewTaskEventDialog.EventType.GAIN_XP, \
		CrewTaskEventDialog.EventType.GAIN_STORY_POINT, \
		CrewTaskEventDialog.EventType.ROLL_ON_TABLE, \
		CrewTaskEventDialog.EventType.SICK_BAY, \
		CrewTaskEventDialog.EventType.GAIN_RIVAL, \
		CrewTaskEventDialog.EventType.GAIN_PATRON, \
		CrewTaskEventDialog.EventType.IMMUNE, \
		CrewTaskEventDialog.EventType.DEFERRED:
			return true
		_:
			return false


func _present_crew_event_via_narrative(event_data: Dictionary) -> void:
	var NarrativeScreenClass = load(NARRATIVE_SCREEN_PATH)
	if not NarrativeScreenClass:
		push_warning("CrewTaskComponent: narrative screen load failed; " \
			+ "applying event outcome directly")
		_on_event_completed({}, event_data)  # state from event_data, chain continues
		return
	var screen = NarrativeScreenClass.new()
	get_tree().root.add_child(screen)
	screen.narrative_completed.connect(
		_on_crew_event_narrative_done.bind(event_data))
	screen.skip_requested.connect(
		_on_crew_event_narrative_skipped.bind(event_data))
	screen.present(_crew_event_to_narrative_dict(event_data),
		_build_crew_narrative_context())


func _crew_event_to_narrative_dict(event_data: Dictionary) -> Dictionary:
	var event_name: String = str(event_data.get("event_name", "Crew Task"))
	var effect_text: String = str(event_data.get("effect_text", ""))
	var crew_name: String = str(event_data.get("crew_name", ""))
	var task_type: String = str(event_data.get("task_type", ""))
	var briefing: String = ""
	if not crew_name.is_empty() and not task_type.is_empty():
		briefing = "%s: %s" % [crew_name, task_type.capitalize()]
	elif not crew_name.is_empty():
		briefing = crew_name
	elif not task_type.is_empty():
		briefing = task_type.capitalize()
	return {
		"id": "crew_task_event",
		"title": event_name,
		"art_tag": "crew_task_event",
		"core_text": effect_text,
		"briefing_text": briefing,
		"advisor_role": "",
		"choices": [{"id": 0, "label": "Continue", "hint": ""}],
	}


func _build_crew_narrative_context() -> Dictionary:
	# World data lives on /root/PlanetDataManager (inner PlanetData .name/.traits).
	var planet_mgr = get_node_or_null("/root/PlanetDataManager")
	var planet = null
	if planet_mgr and planet_mgr.has_method("get_current_planet"):
		planet = planet_mgr.get_current_planet()
	var world_name: String = "Unknown"
	var world_traits: Array = []
	if planet:
		if "name" in planet:
			world_name = str(planet.get("name"))
		if "traits" in planet and planet.get("traits") is Array:
			world_traits = planet.get("traits")
	var crew: Array = []
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_crew_members"):
		crew = gs.get_crew_members()
	return {
		"world_name": world_name,
		"world_traits": world_traits,
		"crew": crew,
		"turn_number": 0,
	}


func _on_crew_event_narrative_done(_result: Dictionary, event_data: Dictionary) -> void:
	# Empty outcome is correct for narrative-friendly types (state comes from
	# event_data). _on_event_completed continues the chain via call_deferred.
	_on_event_completed({}, event_data)


func _on_crew_event_narrative_skipped(event_data: Dictionary) -> void:
	_on_event_completed({}, event_data)


func _auto_resolve_event(event_data: Dictionary) -> void:
	## Auto-resolve an event without showing dialog — sensible defaults
	var event_type: int = event_data.get("type", CrewTaskEventDialog.EventType.INFO_ONLY)
	var gsm = get_node_or_null("/root/GameStateManager")
	var crew_member = event_data.get("crew_member")

	match event_type:
		CrewTaskEventDialog.EventType.GAIN_CREDITS:
			var credits: int = event_data.get("credits", 0)
			if credits > 0 and gsm:
				gsm.add_credits(credits)
		CrewTaskEventDialog.EventType.GAIN_XP:
			var xp: int = event_data.get("xp", 0)
			if xp > 0:
				_apply_xp_to_character(event_data.get("table_result", {}), xp, "auto")
		CrewTaskEventDialog.EventType.GAIN_STORY_POINT:
			var sp: int = event_data.get("story_points", 0)
			if sp > 0 and gsm and gsm.has_method("add_story_points"):
				gsm.add_story_points(sp)
		CrewTaskEventDialog.EventType.ROLL_ON_TABLE:
			for item_str in event_data.get("items_to_resolve", []):
				_add_item_to_stash(str(item_str))
		CrewTaskEventDialog.EventType.CHOICE_ITEM:
			var opts: Array = event_data.get("choice_options", [])
			if opts.size() > 0:
				_add_item_to_stash(str(opts[0]))
		CrewTaskEventDialog.EventType.GRENADE_COMBO:
			for i in range(3):
				_add_item_to_stash("Frakk Grenade")
		CrewTaskEventDialog.EventType.GAIN_RIVAL:
			_apply_rival(event_data)
		CrewTaskEventDialog.EventType.GAIN_RUMOR:
			_apply_rumor(event_data, {})
		CrewTaskEventDialog.EventType.GAIN_PATRON:
			_add_patron_contact()
		CrewTaskEventDialog.EventType.SICK_BAY:
			_apply_sick_bay(crew_member, event_data.get("sick_bay_turns", 1))
		# Skip interactive types in auto mode (no selling, no discarding, no purchases)

# ── State Mutation Helpers ────────────────────────────────────────────

func _check_species_immunity(table_result: Dictionary, crew_member) -> bool:
	## Check if crew member's species makes them immune to this result
	var immune_list: Array = table_result.get("immune_species", [])
	if immune_list.is_empty():
		return false
	var species_name: String = _get_species_name(crew_member)
	for immune_species in immune_list:
		if str(immune_species).to_lower() == species_name.to_lower():
			return true
	return false

func _get_crew_member_by_id(crew_id: String):
	## Find crew member in crew_data by character_id
	for member in crew_data:
		var mid: String = ""
		if member is Dictionary:
			mid = str(member.get("character_id", member.get("id", "")))
		elif member is Object and "character_id" in member:
			mid = str(member.character_id)
		elif member is Object and "id" in member:
			mid = str(member.id)
		if mid == crew_id:
			return member
	return null

func _get_species_name(crew_member) -> String:
	## Get species/origin name as string from crew member (Object or Dict)
	if crew_member == null:
		return ""
	var origin = null
	if crew_member is Dictionary:
		origin = crew_member.get("origin", crew_member.get("species", ""))
	elif crew_member is Object:
		if "origin" in crew_member:
			origin = crew_member.origin
		elif "species" in crew_member:
			origin = crew_member.species
	if origin == null:
		return ""
	# Handle enum ordinal → string
	if origin is int:
		var keys: Array = GlobalEnums.Origin.keys()
		if origin >= 0 and origin < keys.size():
			return str(keys[origin])
		return ""
	return str(origin)

func _get_crew_equipment(crew_member) -> Array:
	## Get equipment array from crew member
	if crew_member == null:
		return []
	if crew_member is Dictionary:
		var equip = crew_member.get("equipment", [])
		return equip.duplicate() if equip is Array else []
	if crew_member is Object and "equipment" in crew_member:
		return crew_member.equipment.duplicate()
	return []

func _get_crew_weapons(crew_member) -> Array:
	## Get only weapon items from crew member's equipment
	var all_equip: Array = _get_crew_equipment(crew_member)
	var weapons: Array = []
	for item_name in all_equip:
		if _is_weapon(str(item_name)):
			weapons.append(item_name)
	return weapons

func _is_weapon(item_name: String) -> bool:
	## Check if item name is a weapon (matches Character.weapons getter heuristic)
	var lower: String = item_name.to_lower()
	for keyword in ["weapon", "rifle", "pistol", "blade", "gun", "sword",
			"flamer", "cannon", "laser", "saber", "axe", "maul", "claw"]:
		if keyword in lower:
			return true
	return false

func _get_crew_class(crew_member) -> String:
	## Get character class as string
	if crew_member == null:
		return ""
	if crew_member is Dictionary:
		return str(crew_member.get("character_class", crew_member.get("class", "")))
	if crew_member is Object and "character_class" in crew_member:
		return str(crew_member.character_class)
	return ""

func _get_crew_stat(crew_member, stat_name: String) -> int:
	## Get a stat value from crew member
	if crew_member == null:
		return 0
	if crew_member is Dictionary:
		return crew_member.get(stat_name, 0) as int
	if crew_member is Object and stat_name in crew_member:
		return crew_member.get(stat_name) as int
	return 0

func _remove_from_crew_equipment(crew_member, item_name: String) -> void:
	## Remove an item by NAME from a crew member's equipment array.
	##
	## ⚠ The array holds EITHER plain names (the `Array[String]` shape
	## `Character.to_dictionary()` produces) OR full item Dictionaries. A live save
	## pulled off the tablet Aug 13 2026 carries the latter, so the old
	## `if item_name in equip: equip.erase(item_name)` compared a String against
	## Dictionaries — never equal, so the erase never ran and the caller's penalty
	## silently did nothing.
	##
	## MEASURED: a "Bad fight - 2 turns in Sick Bay, lose one item" event announced
	## "Discarded: Military Rifle" and Zephyr Flynn's equipment was byte-identical
	## before and after. Every p.82 item loss routed through here was unenforced.
	##
	## Matching goes through the same `item_display_name()` the dialog labelled the
	## button with, so the thing removed is exactly the thing the player clicked.
	## Removes ONE entry — "lose one item" means one, even with duplicates.
	if crew_member == null or item_name.is_empty():
		return
	var equip: Array = []
	if crew_member is Dictionary:
		equip = crew_member.get("equipment", [])
	elif crew_member is Object and "equipment" in crew_member:
		equip = crew_member.equipment
	else:
		return
	for i in range(equip.size()):
		if CrewTaskEventDialogScript.item_display_name(equip[i]) == item_name:
			equip.remove_at(i)
			return

func _apply_sick_bay(crew_member, turns: int) -> void:
	## Place crew member in sick bay for `turns` campaign turns.
	##
	## THE DURATION WAS BEING THROWN AWAY. This wrote a bespoke
	## `sick_bay_turns_remaining` key that NOTHING reads, and added no entry to
	## `injuries` — but the recovery countdown
	## (CampaignPhaseManager._process_sick_bay_recovery) works by decrementing
	## each injury's `recovery_turns` and clears sick bay the moment `injuries`
	## is empty. With no injury entry that condition was true immediately, so a
	## crew member sent to Sick Bay for three turns walked out after one,
	## whatever the task rolled.
	##
	## The fix is to speak the countdown's language: an injuries entry carrying
	## the recovery turns. Both crew shapes, because a fresh campaign holds
	## Character Resources and a loaded save holds Dictionaries.
	if crew_member == null or turns <= 0:
		return

	var injury: Dictionary = {
		"type": "crew_task",
		"name": "Injured during crew tasks",
		"recovery_turns": turns,
	}

	if crew_member is Dictionary:
		crew_member["in_sick_bay"] = true
		crew_member["recovery_turns"] = turns
		crew_member["status"] = "injured"
		var injuries: Array = crew_member.get("injuries", [])
		if not (injuries is Array):
			injuries = []
		injuries.append(injury)
		crew_member["injuries"] = injuries
		return

	if crew_member is Object:
		if "status" in crew_member:
			crew_member.status = "injured"
		if "in_sick_bay" in crew_member:
			crew_member.in_sick_bay = true
		if "recovery_turns" in crew_member:
			crew_member.recovery_turns = turns
		if "injuries" in crew_member and crew_member.injuries is Array:
			crew_member.injuries.append(injury)

func _apply_rival(event_data: Dictionary) -> void:
	## Add a rival to the campaign via NPCTracker
	var npc_tracker = get_node_or_null("/root/NPCTracker")
	var rival_types: Array = ["Criminal", "Corporate", "Military", "Pirate", "Cult"]
	var rival_data: Dictionary = {
		"rival_id": "rival_task_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
		"name": "Rival %d" % (randi() % 100 + 1),
		"type": rival_types[randi() % rival_types.size()],
		"source": "crew_task",
		"hostility": randi() % 3 + 3,
		"resources": randi() % 3 + 1,
	}
	var kerin_bonus: String = str(event_data.get("kerin_bonus", ""))
	if not kerin_bonus.is_empty():
		rival_data["kerin_bonus"] = kerin_bonus

	if npc_tracker and npc_tracker.has_method("add_rival"):
		npc_tracker.add_rival(rival_data)
	else:
		# Fallback: add directly to campaign
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.current_campaign:
			var campaign = gs.current_campaign
			if campaign is Dictionary:
				if not campaign.has("rivals"):
					campaign["rivals"] = []
				campaign["rivals"].append(rival_data)
			elif "rivals" in campaign:
				campaign.rivals.append(rival_data)

func _apply_rumor(event_data: Dictionary, outcome: Dictionary) -> void:
	## Add a quest rumor to the campaign
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.current_campaign:
		return
	var campaign = gs.current_campaign
	var rumor_types: Array = [
		"An extracted data file", "An extracted data file",
		"Notebook with secret information", "Notebook with secret information",
		"Old map showing a location", "Old map showing a location",
		"A tip from a contact", "A tip from a contact",
		"An intercepted transmission", "An intercepted transmission"
	]
	var rumor_roll: int = randi() % 10
	var new_rumor: Dictionary = {
		"id": "rumor_task_%d_%d" % [Time.get_ticks_msec(), randi() % 1000],
		"type": rumor_roll + 1,
		"description": rumor_types[rumor_roll],
		"source": "crew_task",
		"created_turn": _get_current_turn_number()
	}
	if campaign is Dictionary:
		if not campaign.has("rumors"):
			campaign["rumors"] = []
		campaign["rumors"].append(new_rumor)
	elif "rumors" in campaign:
		campaign.rumors.append(new_rumor)

func _apply_recruit() -> void:
	## Add one recruit to the crew (Core Rules p.78), verbatim: "Each recruit rolls
	## using the random method in the character creation process (see p.14).
	## Recruits have the basic profile for their type, and come armed with a
	## Handgun. They do not roll on any of the random background tables in the
	## 'Character Creation' chapter."
	var gs = get_node_or_null("/root/GameState")
	if not gs or not gs.current_campaign:
		push_warning("CrewTaskComponent: Cannot recruit — no campaign")
		return
	var campaign = gs.current_campaign

	# Check crew size limit
	var crew_size: int = 0
	if campaign.has_method("get_crew_size"):
		crew_size = campaign.get_crew_size()
	if crew_size >= 8:
		push_warning("CrewTaskComponent: Crew is full (8 members)")
		return

	# Generate new character via CharacterGeneration
	var CharGen = load("res://src/core/character/CharacterGeneration.gd")
	if CharGen == null or not CharGen.has_method("create_character"):
		return

	# Core Rules p.74, verbatim: "Adventurous population — When successfully
	# Recruiting, you may roll up one additional character and THEN CHOOSE WHO TO
	# HIRE." `WorldTraitEffects.recruit_extra_candidates()` implemented this and
	# had ZERO callers, so the trait was a paragraph of text.
	#
	# The book says "choose", so the extra candidates are generated and offered —
	# auto-picking would turn a decision into a reroll.
	var extra: int = WorldTraitEffectsClass.recruit_extra_candidates(
		_current_world_traits())
	var candidates: Array = []
	for _i in range(1 + maxi(0, extra)):
		var rolled = CharGen.create_character({})
		if rolled == null:
			continue
		_apply_recruit_creation_tables(rolled)
		candidates.append(rolled)
	if candidates.is_empty():
		return

	if candidates.size() == 1:
		_hire_recruit(campaign, candidates[0])
		return
	_offer_recruit_choice(campaign, candidates)


## p.74 Adventurous population — present the rolled candidates and let the player
## pick. Falls back to hiring the first if the popup cannot be built, because the
## alternative is a successful Recruit task that silently hires nobody.
func _offer_recruit_choice(campaign, candidates: Array) -> void:
	var labels: Array = []
	for c: Variant in candidates:
		labels.append(_describe_recruit(c))
	var popup: Window = ItemChoicePopupScript.new()
	if popup == null:
		_hire_recruit(campaign, candidates[0])
		return
	popup.title = "Adventurous Population (p.74)"
	add_child(popup)
	popup.item_chosen.connect(
		func(chosen_label: String) -> void:
			var idx: int = labels.find(chosen_label)
			_hire_recruit(campaign, candidates[maxi(0, idx)]))
	popup.show_choices(
		"This world's adventurous population turns up more than one willing hand. "
			+ "Choose who to hire (Core Rules p.74).",
		labels, "Hire")


func _describe_recruit(new_char) -> String:
	var who: String = "Recruit"
	var species: String = ""
	if new_char is Object:
		if "character_name" in new_char:
			who = str(new_char.character_name)
		if "species_id" in new_char and str(new_char.species_id) != "":
			species = str(new_char.species_id)
		elif "origin" in new_char:
			species = str(new_char.origin)
	return "%s (%s)" % [who, species.capitalize().replace("_", " ")] if species != "" \
		else who


func _hire_recruit(campaign, new_char) -> void:
	if campaign == null or new_char == null:
		return
	if not campaign.has_method("add_crew_member"):
		return
	# ⚠ THE CONTACTS ARE GRANTED HERE, NOT WHEN THE CANDIDATE IS ROLLED.
	#
	# p.74 Adventurous population rolls up EXTRA candidates the player then picks
	# from, and `_apply_recruit_creation_tables()` runs on every one of them so
	# the player can compare real characters. Granting the errata's Rivals and
	# Patrons there would hand out the contacts of people who were never hired —
	# up to two extra Rivals for a single Recruit task, from candidates the player
	# rejected. The table rewards belong to the character who joins.
	if "creation_bonuses" in new_char and new_char.creation_bonuses is Dictionary:
		_grant_recruit_contacts(campaign, new_char, new_char.creation_bonuses)
	if new_char.has_method("to_dictionary"):
		campaign.add_crew_member(new_char.to_dictionary())
	else:
		campaign.add_crew_member(new_char)
	_notify_recruit_joined(new_char)


func _apply_recruit_creation_tables(new_char) -> void:
	## ERRATA v1.06 (Characters, Update), verbatim: "When adding a new character
	## to your crew, ROLL ON THE NORMAL CHARACTER CREATION TABLES as you would
	## when starting a new game but IGNORE ALL CREDITS that would have been
	## awarded normally. Any Rivals are added to your roster immediately. Any
	## Patrons are added to the list known and will award a job offer next turn
	## automatically."
	##
	## THIS SUPERSEDES p.78, which says a recruit "do[es] not roll on any of the
	## random background tables" and arrives with "the basic profile for their
	## type ... armed with a Handgun". The code implemented p.78 exactly, and the
	## designer has since replaced that rule — so a recruit was arriving with no
	## background, no motivation, no class, and none of the Patrons or Rivals the
	## tables hand out. The errata overturns the printed page; see
	## docs/gameplay/rules/5P_errata_and_tweaks106.pdf.
	##
	## Rolled through the STATIC table roller rather than the creation wizard:
	## `CharacterCreator` is a Control scene and this runs inside a World Phase
	## component, and `CharacterGeneration.roll_character_tables()` /
	## `apply_table_results_to_character()` are the same tables without the UI.
	## The result is stored in `creation_bonuses`, which stays the single home for
	## table rewards (CLAUDE.md's one-grant-site-per-rule rule).
	if new_char == null:
		return
	var CharGen = load("res://src/core/character/CharacterGeneration.gd")
	if CharGen == null or not CharGen.has_method("roll_character_tables"):
		return
	var rolled: Dictionary = CharGen.roll_character_tables()
	if CharGen.has_method("apply_table_results_to_character"):
		CharGen.apply_table_results_to_character(new_char, rolled)

	var res: Dictionary = rolled.get("resources", {})
	# "IGNORE ALL CREDITS that would have been awarded normally" — the one reward
	# the errata withholds. Everything else on the tables stands.
	var bonuses: Dictionary = {
		"bonus_credits": 0,
		"credits_dice_sources": [],
		"patrons": int(res.get("patrons", 0)),
		"rivals": int(res.get("rivals", 0)),
		"story_points": int(res.get("story_points", 0)),
		"quest_rumors": int(res.get("rumors", 0)),
		"xp": int(res.get("xp", 0)),
		"starting_rolls": (res.get("starting_rolls", []) as Array).duplicate(),
		"rolled_items": [],
		"source": "recruit_errata_v1_06",
	}
	if "creation_bonuses" in new_char:
		new_char.creation_bonuses = bonuses

	# The tables' XP is a per-character award, so it goes on the character.
	if int(bonuses["xp"]) > 0 and "experience" in new_char:
		new_char.experience = int(new_char.experience) + int(bonuses["xp"])

	_grant_recruit_equipment(new_char, bonuses["starting_rolls"])


func _grant_recruit_equipment(new_char, starting_rolls: Array) -> void:
	## p.78's Hand Gun stays the base — the errata replaces the "no background
	## rolls" clause, not the starting weapon — and the tables' equipment rolls
	## are added on top.
	##
	## Character.equipment is Array[String]; assigning an untyped array to a typed
	## property is REJECTED and the write is silently LOST, so .assign() is the
	## only safe route. "Hand Gun" is the canonical name in
	## data/equipment_database.json — "Handgun" resolves to nothing.
	if not ("equipment" in new_char):
		return
	var names: Array = ["Hand Gun"]
	if not starting_rolls.is_empty():
		var EquipGen = load("res://src/core/character/Equipment/StartingEquipmentGenerator.gd")
		if EquipGen and EquipGen.has_method("generate_bonus_equipment"):
			var dice: Node = get_node_or_null("/root/DiceManager")
			for item in EquipGen.generate_bonus_equipment(starting_rolls, dice):
				# `equipment` holds NAMES (Array[String]); appending an item
				# Dictionary is rejected and the item is LOST.
				if item is Dictionary:
					var item_name: String = str(item.get("name", ""))
					if not item_name.is_empty():
						names.append(item_name)
				elif item is String:
					names.append(item)
	var loadout: Array[String] = []
	loadout.assign(names)
	new_char.equipment = loadout


func _grant_recruit_contacts(campaign, new_char, bonuses: Dictionary) -> void:
	## Errata: "Any Rivals are added to your roster IMMEDIATELY. Any Patrons are
	## added to the list known and will award a job offer NEXT TURN
	## automatically."
	##
	## The follow-up offer is banked as a NAMED id in `patron_followup_offers`,
	## the same channel p.84 Busy and the creation patrons use, because
	## JobOfferComponent generates an offer from nowhere else. `patron_offers_owed`
	## would have been wrong: it draws a RANDOM existing patron.
	if campaign == null:
		return
	var CharGen = load("res://src/core/character/CharacterGeneration.gd")
	var who: String = ""
	if new_char != null and "character_name" in new_char:
		who = str(new_char.character_name)

	for _r in range(int(bonuses.get("rivals", 0))):
		var rival: Dictionary = {}
		if CharGen and CharGen.has_method("_create_starting_rival"):
			rival = CharGen._create_starting_rival(randi() % 1000, who)
		if rival.is_empty():
			continue
		if campaign.has_method("add_rival"):
			campaign.add_rival(rival)
		elif "rivals" in campaign and campaign.rivals is Array:
			campaign.rivals.append(rival)

	if int(bonuses.get("patrons", 0)) <= 0:
		return
	if not ("progress_data" in campaign) or not (campaign.progress_data is Dictionary):
		return
	var owed: Array = []
	var existing: Variant = campaign.progress_data.get("patron_followup_offers", [])
	if existing is Array:
		owed = (existing as Array).duplicate()
	for _p in range(int(bonuses.get("patrons", 0))):
		var patron: Dictionary = {}
		if CharGen and CharGen.has_method("_create_starting_patron"):
			patron = CharGen._create_starting_patron(randi() % 1000, who)
		if patron.is_empty():
			continue
		if "patrons" in campaign and campaign.patrons is Array:
			campaign.patrons.append(patron)
		var ident: String = str(patron.get("id", patron.get("name", "")))
		if not ident.is_empty() and not (ident in owed):
			owed.append(ident)
	campaign.progress_data["patron_followup_offers"] = owed


func _notify_recruit_joined(new_char) -> void:
	var recruit_name: String = "A new recruit"
	if new_char != null and "character_name" in new_char:
		recruit_name = str(new_char.character_name)
	var notif: Node = get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("show_success"):
		notif.show_success("%s joined the crew." % recruit_name)
	var journal: Node = get_node_or_null("/root/CampaignJournal")
	if journal and journal.has_method("create_entry"):
		journal.create_entry({
			"type": "event",
			"auto_generated": true,
			"title": "New recruit",
			"description": ("%s signed on with a Hand Gun and their own"
				+ " background, motivation and class (errata v1.06 replaces"
				+ " p.78's basic profile).") % recruit_name,
			"tags": ["crew", "recruit"],
		})

# `_remove_crew_member()` DELETED (T9-42). Its only caller was the PAY_OR_LOSE
# handler above, which now records a p.82 departure obligation instead, so this
# was genuinely dead rather than a missing wire — and it was the buggy version:
# it reached into the live members array with `remove_at()`, bypassing
# `FiveParsecsCampaignCore.remove_crew_member()` (the chokepoint that exists for
# this and rebuilds `_crew_id_index`), and it dropped the character without
# moving their equipment to the stash, which p.82 explicitly grants the player.
# Removal now happens in DepartureObligation, through the chokepoint.

func _roll_on_military_weapons_table() -> String:
	## Roll D100 on the Military Weapons table (Core Rules p.28).
	## Single source of truth: data/gear_database.json -> weapon_tables.military_weapon.
	var table: Array = _get_military_weapon_table()
	if table.is_empty():
		push_warning("CrewTaskComponent: military_weapon table missing from gear_database.json")
		return ""
	var roll: int = randi() % 100 + 1
	for entry in table:
		var roll_range: Array = entry.get("roll_range", [0, 0])
		if roll >= int(roll_range[0]) and roll <= int(roll_range[1]):
			return str(entry.get("name", ""))
	return str(table[table.size() - 1].get("name", ""))

static var _military_weapon_table_cache: Array = []
func _get_military_weapon_table() -> Array:
	if not _military_weapon_table_cache.is_empty():
		return _military_weapon_table_cache
	var file := FileAccess.open("res://data/gear_database.json", FileAccess.READ)
	if not file:
		push_error("CrewTaskComponent: Failed to open gear_database.json")
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("CrewTaskComponent: Failed to parse gear_database.json: %s" % json.get_error_message())
		return []
	var data: Dictionary = json.data if json.data is Dictionary else {}
	var weapon_tables: Dictionary = data.get("weapon_tables", {})
	_military_weapon_table_cache = weapon_tables.get("military_weapon", [])
	return _military_weapon_table_cache
