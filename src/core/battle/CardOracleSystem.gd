class_name FPCM_CardOracleSystem
extends Resource

## Card Oracle System - Playing Card-Based AI Behavior Oracle
##
## 52 cards + 2 jokers. Suits determine behavior approach, rank determines
## intensity. Jokers trigger special plot twist events.
##
## Suits → Behavior:
##   Spades   = Aggressive (advance, charge, brawl)
##   Hearts   = Defensive (hold position, take cover, overwatch)
##   Diamonds = Tactical (flank, seek elevation, coordinated fire)
##   Clubs    = Erratic (random direction, unexpected action)
##
## Rank → Intensity:
##   Ace      = Maximum effort (full commitment to behavior)
##   2-5      = Conservative (cautious version of behavior)
##   6-10     = Standard (normal execution of behavior)
##   J, Q, K  = Enhanced (aggressive version of behavior)
##   Joker    = Plot twist (special event)
##
## All outputs are TEXT INSTRUCTIONS telling the player what to make enemies do.

signal card_drawn(card: Dictionary)
signal deck_shuffled()
signal deck_exhausted()

enum Suit { SPADES, HEARTS, DIAMONDS, CLUBS, JOKER }
enum Intensity { CONSERVATIVE, STANDARD, ENHANCED, MAXIMUM, PLOT_TWIST }

const SUIT_NAMES: Dictionary = {
	Suit.SPADES: "Spades",
	Suit.HEARTS: "Hearts",
	Suit.DIAMONDS: "Diamonds",
	Suit.CLUBS: "Clubs",
	Suit.JOKER: "Joker",
}

const SUIT_BEHAVIORS: Dictionary = {
	Suit.SPADES: "Aggressive",
	Suit.HEARTS: "Defensive",
	Suit.DIAMONDS: "Tactical",
	Suit.CLUBS: "Erratic",
}

const RANK_NAMES: Array[String] = [
	"Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10",
	"Jack", "Queen", "King",
]

## Instruction templates per suit × intensity
const INSTRUCTIONS: Dictionary = {
	# SPADES - Aggressive
	"Spades_CONSERVATIVE": [
		"Advance cautiously toward nearest crew, staying in cover. Fire if able.",
		"Move toward the nearest visible crew member, using cover along the way.",
	],
	"Spades_STANDARD": [
		"Advance directly toward nearest crew and fire. Use cover if convenient, but prioritize closing distance.",
		"Move to engage the closest crew member. Fire on approach.",
	],
	"Spades_ENHANCED": [
		"Charge the nearest crew member by the fastest route. Fire at close range or enter brawl.",
		"Rush forward aggressively. Ignore cover - close to brawling range.",
	],
	"Spades_MAXIMUM": [
		"ALL enemies charge the nearest crew member by the most direct route. Enter brawling combat if possible. No regard for self-preservation.",
	],
	# HEARTS - Defensive
	"Hearts_CONSERVATIVE": [
		"Remain in current position. If not in cover, move to nearest cover without advancing.",
		"Hold position and fire at nearest visible target. Do not advance.",
	],
	"Hearts_STANDARD": [
		"Take cover and fire at the most exposed crew member. Retreat if cover is compromised.",
		"Maintain defensive position. Shift within cover to get line of sight on a target.",
	],
	"Hearts_ENHANCED": [
		"Fall back to the strongest defensive position on the table. Concentrate fire on anyone who advances.",
		"Dig in hard. All enemies in this group go to overwatch - fire at the first crew member to move.",
	],
	"Hearts_MAXIMUM": [
		"Full defensive lockdown. ALL enemies retreat to best cover and refuse to advance. Concentrated fire on any crew in the open.",
	],
	# DIAMONDS - Tactical
	"Diamonds_CONSERVATIVE": [
		"Reposition to find a flanking angle. Move laterally, staying in cover.",
		"Seek higher ground or a position with better line of sight.",
	],
	"Diamonds_STANDARD": [
		"Split into two groups if possible. One group provides covering fire while the other flanks.",
		"Advance to a position that outflanks the nearest crew member. Fire from the new angle.",
	],
	"Diamonds_ENHANCED": [
		"Execute a coordinated pincer move. Half advance left, half advance right. Converge fire on the most isolated crew member.",
		"Seek elevated position. If already elevated, concentrate fire on crew in the open.",
	],
	"Diamonds_MAXIMUM": [
		"Perfect tactical coordination. ALL enemies move to surround the most isolated crew member. Concentrate all fire on that single target.",
	],
	# CLUBS - Erratic
	"Clubs_CONSERVATIVE": [
		"Move in a random direction (roll d6: 1-2 forward, 3 left, 4 right, 5-6 backward). Fire at nearest target after moving.",
		"Act confused. Shift position randomly, then fire at whoever is closest.",
	],
	"Clubs_STANDARD": [
		"Unexpected action! Ignore the nearest threat and target the crew member furthest away instead.",
		"Break from the group and act independently. Each figure targets a different crew member.",
	],
	"Clubs_ENHANCED": [
		"Wild charge in an unexpected direction! Move toward the crew member with the most cover (not nearest). Attempt to root them out.",
		"Erratic but dangerous. Each figure dashes to a random sector, then fires at whatever they can see.",
	],
	"Clubs_MAXIMUM": [
		"CHAOS! Roll a d6 for each enemy figure individually: 1-2 flee off table edge, 3-4 charge nearest crew, 5-6 fire at random crew member.",
	],
}

## Joker / plot twist events
const JOKER_EVENTS: Array[String] = [
	"PLOT TWIST - Betrayal! One enemy switches sides. The enemy nearest to a crew member joins your crew for the rest of the battle.",
	"PLOT TWIST - Ammo explosion! The largest piece of terrain explodes. Any figure within 3\" takes a hit.",
	"PLOT TWIST - Reinforcements arrive... but whose? Roll d6: 1-3 enemy reinforcements (d3 figures at table edge), 4-6 friendly reinforcements (d3 militia at your table edge).",
	"PLOT TWIST - Cease fire! All enemies hold position for one full round. No attacks. Use this round to reposition your crew.",
	"PLOT TWIST - Leader falls! The enemy leader (or strongest enemy) takes a wound. If no leader, the nearest enemy panics and flees.",
	"PLOT TWIST - Hidden cache! The nearest unoccupied terrain feature contains a weapons cache. First crew member to reach it gains a temporary +1 to hit for the rest of battle.",
]

var _deck: Array[Dictionary] = []
var _discard: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	_rng.seed = Time.get_unix_time_from_system()
	initialize_deck()

## Build a fresh 54-card deck and shuffle.
func initialize_deck() -> void:
	_deck.clear()
	_discard.clear()

	# 52 standard cards
	for suit_val: int in [Suit.SPADES, Suit.HEARTS, Suit.DIAMONDS, Suit.CLUBS]:
		for rank: int in range(13):
			_deck.append({
				"suit": suit_val,
				"rank": rank,
				"suit_name": SUIT_NAMES[suit_val],
				"rank_name": RANK_NAMES[rank],
				"is_joker": false,
			})

	# 2 jokers
	_deck.append({"suit": Suit.JOKER, "rank": -1, "suit_name": "Joker", "rank_name": "Red Joker", "is_joker": true})
	_deck.append({"suit": Suit.JOKER, "rank": -1, "suit_name": "Joker", "rank_name": "Black Joker", "is_joker": true})

	shuffle_deck()

## Shuffle current deck.
func shuffle_deck() -> void:
	# Fisher-Yates shuffle
	for i in range(_deck.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var temp: Dictionary = _deck[i]
		_deck[i] = _deck[j]
		_deck[j] = temp
	deck_shuffled.emit()

## Draw a card from the deck. Auto-reshuffles if empty.
func draw_card() -> Dictionary:
	if _deck.is_empty():
		# Reshuffle discard into deck
		_deck = _discard.duplicate()
		_discard.clear()
		shuffle_deck()
		deck_exhausted.emit()

	var card: Dictionary = _deck.pop_back()
	_discard.append(card)
	card_drawn.emit(card)
	return card

## Interpret a drawn card for a specific enemy AI type.
## Returns instruction text for the player.
func interpret_card(card: Dictionary, enemy_ai_type: String = "") -> String:
	if card.is_joker:
		return JOKER_EVENTS[_rng.randi_range(0, JOKER_EVENTS.size() - 1)]

	var suit: int = card.suit
	var rank: int = card.rank
	var intensity: int = _get_intensity(rank)
	var suit_behavior: String = SUIT_BEHAVIORS.get(suit, "Tactical")
	var intensity_name: String = _get_intensity_name(intensity)

	# Build instruction key
	var key: String = "%s_%s" % [SUIT_NAMES[suit], intensity_name]
	var instructions: Array = INSTRUCTIONS.get(key, ["Act according to their AI type."])
	var instruction: String = instructions[_rng.randi_range(0, instructions.size() - 1)]

	# Build display text
	var card_label: String = "%s of %s" % [card.rank_name, card.suit_name]
	var behavior_label: String = "%s (%s)" % [suit_behavior, intensity_name.to_lower()]

	var result: String = "[%s] %s\n%s" % [card_label, behavior_label, instruction]

	# Add AI type context if provided
	if not enemy_ai_type.is_empty():
		result = "Enemy Group (%s) - %s" % [enemy_ai_type, result]

	return result

## Get display text for a card (no interpretation).
func get_card_display(card: Dictionary) -> String:
	if card.is_joker:
		return card.rank_name
	return "%s of %s" % [card.rank_name, card.suit_name]

## Get remaining cards in deck.
func get_remaining_count() -> int:
	return _deck.size()

## Get total cards (deck + discard).
func get_total_count() -> int:
	return _deck.size() + _discard.size()

func _get_intensity(rank: int) -> int:
	if rank == 0: # Ace
		return Intensity.MAXIMUM
	elif rank >= 1 and rank <= 4: # 2-5
		return Intensity.CONSERVATIVE
	elif rank >= 5 and rank <= 9: # 6-10
		return Intensity.STANDARD
	else: # J, Q, K
		return Intensity.ENHANCED

func _get_intensity_name(intensity: int) -> String:
	match intensity:
		Intensity.CONSERVATIVE: return "CONSERVATIVE"
		Intensity.STANDARD: return "STANDARD"
		Intensity.ENHANCED: return "ENHANCED"
		Intensity.MAXIMUM: return "MAXIMUM"
		Intensity.PLOT_TWIST: return "PLOT_TWIST"
		_: return "STANDARD"

## Serialize for save/load.
func serialize() -> Dictionary:
	return {
		"deck": _deck.duplicate(),
		"discard": _discard.duplicate(),
	}

## Deserialize from save data.
func deserialize(data: Dictionary) -> void:
	_deck = []
	for card in data.get("deck", []):
		_deck.append(card)
	_discard = []
	for card in data.get("discard", []):
		_discard.append(card)
	if _deck.is_empty() and _discard.is_empty():
		initialize_deck()
