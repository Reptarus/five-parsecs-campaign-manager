# Tablet walk 2026-09-04 (Lenovo TB361FU, 1600x2560 @ density 320 = 800x1280 dp)
Build: CLI `--export-debug` APK (export_format temporarily 0), commit 92466e57a.

## T10-01 — Crew Tasks "Resolve without them?" dialog renders COMPLETELY EMPTY
**Severity: high (rules-information loss, portrait AND presumably landscape)**
Screen: World Phase Step 2 of 6, Crew Tasks -> "Resolve All Tasks (1)" with 5 crew unassigned.
Observed: a uniform grey panel with only "Go back and assign" / "Resolve anyway".
No title ("Resolve without them?"), no body text.
Evidence: dialog body region (200,1400)-(1400,2150) = 900,000 px has exactly ONE
distinct luminance value (64). Not a crop artifact.
Source: src/ui/screens/world/components/CrewTaskComponent.gd:657-700.
The Label it should show names the stranded crew AND cites Core Rules pp.77-78
("Each crew member can perform one task per turn... cannot be undone").
So the player is asked to confirm an IRREVERSIBLE action with zero information.
Suspected cause: the T9-39 fix wrapped the Label in a ScrollContainer added as a
direct child of ConfirmationDialog. Needs desk repro to confirm layout vs platform.
Screenshots: 12_resolved.png, 12_dlg2.png, 12_top.png

## T10-02 — "⚔" glyph is missing from the app font; renders as a cancel-looking ✗

> ⚠ **CAUSE CORRECTED 2026-09-04 (deploy #15). The glyph is NOT missing.**
> Every `.ttf.import` sets `allow_system_fallback=true`, and a cmap parse of all
> four bundled fonts shows they lack ✓ ✗ ★ too — glyphs this device is recorded
> as rendering fine. So Android system fallback is live. Magnified 8x from a
> device screencap, U+2694 draws as two crossed blades with crossguards.
> The defect is **legibility at ~16px**, not coverage: thin monochrome strokes
> collapse into an ✗ on the button that STARTS a battle. A font fallback would
> have fixed nothing. **RESOLVED** — glyph removed from the CTA; pinned by
> `tests/unit/test_primary_cta_glyphs.gd`. Decorative sites elsewhere render
> correctly and are left alone.
**Severity: low-medium (wrong affordance signal on a PRIMARY confirm button)**
Observed: the green primary action reads "✗ Proceed to Battle" on device.
The character is U+2694 CROSSED SWORDS; Montserrat has no glyph, so it falls back
to a thin cross that reads as "cancel" on the one button that starts the battle.
Sites (all will render the same way on Android):
  src/ui/screens/world/WorldPhaseController.tscn:226   "⚔ Proceed to Battle"
  src/ui/components/common/PersistentResourceBar.gd:52  rivals counter icon
  src/ui/components/postbattle/PostBattleSummarySheet.gd:446,557
  src/ui/screens/campaign/panels/EquipmentPanel.gd:1375  weapon icon
Fix options: drop the glyph, or add a font with the coverage. Do NOT assume the
desktop editor preview is representative -- Windows has system emoji fallback.

## VERIFIED FIXED / NOT REPRODUCED (portrait)
- **T5-04** Mission Prep briefing is NOT blank: renders Objective/Enemy/Danger/
  Location/Pay in full (22_step6.png).
- **T5-03** "Proceed to Battle" is NOT below the fold: after "Ready for Battle"
  it appears in the FIXED bottom footer, fully visible (23_ready.png).
  ("Ready for Battle" correctly greys out -- it completes the step; all 6 pips ✓.)
- **Aug finding #6** Equipment panel empty after Load: NOT reproduced. Crew show
  item counts 2/2/1/1/1/1 and the stash lists 6 items with [DAMAGED] flags
  (19_step4.png).
- Errata "Lay Low (pay 1D6+1 cr)" from the Sep 3 page walk is live and visible.

## T10-03 — Patron job card shows a FABRICATED objective that battle setup then overrides
**Severity: HIGH (rules accuracy + the player builds the wrong table)**
Observed on device, one continuous flow:
  Job offer card  : "OBJECTIVE: Secure"      (World Phase step 3)
  Mission Prep    : "Objective: Secure"       (step 6)
  PreBattleUI     : "Secure Mission / Secure / Mission type: Secure"
  PreBattleUI     : "HOW YOU WIN: VIP spends a full round within 3 inches of
                     center. Bonus: +2 credits if achieved within first 4 rounds."
That win text is the **Protect** objective, verbatim from
data/mission_tables/mission_objectives.json.

BOOK (verified by PyPDF2, not memory):
- Core Rules p.89, "5. Determine the Objective": "Opportunity, **Patron** and
  Quest missions will **roll for the objective** you are undertaking."
- Core Rules p.83, "3. Determine Job Offers": a job's details are the Patron,
  the Time Frame, Danger Pay, Benefits, Hazards and Conditions. **No objective.**
- Core Rules p.91: Secure = "end 2 consecutive rounds with crew within 2\" of
  the center"; Protect = "If the VIP spends a full round within 3\" of the
  center... you Win". Two different scenarios and two different table layouts.

SO: rolling the objective at battle setup is CORRECT. The bug is that the job
generator invents an objective the book does not grant, displays it three times,
and battle setup then legitimately rolls a different one.

Mechanism (producer/consumer key mismatch):
  src/ui/screens/world/WorldPhaseController.gd:1909
      "objective": job_results.get("objective", "patrol")     <- STRING, key "objective"
  src/ui/screens/campaign/CampaignTurnController.gd:1198
      if not mission_data.has("objective_details"):  ... roll  <- DICT, different key
The job's value can therefore never suppress the roll, and is silently discarded.

⚠ It is not inert: WorldPhaseController.gd:1983 feeds the same fabricated value to
_get_battle_type_for_objective(), so a made-up field drives a real mechanic, and
:1981 builds the mission TITLE from it ("Secure Mission").

Fix direction (needs a decision): stop showing an objective on the job offer /
Mission Prep / title, since the book does not know it yet -- OR roll the objective
at job-generation time and carry it as objective_details so all four surfaces agree.
The second matches what the player expects but changes WHEN the p.89 roll happens.
Do NOT simply forward "objective" into "objective_details": the shapes differ
(string vs dict with name/victory_condition/placement_rules).
Screenshots: 16_c.png (job card), 22_step6.png (prep), 24_prebattle.png (battle).

## T10-04 — Mark Down confirm opens BEHIND the drawer that launched it
**Severity: HIGH (reads as a soft-lock)**
Repro: battle -> ≡ Panels -> Enemies -> "✖ Mark Down" on any enemy.
Observed: the screen dims, the drawer stays up, and there is nothing to tap.
Closing the drawer (tap the ~10px strip at the far left) reveals the dialog
"Mark Void Rippers Lieutenant down? / This removes the figure from the battle."
with [Mark Down] [Cancel] -- it was open the whole time, behind the drawer.
Cause: TacticalBattleUI.tscn puts DrawerLayer at **L92** and OverlayLayer at
**L10**. _on_card_* handlers call _show_overlay(), which targets OverlayLayer,
so any overlay raised FROM a drawer renders underneath it.
Note this is a regression introduced by the Phase 3 fix: the casualty confirm was
deliberately moved off a bare ConfirmationDialog (correct -- Windows misbehave on
Android) onto "the screen's own overlay", which is on the lower layer.
Affects every _show_overlay() caller reachable from a drawer, incl. the p.46
HitResolutionSheet.
Evidence: 35_markdown.png (dimmed, drawer up, no dialog) -> 36_close_drawer.png
(same state, drawer closed, dialog visible).

## T10-05 — EVERY control inside CharacterStatusCard is dead to touch in a drawer
**Severity: HIGH (Phase 3 is unreachable on the launch platform)**
Repro: battle -> ≡ Panels -> Enemies -> tap Stun / Hit / Action / Aim / Snap / ?
Observed: nothing. Screenshots byte-identical before and after, in BOTH the
Reaction Roll and Quick Actions phases, and nothing is revealed by closing the
drawer afterwards (so it is not only the T10-04 layering).
CONTROL that discriminates: "✖ Mark Down" in the SAME drawer body WORKS.
  - Mark Down is added by _populate_unit_drawer directly to `body`
    (TacticalBattleUI.gd:5707+, and it alone gets
     custom_minimum_size = Vector2(0, UIColors.TOUCH_TARGET_MIN)).
  - The dead buttons are nested inside the CharacterStatusCard PanelContainer
    (CardMargin/CardLayout/ActionSection/ActionContainer), each 60x44 px
    = 30x22 dp at this device's density 320 -- under the 48dp minimum.
Ruled out by reading the source, not assumed:
  - signals ARE connected: CharacterStatusCard._ready -> _connect_button_signals
    (:77-118); hit_requested IS connected at TacticalBattleUI.gd:5699-5701.
  - not tier gating: _apply_tier_display() (:418+) never disables the buttons.
  - not the wrong phase: retested in Quick Actions, same result.
  - taps were on target: "Hit" text bbox measured at x 601-707, y 290-301;
    taps sent to (695,295) and (654,295).
Prime suspect: TouchScrollOpener.open_subtree() (Phase 6) relaxes every STOP
descendant to MOUSE_FILTER_PASS, including nested Buttons -- but Mark Down is
also a swept Button and works, so nesting depth / the PanelContainer chain is
the real discriminator. NEEDS A DESK REPRO with node introspection before fixing;
do not guess.
IMPACT: at LOG_ONLY the whole per-figure model (p.46 Hit sheet, p.40 Stun track,
Aim/Snap, rules help) is unreachable by touch. Mark Down is the only usable
control. All of Phase 3 verified green on desktop and is unusable on the tablet.

## T10-06 — The Phase 4 battle checkpoint does NOT survive process death (RAM only)
**Severity: HIGH — this is the exact scenario Phase 4 was built to fix**
Repro (real process death, the thing desktop cannot do):
  1. Battle to Round 2, four enemies Marked Down, objective "Protect: open".
  2. `adb shell am force-stop com.reptarus.fiveparsecs`  (pid confirmed gone)
  3. Relaunch -> Continue Campaign.
Observed: Campaign Dashboard, **"Turn 21 - Upkeep"**. No "Battle in progress -
Resume". The round, the four casualties and the objective state are all gone.
The next entry to MISSION will re-roll enemies/objective/battlefield under a
table the player has already physically built.

PROOF IT NEVER REACHED DISK: pulled the live save with
`adb shell run-as com.reptarus.fiveparsecs cat files/saves/asdasdasd_1778119724.save`
mid-battle. `progress` keys are:
  battles_lost, battles_won, current_mission, current_turn_phase,
  elite_rank_xp_bonus, extra_starting_characters, faction_state, fringe_strife,
  missions_completed, patron_benefit_memory, patron_faction_affiliation,
  patron_job_offers, patron_jobs_accepted_pending, ship_component_discounts,
  suspended_crew, turns_played, world_phase_checkpoint, world_phase_results
-- **no `active_battle`**, and `grep -c active_battle` on the whole file = 0.
(`world_phase_checkpoint`, the T9-50 fix, IS there -- so saving works; this key
is simply never written to disk.)

CAUSE (read, not guessed):
  GameState.gd:1902  set_active_battle() writes ONLY
      current_campaign.progress_data["active_battle"] = data.duplicate(true)
  and `grep -n "save_campaign" src/ui/screens/battle/TacticalBattleUI.gd`
  returns **nothing**. Nothing on the battle path ever flushes the campaign to
  disk, so the checkpoint lives and dies in RAM.
The plan specified "the battle checkpoint piggybacks on gs.save_campaign() from
the same debounced writer" -- that half was never implemented.

⚠ WHY THE DESKTOP WALK PASSED THIS: the desktop resume test re-entered
`_initiate_battle_sequence()` **in the same process**, so it read
progress_data["active_battle"] straight out of RAM. The checkpoint never had to
round-trip through JSON. A same-process "resume" cannot test crash recovery.
Same family as reference_the_participant_is_not_the_crew_member: the test drove
a path the real failure does not take.

FIX: flush after the debounced checkpoint write (and on abandon/complete), then
RE-TEST WITH force-stop, never with an in-process re-entry.
tests/unit/test_battle_checkpoint.gd round-trips the dict but never touches the
save file, so it cannot catch this either -- add a case that serializes the
campaign and reads it back.

## T10-07 (minor) — two exclusive dialogs stack on campaign load
From files/logs/godot.log on the device:
  ERROR: Attempting to make child window exclusive, but the parent window
  already has another exclusive child. This window: /root/MainMenu/@Window@73,
  current exclusive child window: /root/MainMenu/@AcceptDialog@72
    _ready (res://src/ui/dialogs/DLCRequirementDialog.gd:34)
    _load_and_go_to_dashboard (res://src/ui/screens/mainmenu/MainMenu.gd:679)
Visible as a doubled dialog frame behind "Missing Expansion Content"
(04_dashboard.png). Non-fatal but it is a real engine error on a common path.

## T10-08 (minor) — "Undo Mark Down" persists after the confirm is CANCELLED
Cancelling the casualty confirm leaves the bottom bar reading "Undo Mark Down"
with the enemy count unchanged (6). It advertises undoing an action that never
happened. Observed 42_quickactions.png / 53_round2.png.

## T10-09 — Touch-drag scroll is DEAD again in the World Phase (landscape)

> ⚠ **NOT A DEFECT — CLOSED 2026-09-04 (deploy #15) as NOT REPRODUCED.**
> `ScrollContainer.scroll_started` (Android-only; fires for a drag on the
> scrollable area, never the scrollbar) **DOES fire** on the content drag, and
> the chain under the finger is clean. `scrollable_span` is only **168 px** on
> step 2 and 414 px on step 1 — the content barely overflows.
> The measurement below is invalid: the content swipe ran UPWARD (toward the
> bottom) while the "control" scrollbar drag ran DOWNWARD. With the view already
> at the bottom, the first had nothing left to travel and the second had the
> whole range. **The control differed in two variables — position AND direction —
> so it could not distinguish "blocked" from "spent".** Verified in both
> directions on both steps; the reverse drag returns a byte-identical screenshot.
**Severity: HIGH — this is T9-45 / the Aug decorative-chrome blocker, back**
Repro: landscape (user_rotation 1), Continue Campaign -> Begin Turn 21 ->
World Phase Step 1 of 6. Content overflows (outer scrollbar visible at x~2470).
  `adb shell input swipe 1280 1250 1280 450 400`   (middle of the card)
    -> diff bbox None, **0 pixels changed**
CONTROL, same screen, seconds apart:
  `adb shell input swipe 2470 600 2470 1100 500`   (the scrollbar itself)
    -> diff bbox (74,455,2484,1580), **1,442,658 pixels changed**
So the scroll range EXISTS and only the drag-over-content path is broken. That is
the exact signature TouchScrollOpener's own docblock describes:
"a screen scrolls perfectly by dragging the thin scrollbar at the edge and does
nothing at all when dragged in the middle."

The sweep IS wired here (WorldPhaseController.gd:519 ->
TouchScrollOpenerRef.open_subtree(node)), so this is not a missing call.
Two candidates, needs desk introspection to separate:
 (a) ORDER — TouchScrollOpener's docblock warns the sweep must run AFTER the
     content is populated; _open_content_to_scroll_gesture() is invoked from the
     layout/mouse_filter pass, which may precede the step rebuild. This is the
     same "ordered against SOME callers" trap as T9-50.
 (b) _SKIP — open_subtree skips ScrollContainer/Tree/ItemList/TextEdit/
     RichTextLabel/GraphEdit outright. The step cards are full of ItemLists
     (crew list, task list, job list), and an ItemList that does not itself
     scroll still CLAIMS the drag.
Note PhaseScroll is deliberately vertical_scroll_mode=DISABLED + mouse_filter=
IGNORE (:430-447) so the OUTER scroll owns the gesture -- that part behaves as
designed; the gesture just never gets there.

## T10-10 — World "CURRENT EVENT" shown does not match the persisted campaign
**Severity: MEDIUM-HIGH (it is a live rules modifier) — reproduces Aug finding #3**
Observed, same turn (21), same world (Fuller VI), two entries into the World Phase:
  1st entry : "Worker shortages make recruitment easier (+1)"
  2nd entry : "Pirate raids increase local danger level"
FILE-LEVEL PROOF (pulled live via run-as, mid-session):
  grep 'Worker shortages' save -> present
  grep 'Pirate raids'     save -> ABSENT
  qol_data/planet_data/visited_planets/world_1778119714.692/world_events
      count = 1, [0] = "Worker shortages make recruitment easier (+1)"
The renderer (src/core/world/WorldBriefingBuilder.gd:119-126) reads
`planet.world_events[size-1]`, and with a single entry that IS [0] -- so the
displayed "Pirate raids" cannot have come from the persisted array. Either an
in-memory re-roll appends to world_events without ever being saved, or the World
Phase renders the event from a different source than PlanetDataManager.
Needs a desk trace of the producer; do not guess the fix.
IMPACT: these modify play (recruitment bonus vs danger level) and feed crew
tasks, recruitment and prices, so a value that differs between the screen and
the save is a rules divergence, not cosmetic.

## T10-11 — BLOCKER: World Phase has NO navigation footer when entered via
##            "Begin Turn 21" from the dashboard — the campaign cannot advance
**Severity: BLOCKER (soft-lock of the main campaign loop)**
Observed: the World Phase renders its step content but the whole bottom bar is
missing -- no "Next Step", no 1..6 step pips, no "← Back", no "← Back to
Dashboard". Content simply ends and the rest of the screen is black. There is no
control on screen that advances the turn.
Confirmed ABSENT (not merely below the fold): dragging the scrollbar to both
extremes leaves the same empty region; the footer is a fixed sibling of the
scroll, so it should never scroll away.
Reproduces in BOTH orientations, and it is NOT rotation-caused -- isolated:
  Dashboard -> Begin Turn 21 -> World Phase (portrait, no rotation) -> ABSENT
                                                            (66_wp_portrait.png)
  rotate landscape                                          -> ABSENT (67)
  rotate back to portrait                                   -> ABSENT (68)
DISCRIMINATOR (this is the useful part):
  FIRST entry of the session, via MainMenu -> Load Campaign -> auto-route into
  the World Phase: footer PRESENT and fully working (05,06,10,15,19,22,23.png --
  Next Step, all 6 pips, Back, Back to Dashboard).
  EVERY later entry, via CampaignDashboard -> "Begin Turn 21": footer ABSENT.
So the two entry paths into WorldPhaseController do not build the same UI.
Second candidate worth checking at the desk: the turn's phase state is partially
complete on re-entry (step shows "Step 1 of 6" while Calculate Costs / Pay Upkeep
are already disabled), so the footer may be conditionally suppressed in a state
the first-entry path never produces.
Escape hatch for a player: Android BACK returns to the dashboard (BACK behaved
correctly here -- the Aug "BACK quits the app" finding did NOT reproduce), but
Begin Turn 21 leads straight back into the same footerless screen.
