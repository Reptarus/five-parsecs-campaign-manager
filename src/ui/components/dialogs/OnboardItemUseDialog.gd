class_name OnboardItemUseDialog
extends Window

## Use an On-board Item (Core Rules pp.57-58).
##
## "These items are not carried into battle by a specific crew member. Instead,
## they are usually left behind on the ship, and used at other points of the
## campaign turn." (p.57) — this dialog is that "other point".
##
## Ten of the nineteen items are "Single-use." and need a player decision the
## rules do not automate: which character receives the Transcender's XP, which
## damaged item the Fixer repairs, whether to arm the Nano-doc BEFORE the injury
## dice are rolled. The other nine apply automatically at their own rule sites
## (Repair Your Kit, Recruit, Train, the licence roll, Upkeep income) and are
## deliberately absent here — an item that fires by itself must not also offer a
## button, or the player will spend it twice.
##
## PRESENTATIONAL ONLY. Every rule lives in OnboardItemService; this file picks a
## target and reports the outcome. Story points and XP come back from the service
## as data and are written here through the singletons that own them, per the
## Data Ownership table.

signal item_used(item_id: String, summary: String)

const OnboardItemServiceRef = preload("res://src/core/equipment/OnboardItemService.gd")
const EquipmentTransferServiceRef = preload(
	"res://src/core/equipment/EquipmentTransferService.gd")

const COLOR_BASE := UIColors.COLOR_PRIMARY
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const TOUCH_TARGET_MIN := 48

var _campaign: Variant = null
var _crew: Array = []
var _rows: Array[Dictionary] = []
var _list: ItemList = null
var _detail: RichTextLabel = null
var _target_label: Label = null
var _target_list: ItemList = null
var _use_button: Button = null
var _targets: Array = []


func _init() -> void:
	title = "On-board Items"
	size = Vector2i(560, 520)
	transient = true
	exclusive = true
	close_requested.connect(func(): queue_free())


## `crew` is the live crew array (Dictionaries or Character Resources — the
## service normalises both).
func show_items(campaign: Variant, crew: Array) -> void:
	_campaign = campaign
	_crew = crew
	_rows = OnboardItemServiceRef.usable_items(campaign)
	_build()
	popup_centered()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BASE
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var heading := Label.new()
	heading.text = "On-board Items in the Stash (Core Rules pp.57-58)"
	heading.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(heading)

	if _rows.is_empty():
		var empty := Label.new()
		empty.text = ("No single-use on-board items in the Stash.\n\n"
			+ "Items that apply automatically (Repair Bot, Spare Parts, Mk II\n"
			+ "Translator, Teach-bot, Analyzer, Fake ID, Sector Permit,\n"
			+ "Purifier, Lucky/Loaded Dice) need no action here.")
		empty.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(empty)
		var close_btn := Button.new()
		close_btn.text = "Close"
		close_btn.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
		close_btn.pressed.connect(func(): queue_free())
		vbox.add_child(close_btn)
		return

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 150)
	_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	for row in _rows:
		_list.add_item(str(row.get("name", "?")))
	_list.item_selected.connect(_on_item_selected)
	vbox.add_child(_list)

	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.fit_content = true
	_detail.custom_minimum_size = Vector2(0, 70)
	_detail.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(_detail)

	_target_label = Label.new()
	_target_label.visible = false
	_target_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(_target_label)

	_target_list = ItemList.new()
	_target_list.custom_minimum_size = Vector2(0, 130)
	_target_list.add_theme_constant_override("item_height", TOUCH_TARGET_MIN)
	_target_list.visible = false
	_target_list.item_selected.connect(func(_i: int): _refresh_use_button())
	vbox.add_child(_target_list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)

	_use_button = Button.new()
	_use_button.text = "Use Item"
	_use_button.disabled = true
	_use_button.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	_use_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DialogStyles.style_primary_button(_use_button)
	_use_button.pressed.connect(_on_use_pressed)
	buttons.add_child(_use_button)

	var cancel := Button.new()
	cancel.text = "Close"
	cancel.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func(): queue_free())
	buttons.add_child(cancel)


func _selected_row() -> Dictionary:
	if _list == null:
		return {}
	var sel: PackedInt32Array = _list.get_selected_items()
	if sel.is_empty() or sel[0] >= _rows.size():
		return {}
	return _rows[sel[0]]


func _on_item_selected(_index: int) -> void:
	var row: Dictionary = _selected_row()
	if row.is_empty():
		return
	_detail.text = "[b]%s[/b]\n%s" % [
		str(row.get("name", "")), str(row.get("description", ""))]
	_populate_targets(str(row.get("target_kind", "")), str(row.get("id", "")))
	_refresh_use_button()


func _populate_targets(kind: String, item_id: String) -> void:
	_targets.clear()
	_target_list.clear()
	var visible_targets: bool = not kind.is_empty()
	_target_list.visible = visible_targets
	_target_label.visible = visible_targets
	if not visible_targets:
		return

	match kind:
		"character":
			_target_label.text = "Choose a crew member:"
			for member in _crew:
				# p.58 Novelty stuffed animal is the only one with a restriction,
				# and it is a hard one ("isn't Soulless, K'Erin, or a Bot"), so an
				# ineligible character is not offered rather than offered-and-refused.
				if item_id == "novelty_stuffed_animal" \
						and not OnboardItemServiceRef.stuffed_animal_allows(member):
					continue
				_targets.append(member)
				_target_list.add_item(_member_name(member))
		"damaged_item", "stash_item":
			_target_label.text = ("Choose a damaged item:" if kind == "damaged_item"
				else "Choose an item to copy:")
			for entry in _stash():
				if not (entry is Dictionary):
					continue
				var d: Dictionary = entry
				if kind == "damaged_item" \
						and not EquipmentTransferServiceRef.is_item_damaged(d):
					continue
				# p.57: "A Duplicator cannot copy a Duplicator."
				if kind == "stash_item" and OnboardItemServiceRef.normalize_id(
						str(d.get("name", d.get("id", "")))) == "duplicator":
					continue
				_targets.append(d)
				_target_list.add_item(str(d.get("name", "Item")))

	if _targets.is_empty():
		_target_label.text += "  (none available)"


func _refresh_use_button() -> void:
	var row: Dictionary = _selected_row()
	if row.is_empty():
		_use_button.disabled = true
		return
	if str(row.get("target_kind", "")).is_empty():
		_use_button.disabled = false
		return
	_use_button.disabled = _target_list.get_selected_items().is_empty()


func _on_use_pressed() -> void:
	var row: Dictionary = _selected_row()
	if row.is_empty():
		return
	var item_id: String = str(row.get("id", ""))
	var target: Variant = null
	if not str(row.get("target_kind", "")).is_empty():
		var sel: PackedInt32Array = _target_list.get_selected_items()
		if sel.is_empty() or sel[0] >= _targets.size():
			return
		target = _targets[sel[0]]

	var outcome: Dictionary = OnboardItemServiceRef.use(
		_campaign, item_id, target, _turn(), _crew)
	if not bool(outcome.get("ok", false)):
		_detail.text = "[color=#ff8080]That item could not be used.[/color]"
		return

	_apply_story_points(int(outcome.get("story_points", 0)))
	_apply_xp(outcome.get("xp_targets", []))
	if item_id == "fixer":
		_apply_fixer(target)
	elif item_id == "med_patch":
		_apply_med_patch(target)

	var summary: String = str(outcome.get("summary", ""))
	_journal(summary, item_id)
	item_used.emit(item_id, summary)
	queue_free()


## p.57 Fixer: "One piece of damaged or destroyed personal equipment can be
## repaired automatically, and at no cost." No roll — unlike Repair Your Kit,
## which is why this bypasses that task entirely.
func _apply_fixer(target: Variant) -> void:
	if not (target is Dictionary):
		return
	var d: Dictionary = target
	d["damaged"] = false
	d.erase("needs_repair")
	d.erase("damage_source")
	if str(d.get("quality", "")) == "damaged":
		d["quality"] = "standard"
	var nm: String = str(d.get("name", ""))
	if str(d.get("description", "")).ends_with(" (needs Repair)"):
		d["description"] = nm


## p.58 Med-patch: "may subtract one campaign turn from the recovery duration
## required. If this reduces the time to zero turns, they may act normally this
## campaign turn."
func _apply_med_patch(target: Variant) -> void:
	if target == null:
		return
	var remaining: int = 0
	if target is Dictionary:
		var d: Dictionary = target
		remaining = maxi(0, int(d.get("recovery_turns", 0)) - 1)
		d["recovery_turns"] = remaining
		if remaining == 0:
			d["in_sick_bay"] = false
		return
	if "recovery_turns" in target:
		remaining = maxi(0, int(target.recovery_turns) - 1)
		target.recovery_turns = remaining
		if remaining == 0 and "in_sick_bay" in target:
			target.in_sick_bay = false


func _apply_story_points(amount: int) -> void:
	if amount <= 0:
		return
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm and gsm.has_method("add_story_points"):
		gsm.add_story_points(amount)


func _apply_xp(awards: Array) -> void:
	for award in awards:
		if not (award is Dictionary):
			continue
		var cid: String = str(award.get("character_id", ""))
		var amount: int = int(award.get("xp", 0))
		if cid.is_empty() or amount <= 0:
			continue
		for member in _crew:
			if _member_id(member) != cid:
				continue
			if member is Dictionary:
				var d: Dictionary = member
				d["experience"] = int(d.get("experience", 0)) + amount
			elif "experience" in member:
				member.experience = int(member.experience) + amount
			break


func _journal(summary: String, item_id: String) -> void:
	var jr: Node = get_node_or_null("/root/CampaignJournal")
	if jr and jr.has_method("create_entry"):
		jr.create_entry({
			"type": "equipment", "auto_generated": true,
			"title": "On-board Item used",
			"description": summary,
			"tags": ["onboard_items", item_id],
		})


func _stash() -> Array:
	if _campaign == null or not ("equipment_data" in _campaign):
		return []
	var data: Variant = _campaign.equipment_data
	if not (data is Dictionary):
		return []
	var items: Variant = (data as Dictionary).get("equipment", null)
	return items if items is Array else []


func _turn() -> int:
	if _campaign == null or not ("progress_data" in _campaign):
		return 0
	return int(_campaign.progress_data.get("turns_played", 0))


func _member_name(member: Variant) -> String:
	if member is Dictionary:
		var d: Dictionary = member
		return str(d.get("character_name", d.get("name", "Crew")))
	if member != null and "character_name" in member:
		return str(member.character_name)
	return "Crew"


func _member_id(member: Variant) -> String:
	if member is Dictionary:
		var d: Dictionary = member
		return str(d.get("id", d.get("character_id", "")))
	if member != null and "character_id" in member:
		return str(member.character_id)
	return ""
