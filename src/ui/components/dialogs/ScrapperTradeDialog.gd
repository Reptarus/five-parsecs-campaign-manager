class_name ScrapperTradeDialog
extends Window

## The Scrapper (Compendium p.147).
##
## "Scrapper: a merchant that trades in junk, salvage, and broken parts."
##
## THE GAP THIS FILLS. There was no Scrapper anywhere in the codebase. Salvage
## units were counted during a Salvage mission and then evaporated — so the whole
## Salvage chapter (Compendium pp.137-147) produced a currency that could not be
## spent on anything, and `SalvageJobGenerator.get_salvage_credits()`, the one
## function that knew a unit is worth a credit, had zero external callers.
##
## The process, verbatim (p.147):
##   "Roll three times on the Loot table (core rulebook, p.131).
##    For each result, roll 1D6 to determine how many units of Salvage you had to
##    trade in. Treat a roll of a 1 as a 2. You may obtain any of the items you
##    can afford. Note that you cannot convert Credits to Salvage units.
##    You can visit the Scrappers once per campaign turn, and may opt to hang on
##    to Salvage units if you don't find anything that interests you."
##
## The three offers are rolled ONCE per visit and held for the life of the dialog:
## re-rolling on each rebuild would let a player reshuffle the shelf until
## something affordable appeared, which is not what "roll three times" means.
##
## PRESENTATIONAL ONLY. Prices, the p.147 floor, the once-per-turn gate and the
## salvage balance all live in SalvageLedger; the stash is written through
## EquipmentTransferService, which owns it.

signal purchased(item_names: Array, units_spent: int)
signal closed

const SalvageLedgerRef = preload("res://src/core/campaign/SalvageLedger.gd")
const EquipmentTransferServiceRef = preload(
	"res://src/core/equipment/EquipmentTransferService.gd")

const COLOR_BASE := UIColors.COLOR_PRIMARY
const COLOR_TEXT_PRIMARY := UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY := UIColors.COLOR_TEXT_SECONDARY
const COLOR_BORDER := UIColors.COLOR_BORDER
const TOUCH_TARGET_MIN := 48

var _campaign: Variant = null
var _turn: int = 0
var _offers: Array = []
var _rows: VBoxContainer = null
var _balance_label: Label = null


func _init() -> void:
	title = "The Scrapper"
	size = Vector2i(600, 520)
	transient = true
	exclusive = true
	close_requested.connect(_on_close)


## `turn` is the campaign turn, used for the p.147 "once per campaign turn" gate.
## The visit is marked as soon as the offers are shown — a player who looks and
## buys nothing has still spent their visit, which is what "may opt to hang on to
## Salvage units if you don't find anything that interests you" describes.
func open_for(campaign: Variant, turn: int, rng: RandomNumberGenerator = null) -> void:
	_campaign = campaign
	_turn = turn
	_offers = SalvageLedgerRef.roll_scrapper_offers(rng)
	SalvageLedgerRef.mark_visited(campaign, turn)
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

	var blurb := Label.new()
	blurb.text = ("The Scrapper lays out three finds. Each has a price in Salvage "
		+ "units — you cannot pay in Credits (Compendium p.147).")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	vbox.add_child(blurb)

	_balance_label = Label.new()
	_balance_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(_balance_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)

	var done := Button.new()
	done.text = "Keep my Salvage"
	done.custom_minimum_size.y = TOUCH_TARGET_MIN
	done.pressed.connect(_on_close)
	vbox.add_child(done)

	_refresh()


func _refresh() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var held: int = SalvageLedgerRef.get_units(_campaign)
	_balance_label.text = "Salvage held: %d unit(s)" % held

	if _offers.is_empty():
		var empty := Label.new()
		empty.text = "The Scrapper has nothing today."
		empty.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		_rows.add_child(empty)
		return

	for i in range(_offers.size()):
		var offer: Dictionary = _offers[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = "%s — %d Salvage" % [
			str(offer.get("label", "Item")), int(offer.get("price", 0))]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color",
			COLOR_TEXT_PRIMARY if not bool(offer.get("sold", false))
			else COLOR_TEXT_SECONDARY)
		row.add_child(label)

		var buy := Button.new()
		buy.custom_minimum_size = Vector2(120, TOUCH_TARGET_MIN)
		if bool(offer.get("sold", false)):
			buy.text = "Taken"
			buy.disabled = true
		else:
			buy.text = "Trade"
			buy.disabled = held < int(offer.get("price", 0))
			buy.pressed.connect(_on_buy.bind(i))
		row.add_child(buy)

		_rows.add_child(row)


func _on_buy(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	var offer: Dictionary = _offers[index]
	var result: Dictionary = SalvageLedgerRef.buy_offer(_campaign, offer)
	if not bool(result.get("bought", false)):
		_refresh()
		return

	# The stash has ONE mutation API (data-ownership table); loot goes in through
	# it rather than by appending to campaign.equipment_data directly.
	var names: Array = []
	var transfer = EquipmentTransferServiceRef.new(_campaign)
	for item: Variant in result.get("items", []):
		if item is Dictionary:
			transfer.add_loot_to_stash(item)
			names.append(str((item as Dictionary).get("name", "Item")))

	# Marked rather than removed: the offer stays on screen as "Taken" so the
	# player can see what the three rolls produced, which is what they paid a
	# whole visit for.
	offer["sold"] = true
	_offers[index] = offer

	purchased.emit(names, int(result.get("units_spent", 0)))
	_refresh()


func _on_close() -> void:
	closed.emit()
	queue_free()
