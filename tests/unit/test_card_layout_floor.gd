extends GdUnitTestSuite
## Two shared cards, held to the layout floor the windowed sweep measures.
##
## CharacterCard: with no portrait it drew coloured initials over an EMPTY
## PortraitIcon, still visible underneath, so the sweep reported the initials "drawn
## on top of" the portrait on CharacterDetailsScreen at every size. The empty icon is
## now hidden while the initials show, and comes back when a portrait is set.
##
## CalloutCard: its UPPERCASE title never wrapped, so the title's whole width became
## the card's minimum ("RECORD A MISSION PLAYED ELSEWHERE" needed 383 px and pushed the
## Bug Hunt co-op map off a phone). It wraps now, inside the component.

const CARD := preload("res://src/ui/components/character/CharacterCard.tscn")
const CalloutCardScript := preload("res://src/ui/components/common/CalloutCard.gd")
const DetailsScript := preload("res://src/ui/screens/character/CharacterDetailsScreen.gd")
const EXPANDED := 200  # CharacterCard.CardVariant.EXPANDED, the hero card's variant


func _card(character: Character) -> Node:
	var card: Node = auto_free(CARD.instantiate())
	add_child(card)
	card.set_variant(EXPANDED)
	card.set_character(character)
	return card


func _character(portrait: String) -> Character:
	var c := Character.new()
	c.character_name = "Ana"
	# An explicit pick wins over the species registry; a missing file is rejected,
	# which is what puts the card on its initials.
	c.portrait_path = portrait
	return c


func test_a_card_without_a_portrait_shows_only_its_initials() -> void:
	var card := _card(_character("user://no_such_portrait.png"))
	await await_idle_frame()
	var initials: Control = card.find_child("InitialsLabel", true, false)
	var icon: Control = card.find_child("PortraitIcon", true, false)
	# Premise: the card took the initials path.
	assert_object(initials).is_not_null()
	assert_bool(initials.visible).is_true()
	assert_bool(icon.visible).is_false()


func test_a_portrait_brings_the_icon_back() -> void:
	var c := _character("user://no_such_portrait.png")
	var card := _card(c)
	await await_idle_frame()
	c.portrait_path = "res://icon.svg"
	card.set_character(c)
	await await_idle_frame()
	assert_bool((card.find_child("PortraitIcon", true, false) as Control).visible).is_true()
	assert_bool((card.find_child("InitialsLabel", true, false) as Control).visible).is_false()


func test_a_callout_title_wraps_instead_of_widening_the_card() -> void:
	var card: PanelContainer = auto_free(CalloutCardScript.new())
	card.setup("Record a mission played elsewhere, then update the map", Label.new())
	add_child(card)
	await await_idle_frame()
	# Unwrapped, this 18 px uppercase title alone needs well over 400 px.
	assert_float(card.get_combined_minimum_size().x).is_less(200.0)


## CharacterDetailsScreen's Advancement sections put two cards per row in a 2-column
## grid; held open by "Insufficient XP", the pair needed 346 px and put the page
## 26.6 px off a 338 px phone (the windowed sweep, named by its min-width spine). They
## flow now, so the section's minimum is ONE card.
func test_the_advancement_sections_need_only_one_card_of_width() -> void:
	var screen: Control = auto_free(DetailsScript.new())
	var who := {"reactions": 1, "combat_skill": 0, "toughness": 3, "savvy": 0,
		"speed": 4, "luck": 0, "experience": 0, "training": []}
	var stats: Control = auto_free(screen._create_stat_advancement_section(who))
	var training: Control = auto_free(screen._create_training_section(who))
	add_child(stats)
	add_child(training)
	await await_idle_frame()
	# Premise: the widest button label is on the page, so a two-across row would show.
	var texts: Array = []
	for b in stats.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	assert_array(texts).contains(["Insufficient XP"])
	assert_float(stats.get_combined_minimum_size().x).is_less(240.0)
	assert_float(training.get_combined_minimum_size().x).is_less(240.0)
