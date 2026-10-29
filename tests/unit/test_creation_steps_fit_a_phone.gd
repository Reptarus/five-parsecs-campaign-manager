extends GdUnitTestSuite
## Every step of the 5PFH creation wizard fits a phone.
##
## The windowed layout sweep builds CampaignCreationUI at step 1 only, so it stayed
## green while steps 4, 5 and 7 ran off a 393x851 phone: the page outgrew the screen
## and was clipped at BOTH edges ("ll Everything", "/anderer", "MPAIGN CONFIGURATION").
## This walks the seven steps in the real screen at a phone's design size, filling each
## the way the capture tool (and a player) does, and measures every step's content
## against the screen edge. The rolls are random, so each run measures different
## names and items; a driver that only overflows on a long roll can pass one run.

const PHONE := Vector2i(338, 734)
const CREATION := "res://src/ui/screens/campaign/CampaignCreationUI.tscn"
# The create path saves a campaign when it is allowed to run; the guard removes
# anything a run writes to user://saves/ and restores last_campaign.
const SaveDirGuard := preload("res://tests/fixtures/helpers/save_dir_guard.gd")

var _prior: Resource = null
var _user_state: Dictionary = {}


func before_test() -> void:
	_user_state = SaveDirGuard.snapshot()
	_prior = GameState.current_campaign
	GameState.current_campaign = null


func after_test() -> void:
	GameState.current_campaign = _prior
	SaveDirGuard.restore(_user_state)


## The node that sets the width: descend through the widest-minimum visible child.
func _spine(n: Control) -> String:
	var parts: Array[String] = []
	var node: Control = n
	for _i in range(30):
		var extra := ""
		if node is Label:
			extra = " '%s'" % (node as Label).text.substr(0, 30)
		elif node is Button:
			extra = " '%s'" % (node as Button).text.substr(0, 30)
		parts.append("%s[%s] min=%.0f%s" % [node.name, node.get_class(),
			node.get_combined_minimum_size().x, extra])
		var best: Control = null
		var best_w := -1.0
		for c in node.get_children():
			if c is Control and (c as Control).visible:
				var w: float = (c as Control).get_combined_minimum_size().x
				if w > best_w:
					best_w = w
					best = c
		if best == null:
			break
		node = best
	return " > ".join(parts)


## Every unwrapped Label, Button or HBox wider than 200 px under the step: the spine
## names one driver per run, and each fix only exposes the next one.
func _wide_leaves(root: Control) -> String:
	var out: Array[String] = []
	for c: Node in root.find_children("*", "Control", true, false):
		var n := c as Control
		if not n.is_visible_in_tree():
			continue
		var w: float = n.get_combined_minimum_size().x
		if w <= 200.0:
			continue
		if n is Label and (n as Label).autowrap_mode == TextServer.AUTOWRAP_OFF \
				and not (n as Label).clip_text:
			out.append("Label %.0f '%s'" % [w, (n as Label).text.substr(0, 40)])
		elif n is Button and not (n as Button).clip_text:
			out.append("Button %.0f '%s'" % [w, (n as Button).text.substr(0, 40)])
		elif n.get_class() == "HBoxContainer":
			out.append("HBox %.0f under %s" % [w, n.get_parent().name])
	return "\n      ".join(out)


func _fill(ui: Node, step: int) -> void:
	var panel: Node = ui.panels[step]
	match step:
		0:
			panel.campaign_name_input.text = "Phone Run"
			panel._on_campaign_name_changed("Phone Run")
		1, 2:
			panel._on_randomize_pressed()
		3, 4:
			if panel.has_method("_on_generate_pressed"):
				panel._on_generate_pressed()


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func _build() -> Control:
	var sv := SubViewport.new()
	sv.size = PHONE
	add_child(sv)
	auto_free(sv)
	var ui: Control = load(CREATION).instantiate()
	sv.add_child(ui)
	await _frames(4)
	assert_int(ui.panels.size()).override_failure_message("premise: seven steps") \
		.is_equal(7)
	return ui


## Fill each step in turn and advance, calling `at_step` on every step before Next.
func _walk(ui: Control, at_step: Callable) -> void:
	for step in range(7):
		_fill(ui, step)
		await _frames(4)
		at_step.call(step)
		if step < 6:
			ui._on_next_pressed()
			await _frames(4)
			assert_int(int(ui.coordinator.current_step)).override_failure_message(
				"premise: the wizard advanced past step %d" % (step + 1)).is_equal(step + 1)


func test_every_creation_step_fits_a_phone() -> void:
	var ui := await _build()
	var too_wide: Array[String] = []
	await _walk(ui, func(step: int) -> void:
		var panel: Control = ui.panels[step]
		var r: Rect2 = panel.get_global_rect()
		if r.position.x < -0.5 or r.end.x > float(PHONE.x) + 0.5:
			too_wide.append("step %d: %.0f..%.0f on %d px. %s\n    wide:\n      %s" % [
				step + 1, r.position.x, r.end.x, PHONE.x, _spine(panel),
				_wide_leaves(panel)]))
	assert_array(too_wide).override_failure_message("steps wider than a phone:\n%s"
		% "\n".join(too_wide)).is_empty()


## The Final Review on a phone, with names chosen to be long rather than rolled. A
## 30-walk hunt ran it off a phone once, on an XL captain name ("Commander Parker
## Liang", 260 px). It also showed two cards sharing one 260 px row, the Extras card
## squeezed to 62 px, because a flow places cards by their minimum widths.
func test_the_final_review_stacks_its_cards_and_wraps_long_names() -> void:
	const CAMPAIGN := "The Long Campaign Of The Outer Rim"
	const CAPTAIN := "Commander Parker Liang-Ostrova"
	var ui := await _build()
	await _walk(ui, func(step: int) -> void:
		var panel: Node = ui.panels[step]
		if step == 0:
			panel.campaign_name_input.text = CAMPAIGN
			panel._on_campaign_name_changed(CAMPAIGN)
		elif step == 1:
			panel.current_captain.character_name = CAPTAIN
			panel._on_character_created(panel.current_captain))
	await _frames(4)
	var final_panel: Control = ui.panels[6]
	var texts: Array = final_panel.find_children("*", "Label", true, false).map(
		func(l: Node) -> String: return (l as Label).text)
	assert_array(texts).override_failure_message(
		"premise: both long names reach the Final Review").contains([CAMPAIGN, CAPTAIN])

	var r: Rect2 = final_panel.get_global_rect()
	assert_bool(r.position.x >= -0.5 and r.end.x <= float(PHONE.x) + 0.5) \
		.override_failure_message("the Final Review runs %.0f..%.0f on %d px. %s\n      %s"
			% [r.position.x, r.end.x, PHONE.x, _spine(final_panel),
				_wide_leaves(final_panel)]).is_true()

	var cards: Control = final_panel.find_child("SummaryCards", true, false)
	assert_object(cards).override_failure_message("premise: the card column").is_not_null()
	var shared: Array[String] = []
	for c in cards.get_children():
		var card := c as Control
		if absf(card.global_position.x - cards.global_position.x) > 0.5 \
				or absf(card.size.x - cards.size.x) > 0.5:
			shared.append("%s at x=%.0f w=%.0f in a %.0f px column" % [card.name,
				card.global_position.x - cards.global_position.x, card.size.x, cards.size.x])
	assert_array(shared).override_failure_message(
		"cards share a row on a phone:\n%s" % "\n".join(shared)).is_empty()


## Step 6 prints the world name in XL. Rolled names are short, so the walk above
## cannot fail on it; this case sets a long one through the panel's own renderer.
func test_a_long_world_name_wraps_on_a_phone() -> void:
	const WORLD := "New Kessington Orbital Habitat Seven"
	var ui := await _build()
	for step in range(5):
		_fill(ui, step)
		await _frames(4)
		ui._on_next_pressed()
		await _frames(4)
	assert_int(int(ui.coordinator.current_step)).override_failure_message(
		"premise: the wizard reached the world step").is_equal(5)
	var panel: Control = ui.panels[5]
	var world: Dictionary = panel.current_world_data.duplicate()
	world["name"] = WORLD
	panel._display_world_data(world)
	await _frames(4)
	assert_str(str(panel.world_name_label.text)).override_failure_message(
		"premise: the long name is on screen").contains(WORLD)
	var r: Rect2 = panel.get_global_rect()
	assert_bool(r.position.x >= -0.5 and r.end.x <= float(PHONE.x) + 0.5) \
		.override_failure_message("the world step runs %.0f..%.0f on %d px. %s\n      %s"
			% [r.position.x, r.end.x, PHONE.x, _spine(panel), _wide_leaves(panel)]).is_true()


## The final step had two buttons for one action: the footer's "Start Campaign" calls
## the panel's _on_create_campaign_pressed(), and the panel ALSO drew "Create Campaign &
## Start Adventure" at the bottom of its scroll. The footer one is pinned and stays.
func test_the_final_step_has_one_create_button() -> void:
	var ui := await _build()
	await _walk(ui, func(_step: int) -> void: pass)
	var final_panel: Control = ui.panels[6]
	var in_page: Array = final_panel.find_children("*", "Button", true, false).filter(
		func(b: Node) -> bool: return "Create Campaign" in (b as Button).text)
	assert_array(in_page).override_failure_message(
		"the final step still draws its own create button").is_empty()
	assert_str(str(ui.finish_button.text)).is_equal("Start Campaign")

	# The footer greys out from the panel's validation. That signal used to be sent
	# only while the panel's own button existed.
	var announced: Array[bool] = []
	final_panel.panel_validation_changed.connect(func(ok: bool) -> void: announced.append(ok))
	final_panel._update_create_button_state()
	assert_array(announced).override_failure_message(
		"the footer button is no longer told whether the campaign is valid").has_size(1)

	# A second tap while the first finalization is still awaiting does nothing.
	var reacted: Array[String] = []
	final_panel.validation_failed.connect(func(_e: Array) -> void: reacted.append("failed"))
	final_panel.campaign_confirmed.connect(func() -> void: reacted.append("confirmed"))
	final_panel._finalizing = true
	final_panel._on_create_campaign_pressed()
	assert_array(reacted).override_failure_message(
		"a press during finalization ran the create path again").is_empty()


func _stat_texts(row: Control) -> Array:
	return row.find_children("*", "Label", true, false).map(
		func(l: Node) -> String: return (l as Label).text)


## Step 4's equipment cards print a weapon's profile in badges. Core Rules p.50 prints a
## melee weapon's range as "Brawl"; the data stores it as 0 range and 0 shots, and the
## card printed RNG 0" and SHT 0.
func test_an_equipment_card_prints_a_melee_range_as_brawl() -> void:
	var panel: Node = auto_free(load(
		"res://src/ui/screens/campaign/panels/EquipmentPanel.tscn").instantiate())
	add_child(panel)
	await _frames(2)
	var blade: Control = auto_free(panel._build_stats_row("Blade", "Weapon"))
	assert_array(_stat_texts(blade)).contains(["RNG", "Brawl"]).not_contains(["SHT", "0\""])
	var rifle: Control = auto_free(panel._build_stats_row("Military Rifle", "Weapon"))
	assert_array(_stat_texts(rifle)).contains(["RNG", "24\"", "SHT", "1"])
