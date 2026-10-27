> **Written for:** whoever does the desk work on Bug Hunt deploy #36 findings.
> **Provenance:** copied VERBATIM on 2026-09-24 from the walk session's scratchpad, where it was
> the only copy (the scratchpad is a temp directory). Nothing above the `## DESK FIXES` section at
> the bottom was edited, so window-by-window chronology, retractions and downgrades are as written
> on the day. Two evidence dumps it cites (`wa5_transfer.json`, `wa5_save.json`) are preserved
> unmodified in `docs/qa/evidence/deploy36/`; the other frame/save names it mentions were not kept.
> **Runbook:** `docs/qa/BUG_HUNT_DEVICE_WALK_2026-09-20.md`.
> **Ledger:** `docs/audits/BUG_HUNT_PARITY_AUDIT_2026-09-10.md`.

# Bug Hunt device walk — deploy #36 (versionCode 19), 2026-09-21

## CONFIRMED-OK (device)
- W-OK1  Finding J is dead on glass. w07: every generated stat renders whole --
        `CS 1 | React 2 | Tough 3 | Spd 4 | Savvy 1 | XP 1`. No trailing `.0` anywhere,
        for any of the 3 main characters. Phase 3 fixed it; Phase 6 pinned it; this is
        the first time rendered PIXELS have confirmed it.
- W-OK2  Commendation is byte-faithful and fired correctly. Compendium p.172:
        "Roll 2D6. For each 6 ... add +1 XP and +1 Reputation."
        BugHuntCharacterGeneration.gd:311-320 does exactly that. Kira Mendez shows
        "Commendation: +2 XP, +2 Rep" (two sixes) and carries XP 4 vs XP 1 for the others.
- W-OK3  Step gate is live, not cosmetic. On Step 1 the Next button was ABSENT until
        BOTH a campaign name and a generated regiment existed.
- W-OK4  Optional 4th squad slot honoured -- left blank, 3 main characters generated
        (not 4 with an empty name). p.170 3-4 range. Distinct from deferred Row D (5).
- W-OK5  Equipment screen matches p.172 exactly: Service Pistol + Trooper Armor.
        This is the screen that would have exposed Phase 6's bug_hunt_gear.json
        deletion had the deletion been wrong. It was not.

## NEW FINDINGS
- W-1  HAZARD (not a live defect). BugHuntEquipmentPanel.gd loads ZERO data files and
       hardcodes every weapon stat as a UI literal (:58-59, :70-72, :75, :83).
       This is the CheatSheetPanel shape CLAUDE.md records: "Never put a mechanic's
       numbers in a UI literal -- render the reference from the SAME data the mechanic
       reads." Severity is LOWER than CheatSheetPanel's because all six literals were
       measured against the data TODAY and every one agrees:
         Service Pistol  14"/1/0/pistol(+1 Brawl)  == bug_hunt_weapons.json  OK
         Combat Rifle    26"/1/0                   == bug_hunt_weapons.json  OK
         Shotgun         12"/2/1/Focused           == bug_hunt_weapons.json  OK
         Boarding Sword  Melee/+2 Brawl            == bug_hunt_weapons.json  OK
         Hand Cannon     8"/1/1/pistol             == bug_hunt_weapons.json  OK
         Trooper Armor   save on 5-6               == bug_hunt_armor.json save_value 5
         Fire Team       4 grunts, Combat Rifles   == bug_hunt_support_teams.json team_size 4
       So: a DRIFT hazard with no current drift. Nothing asserts the agreement, so one
       edit to either side reintroduces the CheatSheetPanel defect silently.
       NOT FIXED -- in-battle/reference surfaces are explicitly Not-in-Sprint-1.

## NOT A DEFECT (recorded so it is not refiled)
- W-N1 Godot does not release LineEdit focus on a tap outside the field. Tapping an
       empty page margin left mInputShown=true. Ordinary Godot behaviour. The working
       dismissal is the soft keyboard's own blue check/enter key.

---
## Window 2 — Step 4 review, Launch, dashboard

### CONFIRMED-OK (device)
- W-OK6  Finding J dead on TWO MORE surfaces. The Step 4 review re-renders every stat
        (`React:2 Spd:4 CS:1 Tough:3 Savvy:1 (XP:1)`) and the dashboard roster renders
        them a third time (`R:2 S:4 CS:1 T:3 Sv:1`). No trailing `.0` on either.
        Three independent render paths, three clean. Phase 6's pin covers the class.
- W-OK7  THE QA CARD IS REACHABLE ON DEVICE. "QA - Force a Roll" renders on the
        dashboard with its full description, naming all 8 forceable Bug Hunt tables.
        First device confirmation that Phase 3's QA seam survived the --export-debug
        build. This is the instrument the rest of the walk depends on.
- W-OK8  Both transfer cards present: "Enlist from 5PFH (2D6+CS >= 7+)" and
        "Muster Out to 5PFH". Phase 2's transfer-hub wiring is visible on glass.
- W-OK9  Pill row correct in 3 of 4: MCs 3, GRUNTS 4 (the free Fire Team, p.172),
        MAGIC 10 (p.181). REP is the exception -- see W-4.
- W-OK10 TURN 0 and the phase sentinel are BOTH correct, verified against the save.
        Pulled bhwalk36_bh_1790034759.save (4208 B): campaign_turn 0 and
        current_turn_phase -99. -99 is Phase 1's own PHASE_UNRECORDED
        (BugHuntCampaignCore.gd:46) -- a campaign that has never entered a turn has no
        recorded phase, which is exactly what the resume branch needs to distinguish
        from SPECIAL_ASSIGNMENTS (enum value 0, a REAL phase). Bug Hunt's campaign_turn
        increments at turn START, so 0 before the first turn is right.

### NEW FINDINGS
- W-4  *** LIVE DEFECT -- starting Reputation is DISCARDED at creation. ***
       MEASURED: review screen "Starting Reputation: 4" -> dashboard "REP 0" ->
       save on disk `state.reputation: 0`. Display, runtime and persistence all agree
       with each other and all disagree with the value the player was shown.

       ROOT CAUSE is an ORDERING defect -- CLAUDE.md's documented failure shape #3
       from the Aug 2026 page walk ("the write is undone before the read"), in a
       variant: the write happens before its TARGET is registered.

         BugHuntCreationCoordinator.finalize()
           :108   _gsm.set_reputation(squad.get("total_reputation", 0))
           :118   game_state.set_current_campaign(campaign)     <-- 10 lines LATER
           :129   campaign.save_to_file(save_path)              <-- persists the 0

         GameStateManager.set_reputation()  (:128-135)
           var camp = game_state.current_campaign if game_state else null
           if camp and "reputation" in camp:
               camp.reputation = new_amount

       At :108 `game_state.current_campaign` is NOT the new Bug Hunt core. So:
         - no campaign loaded -> camp is null, nothing is written anywhere;
         - a campaign IS loaded -> the value is written into THAT campaign.
       GameState._try_auto_load_last_campaign() runs at EVERY launch
       (continue_last_campaign_on_launch=true on this device), so the loaded case is
       the NORMAL one. 5PFH cores carry a top-level `reputation`, so
       `"reputation" in camp` is TRUE for them -- the new squad's starting Rep is
       written into the player's OTHER campaign.
         Not observed as data loss on this device: tablet_qa_run_1786210201.save
         mtime is still 2026-09-10, so nothing re-saved the polluted core. The
         mechanism is real; the damage needs a save of the victim campaign.

       *** THE SSOT-LOOKING BRANCH IS THE BROKEN ONE. *** The `else` fallback at :110
       (`campaign.reputation = ...`, the branch carrying a `lint:ignore`) writes the
       RIGHT object. Only the "route through GameStateManager for single-source-of-
       truth" branch misses. A reader auditing this file would trust the wrong half.

       COST (not cosmetic): Bug Hunt Reputation is an EXPENDABLE resource --
       `reputation_cost_for_early` (p.206) spends it for early R&R, and p.203 pays
       more of it per objective. Compendium p.172's Service History reputation rows
       (Military action +1, Extended campaign +1), the origin rows (Core systems
       world, Military outpost) and the p.172 commendation (+1 Rep per 6 on 2D6) are
       all rolled, summed, shown to the player and thrown away.

       PRODUCER CHAIN (all correct, only the write is wrong):
         BugHuntCharacterGeneration.gd:157-170  sums `total_reputation`
         BugHuntReviewPanel.gd:98               displays it -- 4
         BugHuntCreationCoordinator.gd:108      writes it to the WRONG object
         BugHuntDashboard.gd:74                 reads `_campaign.reputation` -- 0

       ALPHA-1 EXPOSURE: none. finalize() is only reachable behind A1_BUILD, so an
       Alpha-1 tester cannot trigger the cross-campaign write. Alpha-2 only.

       NOT FIXED YET -- filed during the walk, to be fixed after it.

- W-2  HAZARD, second instance of W-1's shape, this one carrying a COUNT.
       BugHuntReviewPanel.gd:102-103 hardcodes the Movie Magic card as a string
       literal -- both the count ("10 one-time abilities") and all ten names --
       while BugHuntCampaignCore._init_movie_magic() (:117-134) loads the real list
       from bug_hunt_movie_magic.json. The panel loads ZERO data files
       (grep for load(/preload(/FileAccess/.json returns only the UIColors preload).
       MEASURED TODAY: counts agree 10/10; names agree except casing -- the data has
       `You want some too?` (book casing, PDF-verified in Phase 6) and the panel has
       `You Want Some Too?`. THREE copies of this list now exist: the JSON, the core's
       hardcoded fallback id list (:133-134), and this panel literal.
       Drift hazard with essentially no current drift. Not fixed -- reference
       surfaces are Not-in-Sprint-1, and this is a creation-review surface riding
       the same rule.

- W-3  STALE PAGE CITE left behind by Phase 6. BugHuntCampaignCore.gd:113 reads
       `# Initialize movie magic from JSON (Compendium pp.182-183), fallback to
       hardcoded`. The JSON's own _source records that this EXACT cite was corrected
       on 2026-09-20 to p.181, because pp.182-183 are the Campaign Turn sequence and
       Special Assignments -- a different chapter. Phase 6 fixed the data file and
       left the identical wrong cite in the code comment.
       This is the documented "the writer relocated, the reader stayed" shape.
       One-line fix; trivial, but a wrong cite is how a future reader "verifies"
       against the wrong page.

### NOT A DEFECT (recorded so it is not refiled)
- W-N2 Service Record "1 mission" on two brand-new characters is CORRECT, and the
       suspicion was mine, filed from a third of the evidence.
       BugHuntCharacterGeneration.gd:79-111 accumulates `completed_missions` from
       THREE tables, not one: origin (:91), basic training (:101) and service
       history (:111). Sable Adler's Service History row ("Garrison or patrol
       duties", 1-10) grants none -- but `Deep space fleet` (origin 67-75) and
       `Unity Special Project` (basic training 46-50) each grant 1, so a garrison
       veteran with one completed mission is a legal, book-faithful roll.
       Kira Mendez ("Military action", 76-90) grants completed_missions 1 AND
       reactions +1 -- and she renders R:3 against the others' R:2. Consistent.
       LESSON: checking one of three producer tables produced a confident false
       lead. Enumerate the producers before filing.

- W-5  THIRD instance of the UI-literal shape -- and the FIRST one that has ACTUALLY
       DRIFTED. BugHuntDashboard.gd:129-132 describes the QA card as forcing
       "(Priority, Special Assignment, Support, Enlistment, Commendation, Origin,
       Basic Training, Service History)" -- EIGHT tables.
       QAScenarioDialog.FORCEABLE_ROLLS contains TWENTY-FIVE Bug Hunt rows.
       The 17 the card does not name:
         Objective: type · Signals: count · Tactical Location: type
         Court Martial · Casualty · Recovery Time · Muster Out · Reputation
         Operational Progress · Military Life · Brawl · Subject Pick
         (plus the die-2 halves of the paired rows)
       The omitted set is essentially the ENTIRE post-battle block -- Phase 5's slice,
       and exactly the rolls this plan's own Verification section requires forcing
       ("a forced Casualty roll kills the forced character", and forcing Operational
       Progress into a +/-5 row).
       CAUSE: Phase 3 wrote the card when it added the 16 creation/mission rows.
       Phase 5 appended the post-battle block at :125-143 and did not update the
       card. Same "the writer relocated, the reader stayed" shape as W-3 -- TWO
       instances of it in this one walk, both from later-phase additions.
       IMPACT: debug-only surface, zero player exposure. But it misinforms the
       TESTER, and it did: I read the card on the device and was one step from
       recording that the post-battle rolls are not forceable on this build.
       W-1 and W-2 are hazards with no drift; this one is the same hazard after it
       drifted, which is the argument for fixing the class rather than the instance.
       FIX (trivial): render the description FROM FORCEABLE_ROLLS -- filter on the
       "Bug Hunt" prefix and join the labels -- so the card cannot disagree with the
       table it opens. That is the CheatSheetSections.gd remedy this project already
       chose for the same defect.

---

## Window 3 - Special Assignments outcome, top-bar occlusion, phase persistence

## W-6 🔴 — Special Assignments builds a result card per character, then hides it before a frame is drawn

**Proven at source, corroborated on glass.**

`SpecialAssignmentsPanel._on_roll_all()` (from :252) rolls each character's 2D6, builds a
full result card into `_results_container` — heading, outcome, the stat award — and then,
as its LAST statement, calls `complete()` (:351). `complete()` emits `phase_completed`,
the TurnController advances to MISSION, and `_show_panel(MISSION)` hides the panel. On any
later visit `refresh()` (:50) resets `_completed` and repopulates, and `_on_roll_all()`
opens by `queue_free()`-ing every child of the results container.

**There is no frame on which those cards are visible.** They are constructed, coloured,
parented, and discarded.

Device corroboration: the frame captured ~2 s after Roll All (`w28_rolled.png`, 55,791
bytes) shows the MISSION stage with "Generate Mission" and no results; `w29.png` is
byte-size-identical, so the screen had settled.

New: grepping the audit for `results_container|result card|_on_roll_all|Roll All` returns
**zero matches**.

Shape: the T11-13 "a checked rule shown to nobody" defect, one stage further along — there
the rule was detected and only `push_warning()`ed; here the presentation is fully built and
the subtree is hidden anyway.

Why it matters beyond cosmetics: Physical Training's award is Speed +1, a permanent stat
change, and it has no other announcement. See W-8 — together they make the outcome
unobservable by any means the app provides.

## W-7 🔴 — The floating SettingsOverlay buttons occlude the Bug Hunt TurnController top bar

**Device-measured, mechanism identified by a one-variable differential.**

Measured off `w29_zoom.png` (5x zoom of full-res 2330,5 - 2560,95), landscape 2560x1600:

| element | x extent |
|---|---|
| Save button | 2456 - 2540 |
| bug-report circle | 2422 - 2477 |
| settings gear circle | 2492 - 2548 |
| **clear strip** | **2478 - 2491 (~13 px), y ~42** |

Only "Sa" is legible, between the two circles. The Reputation VALUE is behind the
bug-report circle.

Not the W-4 reputation-ordering defect: `_update_reputation_display()` (:448-452) can emit
only `"Rep: %d"` or `"Rep: --"`, so a bare "Rep:" on screen is occlusion, not data.

MECHANISM — the band is never reserved on this screen:
`CampaignScreenBase._ready()` calls `_setup_screen()` at :107 and then
`_clear_settings_overlay_band()` -> `SettingsOverlay.reserve_band_on(self)` at :112.

- `BugHuntDashboard` builds from `_setup_screen()` (:18-20), so its UI exists at :112.
  Strategy 1 finds a container, the band lands, no overlap.
- `BugHuntTurnController` does NOT override `_setup_screen()`. It overrides `_ready()`,
  calls `super._ready()` (:54), then `call_deferred("_initialize")` -> `_build_layout()`.
  At :112 the screen has ZERO children: Strategy 1 finds no MarginContainer, Strategy 2
  finds no vertical BoxContainer, both fall through to `return false`.
  The `size == Vector2.ZERO` branch schedules `_reserve_when_laid_out()`, which awaits ONE
  `process_frame` and returns early if still unsized — racing the equally-deferred build.

Same base class, same overlay, two screens; the only variable is WHEN the UI is built, and
only the deferred one overlaps. The `MarginContainer` created at :180 is exactly the node
Strategy 1 looks for — it simply does not exist yet.

The screen's own docblock (:56-59) already flags this trap for the TOUCH SWEEP: *"the base
ALSO queues a deferred touch sweep, and it queues it before this line runs, so that one
sweeps a tree _initialize() has not built yet."* The sweep was given explicit post-build
calls; the band reservation was not.

FIX (after the walk, not during): call `SettingsOverlay.reserve_band_on(self)` at the end of
`_build_layout()`, mirroring what was already done for the sweep. Moving the build into
`_setup_screen()` is the tidier option but is NOT obviously safe — `_initialize()` defers
because "scene may not be in tree yet when instantiated by TransitionManager.fade_to_scene()"
and it early-returns on `not is_inside_tree()`.

## W-8 🟡 — The Special Assignments journal entry discards the outcome payload it is handed

`SpecialAssignmentsPanel.complete()` (:56-62) emits
`{"completed_assignments": _assignment_slots.duplicate(true)}` — three populated slots,
each carrying `character_id`, `assignment_id` and `result`.

`BugHuntPhaseManager._journal_log_phase_complete(phase, result_data)` (:499) receives it and
enriches the description ONLY for `Phase.MISSION` (:506). Every other phase gets the bare
`"Phase complete: <name>."`.

Measured on device (`save_after_savetap.json`, `qol_data.journal.entries`): two entries,
both `type: milestone`, both with no `stats` and no `characters_involved`:

    'Bug Hunt - Turn 1 begins'         'Operational turn 1 opens with Special Assignments.'
    'Bug Hunt - Special Assignments'   'Phase complete: Special Assignments.'

NOT the documented fixed-key-set chokepoint: the data reaches the logger and the logger
declines it. `create_entry()` deletes nothing here because nothing extra is passed.

COMBINED CONSEQUENCE (W-6 + W-8): on a total failure the app's observable state is
byte-identical to the rule never having run. The cards are hidden, the journal entry is
contentless, and a failed roll writes no effects — so the save cannot distinguish
"rolled and failed" from "silently skipped". The player has no witness, and neither did
this walk.

## W-OK13 ✅ — Phase 1 mid-turn phase persistence VERIFIED ON HARDWARE

Pressing Save at the W-7 clear strip (tap 2485,42) wrote the save: 4,208 -> 4,910 bytes,
with the previous state preserved in the `.bak` sibling by Godot's atomic writer — a clean
before/after pair on disk at no extra cost.

    state.campaign_turn        0   -> 1
    state.current_turn_phase   -99 -> 1     (Phase.MISSION)

This is the device proof of the plan's Phase 1 step 3: `_persist_phase()` writes on EVERY
transition, not only at turn end, so a mid-turn Save stores the live phase rather than a
stale NONE. It also confirms the decode uses an explicit absent sentinel (-99) rather than
5PFH's `<= 0` rule, which would have mis-read Bug Hunt's `SPECIAL_ASSIGNMENTS = 0`.

## W-N3 ⓘ — Physical Training award: NOT a defect on current evidence, unresolved by measurement

After Roll All with all three marines on Physical Training (2D6 target 8), the save shows
speed 4/4/4 unchanged, xp 1/4/1 unchanged, `completed_assignments {}`.

Every structural cause was checked and eliminated:

- `campaign.has_method("apply_assignments")` (`BugHuntPhaseManager.gd:170`) is NOT a dead
  guard — `func apply_assignments` is defined at `BugHuntCampaignCore.gd:362`.
- No type-mismatch abort: the parameter is `completed: Array` and `_assignment_slots` is
  declared `Array[Dictionary]` (`SpecialAssignmentsPanel.gd:24`).
- `apply_assignments()` records only `result == "success"` and `continue`s otherwise, so an
  empty `completed_assignments` is EXACTLY what three failures produce.
- The stat bonus travels a different path and would have landed independently: the slot
  stores a live reference to the campaign's own character Dictionary, so the write goes
  straight into `_campaign.main_characters`.

Three characters all failing 8+ on 2D6 is (21/36)^3 = **19.8%** — unremarkable.

TO SETTLE: arm "Bug Hunt Special Assignment" in the QA card at the start of TURN 2, force a
12, and watch speed go 4 -> 5. Folds into the walk (turn 2 opens on Special Assignments) and
needs no detour. Recorded rather than reported as a failure, because "three failures" and
"the award is broken" are indistinguishable without that forced roll — which is W-6/W-8's
cost, not a separate problem.

---

## Window 4 — Step 4/5/7 audit against the book, and a page-offset retraction

### ⚠ RETRACTION FIRST: my running page cites were two pages high

Every Compendium cite I made during Windows 2-3 of this walk was derived by assuming
`printed = index + 1`. **The page tails prove `printed = index - 1`**, which is exactly what
`CLAUDE.md` already records ("Compendium = index **-1**"). Confirmed four times this window:

| PyPDF2 index | page tail | printed folio |
|---|---|---|
| 188 | `187Mission generation` | **187** |
| 189 | `188Mission Generation` | **188** |
| 190 | `189Mission generation` | **189** |
| 191 | `190Mission Generation` | **190** |
| 187 | `186Mission Generation` | **186** |

So: **Steps 4-7 are p.187** (I had been writing p.189), the **Support table is pp.188-189**
(I had 190-191), **Step 8 contacts/tactical locations is p.190** (I had 192), and the
**difficulty table is p.186**.

⭐ **The relief, and the reason this is recorded rather than quietly corrected: the SHIPPED
DATA was never wrong.** `bug_hunt_support_teams.json` already cites `"printed pp.188-189
(Support table)"` and `BugHuntMissionPanel.gd` already comments `(Compendium p.187)`. Phase 6's
provenance survives independent re-verification — the drift was mine alone, in prose, in this
session. Probable source: `docs/rules/bug_hunt_compendium_extract.txt` marker numbers, whose
offset has **never been derived from a page tail**. Do not cite that file until it has been.

---

### CONFIRMED-OK (device + book)

**W-OK14 ✅ — Priority is the lower of 2D6 (p.187), proven on hardware with a forced pair.**
Forced dice **6 and 1** produced `Priority: 1`. That single observation falsifies three wrong
implementations at once: first-die-wins (6), `max()` (6), and `roll_2d6()`'s sum (7). The code
is two separate `_roll_d6` calls plus `mini()` at
[BugHuntMissionPanel.gd:415-417](src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd#L415-L417),
with a comment stating why the sum cannot be used. Phase 3's routing is what made the force
possible, so this is also the hardware proof of Phase 3.

**W-OK15 ✅ — Spawn Rating 0 is the book's own worked example (p.187).**
*"the Spawn Rating is the Priority Rating minus 1, but the final score cannot exceed 3… A
Priority Rating of 1 would result in a Spawn Rating of 0."* The screen showed `Spawn Rating: 0`
off Priority 1. This is the hardware proof of **Phase 4's phantom `base_count` removal** — on
HEAD-before-Phase-4 a `get("base_count", 2)` against a key `bug_hunt_spawn_rules.json` does not
declare turned the book's *"if 0, none"* into *"if 0, two"*.

**W-OK16 ✅ — Contact markers = objectives + 1 centre, no adjustment on Mess Me Up (p.190).**
Device showed `Contact Markers: 4` with 3 objectives. p.190: *"Place a Contact marker on each
Objective (but not on Tactical Locations). Once this is done, place one additional Contact
marker in the center of the table."* The in-code cite at `:219` is correct.

**W-OK17 ✅ — Support Points = Priority (p.187).** Device: `Support Points: 1 (Priority 1 +
difficulty bonus 0)`, against *"Support points equal to the Priority"*.

**W-OK18 ✅ — all twelve Support rows verbatim against pp.188-189.** Target numbers checked
one by one: Fire team 7+, Sarge 5+, Sharp shooter 6+, Recon patrol 6+, Colonial militia 5+,
Scientific survey team 6+, Weapons support 4+, Grenades 4+, Intel report 7+, Soulless Recon
Team 8+, K'Erin assault marine Team 8+, Precursor explorer 8+. One benign abbreviation: the
book's *"Light Machine Gun"* renders as *"LMG"*.

**W-OK19 ✅ — the one-Hand-Cannon limit binds on hardware (p.187).**
*"one main character may opt to swap the Service Pistol… for a Hand Cannon"* — singular.
Matched-pair evidence `w36_hc_sable.png` / `w37_hc_kira.png`: with Sable's box checked, tapping
Kira's leaves it unchecked. Source is a check-then-revert at
[BugHuntMissionPanel.gd:378-386](src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd#L378-L386),
using a holder Dictionary (GDScript lambdas capture locals **by value**, so a bare bool cannot
work) and `set_pressed_no_signal()` (plain `button_pressed` re-enters the same `toggled`
handler with `pressed == false`).

**W-OK20 ✅ — the loadout dropdown offers exactly p.187's three items** (Combat Rifle, Shotgun,
Boarding Sword). Desk read; a device render of the open dropdown is still owed.

**W-OK21 ✅ — Vital +1 / Critical +2 is applied, and the p.187 clamp is in the right place.**
`_calculate_priority`'s docblock says *"Vital/Critical modifiers applied by caller after
objective generation"* — the exact shape of the documented *live code names a zero-caller
authority* trap, so the collaborator was grepped rather than trusted. **The claim is TRUE**:
`:208` is the sole call site and `:210-213` applies the modifiers. Critically, `:214`'s
`clampi(priority, 1, 6)` sits **after** them, which is what p.187 demands — *"Priority cannot be
reduced below 1 or raised above 6"* is a clamp on the FINAL value, not on the roll.

**W-OK22 ✅ — `bug_hunt_missions.json:difficulty_settings` is byte-exact against p.186.**
Independently re-verified this window against the printed table, all five rows, both book
columns plus the two footnote quantities:

| Difficulty | p.186 contacts | data `initial_contacts_modifier` | p.186 encounter | data `encounter_modifier` |
|---|---|---|---|---|
| I'm Too Pretty to Die | −1 | −1 ✅ | −1 | −1 ✅ |
| Hey, Not Too Crazy | −1 | −1 ✅ | no adj | 0 ✅ |
| Mess Me Up | no adj | 0 ✅ | no adj | 0 ✅ |
| Mega-violence | +1 | +1 ✅ | +1 | +1 ✅ |
| Living Nightmare | +1 | +1 ✅ | +1 | +1 ✅ |

Plus *"Gain +2 Support points"* on I'm Too Pretty → `extra_support_points: 2` ✅, and the Living
Nightmare footnote reproduced near-verbatim in `special_rule` ✅ (book *"less than 3"*, data
*"fewer than 3"* — a grammar correction, not a rules change). This confirms the Phase 7 audit
line. **But see W-13 through W-16: four of these five leaf keys have zero readers.**

---

### NEW FINDINGS

**W-11 🟡 — p.187's Reputation-for-Priority rule has no implementation at all.**
Book, Step 4: *"You may spend up to 2 points of Reputation, with each point raising or lowering
the Priority Rating by 1."* `_calculate_priority`
([:388-418](src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd#L388-L418)) never reads
Reputation, no control exists on the mission screen, and no other file adjusts Priority. A
player cannot buy an easier or harder mission. Plain missing feature — nothing on screen claims
otherwise, which is the only thing that keeps this at 🟡 and not 🔴.

**W-12 🔴 — p.187's Reputation-for-Support rule is PRINTED ON SCREEN and cannot be done.**
Book, Step 7: *"1 point of Reputation may be spent to gain +1 Support."* The panel renders that
promise as a literal at
[:499-505](src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd#L499-L505):

```gdscript
rep_note.text = "Spend 1 Reputation for +1 Support Point. Each option can only be requested once."
```

`rep_note` is a **plain `Label`**. There is no button, no spinner, no handler. The pool is
`_support_points_remaining = priority + bonus` (`:492`), and the only three writers of that
variable repo-wide are `:467` (init 0), `:492`, and `:538` (`-= 1` per request) — **Reputation
never enters the arithmetic.**

This is worse than W-11 by exactly the margin the CheatSheetPanel finding describes: *a dead
rule does nothing; a fabricated rule misinforms play.* The player reads an instruction, looks
for the control, and concludes the app is broken — which it is, just not where they are looking.
**Never put a mechanic's terms in a UI literal that the mechanic does not read.**

**W-13 🟡 — p.186's ENCOUNTER MODIFIER column is byte-exact in data and has ZERO readers.**
`_get_difficulty_settings()`
([:459-460](src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd#L459-L460)) is called from
exactly one place (`:155`), and that caller reads exactly one key — `initial_contacts_modifier`
at `:223`. `encounter_modifier` has no reader anywhere in `src/`:

```
grep -rn --include=*.gd "encounter_modifier" src/
  → 7 hits, ALL in src/game/world/{GameLocation,GameWorldTrait}.gd, all the 5PFH
    PLURAL `encounter_modifiers` world-trait dictionary. Zero Bug Hunt readers.
```

⚠ **Cross-reference, stated as a lead not a verdict**: the Phase 7 audit already files
`bug_hunt_enemies.json:difficulty_modifiers` as having zero readers. If those two are the same
book quantity, then p.186's Encounter Modifier has **two independent dead data homes and no
consumer**, which is a stronger statement than either finding alone. ⚠ **That existing finding's
page cite should be re-derived** — it was written before this window's offset correction and may
carry the same +2 drift.

**W-14 🟡 — a cited data value is duplicated as a hardcoded literal fifteen lines away.**
`extra_support_points: 2` is byte-exact to p.186 and has **zero readers**. The code instead does
a string comparison and a literal at
[:489-491](src/ui/screens/bug_hunt/panels/BugHuntMissionPanel.gd#L489-L491):

```gdscript
var difficulty: String = _mission_context.get("difficulty", "mess_me_up")
if difficulty == "im_too_pretty_to_die":
    bonus = 2
```

The two **currently agree**, so there is no player-visible defect today — this is a drift
hazard, filed at 🟡 on that basis. It is the near neighbour of the documented trap: there, a UI
literal held numbers that existed nowhere else; here the audited, provenance-stamped,
page-cited copy exists and is the one that does **not** bind. The remedy is one line
(`bonus = int(diff_settings.get("extra_support_points", 0))`), and it deletes the string
comparison too — one less place that knows a difficulty id.

**W-15 🟡 — the Living Nightmare special rule is in the data, verbatim from p.186, and is
shown to nobody.** *"At the end of each battle round, if there are less than 3 Contact markers
on the table, place 1 new Contact marker at the center of a random battlefield edge."*
`special_rule` has zero readers (the one grep hit,
`CompendiumDataProvider.gd:230`, is an unrelated 5PFH enemy field list). **Enforcing** it is a
battle-payload rule and out of Sprint 1 scope by the plan's own boundary — but **displaying** it
on the mission briefing is not, and a player who picks Living Nightmare is currently never told
the rule they signed up for.

**W-16 🟡 — `extra_contacts` has no basis on p.186 and disagrees with the live key on half its
rows.** Values `0 / 0 / 0 / 1 / 1` against `initial_contacts_modifier`'s `−1 / −1 / 0 / +1 / +1`.
p.186 has **two** columns and this is not one of them; it is a redundant re-encoding of the
contacts rule that keeps the positive half and silently drops the negative half. Zero readers
today, so it is inert — but it is a **trap for the next person**, who may wire the plausibly
named key and get both easy difficulties wrong with no test to catch it. Candidate for deletion
in the same spirit as `bug_hunt_gear.json`, but it is a data change and therefore an owner call.

**W-9 🔴 (carried, unchanged) — the mission page cannot be touch-scrolled after Generate
Mission.** Matched pair: `w32_generated.png` (430,901 B) → finger swipe → `w33_scroll1.png`
(430,871 B, no meaningful change) → scrollbar drag at x=2535 → `w35_bardrag_ontarget.png`
(409,750 B, scrolled). A frame that moves under the scrollbar and not under a finger is the
signature of `Viewport::_gui_call_input` stopping Mouse/ScreenDrag/ScreenTouch at a
`MOUSE_FILTER_STOP` control — wheel events are the documented exception, which is why desktop
never saw it. The panel rebuilds its own subtree and never calls
`TouchScrollOpener.open_subtree()`; it holds no reference to it.
[CampaignScreenBase.gd:124-126](src/ui/screens/campaign/CampaignScreenBase.gd#L124-L126) states
the rule this panel is outside of. **Fix is one call placed AFTER the attach** (never at the top
of a function that `await`s — the documented `call_deferred` equivalence breaks on a coroutine).

**W-10 🟡 (carried) — the Hand Cannon CheckBox is width-starved.** Its text truncates when
checked or focused, and a refused second tap (W-OK19's correct behaviour) produces no feedback
at all, so a player cannot tell "not allowed" from "didn't register".

---

### NOT A DEFECT (recorded so it is not refiled)

**W-N4 ⓘ** — two objectives both reading "Retrieve" is not a duplicate-suppression bug. Each
objective rolls its own independent nature D6 (p.185); a repeat is ordinary.

**W-N5 ⓘ** — "Generate Mission" stays enabled after generating, but `_mission_generated`
(`:144-146`) makes a second press a no-op. Cosmetic.

**W-N6 ⓘ — the `elif` at `:210-213` is correct and must not be "fixed" to `if/if`.**
It looks like a Critical+Vital mission would get +2 instead of +3. It cannot happen:
`critical_objective` is set when an objective die value appears **three** times and
`vital_objective` when it appears **twice** (`:170-190`). With three objective dice a triple and
a pair are mutually exclusive by construction, so the two branches can never both apply and
`elif` is equivalent to `if/if` here.

**W-N7 ⓘ — p.190's contact prose is ambiguous; p.186's TABLE resolves it, and the data follows
the table.** p.190 says *"Do not place this extra marker if you have selected the I'm too pretty
to die or Hey, not too crazy difficulty settings"*, where "this extra marker" could mean the
centre marker (→ −1) or the just-mentioned bonus marker (→ 0, which would make the sentence
vacuous beside *"if you have opted for Mess me up, no adjustments are made"*). **p.186's table
states it unambiguously: `Adjust by -1`.** The data is right. Recorded so the ambiguity is not
re-derived and "corrected" the wrong way — *when prose and a table state one rule, the table is
the specification.*

---

## Window 5 — the loadout dropdown, and what it does with the answer

### AMENDMENTS to rows already filed above

**W-OK20 — UPGRADED from desk-verified to DEVICE-VERIFIED.** The loadout dropdown was opened on
Kira Mendez's row (device `(437, 490)` — chosen because she has no checkbox state to disturb;
originally logged as Finn's row and corrected from the focus ring in `w41_dropdown_closed.png`). Frame moved `409,345 -> 430,965` bytes; the popup was located by sampling both frames
every 4 px and tracking the changed-pixel extremes, giving bbox `(208, 400, 904, 616)`, then
cropped at 2x and read. It renders **exactly three options and no more**, in p.187's order, with
**Combat Rifle pre-selected** (radio filled):

1. `Combat Rifle (26" | 1 Shot | Dmg 0)`
2. `Shotgun (12" | 2 Shots | Dmg 1 | Focused)`
3. `Boarding Sword (Melee | +2 Brawl)`

**W-10 — REFINED, and the refinement inverts how it reads. The clip is STATE-DEPENDENT.**
Kira and Finn render `Hand Cannon swap` in full; only **Sable, the CHECKED one**, clips to
`Hand Cannon s` — all three rows are visible together in `w41_loadout_card.png`, so this is ONE
frame carrying the control in both states, not a comparison across two captures. The tick glyph and the focus border are drawn inside the same fixed rect, and
Godot's `CheckBox` gives the icon its space first, so the Label absorbs the entire loss.
**The control is legible right up until the player uses it** — which is why a static sweep of the
unchecked screen reports it clean, and why the row as originally filed ("truncates when checked or
focused") understated how easy it is to miss.

---

### W-17 🟡 — FOUR hardcoded weapon-stat literals beside a cited data file that holds the same numbers

The dropdown read for W-OK20 renders **stats**, and the stats are string literals:

| Literal | Site | `bug_hunt_weapons.json` | Agree today? |
|---|---|---|---|
| `Combat Rifle (26" \| 1 Shot \| Dmg 0)` | `BugHuntMissionPanel.gd:364` | `combat_rifle` 26 / 1 / 0 | ✅ |
| `Shotgun (12" \| 2 Shots \| Dmg 1 \| Focused)` | `:365` | `shotgun` 12 / 2 / 1, traits `[focused]` | ✅ |
| `Boarding Sword (Melee \| +2 Brawl)` | `:366` **and** `BugHuntEquipmentPanel.gd:72` | `boarding_sword` traits `[melee]`; `weapon_traits.melee` = "Grants +2 to Brawling rolls." | ✅ |
| `Swap Service Pistol for Hand Cannon (8" \| 1 Shot \| Dmg 1). One MC only.` (tooltip) | `:373` | `hand_cannon` 8 / 1 / 1 | ✅ |

**All four agree, so there is no player-visible defect today.** The severity is the same shape as
W-14: a drift hazard where **only one of the two copies is audited**. `bug_hunt_weapons.json`
carries `_source` ("printed p.179 (Weapons and gear); pages verified 2026-09-20 against the PDF
page tails and the p.223 index") and is inside the Phase 6 census; the literals carry nothing and
are inside no gate. This is the documented CheatSheetPanel trap — *never put a mechanic's numbers
in a UI literal, render the reference from the SAME data the mechanic reads* — in its
benign-today form, and `BugHuntBattleSetup.get_weapon(id)` already exists as the lookup that
would do it.

⚠ **Stated limit, not to be overstated: this verifies LITERAL-vs-JSON consistency only.**
Compendium **p.179 has not been extracted**. Whether the JSON itself matches the book is
unverified by this row, and the recent offset retraction (see the head of this ledger) is reason
to extract before asserting it.

---

### W-18 🟠 — Step 6 collects two loadout choices per marine and DISCARDS BOTH

Grepping the panel for every mention of the two controls:

```
weapon_opt   :363 created  :364-366 three add_item  :367 min width  :368 add_child
             --- and that is the complete list. No signal. No stored reference. No reader.
hand_cannon  :333 var hand_cannon := {"assigned": false}   :375 var hc_holder := hand_cannon
             --- function-local to _build_loadout_selection(); it never escapes.
```

So a player who selects **Shotgun** goes into the battle with nothing recorded, and the Hand
Cannon assignment dies when the function returns.

**The contrast is inside the same loop, eleven lines up, and it is what makes this a defect rather
than a design choice.** `_participant_ids.append(char_id)` at `:349-350` writes to a *member*, and
`:570` stamps it: `_mission_context["participant_ids"] = _participant_ids.duplicate()`. One value
collected in this loop reaches the mission and two do not.

**Player-visible cost.** The choice does not survive leaving the screen, so a companion app whose
whole job is holding state the physical table cannot forgets the loadout immediately. And p.187's
**one-Hand-Cannon-per-squad limit is enforced only within a single build of the panel** — the
holder re-initialises to `{"assigned": false}` on every rebuild, so the constraint is re-armed from
zero while the player's mental model still has it on Sable. There is no contradiction in the data
because **there is no data**: a per-mission loadout has no canonical owner anywhere, which is the
one thing this project's data-ownership rule exists to prevent.

⚠ **This is partly a finding in MY OWN sprint code, and it is recorded at its row rather than
quietly fixed.** Phase 4 step 2 says *"Hand Cannon uses a holder dict plus `set_pressed_no_signal`
(:313-323)"*, and that fix is **correct on its own terms** — it fixed a real double-assign where
the lambda captured a bool by value. What it did was make the capture semantics exact for a value
that is then thrown away. Phase 4 step 1's stamp list (`priority`, `spawn_rating`,
`escalation_step`, `objectives[]`, `signals_total`, `participant_ids`) **never included the
loadout**, so no later step was going to pick it up.

#### Context: the battle half of the chain is dead too — OUT OF SCOPE, recorded not fixed

The plan defers the battle payload (pp.190-201) past Sprint 1, so this is filed as context for
that work and **must not be fixed here**:

| Layer | State | Evidence |
|---|---|---|
| `weapons_table` in the battle payload | **zero readers** | one writer, `BugHuntBattleSetup.gd:77`; the only other `weapons_table` hits are `CrewTaskComponent`'s unrelated 5PFH `_roll_on_military_weapons_table` |
| `BugHuntBattleSetup.get_weapon(id)` | **zero external callers** | every `get_weapon(` hit repo-wide is a same-named method on a *different* class — `WeaponTableSystem`, `PlanetfallArmorySystem`, `TacticsSpeciesBook` |
| `BugHuntCharacterGeneration.get_weapon_by_id` / `get_all_weapons` / `get_armor_by_id` | **zero external callers** | same — every hit is `GameDataManager`, `FiveParsecsCombatData`, `PlanetfallArmorySystem`, `WeaponTableSystem` |

Four stacked instances of the shape this project names *correct code with no call site*.

⭐ **The transferable part is what the census could not see, and the census is not at fault.**
`test_bug_hunt_consumer_census.gd` **passes**, and it is right by its own contract: it asserts
every *section-level* key has a reader, and `bug_hunt_weapons.json::weapons` genuinely does have
readers — four of them. What it cannot assert is that a reader is itself reachable. **A consumer
census proves a key is READ; it cannot prove the READER is live.** That is the exact inverse of
the documented wrapper trap (*grepping the wrapper and finding zero callers says nothing about the
rule*): here, grepping the key and finding a reader says nothing about whether the reader runs.
One hop is not a chain — and note the allowlist already anticipated the neighbouring key,
`bug_hunt_weapons.json::weapon_traits`, as PAYLOAD, which is correct and unaffected.

---

## Window 6 — the briefing on record, and the objective table read against p.185

### THE REFERENCE FRAME. Everything the p.201 debrief and the post-battle scorer will be checked against.

Captured from `w42_top.png` (430,173 bytes) after scrolling the mission page to the top with the
scrollbar at x=2535. This is recorded BEFORE pressing Launch Mission because the launch destroys
the screen that holds it.

```
Mission Briefing
  Objectives:       Objective dice: [3, 4, 1] → 3 objective(s)
    #3:   Retrieve — A trooper moves into contact and spends a Combat Action to pick up the
                     package. If casualty, package drops. Must hold package when Evac'ing.
    #4:   Retrieve — (identical text)
    #1:   Scout    — Completed at the end of the round during which a trooper moved to make
                     contact with the marker.
  Priority:         1
  Spawn Rating:     0
  Contact Markers:  4
  Difficulty:       Mess Me Up

Signals (Optional Rule)
  [ ] Use Signals rule this mission          <- UNCHECKED
  If 4+ Signals: must investigate at least 2 or lose 1 Objective.

Step 7: Force Strength
  FREE: Fire Team — 4 Grunts with Combat Rifles (always included)
  Support Points: 1 (Priority 1 + difficulty bonus 0)
  Spend 1 Reputation for +1 Support Point. Each option can only be requested once.
  12 Request buttons, ALL RENDERED ENABLED against that single point.
```

**Expected debrief arithmetic**, so a deviation is a finding rather than a surprise: three NORMAL
objectives at weight 1 each, no Vital and no Critical (all three dice differ), Signals rule OFF so
the p.201 4-signals penalty cannot apply. **Completing 2 of 3 is the p.201 success threshold**
(`bug_hunt_missions.json:objectives.scoring.success_threshold` = 2, quoting *"Two or more is
considered a success for the purposes of awarding Experience Points after the battle."*).
**Completing 0 is what arms Court Martial** — the defect Phase 4 closed.

---

### W-OK21 ✅ CONFIRMED-OK — two identical objectives is the BOOK, not an off-by-one

Filing this as a confirmed row precisely because it looks like a defect. Markers **#3 and #4 both
read Retrieve**, and `bug_hunt_missions.json:objectives.types` is keyed by `d6_value` where
**3 = Secure** and **4 = Retrieve** — so "marker #3 displays the d6_value-4 entry" reads exactly
like an array index used where a face value belongs, which is a real defect shape this project has
hit before. It is not one here.

Compendium **printed p.185** (PyPDF2 index 186; page tail `185Mission generation`, confirming the
−1 offset again) is explicit that these are two different dice:

> Roll three D6 and remove any of the table dice that do not match one of the numbers you rolled.
> The remaining dice become your Objectives. […] If two of the D6s rolled the same number, the
> Objective with that number becomes a Vital Objective. If all three rolled the same number, the
> one remaining die becomes a Critical Objective. **To determine the nature of each Objective, roll
> a D6 on the table below.** You may identify a given Objective marker before rolling, or determine
> the results first and assign the results to the Objective markers where they make the most sense.

So the face number is **a marker ID only** — it says which of the six table dice survived, and it is
what the Vital/Critical rule keys on. The objective's *nature* is an independent D6 per marker.
`[3, 4, 1]` selected markers 3, 4 and 1; three further type rolls came up 4, 4 and 2.
`BugHuntMissionPanel.gd:183-184` rolls exactly that and resolves it through `_find_by_d6_value`,
whose own comment records that the previous `randi() % size()` form agreed with the data only by
the coincidence that the six rows happen to be stored in `d6_value` order.

⚠ **The corollary matters for the debrief**: the app takes the book's FIRST option (roll, then
assign automatically). The book also permits assigning results to markers "where they make the
most sense", which is a table-side choice the app does not offer and is not required to.

**Arithmetic checked rather than assumed**, all three from the code and the data, all three
matching the screen:

| Screen | Formula | Source | Match |
|---|---|---|---|
| Contact Markers **4** | `objective_count + 1 + initial_contacts_modifier + extra` = 3+1+0+0 | `:220-224`; `mess_me_up.initial_contacts_modifier` = **0** | ✅ |
| Priority **1** | lower of 2D6 (p.187), +0 escalation, no Vital/Critical bump | `:204-212` | ✅ |
| Spawn Rating **0** | `clampi(priority - 1, 0, 3)` = `clampi(0,0,3)` | `:217` | ✅ |

Spawn Rating 0 is the value **Row A** of the desk probe verified end to end (0/1/3 → 0/1/3 spawn
points, with `'base_count' present in the data: false` asserted beside it), so the phantom
`base_count` that used to turn the book's *"if 0, none"* into *"if 0, two"* should produce **zero
spawn points** in the battle about to be launched. That is a device check this walk can now make.

---

### W-19 ⚠ UNTESTED, queued — twelve Support requests render enabled against one Support Point

`Support Points: 1` and **twelve** `Request` buttons, none visibly disabled. The affordability
question is untested: whether the eleven unaffordable options refuse, and whether the twelve
disable after the one point is spent. Deferred to after the battle rather than spent now — a
Support request alters the force the battle fields, and the briefing above is the reference frame
this walk is carrying into the debrief.

---

## Window 12 — the reaction roll fires, and what it rolls is the wrong shape

### W-20 🟠 — DEVICE-MEASURED: seven reaction dice for seven figures, and identical grunts split across phases

**This is device confirmation of audit row 226, and the measurement REFINES that row rather than
simply confirming it.** Row 226 reads *"a 3-MC + 4-grunt squad rolls **7** dice instead of the
book's **4**"*. The 7 is measured and correct; the "4" needs restating.

**What the device did.** With no drawer open, `Roll Reactions` (device `(2223, 1516)`) moved the
frame `372,338 → 402,661` bytes, md5 `a2a9cd34…` → `60ea6a40…`. The Battle Log prints the whole
pool, so the die count needs no inference:

```
[R1] Reaction Roll:  Sable Adler: 1 vs Reactions 2 — QUICK      (scrolled off the top)
[R1] Reaction Roll:  Kira Mendez: 4 vs Reactions 3 — SLOW       (scrolled off the top)
[R1] Reaction Roll:  Finn Adler: 4 vs Reactions 2 — SLOW
[R1] Reaction Roll:  Casey Frost: 1 vs Reactions 1 — QUICK
[R1] Reaction Roll:  Dex Ortiz: 6 vs Reactions 1 — SLOW
[R1] Reaction Roll:  Uri Kovac: 4 vs Reactions 1 — SLOW
[R1] Reaction Roll:  Pike Yang: 4 vs Reactions 1 — SLOW
[R1] Reaction Roll: Pool [1, 4, 2, 4, 4, 6, 4] → 2 Quick · 5 Slow
```

The Crew drawer agrees: `ACTIVATED 0/7 · Q 2 · S 5`, a badge on every one of the seven figures.

#### The book, extracted verbatim (marker − 2 = printed page)

**p.173** (`bug_hunt_compendium_extract.txt:715-745`):

> usually organized into combat teams of 2-4 troopers which must obey the following rules. A few
> grunts (e.g. the sniper) are elite enough to form a one-figure combat team of. They do not
> receive the team formation bonus below. **Note: Combat Teams are only used for grunts, never for
> your main characters.** Your main characters always move and fight individually.
>
> **Reactions** — Treat each combat team as a single character when rolling for Reactions, and
> **every figure in a given combat team acts in the same phase.** Example: If you have 2 main
> characters and 3 combat teams, you roll 5 dice […]
>
> **Team formation** — If a combat team is in formation, they receive a **+1 bonus to their
> Reactions score.** […] select a combat team member, and if every other member of that team is
> within 2″ of the selected figure, the team is in formation.

**p.198** (`:2520-2545`):

> To begin the round, roll a number of D6 equal to the number of your main characters and combat
> teams. For example, if you have 3 main character and 4 combat teams, you would roll 7 dice.

**p.214, Quick Reference** (`:3600-3625`):

> Roll D6s equal to number of main characters and combat teams […] Teams in formation (2″) count
> as +1 Reactions.

#### ⭐ Why the bare number 7 is NOT the finding, and row 226 should say so

p.198's worked example is *"3 main character and 4 combat **teams** → 7 dice"*. This squad is 3
main characters and 4 **grunts**. The two coincide only if each grunt is its own one-figure team —
which p.173 reserves for grunts *"elite enough (e.g. the sniper)"*. Organised as the book expects,
four grunts are **one team of 4** (3 + 1 = **4 dice**) or **two teams of 2** (3 + 2 = **5 dice**).
So the correct answer is 4 or 5 *depending on a choice the player makes*, and the app rolled 7.

**That coincidence is what makes this defect durable.** A tester who knows p.198 sees seven dice
against a printed example that says seven and concludes the rule is implemented. Change the squad
to 3 MC + 6 grunts and the app rolls 9 where the book rolls 5.

#### The two halves that need no assumption about team organisation

1. **Identical grunts split across phases.** Casey Frost, Dex Ortiz, Uri Kovac and Pike Yang are
   byte-identical stat lines (`C0 T4 Sv0 R1`) and came out **Q1 / S3**. Under p.173 they are one
   team, roll one die, and *"every figure in a given combat team acts in the same phase"*. Whatever
   organisation the player picks, **a team may never split** — and the app has no way to keep one
   together.
2. **The formation bonus is structurally unreachable.** p.173 and p.214 both grant **+1 Reactions**
   to a team in formation. With no team, there is nothing to be in formation, so a rule printed
   twice in the book can never fire.

#### Root cause: the concept exists at five layers and is connected at none

| Layer | State | Evidence |
|---|---|---|
| Rules data | **Present and book-faithful** — `team_size {min 2, max 4}`, `formation_bonus {range_inches 2, reactions +1}`, `reactions_rule`, `elite_solo_teams` | `data/bug_hunt/bug_hunt_character_creation.json:226-238` |
| Campaign core field | **Present** `var combat_teams: Array = []` | `BugHuntCampaignCore.gd:71` |
| Core mutator | **Present, ZERO callers repo-wide** | `BugHuntCampaignCore.gd:172` |
| Core serialization | **Present** — saved `:407`, loaded `:463` | round-trips an array nothing ever fills |
| Any reader of the JSON section | **NONE** | `grep '"combat_teams"' src/` hits only the core's own save keys |
| Battle screen | rolls one die per living crew unit | `TacticalBattleUI.gd:6434` |

Five layers of *correct code with no call site*, stacked. The player is never asked to organise
teams, so **the rule's INPUT does not exist** — which is why this cannot be fixed by changing the
die loop alone.

⚠ **The help text confirms intent, not accident.** The screen's own explainer reads *"Roll 1D6 for
each crew figure. A figure that rolls ≤ its Reactions acts in Quick Actions; the rest act in Slow
Actions."* That is **Core Rules p.118** — the 5PFH rule — rendered verbatim on a Bug Hunt screen.
Same shape as the three other Core Rules citations already filed in this walk.

⚠ **OUT OF SCOPE, recorded not fixed.** The plan's *Not in Sprint 1* list names *"Reaction dice per
combat team"* explicitly. This row is device evidence for that deferred work.

**Amendment owed to the audit:** row 226's *"instead of the book's 4"* becomes *"instead of the
book's 4 or 5, depending on how the player organises the four grunts into teams of 2-4 — an
organisation the app provides no way to express."*

---

### W-21 🟠 — A FALSE GREEN IN MY OWN PHASE 6 CENSUS: the reader it found was a name collision

`bug_hunt_character_creation.json::combat_teams` is a section-level key with **no reader**, in a
file the census already walks — it allowlists two other sections of that same file
(`standard_equipment:79`, `combat_operation_commendation:82`). The census **passes**.

**Why.** `_reader_paths()` (`tests/unit/test_bug_hunt_consumer_census.gd:318-327`) builds the needle
as the key wrapped in literal double quotes, and returns any Bug-Hunt-pathed source file containing
that string:

```gdscript
var needle := "\"%s\"" % key
for path: String in index.keys():
    if not str(index[path]).contains(needle):
        continue
    if path.to_lower().contains("bug_hunt") or path.to_lower().contains("bughunt"):
        hits.append(path)
```

`BugHuntCampaignCore.gd:407` contains `"combat_teams": combat_teams.duplicate(true)` — a key in the
core's **own save dictionary**, which has nothing to do with the JSON file. The census matched it,
called the row read, and moved on.

⭐ **This is a DIFFERENT shape from the one already recorded at W-18.** W-18 says *a consumer census
proves a key is READ; it cannot prove the READER is live* — one hop short of a chain. This is
worse: **the "reader" is not reading that file at all.** Any data section whose name collides with
a campaign-core field name is invisible, because the core serializes every field by name.

**Measured blast radius — 5 collisions, 1 genuinely masked.** Section keys that also appear as a
quoted string in `BugHuntCampaignCore.gd`:

| Row | Real reader elsewhere? |
|---|---|
| `bug_hunt_character_creation.json::combat_teams` | **NO — MASKED** |
| `bug_hunt_movie_magic.json::abilities` | yes — `BugHuntCampaignCore.gd:122` genuinely does `json.data.get("abilities", [])` |
| `bug_hunt_missions.json::evac` | yes — `BugHuntDashboard.gd` |
| `bug_hunt_post_battle.json::reputation` | yes — six files |
| `bug_hunt_regiment_names.json::uniform_color` | yes — four files |

⚠ **My first sweep reported TWO masked rows and that was an over-claim, caught before it was
written down.** The sweep excluded `BugHuntCampaignCore.gd` from the "other readers" search —
correct for finding collision-only matches, wrong as a verdict, because the core is *also* a
legitimate JSON reader (`:122`). Movie Magic is fine. **An exclusion built to isolate one cause
cannot double as proof of absence.**

**The cost is not that the row is unread — it is that the row is INVISIBLE.** The
`ALLOWLIST`/`NAMED_READERS` pair exists so a known-unread key is recorded *with a stated reason*
that goes stale loudly. A collision routes around that mechanism entirely, so the one Bug Hunt
rules section with no consumer is the one section the census cannot report.

**Remedy (not applied — the census is Phase 6 code and this walk is read-only):** require the hit
to look like a data read rather than a dictionary literal — e.g. reject a hit whose only
occurrences are immediately followed by `:` (a key being written) instead of preceded by `get(`,
`has(` or `[`. Cheaper alternative: exclude the owning campaign core from `_reader_paths` and
allowlist its two legitimate JSON reads by name, which turns a silent pass into an explicit one.

---

### W-22 🟠 — A drawer tab CLOSES the open drawer instead of swapping to it, and an open drawer covers the action buttons

**H1, confirmed by control.** The six drawer tabs (`Crew · Enemies · Intel · Dice · Reference ·
Tracking`, y≈1484) and the two action buttons (`Roll Reactions` x≈2223, `Consumable` x≈2425,
y≈1516) share one toolbar band. Measured:

| Action | Frame | Verdict |
|---|---|---|
| Tracking tab pressed while **Intel** drawer open | → no-drawer md5 `a2a9cd34` | closed Intel, did NOT open Tracking |
| Tracking tab pressed while **Tracking** drawer open | `573,665 → 372,338`, md5 `a2a9cd34` | closed it (expected) |

Both arms land on the **same** no-drawer state, so a tab tap is a close, never a swap. **Moving
between two drawers takes two taps**, and the second tap is on a control the player has already
pressed once with no visible effect — which reads as a dead tap.

⭐ **It cost this walk a false measurement, and that is the transferable part.** `Roll Reactions`
was pressed once with the Tracking drawer open. The frame moved `573,665 → 573,552` — **113 bytes,
non-zero** — and was recorded as "pressed, result not yet read". It had not fired: the drawer was
covering the button, the delta was drawer-internal, and closing the drawer returned a frame
**byte-identical** to three earlier pre-press states. Three signals had to agree before it was
settled: the Battle Log's newest entry was a *reset* not a roll, the Crew header read `Q 0 · S 0`,
and the closed-drawer md5 matched a known state.

⚠ **A small non-zero frame delta is not evidence a control fired.** Only an md5 against a known
state, plus the panel that would RECORD the effect, settles it. Byte size alone discriminates
"something moved" from "nothing moved" and nothing more.

---

## Window 13 — the Reference drawer is the 5PFH rulebook, rendered inside a Bug Hunt battle

### W-23 🟠 — THREE unguarded producers put Core Rules content on a Bug Hunt battle screen, and one of them contradicts the loadout screen the player used minutes earlier

**Device frame** `w54_reference.png`, 497,653 bytes, md5 `eb47b6586deb9201a71a62e02a6a83c9`, re-captured
as `w55_ref_base.png` at byte-identical size and md5 before the scroll attempt — so the reads below
are of a stable state, not a transient one.

#### What a Bug Hunt player is shown

Drawer title, wrapping across two lines beside a ⚠ triangle and a gear icon:

```
Battle Round Reference (Core Rules p.118)
```

Card **Quick Reference**, collapsible rows:

```
[+] Turn Sequence (pp.112-113)
[+] Hit Rules (pp.44-46)
[+] Damage & Armor (p.46)
[+] Morale Rules (p.114)
[+] (a fifth row, clipped at the fold)
```

Card **Weapon Reference** (yellow border), with a `Search weapons...` field and tabs
`All | Pistols | Rifles | Heavy | …`:

```
WEAPON           RANGE   SHOTS   DMG   TRAITS
Auto Rifle        24"      2      -     -
Beam Pistol       10"      1     +1    [Pistol, Critical]
Blade            Melee     0      -    [Melee]
Blast Pistol       8"      1     +1    [Pistol]
Blast Rifle       16"      1     +1     -
Boarding Saber   Melee     0     +1    [Melee]     <- highlighted, part-cut at the fold
```

⚠ **Two stacked header rows render**, `Name | Rng | Sh | Dmg | *` directly above
`WEAPON | RANGE | SHOTS | DMG | TRAITS`. Cosmetic, recorded so it is not rediscovered.

#### ⭐ The one-word discriminator: Saber, not Sword

Bug Hunt's melee weapon is the **Boarding Sword** (`bug_hunt_weapons.json`, `_source` "printed p.179").
The 5PFH weapon is the **Boarding Saber** (`data/equipment_database.json`). The drawer shows
**Saber**. A near-homograph one letter apart is exactly the kind of row that reads as correct at a
glance, which is why the list was checked against the data rather than eyeballed.

#### Three producers, none of them mode-aware

| # | Producer | Site | `battle_mode` branch? |
|---|---|---|---|
| 1 | Drawer title string | `TacticalBattleUI.gd:544` | **none** — a bare literal |
| 2 | Quick Reference section list | `CheatSheetPanel.gd:44-80` | **none** — a flat literal array |
| 3 | Weapon Reference rows | `WeaponTableSystem.gd:54` → `data/equipment_database.json` | **none** — no Bug Hunt path exists in the component |

All three are attached to `reference_content` inside `_instance_log_only_components()`
(`TacticalBattleUI.gd:1690`, adds at `:1790-1802`), and there is no mode guard anywhere on that
path. Producer 2's own docblock states the intent outright: *"All text references page numbers from
the Five Parsecs Core Rulebook."* `grep battle_mode|bug_hunt` returns **nothing** in
`WeaponTableDisplay.gd`.

#### The sharpest rules point: a Morale section for a game that has no morale

`docs/rules/bug_hunt_compendium_extract.txt:2709` reads, verbatim:

> There is no morale system in Bug Hunt: The

That line is load-bearing in this sprint's own plan — it is quoted in the Adherence model as the
justification for mirroring Bug Hunt's rules chokepoints rather than branching inside 5PFH code.
The battle screen offers a Bug Hunt player **`[+] Morale Rules (p.114)`** anyway.

#### The weapon table is not merely a superset — it CONTRADICTS Bug Hunt's own numbers

The render chain was traced end to end and is **verbatim at every hop**, with no transformation and
no mode branch:

```
equipment_database.json  "damage"
  -> WeaponTableSystem.gd:69     weapon.damage_bonus = int(entry.get("damage", 0))
  -> WeaponTableDisplay.gd:162   dmg_label.text = "+%d" % weapon.damage_bonus  (or "-" at 0)
```

That `+%d` / `-` pair is what the device frame shows (`+1` on Beam Pistol, `-` on Auto Rifle), which
confirms these are the files doing the rendering and not a same-named sibling.

**Five names exist in both books. Two carry different damage:**

| Weapon | `bug_hunt_weapons.json` (p.179) | `equipment_database.json` (what the drawer prints) |
|---|---|---|
| **Hand Cannon** | 8" / 1 shot / **Dmg 1** / `[pistol]` | 8" / 1 shot / **+2** / `[Pistol]` |
| **Power Claw** | Melee / **Dmg 1** / `[melee]` | Melee / **+3** / `[Melee, Clumsy]` |
| Hyper Blaster | 24" / 3 / 1 / `[overheat]` | 24" / 3 / +1 / `[]` — **the Overheat trait is dropped** |
| Plasma Rifle | 20" / 2 / 1 / `[focused, piercing]` | same numbers | 
| Shotgun | 12" / 2 / 1 / `[focused]` | same numbers |

⭐ **The Hand Cannon row is an in-app contradiction inside a single mission.** This walk's own
loadout screen rendered `Swap Service Pistol for Hand Cannon (8" | 1 Shot | Dmg 1). One MC only.`
(`BugHuntMissionPanel.gd:373`, read on device at W-OK20/W-17). Minutes later, the battle screen's
reference says **+2** for the same weapon. The player is not choosing between two books — they are
being shown two numbers by two screens of the same app, in the same mission, for a weapon one of
those screens just offered them.

**And ten of Bug Hunt's fifteen weapons are absent from the list entirely**, including both halves
of the p.172 standard issue:

```
Service Pistol   Combat Rifle   Carbine        Sniper Rifle    Light Machine Gun
Incinerator      Mounted Launcher   Boarding Sword   Flash Grenade   Frag Grenade
```

So a trooper carrying the book's default load — Service Pistol and Trooper armor, p.172 — can look
up neither of their weapons, while the drawer offers 36 they cannot have.

#### Stated limits — what this row does NOT claim

- **It does not say which damage number is RIGHT.** `bug_hunt_weapons.json` carries `_source`
  citing printed p.179, and **p.179 has still not been extracted** (W-17's stated limit, still
  open). The claim here is that the app contradicts itself, not that the Compendium was misread.
- **The Hand Cannon row was not read on screen.** The visible rows stop at `Boarding Saber`
  (alphabetical A-B); the contradiction is established from the data plus a render chain proven
  verbatim at every hop, and by the five rows that WERE read matching that file exactly. A scroll
  was attempted and failed — see the operational note below.
- **Tier coverage is unverified.** The instancing function is named
  `_instance_log_only_components()` and this walk is running at **Assisted**. Whether the drawer is
  built identically at every tier was not checked; that is an open thread, not a claim.

⚠ **Operational note, my own error, not a product finding.** The scroll attempt swiped from
`(2340, 1300)` — **below** the weapon table's measured extent of y 450-1070 from the earlier crop —
and closed the drawer instead (`497,653 -> 402,408`, md5 `48dbb454…`). That frame is 253 bytes off
the known post-Reaction no-drawer state (`402,661 / 60ea6a40…`); the difference is a `Battle Notes`
tooltip visible top-right. Recorded because "a vertical swipe dismisses the drawer" would have been
a plausible and completely wrong finding to file off that delta.

#### ⚠ OUT OF SCOPE — filed, not fixed

The plan's *Not in Sprint 1* block names **"Cheat Sheet"** among the 15 CONTRADICTS rows, alongside
HitResolutionSheet, BrawlResolverPanel, BattleRoundTracker and Snap Fire. This row is device
confirmation of already-deferred work and **must not be fixed here**.

**What is new, and why the decomposition is worth having.** The audit row says the Cheat Sheet
contradicts. The measurement adds three things it did not have: exactly which headings a Bug Hunt
player is offered (including Morale); that the Weapon Reference is a *separate, second* wrong
source with its own contradiction, not part of the cheat sheet at all; and that the fix is **three
edits in three files**, not one — a title literal, a section array, and a data path that has no
Bug Hunt variant to point at. That last one means the deferred work has a prerequisite the ledger
did not record: `bug_hunt_main_rules.json` (pp.174-181) must exist before producer 3 can be
pointed anywhere, and `bug_hunt_weapons.json` already holds the rows it would need.

#### Negative result, recorded because an absence is evidence

The stamped objectives, the 4 Contact Markers and the signals total appear in **none** of the three
drawers inspected — Intel, Tracking or Reference. The `Setup → Deploy → Combat` breadcrumb is the
last candidate surface. If it is not there either, then Phase 4's stamp reaches the battle screen
and the battle screen never shows it to the player, which is its own row.

---

## Window 14 — the battlefield: nothing to fight, on terrain the app itself called something else

**State control before any reading.** `w56_prerecord.png` came back **402,408 bytes, md5
`48dbb454b68abf6d53b3252ad7e139e3`** — byte- and md5-identical to the last recorded state from the
previous window. The screen had not drifted, so both crops below are of a known state. Crops were
used rather than full-frame reads: `w56_top.png` `(0,0,2560,320)` and `w56_map.png`
`(420,140,2060,1180)`.

### W-OK23 ✅ — NEGATIVE RESULT CLOSED: the stamped mission data reaches the battle screen and is shown to the player nowhere

The `Setup → Deploy → Combat` breadcrumb was the last candidate surface, and it carries only the
three phase names (Setup and Deploy teal/complete, Combat white/current). The top strip reads:

```
Tactical Companion   [ASSISTED]   Setup > Deploy > Combat
CREW 7/7 · ACTIVATED 0/7 · Q 2 · S 5                    ENEMIES 0/0 active
```

With the Intel, Tracking and Reference drawers already inspected, the surfaces are exhausted.
**Phase 4's stamp — 3 objectives, 4 Contact Markers, the signals total — reaches the battle screen
and no surface displays any of it.** Recorded as a closed negative, not an open thread.

⚠ **This is not itself a Phase 4 defect.** Phase 4's contract is that the stamp reaches the
*post-battle* chain so a played mission scores, and the debrief is where that is proved. The
battle screen displaying it is a separate concern that no plan step claims.

---

### W-24 🟠 — Four contact markers are generated, delivered, and read by nothing; the battle fields zero enemies

**Device.** `ENEMIES 0/0 active`, and the battlefield renders terrain only — no contact markers
anywhere on the 4×4 grid. The debrief reference (W-OK21) stamped **4 Contact Markers**.

This matters more in Bug Hunt than the bare numbers suggest: contact markers revealing into enemies
**is** the mode's core loop, so a battle with zero of both has nothing in it to fight.

**The chain is produced and delivered, then dropped:**

| Hop | State | Evidence |
|---|---|---|
| Count computed | ✅ `objective_count + 1 + modifiers` = 4 | `BugHuntMissionPanel.gd:226-247` |
| Markers generated | ✅ 4 dicts, each with a sector, `enemy_type: ""`, `enemy_count: 0` | `BugHuntBattleSetup.gd:40`, `:96-116` |
| Put on the payload | ✅ `"contact_markers": contact_markers` | `:69` |
| Payload built and handed over | ✅ | `BugHuntMissionPanel.gd:573` |
| **Any reader of the array** | ❌ **ZERO repo-wide** | every other `contact_markers` hit is `extra_contact_markers`, a different key — the Operational Progress *count* modifier, which does have readers |

⭐ **The map is not incapable of drawing them.** `BattlefieldMapView._draw_objective_marker`
(`:1076`) exists and 5PFH uses it for the p.89 Notable Sight. So this is not "a companion app
leaves markers to the physical table" — the same view draws 5PFH's markers and would draw these.
The array simply has no consumer.

⚠ **OUT OF SCOPE — filed, not fixed.** The plan's *Not in Sprint 1* list names
*"Contact markers, tactical locations, the signal table, Closing Down"* explicitly. This is device
confirmation of already-deferred work.

**What the measurement adds to the ledger row:** the deferred work is a *consumer*, not a producer.
The generator, the count arithmetic, the payload key and the drawing primitive all already exist and
are correct. That is a materially smaller job than the row implies, and it is the documented
consumer-without-a-producer shape **inverted** — here the producer is the orphan.

---

### W-25 🟠 — The app declares this battlefield `"indoor"` and then renders trees and a hill on it

**Book, Compendium printed p.184** (extract marker 186 → page tail `184` at
`bug_hunt_compendium_extract.txt:1602`, so the **−2 offset holds again**), verbatim at `:1589-1595`:

> A typical (3x3 feet) battlefield should contain **10 decent-size terrain features**, such as
> large rocks, a collection of smaller crates, a small structure, a forested area, or similar.
> Distribute these fairly evenly, then add **5-10 small individual features** (rocks, crates,
> single trees, etc.) in any gaps.

**Device, read verbatim off `w56_map.png`** — a 4×4 lettered grid A1–D4 on a 0/15/30″ axis (the
3×3 ft table), **20 labelled features**:

```
SMALL (13)  Building 4",6"[F]  Rock 13",3"[A]  Rock 23",4"[A]  Rock 30",4"[A]
            Building 33",14"[F]  Rock 3",19"[I]  Building 11",20"[F]  Rock 32",23"[A]
            Building 4",25"[F]  Building 2",29"[B]  Building 23",30"[F]  Rock 30",28"[B]
            Hill 30",34"[A]
LINEAR (3)  Trees 3",14"[I]   Trees 23",22"[I]   Trees 30",33"[I]
LARGE  (1)  Building 14",24"[F]   (yellow-outlined)
(none) (3)  Building 12",13"[B]   Building 23",14"[B]   Building 13",32"[B]
```

**The root cause is a producer with no consumer, wrong twice over.**

```
BugHuntBattleSetup.gd:73      "terrain_theme": "indoor"      <- hardcoded literal, no page cite
TacticalBattleUI.gd:7284      bf_data.get("theme", "wilderness")   <- a DIFFERENT key
TacticalBattleUI.gd:7288-90   comment: "FALLBACK (Battle Simulator / Bug Hunt / Planetfall /
                              standalone): no campaign-side generation ran."
```

Two independent breaks, either fatal alone. The key does not match (`terrain_theme` vs `theme`) —
**and even if it did, Bug Hunt never reaches that reader**, because `:7284` sits in the
*consume-first* branch and the file's own comment names Bug Hunt as a **fallback** case that
generates locally with a fresh seed. So Bug Hunt gets 5PFH's generator at its default, which is the
visible result: `Trees` and a `Hill` on a battlefield the app labelled `"indoor"`.

⭐ **A one-glance contradiction, the same shape as the Hand Cannon.** No rules knowledge is needed
to see that an indoor sweep should not have a forested area and a hill in it. That is what makes
this worth a row rather than a note.

#### Stated limits — what this row does NOT claim

- **The feature counts are ONE sample.** Under the app's own size prefixes this mission produced
  **7 decent-size** (1 LARGE + 3 LINEAR + 3 unprefixed) against the book's **10**, and **13 small**
  against the book's **5-10**. Generation is seeded and varies per mission, so a single mission
  cannot establish what the generator does in general. It is recorded as a measured instance.
- **The prefix-to-book mapping is an INFERENCE.** `SMALL:`/`LINEAR:`/`LARGE:` is the app's taxonomy;
  the book's split is "decent-size" vs "small individual features". A `LINEAR: Trees` maps cleanly
  to the book's *"forested area"* and a `SMALL: Rock` to its *"rocks"*, but the three unprefixed
  `Building` rows are ambiguous and were counted generously as decent-size.
- **The structural claim does not depend on either.** That Bug Hunt runs 5PFH's `pp.94-95`
  generator with a defaulted theme, and that its own `terrain_theme` has no reader, is established
  from source and holds whatever any single mission rolls.

⚠ **Supersedes the pending ledger note** *"`terrain_theme` producer/consumer mismatch: writes
`indoor`, reads `theme`, falls back to `wilderness`."* That note had the key mismatch right and the
branch wrong — it implied the fallback fires *because* the key misses. It fires regardless.

⚠ **Scope.** p.184 is **not** inside the deferred pp.190-201 battle payload and is not named in
*Not in Sprint 1*, so unlike W-24 this is not already-deferred work — it is an open audit-ledger
row. It is still **out of Sprint 1's scope**, which is the p.202 post-battle slice, and is filed
rather than fixed on that basis.

---

## Window 15 — the Record Battle Result drawer, read to its bottom edge

**State control.** The drawer was opened at `510,550` / md5 `7018b9551dcd25f73b285cf309c0a643`,
scrolled once to `511,890` / `7de3ad53bb5460c08e6a75510f6bbd39`, then twice more to
`511,963` / `4e406ded3ab3ac9abef0d64d3c1e99cd`. The last two swipes moved **73 bytes** and band A was
visually identical, so the drawer is at its scroll limit — and band C confirms that limit is
legitimate rather than a clipped overflow: the card's bottom edge and the drawer's bottom edge are
both visible below the Submit button.

### The complete inventory, read across three crops

```
Record Battle Result                                        ⚠  ⚙
BATTLE RESULTS   Record the outcome of your tabletop battle

OUTCOME     Battle Result [ Won v ]   [x] Held the field     Rounds fought [ 1 ]
ENEMIES     Defeated: [ 0 ]   / 8 total
CREW CASUALTIES   (killed or removed from play)  — 7 checkboxes WITH stat lines
              Sable Adler CS:1 R:2 T:3 Spd:4   Kira Mendez CS:1 R:3 T:3 Spd:4
              Finn Adler  CS:1 R:2 T:3 Spd:4   Casey Frost CS:0 R:1 T:4 Spd:4
              Dex Ortiz   CS:0 R:1 T:4 Spd:4   Uri Kovac   CS:0 R:1 T:4 Spd:4
              Pike Yang   CS:0 R:1 T:4 Spd:4
CREW INJURIES     (injured but survived)        — the same 7, names ONLY, no stat lines
XP CREDIT  (Core Rules p.123)
              First to inflict a casualty (+1 XP)  [ Nobody v ]
              Killed a Unique Individual  (+1 XP)  [ Nobody v ]
              [ Submit Battle Results ]
```

### W-OK24 ✅ — NEGATIVE RESULT, and it is the DESIGNED one: no objectives control in this drawer

The load-bearing question going into this read was whether an objectives control sat below the fold.
It does not — the inventory above is complete and Submit is the last control.

⚠ **That is correct, not a defect, and concluding otherwise would have been the error.** Phase 4
step 5 of the plan says *"The first card of `BugHuntPostBattlePanel` records completed objectives
(from the stamp) … The shared battle screen stays untouched."* Objectives belong to the debrief, and
the debrief is where Phase 4's headline fix must be proved. Recorded as a closed negative so the
absence is not re-investigated.

**Also confirmed incidentally:** the casualty rows' stat lines are device evidence for the pending
MC/grunt split observation — three main characters at `CS:1 T:3` and four grunts at `CS:0 T:4`.

---

### W-26 🟠 — The form invents **8 enemies** for a battle that fielded none, and the number is uncited

**Device.** `ENEMIES  Defeated: [ 0 ]  / 8 total`, on a battle whose own header reads
`ENEMIES 0/0 active` and whose map has no contact markers on it (W-24).

**Source, `src/ui/screens/battle/TacticalBattleUI.gd:3152-3155`, verbatim:**

```gdscript
var enemy_count: int = enemy_units.size()
if enemy_count == 0:
    enemy_count = 8
```

A bare literal with **no page cite, no comment and no mode guard**, in a function
(`_ensure_results_form_drawer`, `:3124`) whose own docblock is otherwise unusually well annotated —
so the silence around this line is conspicuous rather than typical for the file.

It reaches the player through `BattleResultsInputForm`, which stores it as `_enemy_count` (`:57`) and
renders it three ways (`:300-306`): the SpinBox `max_value`, the SpinBox's initial `value`, and the
`"/ %d total"` label. The device shows `0` in the spin because `_apply_prefill` (`:463-467`)
overwrites the initial value with the tracker's real count and clamps it; **the label is not
overwritten**, so the fabricated number is the one left on screen.

⭐ **The fallback is not an edge case in Bug Hunt — it is the ONLY case.** In 5PFH `enemy_units` is
filled by `EnemyGenerator`, so `size() == 0` is nearly unreachable. In Bug Hunt the entire enemy
population is supposed to arrive by revealing contact markers, and W-24 measured that array as
having **zero consumers repo-wide**. So `enemy_units.size()` is 0 on *every* Bug Hunt battle and
this line fires *every* time. A defect filed as a 5PFH safety net is, in practice, Bug Hunt's
enemy count.

**Why this is a rules row and not a cosmetic one.** This project's cardinal data rule is *never
invent game data values*, and 8 is invented: it appears in neither book for this purpose, it has no
`GAME_BALANCE_ESTIMATE` tag, and it is displayed to the player as fact. It is the documented
*"never put a mechanic's numbers in a UI literal"* trap with the aggravating factor that there is no
correct number for it to have read — the mechanic that would supply one is the unconsumed contact
markers.

**And in Bug Hunt the collected answer is discarded anyway.** `enemies_defeated` and
`enemies_remaining` are written into the submitted result (`BattleResultsInputForm.gd:810`) and have
**zero readers** across `BugHuntBattleResultNormalizer`, `BugHuntPostBattleResolver`,
`BugHuntPhaseManager` and all of `src/ui/screens/bug_hunt/`. So the player is asked how many of 8
non-existent enemies they killed, and the answer goes nowhere — the W-18 collect-and-discard shape
stacked on top of a fabricated prompt.

#### Stated limits

- **The `8` is not claimed to be wrong against a book value** — it is claimed to have no source at
  all. No page in either book prescribes a default enemy count for an unpopulated battle.
- **This row does not fix W-24.** If contact markers gained a consumer, `enemy_units.size()` would
  be non-zero and this line would stop firing in Bug Hunt. The two are related but independently
  wrong: an uncited literal in a shared file is a defect whether or not its trigger is common.

⚠ **Out of Sprint 1's scope — filed, not fixed.** `TacticalBattleUI.gd` is a shared, Alpha-1-guarded
file and Sprint 1's scope is the p.202 post-battle slice. ⚠ Note it is **not** covered by the
existing deferral either: *Not in Sprint 1* defers *"the enemy table generator, variants and pack
leaders"*, and this is a UI fallback in 5PFH code, not the generator. It is a new ledger row.

---

### W-27 🟠 — A Core Rules p.123 XP card on the Bug Hunt recording path, collected and discarded

**Device.** The drawer's last card before Submit is headed **`XP CREDIT  (Core Rules p.123)`** with
two crew pickers, *First to inflict a casualty (+1 XP)* and *Killed a Unique Individual (+1 XP)*.

**Source.** `BattleResultsInputForm.gd:364` builds it from a bare literal —
`_create_section("XP CREDIT  (Core Rules p.123)")` — with **no `battle_mode` branch anywhere in the
file**. The answers are emitted at `:849-851` as `first_casualty_by` (a crew id) and `unique_kills`
(a list), shapes the file's own comment at `:830-833` says are matched to
`ExperienceTrainingProcessor` — a **5PFH** post-battle processor.

**Zero readers on the Bug Hunt chain.** `grep` across `BugHuntBattleResultNormalizer`,
`BugHuntPostBattleResolver` and `BugHuntPhaseManager` returns nothing for either key. Bug Hunt's
experience rules are **Compendium p.204**, resolved in the Phase 5 resolver's Step 5, which pays
awards from `bug_hunt_post_battle.json::experience` and has its own MVP control.

⭐ **This is the FOURTH Core Rules citation surfaced on a Bug Hunt screen in this walk, and the
first one outside the Reference drawer.** W-23's three (`Battle Round Reference (Core Rules p.118)`,
the Quick Reference headings, the 5PFH weapon table) are all reference material a player consults.
This one is **on the recording path** — it does not merely tell a Bug Hunt player a 5PFH rule, it
*asks them to apply one*, then drops the answer. A player who correctly nominates the marine who
scored first blood is told, by a cited heading, that it is worth +1 XP; in Bug Hunt it is worth
nothing.

⚠ **"Unique Individual" is itself a 5PFH concept** (Core Rules pp.95-96, rolled by `EnemyGenerator`).
Bug Hunt's enemies come from its own tables and the mode has no Unique Individual roll, so the
second picker asks about a category that cannot occur — which is why this reads as a stronger row
than the first picker alone would be.

#### Stated limits

- **Not verified: whether a Bug Hunt player can reach a state where either answer WOULD matter.**
  The claim is that no Bug Hunt consumer reads the keys today, established by grep over the four
  Bug Hunt post-battle sites. It is not a claim about what p.204 ought to pay.
- **The fix is not obviously "hide the card".** Bug Hunt does award XP (p.204), so the honest
  remedy is a mode-aware card sourced from `bug_hunt_post_battle.json::experience` — which is the
  same prerequisite W-23 identified for its producer 3. Recorded so the two rows are costed together.

⚠ **Out of Sprint 1's scope — filed, not fixed**, for the same reason as W-26: a shared,
Alpha-1-guarded file.

---

### Operational notes, both mine

**A 1,340-byte delta was not read as proof of a scroll.** Per W-22 the first scroll's delta was
treated as "something moved" only, and the drawer was cropped and read before any conclusion. The
scroll had in fact happened — the discipline is what made that sound rather than lucky.

**An out-of-drawer diff was attributed, not filed.** The first scroll's changed bbox was
`(1189, 95, 2542, 1581)`, extending ~800 px left of the drawer's x≈1990 edge, which looks exactly
like a swipe leaking through to the battlefield map. A per-100px column band count restricted to
x < 1990 localised every changed pixel to **x 1190-1382, y 1522-1574** — the `Record Result`
button's own rect, a press highlight decaying between captures. The drawer's content is
`MOUSE_FILTER_STOP` and the gesture did not leak. ⭐ *"A swipe inside a drawer scrolls the map
behind it"* would have been a plausible, specific and completely wrong finding.

**The swipe started INSIDE the content extent.** The recorded W-23 error was a swipe from y=1300
that sat below the Reference drawer's content and dismissed the drawer instead of scrolling it.
Here y=1300 is inside the Record drawer's taller content and the drawer stayed open.

---

## Window 13 — cold relaunch, the QA card, and turn 2 with a forced Special Assignment

Device `HNQ05SR3` (Lenovo TB361FU, `ROTATION_90`, 2560x1600). App force-stopped and
relaunched cold at the start of this leg. `A1_BUILD` still flipped.

### VERIFIED — the turn-completion assertion is CLOSED, including resume

The plan's clause: *"the turn ENDS: `current_phase` is NONE, the phase is persisted,
Start Next Turn opens turn 2 on Special Assignments, pressing it twice applies the
finished turn's effects exactly once, and reopening the save resumes where it was left
rather than replaying turn 1."*

| Sub-assertion | Verdict | Evidence |
|---|---|---|
| `current_phase` NONE at turn end | PASS | between-turns footer rendered |
| phase persisted | PASS | disk `current_turn_phase = 0` at `campaign_turn = 2` |
| Start Next Turn opens turn 2 on Special Assignments | PASS | `w71_thumb.png` |
| pressing twice applies effects once | PASS | structurally unreachable on device (the button is gone once turn 2 opens); unit case 5 covers it |
| reopening resumes rather than replaying turn 1 | PASS | cold force-stop + relaunch + Continue -> TURN 2 (`w75_continue.png`) |

**The Bug-Hunt-specific decode rule is PROVEN, not merely present.** Bug Hunt's enum is
`{NONE = -1, SPECIAL_ASSIGNMENTS = 0, MISSION = 1, POST_BATTLE = 2}`, so **0 is a real
phase**. 5PFH's `<= 0 -> NONE` rule (`CampaignPhaseManager:1104-1111`) would have routed
this save to `start_new_turn()` and opened **turn 3**. It opened turn 2. Phase 1's
explicit absent/`-1` test is live on hardware.

### VERIFIED — the mode predicate routes through the real menu path

Continue Campaign from the main menu landed on **BugHuntDashboard**, not the 5PFH
dashboard. Phase 2's `campaign_type` fix verified on hardware end to end.

Cold-relaunch dashboard (`w75_thumb.png`): campaign `BHWalk36` / `Star Rats`.
Pills TURN 2 / REP 1 / MCS 3 / GRUNTS 4 / MAGIC 10. Roster: Kira Mendez XP:1, Service
Record **2 missions**; Finn Adler XP:3, 1; Jules Liang XP:1, 1; "3 main characters".
**Sable Adler ABSENT** (the forced casualty) and **Jules Liang present** (the p.203
replacement) — a fourth independent surface for that chain, now surviving full process
death. Matches disk exactly.

### VERIFIED — W-N3: a forced Special Assignment delivers its effect

Queued through the new QA card: `Bug Hunt Special Assignment die 1 (D6) = 6` and
`die 2 (D6) = 6`. Turn 2, Kira Mendez assigned **Marksman Training (2D6 >= 9)**, the
other two left on None (Skip). Pressed Roll All Assignments, then Save.

Disk before -> after (`w88_save.json` -> `w89_save.json`, 13,457 -> 14,191 bytes,
`last_modified` 08:24:08 -> 08:44:00):

```
completed_assignments  {}  ->  {"bh_mc_4113491534": ["marksman_training"]}
current_turn_phase      0  ->  1              (SPECIAL_ASSIGNMENTS -> MISSION)
Kira Mendez    CS 1 -> CS 2    XP 1 -> XP 2
Finn Adler     CS 1 -> CS 1    XP 3 -> XP 3   (unchanged)
Jules Liang    CS 0 -> CS 0    XP 1 -> XP 1   (unchanged)
```

The forced 12 cleared the 9+ target, Marksman Training granted **+1 Combat Skill and
+1 XP**, the career-once register is written **keyed by character id**, and exactly one
character rolled. Both ends of the seam are proven: the queue was consumed by the roll it
named, and the roll's effect reached the campaign.

### VERIFIED — mid-turn phase persistence tracks the ACTUAL phase

`current_turn_phase` read **0** at the first mid-turn Save and **1** at the second, in the
same campaign. Stronger than the first reading alone: the field follows the live phase
rather than storing a constant. Confirms `BugHuntPhaseManager._persist_phase`'s docblock —
*"Called from EVERY transition, not only at turn end"* — on hardware.

### NOT a defect — a phase transition does not write to disk

Pulled the save immediately after Special Assignments completed and the screen moved to
MISSION: **byte-identical**, 13,457 bytes, `last_modified` unchanged, `current_turn_phase`
still 0. `_persist_phase()` writes the phase onto the **core**; reaching disk needs an
explicit Save. 5PFH's `CampaignPhaseManager` behaves the same way, and the plan's Phase 1
wording (*"phase -> persist -> save -> emit"*) treats save as its own step. Recorded so a
later reader does not file it as lost state.

### VERIFIED ON HARDWARE — T11-15 keyboard avoidance (obtained from a mis-tap)

`QAScenarioDialog` is one of the two dialogs T11-15 gave a ScrollContainer to. Measured
with the IME open:

| | keyboard closed (`w76`) | keyboard open (`w79`) |
|---|---|---|
| forced-roll controls | thumb y 693 | thumb y 339 |
| Close / Apply row | thumb y 743 | thumb y 390 |
| empty scenario panel | y 57-648 | y 57-295 |

Content moved up ~354 thumb px = **~708 device px**; the focused field sits at device
y 678, clear of the keyboard's top edge at device y 850. **The scenario panel itself
SHRANK**, which identifies the strategy as **headroom-and-scroll** operating inside the
ScrollContainer — the correct one for a dialog that has one, and the reason T11-15 added
it (the move-the-Window strategy has a hard ceiling, which was T11-15's original defect).

### POSITIVE — the QA dialog's owner-guard works and explains itself

Dialog body, verbatim:

> Applies a state DELTA to the loaded campaign through the normal owner setters, then
> hands back. It does not jump the phase — enter the turn normally.
>
> The QA fixtures are 5PFH-only. (orange)
>
> Every file in `res://data/qa_scenarios/` is a delta against a `crew_data` campaign, and
> applying one writes through GameStateManager to whichever campaign GameState currently
> holds — which in this mode is not the one on screen.
>
> Forcing a roll below is safe in every mode, and is what this dialog is for here.

**Apply Scenario is greyed; Queue Roll is live.** This is Phase 3 step 5's *"guard on the
owner, not a mode flag"* rule, and it NAMES the hazard rather than silently disabling.

### POSITIVE — `Priority: die 1` / `die 2` are two separate D6 rows

Visible in the dropdown itself. That is Phase 3 step 3's rule — *"Lower-of-2D6 Priority
(p.187) is two `roll_d6` calls plus `mini()`, never `roll_2d6`"* — made legible in the QA
seam.

### POSITIVE — every row carries a CITED DEFAULT, not just a floor

Two samples, so it is a table property rather than a one-off:

- `Bug Hunt Muster Out (2D6)` loads **12**, hint *"p.203 - 2D6 vs the row's target (9 at
  8-9 missions, 5 at 14); 12 musters on every row"*.
- `Bug Hunt Special Assignment die 1 (D6)` loads **6**, hint *"p.183 - 2D6 vs the
  assignment's own target (Marksman training 9+)"*.

Pre-loading the maximal useful value is a stronger mitigation than clamping, because the
tester never approaches the hazard the floor guards against.

### POSITIVE — the queue state is displayed, not just the last action

After queuing both dice the status line read, verbatim:

> Queued 6 for the next "Bug Hunt Special Assignment die 2" roll. p.183 - 12 clears every
> row, incl. Officer training course 11+  **[pending: bug hunt special assignment die
> 1=[6], bug hunt special assignment die 2=[6]]**

`DiceManager.queue_forced_result()` matches on a **case-insensitive substring** of the
roll's context, which is powerful and otherwise invisible. Printing the normalized keys
and their value **arrays** makes the matching contract legible before the tester leaves
the dialog, and shows the queue is a list per key (repeat queues stack, they do not
overwrite).

### FINDING W-N13 — the dashboard QA card's description is a drifted UI literal

**Severity: low-medium** (debug-only tooling). **Not fixed — read-only walk.**

The BugHuntDashboard QA card enumerates **8** names — *"Priority, Special Assignment,
Support, Enlistment, Commendation, Origin, Basic Training, Service History"* — and reads
as exhaustive. The control it describes carries **22+** Bug Hunt rows, including
**Casualty**, **Court Martial**, **Muster Out**, **Recovery Time**, **Reputation**,
**Operational Progress**, **Military Life**, **Objective: type**, **Signals: count**,
**Tactical Location: type**, **Brawl** and **Subject Pick**.

A tester reading the card concludes Casualty and Muster Out cannot be forced and never
opens the dialog. This is the project's own documented trap: *never put a mechanic's
contents in a UI literal; render it from the same data the mechanic reads.*

**Fix shape:** build the string from `QAScenarioDialog.FORCEABLE_ROLLS` filtered on the
`Bug Hunt ` prefix, so the card and the control cannot drift.

### FINDING W-N14 — the QA hint cites an assignment the panel does not offer

**Severity: low.** **Lead, not root-caused — one grep settles it.**

The `Special Assignment die 2` hint reads *"p.183 - 12 clears every row, incl. Officer
training course 11+"*. The turn-2 assignment dropdown offers nine assignments and **no
Officer Training Course**, with **no target above 10**:

| Assignment | Target | | Assignment | Target |
|---|---|---|---|---|
| Marksman Training | >= 9 | | Cross-training | >= 8 |
| Leadership Training | >= 9 | | Special Assault Course | >= 10 |
| Physical Training | >= 8 | | Survival Course | >= 8 |
| Commando Course | >= 10 | | Harsh Environment Course | >= 8 |
| Technical Training | >= 9 | | | |

Either the data holds an Officer Training Course the panel filters out, or the hint is a
drifted literal. Same family as W-N13. Check: grep `data/bug_hunt/` for `officer`, then
compare the offered list against Compendium p.183.

### FINDING W-N15 — a load/save round-trip converts character stats int -> float

**Severity: low today, latent.** **Observation, not fixed.**

Before this leg every stat on disk was an **int**. After a cold load and a save, every
stat is a **float** except the one the assignment code rewrote:

```
MC Kira Mendez  CS 2    R 3.0  S 5.0  T 3.0  Sv 0.0  XP 2.0
MC Finn Adler   CS 1.0  R 2.0  S 4.0  T 3.0  Sv 0.0  XP 3.0
```

Godot's JSON parser returns every number as a float, so **generate -> save writes ints**
while **load -> save writes floats**, and the same file now holds both shapes for one
concept. This is Phase 3 finding **J** surfacing in the save layer rather than at
generation.

Numerically correct, and rendering is already covered — the turn-2 screen printed
`R:3 S:5 CS:1 T:3` after a load, which is Phase 6's `test_bug_hunt_rendered_numbers.gd`
fix holding. The live hazard is any future `value is int` type test, which is **always
false** on loaded data (the documented trap that silently zeroed all seven Story Track
clocks).

### INCONCLUSIVE — the SpinBox `min_value` floor is NOT device-verified

Aiming for the spin-down chevron I hit the LineEdit, the IME opened, and eleven loop taps
typed `3x.` into the field. After clearing, it settled at **3** — **above both candidate
floors (1 and 2), so the measurement cannot discriminate between them.** Recorded as
inconclusive, not as a pass. The floor remains desk-pinned only (`roll_min(entry)` plus
the `_roll_value.min_value = roll_min(entry)` assignment, the T11-05 shape).

**Process lesson: a settled value above every candidate threshold cannot discriminate
between them — say inconclusive, do not claim a pass.**

### FINDING W-N16 — SpinBox spin arrows are ~10 device px wide

**Severity: low** (debug-only dialog). **Measured, not fixed.**

The forced-roll SpinBox's up/down chevrons occupy device x ~706-716, each ~14 px tall.
This project defines `TOUCH_TARGET_MIN = 48px` on `WorldPhaseComponent`; Godot's default
`SpinBox` chevrons are roughly **a fifth** of that. On this tablet the only reliable way
to change the value is to tap the field and type, which opens the IME — which is exactly
how `3x.` got typed into it.

Mitigated in practice by the cited defaults above (a tester who never touches the SpinBox
gets a valid maximal value), which is why this is filed low rather than medium.

### Two low-severity QA-dialog rows confirmed on device

- The empty scenario list reserves **~1,180 device px** of blank dialog.
- The forced-roll dropdown **defaults to "Rival Attack Type (D10)"** — a 5PFH row whose
  hint cites *"T9-48 - 1 = AMBUSH, the only battle that forbids Seize (p.91)"* — inside a
  Bug Hunt campaign where that roll can never fire. A tester pressing Queue Roll without
  touching the dropdown queues a value nothing will consume.

### OPEN — the Special Assignment result is displayed for an unknown duration

`Roll All Assignments` rolled and **advanced straight to MISSION**; three seconds later
the capture shows the Mission step with Special Assignments green. I cannot distinguish
*"no result was shown"* from *"a result was shown and auto-advanced"* with a 3 s sleep, so
this is **not filed as a defect**. The effect is confirmed on disk either way.

To settle it: re-run with a ~0.4 s sleep and look for an intermediate frame, or read
`SpecialAssignmentsPanel._on_roll_all` (:252) at desk. Worth settling because a 2D6 roll
against a target, with a once-per-career restriction, is a moment the player should see.

### Frame ledger (this leg)

`w74_menu.png` 2,200,787 (main menu, cold relaunch) | `w75_continue.png` 248,626
`c6e6a3b33f4aaa5bf3a8cfea3b0958f3` (BugHuntDashboard, TURN 2) | `w76_qa.png` 279,245
`e75e27441313602e698f18c3cd13f3c6` | `w77_dd.png` 525,202
`6f4152b3e9d3eb5ba31eb19929f708c4` | `w78_muster.png` 284,447 (Muster Out, default 12) |
`w79_floor.png` 1,408,084 (IME open, T11-15 evidence) | `w80_floor.png` 284,853 (settled
at 3) | `w81_dd.png` (full row list) | `w82_sa.png` (SA die 1, default 6) |
`w83_q1.png` | `w84_dd.png` (die 2 located by measurement) | `w85_q2.png` (pending list) |
`w86_t2.png` 173,090 (TURN 2 Special Assignments) | `w87_asn.png` (10 assignments) |
`w88_roll.png` (advanced to MISSION) | `w88_save.json` 13,457 (unchanged) |
`w89_save.json` 14,191 (post-Save).

---

## Window 17 — the ENLIST leg (device walk, 2026-09-22)

Device: Lenovo TB361FU `HNQ05SR3`, `ROTATION_90`, 2560x1600. App on `A1_BUILD`-flipped
Alpha-2 build. Bug Hunt campaign `bhwalk36_bh_1790034759.save`, turn 2.

---

### 🔴 W-N17 — CRITICAL: the enlistment roll is ALWAYS ZERO. Enlistment can never succeed.

**Rendered verbatim, twice, from two independent rolls:**

```
Dice: [0] + [0] + Combat Skill 0 = 0  (needed 7+)
```

Frames: `w96_rolled.png` (md5 `19cdaa6302fb489bf0b972a5f023ddd2`, 180,479 bytes) and
`w97_rolled2.png` (md5 `dad28f2560d37084fd899dda1ca0d755`, 180,190 bytes). Crops
`w96_c1.png` / `w97_c1.png` read byte-for-byte the same string. The two frames differ only
by the live background animation (see W-N18), not by a single digit of the roll.

**Three values are wrong, and each is independently impossible:**

| Value | Rendered | Possible range | Why it is impossible |
|---|---|---|---|
| die 1 | `0` | 1-6 | a D6 has no zero face |
| die 2 | `0` | 1-6 | a D6 has no zero face |
| Combat Skill | `0` | Bryn Ito's is **3** | the CONFIRM screen **one tap earlier** rendered `2D6 + 3 (Combat Skill) — need 7+` (`w95_thumb.png`), and the enlist list rendered `R:2 S:5 CS:3 T:4 Sv:2` (`w93_c2.png`) |

**Consequence.** The total can only ever be 0 against a target of 7+, so the roll is a
**guaranteed rejection on every attempt, for every character**. The header reads
`ENLISTMENT REJECTED` and the body reads *"Application denied. The military has standards,
apparently."*

**The UI promises the opposite, and its promise is arithmetically correct.** The confirm
screen states `Success chance: ~92% (need 4+ on 2D6)`. That derivation is sound —
P(2D6 >= 4) = 33/36 = 91.67%. So the *preview* reads Combat Skill correctly and computes
correctly; only the *roll* reads zero. **A preview and a resolver disagreeing about the same
character's stat, one screen apart, is the tell.**

**Neither save was written.** `bhwalk36_bh_1790034759.save` stayed at md5
`762967cce7eefd7ec4c47b86ca1432c7` and `tablet_qa_run_1786210201.save` stayed at
`6df0db4f05b1f6e0981e51612cc75ebc` across both attempts — correct behaviour for a failed
roll, and incidentally proof that nothing half-wrote.

⚠ **This blocks the measurement the Enlist leg existed to take.** Phase 2 step 4's transfer-hub
wiring — `add_main_character()` **and** `CharacterTransferService.remove_character_from_save()`
— is on the success branch only, so it is **UNREACHABLE ON DEVICE** until W-N17 is fixed. The
Enlist leg is therefore **BLOCKED**, not passed and not failed: the filter half is verified
(W-V4 below) and the transfer half was never reached.

⚠ **Likely in this sprint's own code, and recorded rather than quietly fixed.** Phase 3 step 1
routed *"the enlistment roll (CTS:98-99)"* through DiceManager. A routed roll returning 0 twice
running is the shape of a `roll_*` call whose result is read from the wrong key, or a character
dict handed to the resolver in a different shape from the one the preview reads. **Desk work,
not walk work** — the walk's job was to measure it, and it has.

⚠ **Desk instruction: fix the CS read and the dice read as two separate defects.** They are
adjacent but not the same bug — a Combat Skill of 0 would still leave `[3] + [5] = 8`, a pass;
and correct dice with CS 0 would still pass 42% of the time. Both are zero, so **either fix
alone leaves enlistment broken**, and either fix alone will look like it worked if the other is
tested with a forced roll. Prove them separately.

---

### 🟠 W-N18 — the Enlist panel has no opaque background; the dashboard behind is still LIVE

`w93_c1.png` (device y 590-700) shows the ghost text **"Enlist from 5PFH"** — the dashboard
card's own title — rendering *through* the gap between the Bryn Ito and Dex Kovac cards.
Further ghosts at thumb y ~313, ~593, ~686, matching the dashboard card pitch. Every
subsequent enlist frame repeats it: `w95_thumb.png` shows `Main Menu`, `QA - Force a Roll`,
`Enlist from 5PFH`, `Muster Out to 5PFH`, `SQUAD ROSTER`, all three marines, `GRUNT POOL` and
`MOVIE MAGIC` legible behind the confirm dialog.

**It is not merely visible — it is still animating.** `w93_enlist.png`
(`0542a20c8adf431be4536c2681734a3a`) and `w94_enlist2.png`
(`d37758df8b1e04610eebec4f86e7b7f7`) are not byte-identical despite looking identical:

- diff bbox `(0, 221, 2560, 680)`, 186,976 of 4,096,000 px = **4.5648%**
- rows differing above threshold 4: **zero**
- brightness delta by band: bullets `+0.00`, SELECT CHARACTER bar `+0.00`, Bryn card `+0.00`,
  ghost gap `-0.01`, Dex card `+0.00`
- **max per-channel luminance delta across the whole frame: 5**

So: many pixels differ, all by <= 5/255, with no geometric and no content change. That is a
live tween running behind a transparent panel, which means the dashboard was **added to, not
hidden or freed**.

Project context (no source opened this window): CLAUDE.md records *"Bug Hunt panels extend
Control (not BaseCampaignPanel)"*, and `BasePhasePanel` / `BaseCampaignPanel` are what inject
the `COLOR_BASE` ColorRect (`"__phase_bg"` / `"__panel_bg"`). `BugHuntScreenBase` was read in an
earlier window and is thin — `class_name`, `MAX_FORM_WIDTH := 800`, four helpers, **no
`_ready()` override** — so it would not inject one either. Phase 1 moved only the
**TurnController** onto the base, not the panels.

---

### 🟠 W-N19 — the Enlist list does not scroll, and `Cancel / Go Back` is clipped off-screen

`Cancel / Go Back` sits at thumb y ~798 -> device y ~1596 against a 1600-tall screen; only a
sliver of the buttons is on-screen. A swipe from (1280, 1250) to (1280, 550) over 400 ms
produced **zero geometric and zero content change** — the 4.56%/max-5 delta characterised in
W-N18 is the background tween, not a scroll.

Same family as **T11-01** (content overflow with scrolling disabled or absent) and the §2 touch
sweep, which Bug Hunt panels were never included in. With six characters rendered the footer is
already off; a seventh would push a character card off too.

⚠ **The finding survives because it was measured, not seen.** My reading of the two frames was
"identical"; their md5s disagreed. Rather than trust either, I profiled the delta — and the
profile both preserved the conclusion (no scroll) and produced the corroborating evidence for
W-N18 (a live background). **md5 before eyes; then characterise, do not choose.**

---

### 🟡 W-N20 — `missions_completed` is displayed but never incremented in 5PFH

Every character in the enlist list renders `Missions: 0` while carrying XP 7-12. Dumped from
`tablet_qa_run_1786210201.save`, Bryn Ito:

```
battles_participated = 2.0
battles_survived     = 2.0
combat               = 3.0
experience           = 12.0
lifetime_kills       = 0.0
missions_completed   = 0.0
xp_discount_stat     = ''
```

The panel faithfully renders `missions_completed`; the key itself never moves while
`battles_participated` does. Same family as Bug Hunt's own dead `total_objectives_completed`
(zero writers, zero readers).

⚠ **The ambiguity is part of the finding.** The panel's own bullet says *"Your Completed
Missions and Reputation start at 0 for the military"*, so a reader could take the 0 as a
forward-looking statement about the Bug Hunt career. But it is printed inside the character's
**current-stats** line, beside their real Combat Skill and real XP, which reads as their 5PFH
record. Desk: grep for writers of `missions_completed` — is the reader dead, or is the producer
missing?

---

### ✅ W-V4 — Phase 2 step 3 (the Enlist filter) VERIFIED ON HARDWARE, against a shape no fixture would have produced

| Save on device | `campaign_type` on disk | Offered in Enlist? |
|---|---|---|
| `22222222_1775243767.save` | **absent** (legacy) | yes |
| `asdasdasd_1778119724.save` | **absent** (legacy) | yes |
| `tablet_qa_run_1786210201.save` | **absent** (legacy) | yes |
| `zone_fixture_1786210201.save` | **absent** (legacy) | yes |
| `tacticsqa35_tac_1789071949.save` | `"tactics"` | no |
| `bhwalk36_bh_1790034759.save` | `"bug_hunt"` | no |

Identity confirmed by name: the panel lists Bryn Ito / Dex Kovac / Nyx Ward, present only in
`tablet_qa_run_*` and `zone_fixture_*`, both 5PFH.

⭐ **This is the branch a desk fixture cannot reach.** Phase 2 step 3 moved the filter off
`info.get("type")` (a key no producer writes) onto `campaign_type`. A naive version — requiring
`campaign_type == "five_parsecs"` to be **present in the file** — passes every test written
against freshly generated saves and then shows an **empty panel** on this tablet, because all
four 5PFH saves here predate the field. Six characters render, so the filter routes through
`GameState._detect_campaign_type()`'s absent-defaults-to-5PFH branch. **That legacy branch is
now verified on real saves.**

---

### ✅ W-V5 — Phase 6's float render VERIFIED ON HARDWARE, on two loaded-save surfaces

W-N15 established that a save/load round-trip converts every stat to float. Both surfaces below
are built from **loaded** data and both render integers:

- Dashboard (`w92_thumb.png`): Kira Mendez `XP: 2 | Service Record: 2 missions` /
  `R3 S5 CS2 T3 Sv0`
- Enlist panel (`w93_c2.png`, a *different* save): Bryn Ito
  `R:2 S:5 CS:3 T:4 Sv:2 | XP: 12 | Missions: 0`

⭐ A desk test can assert the render function; only a **loaded-save device frame** proves the
render is actually being fed the float. `test_bug_hunt_rendered_numbers.gd` holds on both.

Incidentally this is the sixth independent surface confirming the W-N3 Special Assignment
result (+1 Combat Skill, +1 XP) survived **save -> cold process death -> load -> render**.

---

### ✅ W-V6 — POSITIVE: the CONFIRM TRANSFER screen is a good disclosure surface

`w95_thumb.png`, verbatim:

```
CONFIRM TRANSFER: Bryn Ito
TRANSFER PREVIEW
Enlistment Roll:  2D6 + 3 (Combat Skill) - need 7+
Stats:            All carry over unchanged
Luck:             Set to 0 (not used in Bug Hunt)
Equipment:        Stashed safely - 1 Pistol retained
Missions/Rep:     Reset to 0 for military career
XP:               Reset to 0
Return Trip:      Muster out later to restore everything
Success chance: ~92% (need 4+ on 2D6)
```

Every irreversible consequence is stated before the commit, the return path is named, and the
92% is **derived, not hardcoded** (P(2D6 >= 4) = 33/36 = 91.67%). This is the standard the rest
of the mode's confirmations should meet.

⚠ It is also what makes W-N17 unambiguous: the preview reads Combat Skill **3** and the
resolver one tap later reads **0**.

---

### 🟡 W-N21 — the Story Point bypass is described to the player but no control is offered

Two surfaces mention it. The enlist header: *"If a Story Point is available, it can bypass a
failed roll"*. The rejection screen: *"You may try again after your next mission. (1 Story Point
can also bypass the roll.)"*

The rejection screen offers exactly one control: **`Back to Selection`**. No bypass button, no
disabled-with-reason affordance.

⚠ **Both readings are live and the walk cannot separate them.** Either the bypass is unbuilt, or
it is conditional on a story point the campaign does not have. Bug Hunt's meta-currency is
**Movie Magic** (the dashboard renders a `MOVIE MAGIC` section), and 5PFH story points are
campaign-level (`campaign.story_points`), not per character — so which pool is even being
checked is itself undetermined. Desk: identify the pool, then decide whether the correct
behaviour is a disabled button with a reason or no mention at all. **A rule described to the
player with no way to invoke it is worse than an unmentioned rule.**

---

### ⏳ W-N22 — cite to verify at desk: `Compendium p.212`

The enlist header renders, verbatim:

> **What happens when you enlist:**
> - Your character applies to join a Bug Hunt military squad
> - Roll 2D6 + Combat Skill - need 7 or higher to be accepted (**Compendium p.212**)
> - If a Story Point is available, it can bypass a failed roll
> - All equipment is stashed safely - you keep ONE Pistol
> - Your stats (Combat, Reactions, Speed, Toughness, Savvy) carry over exactly
> - Luck is NOT used in Bug Hunt - it will be restored when you return
> - Your Completed Missions and Reputation start at 0 for the military
> - You can return to Five Parsecs later via Mustering Out

The **threshold 7** matches Phase 0's housekeeping record (*"`SKILL.md` has enlistment at 7"*).
The **page cite is UNVERIFIED**. Compendium offset is index **-1**, so printed p.212 = PyPDF2
index 211. Extract and confirm; do not claim it wrong without the page.

Also unverified against the book: `XP: Reset to 0` and `Missions/Rep: Reset to 0`. These are
stated as consequences in the preview and are plausible for a fresh military career, but they
destroy player progress and therefore need a page behind them.

---

### Process notes from this window

- ⚠ **`run-as` executes directly with NO shell, so globs never expand.**
  `adb shell run-as <pkg> md5sum files/saves/*` returns
  `md5sum: files/saves/*: No such file or directory`. The working form is
  `adb shell "run-as <pkg> sh -c 'md5sum files/saves/*'"`.
  ⭐ **And the failure is silent from the host's side**: `adb`'s exit code is still 0, so a
  trailing `&& echo "backed up"` fires anyway. **A success echo from an unglobbed `run-as` is
  not evidence.** I re-verified the three backups with an explicit `sh -c 'ls -l'`.
- ⚠ **A `grep` pattern with a trailing space cannot match an `md5sum` line**, because `md5sum`
  prints the path at end-of-line. `grep -E "name.save "` silently dropped
  `tablet_qa_run_1786210201.save` from a measurement and made it look absent. Anchor on `$`.
- ⭐ **md5 before eyes**, and when they disagree, **characterise the delta rather than picking a
  side**. Here the profile (max 5/255, zero rows over threshold, zero brightness shift)
  simultaneously confirmed W-N19 and produced the evidence for W-N18.
- ⭐ **Reproduce an impossible value before filing it.** One roll of `[0] + [0]` could be argued
  as a render artifact; two identical rolls from two independent taps make it deterministic.

### Evidence protection state (to unwind before leaving the device)

Backups live in `files/` — deliberately **not** `files/saves/`, so they cannot be mistaken for
campaigns — and were verified present by explicit listing:

```
files/tablet_qa_run_1786210201.save.WALKORIG      82459
files/tablet_qa_run_1786210201.save.bak.WALKORIG  82459
files/zone_fixture_1786210201.save.WALKORIG       89966
```

Pre-enlist md5s of the two saves at risk, both **unchanged** after four enlist interactions:

```
6df0db4f05b1f6e0981e51612cc75ebc  files/saves/tablet_qa_run_1786210201.save
762967cce7eefd7ec4c47b86ca1432c7  files/saves/bhwalk36_bh_1790034759.save
```

Still owed: restore the three WALKORIG files, confirm the two md5s above, remove the WALKORIG
copies, restore `A1_BUILD`, run `svc power stayon false`, and confirm
`git diff project.godot export_presets.cfg` is empty.

---

## Windows A1-A6 — the MUSTER OUT leg (2026-09-22, deploy #36)

The last item in the plan's device scope: *"Walk creation -> assignments -> mission -> battle ->
debrief -> post-battle -> dashboard -> enlist -> **muster out**, with a forced roll through the new
QA card."*

**Verdict: the leg PASSES. The transfer hub fires, the removal is surgical, and the envelope
matches the documented contract on ten of eleven keys.** Six new findings and three verifications
below, one of them a timing defect that can lose a player's veteran entirely.

### ✅ W-V7 — the muster-out writes a transfer file AND removes the character. HEAD's defect is closed.

The audit's row on HEAD: *"a post-battle muster-out only calls `remove_main_character()`, so no
transfer file is written and the veteran is lost"* (`BugHuntPhaseManager.gd:192-195`).

Pre-state, pinned before the tap:

```
files/transfers/                             <- did not exist
bhwalk36_bh_1790034759.save   md5 762967cce7eefd7ec4c47b86ca1432c7   14191 bytes
```

Post-state:

```
drwx------  2 u0_a179 u0_a179  3452 2026-09-22 09:18 transfers
files/transfers/transfer_bh_mc_4113491534_1790093900.8274.json      1475 bytes
bhwalk36_bh_1790034759.save   md5 19b86b17342a2cfe11eae07cfc35fdab   13613 bytes
```

The directory **provably did not exist beforehand**, so the file's presence is unambiguous
evidence the hub ran. The save shrank by **578 bytes**, consistent with exactly one character.

Roster after, read off the save:

```
/squad/main_characters: list[2]
    [0] Finn Adler   id=bh_mc_1828224615
    [1] Jules Liang  id=bh_mc_4164131632
/squad/grunts: list[4]
    [0] Casey Frost  [1] Dex Ortiz  [2] Uri Kovac  [3] Pike Yang
/squad/combat_teams: list[0]
```

Only Kira Mendez was removed. All four grunts and both remaining marines are intact. The dashboard
agrees: the `MCS` pill moved **3 -> 2**, the SQUAD ROSTER lists two cards, and the footer reads
`2 main characters`.

Ordering is correct and it is the ordering that matters: **the transfer file exists AND the
character is gone**, so there is no window in which the veteran is deleted before being written out.

### ✅ THE FORCED-ROLL CHAIN CLOSES END TO END

The transfer filename carries the character id `bh_mc_4113491534`. That is **exactly** the id
W-N3 recorded when a QA-forced 2D6 = 12 passed Marksman Training's 9+ check:

```
completed_assignments = {"bh_mc_4113491534": ["marksman_training"]}
```

and the transfer payload carries her post-assignment stat:

```
combat = 2.0      <- base was 1; Marksman Training granted +1 CS
xp = 2            <- +1 XP from the same assignment
```

So a single unbroken chain is verified on hardware:

> **QA seam forces a roll -> the Special Assignment applies -> +1 CS / +1 XP -> persisted across a
> save/load -> carried out of the mode through the transfer hub.**

That satisfies the plan's *"with a forced roll through the new QA card"* requirement in the
strongest form available, because the forced roll's effect is observable in a different subsystem
two phases later.

### 🔴 W-N24 — THE MUTATION IS ON **DISMISS**, NOT ON **CONFIRM**. The app announces an irreversible transfer before committing it.

Measured twice, three seconds after each tap:

| After tap | `files/transfers/` | save md5 |
|---|---|---|
| `Confirm Muster Out` | `ls: files/transfers/: No such file or directory` | `762967cc...` (**unchanged**) |
| `Dismiss - Good Luck Out There` | directory created 09:18, file present | `19b86b17...` (**changed**) |

While **nothing was committed**, the screen read verbatim:

```
MUSTERED OUT!
Kira Mendez has completed their military service and returns to civilian life.

Rewards earned:
 +1 Credits (mustering out pay)
 +1 Story Point
 +1 Sector Government Patron added to contacts

This character can now be added to any Five Parsecs crew.
```

A player who backgrounds the app, force-quits, or loses the process at that screen **loses the
transfer entirely**: the save is untouched, no file is written, and the app has already told them
the marine is out and their rewards are earned. The result screen is a receipt for work that has
not happened.

⚠ **The lazy-flush explanation was considered and rejected on evidence.** `ls` run from the app's
own uid reported "No such file or directory" for the **directory**, not merely an empty listing —
directory creation is not subject to that kind of deferral — and the save file's md5 was
byte-identical across the Confirm tap.

⭐ **Process note worth keeping.** I declined to file *"the transfer hub did not fire"* at the
Confirm measurement, precisely because the write could plausibly be deferred to the Dismiss
handler. Checking before filing is what turned a false finding ("the feature is broken") into the
true one ("the feature commits one tap later than the UI claims"). **When a measurement says
nothing happened, check whether the write is deferred to the next control before filing "it did not
fire."**

**Desk remedy:** move the commit into the Confirm handler, or make the result screen non-final
until the write lands.

### ✅ W-V8 — the transfer envelope matches the documented contract, with ONE key absent

```
add_sector_government_patron = True     bonus_story_points          = 1
character: dict[23]                     direction    = 'bug_hunt_to_five_parsecs'
mustering_credits            = 1        schema_version              = 2
snapshot: dict[23]                      source_campaign_id = 'bhwalk36_bh_1790034759'
source_campaign_name = 'BHWalk36'       source_mode  = 'bug_hunt'
target_mode = 'five_parsecs'            transferred_at = '2026-09-22T09:18:20'
```

CLAUDE.md's contract names: `schema_version 2`, `direction`, `source_mode`, `target_mode`,
`character`, `snapshot`, `stashed_equipment`, `mustering_credits`, `bonus_story_points`,
`add_sector_government_patron`, `transferred_at`. **All present except `stashed_equipment`.**

`snapshot` is key-for-key identical to `character`, which is the only honest value for a native
(never-imported) Bug Hunt marine — there is no prior canonical form to restore.

### 🟡 W-N25 — the confirm preview renders `Stashed Equipment: Returned from enlistment` unconditionally

Kira was Bug-Hunt-generated and never enlisted. `character.equipment = []`, and the core's
`/stashed_equipment` and `/original_character_snapshots` are both `dict[0]`. There is nothing to
return, and the transfer envelope omits `stashed_equipment` entirely.

⭐ **The tell is the contrast with the line two rows above it.** `Service Pistol: Not retained
(2/10 missions)` is correctly conditional and names its own shortfall — so the screen demonstrably
*can* render a conditional line. The stash line simply is not one.

### 🟠 W-N26 — W-N15's int/float drift now CROSSES A MODE BOUNDARY, inside the transfer payload

```
combat   = 2.0   reaction = 3.0   reactions = 3.0   savvy = 0.0
speed    = 5.0   tech     = 0.0   toughness = 3.0
luck = 1   experience = 2   xp = 2   bug_hunt_missions_completed = 2
mustering_credits = 1   bonus_story_points = 1
```

Seven stats are floats; six other numbers are ints, in the same dictionary.

This envelope is consumed by `CampaignScreenBase._add_character_to_mode()` ->
`FiveParsecsCampaignCore.add_crew_member()`, so those floats land in **another campaign's crew
data**. That raises W-N15 above "cosmetic, the render handles it." CLAUDE.md's standing warning
applies directly:

> *"Godot's JSON parser returns every number as FLOAT — so `value is int` is ALWAYS false on loaded
> data."*

**Desk question:** where does the int coercion belong — the generator, the core's setters, or the
transfer boundary? The boundary is the narrowest place that fixes the cross-mode case.

### 🟡 W-N27 — two vocabulary observations in the payload

- **`reaction` AND `reactions`**, both `3.0`. That is a **third** dual-key pair beyond the two
  CLAUDE.md documents (`id`/`character_id`, `name`/`character_name`).
- **`game_mode = 'standard'`** inside the character dict — a **fourth** mode-key spelling alongside
  `campaign_type`, `"type"`, and `get_campaign_summary()`'s hardcoded `"type": "bug_hunt"`. The
  *value* is correct for a 5PFH-bound character; the spelling proliferation is the observation.
  Phase 2 unified the predicate to `campaign_type`; this is a survivor it did not reach.

### 🟡 W-N28 — `completed_assignments` retains an orphaned entry for a departed character

```
/completed_assignments/bh_mc_4113491534: list[1]
```

Kira is gone from `/squad/main_characters`, and her assignment record survives. `sick_bay` is
correctly `dict[0]`.

Low severity, but real: over a long campaign this dict accrues an entry per departed marine, and if
an id were ever reused the stale entry would suppress a legitimate assignment. It is exactly the
shape Phase 6's consumer census exists to surface.

**Desk remedy:** erase `completed_assignments[<id>]` when a character leaves, in the same mutator
that calls `remove_main_character()`.

### 🟠 W-N30 — the mustered marine's tally (2) exceeds both the campaign's mission count (1) and the retained marines' tally (1)

Three independent readings of the same campaign, one mission played:

| Source | Value |
|---|---|
| `state/total_missions_played` | **1** |
| Dashboard, Finn Adler | `Service Record: 1 mission` |
| Dashboard, Jules Liang | `Service Record: 1 mission` |
| Muster panel, Kira Mendez | `Missions: 2` |
| Transfer payload | `bug_hunt_missions_completed = 2` |
| Muster preview arithmetic | `Credits Earned: +1 (1 per 2 missions from 2 served)` |

The tally is not merely displayed as 2 — it is **persisted as 2 and paid out on 2**, producing a
credit that a 1-mission career should not earn.

This is the p.203 tally rule, which Phase 5 rewrote so it *"rises once for a character who took the
field"*, deleting `BugHuntPhaseManager:179`'s second `+1`. Two marines show 1, so the general rule
is working; Kira alone is doubled.

⚠ **NOT diagnosed — no source was opened during the walk.** Candidate explanations, none
eliminated: she was the only character to satisfy some second increment path; the muster lookup
adds its own `+1` before reading (the audit records exactly that shape at `PBP:459`/`:307`/`:462`);
or the preview reads a different key from the dashboard. **The discriminator is cheap at the desk:**
grep every writer of the tally key and count them.

⭐ **This finding exists only because two marines stayed behind.** A single-marine squad would have
shown "2" with nothing to compare it against, and it would have read as correct. **Keep a control
subject in the campaign when walking a mutation.**

### ✅ W-V9 — the voluntary muster-out is DETERMINISTIC, which resolves an open blocker question

The confirm screen offers no dice. That means the plan's Phase 5 step 3 *"Muster out"* 2D6 check is
the **involuntary** post-battle check at the p.203 tally rows — and the QA dialog's omission of a
"Muster Out" forceable row (W-N13) does **not** block this path.

The preview verbatim:

```
CONFIRM TRANSFER: Kira Mendez
TRANSFER PREVIEW
Stats:              All carry over unchanged
Luck:               Restored to 1 (base)
XP:                 2 unused XP carries over
Credits Earned:     +1 (1 per 2 missions from 2 served)
Story Points:       +1
Patron:             +1 Sector Government Patron
Service Pistol:     Not retained (2/10 missions)
Stashed Equipment:  Returned from enlistment
```

Every number is **derived and shows its own arithmetic** — `1 per 2 missions from 2 served`,
`2/10 missions`. `Luck: Restored to 1 (base)` mirrors the enlist side's `Luck: Set to 0 (not used
in Bug Hunt)`, so the round trip is symmetric by construction. The screen states every irreversible
consequence before the commit.

### ⭐ W-N17 NARROWED — the preview layer reads the character correctly on BOTH legs

The muster preview reads `2 unused XP` (matches the payload's `xp = 2`) and `2 served` (matches
`bug_hunt_missions_completed = 2`); the enlist preview read `2D6 + 3 (Combat Skill)` and a
correctly-derived `~92%`.

So the character dict is **fetched correctly in both directions**. W-N17's
`Dice: [0] + [0] + Combat Skill 0 = 0` is therefore **isolated to the enlistment resolver**, not to
the fetch. That sharpens the desk instruction: fix the dice read and the CS read inside the
resolver, and do not go looking for a broken fetch.

### ⏳ W-N29 (UNVERIFIED — desk) — possible double-pay across a re-enlist round trip

The `snapshot` bakes in `mustering_credits = 1`, `bonus_story_points = 1`,
`add_sector_government_patron = True` and `transferred_from_bug_hunt = True`.

CLAUDE.md states *"`export_to_canonical()` short-circuits on the snapshot."* If this veteran later
re-enlists and musters out again, the short-circuit may re-emit the **first** service's rewards.

Filed as a question, not a finding. No source was opened. **Desk:** read
`CharacterTransferService.export_to_canonical()` and determine whether the reward keys are re-read
off the snapshot.

### Save-layer state on the post-muster dump

```
/state: campaign_turn = 2 · current_turn_phase = 1 · reputation = 1
        total_missions_played = 1 · total_objectives_completed = 0
        operational_progress_modifier = 5 · missions_in_current_operation = 1
        extra_contact_markers = 0 · extra_support_rolls = 1
/meta:  schema_version = 1 · last_modified = '2026-09-22T09:18:20' · game_phase = 'active'
/sick_bay: dict[0]   /military_life_modifiers: dict[0]   /support_teams_available: list[0]
/stashed_equipment: dict[0]   /original_character_snapshots: dict[0]
/journal/entries: list[7]
```

**Phase 4's normalizer markers survive save/load intact:** `bug_hunt_normalized = True`,
`casualty_ids: list[1]`, `court_martial_required = False`, `debrief_recorded = True`,
`objectives_completed = 1.0`, `objectives_completed_count = 1.0`,
`mvp_id = 'bh_mc_1535904973'`, `rounds_fought = 1.0`, `mission_source = 'opportunity'`.

**Phase 4's cited scoring block persists with its provenance:**

```
/current_mission/scoring/_source = 'Five Parsecs From Home: Compendium, printed pp.185, 201'
/current_mission/scoring/success_threshold = 2.0
/current_mission/scoring/success_note = "p.201: 'Two or more is considered a success for the
   purposes of awarding Experience Points after the battle.'"
/current_mission/scoring/weights: dict[3]
/current_mission/scoring/signals_requirement: dict[5]
```

### ⭐ CORRECTION — the `mission_success` "contradiction" is NOT a contradiction. Downgraded.

Earlier windows filed `mission_success = False` and `objective_met = False` sitting beside
`success / victory / won / held_field = True` as a contradiction. **The scoring block resolves it
in the app's favour:**

```
objectives_completed = 1.0      success_threshold = 2.0
```

The two families answer **two different questions**:

- `success / victory / won / held_field` describe the **battle** — the squad held the field.
- `mission_success / objective_met` describe the **p.201 objective bar** — 1 is below "two or more
  is considered a success for the purposes of awarding Experience Points."

Both answers are correct simultaneously. `court_martial_required = False` is coherent with them:
Court Martial fires only on **0** weighted objectives, and 1 is below the XP bar but above the
Court Martial bar.

**Downgraded from "contradiction" to a naming observation:** the hazard is that four keys spelled
like synonyms carry two different meanings, with nothing at the site saying so. A one-line docblock
on the normalizer would close it.

### ⭐ CORRECTION — `participant_ids` (3) vs `crew_participants` (7) is likely two SCOPES, not a discrepancy. Downgraded.

With the roster now legible: the campaign had 4 main characters (Sable Adler died in the battle)
and 4 grunts. `participant_ids: list[3]` is main characters who took the field;
`crew_participants: list[7]` is main characters plus grunts.

Phase 5 step 2's rule is *"+1 once, only for a character who took the field"* — and grunts do not
carry tallies — so an MC-only participant list is probably intentional.

**Downgraded from "discrepancy" to "two scopes, likely intentional; needs a one-line docblock."**
Not eliminated: the scopes have never been stated anywhere, so the next consumer is one `.get()`
away from using the wrong one.

### Consistent with previously-closed leads (no action)

- `mvp_id = 'bh_mc_1535904973'` is Sable Adler, who is also the sole entry in `casualty_ids` — **the
  MVP is the dead marine.** This is the live instance of the dead-MVP fallback that was examined and
  **closed as NOT-a-defect** in an earlier window. Recorded so the next reader recognises it rather
  than re-filing it.
- `spawn_rating = 0.0` with no phantom base — Phase 7's Row A fix, visible in persisted state.
- `enemies_remaining = 8.0` with `enemies_defeated_count = 0.0` — W-26, already filed.
- `squad/combat_teams: list[0]` — W-20, already filed (third disk measurement).
- `total_objectives_completed = 0` — the dead counter, already filed (third disk measurement).

### Panel-level observations on the muster screens

- **W-N18 repeats here.** The muster-out panel has no opaque background; the dashboard behind is
  still animating through it. The finding is **not enlist-specific** — it is a Bug Hunt panel-wide
  omission of the `__panel_bg` pattern that `BasePhasePanel` / `BaseCampaignPanel` inject
  automatically.
- **W-N19 is narrowed by contrast.** The muster-out panel's footer is **NOT** clipped, while the
  enlist panel's is. The muster list holds 3 characters; the enlist list held 6. So the clipping is
  a function of **list length against a non-scrolling container**, not a fixed offset. Established
  without opening a file.

### Process rules earned this window

1. ⭐ **A byte-size delta that contradicts your extractor's count means the extractor is wrong, not
   the app.** My first save extractor reported `main_characters = 0` and `grunts = 0` — an apparent
   total roster wipe. The byte delta refused it: 14,191 -> 13,613 is **-578 bytes**, about one
   character, not seven. Re-dumping the whole structure showed the roster lives under `/squad/`, not
   at top level. This is the fifteenth appearance of *print the universe next to the lookup*, and it
   kept a catastrophic false finding ("muster-out wipes the entire squad") out of this ledger.
2. ⭐ **When a measurement says nothing happened, check whether the write is deferred to the next
   control before filing "it did not fire."** See W-N24.
3. ⭐ **Keep a control subject in the campaign when walking a mutation.** W-N30 is visible only
   because two marines stayed behind to disagree with the third.

---

## TEARDOWN — the device walk is COMPLETE (2026-09-22)

| Condition | Result |
|---|---|
| At-risk save `tablet_qa_run_1786210201.save` | `6df0db4f05b1f6e0981e51612cc75ebc` — **unchanged across the entire walk** |
| At-risk save `zone_fixture_1786210201.save` | `f54baedfdb4f5600483333a3915c5ddc` — **unchanged across the entire walk** |
| Proof | The three `.WALKORIG` backups taken before the walk were byte-identical to the live files at the end of it |
| WALKORIG backups | removed (named explicitly, no globs) |
| `files/transfers/` | file pulled to host as evidence, then **removed with the directory** |
| `bhwalk36_bh_1790034759.save{,.bak}` | removed (my probe campaign; fully dumped to `wa5_save.json`) |
| `settings.cfg` | one line changed, verified by diff: `last_campaign="bhwalk36_bh_1790034759"` -> `last_campaign=""` |
| `svc power stayon` | false |
| `A1_BUILD` | `true` (restored) |
| `git diff project.godot export_presets.cfg` | **empty** |

The user's other saves are all present and untouched: `22222222_*`, `asdasdasd_*`,
`tablet_qa_run_1786210201.{save,save.bak,backup,save.cleanbak,save.walkbak}`, `tacticsqa35_*`,
`zone_fixture_1786210201.save`.

### Why the transfer file had to be removed rather than left as evidence

`CampaignScreenBase._check_pending_transfers()` is called `call_deferred` from every dashboard's
`_setup_screen()`, and `apply_transfer_rewards()` **deletes the file after applying it**. Left in
place, the next time the user opened any 5PFH campaign on this tablet, Kira Mendez would have been
silently added to their crew along with +1 Credit, +1 Story Point and a Sector Government Patron.
The evidence is preserved off-device in `wa5_transfer.json`.

### Why `last_campaign` had to be cleared

`GameState._try_auto_load_last_campaign()` (`GameState.gd:150`) runs on **every** launch and gates
only on `last_campaign` being non-empty — it is in the autoload, so the MainMenu's `A1_BUILD` gate
does not reach it. With `A1_BUILD` restored, the next boot would have loaded a
`BugHuntCampaignCore` into `GameState.current_campaign` while every Bug Hunt screen was hidden,
leaving a 5PFH screen to call `get_crew_members()` on it — the documented class-(b) abort, and the
same cross-mode bleed shape CLAUDE.md records for the Tactics suites. The walk created that
pointer, so clearing it is teardown of my own side effect, not a product change.

---

## DESK FIXES

### ✅ W-N24 — FIXED at the desk, 2026-09-24 (not yet re-walked on hardware)

**Root cause.** One signal, `CharacterTransferPanel.character_transferred`, meant both "persist
this" and "the player is done", so it was emitted from the result screen's dismiss button. For
muster-out that made the result screen a receipt for work not yet done (the row above). For
enlistment it was worse than the row measured: backing out of "ENLISTMENT ACCEPTED!" discarded an
accepted roll, and p.212 gates a retry on the next mission.

**Fix.**
- `CharacterTransferPanel._execute_transfer()` now commits BEFORE building the result screen:
  `_commit_enlistment()` / `_commit_muster_out()` → `_emit_and_confirm()`. Signals are synchronous,
  so the dashboard listener runs inside the emit and reports a failure back through
  `report_commit_error()`; the panel then shows "TRANSFER FAILED" / "NOT SAVED" instead of success.
- The dismiss buttons now emit a new `transfer_closed` signal and nothing else;
  `BugHuntDashboard` rebuilds on it (`_rebuild_after_transfer()`).
- `BugHuntDashboard._apply_enlistment()` / `_apply_muster_out()` return an error `String`
  (empty = committed).
- ⚠ A commit failure on ENLIST carries `commit_failed: true`. Without it the enlist screen reads the
  failure dict's missing `dice` as "never rolled" and announced an accepted roll whose SAVE failed as
  "CANNOT ENLIST / not eligible". It now reads "NOT SAVED".

**Pinned by** `tests/unit/test_bug_hunt_enlistment_transfer.gd`, three new cases, each proven alone
(other cases renamed `off_*`) with a passing control, then only its own fix reverted, files
md5-restored:

| Case | Revert | Control | Reverted |
|---|---|---|---|
| `test_the_result_screens_dismiss_control_commits_nothing` | re-emit `character_transferred` from Welcome Aboard | 1/0/0 | 1/0/**1** |
| `test_a_failed_enlist_commit_is_not_announced_as_an_ineligibility` | drop `commit_failed` | 1/0/0 | 1/0/**2** |
| `test_the_muster_screen_never_claims_success_before_the_commit` | ignore `_commit_error` | 1/0/0 | 1/0/**2** |

Gate: `test_bug_hunt_enlistment_transfer` 9 · `test_bug_hunt_enlist_result_render` 2 ·
`test_character_transfer_hub` 20 · `test_every_script_compiles` 1 — **32 cases, 0 errors, 0 failures.**

**Still owed:** a hardware re-walk of the muster leg, re-measuring the row's own table:
`files/transfers/` and the save md5 must change on **Confirm**, not on Dismiss.
