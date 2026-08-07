class_name CharacterUpgradeDialog
extends Window

## Core Rules p.78, Train crew task, verbatim: "characters can also Train as a
## task, earning 1XP. If this means they may make a Character Upgrade (see
## 'Experience and Character Upgrades', p.123), resolve that immediately."
##
## THE GAP THIS FILLS. The Train task awarded its XP and stopped there. The XP
## sat unspent until the player happened to open the post-battle Advancement step
## or a character sheet — so the one word that makes Train a real decision,
## "immediately", never happened. A crew sent to Train came back from a whole
## campaign turn with a number on a sheet and no visible change.
##
## p.123 is explicit that the PLAYER chooses which ability to raise, so this is a
## picker, never an auto-advance: `auto_advance_character()` exists but takes
## "first available", which would silently spend a character's Luck savings on
## Speed. It is deliberately not used here.
##
## PRESENTATIONAL ONLY. Every cost, cap and species freeze lives in
## CharacterAdvancementService; this file picks a stat and reports the outcome.

signal upgrade_resolved(stat_name: String, summary: String)
signal dismissed

const AdvancementServiceRef = preload(
	"res://src/core/services/CharacterAdvancementService.gd")

const COLOR_BASE := UIColors.COLOR_PRIMARY
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const TOUCH_TARGET_MIN := 48

var _character: Dictionary = {}
var _picker: OptionButton = null
var _status: Label = null
var _spend_button: Button = null


func _init() -> void:
	title = "Character Upgrade"
	size = Vector2i(520, 340)
	transient = true
	exclusive = true
	close_requested.connect(_on_dismiss)


## Returns true when the dialog has something to show. The caller MUST check it:
## a Train task that earns 1 XP usually does NOT cross a p.123 threshold, and
## popping an empty dialog every single turn would be worse than the bug.
static func has_upgrade_available(character: Dictionary) -> bool:
	return not AdvancementServiceRef.get_available_advancements(character).is_empty()


## `character` must be the LIVE crew entry (advance_stat mutates in place), not a
## duplicate — otherwise the upgrade is applied to a copy and thrown away.
func show_for(character: Dictionary) -> void:
	_character = character
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
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "%s has earned a Character Upgrade" % str(
		_character.get("name", _character.get("character_name", "Crew member")))
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(header)

	var cite := Label.new()
	cite.text = ("Training paid off. Core Rules p.78: \"If this means they may "
		+ "make a Character Upgrade, resolve that immediately.\"")
	cite.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	cite.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(cite)

	_picker = OptionButton.new()
	_picker.custom_minimum_size.y = TOUCH_TARGET_MIN
	vbox.add_child(_picker)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	_spend_button = Button.new()
	_spend_button.text = "Spend XP"
	_spend_button.custom_minimum_size.y = TOUCH_TARGET_MIN
	_spend_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spend_button.pressed.connect(_on_spend)
	row.add_child(_spend_button)

	# p.123 never forces the spend — banking XP toward a dearer ability is a legal
	# and common play, so "Save the XP" is a real option, not a cancel.
	var later := Button.new()
	later.text = "Save the XP"
	later.custom_minimum_size.y = TOUCH_TARGET_MIN
	later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	later.pressed.connect(_on_dismiss)
	row.add_child(later)

	_refresh()


func _refresh() -> void:
	if _picker == null:
		return
	_picker.clear()
	var xp: int = int(_character.get("experience", _character.get("xp", 0)))
	var options: Array[Dictionary] = AdvancementServiceRef.get_available_advancements(
		_character)

	if options.is_empty():
		_picker.disabled = true
		_spend_button.disabled = true
		_status.text = ("%d XP — nothing else affordable (p.123 costs: Speed/Savvy 5, "
			+ "Toughness 6, Reactions/Combat 7, Luck 10)") % xp
		return

	for opt: Dictionary in options:
		var stat_name: String = str(opt.get("stat", ""))
		_picker.add_item("%s %d→%d (%d XP)" % [
			stat_name.capitalize().replace("_", " "),
			int(opt.get("current", 0)), int(opt.get("current", 0)) + 1,
			int(opt.get("cost", 0))])
		_picker.set_item_metadata(_picker.item_count - 1, stat_name)
	_picker.disabled = false
	_spend_button.disabled = false
	_picker.select(0)
	_status.text = "%d XP available" % xp


func _on_spend() -> void:
	if _picker == null or _picker.selected < 0:
		return
	var stat_name: String = str(_picker.get_item_metadata(_picker.selected))
	if stat_name.is_empty():
		return

	var result: Dictionary = AdvancementServiceRef.advance_stat(_character, stat_name)
	if not bool(result.get("success", false)):
		_status.text = str(result.get("message", "Cannot advance that ability."))
		_status.add_theme_color_override("font_color", UIColors.COLOR_AMBER)
		return

	var summary: String = "%s raised to %d — %d XP remaining (Core Rules p.123)" % [
		stat_name.capitalize().replace("_", " "),
		int(result.get("new_value", 0)), int(result.get("xp_remaining", 0))]
	upgrade_resolved.emit(stat_name, summary)
	_status.text = summary
	_status.add_theme_color_override("font_color", UIColors.COLOR_EMERALD)

	# A single Train can only ever cross one threshold, but the character may have
	# been carrying XP already — refresh rather than close so a crew member who can
	# afford two upgrades is not made to wait a turn for the second.
	_refresh()


func _on_dismiss() -> void:
	dismissed.emit()
	queue_free()
