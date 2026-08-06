class_name FPCM_CheatSheetPanel
extends PanelContainer

## Cheat Sheet Panel - Quick Five Parsecs Combat Rules Reference
##
## Collapsible overlay (accordion pattern) with combat rules.
## Toggled via floating "?" button. Touch-friendly section headers.
## All text references page numbers from the Five Parsecs Core Rulebook.


const CompendiumGridMovementRef = preload(
	"res://src/data/compendium_grid_movement.gd")

# Design system constants
const SPACING_SM: int = 8
const SPACING_MD: int = UIColors.SPACING_MD
const SPACING_LG: int = UIColors.SPACING_LG
const TOUCH_TARGET_MIN: int = UIColors.TOUCH_TARGET_MIN
const FONT_SIZE_SM: int = UIColors.FONT_SIZE_SM
const FONT_SIZE_MD: int = UIColors.FONT_SIZE_MD
const FONT_SIZE_LG: int = UIColors.FONT_SIZE_LG
const FONT_SIZE_XL: int = UIColors.FONT_SIZE_XL

const COLOR_BASE: Color = UIColors.COLOR_BASE
const COLOR_ELEVATED: Color = UIColors.COLOR_ELEVATED
const COLOR_BORDER: Color = UIColors.COLOR_BORDER
const COLOR_ACCENT: Color = UIColors.COLOR_ACCENT
const COLOR_TEXT_PRIMARY: Color = UIColors.COLOR_TEXT_PRIMARY
const COLOR_TEXT_SECONDARY: Color = UIColors.COLOR_TEXT_SECONDARY

# Section data: Array of { title, content }
var _sections: Array[Dictionary] = []
var _section_buttons: Array[Button] = []
var _section_bodies: Array[RichTextLabel] = []
var _scroll: ScrollContainer
var _vbox: VBoxContainer
var _title_label: Label

func _ready() -> void:
	_build_sections_data()
	_setup_ui()

func _build_sections_data() -> void:
	_sections = [
		{
			"title": "Turn Sequence (p.38)",
			"content": _turn_sequence_text(),
		},
		{
			"title": "Hit Rules (p.40-43)",
			"content": _hit_rules_text(),
		},
		{
			"title": "Damage & Armor (p.43-44)",
			"content": _damage_rules_text(),
		},
		{
			"title": "Morale Rules (p.114)",
			"content": _morale_rules_text(),
		},
		{
			"title": "Status Effects (p.44)",
			"content": _status_effects_text(),
		},
		{
			"title": "Common Weapons (p.45-47)",
			"content": _common_weapons_text(),
		},
	]
	# Compendium DLC sections (added dynamically if DLC owned)
	_add_compendium_sections()

func _setup_ui() -> void:
	# Panel styling
	custom_minimum_size = Vector2(380, 300)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_BASE
	panel_style.set_corner_radius_all(8)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = COLOR_BORDER
	panel_style.set_content_margin_all(SPACING_MD)
	add_theme_stylebox_override("panel", panel_style)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", SPACING_SM)
	add_child(outer_vbox)

	# Title
	_title_label = Label.new()
	_title_label.text = "Quick Reference"
	_title_label.add_theme_font_size_override("font_size", FONT_SIZE_XL)
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(_title_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", COLOR_BORDER)
	outer_vbox.add_child(sep)

	# Scroll container for sections
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(_scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	_scroll.add_child(_vbox)

	# Build accordion sections
	for i in range(_sections.size()):
		var section: Dictionary = _sections[i]
		_build_section(i, section.title, section.content)

func _build_section(index: int, title: String, content: String) -> void:
	# Section header button (touch-friendly)
	var header := Button.new()
	header.text = "[+] %s" % title
	header.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	header.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var header_style := StyleBoxFlat.new()
	header_style.bg_color = COLOR_ELEVATED
	header_style.set_corner_radius_all(4)
	header_style.set_content_margin_all(SPACING_SM)
	header.add_theme_stylebox_override("normal", header_style)

	var hover_style := header_style.duplicate()
	hover_style.bg_color = COLOR_ACCENT
	header.add_theme_stylebox_override("hover", hover_style)
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)

	header.pressed.connect(_toggle_section.bind(index))
	_vbox.add_child(header)
	_section_buttons.append(header)

	# Section body (collapsed by default)
	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.text = content
	body.fit_content = true
	body.scroll_active = false
	body.add_theme_font_size_override("normal_font_size", FONT_SIZE_SM)
	body.add_theme_color_override("default_color", COLOR_TEXT_SECONDARY)
	body.visible = false
	_vbox.add_child(body)
	_section_bodies.append(body)

func _toggle_section(index: int) -> void:
	if index < 0 or index >= _section_bodies.size():
		return

	var body: RichTextLabel = _section_bodies[index]
	var button: Button = _section_buttons[index]
	var title: String = _sections[index].title

	body.visible = not body.visible
	if body.visible:
		button.text = "[-] %s" % title
	else:
		button.text = "[+] %s" % title

## Expand all sections.
func expand_all() -> void:
	for i in range(_section_bodies.size()):
		_section_bodies[i].visible = true
		_section_buttons[i].text = "[-] %s" % _sections[i].title

## Collapse all sections.
func collapse_all() -> void:
	for i in range(_section_bodies.size()):
		_section_bodies[i].visible = false
		_section_buttons[i].text = "[+] %s" % _sections[i].title

## Session 48: Set battle context and insert "This Battle" section at top.
func set_battle_context(data: Dictionary) -> void:
	if data.is_empty():
		return
	var content: String = _build_battle_reference_text(data)
	if content.is_empty():
		return
	var ef: Dictionary = data.get("enemy_force", {})
	var enemy_name: String = ef.get("type", "Enemy")
	var title: String = "This Battle: %s" % enemy_name
	_insert_battle_section_at_top(title, content)

func _insert_battle_section_at_top(title: String, content: String) -> void:
	## Insert a new accordion section at position 0 in the VBox.
	## Starts expanded (unlike other sections which start collapsed).
	if not _vbox:
		return

	# Remove any previous battle section
	var existing_header: Node = _vbox.get_node_or_null("_battle_header")
	var existing_body: Node = _vbox.get_node_or_null("_battle_body")
	if existing_header:
		existing_header.queue_free()
	if existing_body:
		existing_body.queue_free()

	# Rebuild arrays without old battle entry (index 0 if it existed)
	if not _sections.is_empty() and _sections[0].get("_is_battle", false):
		_sections.remove_at(0)
		if _section_buttons.size() > 0:
			_section_buttons.remove_at(0)
		if _section_bodies.size() > 0:
			_section_bodies.remove_at(0)

	# Insert battle section data at index 0
	_sections.insert(0, {
		"title": title, "content": content, "_is_battle": true})

	# Build header button
	var header := Button.new()
	header.name = "_battle_header"
	header.text = "[-] %s" % title
	header.custom_minimum_size = Vector2(0, TOUCH_TARGET_MIN)
	header.add_theme_font_size_override("font_size", FONT_SIZE_LG)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.178, 0.353, 0.482, 0.8)
	header_style.set_corner_radius_all(4)
	header_style.set_content_margin_all(SPACING_SM)
	header_style.border_width_left = 3
	header_style.border_color = Color("#D97706")
	header.add_theme_stylebox_override("normal", header_style)
	var hover_style := header_style.duplicate()
	hover_style.bg_color = COLOR_ACCENT
	header.add_theme_stylebox_override("hover", hover_style)
	header.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.pressed.connect(_toggle_section.bind(0))

	# Build body (starts expanded)
	var body := RichTextLabel.new()
	body.name = "_battle_body"
	body.bbcode_enabled = true
	body.text = content
	body.fit_content = true
	body.scroll_active = false
	body.add_theme_font_size_override(
		"normal_font_size", FONT_SIZE_SM)
	body.add_theme_color_override(
		"default_color", COLOR_TEXT_SECONDARY)
	body.visible = true # Starts expanded

	# Insert at top of VBox
	_vbox.add_child(header)
	_vbox.move_child(header, 0)
	_vbox.add_child(body)
	_vbox.move_child(body, 1)

	# Update tracking arrays
	_section_buttons.insert(0, header)
	_section_bodies.insert(0, body)

	# Fix toggle indices for existing sections (shifted by 1)
	for i in range(1, _section_buttons.size()):
		var btn: Button = _section_buttons[i]
		# Reconnect with corrected index
		if btn.pressed.is_connected(_toggle_section):
			btn.pressed.disconnect(_toggle_section)
		btn.pressed.connect(_toggle_section.bind(i))

func _build_battle_reference_text(data: Dictionary) -> String:
	## Build BBCode reference text for the "This Battle" section.
	var lines: Array[String] = []
	var ef: Dictionary = data.get("enemy_force", {})

	# Enemy stats
	if not ef.is_empty() and ef.get("type", "") != "":
		lines.append("[b]%s[/b] x%d" % [
			ef.get("type", "Unknown"), ef.get("count", 0)])
		lines.append(
			"Speed: %s\" | Combat: +%s | Tough: %s | Panic: %s" % [
				str(ef.get("speed", "?")),
				str(ef.get("combat_skill", "?")),
				str(ef.get("toughness", "?")),
				str(ef.get("panic", "?"))])
		var ai_code: String = str(ef.get("ai", ""))
		var ai_descs: Dictionary = {
			"A": "Aggressive — move toward closest, attack",
			"C": "Cautious — stay in cover, fire at closest",
			"D": "Defensive — hold position, fire if approached",
			"G": "Guardian — stay near assigned unit",
			"R": "Rampage — rush nearest, always melee",
			"T": "Tactical — advance to cover, best target",
			"B": "Beast — move to nearest, attack on contact",
		}
		lines.append(
			"AI: %s" % ai_descs.get(ai_code, ai_code))

		var rules: Array = ef.get("special_rules", [])
		if not rules.is_empty():
			lines.append("")
			lines.append("[b]Special Rules:[/b]")
			for rule in rules:
				var rs: String = str(rule)
				if not rs.is_empty():
					lines.append(
						"[color=#D97706]  %s[/color]" % rs)

	# Deployment condition
	var deploy: Dictionary = data.get("deployment", {})
	var cond_id: String = deploy.get("condition_id", "NO_CONDITION")
	if cond_id != "NO_CONDITION" and cond_id != "":
		lines.append("")
		lines.append(
			"[b]Deployment:[/b] %s" % deploy.get(
				"condition_title", cond_id))
		var desc: String = deploy.get("condition_description", "")
		if not desc.is_empty():
			lines.append("  %s" % desc)

	# Objective — tolerate both a Dict {name, victory_condition} and a bare
	# String objective id. The campaign battle context stores a String
	# (mission_data["mission_objective"]), which crashed the old Dict-typed
	# assignment when combat started (found 2026-07-03 campaign-path walk).
	var obj_raw: Variant = data.get("mission_objective", {})
	var obj_name: String = ""
	var obj_vc: String = ""
	if obj_raw is Dictionary:
		obj_name = str(obj_raw.get("name", ""))
		obj_vc = str(obj_raw.get("victory_condition", ""))
	elif obj_raw is String:
		obj_name = obj_raw
	if obj_name != "":
		lines.append("")
		lines.append("[b]Objective:[/b] %s" % obj_name)
		if obj_vc != "":
			lines.append("  %s" % obj_vc)

	return "\n".join(lines)

# =====================================================
# SECTION CONTENT
# =====================================================

func _turn_sequence_text() -> String:
	return """[b]Five Parsecs Battle Round (5 phases):[/b]

[color=#4FC3F7]1. Reaction Roll[/color] - Roll 1d6 per crew member
   Result <= Reactions stat = Quick Action

[color=#4FC3F7]2. Quick Actions[/color] - Crew with Quick Actions act
   Each can Move + one Action (fire, brawl, aim, dash)

[color=#4FC3F7]3. Enemy Actions[/color] - All enemies act
   Follow AI behavior type (see oracle)

[color=#4FC3F7]4. Slow Actions[/color] - Remaining crew act
   Same options as Quick Actions

[color=#4FC3F7]5. End Phase[/color] - Morale checks, conditions, events
   Check for Battle Events on rounds 2 and 4"""

func _hit_rules_text() -> String:
	return """[b]To Hit (p.44) - roll 1d6 + Combat Skill:[/b]
Cover does not modify the roll. It changes which
target number applies:
  Within [color=#4FC3F7]6\"[/color] and in the open      [color=#10B981]3+[/color]
  Within range in the open,
  OR within [color=#4FC3F7]6\"[/color] and in Cover   [color=#10B981]5+[/color]
  Within range and in Cover     [color=#10B981]6+[/color]
Equal to or above the target = Hit. Misses do nothing.

[b]The only To Hit modifiers:[/b]
  [i]Heavy[/i] trait:  [color=#DC2626]-1[/color] if the firer moved this round
  [i]Snap shot[/i]:   [color=#10B981]+1[/color] within [color=#4FC3F7]6\"[/color]
  Bipod (mod): [color=#10B981]+1[/color] over [color=#4FC3F7]8\"[/color] when Aiming or in Cover
There is no elevation or long-range modifier.

[b]Aiming (p.46):[/b]
If not Stunned and you did not Move, pick up any
[color=#4FC3F7]1[/color]s on the To Hit dice and roll them again once.
Tactical/Cautious/Defensive enemies Aim from Cover.
Aggressive/Rampaging enemies never Aim.

[b]Line of fire (p.44):[/b]
If the shot crosses another figure, it cannot be taken
(both sides). To risk an ally with an [i]Area[/i] weapon,
roll 1d6 and score [color=#10B981]5+[/color] or pick another target.

[b]Brawling (p.45):[/b]
Both roll 1d6 + Combat Skill. K'Erin roll twice, better.
  [color=#10B981]+2[/color] if carrying a [i]Melee[/i] weapon
  [color=#10B981]+1[/color] if carrying a [i]Pistol[/i] weapon
  [color=#10B981]+1[/color] to the outnumbering side
  [color=#10B981]+1[/color] per Stun marker on your opponent
      (all their Stun markers are then removed)
Lower total takes a Hit. Draw = both take a Hit.
Natural [color=#4FC3F7]6[/color]: inflict an extra Hit on the opponent.
Natural [color=#DC2626]1[/color]: opponent inflicts an extra Hit on you.
Damage = the highest [i]Melee[/i] or [i]Pistol[/i] Damage carried,
or [color=#D97706]+0[/color] with no suitable weapon.
[color=#10B981]Eliminate[/color] your opponent and you may move 2\" in any
direction, but may not enter a new Brawl."""

func _damage_rules_text() -> String:
	return """[b]Resolving Hits (p.46):[/b]
Roll [color=#4FC3F7]1d6 and ADD the Damage rating[/color] of the attack.

Result >= target's [color=#D97706]Toughness[/color], or a natural [color=#4FC3F7]6[/color]:
  [color=#DC2626]Casualty[/color] - removed from play.
Result < Toughness:
  Target is pushed [color=#D97706]1\"[/color] directly away from the attacker
  (unless blocked) and gains a [color=#D97706]Stun marker[/color].

[b]Saving Throws (p.46):[/b]
Roll 1d6 when becoming a casualty. Equal to or above
the save number negates the Hit - but the figure is
still [color=#D97706]Stunned[/color].
  Combat armor      [color=#10B981]5+[/color]
  Battle dress      [color=#10B981]5+[/color]  (also +1 Reactions, max 4)
  Frag vest         [color=#10B981]6+[/color]  ([color=#10B981]5+[/color] vs [i]Area[/i])
  Screen generator  [color=#10B981]5+[/color]  vs gunfire only
  Bot / Soulless / De-converted  [color=#10B981]6+[/color] built-in plating
  Assault Bot                    [color=#10B981]5+[/color] built-in plating
Max one armor and one screen per character.

[i]Piercing[/i] negates ARMOR saves, but not screens.

[b]Multiple Saving Throws (p.46):[/b]
Roll only the [color=#10B981]best[/color] save, with the target number
lowered by 1. Bot 6+ with a 5+ screen = [color=#10B981]4+[/color], counts as
a screen. Two 5+ armors = [color=#10B981]4+[/color]. Against a [i]Piercing[/i]
weapon, only Screen saves count at all.

[b]Stun markers (p.40):[/b]
A Stunned figure may Move [color=#4FC3F7]OR[/color] take a Combat Action next
time it acts, but not both. A Free Action is still
allowed. Remove one marker after it has acted.
[color=#DC2626]3 or more[/color] Stun markers at once = knocked out and
removed from play."""

func _morale_rules_text() -> String:
	return """[b]Running Away (p.47) - end of each round:[/b]
The enemy tests Morale only if they [color=#4FC3F7]lost figures[/color]
during the round just played.

[b]How to Check:[/b]
Roll [color=#4FC3F7]one d6 per enemy figure removed by combat[/color] this
round. Casualties from hazards or terrain do not count.
Every die falling inside that enemy type's
[color=#D97706]Panic range[/color] means one of them will [color=#DC2626]Bail[/color].

[b]Applying the results:[/b]
Assign each die to an enemy figure, starting with
those [color=#4FC3F7]closest to the enemy battlefield edge[/color].
Those figures Bail and are removed from play.
They do [color=#10B981]not[/color] count as killed for any purpose, and do
[color=#10B981]not[/color] trigger further Morale dice.

[b]Panic range 0:[/b]
That enemy fights to the death, unless something
raises their Panic range to 1 or more.

[b]Note:[/b] "Enemy Morale +1" (Bitter Struggle, p.88) makes
them [color=#10B981]steadier[/color] - the Panic range moves DOWN."""

func _status_effects_text() -> String:
	return """[b]Stunned (p.40)[/b]
Next time the figure acts it may Move [color=#4FC3F7]OR[/color] take a
Combat Action, but not both. A Free Action is still
allowed. Remove one Stun marker after it acts.
Markers accumulate: [color=#DC2626]3 or more at once[/color] = knocked out
and removed from play.
Attacked in a Brawl: all its Stun markers are removed,
but the attacker gets [color=#10B981]+1[/color] per marker removed.

[b]Stunned enemies (p.40)[/b]
Always fire at the nearest visible target. With no
target, they retreat toward better Cover. They will
[color=#DC2626]not[/color] enter Brawling combat.

[b]Wounded (crew only)[/b]
After battle, roll on the Injury Table (p.122).

[b]Bail (p.47)[/b]
An enemy that fails Morale flees the field and is
removed. Bailed figures do [color=#10B981]not[/color] count as killed and do
[color=#10B981]not[/color] trigger further Morale dice.

[i]There is no Suppression in Five Parsecs. The only
status effect is Stunned. "Suppressing fire" is a
Renegade Soldier rule (+1 shot), not a state.[/i]"""

func _common_weapons_text() -> String:
	# Core Rules p.50 Weapon Ratings, verbatim.
	#
	# ⚠ Do NOT "correct" these against the Compendium. The Compendium prints a
	# SECOND weapon table under its Game Options heading with different values
	# (Shotgun 8"/1 shot, Ripper sword 2 damage, Marksman's rifle Critical, and
	# so on). Its designer notes call them "minor tweaks" — it is an opt-in
	# alternative set, not errata. See docs/RULES_WIRING_AUDIT_2026-08.md.
	return """[b]Weapon             Rng  Shots  Dmg  Traits[/b]
Auto rifle         24"    2     0   -
Beam pistol        10"    1     1   Pistol, Critical
Blade             Brawl   -     0   Melee
Blast pistol        8"    1     1   Pistol
Blast rifle        16"    1     1   -
Boarding saber    Brawl   -     1   Melee, Elegant
Brutal melee wpn  Brawl   -     1   Melee, Clumsy
Cling fire pistol  12"    2     1   Focused, Terrifying
Colony rifle       18"    1     0   -
Dazzle grenade      6"    1    NA   Area, Stun, Single use
Duelling pistol     8"    1     0   Pistol, Critical
Flak gun            8"    2     1   Focused, Critical
Frakk grenade       6"    2     0   Heavy, Area, Single use
Fury rifle         24"    1     2   Heavy, Piercing
Glare sword       Brawl   -     0   Melee, Elegant, Piercing
Hand cannon         8"    1     2   Pistol
Hand flamer        12"    2     1   Focused, Area
Hand gun           12"    1     0   Pistol
Hand laser         12"    1     0   Snap Shot, Pistol
Hold out pistol     4"    1     0   Pistol, Melee
Hunting rifle      30"    1     1   Heavy
Hyper blaster      24"    3     1   -
Infantry laser     30"    1     0   Snap Shot
Machine pistol      8"    2     0   Pistol, Focused
Marksman's rifle   36"    1     0   Heavy
Military rifle     24"    1     0   -
Needle rifle       18"    2     0   Critical
Plasma rifle       20"    2     1   Focused, Piercing
Power claw        Brawl   -     3   Melee, Clumsy
Rattle gun         24"    3     0   Heavy
Ripper sword      Brawl   -     1   Melee
Scrap pistol        9"    1     0   Pistol
Shatter axe       Brawl   -     2   Melee
Shell gun          30"    2     0   Heavy, Area
Shotgun            12"    2     1   Focused
Suppression maul  Brawl   -     1   Melee, Impact"""


# =====================================================
# COMPENDIUM DLC SECTIONS (gated by DLCManager)
# =====================================================

func _add_compendium_sections() -> void:
	var dlc_mgr = Engine.get_main_loop().root.get_node_or_null("/root/DLCManager") if Engine.get_main_loop() else null
	if not dlc_mgr:
		return

	# Trailblazer's Toolkit sections
	if dlc_mgr.has_dlc("trailblazers_toolkit"):
		_sections.append({"title": "Species Rules [Compendium]", "content": _species_rules_text()})
		if dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.PSIONICS):
			_sections.append({"title": "Psionics [Compendium]", "content": _psionics_text()})

	# Freelancer's Handbook sections
	if dlc_mgr.has_dlc("freelancers_handbook"):
		if dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.NO_MINIS_COMBAT):
			_sections.append({"title": "No-Minis Combat [Compendium]", "content": _no_minis_text()})
		if dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.GRID_BASED_MOVEMENT):
			_sections.append({"title": "Grid Movement [Compendium]", "content": _grid_movement_text()})
		_sections.append({"title": "Difficulty Toggles [Compendium]", "content": _difficulty_toggles_text()})
		if dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.ESCALATING_BATTLES):
			_sections.append({"title": "Escalating Battles [Compendium]", "content": _escalating_battles_text()})
		if dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.CASUALTY_TABLES):
			_sections.append({"title": "Casualty Tables [Compendium]", "content": _casualty_tables_text()})

	# Fixer's Guidebook sections
	if dlc_mgr.has_dlc("fixers_guidebook"):
		if dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.STEALTH_MISSIONS):
			_sections.append({"title": "Stealth Missions [Compendium]", "content": _stealth_rules_text()})
		if dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.SALVAGE_JOBS):
			_sections.append({"title": "Salvage Jobs [Compendium]", "content": _salvage_rules_text()})
		if dlc_mgr.is_feature_enabled(dlc_mgr.ContentFlag.STREET_FIGHTS):
			_sections.append({"title": "Street Fights [Compendium]", "content": _street_fight_rules_text()})


func _species_rules_text() -> String:
	return """[b]Krag[/b]
Speed 4", Toughness 4. [color=#DC2626]Cannot Dash[/color] under any circumstances.
vs Rivals: Reroll one natural 1 on firing or Brawl (once per battle).
Armor: Non-trade armor needs modification (2 cr). Skulkers/Engineers fit.

[b]Skulker[/b]
Speed 6", Toughness 3. Ignores difficult ground, obstacles ≤1".
First 1" of climb is free. D6 3+ resists poison/toxin/gas.
All armor fits (flexible skeleton)."""


func _psionics_text() -> String:
	return """[b]Psionic Projection:[/b]
Roll 2D6 for range (sum in inches). Must have LoS.
[b]Strain:[/b] After use, roll D6: 4-5 = Stunned, 6 = Stunned + power fails.

[b]Legality (roll D100 at world arrival):[/b]
  01-25: [color=#DC2626]OUTLAWED[/color] - usage risks detection
  26-55: [color=#D97706]UNUSUAL[/color] - 2+ sixes on projection = reinforcements
  56-100: [color=#10B981]WHO CARES[/color] - no restrictions

[b]Player Powers:[/b] Lift, Grab, Slow, Guide, Psionic Bolt,
  Barrier, Predict, Inspire, Crush, Dominate

[b]Enemy Powers:[/b] Assail, Reflect, Bolster, Slow, Direct,
  Obscure, Dominate, Crush, Paralyze, Psionic Rage"""


func _no_minis_text() -> String:
	return """[b]Abstract Combat (no miniatures needed)[/b]

[b]Locations:[/b] 3-5 zones: Open / Light Cover / Heavy Cover / Elevated / Objective / Hazard
[b]Movement:[/b] 1 Location per activation. Sprint = 2 Locations.
[b]Taking Cover:[/b] 2D6 Battlefield Test, [color=#10B981]6+[/color] ([color=#DC2626]-1[/color] at a Location).
  While in Cover, all shots [color=#4FC3F7]by and against[/color] you hit only on a
  natural [color=#4FC3F7]6[/color]. Brawling enemies still engage you.
  The status is lost when you Move Up or Brawl.
  (No light/heavy cover tiers - Cover is binary here too.)

[b]Initiative Actions (choose 1 per figure):[/b]
  Fire | Engage (Brawl) | Take Cover | Sprint | Search | First Aid

[b]Enemy Actions (D6):[/b]
  1-2: Advance + Fire | 3-4: Hold + Fire (+1 aim)
  5: Advance + Engage | 6: Special (retreat/coordinate/rush)

[color=#D97706]NOT compatible with: AI Variations, Escalating Battles, Deployment Variables[/color]"""


## Compendium pp.90-93, via the single source of truth.
##
## What used to live inline here was FABRICATED: "1 square = 2 inches", a
## speed/range-to-squares conversion table, "1 square per activation (+1 if
## Speed > 4\")" and "enter occupied square = automatic Brawl". A full-text
## search of the Compendium finds no square/inch conversion at all, and p.93
## says the opposite of two of them — ranged combat and proximity both stay on
## the core rules, in inches. Only the Flanking block was correct. Do not
## re-inline this text; extend CompendiumGridMovement instead.
func _grid_movement_text() -> String:
	return CompendiumGridMovementRef.get_reference_text()


func _difficulty_toggles_text() -> String:
	return """[b]Difficulty Toggles (enable individually):[/b]

[color=#4FC3F7]Encounter Scaling:[/color]
  Strength-Adjusted: Enemy count = crew size + modifiers

[color=#4FC3F7]Economy:[/color]
  Money is Tight: Increased upkeep, crew actions cost 1 cr
  Slower Progression: XP costs increased (Reactions/Combat/Tough: 8 XP)

[color=#4FC3F7]Combat:[/color]
  Veteran: 1 basic enemy gets +1 Combat Skill
  Actually Specialized: Specialists min Combat +1, Toughness 4
  Armored Leaders: Lieutenants get 5+ Armor save
  Better Leadership: Unique Individuals roll 7+ (not 9+)

[color=#4FC3F7]Time Pressure:[/color]
  Paying by the Hour: 2D6 (pick highest) +4 = round limit
  Fickle Scans: Notable Sights removed after Round 3"""


func _stealth_rules_text() -> String:
	return """[b]Stealth Mission Rules[/b]

[b]Movement:[/b] Base speed +1" (no Dashing allowed).
[b]Detection:[/b] Sentries patrol randomly. If detected = combat begins.

[b]Spotting Check:[/b] Enemy rolls 2D6
  Modifiers: -2 partial cover, -1 per intervening feature
  -1 if sentry scanning (slow patrol)
  If roll > distance in inches = [color=#DC2626]DETECTED[/color]

[b]Finding (objectives):[/b]
  Move within 6" with LoS, roll D6+Savvy
  [color=#10B981]6+[/color] = located. Some objectives need multiple successes.

[b]Quick Actions:[/b] Move + 1 action (lockpick, hack, search, signal)
[b]Alarm:[/b] When triggered, all sentries converge. +D6 reinforcements Round 2."""


func _salvage_rules_text() -> String:
	return """[b]Salvage Job Rules[/b]

[b]Tension Track:[/b] Starts at ceil(crew_size / 2). Max 12.
  Each round after Round 1, roll D6:
	pass
  D6 > Tension = [color=#D97706]+1 Tension[/color]
  D6 ≤ Tension = [color=#DC2626]New Contact marker![/color]

[b]Contact Resolution (D6):[/b]
  1: Nothing | 2: Bad feeling (+1 Tension)
  3-5: [color=#DC2626]HOSTILES![/color] | 6: Place 2 new Contacts

[b]Points of Interest (D100):[/b]
  Move within 2", 1 action to search. Yields salvage units + possible loot.

[b]Salvage → Credits:[/b]
  1-3 units = 2 cr | 4-6 = 5 cr | 7-10 = 8 cr | 11-15 = 12 cr | 16+ = 18 cr

[b]Extraction:[/b] All crew must reach table edge to end mission."""


func _street_fight_rules_text() -> String:
	return """[b]Street Fight Rules[/b]

[b]Setup:[/b] Urban terrain. Place 3-5 buildings with interiors.
[b]Suspects:[/b] D6 Suspect markers placed. Move within 4" to identify.

[b]Suspect Identity (D6):[/b]
  1-2: Civilian (remove) | 3-4: Armed thug | 5: Target! | 6: Trap!

[b]Police Response:[/b]
  Timer starts at 6. Decrease by 1 each round + 1 per gunshot heard.
  Timer reaches 0 = [color=#DC2626]Police arrive[/color] (D6+2 Enforcers, 2 edges).

[b]Evasion (D6+Savvy, 7+):[/b]
  Success = slip away before police cordon.
  Fail = must fight through or surrender.

[b]Objectives (D100):[/b] Assassination, Protection, Retrieval, Delivery, Sabotage, Escape"""


func _escalating_battles_text() -> String:
	return """[b]Escalating Battles (Compendium pp.46-48)[/b]

[b]Trigger Check (end of each round):[/b]
  - Any enemy removed from play this round
  - A crew member reached an objective
  - End of Round 1 if enemies outnumbered by 3+
[color=#D97706]Max 3 escalation rolls per battle.[/color]

[b]Roll D100 on escalation table (varies by AI type):[/b]

[color=#4FC3F7]Morale Increase[/color] - Panic range -1 for rest of battle
[color=#4FC3F7]Fighting Intensifies[/color] - Random enemy +1 Combat, +1 Toughness (max 5)
[color=#DC2626]Reinforcements![/color] - 2 basic enemies from random edge
[color=#4FC3F7]Regroup[/color] - Enemies bonus move to cover with LoS
[color=#DC2626]Sniper![/color] - +1 enemy on tallest terrain, Marksman's Rifle
[color=#DC2626]Ambush![/color] - 2 basic enemies placed halfway to crew
[color=#D97706]Covering Fire[/color] - Closest enemy fires Frakk grenade or +1 hit
[color=#D97706]Unconventional Tactics[/color] - All crew Reaction = 1 next round
[color=#DC2626]Rush Attack[/color] - All enemies full move + brawl if possible

[b]Variation Mode:[/b] Duplicate results = no effect (doesn't count toward limit)
[color=#D97706]NOT compatible with No-Minis Combat[/color]"""


func _casualty_tables_text() -> String:
	return """[b]Compendium Casualty Table (p.86) - Roll D6:[/b]

[color=#DC2626]1: Instantly Killed[/color] - Remove from campaign
[color=#DC2626]2: Dead[/color] - Roll on injury for dramatic flavor only
[color=#D97706]3: Permanent Injury[/color] - Roll on Detailed Injury table
[color=#D97706]4: Serious Wound[/color] - Miss 3 campaign turns
[color=#4FC3F7]5: Minor Wound[/color] - Miss 1 campaign turn
[color=#10B981]6: Lucky Escape[/color] - No lasting effect

[b]Detailed Injury Table (p.87) - Roll 2D6:[/b]
  2: [color=#DC2626]Lost Limb[/color] (-1 Speed permanent)
  3: [color=#DC2626]Head Trauma[/color] (-1 Savvy permanent)
  4: [color=#D97706]Nerve Damage[/color] (-1 Reactions permanent)
  5: [color=#D97706]Torn Muscle[/color] (-1 Combat permanent)
  6-8: [color=#4FC3F7]Deep Laceration[/color] (miss 2 turns)
  9: [color=#4FC3F7]Cracked Ribs[/color] (miss 1 turn, -1 Toughness next battle)
  10: [color=#4FC3F7]Concussion[/color] (miss 1 turn, -1 Savvy next battle)
  11: [color=#10B981]Flesh Wound[/color] (miss 1 turn)
  12: [color=#10B981]Adrenaline Rush[/color] (no effect, +1 XP)"""
