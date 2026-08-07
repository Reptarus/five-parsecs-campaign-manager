extends RefCounted
## Salvage as a currency, and the Scrapper trade (Compendium p.147).
##
## THE GAP THIS FILLS. Salvage units were counted DURING a Salvage mission
## (`SalvageResolver` increments them, `SalvageMissionPanel` displays them) and
## then evaporated the moment the battle ended. Nothing banked them onto the
## campaign, so:
##   - Post-battle Step 4 never tallied them, which is the exact step p.147 names;
##   - there was no Scrapper anywhere in the codebase, so the three Loot rolls
##     salvage exists to buy could never be made;
##   - `SalvageJobGenerator.get_salvage_credits()` — the one function that knew
##     salvage is worth 1 credit each — had ZERO external callers, so the
##     salvage-as-currency rule was unreachable;
##   - a player could run the whole Salvage chapter and receive nothing for it.
##
## The book, verbatim (Compendium p.147):
##   "In Post-battle Step 4. Get paid (core rulebook, p.120), tally up how many
##    units of Salvage you have obtained.
##    To determine what the Scrappers are willing to offer for your Salvage,
##    carry out the following process:
##    Roll three times on the Loot table (core rulebook, p.131).
##    For each result, roll 1D6 to determine how many units of Salvage you had to
##    trade in. Treat a roll of a 1 as a 2. You may obtain any of the items you
##    can afford. Note that you cannot convert Credits to Salvage units.
##    You can visit the Scrappers once per campaign turn, and may opt to hang on
##    to Salvage units if you don't find anything that interests you."
##   "There are no Invasion checks after a Salvage battle. It's just scrap metal,
##    right?"
##   "When purchasing any of the following, you may cash in Salvage to offset the
##    cost in Credits. 1 unit of Salvage equals 1 Credit ONLY when purchasing:
##    Ship repairs / Ship modules / Bot upgrades"
##
## Credits are NEVER written here — the caller applies the credit side through
## GameStateManager, which owns it. Salvage units ARE written here, because this
## file is their canonical owner.
##
## No `class_name` — preload by path.

const LootTableResolverRef = preload("res://src/core/equipment/LootTableResolver.gd")

## Canonical store. A plain int on progress_data, like turns_played — salvage is
## a running total, not per-battle state.
const UNITS_KEY := "salvage_units"
## The campaign turn on which the Scrapper was last visited ("once per campaign
## turn"). Absent means never.
const SCRAPPER_TURN_KEY := "scrapper_visited_turn"

## "Roll three times on the Loot table."
const SCRAPPER_OFFER_COUNT := 3
## "For each result, roll 1D6... Treat a roll of a 1 as a 2."
const SCRAPPER_PRICE_FLOOR := 2

## The ONLY three purchases p.147 lets Salvage pay for. Anything not on this list
## is credits-only — the list IS the rule, so callers pass a purpose and get told
## no rather than each site re-deciding.
const PURPOSE_SHIP_REPAIR := "ship_repair"
const PURPOSE_SHIP_MODULE := "ship_module"
const PURPOSE_BOT_UPGRADE := "bot_upgrade"
const SALVAGE_PURCHASABLE := [
	PURPOSE_SHIP_REPAIR, PURPOSE_SHIP_MODULE, PURPOSE_BOT_UPGRADE,
]


## ── The store ────────────────────────────────────────────────────────────────

static func get_units(campaign: Variant) -> int:
	if not _has_store(campaign):
		return 0
	return int(_progress(campaign).get(UNITS_KEY, 0))


static func add_units(campaign: Variant, amount: int) -> int:
	if amount == 0:
		return get_units(campaign)
	if not _has_store(campaign):
		return 0
	var pd: Dictionary = _progress(campaign)
	var total: int = maxi(0, int(pd.get(UNITS_KEY, 0)) + amount)
	pd[UNITS_KEY] = total
	return total


## Spend up to `amount`. Returns how many units ACTUALLY went, which may be fewer
## — the caller must read it rather than assume the full amount was paid.
static func spend_units(campaign: Variant, amount: int) -> int:
	if amount <= 0:
		return 0
	if not _has_store(campaign):
		return 0
	var pd: Dictionary = _progress(campaign)
	var have: int = int(pd.get(UNITS_KEY, 0))
	var spent: int = mini(amount, have)
	pd[UNITS_KEY] = have - spent
	return spent


## ── Post-battle Step 4: "tally up how many units of Salvage you have obtained" ──

## Move this battle's salvage onto the campaign and clear it off the result, so a
## re-run of the step (or a save mid-sequence) cannot bank it twice.
static func bank_battle_salvage(campaign: Variant, battle_result: Dictionary) -> int:
	var units: int = int(battle_result.get("salvage_units", 0))
	if units <= 0:
		return 0
	battle_result["salvage_units"] = 0
	battle_result["salvage_units_banked"] = units
	return add_units(campaign, units) if campaign != null else 0


## p.147: "There are no Invasion checks after a Salvage battle."
static func invasion_check_suppressed(battle_result: Dictionary) -> bool:
	if bool(battle_result.get("is_salvage", false)):
		return true
	var mission_type: String = str(battle_result.get("mission_type", "")).to_lower()
	if mission_type == "salvage":
		return true
	return str(battle_result.get("combat_mode", "")).to_lower() == "salvage"


## ── The Scrapper ─────────────────────────────────────────────────────────────

static func can_visit_scrapper(campaign: Variant, turn: int) -> bool:
	if not _has_store(campaign):
		return false
	var pd: Dictionary = _progress(campaign)
	if not pd.has(SCRAPPER_TURN_KEY):
		return true
	return int(pd.get(SCRAPPER_TURN_KEY, -1)) != turn


## Roll the three offers. Does NOT mark the visit or spend anything — a player who
## opens the Scrapper and buys nothing has still used their visit, so the caller
## marks it once the offers are shown (`mark_visited`).
##
## Each offer: {items: Array[Dictionary], price: int, label: String}.
## `price` is the 1D6 with the p.147 floor applied — "Treat a roll of a 1 as a 2".
static func roll_scrapper_offers(rng: RandomNumberGenerator = null) -> Array:
	var gen: RandomNumberGenerator = rng
	if gen == null:
		gen = RandomNumberGenerator.new()
		gen.randomize()

	var offers: Array = []
	for _i in range(SCRAPPER_OFFER_COUNT):
		var items: Array = LootTableResolverRef.roll_loot()
		if items.is_empty():
			continue
		var price: int = maxi(SCRAPPER_PRICE_FLOOR, gen.randi_range(1, 6))
		var names: Array[String] = []
		for item: Variant in items:
			names.append(str((item as Dictionary).get("name", "Item")) \
				if item is Dictionary else str(item))
		offers.append({
			"items": items,
			"price": price,
			"label": ", ".join(names),
		})
	return offers


static func mark_visited(campaign: Variant, turn: int) -> void:
	if not _has_store(campaign):
		return
	_progress(campaign)[SCRAPPER_TURN_KEY] = turn


## "You may obtain any of the items you can afford."
##
## Returns {bought, reason, units_spent, units_remaining, items}. The caller adds
## the items to the stash — this file does not own equipment.
static func buy_offer(campaign: Variant, offer: Dictionary) -> Dictionary:
	var price: int = int(offer.get("price", 0))
	var out: Dictionary = {
		"bought": false, "reason": "", "units_spent": 0,
		"units_remaining": get_units(campaign), "items": [],
	}
	if price <= 0:
		out["reason"] = "That offer has no price."
		return out
	if get_units(campaign) < price:
		# "you cannot convert Credits to Salvage units" — so there is no way to
		# top up a short balance, and offering one would break the rule.
		out["reason"] = "Not enough Salvage: %d needed, %d held (Compendium p.147)." % [
			price, get_units(campaign)]
		return out

	out["units_spent"] = spend_units(campaign, price)
	out["units_remaining"] = get_units(campaign)
	out["items"] = offer.get("items", [])
	out["bought"] = true
	return out


## ── Salvage as currency (p.147, three purchases only) ────────────────────────

static func can_pay_with_salvage(purpose: String) -> bool:
	return purpose in SALVAGE_PURCHASABLE


## Work out how much of a credit cost Salvage may cover, WITHOUT spending it.
## Returns {eligible, salvage_applied, credits_due}.
static func preview_offset(
	campaign: Variant, credit_cost: int, purpose: String
) -> Dictionary:
	var out: Dictionary = {
		"eligible": false, "salvage_applied": 0, "credits_due": maxi(0, credit_cost),
	}
	if credit_cost <= 0 or not can_pay_with_salvage(purpose):
		return out
	out["eligible"] = true
	var applied: int = mini(credit_cost, get_units(campaign))
	out["salvage_applied"] = applied
	out["credits_due"] = credit_cost - applied
	return out


## Spend Salvage against a credit cost at the p.147 1:1 rate and return what the
## caller still owes in credits. Deliberately spends salvage FIRST — it has no
## other use than these three purchases and the Scrapper, whereas credits pay
## Upkeep, so burning salvage first is strictly better for the player.
static func apply_offset(
	campaign: Variant, credit_cost: int, purpose: String
) -> Dictionary:
	var preview: Dictionary = preview_offset(campaign, credit_cost, purpose)
	if not bool(preview.get("eligible", false)):
		return preview
	var wanted: int = int(preview.get("salvage_applied", 0))
	var spent: int = spend_units(campaign, wanted)
	return {
		"eligible": true,
		"salvage_applied": spent,
		"credits_due": maxi(0, credit_cost - spent),
	}


## ── Internal ─────────────────────────────────────────────────────────────────

## Whether this campaign HAS a salvage store at all.
##
## Kept separate from _progress() on purpose. Guarding on `pd.is_empty()` — the
## obvious shortcut — conflates "there is no campaign" with "the campaign's
## progress_data happens to be empty", and the second is a perfectly legal state
## for a brand-new campaign. Written that way, add_units() silently returned 0 and
## can_visit_scrapper() said "already visited" for a crew that had never played a
## turn. Caught by test_the_scrapper_is_once_per_campaign_turn.
static func _has_store(campaign: Variant) -> bool:
	if campaign == null:
		return false
	if not ("progress_data" in campaign):
		return false
	return campaign.progress_data is Dictionary


static func _progress(campaign: Variant) -> Dictionary:
	if not _has_store(campaign):
		return {}
	return campaign.progress_data
