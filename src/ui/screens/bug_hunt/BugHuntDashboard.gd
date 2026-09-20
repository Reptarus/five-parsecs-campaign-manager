extends BugHuntScreenBase

## Bug Hunt Dashboard — Campaign overview screen.
## Uses CampaignScreenBase factory methods for glass cards, stat displays,
## character cards, and responsive layout.

const EmptyStateWidgetClass = preload("res://src/ui/components/common/EmptyStateWidget.gd")
const HubFeatureCardClass = preload("res://src/ui/components/common/HubFeatureCard.gd")
const SaveFileWriterRef = preload("res://src/core/state/SaveFileWriter.gd")
const TransferPanelClass = preload("res://src/ui/screens/bug_hunt/panels/CharacterTransferPanel.gd")
const QAScenarioDialogClass = preload("res://src/ui/screens/dev/QAScenarioDialog.gd")

var _campaign: Resource
var _content: VBoxContainer
var _play_btn: Control  # HubFeatureCard (extends Control, not Button)


func _setup_screen() -> void:
	_campaign = _get_bug_hunt_campaign()
	_build_dashboard()
	# Surface veterans mustered in from 5PFH or Planetfall (CampaignScreenBase).
	_check_pending_transfers.call_deferred()


## CampaignScreenBase hook — rebuild after veterans muster in.
func _on_transfers_applied() -> void:
	_rebuild()


func _build_dashboard() -> void:
	var layout := _create_scroll_layout()
	_content = layout.content

	if not _campaign or not "main_characters" in _campaign:
		var empty := EmptyStateWidgetClass.new()
		empty.setup(
			"No Active Bug Hunt",
			"The barracks are quiet. Create a new campaign to deploy your squad.",
			"New Bug Hunt",
			func(): _navigate("bug_hunt_creation"))
		_content.add_child(empty)
		_fix_touch_scroll_filters()
		return

	# ── Header ──────────────────────────────────────────────────────
	var name_str: String = _campaign.campaign_name if "campaign_name" in _campaign else "Unknown"
	var regiment: String = _campaign.regiment_name if "regiment_name" in _campaign else ""

	var header_box := VBoxContainer.new()
	header_box.add_theme_constant_override("separation", SPACING_XS)

	var title := Label.new()
	title.text = name_str
	title.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_XL + 4))
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Long campaign names must wrap, not clip, in narrow portrait (~384px).
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(title)

	if not regiment.is_empty():
		var reg_lbl := Label.new()
		reg_lbl.text = regiment
		reg_lbl.add_theme_font_size_override("font_size", get_responsive_font_size(FONT_SIZE_LG))
		reg_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		reg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header_box.add_child(reg_lbl)

	_content.add_child(header_box)

	# ── Stat Strip ──────────────────────────────────────────────────
	var turn: int = _campaign.campaign_turn if "campaign_turn" in _campaign else 0
	var rep: int = _campaign.reputation if "reputation" in _campaign else 0
	var chars: Array = _campaign.main_characters if "main_characters" in _campaign else []
	var grunts: Array = _campaign.grunts if "grunts" in _campaign else []
	var movie_remaining: int = 0
	if _campaign.has_method("get_available_movie_magic"):
		movie_remaining = _campaign.get_available_movie_magic().size()

	var stats := {"TURN": turn, "REP": rep, "MCs": chars.size(), "GRUNTS": grunts.size(), "MAGIC": movie_remaining}
	# Portrait phones (~384px) can't fit five 64px stat cards in one row (352px floor,
	# no horizontal scroll). Cap at 3 columns so they wrap to 3+2; stay 5-wide on desktop.
	var stat_cols: int = 3 if should_use_single_column() else mini(stats.size(), 5)
	var stat_grid := _create_stats_grid(stats, stat_cols)
	_content.add_child(stat_grid)

	# ── Navigation Hub Cards ────────────────────────────────────────
	var hub_box := VBoxContainer.new()
	hub_box.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(hub_box)

	var continue_card := HubFeatureCardClass.new()
	continue_card.setup("", "Continue Campaign", "Start the next campaign turn")
	continue_card.card_pressed.connect(func(): _navigate("bug_hunt_turn_controller"))
	hub_box.add_child(continue_card)
	_play_btn = continue_card  # Reference for breathe animation

	var save_card := HubFeatureCardClass.new()
	save_card.setup("", "Save Campaign", "Save current progress to disk")
	save_card.card_pressed.connect(_on_save)
	hub_box.add_child(save_card)

	var menu_card := HubFeatureCardClass.new()
	menu_card.setup("", "Main Menu", "Return to the main menu")
	menu_card.card_pressed.connect(func(): _navigate("main_menu"))
	hub_box.add_child(menu_card)

	# ── QA (debug builds only) ──────────────────────────────────────
	# Same gate as the 5PFH dashboard's QA button (CampaignDashboard.gd:262): a
	# release export physically cannot reach this, so there is no unlock to discover
	# and nothing to remember to switch off before shipping, while a remote-deploy
	# QA build IS a debug build and still gets it.
	#
	# A card rather than a header button because this screen is code-built from
	# HubFeatureCards and has no header bar to insert a sibling into.
	#
	# ⚠ The FIXTURES half of that dialog refuses to run in this mode, and the
	# subtitle says so rather than leaving a tester to press a disabled button and
	# guess why. Forcing a roll is mode-agnostic -- the queue lives on the
	# DiceManager autoload, not on a campaign -- and is what this is for here.
	if OS.is_debug_build():
		var qa_box := VBoxContainer.new()
		qa_box.add_theme_constant_override("separation", SPACING_SM)
		_content.add_child(qa_box)

		var qa_card := HubFeatureCardClass.new()
		qa_card.setup("", "QA - Force a Roll",
			"Debug build only. Queue a value for the next Bug Hunt table roll "
			+ "(Priority, Special Assignment, Support, Enlistment, Commendation, "
			+ "Origin, Basic Training, Service History). The 5PFH state fixtures are "
			+ "disabled in this mode.")
		qa_card.card_pressed.connect(_on_qa_pressed)
		qa_box.add_child(qa_card)

	# ── Character Transfer (Compendium pp.212-213) ──────────────────
	var transfer_box := VBoxContainer.new()
	transfer_box.add_theme_constant_override("separation", SPACING_SM)
	_content.add_child(transfer_box)

	var enlist_card := HubFeatureCardClass.new()
	enlist_card.setup("", "Enlist from 5PFH", "Transfer a Five Parsecs character into Bug Hunt (2D6+CS >= 7+)")
	enlist_card.card_pressed.connect(_on_enlist_pressed)
	transfer_box.add_child(enlist_card)

	var muster_card := HubFeatureCardClass.new()
	muster_card.setup("", "Muster Out to 5PFH", "Transfer a Bug Hunt character to a Five Parsecs campaign")
	muster_card.card_pressed.connect(_on_muster_out_pressed)
	transfer_box.add_child(muster_card)

	# ── Squad Roster ────────────────────────────────────────────────
	var sick_bay: Dictionary = _campaign.sick_bay if "sick_bay" in _campaign else {}
	var roster_content := VBoxContainer.new()
	roster_content.add_theme_constant_override("separation", SPACING_SM)

	for mc in chars:
		if mc is not Dictionary:
			continue
		var mc_name: String = mc.get("name", mc.get("character_name", "?"))
		var mc_stats := {
			"R": int(mc.get("reactions", 0)),
			"S": int(mc.get("speed", 0)),
			"CS": int(mc.get("combat_skill", 0)),
			"T": int(mc.get("toughness", 0)),
			"Sv": int(mc.get("savvy", 0))
		}
		var missions: int = mc.get("completed_missions_count", 0)
		var subtitle: String = "XP: %d | Service Record: %d mission%s" % [
			mc.get("xp", 0), missions, "" if missions == 1 else "s"]
		var char_id: String = mc.get("id", mc.get("character_id", ""))
		if sick_bay.has(char_id):
			subtitle += " | SICK BAY (%d turns)" % sick_bay.get(char_id, 1)

		var card := _create_character_card(mc_name, subtitle, mc_stats)
		roster_content.add_child(card)

	var roster_section := _create_section_card("Squad Roster", roster_content, "%d main characters" % chars.size())
	_content.add_child(roster_section)

	# ── Grunt Pool ──────────────────────────────────────────────────
	var grunt_content := VBoxContainer.new()
	if grunts.is_empty():
		var no_lbl := Label.new()
		no_lbl.text = "No grunts in pool"
		no_lbl.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		grunt_content.add_child(no_lbl)
	else:
		grunt_content.add_child(_create_info_row("Grunts Available", str(grunts.size()), COLOR_CYAN))
		grunt_content.add_child(_create_info_row("Profile", "R:1 S:4 CS:0 T:4", COLOR_TEXT_SECONDARY))
	var grunt_section := _create_section_card("Grunt Pool", grunt_content)
	_content.add_child(grunt_section)

	# ── Movie Magic ─────────────────────────────────────────────────
	var movie_content := VBoxContainer.new()
	movie_content.add_theme_constant_override("separation", SPACING_XS)
	var used: Dictionary = _campaign.movie_magic_used if "movie_magic_used" in _campaign else {}
	var all_magic := [
		["barricade", "Barricade"], ["double_up", "Double-Up"], ["escape", "Escape"],
		["evac", "Evac"], ["extra_support", "Extra Support"], ["lucky_find", "Lucky Find"],
		["reinforcements", "Reinforcements"], ["remove_contact", "Remove Contact"],
		["survived", "Survived"], ["you_want_some_too", "You Want Some Too?"]]
	for pair in all_magic:
		var ability_id: String = pair[0]
		var ability_name: String = pair[1]
		var is_used: bool = used.get(ability_id, false)
		var color: Color = COLOR_TEXT_MUTED if is_used else COLOR_SUCCESS
		var prefix: String = "[USED]" if is_used else "[READY]"
		movie_content.add_child(_create_info_row(ability_name, prefix, color))
	var movie_section := _create_section_card("Movie Magic", movie_content, "%d remaining" % movie_remaining)
	_content.add_child(movie_section)

	# ── Stagger fade-in ─────────────────────────────────────────────
	_stagger_reveal()

	# ── Breathe animation on Continue card ──────────────────────────
	if is_instance_valid(_play_btn):
		_play_btn.pivot_offset = _play_btn.size / 2
		TweenFX.breathe(_play_btn, 3.0, 0.03)

	## §2 sweep. Here rather than in _setup_screen() because this function has FOUR
	## callers (:19 setup, :29 after a veteran musters in, :329 enlist, :426 muster
	## out) and each one
	## replaces the whole subtree -- the base's single deferred sweep only ever saw
	## the first build. Both exits sweep: the empty-state branch returns early.
	##
	## Safe after _stagger_reveal(): that coroutine suspends at its first await and
	## returns here, so this line runs while the children already exist, and it
	## touches mouse_filter only -- nothing the fade animates.
	_fix_touch_scroll_filters()


func _stagger_reveal() -> void:
	# The subtree this coroutine animates, captured before the first await.
	#
	# ⚠ Three of the four _build_dashboard() callers free the WHOLE subtree and rebuild
	# (:29, :329, :426). queue_free() defers to the end of the frame while this function
	# suspends for 0.04s PER CARD, so a rebuild landing mid-reveal frees the very nodes
	# still sitting in `children`, and TweenFX.fade_in() is handed a previously-freed
	# Object. Measured in a full tests/unit run -- the suite passes 5/5 ALONE, so the batch
	# is only what makes the timing line up:
	#   Invalid type in function 'fade_in' ... argument 1 (previously freed)
	#   at res://src/ui/screens/bug_hunt/BugHuntDashboard.gd:215
	#
	# ⚠ This is a runtime error, NOT a visible defect -- do not cite it as one. The nodes
	# this coroutine is left holding are the ones being destroyed, and the rebuild starts
	# its own reveal over the new cards, so the screen still ends up correct. What it costs
	# is a class-(b) abort in the log, a debugger HALT under --debug/MCP (which is how this
	# project does runtime QA), and a suite that goes red only in a batch.
	#
	# The guard is the CONTAINER's identity rather than a generation counter:
	# _build_dashboard() rebinds _content as its first act (:34), so "am I still the live
	# reveal?" is answerable from state the tree already holds, with nothing to keep in sync.
	var revealing := _content
	var children := revealing.get_children()
	for child in children:
		if child is Control:
			child.modulate.a = 0.0
	for i in children.size():
		if children[i] is Control:
			if i > 0:
				await get_tree().create_timer(0.04).timeout
				# Re-checked AFTER the await and never before: suspended is the only state
				# in which the tree can change under us.
				if _content != revealing:
					return # a rebuild owns the screen now, and runs its own reveal
				if not is_instance_valid(children[i]):
					continue # one card went; the rest still deserve to appear
			TweenFX.fade_in(children[i], 0.2)


func _exit_tree() -> void:
	if _play_btn and is_instance_valid(_play_btn):
		TweenFX.stop_all(_play_btn)


func _navigate(route: String) -> void:
	var router = get_node_or_null("/root/SceneRouter")
	if router and router.has_method("navigate_to"):
		router.navigate_to(route)


func _on_save() -> void:
	if not _campaign:
		return
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("save_campaign"):
		gs.save_campaign(_campaign)
	elif _campaign.has_method("save_to_file") and _campaign.has_method("get_campaign_id"):
		var path: String = "user://saves/" + _campaign.get_campaign_id() + ".save"
		_campaign.save_to_file(path)


## Free the whole subtree and rebuild it from the current campaign.
##
## Extracted so the QA seam's rebuild is the SAME rebuild the transfer pickup
## does, rather than a fourth hand-copy of the free-then-build idiom (the other
## two live at the tail of _apply_enlistment and _apply_muster_out, each with its
## own note about why the rebuild is safe there).
func _rebuild() -> void:
	_campaign = _get_bug_hunt_campaign()
	for child in get_children():
		child.queue_free()
	_build_dashboard()


## Open the forced-roll seam. Debug builds only -- the card is gated at :122.
##
## ⚠ Passes THIS campaign, never GameState.current_campaign. The dialog's owner
## guard reads `crew_data` off whatever it is handed, and
## GameState._try_auto_load_last_campaign() (GameState.gd:150) loads a campaign at
## every launch -- so handing it the autoload's campaign would re-enable the
## fixtures and let a Bug Hunt session write credits, supplies, story points and
## reputation into the player's 5PFH save, with nothing visible happening on
## either screen.
##
## `_campaign` cannot be null here: this card is only built in the populated
## branch, after _build_dashboard()'s empty-state early return (:34-43).
func _on_qa_pressed() -> void:
	var dlg: Window = QAScenarioDialogClass.open(self, _campaign)
	if dlg == null:
		return
	# Cannot fire while the dialog's owner guard is false -- it refuses to apply and
	# never emits. Connected anyway: the signal IS emitted on the 5PFH path, so this
	# is not a dead wire, and the dashboard stays correct on the day that guard
	# learns about Bug Hunt fixtures.
	dlg.scenario_applied.connect(func(_id: String, _receipt: Dictionary): _rebuild())


func _on_enlist_pressed() -> void:
	## Show CharacterTransferPanel in enlist mode (5PFH → Bug Hunt).
	## Player picks a character from a standard campaign save to transfer in.
	var panel := TransferPanelClass.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_direction("enlist")
	panel.character_transferred.connect(
		func(char_data: Dictionary, _dir: String):
			_apply_enlistment(char_data)
			panel.queue_free()
	)
	add_child(panel)

	# Load standard campaign saves for character selection
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_available_campaigns"):
		var source: String = pick_enlist_source(gs.get_available_campaigns())
		if not source.is_empty():
			panel.load_characters_from_save(source)


## Pick the save a 5PFH veteran is enlisted FROM. Returns "" when none is eligible.
##
## Extracted as a pure static so a test can drive the rule without building the
## dashboard, the transfer panel or a GameState.
##
## ⚠ This used to read info.get("type", ""), a key NO producer writes:
## GameState.get_campaign_info() emits "campaign_type" (:1353). The comparison was
## therefore "" != "bug_hunt", permanently TRUE, so the first save of any type won and
## a player could enlist a Bug Hunt marine into Bug Hunt as a 5PFH veteran.
##
## ⚠ The test is POSITIVE, not the negative HEAD used. "not bug_hunt" also admits
## Tactics and Planetfall saves, and CharacterTransferPanel.load_characters_from_save()
## reads a 5PFH crew: this leg is the 5PFH -> Bug Hunt enlistment (Compendium p.171), so
## the eligible source is a standard campaign, not merely a non-Bug-Hunt one. A colonist
## or an army-list veteran reaches Bug Hunt by composing two book-defined legs through
## the 5PFH canonical, which is CharacterTransferService's job, not this picker's.
static func pick_enlist_source(campaigns: Array) -> String:
	for info_v in campaigns:
		if not info_v is Dictionary:
			continue
		var info: Dictionary = info_v
		var path: String = str(info.get("path", ""))
		# Only a STANDARD 5PFH save can supply a veteran to enlist.
		if str(info.get("campaign_type", "")) == "five_parsecs" and not path.is_empty():
			return path  # First standard save found
	return ""


func _apply_enlistment(char_data: Dictionary) -> void:
	## Enlist a 5PFH veteran into the squad (Compendium p.212), through the transfer hub.
	##
	## ⚠ HEAD appended to _campaign.main_characters directly and stopped there, so the
	## veteran existed in BOTH campaigns afterwards — the very "one item, one home" breach
	## CharacterTransferService.remove_character_from_save() was written to close for the
	## Planetfall and Tactics pull-imports (its docblock, :617). A duplicate is not merely
	## untidy: the same veteran can be enlisted again, and again, off the source save.
	##
	## Two further consequences of the raw append, fixed by going through the core's own
	## mutator: the campaign's modified time was never touched (add_main_character does it,
	## :178-179), and any future invariant that mutator grows would have been bypassed.
	if not _campaign or not _campaign.has_method("add_main_character"):
		return

	# Pull the source coordinates off before the character lands in the squad, so they
	# never persist into the Bug Hunt save. CharacterTransferPanel stamps them on the
	# enlist emit only; they are absent when the source was an in-memory array.
	var safe_copy: Dictionary = char_data.duplicate(true)
	var src_path: String = str(safe_copy.get("_source_path", ""))
	var src_id: String = str(safe_copy.get("_source_character_id", ""))
	safe_copy.erase("_source_path")
	safe_copy.erase("_source_character_id")

	_campaign.add_main_character(safe_copy)
	_on_save()

	# DESTINATION FIRST, THEN DROP THE SOURCE — the same ordering muster-out uses, and the
	# same as PlanetfallDashboard._apply_import (:64-87). Interrupted here, the failure is a
	# duplicate the player can delete, never a veteran who exists nowhere.
	if not src_path.is_empty() and not src_id.is_empty():
		if not CharacterTransferService.remove_character_from_save(src_path, src_id):
			push_warning(
				"BugHuntDashboard: enlisted %s but could not remove them from %s"
				% [src_id, src_path])

	# Rebuild dashboard to show new character. _build_dashboard() ends with the inherited
	# _fix_touch_scroll_filters(), so the rebuilt subtree is swept — no extra call needed.
	for child in get_children():
		child.queue_free()
	_build_dashboard()


func _on_muster_out_pressed() -> void:
	## Show CharacterTransferPanel in muster-out mode (Bug Hunt → 5PFH).
	var panel := TransferPanelClass.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_direction("muster_out")
	panel.character_transferred.connect(
		func(char_data: Dictionary, _dir: String):
			_apply_muster_out(char_data)
			panel.queue_free()
	)
	add_child(panel)

	# Load Bug Hunt characters for selection
	if _campaign and "main_characters" in _campaign:
		panel.load_characters_from_array(_campaign.main_characters)


func _apply_muster_out(char_data: Dictionary) -> void:
	## Save transferred character as pending transfer file for standard campaign pickup.
	## Remove from Bug Hunt squad. Deep copy to prevent shared references.
	if not _campaign or not "main_characters" in _campaign:
		return

	var safe_copy: Dictionary = char_data.duplicate(true)
	var char_id: String = safe_copy.get("id", safe_copy.get("character_id", ""))

	# Save pending transfer to user://transfers/
	var transfer_dir := "user://transfers/"
	if not DirAccess.dir_exists_absolute(transfer_dir):
		DirAccess.make_dir_recursive_absolute(transfer_dir)
	var timestamp := str(Time.get_unix_time_from_system())
	var filename := "transfer_%s_%s.json" % [char_id, timestamp]
	# safe_copy is already the canonical 5PFH-standard form (the panel ran
	# muster_out → _convert_to_standard), so it doubles as the lossless snapshot.
	var transfer_data := {
		"schema_version": 2,
		"direction": "bug_hunt_to_five_parsecs",
		"source_mode": "bug_hunt",
		"target_mode": "five_parsecs",
		"character": safe_copy,
		"snapshot": safe_copy.duplicate(true),
		"mustering_credits": safe_copy.get("mustering_credits", 0),
		"bonus_story_points": safe_copy.get("bonus_story_points", 1),
		"add_sector_government_patron": true,
		"source_campaign_id": _campaign.campaign_id if "campaign_id" in _campaign else "",
		"source_campaign_name": _campaign.campaign_name if "campaign_name" in _campaign else "",
		"transferred_at": Time.get_datetime_string_from_system()
	}

	# Write the destination FIRST and only drop the source if it succeeded.
	#
	# The write used to be wrapped in `if file:` while the removal and _on_save()
	# below ran unconditionally. An I/O failure therefore deleted the character from
	# the squad, PERSISTED that deletion, and wrote nothing to user://transfers/ for
	# the 5PFH side to pick up — the veteran vanished from both ends with no message,
	# which is precisely the loss the file-drop mechanism exists to prevent.
	#
	# SaveFileWriter checks the write (flush, get_error, verified rename) instead of
	# assuming a successful open means a successful save.
	var write_err: Error = SaveFileWriterRef.write_text_atomic(
		transfer_dir + filename, JSON.stringify(transfer_data, "\t"))
	if write_err != OK:
		push_error("BugHuntDashboard: transfer file could not be written (err %d) — "
			% write_err + "character kept in the squad rather than lost")
		# ⚠ `show_notification` DOES NOT EXIST on NotificationManager — `func
		# show_notification` has ZERO definitions repo-wide, so this guard was
		# permanently false and the player was told NOTHING on a failure path.
		# The real API is show_info / show_success / show_warning / show_error /
		# show_toast (src/autoload/NotificationManager.gd:105-131).
		# WorldPhaseAutomationController:569-570 already found and documented this
		# trap; these call sites were missed by that pass.
		var notifier := get_node_or_null("/root/NotificationManager")
		if notifier and notifier.has_method("show_error"):
			notifier.show_error(
				"Muster out failed — the character is still in your squad. "
				+ "Check device storage.")
		return

	# Remove character from Bug Hunt squad
	var idx_to_remove := -1
	for i in range(_campaign.main_characters.size()):
		var mc = _campaign.main_characters[i]
		if mc is Dictionary:
			var mc_id: String = mc.get("id", mc.get("character_id", ""))
			if mc_id == char_id:
				idx_to_remove = i
				break
	if idx_to_remove >= 0:
		_campaign.main_characters.remove_at(idx_to_remove)

	_on_save()
	# Rebuild dashboard
	for child in get_children():
		child.queue_free()
	_build_dashboard()
