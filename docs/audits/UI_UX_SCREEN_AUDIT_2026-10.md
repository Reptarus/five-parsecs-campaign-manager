# UI/UX screen audit — Sprint U (2026-10)

**Started 2026-10-28 · branch `campaign-editor-and-fixits` · uncommitted.**
Plan: start-doing-deep-dive-elegant-reddy.md (in the Claude plans directory, outside the
repo), Sprint U.

The owner's brief: *"not just inventory but the fucking scenes and ui/ux for the fucking app
as a whole."* The rules-wiring censuses that built the plan never rendered a screen. They
named 6 of 30 Planetfall screens and mentioned `.tscn` three times. So this ledger works
from **real renders**. Each screen gets a capture, a verdict against the book step it
serves, and a fix that a test pins and an isolated revert proves.

## How to read a row

- **Capture** names a PNG written by `tests/tools/capture_modes.gd` (variant modes) or
  `capture_screens.gd` (5PFH and shared). Phone is `393x851` (design 338x734); tablet is
  `2560x1600`. Output goes to `user://shots/<run>/`.
- **Verdict** is what the render showed, judged against the book step.
- **Arms** are isolated-revert proofs from arm_runner.py (a session scratchpad script,
  not in the repo; the logs it writes are named per section). A row is **DETECTED** when the
  control run passes and the reverted run fails. An **UNDETECTED** arm is recorded, never
  dropped. Each one led to a better test (the `b`/second-run arms below).
- Only attested rows appear. A screen nobody has captured yet is listed under **Not yet
  walked**, not given a verdict.

## Cross-cutting fixes (every mode, found on the Planetfall pass)

| # | Defect | Fix | Pinned by | Arms |
|---|---|---|---|---|
| X1 | **Bold runs in rich text printed larger than the line around them, app-wide.** The theme sets RichTextLabel `bold_font_size = 16` (`sci_fi_theme.tres:655`). 68 call sites overrode `normal_font_size` alone, so every `[b]` printed at 16 inside 12-14 px text. | `ScreenChrome.size_rich_text(rtl, size)` sets all four sizes (normal, bold, italics, bold-italics). All 68 sites across ~45 files call it. Scenes that shrink bbcode text set `bold_font_size` too (`CharacterStatusCard.tscn`). | `test_ui_color_tokens.gd::test_rich_text_bold_takes_the_labels_size` | RB1-RB3 DETECTED |
| X2 | **The failing `#808080` grey survived in scenes.** The Sep 7 fix covered `.gd` literals only; four `.tscn` files still carried `Color(0.502, 0.502, 0.502)`, at 4.49:1 on the card. | Moved to the `COLOR_TEXT_SECONDARY` value (`#9ca3af`) in `CharacterStatusCard`, `TacticalBattleUI`, `CampaignCreationUI` and `WorldPhaseController` scenes. | `test_the_failing_grey_is_gone_from_scenes` | GS1 DETECTED |
| X3 | **A touch drag that starts on a line of rich text went nowhere.** `TouchScrollOpener` skipped every `RichTextLabel`. A non-scrolling RTL (`fit_content`, the common case for result lines) defaults to STOP and has no gesture of its own, so it swallowed the drag. | The opener now skips only controls that keep their own gesture: a RichTextLabel only when `scroll_active` (`keeps_its_gesture()`). A `[url]` tap still fires on an opened label, because PASS delivers the event to the control first. | `test_touch_pass_is_safe_for_buttons.gd` (4 new cases, including the link tap with a premise tap on the closed label) | TK3, TK4 DETECTED |
| X4 | **Controls added after the one-shot sweep stayed STOP.** Result lines appear when a step resolves, after `_ready()`'s sweep has already run. So the page could not be scrolled from the result it had just shown. | `TouchScrollOpener.keep_open(root)` sweeps once, then a `_Keeper` node watches `node_added` and opens each later Control under that root (deferred, idempotent per root). `CampaignScreenBase` and `PlanetfallCreationUI` call it. | `test_keep_open_opens_controls_added_later`; `test_planetfall_turn_footer.gd::test_result_lines_added_after_a_press_let_the_page_scroll` | TK1, TK2 DETECTED |
| X5 | **Hex colours in Planetfall prose.** Result text named colours by hex, so a palette change could not reach it, and a typo rendered silently as white. | Panels name a role (`ui-success`, `ui-danger` …), and `UIColors.bbcode()` resolves it. The guard rejects quoted hex fed through a variable and a misspelt role. | `test_planetfall_text_names_roles_not_hex`, `test_bbcode_resolves_every_role_to_its_token` | HX1-HX6 DETECTED |
| X6 | **Headings clipped instead of wrapping on a phone.** 24 heading Labels across the Planetfall turn panels, the dashboard and the creation panels had autowrap off. | All 24 autowrap (`AUTOWRAP_WORD_SMART`). | `test_planetfall_turn_footer.gd::test_every_heading_wraps_on_a_phone` | WT1, WT2 DETECTED |
| X7 | **CheckBox icons came from the default theme**, which did not match the Deep Space palette. | The theme sets the CheckBox icons. | `test_ui_color_tokens.gd` | U1 (theme) DETECTED |
| X8 | **TweenFX `stop()` left a node scaled mid-punch**, so the creation step label grew ~15% per step. | `TweenManager` restores rest values on `stop()`/`stop_all()`, and forgets them when a tween finishes. The step label punches once per step from a left-anchored pivot. | `test_tweenfx_rest_restore.gd` | U1-U4 (tween) DETECTED |
| X9 | **Overlays had no gutter in three modes, because the margin was set on a type that has none.** Five full-screen pages set `margin_left`/`margin_right` on a `ScrollContainer`: Bug Hunt's transfer panel, Planetfall's Import and Muster Out, and Tactics' Commission panel and Retire overlay. Measured in 4.6: `ThemeDB` lists **zero** theme constants for `ScrollContainer`, in both the default and the project theme, so all five ran edge to edge. The Planetfall Import page also left horizontal scrolling on and scrolled sideways on a phone. | `ScreenChrome.overlay_page(host)` builds the page colour, a scroll with the horizontal axis disabled, and a `MarginContainer` *inside* it. The side margins come from the host's width (never the margin's own, which would feed back), with a 16 px gutter and an 800 px column, and the top clears the Settings buttons. All five pages use it. | `test_overlay_pages.gd::test_every_transfer_page_is_framed_on_a_phone` | OV12, OV13, OV17 (see arms log). Tactics' Retire overlay was covered through the shared helper only until the Tactics pass built it (TD5, below). |
| X10 | **Four of the six Planetfall dashboard overlays had no background**: Colony Status, Armory, Enemy Tracker and Augmentations drew straight over the dashboard and could not be read (captured, `pf_port11`). All six sat flush to the left edge and under the Settings buttons. | `ScreenChrome.overlay_frame(host)`, the same page for a panel that brings its own scroll. The dashboard builds it once and mounts every overlay inside it. | `test_every_dashboard_overlay_is_framed` (phone and tablet, all six) | OV1-OV3 |
| X11 | **One weapon, three spellings.** Lock and Load and the Research application each wrote the profile line out by hand, and the Armory printed the JSON floats ("R:6.0 S:1.0 D:+0"). | `DisplayText.weapon_profile()` (`6" · 1 shot · Dmg +0`), read by all three. | `test_weapon_profile_prints_whole_numbers_and_words`, `test_the_armory_card_reads_like_lock_and_load` | OV5, OV16 |
| X12 | **An overlay built before it joins the tree never cleared the Settings buttons.** `_reserve_band_when_ready` waited on the HOST's `tree_entered`. Godot emits that before the host's children enter the tree, so `reserve_band(scroll)` found the scroll outside it and returned. Muster Out's title sat under the buttons (`pf_port12`). Import builds in `_ready()`, so it never took that path. | Wait on the TARGET's `tree_entered`. | `test_every_transfer_page_is_framed_on_a_phone` (now checks the band on every transfer page) | OV19 DETECTED |
| X13 | **All three transfer pages ran off a phone once they had something on them.** 28 Labels and the select buttons did not wrap: titles, explanation headers, the "No eligible veterans" line a fresh device shows first, the veteran's name and stats, and `Select <name>` / `Commission <name>`. The Step 2 button rows were HBoxes of fixed-width buttons. Measured: Step 1 ran to x=513 and Tactics' Step 2 to x=626 on a 338 px screen. | Every Label in a VBox wraps. The select buttons wrap. The Step 2 row buttons expand and wrap, so the pair splits the row. | same | OV20, OV21, OV22 DETECTED |
| X15 | **Neither layout sweep had ever built a Planetfall screen.** `verify_layout.gd` declared the variant modes "deliberately out of scope" because `is_a1_build()` hides them, a reason the review build retired. `test_touch_scroll_sweep.gd` stopped at Bug Hunt. | `ScreenPopulator._pre_planetfall()` founds a colony through the wizard's own `build_campaign()` (recommended p.14 roster, rolled backgrounds) and resumes turn 1 at Recovery, so nothing saves. Both sweeps list the three Planetfall screens. `verify_layout` now puts its baseline campaign back before every screen, so a variant fixture cannot leak into the 5PFH screens after it, and takes `-- only=<text>`. The touch sweep gained `SaveDirGuard` and node floors from a one-variable A/B: Dashboard 14 → 284, Turn Controller 2 → 226, Creation 165 either way. | `test_touch_scroll_sweep.gd` (33/33 built, 0 STOP under 26 Planetfall scrolls); `verify_layout -- only=planetfall` 24/24 | SW1-SW3 DETECTED |
| X14 | **The dashboard overlays put Close in three places**: under the content (Colony Status, Armory, Enemy Tracker, and Augmentations opened from the dashboard), top right (Milestones, Calamities), and under Muster Out's whole roster. On a phone the eight Augmentation cards had to be scrolled to the end to leave the page. | Close (and Muster Out's Cancel) is the first child, top right, 120 × 48, below the band. Colony Status and Enemy Tracker had re-added the kept Close at the end of every rebuild, which also errors on a second refresh (the node already has a parent); that is gone. As a turn step, Augmentations keeps its Continue last. | `test_every_overlay_can_be_closed_without_scrolling` (phone and tablet; 12-colonist roster; three Tactical Enemies from `create_full_enemy()`) | OV23-OV27 DETECTED |
| X16 | **Neither sweep had built a Tactics screen, and the touch sweep failed the moment it did.** With the three Tactics screens added, it found 32 STOP controls under the creation wizard's scrolls (the 15 species cards and their Select buttons, plus the review: two panels with no opener) and 3 under the turn screen's (the row each phase panel adds after its own one-shot sweep). | `ScreenPopulator._pre_tactics()` builds a campaign through the wizard's own `build_campaign()` (a five-unit Human platoon, validated) and opens the operational map, so nothing saves. `TacticsCreationUI` and `TacticsTurnController` call `TouchScrollOpener.keep_open(self)`. Node floors from a one-variable A/B: Dashboard 12 → 125, Turn Controller 1 → 61, Creation 223 either way. | `test_touch_scroll_sweep.gd` (36/36 built, 0 STOP under every Tactics scroll); `verify_layout -- only=tactics` | TW1, TW2, TW3 DETECTED |
| X17 | **No overlay page could be dragged from a row.** `overlay_page()` builds a ScrollContainer that every caller fills with buttons and cards (STOP by construction), and most callers add the page to the window root, where no screen's sweep reaches. None of the five callers opened it: Bug Hunt's transfer panel (which opened only its own `_content` on some steps), Planetfall's Import and Muster Out, and Tactics' Commission and Retire. | `overlay_page()` calls `TouchScrollOpener.keep_open(host)`, **deferred past the host's tree entry**. A non-deferred call sweeps an empty column (callers add rows after it returns), and a keeper that becomes ready inside the same entry has already missed those rows' `node_added`. | `test_touch_scroll_sweep.gd::test_an_overlay_page_opens_every_row_it_hosts` (one row added before entry, one after; premise: a Button is STOP by default) | X17a, X17a', X17b DETECTED (X17b is the deferral) |

## Planetfall — per screen

Captures `pf_port10` / `pf_land11` predate X1, X3, X4 and the Enemy Tracker and Tutorial
fixes. The re-capture is recorded in the next section.

### Creation wizard (`PlanetfallCreationUI.tscn`, 6 steps)

| Step | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Header | **Ran 7.2 px off a phone and 35.7 px off a 310 px small phone** (verify_layout's first Planetfall run). The title did not wrap, so it demanded its whole 306 px text width. It now wraps and expands across its line. ⚠ Wrapping alone was not enough: a wrapped Label reports a ~1 px minimum, and without `SIZE_EXPAND_FILL` the title collapsed to a narrow column (SF2). | `test_planetfall_screen_fit.gd::test_the_creation_title_wraps_inside_a_small_phone` | SF1, SF2 DETECTED |
| 1 Expedition | Renders and rolls. Heading wraps (X6). | `test_planetfall_turn_footer.gd` heading case | WT2 |
| 2 Roster (pp.14-20) | **Was a self-described stub**: eight "Colonist N", no sub-species, and the coordinator accepted any roster of three or more. Now it has the book's eight in the recommended mix, sub-species with the p.19 limits, Soulless only as a Trooper (p.20), an illegal sub-species disabled with its reason, an import label that fits a phone, and untitled names. | `test_planetfall_founding_roster.gd` (22) | R1-R5, R9-R11, R14, L7, L8 DETECTED |
| 3 Backgrounds (pp.21-23) | **Was a stub**: raw `randi()`, the first four characters made experienced instead of the player choosing, and no result shown. Now the player picks exactly four experienced characters (p.21), nothing rolls before four are chosen, the inexperienced roll Motivation only, a departed character's backgrounds are dropped, each rolled character is a heading, and the bonus names its stat. | same | R6-R8, R12, R13, R15-R17, D5, D9 DETECTED |
| 4 Map | The map is a real sector grid (`PlanetfallSectorGrid`) that scrolls inside its own width. | `test_planetfall_scout_reports.gd` | S11 DETECTED |
| 5 Initial Missions (pp.44-45) | **Ran off the right edge of a phone**: the Success/Failed buttons side by side asked for 290 px, which with card padding is 322 against ~290 of room. The button row is now an `HFlowContainer`. ⚠ The first version of the test was UNDETECTED (see Instruments). | `test_planetfall_tutorial_panel.gd::test_every_creation_step_fits_a_phone` (all six steps, in the real screen at phone width) | TU1 UNDETECTED, then DETECTED |
| 6 Review | Prints the founded profile, with the stat bonus applied at founding. | `test_planetfall_founding_roster.gd` | R15, R16 DETECTED |

### Dashboard (`PlanetfallDashboard.tscn`)

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Header and pools | **Was a self-labelled TODO.** Now it shows the colony pools and stat tiles that expand to the column, keeps a gutter, a fresh colony does not read "turn 0", and Continue names the step it resumes. | `test_planetfall_dashboard.gd` | D1, D7, D8, D10, D11, T1 DETECTED |
| Map | Shows the campaign map; it had none. **Every cell was under the touch floor in portrait**: the phone cell was 40 design px, which is 46.4 dp at the 1.16 effective scale, so all 36 cells of a 6 × 6 map failed at four sizes. It is now 42 (48.7 dp). The case reads the effective scale from the line in `SettingsManager.gd` that sets it, so it follows a re-tune. The map's own rules (p.52 D8 order, Chebyshev distance, the 6 × 6 default; p.53 site count and the adjacent re-pick; pp.156-157 emergence) are pinned by `test_planetfall_map.gd`. | same; `test_planetfall_screen_fit.gd::test_every_map_cell_is_a_touch_target`; `test_planetfall_map.gd` (10) | D2, SF3, MP1-MP9 DETECTED |
| Enemy line | Carries the Enemy Information count and names a strongpoint. | same | D3, D4 DETECTED |
| Roster cards | Print the full profile and name the background bonus. | same | D5, D6 DETECTED |
| Colony Status overlay | No page behind it (X10). The stats sat in four fixed columns that ran past a phone, and now flow. The milestone bar filled a share of a fixed 400 px, so it read full at a different count on each width and overran a phone at 7/7; it now fills a share of itself. | `test_overlay_pages.gd` | OV4, OV8 |
| Armory overlay (p.76) | No page behind it (X10). **Every card was several hundred px tall**: the traits label wrapped in an HBox beside two other columns, so it got no width and printed one letter per line (`pf_land12`). The card now stacks name/tier, profile, traits and the lock reason. The profile reads as Lock and Load's (X11), the traits are title-cased, and the filter buttons flow two-and-two on a phone. | `test_the_armory_card_reads_like_lock_and_load` | OV5, OV6 |
| Augmentations overlay | No page behind it (X10). Long names ("Boosted Decision Making") did not wrap beside the Purchase button, so the card ran 5 px off a phone. | `test_every_dashboard_overlay_is_framed` | OV11 |
| Milestones overlay (p.156) | Seven fixed 40 px segments ran 14 px off a phone; they now share the row from a 28 px floor. **The checklist turned every row green once a single source was owned** (it coloured by `owned`, the whole list, not `is_owned`). It also re-derived names from ids, so it printed "Post Organic Demarcation" for the book's "Integrated Post-Organic Demarcation". Names now come from the owning file through a new `PlanetfallResearchSystem.get_application()`, `get_building()`, `get_augmentation()` and `get_artifact_by_id()`. | `test_the_milestone_checklist_reads_names_and_colours_each_row` | OV9, OV14, OV15 |
| Calamities overlay | The empty-state sentence did not wrap and ran 15 px off a phone. Calamity names, section titles and progress lines now wrap too. | `test_every_dashboard_overlay_is_framed` | OV10 |
| Import and Muster Out | Edge to edge with a dead margin override (X9). Import scrolled sideways. Muster Out's name and two buttons in one HBox ran off a phone; the pair now drops under the name. **The `pf_port12` recapture showed two more**: Import's text ran off the right once Step 1 was drawn (X13), and Muster Out's title sat under the Settings buttons (X12). Its Cancel moved to the top (X14). Verified on `pf_port13` and `pf_land14`. | `test_every_transfer_page_is_framed_on_a_phone` | OV12, OV13, OV17, OV19-OV22, OV25 |
| Enemy Tracker overlay (pp.50-51, 61) | **Read dead and wrong data**: it printed the enemy's type record as its name, read a per-enemy info field that nothing writes, hard-coded the arrival milestones, and counted held sectors without naming them. It now reads `PlanetfallMap.enemy_name()`, `get_enemy_info_count()` against `ENEMY_INFO_MAX` (with the p.61 Strike note at the max), the milestones from `PlanetfallMilestoneSystem.milestones_with_effect()`, and lists held sectors by label. | `test_planetfall_dashboard.gd::test_the_enemy_tracker_reads_the_live_stores` | ET1-ET5 DETECTED |

### The 18-step turn (`PlanetfallTurnController.tscn`)

| Step | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Header | The turn header flows, so it no longer clips on a phone. The turn strip reads `colony_stats`. | `test_planetfall_turn_footer.gd` | TH1, T1 DETECTED |
| Footer (all steps) | The footer follows the SHOWN step, not `can_forward`. A disabled button says why, and a step with no status hides the footer. The next-step label skips Step 12, which the phase manager auto-completes. | same | F1 UNDETECTED, then F1b DETECTED; F2-F8 DETECTED |
| 1 Recovery (p.58) | With an empty Sick Bay the step arrives ready instead of waiting for a press. | `test_planetfall_colony_crisis.gd`, footer suite | AR1 DETECTED |
| 2 Repairs (p.59) | With nothing to repair the step is ready. | footer suite | F9 DETECTED |
| 3 Scout Reports (pp.59-61) | One Explore per turn, only on a legal sector. The discovery rolls once and its ops apply. The player's pick reaches the discovery, and Enemy Information reaches the map. A tapped sector reaches the screen, and long choices wrap. A pending discovery applies first. | `test_planetfall_scout_reports.gd` | S1-S10 DETECTED |
| 4 Enemy Activity (p.61) | With no Tactical Enemy the step arrives ready, and the footer arrives held. | footer suite, crisis suite | AR2, AR2f DETECTED |
| 5 Colony Events (p.62) | Waits for the roll and names an owed Milestone event. The next turn's roll button is reset. | footer suite | F10-F12 DETECTED |
| 6 Mission Determination (p.62) | An Attack leaves only the Pitched Battle. Availability follows the Map Location, and a mission with no sector is greyed with its reason. Several sectors wait for a pick; one sector is picked without asking. The pick reaches the footer, and the sector rides the stamp and the normalizer into the battle. | `test_planetfall_mission_determination.gd`, `test_planetfall_battle_payload.gd` | M1-M10 DETECTED; F13 DETECTED; F14 UNDETECTED, then F14b DETECTED |
| 7 Lock and Load (p.75) | Needs someone deployed. The weapon shown is the one recorded at the tick and reaches the quick roll. Rows fit the layout class and re-fit on a change. A new turn keeps Step 1's footer. | footer suite, battle payload suite | L1, L3-L6, F15, F19 DETECTED; L2 UNDETECTED, then L2b DETECTED (L2c was a probe) |
| 9 Injuries (pp.66-67) | Does not read "Roll Injuries" with nothing to roll. | `test_planetfall_post_battle.gd` | PB1 DETECTED |
| 10 Experience (p.67) | The preview comes from the rule, not a literal. | same | PB2 DETECTED |
| 9-12 footer | Names Post-Mission Finds and Enemy Information. The reason no longer says "above first". | footer suite | F17, F18, PB3 DETECTED |
| 14 Research (pp.92-93) | A Theory alone does not open its field (p.93/p.98 application gate). The Application pick is forceable. A locked Theory names what it needs, the detail pane is never empty, there is no second Done button, and the columns follow a layout change. | `test_planetfall_research_and_building.gd` | RB1, RB7, RB13, RB14, HN2, F16 DETECTED |
| 15 Building (pp.97-100) | The Application alone does not open the High-tech plant (p.100). BP go to one Building per turn (p.97). The conversion cap is per turn (p.98), as is the one reclaim (p.98), and the reclaim asks to confirm. A destroyed Building loses its standing benefit. Locked Buildings are listed with what they need, the spinner ceiling holds after a conversion, the convert row flows, and the columns follow a layout change. | same | RB2-RB6, RB8-RB12, HN1 DETECTED |
| 16 Colony Integrity (p.87) | Above the threshold the step arrives ready, and the roll-owed predicate is not off by one. | crisis suite | AR3, AR4 DETECTED |
| 16 result lines | Take their role colour. | footer suite | AR5 DETECTED |
| 18 Update Tracking (p.71) | **Asked for a press and saved twice**. p.71 rolls nothing at this step. It now arrives ready with the book's text, and the campaign saves when the turn ends. | `test_planetfall_colony_crisis.gd::test_step_18_arrives_ready_with_the_books_text` | S18 DETECTED |
| End Game (pp.160-164) | **Captured stage by stage for all four paths** (`pf_port14`, 15 frames). The text matches the book at every stage: Summit, D6 per character plus one for the population (p.160); Colony Security, 1 Strongpoint or 2 for Loyalty (p.160); costs of 15/5, 5/15, 10/5 and 5/10 BP/RP (pp.161-163); Independence and Ascension offer the narrated victory; and Isolation's completion lists each Nomad Struggles roll to 3 Wisdom (p.163). **One defect:** the path buttons did not wrap. "Independence (Cost: 15 BP, 5 RP) [SECURITY NOT MET]" ran past a phone and dragged the whole stage off-centre. The Loyalty dice had the same exposure, waiting on a roll: a rolled 2 is "Staging ground for continued colonization missions", 50 characters on one button in a flow. Both now wrap, and the dice stack full width. | `test_overlay_pages.gd::test_the_end_game_fits_a_phone` | OV28, OV29 DETECTED |

### Reopened by the Bug Hunt pass: the battle screen in Planetfall mode

Found while fixing the same defect for Bug Hunt (below), through the shared
`PreBattleChecklist`. Neither sweep nor any fit case had built the Planetfall battle modal,
so the Planetfall pass closed without measuring it.

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Setup checklist | **A Planetfall battle opened on the Core Rules checklist**: roll the p.88 deployment condition and the p.89 Notable Sight (Core Rules) and roll to Seize the Initiative. *"Planetfall does not have a Seize the Initiative roll"* (printed p.27). `PlanetfallBattleGuide.setup_checklist()` now gives the mission briefing's own setup, under the book's headings and in its order (pp.114-133): Table Setup (the mission's table size), Objectives (its `*_placement` key), Uncertain features (`uncertain_feature_text()`, reused), Battlefield Conditions ("There are no Battlefield Conditions" when the briefing says so), Player Forces (its `deployment`) and Opposition. The general placement rules come from a new `mission_types.json:briefing_rules` block quoting **p.114** (Enemy Deployments, Terrain Placement), so no rule number sits in a UI literal. TBUI branches on the mission's `battle_mode`; any other battle keeps the Core list. | `test_planetfall_battle_payload.gd::test_a_planetfall_battle_sets_up_by_its_mission_briefing` (payload from the turn controller's own `build_battle_payload()`, opened through TBUI's modal, with a 5PFH Alpha-1 arm) | PF1-PF5 DETECTED (`arms_pf.log`) |
| Modal width | **It ran past a phone's edge**: the Core list's dice-roll row is wider than a 310 px phone (PF6 restores the Core list and the fit case fails). The Planetfall steps have no roll row, and the step check boxes wrap. | `test_planetfall_screen_fit.gd::test_the_planetfall_battle_modal_fits_a_small_phone` (a Skirmish: conditions, two Uncertain features, a Tactical force) | PF6, PF7 DETECTED (`arms_pf_fit.log`) |

## Tactics — per screen

Captures `tac_land` / `tac_port` (`capture_modes.gd -- mode=tactics`, 2026-10-28), every
creation step empty and filled, the dashboard, the Commission overlay, all eight turn
phases and the turn-end card. Every case below is in `test_tactics_screen_fit.gd` unless
named, and the arms are in `arms_sf.log`. ⚠ The arms were logged as SF1-SF18, which
collides with the Planetfall SF1-SF3 above, so this section writes them **TSF**.

### Creation wizard (`TacticsCreationUI.tscn`, 4 steps)

| Step | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Header | **The first screen said "Step 1 of 5" on a four-step wizard.** The label was only set on a step change, so the build-time literal showed until the player moved. It is now set at `_ready`. **The title ran past a 310 px phone**: it now wraps, and its 70 px right spacer (which balances the Cancel button on a wide screen) hides on a narrow one. | `test_the_first_screen_names_the_real_step_count`, `test_the_creation_title_wraps_inside_a_small_phone` | TSF1, TSF2, TSF3 DETECTED |
| Navigation | Launch Campaign ended 3 px past a 310 px phone, in a row beside Back. The row is an `HFlowContainer`, so the pair wraps. | `test_every_creation_step_fits_a_small_phone` (all four steps, each filled by its own panel) | TSF5 DETECTED |
| Cancel, Select | Both carried a 40 px minimum and a comment calling it 46.4 dp, under the 48 dp floor. **Measured, that was false:** the theme draws a 40 px-minimum button at 42 design px, 48.7 dp. They now use `TOUCH_TARGET_MIN` for consistency, and the comments say so. | `test_the_wizard_buttons_meet_the_touch_floor` | TSF6, TSF7 UNDETECTED by design (no defect to detect) |
| 1 Configuration | The title ran past a phone and now wraps. The scroll's horizontal axis is disabled, so an overflow shows instead of scrolling sideways. | steps case | TSF4 DETECTED. CF1 (the armored-platoon CheckBox wrap) UNDETECTED: "Build an armored platoon" fits; the longer company-org label is not reached by the case. |
| 2 Species (pp.153-167) | **Every card read "Major — 31 units, 40 weapons"** (the loader's own log prints those counts for every species). Units are composed from the one Army Builder (pp.133-139) and every species arms from the one p.181 table, so the numbers said nothing. Special Rules showed as names only. The species book now keeps its Lifeforms `profiles`, and each card prints its power, its **Military** profile as the file prints it, and each Special Rule's text. ⚠ The composed units could not supply the profile: the loader sets no `profile_tier`, so every unit reads MILITARY. | `test_each_species_card_shows_its_own_profile_and_rules` (every rule text present, more than five distinct Military lines, the Human line built independently from the JSON) | TC7a, TC7b, TC7c DETECTED |
| 2 Species (Select) | With the profile and each rule's text, a card grew to five or six lines and its `SIZE_FILL` Select button grew with it, into a slab as tall as the card (`tac_land2`). It now centres at the touch height. | species case (each Select no taller than `TOUCH_TARGET_MIN`) | TC7d DETECTED (all 15 cards fail when reverted) |
| 3 Roster | **Available Units and Your Roster were stacked on every screen**, so the roster being built sat below about two dozen "+ Add" rows (the code comment said they "would be side-by-side on wide"). They are now two columns wherever `ResponsiveManager` offers more than one, and one in portrait, where the header counts the units added. The header flows, so the count drops under the title on a phone. "1 models" now reads "1 model". | `test_the_roster_sits_beside_the_unit_list_on_a_tablet`, `test_counts_read_as_a_player_writes_them` | TSF16, TSF17, TSF18, TC6a, TC6b DETECTED |
| 4 Review | "1 models" and "Validation: 1 issue(s)" now read as a player writes them. | counts case | TC6c DETECTED |

### Dashboard (`TacticsDashboard.tscn`)

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Header | **The title sat under the Settings and bug-report buttons in portrait.** `TacticsScreenBase` centred the page by moving the full-rect scroll's own offsets, so the screen had neither shape `reserve_band_on()` handles (a MarginContainer, or a vertical box) and nothing was reserved. The column is now margins *inside* the scroll, as in `PlanetfallScreenBase`, and the band is reserved on the scroll. This also gives a tablet the full-width drag area, and removes a `size_changed` lambda that kept the scroll `_rebuild()` frees. | `test_the_dashboard_clears_the_settings_band_and_cards_do_not_repeat_stats` (asserts the band is non-zero first: measured 60 px headless) | TD1 DETECTED |
| Unit cards | **The subtitle repeated the stats grid**: "1 models — 0 battles" above "Models 1, Battles 0". It now says what the grid cannot: the p.106 condition, what CP has bought, or "Ready to deploy" (`is_deployable()`). A Devastated unit reads "2 battles until usable", not "2 more battle(s)". | same; counts case | TD2, TC6d DETECTED |
| Turn tiles | A freshly built campaign read **TURN 0** and **OP TURN 0**, which looked like a fault. Both count turns started, so 0 now reads "—" (the Planetfall dashboard had the same reading). | `test_continue_says_what_it_will_do` (no "0" beside either tile) | TD3 DETECTED |
| Continue | **Read "Start the next operational turn" in every state**, including halfway through a battle. It now reads the turn the core recorded (`record_turn_phase`), branch for branch as `TacticsPhaseManager.enter_campaign()` decides: "Start turn 1", "Resume turn 1: Battle", "Start turn 2" after an ended turn, and "Resume turn N: Commit Your Force" for a save older than the record. | same | TD4, TD4b DETECTED |
| Retire overlay | Built for the first time (`_build_retire_overlay`, two veterans, one with a 48-character name, on a 310 px phone). **Each row was an HBox of the name and three buttons**, about 500 px. **Cancel sat below every veteran.** It now follows Planetfall's Muster Out (X14): Cancel first and top right, a wrapping title, and one `HFlowContainer` per veteran in which the name wraps at 180 px and each destination wraps on its own, because the three buttons alone (about 326 px) are wider than the phone. The Commission overlay was captured in both orientations and needed nothing (wrapped prose, the empty state, a full-width Cancel). | `test_the_retire_overlay_fits_a_small_phone` (nothing past the phone, Cancel above the title, no STOP button, six destinations at the touch floor) | TD5a, TD5b, TD5c, X17a' DETECTED |

### The turn (`TacticsTurnController.tscn`, 8 phases)

| Phase | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Turn lifecycle | **A Tactics campaign could never reach turn 2.** `start_new_turn()` ran only while `campaign_turn <= 0`, so every later entry resumed at Orders of the same turn. The phase is now recorded on the core at every change and at turn end (`record_turn_phase`). Entering after an ended turn starts the next one, a turn left midway resumes on its phase with its tallies, and a save older than the record resumes at Orders as before. The turn end shows "Turn N is complete and saved" with **Start Turn N+1**. | `test_tactics_turn_resume.gd` (8) | TR1-TR9 DETECTED (10 runs) |
| Top bar | The Dashboard button was 40 px and, with its smaller font, rendered at 40 (46.4 dp) in landscape. It is now `TOUCH_TARGET_MIN` in both orientations. | `test_the_turn_screen_dashboard_button_meets_the_touch_floor` (drives both layout classes on the live `ResponsiveManager`) | TSF8 DETECTED |
| Width | On a 2560 px tablet each value sat about 2,500 px from its label. The content is now an 800 px centred column. | `test_the_turn_screen_keeps_a_readable_column_on_a_wide_screen` | TSF14 DETECTED |
| 0 Orders (p.96) | Titled "Operational Orders", which is p.98's Step 4, and it carried a "Battle Plan" card: in this book that is the p.58 AI Battle Plan System. It is now **Commit Your Force**, with an Operational Zone card quoting p.96 Step 1 ("Each player-controlled force will be assigned to a particular Operational Zone") and Step 8 ("Choose player commitments"). Both checked against `tactics_source.txt`. | `test_the_orders_step_names_the_operational_zone` | TT2, TT2b DETECTED |
| 4 Battle | The no-VP CheckBox ran to 318 on a 310 px phone and now wraps. **"Play another battle this turn" sat below the outcome buttons**, and pressing an outcome completes the phase, so it had to be ticked before the button it qualifies. It is now above them. | `test_every_turn_phase_fits_a_small_phone`, `test_the_play_another_option_comes_before_the_outcome_buttons` | TSF9, TSF15 DETECTED. TSF10 UNDETECTED by design: the play-another label is 225 px against 278 of room; its wrap is a guard for larger UI scales. |
| 5 Post-Battle | "<unit> — completely destroyed" ran 21 px past a phone and now wraps. | phases case | TSF11 DETECTED |
| 6 Advancement | The refit options (p.108) are CheckBoxes that exist only while a refit is pending, so they get their own case. | `test_the_refit_options_fit_a_small_phone` | TSF12 UNDETECTED by design: the longest option is 164 px against 270 of room (measured). |
| 7 Strategic | The adjacency CheckBoxes ran to 330 on a phone and now wrap. | phases case | TSF13 DETECTED |
| All phases (touch) | **Three phase panels left their last row STOP.** Each panel swept itself once, then added a button row, so a drag that started on that row never reached the panel's scroll. The controller now calls `TouchScrollOpener.keep_open(self)`. | `test_touch_scroll_sweep.gd` (X16) | TW2 DETECTED |

## Bug Hunt — per screen

Captures `bh_land2` / `bh_port2` (`capture_modes.gd -- mode=bug_hunt`, 2026-10-28): every
creation step empty and filled, the dashboard with Enlist and Muster Out open, all three turn
stages before and after their action, the turn-end card and the battle modal. Cases are in
`test_bug_hunt_screen_fit.gd` (**fit**) and `test_bug_hunt_screen_flow.gd` (**flow**) unless
named, and the arms are in `arms_bh.log`. The common shape: every creation step, all three
turn stages and the Battle Card **scrolled sideways on a phone**, because seven panel scrolls
left the horizontal axis on AUTO while holding unwrapped titles, a 420 px CheckButton and
rows of fixed text. `verify_layout` cannot see that (content inside a scroll may overflow
it), so the fit cases assert the render truth: no scroll shows a horizontal bar, and no
text ends past the screen edge.

### Creation wizard (`BugHuntCreationUI.tscn`, 4 steps)

| Step | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Header and nav | **The title ran off a 310 px phone (it ended at x=332).** An HFlowContainer moved it under Cancel but let the unwrapped Label demand its whole width. It is now an HBox with an expanding, wrapping title. Back, Next and Launch Campaign side by side need more than a phone's width, so the nav row is a flow row. | fit `test_every_creation_step_fits_a_small_phone` | BH21 is that case's arm; the header has no arm of its own |
| 1 Config | Scrolled sideways: the axis is off and every label and the generate button wrap. | same | as above |
| 2 Squad | The stat row was one HBox. It flows now, and prints the p.170 profile in p.170's order and format (React, Spd in inches, CS and Savvy signed, Tough), through one `stat_pairs_for()` that the Review step, the dashboard grunt line and Special Assignments also use. | same; flow dashboard case (order) | BH21, BH17 DETECTED |
| 3 Equipment | **The weapon profiles were literals** ("Range 14, 1 shot") beside the Mission step's data-driven copy. They print `RefText.profile()` from the data. A melee weapon printed a 0" range; it prints "Brawl · Dmg +0" (p.179: "Boarding sword  Brawl  –  0  Melee"). That fix is in `DisplayText`, so Planetfall's Carver Blade and the other melee weapons get it too. | flow `test_the_equipment_step_prints_the_data_profiles`, `test_a_melee_weapon_prints_as_brawl` | BH1, BH2 DETECTED |
| 4 Review | The Movie Magic list was a literal; it is the ten p.181 abilities from `BugHuntCampaignCore.movie_magic_abilities()`. The profile uses the p.170 order. | — (it shares the dashboard's source) | no arm of its own |

### Dashboard (`BugHuntDashboard.tscn`)

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Header and column | **Edge to edge, and the title sat under the Settings buttons.** The content went straight into a full-rect scroll (x=0 on a phone, 2560 px wide on a tablet), which has neither shape `reserve_band_on()` looks for. The margins are now inside the scroll (the Tactics and Planetfall shape), the band is reserved, and a tablet gets a centred `MAX_FORM_WIDTH` column. The zero-caller `_apply_content_max_width()` went with it. | fit `test_the_dashboard_clears_the_settings_band_on_a_phone` (asserts the band is non-zero first); flow `test_a_tablet_gets_a_centred_column` | BH10, BH11 DETECTED |
| Continue card | **The subtitle was a literal**, "Start the next campaign turn", whatever the state. `continue_text()` names where the turn resumes ("Start turn 1", "Resume turn 2: Mission"). A turn saved at Post-Battle with no battle result resumes at Mission, where the battle can be played. | flow `test_continue_names_where_the_turn_resumes`, `test_the_dashboard_reads_its_lines_from_the_campaign_and_the_data` (rendered on screen, not only computed) | BH13, BH14 DETECTED |
| Stat tiles | A fresh campaign read "Turn 0"; it reads "—". The tiles are words (SQUAD, MOVIE MAGIC, REPUTATION). | dashboard case | covered by the BH14-BH17 runs |
| Movie Magic | **A literal list beside the core's own table.** It is the ten p.181 abilities from `movie_magic_abilities()`, each marked used from `is_movie_magic_available()`. ⚠ The literal held `["evac", "Evac"]`, which the census counted as Evac's reader (see the Evac row and Instruments). | dashboard case | BH15 DETECTED |
| Grunt pool | The profile was a literal, "R:1 S:4 CS:0 T:4". It is `grunt_profile_line()` from `grunt_stats` (p.170 format). | dashboard case (seeds the pool through `generate_fire_team(4)`; an empty pool draws no profile) | BH16 DETECTED |
| Enlist and Muster Out (F2) | **Enlist with no Five Parsecs save opened a blank page with no way back.** Step 1 was drawn only when a later `load_characters_*()` call redrew it, and no save means no call. Cancel was at the bottom. A source with nobody eligible ended at a bare header. A missing saves folder returned before drawing. Step 1 now draws at `_ready`, Cancel is first and top right at 48 px, and the empty states say why (`empty_text()`, `is_eligible()`: enlist takes a character from another mode, p.212; muster-out takes a main character, never a grunt, p.213). The save buttons are 48 px and wrap. | flow `test_enlisting_with_no_save_shows_a_way_back`, `test_a_squad_with_nobody_to_muster_out_says_so` | BH3, BH4, BH5 DETECTED |

### The turn (`BugHuntTurnController.tscn`, 3 stages)

| Stage | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Phase strip | **It hid the stage the player was in.** It shared the top row inside a horizontal scroll, so a phone showed "1. Special Assig". It has its own row and wraps. | fit `test_every_turn_stage_fits_a_small_phone` (no exemptions) | that case's arms are BH22 and BH23b |
| Column | Full width on a tablet; it is a centred `MAX_FORM_WIDTH` column with 16 px gutters on a phone. | flow `test_a_tablet_gets_a_centred_column` | BH12 DETECTED |
| Footer | **It read "Complete Phase" in every stage and could never be pressed.** It enabled on `can_advance()`, which is true only once the phase is complete, and `complete_current_phase()` moves on in the same call. It now names the stage's own next step, or shows nothing. | `test_bug_hunt_turn_completion.gd` | BH20 (with F1) |
| 1 Special Assignments (F1, p.183) | **The rolled results were never seen.** Roll All called `complete()`, which moved the turn to Mission in the same frame, so the result cards were built and hidden unread. The old turn-completion case asserted that jump. The results now stay on screen with "Continue to Mission". Roll All works once per turn, because a second press re-applied every award. The trooper line was "R:1  S:5  CS:1" on one unwrapped line, which set the stage's width; it is the p.170 line. The assignment picker clips, with a detail line under it for the target and award. | `test_bug_hunt_turn_completion.gd::test_rolling_real_assignments_advances_the_turn_to_mission` (rewritten); fit | BH20 DETECTED; BH23 UNDETECTED by design, BH23b DETECTED (Instruments) |
| 2 Mission | The per-trooper row (a 140 px name and a 280 px loadout picker in one HBox) ran off a phone. It flows. | fit | BH22 DETECTED |
| 3 Post-Battle | **The receipt stayed live after the turn ended**: a box ticked then changed nothing, because every answer had already gone to the phase manager. The controls lock and the button says the step is done. The resolver's prompt is a sentence, and unwrapped it set the receipt's width (895 px on a 310 px phone); it wraps. | flow `test_post_battle_locks_once_completed`; fit | BH9 DETECTED |

### The battle screen in Bug Hunt mode (`TacticalBattleUI`, shared)

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Setup checklist (L3, p.184) | **A Bug Hunt battle opened on the Core Rules checklist**: roll the p.88 deployment condition and the p.89 Notable Sight, roll to Seize the Initiative, run the Enemy wizard. Bug Hunt has none of those. Its troops land within 3" of a random edge (p.190), and each round opens with Reaction dice, not an initiative roll (p.198). `BugHuntBattleGuide.setup_checklist()` gives p.184's Mission Generation steps 1, 2, 8 and 9 from data: the battle area (p.184, a new `battle_area` block), the six objective dice (p.185), Tactical Locations and Contacts (p.190), and the troops (p.190). The steps rolled before launch say so, so nobody rolls them twice. `PreBattleChecklist.set_setup_steps()` is order-independent: after `_ready` it swaps only the step rows, so reminders appended later survive. TBUI branches on the mission's `battle_mode`. | flow `test_a_bug_hunt_battle_sets_up_by_its_own_steps`, `test_a_five_parsecs_battle_keeps_the_core_rules_steps` (Alpha-1 arm), `test_swapping_steps_after_ready_keeps_appended_rows`; fit `test_the_bug_hunt_battle_card_fits_a_small_phone` | BH6, BH7, BH8 DETECTED |
| Modal width | **It scrolled sideways on a phone and cut the card's rules text mid-word.** The width driver was the Core checklist's dice-roll row (360 px), which the p.184 steps do not have. The title and the step check boxes wrap. | fit battle case (prints the min-width spine on failure) | BH7, and PF7 for the check box |
| Evac (p.201) | **No screen told the players about Evac.** `bug_hunt_missions.json:evac` had no reader (the census counted the dashboard literal as one). The Battle Card has an Evac row ("request it from Round N", the roll, arrival, loiter rounds, priority, supporting fire). The round prompts say it opens one round before it does, and while a call is outstanding they ask whether it arrived. `evac.retry` was added from p.201 ("roll again at the end of each battle round until the drop ship arrives"). | flow `test_evac_is_on_the_card_and_in_the_round_prompts` | BH18, BH19 DETECTED |

## Battle Simulator — per screen

Captures `sim2` / `sim3` (`capture_modes.gd -- mode=simulator`, 2026-10-29) at 2560x1600 and
393x851: setup top and bottom, the battle launched through the screen's own launch handler,
the results card fed the return shapes `TacticalBattleUI` emits, and Play Again. Cases are in
`test_battle_simulator_setup.gd` and the arms are in `su_sim/arms_sim.log`. This pass absorbs
Sprint 6's S1-S10 rows, because every one of them is on this screen.

The common shape was the one this plan keeps finding: **the screen described one battle and
fought another.** The setup panel rolled a preview, Launch sent only the SETTINGS, and the
screen rolled a second battle from them, so the crew, the enemy count and the mission on the
preview were not the ones on the table. Behind that, the generator invented its own rules: 5
enemies plus a difficulty bonus, identical clones, a crew with random stats and no weapons,
crew size 3, a 1-5 difficulty scale, and no p.88 or p.89 rolls.

### Setup (`BattleSimulatorSetupPanel`, `BattleSimulatorSetup`)

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Launch (S7) | **The preview and the fight disagreed.** The panel now holds one rolled battle, `_context`, re-rolls it on every change (and on Roll Again), and Launch sends that battle. A settings dict is still accepted by the screen and rolled there. | `test_launch_sends_the_battle_the_preview_shows` | SIM-7 |
| Crew (S5) | **Random stats, no equipment, size 3 allowed.** Crew size is 4-6 (p.63), default 6. Every member is the p.15 Baseline Human (React 1, Speed 4", Combat +0, Tough 3, Savvy +0) and carries a weapon rolled on the p.28 Military and Low-tech tables through the same DiceManager contexts as campaign creation. With a crew under six the rest are spares. | `test_crew_is_the_p15_baseline_and_sized_4_to_6` | SIM-3, SIM-3b, SIM-3c |
| Opposition (S3, S4, S6) | **5 + numbers + a difficulty bonus, identical clones.** The force is `EnemyGenerator.generate_enemies_as_dicts()`, the campaign's own: the p.63 crew-size dice, Specialists, a Lieutenant and the Unique Individual roll. A chosen category rolls its own table (`roll_core_enemy_type()`). The preview prints "N × Type (including ...)" with the profile and rules. | `test_enemy_numbers_come_from_the_crew_size_dice` (40 rolls at crew 4 must vary) | SIM-2 |
| Mission (S8) | **No p.88 or p.89 rolls, and their consequences nowhere.** The mission rolls its objective and Notable Sight (p.89) through `MissionTableManager` and its Deployment Condition (p.88) through `DeploymentConditionsSystem`, whose D100 now goes through DiceManager ("Deployment Condition", a new QA forcing row). `BattleSetupRules.compute()` applies the result as the campaign does: Small Encounter sits a random crew member out and trims the opposition. | `test_the_battle_carries_its_p88_p89_rolls_and_their_consequences` (forces 43) | SIM-5, SIM-5b, SIM-5c |
| Difficulty (S9) | **A 1-5 scale whose 3 and 5 were the deprecated HARD and NIGHTMARE.** The dropdown is the five p.64-65 modes, and its note reads the battle effects from the `DifficultyModifiers` accessors, not a literal. The p.112 Seize the Initiative context is built by one shared `build_battle_context()`, which the campaign's turn controller now calls too, so the two cannot drift. | `test_only_the_five_book_difficulty_modes_are_accepted`, `test_hardcore_carries_its_seize_the_initiative_penalty`, `test_one_initiative_builder_serves_the_campaign_too` | SIM-4, SIM-6, SIM-6b, SIM-6c |
| Ownership (S2, S11) | **A Simulator force read the auto-loaded campaign.** `GameState` loads the last campaign at every launch, so its Compendium toggles, house rules, Progressive Difficulty and elite substitution reached Simulator battles. `EnemyGenerator` reads the mission's `standalone` flag (the T11-49 signal) once per generation and withholds all five. The case enables the Progressive Difficulty flag and asserts its premise first: without the flag the toggle cannot unlock, and the assertion would pass with the guard removed. | `test_a_standalone_force_reads_no_campaign_setting`; `test_compendium_difficulty_toggles.gd::test_the_generator_reads_every_toggle_through_one_chokepoint` | SIM-8, SIM-8b, SIM-8c, SIM-8d |
| Raw dice (S10) | `BattleSimulatorSetup` rolls through `DiceManager.legacy_randi_range()` with a context per roll. | covered by the forced p.88 case | no arm of its own |

### Results (`BattleSimulatorResultsPanel`)

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| The card (S1) | **Blank on every path.** All four emit sites send `crew_casualties` and `crew_injuries` as counts, with the records in `*_data`, and the panel assigned the count to an `Array` variable, which aborted `show_results()` before it wrote a word. Measured on all three captured shapes. `summarize()` reads either form. | `test_the_results_card_shows_every_return_shape` | SIM-1 |
| Objective (p.90) | The card said nothing about the p.89 objective this pass gave the battle. It prints "Objective (Fight Off): achieved" or "not achieved", because a won fight can still miss the objective. | same case | SIM-1b |
| Phone width | A fixed 500 px card ran ~100 px off a 393 px phone, taking Main Menu with it. The card fills the column, and the buttons flow. | `verify_layout -- only=battle_simulator` 8/8 | — |
| Evacuation | The "It's time to go!" Star is the only evacuation path, and the Simulator withholds Stars, so this card never receives that shape. Were it to, it would read DEFEAT, since leaving the table forfeits Holding the Field (p.115, as the emit site cites), and the objective line would still say whether the objective stood. | — | — |

### The screen (`BattleSimulatorUI`)

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| After a battle (S9 margins) | **The results and the next setup ran edge to edge, under the Settings icons.** `_set_margins(0)` gave the battle the screen and nothing put back the centred column or the Settings band. `_restore_margins()` re-applies both. | `test_returning_from_a_battle_restores_the_centred_column` (asserts the premise that the column is centred first) | SIM-9 |
| Rotation mid-battle | `_apply_content_max_width()` runs on every resize, so rotating a tablet mid-battle squeezed the battle into the 800 px column. It returns while a battle is up. | `test_a_rotation_mid_battle_leaves_the_battle_full_screen` | SIM-9b |
| Header | **"BATTLE / SIMULATO / R" on a phone.** A word-wrapped Label in an HBox gets only what the Back button leaves, and WORD_SMART then breaks inside a word. The header is a flow row, and the unwrapped title takes its own line where it does not fit. ⚠ The Bug Hunt pass went the other way for its own creation title (HFlow to HBox with a wrapping title), because that title ran past a 310 px phone unwrapped (it ended at x=332). Which shape is right depends on whether the title fits the narrowest screen whole. "BATTLE SIMULATOR" does at 310 px, and the case measures that rather than assuming it. | `test_the_phone_title_never_breaks_mid_word` (line count AND right edge at 310 px) | SIM-10, SIM-10b |
| Play Again | `_last_config` was written on every launch and read by nothing, so Play Again offered whatever the panel last showed. It restores the settings and rolls a new battle with them. | capture `sim_05_play_again` | — |

## 5PFH and shared — per screen

Walked 2026-10-29 at 2560x1600 and 393x851 (design 338x734). Arms are in
`su_5p/arms_5p.log`: 123 arms DETECTED. Six UNDETECTED arms led to a better test and were
then DETECTED (S4, S5, BU10, HR3, EM2, CF13; see Instruments). Two stay UNDETECTED, each for
a measured reason (CF9, CF12).

The common shape on the 5PFH side was **a screen that works on a desktop and fails on a
phone, while the windowed sweep stayed green**. `verify_layout` builds the creation wizard
at step 1 only, so steps 4, 5 and 7 ran off a phone, clipped at both edges, with every gate
green. `test_creation_steps_fit_a_phone.gd` walks all seven steps in the real screen at a
phone's design size.

### Creation wizard (`CampaignCreationUI.tscn`, 7 steps)

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Step warnings | **Four warnings on a correctly set-up campaign, each from a different cause.** "Crew size not set" read `config.crew_size`, which nothing writes; the config step writes `campaign_crew_size` (p.63). "Captain combat stats need setting" tested `combat < 1`, and Combat +0 is the Human baseline (p.15). Two "not generated via backend system" warnings read a `backend_generated` flag with no producer. The world step's result never reached the final check. | `test_creation_wizard_warnings.gd` (5 cases) | W1-W5 |
| Phone fit, steps 4, 5, 7 | **The page outgrew a 338 px phone and was clipped at both edges** ("ll Everything", "/anderer", "MPAIGN CONFIGURATION"). Twenty drivers, each found by a spine walk, then the next exposed: Stars of the Story's 400 px floor (in the script AND the scene) and its 280 px card floor; the Ship cards' 450 px floor, now applied only where it fits; HBox rows of buttons, badges and stats turned into flows; the credits line stacked; prose and names wrapped. | `test_every_creation_step_fits_a_phone` | CF1a-CF8, CF10, CF11, CF14-CF20 |
| Final Review, long names | **A 30-walk hunt ran step 7 off a phone once**, on an XL captain name ("Commander Parker Liang", 260 px). The campaign, ship and captain names and the difficulty line now wrap. The same probe found **two cards sharing one 260 px row**, Extras squeezed to 62 px beside Equipment: a flow places children by their minimum widths, and a card whose text wraps has a minimum of a few pixels (CF17 had wrapped the Extras line). A phone now gets a VBox, a real single column; the two-column flow stays for wide screens; and the swap re-runs on a layout change, so a rotation re-stacks. | `test_the_final_review_stacks_its_cards_and_wraps_long_names` (long names set, not rolled; asserts every card owns its row) | CS1-CS3 |
| World name | The world step prints the name in XL. Rolled names are short, so the walk could not fail on it. | `test_a_long_world_name_wraps_on_a_phone` | CF13 (rerun) |
| One create button | **The final step had two buttons for one action.** The footer's "Start Campaign" calls the panel's `_on_create_campaign_pressed()`, and the panel also drew "Create Campaign & Start Adventure" at the bottom of its scroll. The in-page button is gone. The footer still learns validity, which the panel used to announce only while its own button existed. A second tap during finalization is ignored. | `test_the_final_step_has_one_create_button` | SB1-SB3 |
| Equipment cards | A melee weapon printed `RNG 0"` and `SHT 0`. Core Rules p.50 prints its range as "Brawl". | `test_an_equipment_card_prints_a_melee_range_as_brawl` | BR1 |
| Manual Select | **The equipment screen's catalogue was a five-item literal in neither book**: a Military Rifle at Damage 1 (p.50 prints 0), a "Combat Armor" with a "Heavy" trait, a "Medkit", and four invented crew ("Captain Reynolds", "Dr. Chen") when none was handed over. Its details pane could only print zeros, because it read `DataValidator.validate_equipment()`'s fixed-key copy. The catalogue is `equipment_database.json`, the pane reads the item, and the crew is only what the panel hands over. | `test_equipment_manager_catalogue.gd` | EM1, EM2-EM4 (rerun through the grid button) |

### Character sheet (`CharacterDetailsScreen`) and crew

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| The 8 sweep failures | **All eight windowed `verify_layout` failures** (s4p2 gate) were this screen. The coloured initials were drawn over an EMPTY portrait icon, which is now hidden while the initials show. The two hero-card buttons were under 48 dp. Overlaid on the card's corners, they covered its content and collided by 30 px on a phone, so they now sit in a flow row under the card. The CalloutCard's uppercase title never wrapped, so its width became the card's. | `test_card_layout_floor.gd`, `test_crew_pager.gd` | CC1-CC3, HB1, HB2, HR1-HR3 |
| Advancement | The stat and training sections were HBoxes of cards, so their minimum was the sum of the cards. They flow, needing one card of width. | `test_the_advancement_sections_need_only_one_card_of_width` | AD1, AD2 |
| Creation summary | It printed storage keys (`COMFORTABLE_MEGACITY`) where the player reads names. | `test_the_creation_summary_shows_names_not_storage_keys` | DN1 |
| Add Member | **A blank page, and its Create button added nobody.** It navigated to `SimpleCharacterCreator` as a whole screen; that script hid itself in `_ready()`, its `character_created` had no listener, and it rolled stats with an invented `ceil(2D6/3)`. The layout sweep force-shows hidden roots, so it measured that screen visible and green. Crew Management now hosts the creator the wizard and the Campaign Editor use (`CharacterCreator.tscn`) as an overlay, and adds through `add_crew_member()`. SimpleCharacterCreator.gd is deleted. | `test_crew_add_member.gd` | CR1-CR3 |

### Campaign dashboard, journal, patrons and rivals

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Header | Between turns the header read "Turn 9 — None". It reads "Turn 9". | `test_between_turns_the_header_names_no_placeholder_phase` | DH1 |
| Journal | An empty journal said its filters hid everything. It says the journal is empty. | `test_an_empty_journal_is_not_called_over_filtered` | JE1 |
| Patron cards | A patron card printed an invented relationship score and an empty status line. | `test_patron_rival_manager_reads_real_rivals.gd` | PR1, PR2 |

### World phase and post-battle

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Crew-task dice | Find a Patron, Recruit, Track and Repair (pp.77-78), the loot subtables (pp.131, 134) and the Military Weapon Table (p.28) rolled with raw `randi()`, so the QA "Force the next roll" rows queued values nothing consumed. They roll through `DiceManager`. | `test_crew_task_and_salvage_dice_forcing.gd` (each case forces two values landing in different rows) | C1-C4 |
| Training (p.25, p.125) | The Compendium courses were sold in Advancement for credits alone, with no application roll, and stored as traits nothing read. They are offered by the step-10 dialog. Instructor waives the fee and the roll. Fixer adds +1 to patron and recruit rolls, and a Broker adds +1 to Find a Patron. | `test_compendium_training_wiring.gd` | TR1-TR5 |
| Ship Components (p.60) | **Every Component was free.** The screen asked the `GameState` autoload for `get_credits()`/`remove_credits()`, which it does not have, so the guard was always false. The dead-guard lint cannot see it, because both names exist on `GameStateManager`. One Component per turn, working from the next turn. The screen's second copy of Upkeep (Repair, Pay Debt) and its fuel tank are gone. | `test_ship_component_purchase.gd`; the voucher order in `test_training_and_reward_wiring.gd` | SH1-SH5 |
| Bot upgrades (p.123, Compendium p.26) | **Every Bot read 0 credits** (the sheet read credits from `GameState`) and the install was rejected before it ran (a Node passed to a Resource parameter). "Each ability score can be upgraded only once" had no record (`bot_upgraded_stats` was declared nowhere). Improved armor casing's 5+ save, the Multi-wave scanner's Seize +1, the Deflection module and the p.46 built-in save now reach the battle and the auto-resolver. Salvage pays toward an upgrade (p.147). | `test_bot_upgrades.gd` | BU1-BU9, BU10 (rerun), BU11 |

### Battle screen (`TacticalBattleUI`) and PreBattle

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Core checklist | The checklist offered a "Roll d100" beside the p.88 and p.89 steps, which were already rolled before the battle, so a player could get a second answer. Its Seize step taught an invented "Roll 1d6, on a 6" rule, where p.112 is 2D6 plus the crew's best Savvy, 10+. The dice row (`DualInputRoll`) rolled raw, and as an HBox it set the battle modal's width past a phone's edge; it wraps. | `test_dual_input_roll_and_core_checklist.gd` | K1-K4 |
| Objective panel | A free "Reroll" drew a new objective and displayed it while the tracker scored the original. Every battle was labelled "Opportunity". | `test_objective_display_read_only.gd` | O1, O2 |
| Fickle Scans (Compendium p.34) | It named the sight from a `name` key the roller never writes, so the log read "(unknown)", and the removal flag had no reader, so the marker stayed on the map. | `test_fickle_scans.gd` | F1-F4 |
| Figure cards | No card ever named a weapon: `_unit_card_dict()` never carried the key. Crew read the equipment database, so a Hand Cannon is not missed by a name filter. A tap kept the card's tier strip. | `test_battle_card_weapons.gd` | WC1-WC3 |
| Modal chrome | A tall modal ran its title and scrollbar under the floating Settings buttons on a phone. It is centred in the space below them. | `test_battle_modal_clears_chrome.gd` | MC1 |
| Font sizes | 27 sites wrote a fixed size while the other 24 scaled through `_scaled_font()`, so the crew rail, terrain controls, psionics card and end-of-phase checklist kept a desktop size on a phone. | `test_the_battle_screen_scales_every_font_size` | FS1 |
| Enemy dice | The p.63 count, the p.94 encounter column, the category tables, the p.104 weapon tables and the pp.105-107 Unique Individuals rolled raw, so a Unique Individual or a Roving Threat could be walked on a device only by luck. | `test_enemy_dice_forcing.gd` | D1-D6 |
| Auto-resolve finds | Every auto-resolver returned a random 0-2 `battlefield_finds` count, in neither book and read by nothing. p.120 rolls once when you Held the Field, and `PaymentProcessor.process_battlefield_finds()` decides how many (two for Scavengers, p.94). | `test_an_auto_resolved_win_carries_no_invented_finds_count` and each resolver's shape case | FC1-FC4 |

### Compendium salvage, reference and help

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Salvage dice (pp.137-146) | Every Salvage Job table and the p.137 availability roll rolled raw. They go through `DiceManager`, as one helper (`roll_die`) the resolver also uses. | `test_the_salvage_tables_can_be_forced`, `test_salvage_availability_can_be_forced` | S1-S3, S4/S5 (rerun), S6 |
| Mission pages | "Mission Types" rendered `mission_templates.json` under a Core Rules label: credit rewards of 100-1500, a 1-5 difficulty, and objectives in neither book. The pages read `data/mission_tables/`, which `MissionTableManager` rolls from, and the objectives page lists p.89's. The Rival note quotes p.91. | `test_compendium_mission_reference.gd` | MR1-MR3 |
| Category view | The description sat above the list and did not scroll with it. | `test_the_category_description_scrolls_with_the_list` | CV1 |
| Context help | **`help_context_map.json` named a section for every screen, and nothing read it**: `get_context_help()` had no caller, and `HelpScreen` ignored its section argument. The "?" chrome button opens the guide at the screen's section, in place, as Settings opens (navigating to Help would free a half-filled wizard). | `test_context_help_overlay.gd` | H1-H4 |
| Store chapter | **Chapter 13 listed the packs' contents differently from the Store.** It put Skulker and Psionics in the wrong packs and named features nothing in the app is called ("Loans System", "Prison Planet Campaigns"). The text was there before this sprint. The lists are rewritten from `DLCContentCatalog`, which builds the Store's cards. | `test_the_store_chapter_lists_each_pack_as_the_store_sells_it` | H5 |

### Bug Hunt co-op (Sprint 5 UI, agent-built, verified here)

Four agent arms were re-run independently in batch G, plus B1: sector Priority from the map
(p.211), a refused sector generating nothing, a victory recorded once, the map rolled once at
Launch, and the post-battle panel telling the resolver it is a co-op campaign. All DETECTED.

### Colours, cross-cutting

| Area | Verdict and fix | Pinned by | Arms |
|---|---|---|---|
| Inline hexes | **137 `Color("#...")` literals in 22 UI files**, most of them the OLD values of tokens `UIColors` has since moved (`#D97706` was `COLOR_WARNING`, `#252542` `COLOR_ELEVATED`, `#4FC3F7` `COLOR_FOCUS`). The battle screens drew a palette the rest of the app had left, and comments such as `Color("#1A1A2E")  # COLOR_BASE` named a token the code did not use. Each maps back to its token. Hover shades derive from their base token (`lightened()`), so a hover stays lighter than its button. PreBattle's selected crew toggle is `COLOR_ACCENT.darkened(0.5)`, because light text on the bare accent measures about 3.3:1. Three categorical palettes (die tints, event-art tints, the activation toast) are named consts. Rendered after the change: Simulator setup, battle and results at both sizes (`user://shots/hex_*`). | `test_ui_scripts_write_no_inline_hex_colours` | HX1 |
| Token names | 16 consts in five files bound a token's own NAME to a legacy hex (the Simulator screens, `TerrainLegendStrip`, `SectorRulesPopover`): the `TerrainLegendStrip` trap CLAUDE.md records, still live. Each is the token now. | `test_no_const_restates_a_token_with_a_hex` | HX2 |
| Avatars | Five screens kept their own copy of the coloured-initials list, and the Bug Hunt squad's was a different palette, so a character moved between modes changed colour. One `UIColors.AVATAR_COLORS`, read through `avatar_color()`. | `test_every_avatar_reads_the_one_palette` | HX3 |
| The reference | `deep-space-theme.md` listed the legacy values as "Still Supported", and the QA checklist (DS-01..DS-11) and the Bug Hunt reference prescribed them, so a correct screen would have failed QA. All three now point at `UIColors.gd`. | — | — |
| `get_visible_rect` | **Audited: 60 code reads in `src/ui`, none deciding orientation.** The eight that compare height with width are all fallbacks for a missing `ResponsiveManager`, an autoload, so dead in the app. Six compare one axis with a design-pixel threshold (a fit question). The other 46 are single-axis size reads for popups, columns and margins. | — | — |

### Rendered and swept, no change

Captured at both sizes, read against the step they serve, and measured by the windowed sweep
(295/296 before CV1; the one failure was the category view, fixed above). No defect found:
the Campaign Editor, Equipment Generation, the six World Phase steps, PreBattle, the
Post-Battle sequence (14 steps), Galaxy Log (the long title truncates with an ellipsis),
Print Sheets, Settings, Store, the Legal viewer, the EULA (Accept and Decline reachable on a
phone) and Game Over. MainMenu sits behind the first-launch EULA gate in the capture profile,
which holds no consent, and consent is not written into `user://` to get past it; its
geometry comes from the sweep.

### CONFIRMED (read, no change)

- **Co-op stash:** Compendium p.210 says 1D6 Support points and p.211 says "+5". The code
  follows p.210, the procedural page, and `bug_hunt_coop_campaign.json` records
  `stash_size_contradiction`.
- **Bot stat upgrades are once per ability score** (Core Rules p.123: "Each ability score can
  be upgraded only once"), as the sheet now enforces.
- **PreBattle remembers the representation mode.** Its only writer is `PreBattleUI:1334`, on
  the player's own pick. By design.
- **`reactions` vs `reaction`:** one property, with a bridge alias (`src/core/character/Character.gd:117`).
- **The `CampaignScreenBase` stat strip** (`Models:1  Battles:0`) is the shared helper's
  format, legible on the 5PFH crew screens; unchanged.

### Filed for Sprint 6 (found here, outside this pass's screens)

Each was read, not inferred, and goes to the Sprint 6 table in the plan:
`WorldGenerator`'s danger, tech, government, population, locations and special features with
bogus pp.80-86 cites, and `WorldInfoPanel`'s `WORLD_TEMPLATES` and `_generate_world_traits`;
`PostBattleContext.add_patron()`'s no-argument path (`:729-755`) and
`PatronManager.generate_patron()` / `required_skills`; the p.70 Raided count
(`calculate_raided_enemy_count`, zero callers); `EnemyGenerationWizard` (unreachable), with
`WeaponTableSystem`'s weighted table and `_determine_enemy_category`'s 70/30 split, the last
raw D100s in `EnemyGenerator`; `CrewTaskComponent`'s fabricated Rival shape (`:4102-4106`);
`generate_random_encounter()` (zero callers); the `Character.weapons` substring heuristic;
and the background display name kept in at least five copies (`src/core/character/Character.gd:919`,
`CharacterGeneration.gd:113`, `CharacterCreator.gd:66`, `background_table.json`,
`character_creation_bonuses.json`) while `GlobalEnums.get_background_display_name()` only
capitalises the key.

## Instruments — tests that were wrong first

Recorded so the next reader does not trust a green case that cannot fail.

- **TU1, first run UNDETECTED.** The tutorial-fit case asserted `page <= scroll width`. A
  ScrollContainer whose horizontal axis is disabled has already grown to its page's
  minimum, so that holds however far the page overflows (measured: need 318, room 318).
  The case now measures the scroll's right edge against the screen edge (reverted: 346 on
  a 338 screen).
- **The roster suite's phone bar was loose.** It compared each step's page to 338, the
  whole screen. A step really gets `338 − 2 × NARROW_SIDE_MARGIN − scrollbar`, which is
  290. The margin is now a named constant (`PlanetfallCreationUI.NARROW_SIDE_MARGIN`) that
  the test reads, so the two cannot drift.
- **F1, F14, L2, first runs UNDETECTED.** Each revert left a second path doing the same
  work: the footer re-disabled after the step set it (F1b), the mission pick through the
  emitted signal (F14b), and the clip without the trim (L2b). Each second arm reverted the
  path the case actually depends on.
- **The transfer-page case measured empty pages.** It built each panel and never loaded a
  source, so Step 1 was never drawn and the case stayed green while Import ran off a phone.
  It now draws the empty Step 1 (what a fresh device shows), Step 1 with a long-named
  veteran, and Step 2. This is the T11-01 shape again: a layout check of an unpopulated
  screen.
- **The Close case could not see the Enemy Tracker.** With no Tactical Enemy the tracker is
  short, so a Close at its foot is on screen anyway. The fixture now adds three enemies from
  the real generator, and OV27 is detected.
- **Tactics: four UNDETECTED arms, each measured rather than explained away.** TSF6/TSF7:
  the 40 px buttons were never under the floor (the theme draws them at 42 design px,
  48.7 dp), so the "46.4 dp" comments were arithmetic on a literal and are corrected.
  TSF10, TSF12 and CF1: each label fits its room at 310 px (225/278, 164/270, and "Build
  an armored platoon"), so those wraps guard larger UI scales and fix nothing measured.
  TSF12's first run used the plain phase walk, which never draws the refit options; it got
  its own case and was still UNDETECTED, which is what sent it to be measured.
- **A headless Settings-band case is real, not vacuous.** The band reads 60 px with no
  window (the buttons sit at y 12-60), so `test_the_dashboard_clears_...` asserts the band
  is non-zero before it asserts the title clears it.
- **The link-tap case first failed in both arms.** The tap landed in the empty part of a
  60 px row, so even the closed label did not fire. It now aims at the text line and
  asserts the closed-label premise.
- **The old turn-completion case pinned F1.** `test_rolling_real_assignments_advances_the_turn_to_mission`
  asserted that Roll All moved the turn to Mission, which was the defect: the results were
  hidden in the same frame. It now asserts the results stay until Continue, and BH20
  (putting `complete()` back) fails it.
- **The Bug Hunt census counted a dashboard literal as Evac's reader.** Its read forms include
  `["key"` unassigned, which also matches the first element of an array literal, so the
  Movie Magic literal `["evac", "Evac"]` satisfied it. A census proves a read form exists,
  not that the data is read. Replacing the literal with the data surfaced the missing
  consumer.
- **The battle-card spine stopped at the footer.** It started at the modal, but a scroll
  whose horizontal axis is AUTO does not pass its child's minimum up, so the walk ended at
  "Begin Battle". It starts inside the scroll.
- **BH23 was UNDETECTED by design.** It removed `clip_text` from the assignment picker but
  left `text_overrun_behavior` on the next line. A probe measured the picker's minimum width
  at 267 px with neither, and 32 px with either one alone, so the pair is belt and braces.
  BH23b removes both and is DETECTED. ⚠ The probe's first run read 32 for every
  configuration, including neither: the minimum-size cache had not been built in the same
  frame. Read it after a frame.
- **A shell detector called a LF file CRLF.** `od -c | grep -c '\\r'` reported 11 on
  `data/planetfall/mission_types.json`, which had 464 LF and no CR. The edit script asserts the ending on the
  bytes, so it stopped before writing.
- **A backtick in a double-quoted `-c` blanked a word.** Bash ran it as command substitution
  and "weapon_traits" vanished from a census comment. Edit scripts go through the Write tool.
- **The first full gate (`sub`) failed two cases, and both were instruments.**
  `test_checklist_builder_is_not_self_recursive` read `_items()`'s body as "up to
  `func _table_size_ft`". `set_setup_steps()` now sits between them and calls `_items()`
  legitimately, and the window read that call as recursion. The body now ends at the next
  top-level `func`; IN1 (a truly recursive `_items()`) is DETECTED.
  `test_a_refusal_prints_its_reason_instead_of_a_zero_roll` found "Story Point" on the
  refusal screen. It was Step 1's explanation: F2 draws Step 1 at `_ready`, and the fixture
  called `_show_enlistment_result()` directly, skipping the `_clear_steps()` that both
  product callers run first. Until F2 the blank page made that skip free. Five render calls
  across two suites now clear first, and the text walkers skip nodes queued for deletion.
  ⚠ A **positive** `contains()` would have passed vacuously on the same leftover text. IN2
  (`held >= 0`) was UNDETECTED because a fixture with no save reads **-1** held. IN2b
  (`if true:`) offers the rescue unconditionally and is DETECTED.
- **The second full gate (`sub2`) failed a case nothing in this pass touched:**
  `test_compendium_mission_types.gd::test_each_generator_stamps_its_dispatch_type`. The
  report read *"Expecting 'salvage' but was 'salvage'"*, because gdUnit4 prints a string
  mismatch as a coloured character diff and the log strips the colour, so a deleted word
  reads like the expected one. The actual value was `""`: Compendium p.137's availability
  D6 returns no job on a 1, and the case called the generator once. Measured alone: 3
  failures in 5 runs before the fix, 0 in 10 after. It now draws until a job is on offer,
  as `test_salvage_availability.gd` already did. No arm: the defect is a die roll, so a
  reverted run fails only some of the time.
- **A false lead, not filed.** The February legacy save showed zero stats on Enlist. It
  nests the character under a `character` key and exists only on the dev machine.

- **SIM-2, first run UNDETECTED.** `test_enemy_numbers_come_from_the_crew_size_dice` asked
  whether 40 Simulator battles fielded more than one enemy count, and stayed green with the
  p.63 dice reverted to a fixed five. Each battle also rolls a p.88 Deployment Condition, and
  its `enemy_delta` (Small Encounter and the rest) changes the size of even a fixed force. The
  case now subtracts the delta before counting, and the arm is DETECTED.
- **The standalone toggle assertion could not fail at first.** `_campaign_toggle()` returned
  false with the standalone guard removed too, because `strength_adjusted` unlocks only
  through Progressive Difficulty Option 2 (p.31) and that flag is off in the test process. A
  premise assertion (a campaign battle DOES get the toggle) went red, the case now enables
  the flag for itself and restores it, and SIM-8b is DETECTED.
- **A source-scan anchor caught a refactor of mine.** `test_final_partial_rows.gd` anchors on
  the exact form `if _option_2_blocks_elite():`, and folding `_standalone or` into that line
  failed it. The two reasons are now two guards, so the anchor still names the Option 2 gate.
- **The first full gate (`susim`) caught the same shape again, and my own filter had hidden
  it.** `test_compendium_difficulty_toggles.gd` anchored three cases on
  `is_toggle_active("<id>")` inside `EnemyGenerator`, and all five reads now go through
  `_campaign_toggle()`. The suite stopped at its first failure, so the gate read 4095 executed
  of 4102 declared. The suite was in the 27-suite "related" batch I ran before the gate, but I
  read that batch through `tail -20` over 27 per-suite lines, which cut the failure out. The
  anchors now name `_campaign_toggle("<id>")`, and a new case pins the chokepoint's route
  (it calls `CompendiumTogglesRef.is_toggle_active(toggle_id)`, returns early when standalone,
  and no other site calls the toggle rules directly; arm SIM-8d DETECTED). The related batch
  was re-run and read by its `Overall Summary` line: 30 suites, 486 / 486, 0 errors,
  0 failures. Read a batch by its total, never by a tail of its parts.

- **The capture tool reported Settings running off a phone, and it did not.**
  `capture_modes.gd` sized the window before mounting each screen and again before each
  shot. SettingsScreen restores `user://window.ini` (1600x2560) on entry and builds at
  that size, so the phone shot was a tablet-type page shrunk to 393x851. `verify_layout`
  and `verify_rotation` have carried a guard for this since T11-04, and this tool did not.
  The tool now rebuilds a screen that moved the window, re-applying the size before
  freeing, as the sweeps do. The re-capture prints `NOTE SettingsScreen.tscn moved the
  window to 1600x2560; rebuilt at 393x851` and the page fits. The same run fixed a second
  artifact: MainMenu routes to the EULA through `SceneRouter`, that screen outlived the
  capture, and its title showed through under the Store header. Anything a shared screen
  adds to the root is now freed with it.
- **S4, S5, first runs UNDETECTED.** The salvage cases (Tension, Authorities) forced one
  value on tables with only a few rows, so a raw roll could land in the forced row and pass
  with the routing reverted. Each case now forces two values that land in different rows.
- **BU10, first run `NO STATISTICS`.** The revert left the file unparseable, so the suite
  loaded no cases. That reads like an undetected arm and measures nothing. The rerun used a
  revert that parses, and it is DETECTED.
- **HR3, first run UNDETECTED.** The case counted the hero-card action row by NAME. A row
  rebuilt per page collides on its name, Godot renames it `@HFlowContainer@N`, and the count
  misses it. The case counts the buttons by their text, which Godot never renames.
- **EM2, first run UNDETECTED.** The case called the details handler with the item, which
  skipped the grid's binding, the thing reverted. The rerun drives the grid button.
- **CF13: a BAD CONTROL, then UNDETECTED, then a deterministic case.** The unreverted
  control failed once: the walk rolls its names, and one roll gave the captain an XL name
  wider than a phone. A 30-walk hunt in one process named that driver (CF13 itself was the
  world name). Rolled world names are short, so the walk could not fail on them, and the
  arm was UNDETECTED on rerun. Both are now set, not rolled, in their own cases, and the
  arms are DETECTED. A fit test over random data needs a pinned worst case beside it.
- **CF9 and CF12 stay UNDETECTED, by measurement.** The crew card's stat row measures
  240 px as an HBox, inside the phone's column, so its flow is a guard against a longer
  label rather than a fix for a failure. The flavor row's width depends on which result is
  rolled.
- **The wizard is swept at step 1 only.** `verify_layout` builds `CampaignCreationUI` and
  measures the step it opens on, so steps 4, 5 and 7 ran off a phone with the sweep green.
  `test_creation_steps_fit_a_phone.gd` walks all seven.
- **The hex guard's premise was a guess.** It first asserted more than 300 UI scripts were
  scanned. There are 237, and the premise failed before the guard ran. It reads 200 now,
  with the measured count in its message.
- **The first full gate (`su5p`) caught a source anchor my Ship fix moved.**
  `test_training_and_reward_wiring.gd` checks that the p.134 voucher is spent after the
  affordability check, and it found the check by the text `if current_credits < `. SH1
  replaced that guard (it asked an autoload that has no `get_credits()`), so the anchor
  matched nothing and the case failed on `-1 > -1`. The suite stopped there, and fail-fast
  hid its five later cases: 4270 executed of 4275 declared. The order the case protects
  still held. The anchor is now the new read, `gsm.get_credits() < `, and arm SH5 (spending
  the voucher above the guard) is DETECTED.

## Gates

| Run | Suites | Executed / declared | Errors | Failures | Lints |
|---|---|---|---|---|---|
| su1 (after X1, X2) | 353 | 3872 / 3872 | 0 | 0 | 8/8 exit 0; orphans 0 |
| su2 (after X3, X4) | 353 | 3879 / 3878 | 0 | 0 | — |
| su3 (final tree) | 353 | 3879 / 3879 | 0 | 0 | 8/8 exit 0; `files=573 orphans=0 test_only=0 unwired_rules=0` |
| su4 (after X9-X14) | 354 | 3886 / 3886 | 0 | 0 | 8/8 exit 0; `files=573 orphans=0 test_only=0 unwired_rules=0` |
| after su4: the End Game fix | 2 (overlay pages, End Game) + compile guard | 22 / 22, 1 / 1 | 0 | 0 | 8/8 exit 0. Covered by the s4p2 full gate below. |
| s4p2 (Sprint 4 part 2, X15, SF1-SF3) | 364 | 4047 / 4047 | 0 | 0 | 8/8 exit 0; `files=575 orphans=0 test_only=0 unwired_rules=0`. Windowed `verify_layout`: 240/248, the 8 being CharacterDetailsScreen (see Not yet walked) |
| sut (Tactics pass, X16, X17) | 366 | 4072 / 4072 | 0 | 0 | 8/8 exit 0; `files=575 orphans=0 test_only=0 unwired_rules=0`. Windowed `verify_layout -- only=tactics` 24/24. Every Tactics arm DETECTED or UNDETECTED-by-design with a measurement (arms log) |
| sub3 (Bug Hunt pass, and the Planetfall battle checklist) | 368 | 4090 / 4090 | 0 | 0 | 8/8 exit 0; `files=576 orphans=0 test_only=0 unwired_rules=0`. Windowed `verify_layout -- only=bug_hunt` 24/24 and `-- only=planetfall` 24/24; `test_touch_scroll_sweep` 3/3. The third full run: `sub` failed two instruments and `sub2` a pre-existing intermittent case (see Instruments) |
| susim2 (Battle Simulator pass) | 369 | 4103 / 4103 | 0 | 0 | 8/8 exit 0; `files=576 orphans=0 test_only=0 unwired_rules=0`. Windowed `verify_layout -- only=battle_simulator` 8/8; `test_touch_scroll_sweep` 3/3; 22 arms DETECTED (`su_sim/arms_sim.log`). The first run, `susim`, read 4095 / 4102 with one failure: three source anchors of mine (see Instruments) |
| su5p2 (5PFH and shared pass, Sprint 5 Co-op, guide chapters 16-18) | 392 | 4276 / 4276 | 0 | 0 | 8/8 exit 0; `files=578 orphans=0 test_only=0 unwired_rules=0`. Windowed `verify_layout` (full) 296/296; `test_touch_scroll_sweep` 4/4; 123 arms DETECTED, 2 UNDETECTED by measurement (`su_5p/arms_5p.log`). Declared 4275 at launch: the +1 is the chapter-13 case added during the run, and the recount on the final tree is 4276. The first run, `su5p`, read 4270 / 4275 with one failure, a source anchor my SH1 fix moved (see Instruments) |

⚠ su2's delta of −1 was batch b08 executing one case more than its suites declared at
launch. That run overlapped with adding `test_every_creation_step_fits_a_phone`. su3
re-counted the same batch on the final tree at 399 / 399, which confirms it.

## Not yet walked

Every mode in this list still needs the same pass: capture, verdict and fix.

- **5PFH and shared: walked 2026-10-29.** See "5PFH and shared — per screen". Every
  item this list carried for it is a row there, including the Character Details
  sweep failures and the items found on the Bug Hunt and Simulator passes.
- **Planetfall turn steps beyond Recovery**: the sweeps build the Turn Controller resumed at
  Step 1, so the other seventeen step panels are measured only by their own suites.
- Cross-cutting: the help keys are no longer owed. During this pass, an agent working ahead on Sprint 7 (UX-0b) wrote chapters
  16-18 (Planetfall, Tactics, Battle Simulator) and gave every router screen a `help_context_map.json` key,
  pinned by `test_help_guide_ships.gd`. I checked the three chapters mechanically: every label they name is in
  the code or is a template, and no rules number is restated without its page. Still owed for Sprint 7:
  chapter 19 (Co-op Campaign) and a read of 16-18 on the device. Done in the 5PFH pass: `TacticalBattleUI`
  font sizes (FS1), hex to token (HX1-HX3), and the `get_visible_rect` audit. Planetfall (X15), Tactics (X16)
  and Bug Hunt are in both sweeps.
