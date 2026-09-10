extends GdUnitTestSuite

## T11-51 — the captain's avatar rendered a literal `[`.
##
## Found on the tablet during the 2026-09-08 §1/§6 walk: the Manage Crew screen showed
## the captain's avatar as an orange box containing `[` instead of `B`.
##
## `CrewManagementScreen.gd:165` builds `display_name = "[Captain] " + name_str`, and
## `BaseCampaignPanel._create_character_card()` derived BOTH the avatar initial
## (`char_name.substr(0, 1)`) and the avatar COLOUR (`char_name.hash() % 8`) from that
## same decorated string. So the captain got the wrong glyph AND a colour that does not
## match the same character rendered anywhere else.
##
## ⭐ These cases assert the INVARIANT, not the constant: "decorating the display name
## must not change the avatar". Pinning the literal colour or the literal "B" would pass
## just as well with the identity plumbed to the wrong place, and would have to be
## rewritten every time the palette changes. The avatar-colour case in particular cannot
## be written against a constant at all — `avatar_colors` is a local inside the factory.
##
## ⚠ The last case is the DETECTION ARM: it drives the un-decorated call, which must be
## unaffected by the fix. Without it, a change that simply ignored `char_name` entirely
## would pass every other case here.

const PanelScript := preload("res://src/ui/screens/campaign/panels/BaseCampaignPanel.gd")

var _panel: Control


func before_test() -> void:
	_panel = PanelScript.new()
	add_child(_panel)
	auto_free(_panel)


## The avatar lives at panel > hbox > portrait_container > {ColorRect, Label}.
func _avatar_of(card: Control) -> Dictionary:
	var out := {"initial": "", "color": Color(0, 0, 0, 0), "found": false}
	var hbox: Node = card.get_child(0) if card.get_child_count() > 0 else null
	if hbox == null:
		return out
	for child in hbox.get_children():
		# The portrait container is the plain Control; `info` is a VBoxContainer.
		if child is VBoxContainer:
			continue
		for sub in child.get_children():
			if sub is ColorRect:
				out["color"] = (sub as ColorRect).color
				out["found"] = true
			elif sub is Label:
				out["initial"] = (sub as Label).text
	return out


## The display name is what the player reads on the card and must keep its decoration.
func _name_label_of(card: Control) -> String:
	var hbox: Node = card.get_child(0) if card.get_child_count() > 0 else null
	if hbox == null:
		return ""
	for child in hbox.get_children():
		if child is VBoxContainer and child.get_child_count() > 0:
			var first: Node = child.get_child(0)
			if first is Label:
				return (first as Label).text
	return ""


func test_decorated_display_name_does_not_leak_into_the_avatar_initial() -> void:
	var card: Control = _panel._create_character_card(
		"[Captain] Bryn Ito", "Genetic Uplift / Enforcer", {}, "", "Bryn Ito")
	auto_free(card)
	var av := _avatar_of(card)
	assert_bool(av["found"]).override_failure_message(
		"could not locate the avatar ColorRect; the card tree changed shape").is_true()
	assert_str(av["initial"]).override_failure_message(
		"T11-51: the captain's avatar initial came from the DISPLAY name").is_equal("B")


func test_the_card_still_shows_the_decorated_name_to_the_player() -> void:
	## The fix must not "solve" the initial by dropping the prefix from the card.
	var card: Control = _panel._create_character_card(
		"[Captain] Bryn Ito", "Genetic Uplift / Enforcer", {}, "", "Bryn Ito")
	auto_free(card)
	assert_str(_name_label_of(card)).is_equal("[Captain] Bryn Ito")


func test_decoration_does_not_change_the_avatar_colour() -> void:
	## The colour is hashed from the identity, so the SAME character must get the SAME
	## avatar whether or not the caller decorated the display string. Asserting the
	## invariant rather than the palette entry, which is a local inside the factory.
	##
	## ⚠⭐ THE DECORATION USED HERE IS LOAD-BEARING, AND IT IS DELIBERATELY **NOT**
	## `"[Captain] "`. The original T11-51 write-up claimed the captain also hashed the
	## wrong avatar COLOUR. That claim is FALSE, and the arithmetic says so:
	##
	##   Godot's `String.hash()` is djb2 — `h = 5381; h = h * 33 + c`. Since
	##   **33 ≡ 1 (mod 8)**, every power of 33 is 1 (mod 8), so for an 8-entry palette
	##   `hash(s) % 8 == (5381 + Σ chars) % 8`. Prefixing a constant P therefore shifts
	##   the index by exactly `Σ(P) % 8` — and **Σ("[Captain] ") = 920 ≡ 0 (mod 8)**.
	##   That prefix CANNOT move the colour index, for any name, ever.
	##
	## Measured with the defect fully reproduced: Bryn Ito 4/4, Dex Kovac 2/2, Yuri
	## Drake 5/5 — identical, and not by luck. A colour case written with `"[Captain] "`
	## is a permanent false green no matter how many names it loops over.
	##
	## So this case uses `"[MIA] "` (Σ = 431 ≡ 7 mod 8), which genuinely shifts the
	## index. The colour derivation is still worth pinning because it is LATENT: the
	## day someone decorates a card with `"★ "` (≡ 2) or `"(KIA) "` (≡ 6), the identity
	## has to already be plumbed through.
	for who in ["Bryn Ito", "Dex Kovac", "Yuri Drake", "Mars Stark"]:
		var plain: Control = _panel._create_character_card(who, "sub", {})
		auto_free(plain)
		var decorated: Control = _panel._create_character_card(
			"[MIA] " + who, "sub", {}, "", who)
		auto_free(decorated)
		assert_object(_avatar_of(decorated)["color"]).override_failure_message(
			"T11-51: %s hashed a different avatar colour when decorated" % who
			).is_equal(_avatar_of(plain)["color"])


func test_two_different_characters_still_differ() -> void:
	## Guards the lazy fix of hashing a constant: the avatar must still vary by name.
	var a: Control = _panel._create_character_card("Bryn Ito", "sub", {})
	auto_free(a)
	var b: Control = _panel._create_character_card("Nyx Ward", "sub", {})
	auto_free(b)
	assert_str(_avatar_of(a)["initial"]).is_equal("B")
	assert_str(_avatar_of(b)["initial"]).is_equal("N")


func test_undecorated_callers_are_unaffected() -> void:
	## DETECTION ARM. Three of the four callers (BugHuntDashboard, FinalPanel,
	## TacticsDashboard) pass a bare name and no identity, so `identity_name` defaults
	## to `char_name`. If the fix had made the identity mandatory, or ignored
	## `char_name` when the identity is empty, this goes red.
	var card: Control = _panel._create_character_card("Mars Stark", "K'Erin / Enforcer", {})
	auto_free(card)
	assert_str(_avatar_of(card)["initial"]).is_equal("M")
	assert_str(_name_label_of(card)).is_equal("Mars Stark")


func test_empty_name_still_renders_a_placeholder() -> void:
	## The factory's own fallback. An empty identity must not crash substr().
	var card: Control = _panel._create_character_card("", "", {})
	auto_free(card)
	assert_str(_avatar_of(card)["initial"]).is_equal("?")
