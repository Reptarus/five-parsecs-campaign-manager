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

⚠ su2's delta of −1 was batch b08 executing one case more than its suites declared at
launch. That run overlapped with adding `test_every_creation_step_fits_a_phone`. su3
re-counted the same batch on the final tree at 399 / 399, which confirms it.

## Not yet walked

Every mode in this list still needs the same pass: capture, verdict and fix.

- **Bug Hunt**: every screen.
- **Battle Simulator**: setup and results.
- **5PFH and shared**: MainMenu, Settings, Help, Store, Compendium, Legal, Journal, Galaxy
  Log, Print Sheets, and the battle screens. **Measured already (2026-10-28, full windowed
  `verify_layout`, 240/248):** all 8 failures are `CharacterDetailsScreen`, at every size.
  `InitialsLabel` is drawn over `PortraitIcon` (11-17 × 67 px), `__ChangePortraitBtn` and
  `__PrintSheetBtn` are under 48 dp, and at phone portrait and small phone the page runs off
  the right edge. No file on that screen's path changed this sprint, and it sweeps before
  any variant screen, so the new baseline restore is a no-op for it. These are existing
  defects, owed in this pass. Also owed here: the shared
  `CampaignScreenBase._create_character_card()` prints its stat row as `Models:1  Battles:0`
  (`"%s:%s"`, `:1029`), seen on the Tactics unit cards. The 5PFH crew screens use the same
  helper, so the format is judged on that pass, not changed from a variant mode.
- **Planetfall turn steps beyond Recovery**: the sweeps build the Turn Controller resumed at
  Step 1, so the other seventeen step panels are measured only by their own suites.
- Cross-cutting work still owed: help keys for 19 router screens, hex-to-token in the
  remaining ~14 files, `TacticalBattleUI` literal font sizes and autowrap, the
  `get_visible_rect` audit, and Bug Hunt in `verify_layout`. Planetfall (X15) and Tactics
  (X16) are in both sweeps. The help keys resolve to mode chapters that do not exist yet,
  so they land with those chapters in Sprint 7 (UX-0b), not as keys pointing at nothing.
