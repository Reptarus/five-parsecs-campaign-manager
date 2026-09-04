# Tablet QA Sprint — Aug 8 2026

First full-app test on real hardware. Every prior QA pass on this branch was a
desktop window standing in for a tablet; this is the device itself.

**Device**: Lenovo TB361FU, Android 16 (SDK 36), arm64-v8a. **1600×2560
physical, density 320 (2.0×) → 800×1280 dp.** USB `HNQ05SR3`. No prior install,
so this is a genuine first-run.

> Measured, not assumed — an earlier note in this session had it as 1200×1920 @
> 1.5×. The dp figure was right by luck; the pixel figure was not. It matters
> because `adb shell input tap` takes **physical** pixels, so taps read straight
> off a screencap 1:1, and every dp number in the layout work is half the
> screencap coordinate.
**Build**: debug APK via Godot editor one-click Remote Deploy.
**Branch**: `campaign-editor-and-fixits`.
**Driving**: adb (screencap / input / logcat / run-as). Godot editor Remote
Deploy for install.

## Why a debug deploy and not the release APK

CLI `--export-release` is blocked by a Godot engine bug — autoload identifiers
are not registered as global constants when scripts compile during a headless
export, producing 336 `Identifier "Talo" not declared` parse errors. Four
attempts, deterministic, and independent of the UID-vs-path autoload form
(both tested). Editor-context export does not hit it because the editor
registers autoloads first.

That makes the debug build the *better* test vehicle anyway: `adb run-as` works
on debug packages, so save files and `godot.log` can be pulled off the device
for forensics — the only way to catch Godot's class-(b) silent aborts, which
kill a feature without crashing the app.

## Severity scale

Carried over from the rules-wiring audit so findings are directly comparable:

| Severity | Meaning |
|---|---|
| demo-breaking | A tester cannot proceed or cannot reach a whole feature |
| wrong-play | The app leads the player to play the game incorrectly |
| silent-loss | A rule/reward/state is lost with no error shown |
| freedom | The player cannot choose a method the book or app implies |
| cosmetic | Visual or wording only |

## Fix-next triage

Ordered by what unblocks the most. The top three are the tablet-only class —
none of them can be reproduced on desktop, which is why a device pass was worth
running at all.

| # | Finding | Why first |
|---|---|---|
| ~~1~~ | ~~**T4-03** crew list empty → World Phase Step 2 soft-lock~~ | **FIXED + device-verified Aug 8.** Was a layout collapse, not a data bug |
| ~~2~~ | ~~**T4-01** touch-drag does not scroll~~ | **FIXED + device-verified Aug 8.** Decorative chrome was swallowing the gesture |
| ~~1~~ | ~~**T3-01** nothing yields to the soft keyboard~~ | **FIXED Aug 8 (fix pass 2), NEEDS DEVICE VERIFY.** New `KeyboardAvoidance` autoload; no keyboard signal exists in 4.6, so it arms on focus and polls |
| ~~2~~ | ~~**T8-01** Android BACK quits the app with no prompt~~ | **FIXED + device-verified Aug 8.** `quit_on_go_back` was defaulting to true |
| 1 | **T3-01** soft keyboard — headroom fix written, NOT yet device-confirmed | Device pass #2 FAILED it: the page had zero scroll range, so scrolling alone was a no-op. Needs one more deploy |
| 2 | **T4-02** world event re-rolls on every render (4 values in one turn) | It is a live rules modifier (crew tasks, recruitment, prices), not decoration |
| 5 | **T2-01** Genetic Uplift credit chip / **T3-02** editor turn off-by-one / **T3-03** stale ship debt | Each misinforms the player about a rule or a value they are about to edit |
| 6 | **T7-01** equipment blank after load | Data is safe, but it reads as catastrophic loss to a tester |
| 7 | **T2-02** disconnected validator layer (5 false warnings per campaign) | Cheap to delete/re-key, and it is currently camouflage for any real failure |
| 8 | T1-01/02/03, T2-03/04/05/06 | Cosmetic; batch them |

## What this pass established that desktop QA could not

- The soft keyboard exists (T3-01) — desktop has no IME.
- Touch-drag scrolling is a distinct input path from the scrollbar (T4-01).
- Real ARM/Vulkan rendering: **Forward Mobile on Mali-G57**, not the Forward+
  configured in `project.godot`. The battlefield map, terrain shapes, badges and
  deployment zones all render correctly on it.
- Exported-build resource loading is fine — no missing-asset fallbacks appeared.
- `run-as` save inspection, which is how every "did it really persist?" claim in
  this document was settled against the file rather than the screen.

## Findings

| ID | Test | Screen | Expected | Observed | Severity | Evidence | Verdict |
|---|---|---|---|---|---|---|---|
| T1-01 | 1 | Main menu | Mode showcase cover reads as art on the dark theme | **Large opaque WHITE rectangle** behind the "Five Parsecs From Home" wordmark, top-left of the main menu | cosmetic (high visibility) | `05_menu_clean.png` | FAIL |
| T1-02 | 1 | Main menu coach marks | The bubble points at the highlighted button | Step 2/4's bubble is drawn **on top of** the "New Campaign" button it highlights, hiding the label, and overlaps "Onboard Existing Game" below. ~1000px of empty canvas to the left goes unused | cosmetic | `04_tutorial_4.png` | FAIL |
| T1-03 | 1 | EULA / consent | Legal text comfortably readable | Scroll region is ~148 dp tall on an 800 dp screen — about 5 lines, clipped mid-sentence. Dialog uses ~464×386 dp of a 1280×800 dp screen | cosmetic | `01_first_boot.png` | FAIL |

| T2-01 | 2 | Captain Creation card | A Genetic Uplift captain shows no background-credit bonus (Core Rules p.21 ignores it) | Card displays a **"+1d6 credits — Peaceful High-Tech Colony"** chip for a bonus the character provably does not receive | **wrong-play** | `10_captain_random.png` | FAIL |
| T2-02 | 2 | Creation state validator | Crew-size validation runs on the value the player picked | Validator keys on `crew_size`, a key **nothing in the creation flow ever writes** (the SSOT is `campaign_crew_size`). Fires a false warning on every campaign, claims "will use default of 4" when the real default is 6, and its range check never executes | silent-loss (validation gap) | logcat 10:21:07 | FAIL |
| T2-03 | 2 | Captain Creation empty state | Call-to-action near its explanation | "No captain created yet" sits at the top, its Create/Random buttons ~1000 px away at the bottom, with dead canvas between | cosmetic | `09_wizard_step2.png` | FAIL |
| T2-04 | 2 | World Generation (step 6) | Market card shows its own empty state | **"Market Prices:"** renders with nothing after the colon, and its empty-state line ("No market data available for this world") is drawn inside the **adjacent Opportunities card** instead | cosmetic | `15_wizard_step6.png` | FAIL |
| T2-05 | 2 | Turn rollover → journal | Ship-debt entry carries a canonical tag | `CampaignPhaseManager._process_ship_debt():895` writes tag `'debt'`, which is not in `JournalEntryTypes.TAGS`; warns on every debt turn | cosmetic | logcat 10:30:07 | FAIL |
| T2-06 | 2 | World Phase step strip | Steps read 1-6 | Strip renders `1 2 3 4 ✓ 6` — position **5 shows a completion check on Turn 1 Step 1**, before anything has been done | cosmetic (needs triage) | `17_dashboard.png` | FAIL |

`T2-05` severity note: `CampaignJournal.create_entry()` **discards**
`validate_entry()`'s return, so the entry is still written — the tag just falls
back to a default colour and an auto-capitalised label. Nothing is lost; it is
log noise plus a tag the canonical-tag filter cannot match.

| T3-01 | 3 | **Every screen with a text input** | Focused field scrolls above the Android soft keyboard | Nothing adjusts for the IME. In landscape the keyboard covers the bottom **52%**; the whole Compendium Progress group (licence, RZ turns, salvage, hint) disappears behind it and **the focused field is one of the hidden ones — you type blind**. A second tap aimed at a lower field hits the keyboard instead | **demo-breaking (landscape data entry)** | `21_editor_keyboard_landscape.png` | FAIL |
| T3-02 | 3 | Campaign Editor | "Turn #" agrees with the turn shown everywhere else | Editor shows **Turn # 0** while the dashboard and World Phase show **Turn 1**. The editor exposes the raw `progress.turns_played`; every other surface displays it +1 | wrong-play (edit sets a different turn than intended) | `19_campaign_editor.png` | FAIL |
| T3-03 | 3 | Campaign Editor | Ship Debt matches campaign state | Editor shows **25**; World Phase shows **26** and the saved file holds **`ship_debt: 26`**. The editor's value is stale. No corruption resulted this run (the save kept 26), but the field is editable, so a user "confirming" the displayed 25 could silently revert a turn of debt | silent-loss (potential) | `19_campaign_editor.png` + pulled save | FAIL |

| T4-01 | 4 | World Phase (Travel & Upkeep) | Swiping the content scrolls it | **Touch-drag does not scroll.** The "Calculate Costs" / "Pay Upkeep" buttons the on-screen hint tells you to tap sit below the fold, and four swipes (both directions, both `input swipe` and `input touchscreen swipe`) moved nothing. Dragging the **scrollbar** scrolls normally | **demo-breaking (touch)** | `26`-`30`, `34` | FAIL |
| T4-02 | 4 | Dashboard → Current World | The world's Current Event is stable | Event read **"Worker shortages make recruitment easier (+1)"** on the first dashboard visit and **"A supply glut drops market prices by 20%"** on a later visit in the same turn, with no turn advance between them | wrong-play (needs triage) | `18` vs `32` | FAIL |

### T4-01 detail — the control test that makes this conclusive

The obvious worry with any adb-driven scroll finding is that the harness, not the
app, is at fault. That is ruled out **within the same screen and session**:

| Gesture | Start point | Result |
|---|---|---|
| `input swipe 2519 800 → 2519 1400` | on the **scrollbar** | **scrolled** — revealed Calculate Costs, Pay Upkeep, and the whole World Briefing |
| `input swipe 1280 1150 → 1280 700` | on the content | no movement |
| `input swipe 1280 1100 → 1280 500` (fast flick) | on the content | no movement |
| `input swipe 1280 500 → 1280 1200` (opposite direction, from a known bottom position) | on the content | no movement |
| `input touchscreen swipe 2100 1250 → 2100 550` | on the content | no movement |

Same tool, same device, same screen, one minute apart. The app receives and acts
on synthetic drags; it just ignores them everywhere except the scrollbar.

This is very likely the `mouse_filter` class already in this project's memory
(`reference_job_offers_soft_lock_mouse_filter`,
`reference_drawer_downed_card_collapse_touch_scroll`): child Controls with
`MOUSE_FILTER_STOP` swallow the drag before the `ScrollContainer` sees it.

**Why it is demo-breaking rather than annoying:** the screen prints
`⚠ Tap "Calculate Costs", then "Pay Upkeep" to continue`, both buttons are below
the fold, and the natural gesture to reach them does nothing. A tester who does
not think to drag a 6-px scrollbar concludes the turn cannot be advanced.

### T4-01 — FIXED Aug 8 2026: right about the class, wrong about every node

Verified on device, clean build `12:49:31`: a swipe over the world briefing scrolls the
screen (diff bbox `(37,230)-(2522,1591)`), as does one over the card header. A swipe over
the task **list** moves only a 32px band — the ItemList's own selection, which is correct
and deliberate. Assigning a task still works end to end (`Resolve All Tasks (0) → (1)`).

**Three wrong fixes shipped to the tablet before the right one, and each was disproved by
one measurement.** Worth recording because the reasoning was plausible every time:

| # | Hypothesis | Why it was wrong |
|---|---|---|
| 1 | `PhaseScroll` (ScrollContainer) is STOP and blocks it | A live probe printed it as **PASS** — `Container` defaults to PASS in Godot 4.6. "Fixing" it would have been a no-op with a confident comment on it |
| 2 | `PhaseContainer` (PanelContainer, genuinely STOP) blocks it | It is STOP, and clearing it changed **nothing**: the finger never lands on it |
| 3 | Both of the above, cleared together | Still nothing. Both were verifiably applied on device (`ps_filter=2 pc_filter=1`) and the drag still died |

**What actually finds it:** dump the chain from the deepest control *under the finger*
upward, on the device, at the moment of the touch. That printed:

```text
@HSeparator@1533   HSeparator      STOP   <- finger here
WorldBriefingCard  PanelContainer  STOP
PhaseContentVBox   VBoxContainer   PASS
PhaseScroll        ScrollContainer IGNORE  <- fix #1/#3, never reached
PhaseContainer     PanelContainer  PASS    <- fix #2/#3, never reached
ContentScroll      ScrollContainer PASS    <- the one that needed the drag
```

The blockers are **decorative chrome** — a separator and a card — and there are **37** of
them across the step area (the regression test enumerates them all when it fails). The
briefing rebuilds a fresh crop on every refresh, so no per-node fix at a creation site
holds. The fix is a sweep over the scroll's subtree that converts **non-focusable**
Controls from STOP to PASS while the outer scroll owns the gesture; focusable ones are
left alone on purpose, so dragging over a list still scrolls that list.

**The trap that cost the most, and it is the sprint's recurring one.** The first sweep
worked and then undid itself: it ran from the content-rebuild hooks and re-derived
"am I tight?" at that moment — but the briefing has just `queue_free()`d its children
there, so the minimums are momentarily tiny, the budget reads huge, and the answer comes
back "not tight". Device log, in order:

```text
[T4-01] sweep tight=true  opened=33
[T4-01] sweep tight=false opened=0     <- closed all 33 again
```

This is the **same hysteresis** as the T4-03 budget fix (never measure in units the
decision itself changes), one level up. Cure is the same: decide once in
`_apply_vertical_compaction()`, cache it in `_is_tight_layout`, and have every later
consumer read the cache instead of re-asking.

Pinned by `tests/unit/test_world_phase_step_viewport.gd` (10 cases). Two are new and both
are detection-proven by isolated revert:
`test_decorative_chrome_does_not_swallow_the_drag` (live: names every non-focusable STOP
control left inside the owning scroll) and the source guard that the sweep reads
`_is_tight_layout`, not `_is_tight()`.

### T3-01 detail — the systemic one, and it can only be found on a device

`DisplayServer.virtual_keyboard_get_height()` appears **nowhere in `src/`**, and
no screen calls `ensure_control_visible()` in response to focus (the only two
`ensure_control_visible` hits are the tutorial overlay and an unrelated comment).
So no screen in the app makes room for the soft keyboard.

It is invisible on inputs that happen to sit in the upper half — the campaign
name field in the creation wizard worked fine — and breaks on every input below
the midline. Desktop QA can never see it, because desktop has no IME.

Workaround that let the test finish, and which also demonstrates the shape of
the bug: drive the **lowest** field first while the keyboard is closed, then work
upward. Each field is reachable exactly once, on the tap that opens the keyboard.

### Test 3 result — the seed fields WORK, verified in the save file

The feature under test passed. Set on device → Apply & Save → pulled
`files/saves/tablet_qa_run_1786210201.save` via `run-as` and asserted the
persisted state rather than the screen:

| Key | Value | Meaning |
|---|---|---|
| `red_zone_licensed` | `true` | checkbox → core field ✓ |
| `red_zone_turns_completed` | `10` | spinbox → core field ✓ |
| `progress.salvage_units` | `23` | routed through `SalvageLedger.add_units()` delta API ✓ |
| `campaign_crew_size` | `6` | **T2-02's "default of 4" disproven at the persistence layer** |
| `crew.members` | 6, `[0].is_captain = true` | data-ownership invariant holds |
| `crew.members[0]` | `ENFORCER` / `genetic_uplift` / `PEACEFUL_HIGH_TECH_COLONY` / `GLORY` | no enum defaulting |
| `crew.members[1]` | `GANGER` / `traveler` / `MILITARY_OUTPOST` / `TRUTH` | confirms Dex's Reactions 5 = 3+1+1 |

Save rotation also works: `.save`, `.save.bak` and an earlier `.backup` all
present with sane timestamps.

**This is also the deploy-freshness proof.** The "Compendium Progress" group
exists only in this week's uncommitted code, and it is on the device — so the
build under test is current, no APK unzip required.

### T2-01 detail — the mechanic is RIGHT and the display is WRONG

This is the inverse of the usual audit finding, and it is worth stating carefully
because three of the four links in the chain are correct.

| Link | State |
|---|---|
| Book, Core Rules p.21 (extracted, verbatim) | *"All Background rolls that would result in additional credits are ignored. The crew receives 1 additional Rival."* |
| `data/character_species.json` `genetic_uplift` | base_stats **byte-exact** to the book (Reactions 2, Speed 5, Combat +1, Toughness 4, Savvy +1); rule recorded in `special_rules` ✓ |
| `CharacterCreator.gd:903-920` | **Correct.** Subtracts only `source == "background"` entries from `bonus_credits`, drops them from `credits_dice_sources`, adds the Rival. Carries a comment recording a previous over-correction that wrongly ate Motivation/Class credits too ✓ |
| `CaptainPanel.gd:435-439` | **WRONG.** Builds the chip from `_find_db_entry()` — the raw `gear_database.json` row — so it renders `resources.credits_dice` with no knowledge of the suppression |

The UI and the mechanic read **different sources for the same number**. That is
precisely the trap CLAUDE.md records from the rules-wiring closeout: *"Any UI
literal describing a mechanic must READ the same data the mechanic does."*

**Blast radius is wider than the one card.** `CrewPanel.gd:638-640` has the
identical pattern (`"+%s cr"`), so ordinary crew show it too; and the same
`CharacterCreator` match block applies a **Bio-Upgrade** penalty (p.23,
"receive 2 credits less") that the panel is equally blind to.

Fix direction: have the tag builder read the character's own
`creation_bonuses.credits_dice_sources` (already the post-suppression truth)
rather than re-deriving from the database table.

**Not tablet-specific** — it renders the same on desktop.

**Scoped down after checking the money path — this is DISPLAY ONLY.** The
obvious next worry was that the credit total is re-derived the same way, which
would have made it a real credit leak. It is not: `EquipmentPanel.gd:547` adds
`bonuses.get("bonus_credits", 0)` — the character's own **post-suppression**
`creation_bonuses` — so the total is right. `_lookup_credits_dice_for_character()`
(`:1785`, the name-lookup twin of the CaptainPanel bug) feeds a breakdown
display, not the sum.

Live arithmetic agrees: **Starting Credits 19 = 6 base (1/crew × 6) + 13 rolled**,
with the visible dice chips (Finn +2d6, Nyx +1d6, others) fitting 13 only if
Bryn's background 1d6 is absent. Severity stays **wrong-play** because the
player is misinformed at the moment they decide whether to keep a rolled
captain, but no credits are actually gained.

## Book rules confirmed working on device (Test 2)

Worth recording as explicitly verified, since each was a live check against the
PDF rather than a code read:

| Rule | Source | Evidence |
|---|---|---|
| Genetic Uplift stat block | Core Rules p.21, extracted | Reactions 2 / Speed 5 / Combat +1 / Toughness 4 / Savvy +1 — captain matched exactly |
| Traveler stat block | Core Rules p.23, extracted | Reactions 3 / Speed 4 / Combat +0 / Toughness 4 / Savvy +2 — Dex Kovac matched |
| Stat stacking | gear_database | Captain Combat 3 = species +1, Enforcer +1, Glory +1. Dex Reactions 5 = Traveler 3, Ganger +1, Military Outpost +1. Both exact |
| `stat_modifiers` is NOT double-applied | — | Would have raised all five stats by +1; Reactions/Toughness/Speed were untouched |
| **Mutant background is forced** | Core Rules p.21 *"Background is always Lower classes of megacity"* | Yuri Drake (Mutant) generated with **Lower Megacity Class** |
| Genetic Uplift +1 Rival | Core Rules p.21 | `CharacterCreator.gd:920` |
| int→string enum conversion | prior known bug | All 6 characters got real class/species/background/motivation — none defaulted to BASELINE/COLONIST |
| p.28 Savvy substitution | Core Rules p.28 | "Swap Military → High-Tech (2 available)" offered with live swap buttons |

### T2-02 is not one warning, it is a DISCONNECTED VALIDATION LAYER

Creating one campaign produced **five** validator complaints, and every one of
them is false. Reported as a single systemic finding because they share a cause
and fixing them one at a time would miss it:

| Step | Warning emitted | Reality on screen |
|---|---|---|
| 1→2 | `Crew size not set - will use default of 4` | Config shows 6; final review confirms "Campaign Size: 6" |
| 3→4 | `Crew not generated via backend system (using fallback)` | 5 crew + captain generated with full stats |
| 4→5 | `Equipment not generated via backend system (using fallback)` | 15 items, shared pool, per-character bonuses, Savvy swap all present |
| 6→7 | `World data not generated yet - will use defaults` | "Current World: Foch II", traits/government/tech level, **"✓ World Confirmed"** |
| finalize | `Final validation failed. Total errors: 1` | Campaign created and played fine |

**Cause.** `CampaignCreationStateManager` keeps its own `campaign_data` mirror,
and its warning validators test keys the live panels never write — `crew_size`
(the SSOT is `campaign_crew_size`), `crew.backend_generated`,
`equipment.backend_generated`. The last row is already **documented as
deliberate** in CLAUDE.md: `_validate_final_phase` is hard-coded not to block
because its strict crew check compares members against the total crew size while
the panel excludes the captain, so it reports legal campaigns as short.

**Why it matters even though nothing is broken.** Five false alarms per campaign
is not noise, it is camouflage — a real validation failure would land in the
same log looking identical, and the one validator that could have caught
something (`:969`'s crew-size range check) is unreachable behind the same orphan
key. The cheapest correct fix is to delete or re-key the dead validators, not to
suppress the log.

### T2-02 detail — a validator keyed to a name nobody writes

`CampaignCreationStateManager.gd:467` tests `config.has("crew_size")`. The
creation config uses **`campaign_crew_size`** throughout: defaulted to 6 in both
`ExpandedConfigPanel.gd:83` and `CampaignCreationCoordinator.gd:93`, written at
`ExpandedConfigPanel.gd:1147`, forwarded at `Coordinator.gd:661-662`, and
consumed at `CampaignFinalizationService.gd:377-378`
(`clampi(config.get("campaign_crew_size", 6), 4, 6)`).

So three separate things are true at once:

1. **The gameplay value is fine.** The campaign really does get 6 — to be
   confirmed against the saved file in Test 7.
2. **The warning is unconditional and its text is false.** It fires on every
   creation and names a default of 4 that no code path produces.
3. **The real defect: the range validation never runs.** `:969`'s
   `SecurityValidator.validate_numeric_input(config_data.crew_size, 1, 8)` is
   gated on the same orphan key, so crew size is never validated at all. (Its
   bounds are wrong too — the book allows 4/5/6, not 1-8 — but that is moot
   while the branch is unreachable.)

Same defect family as the closed ledger: *a consumer reading a key no producer
writes*. It survived because the symptom is a log line, not a broken screen.

### T1-01 detail — it is the ASSET, and it is not tablet-specific

Verified rather than assumed. `assets/covers/cover_standard.png` is
**1843×695, PNG colortype 2 = RGB with no alpha channel, and no `tRNS` chunk**.
The white plate is baked into the source art, so `ModeShowcaseCard`'s
`STRETCH_KEEP_ASPECT_CENTERED` faithfully letterboxes a white rectangle.

The other three covers (`cover_bug_hunt`, `cover_planetfall`, `cover_tactics`)
are also alpha-less, but they are 4229×3307 full-bleed illustrations where an
opaque background is correct. `cover_standard` is the odd one out: it is a
**wordmark** where the others are paintings.

**This renders identically on desktop.** It is a pre-existing defect that every
prior desktop QA pass looked straight at and did not record — which is the
useful part of the finding. Fix is art-side: re-export with alpha, or replace
with a full-bleed cover matching the other three.

## Scope correction found during Test 1

`MainMenu.gd:14` sets `const A1_BUILD := true`, which deliberately hides
**Co-op, Bug Hunt, Tactics and Planetfall** (`_apply_a1_scope()`, and the
Tactics/Planetfall inject functions early-return). Their absence from the menu
is intended alpha-1 scoping, **not** a defect.

Test 8 is rescoped accordingly: only **Battle Simulator, Library, Settings and
Onboard Existing Game** are reachable entry points in this build. Reaching the
other three modes would require flipping the constant and redeploying, which is
out of scope for an alpha-1 test pass.

| T4-03 | 4 | World Phase Step 2 (Crew Tasks) | Crew are listed so a task can be assigned | **Crew list renders EMPTY on a fresh campaign.** No task can be assigned → "Resolve All Tasks (0)" stays disabled → **Next Step does nothing.** The campaign cannot leave Step 2 | **BLOCKER** | `36`-`38` | FAIL |
| T7-01 | 7 | Dashboard after Load | Equipment stash lists its items | EQUIPMENT panel renders **heading only, no items**, after loading a campaign. The save file still holds all 8 (`equipment.equipment`), so **no data is lost** — display-only | wrong-play (reads as loss) | `43` + pulled save | FAIL |

### T4-03 — FIXED Aug 8 2026, and it was not the bug it looked like

**The crew data was never wrong.** Every accessor in the suspected chain returns 6:
`GameState.get_active_crew()`, `campaign.get_crew_members()`,
`CampaignTurnController`'s own `c_wp.crew_data.get("members", [])`, and
`CrewTaskComponent.crew_data`. The `ItemList` itself held all six names the whole
time. The Jun-2024 `_member_get()` hardening is intact and logcat was clean.

**It is a layout collapse.** Measured live on desktop at the tablet's geometry:

| Node | Height |
|---|---|
| `PhaseContentVBox` (the step content) | 1130 |
| **`PhaseScroll` viewport** | **117** |
| `PhaseContainer` contribution to the column minimum | **2** |

`_apply_vertical_compaction()` hands space back — by letting the OUTER scroll own
the gesture and disabling the inner one — but only when the viewport is under
`SHORT_VIEWPORT_DESIGN_PX` (620), which was calibrated for a phone on its side
(~338). **A 1280x800 tablet in landscape measures 689 design px**, sails past that
test, and is then left with a 240px budget after 449px of fixed chrome (margins 64,
header 75, the 134px Controls block, the 48px footer, two separators, four 24px
gaps). A `ScrollContainer` reports ~0 minimum height, so `PhaseContainer`
contributed 2px to the column minimum and absorbed the whole squeeze in silence —
nothing overflowed, nothing was logged, and the layout sweep passed.

**Fix** (`WorldPhaseController.gd`): decide compaction on the space actually left
for the step area, not on raw viewport height.

- `MIN_PHASE_VIEWPORT_DESIGN_PX := 320.0` — a list plus the buttons that act on it.
- `_phase_viewport_budget()` — viewport height minus the chrome's *minimums*.
- `tight` is now `viewport < 620 OR budget < 320`.

Two traps handled, both found by measuring rather than reasoning:

1. **The budget must be taken in RELAXED units.** Compaction edits four of its own
   inputs (both separations, `margin_bottom`, the Title's visibility), so reading
   them live made the same tablet measure **240 relaxed and 384 tight** — straddling
   the threshold, so the layout would flip-flop between resizes.
2. **The Title must be normalised out in both states.** Charging for it while hidden
   put every tight reading permanently below every relaxed one, which latched the
   layout on the first evaluation (a 1920x1200 desktop wrongly went tight and stayed
   there).

**Verified across four geometries, three consecutive passes each — budgets identical
every pass, so no oscillation:**

| Window | Budget ×3 | Outer scroll | Step viewport | |
|---|---|---|---|---|
| 1920×1200 desktop | 624.5 | disabled | 465 | unchanged |
| **1280×800 tablet landscape** | **283.7** | **auto** | **1151** (was 117) | **fixed** |
| 800×1280 tablet portrait | 697.4 | disabled | 545 | unchanged |
| 733×338 phone landscape | −109.6 | auto | 1159 | unchanged |

Confirmed visually: the crew list renders all six members beside the full task list.

**Regression guard**: `tests/unit/test_world_phase_step_viewport.gd`, 7 cases, 0
orphans. Detection-proven — reverting the budget condition fails
`test_compaction_triggers_on_either_small_screen_or_starved_step_area`. The suite
documents in place why the 1280x800 case itself is *not* asserted there: a
bare-instantiated screen has no campaign, so its chrome is a fraction of production
size and the budget never reaches the floor. That test was attempted and removed
rather than weakened into a green row that proves nothing.

**No regressions**: `verify_layout` 166 passed / 2 failed — byte-identical with the
change stashed, and both failures are on `CampaignJournalScreen` at phone sizes.
All four `scripts/lint_*.py` CLEAN. Neighbouring suites
(`test_new_world_arrival_steps` 10/10, `test_prebattle_responsive_layout` 4/4) green.

**VERIFIED ON DEVICE** (build `12:12:19`, then re-confirmed on the clean build
`12:49:31`): Step 2 renders all six crew, all eight tasks, both action buttons and the
full world briefing. Screenshot `world1_s` / `c1_s`.

**T4-01 was NOT the same root cause.** That prediction was wrong and the device
disproved it in one measurement: on the fixed build a swipe over the content still moved
nothing, pixel-for-pixel (`ImageChops.difference(...).getbbox() is None`). Two separate
defects that happened to share a screen. See the T4-01 entry below.

### T4-03 — the sprint blocker (original diagnosis, kept for the record)

This is the finding that stopped the run. It is **not** the documented Jun-2024
`2-arg .get()` abort: logcat is completely clean, no `SCRIPT ERROR`, so the
`_member_get()` hardening in `CrewTaskComponent` is doing its job.

Trace, so the fix has a starting point:

- `WorldPhaseController._refresh_crew_tasks()` (`:1620-1627`) sets
  `crew_data = GameState.get_active_crew()` then calls
  `crew_task_component.initialize_crew_tasks(crew_data)`.
- `CrewTaskComponent.initialize_crew_tasks()` (`:171-173`) does
  `crew_data = crew.duplicate()`, and `_populate_crew_list()` (`:193-199`)
  iterates it.
- The eligibility filter is **not** the cause: `_task_block_reason()` returns a
  *reason string* and blocked members are still added to the list, greyed with a
  label (`"%s [%s]"`). An entirely empty list means `crew_data` itself is empty.

So the suspect is `GameState.get_active_crew()` returning empty for a
freshly-created (never-reloaded) campaign. Worth testing both branches, because
the dashboard's own CREW MANIFEST renders all six at the same moment — the crew
exist, this one accessor cannot see them.

**Impact:** a new player cannot finish their first campaign turn. Everything
downstream of World Phase Step 2 — the campaign battle, post-battle, turn
rollover — is unreachable via the normal path.

## T8-01 — Android BACK killed the app — FIXED + device-verified Aug 8 2026

Pressing the system Back button on the World Phase did not navigate and did not prompt:
it exited to the launcher and the **process was gone** (`ps -A | grep fiveparsecs` empty
afterwards). Severity **wrong-play**: Back is the most-used control on Android and the app
treated it as "quit, no confirmation". Desktop QA cannot see this — there is no Back key.

**It was not missing code.** `application/config/quit_on_go_back` defaults to **true**, so
`SceneTree` quits the moment Back arrives, *before* any handler can react — and
`GameState._notification()` had been flushing the campaign on
`NOTIFICATION_WM_GO_BACK_REQUEST` all along. Nothing was ever lost; the app just left. The
original note here said "unsaved turn progress goes with it", which reading the existing
handler disproved.

Fix: the setting is now `false` and `SceneRouter` owns Back.

| Situation | Behaviour | Verified on device |
|---|---|---|
| A dialog is open | Close it — **checked first**, since navigating out from under a modal orphans it | by construction (unit-tested) |
| History exists | `navigate_back()` | World Phase → Dashboard → main menu, process alive |
| At the root screen | Toast "Press Back again to exit" | toast shown, process alive |
| Second press within 2.5 s | Quit | quit |
| Press after the window lapses | **Re-arm, never quit** | waited 5 s, still alive |

Closing a dialog emits `close_requested` when anything is listening rather than a bare
`hide()`, so the owner's cleanup still runs.

Pinned by `tests/unit/test_android_back_button.gd` (6 cases). The first asserts the
**project setting**, deliberately: every line of the handler is inert while
`quit_on_go_back` is true, so an edit dropping that one line would restore the bug with
all the code still present and passing review. The policy itself is a pure function
(`SceneRouter.decide_back_action`) so the decision table is testable without an app that
really quits.

## ✅ Test 5 COMPLETE — first end-to-end campaign turn on real hardware (Aug 8 2026)

Build `15:53:33`. Walked **World Phase steps 1-6 → campaign battle → 14-step post-battle →
Campaign Cycle Summary (Phase: Retirement, 100%)**. This had never completed on device
before; three separate blockers were fixed to get through it (T5-02, T5-07, plus T5-01).

Evidence the sequence really ran, from the Battle Results log:

```text
Step 4:  Payment received: 6 credits
Step 5:  Battlefield: Roll on Consumables Table, receive 1 dosage
Step 6:  Sector Clear - No invasion threat detected
Step 7:  Loot found: Camo Cloak
Step 9:  5 XP + 3 XP x5   (all six crew)
Step 12: Campaign Event: Bad Reputation  (full book text)
Step 13: Overhear Something Useful
Step 14: Galactic War: no Invaded worlds tracked
```

Step 14's panel is Core Rules p.126 verbatim (2-4 Lost to Unity / 5-7 Contested / 8-9
Making Ground +1 / 10+ Unity Victorious, future Invasion Threat -2) and correctly declined
to roll with no tracked worlds.

Three different objectives were drawn across the runs and all rendered book-correct text:
**Patrol** ("end a move within 2\" of each of the 3 marked terrain features", p.90),
**Access** ("successfully access the console (1D6+Savvy, 6+ needed)", p.90), **Fight Off**
("Hold the Field", p.90). Notable Sights fired too (Person of Interest +1 story point,
Shiny bits +1 credit, p.89), and one battle drew a **Poor Visibility** deployment condition.

---

## T5-07 — BLOCKER, FIXED: submitting a battle result killed the post-battle sequence

**Severity: BLOCKER** (campaign unplayable past the first battle). Device-verified fixed.

Submitting Battle Results tore down the battle screen to black and **nothing replaced it**.
The drawer stayed open, the process kept running at 60fps, and `adb logcat` showed no
error at all. It reads exactly like a hang.

The remote-deploy debugger had the answer (this is why the editor Output panel matters —
`print`/errors from a remote deploy go there, NOT to logcat):

```text
Invalid call. Nonexistent function 'set' in base 'String'.
  PostBattleContext.gd:785   _set_character_stat   character = "char_690716_1964"
  PostBattleContext.gd:824   apply_random_ability_increase   stat="reaction" value=1
  CharacterEventEffects.gd:478   "Personal Breakthrough" (Core Rules p.129)
  CharacterEventEffects.gd:206   finalize_event
  PostBattlePhase.gd:543     _process_character_events   (step 13)
```

**Root cause — one expression returning two incompatible shapes:**

```gdscript
var crew: Variant = event.get("crew_id", ctx.get_random_crew_member())
```

`crew_id` is a String **id**; the fallback returns a Character/Dictionary. Everything
downstream treats the value as a character. A non-empty String is **truthy**, so
`_set_character_stat`'s `elif character:` accepted it and died on `String.set()`. Godot
**aborts the function** on an invalid call and keeps the process alive — so step 13 unwound
and took the whole 14-step sequence with it, silently.

The dual shape was *half*-known: the journal line right below already read
`crew if crew is String else str(crew)`. **Handling a type split at one of its consumers
leaves every other consumer to find it at runtime.** It also silently broke
`get_character_origin()`, because `"origin" in some_string` is a *substring* test.

Fixes (both, deliberately):
1. `CharacterEventEffects.finalize_event()` resolves an id through `ctx.get_crew_member()`
   — the real fix, normalizing at the boundary.
2. `PostBattleContext._is_character_like()` guards `_get/_set_character_stat`,
   `apply_luck_increase` and `apply_random_ability_increase` on **shape, not truthiness**,
   with a `push_error`. A future caller that forgets now loses one stat write loudly
   instead of the entire post-battle run silently. (`apply_random_ability_increase` also
   used to *return an ability name* for a String — telling the player "+1 Reaction" for a
   stat that never moved.)

Pinned by `tests/unit/test_character_event_crew_resolution.gd` (3 cases, detection-proven:
reverting the boundary resolution fails 2 of 3).

### T5-07b — the same class, found by scanning for it

While in there, a repo-wide scan for **typed return signature vs untyped body** found two:

| Site | Shape | Fix |
|---|---|---|
| `PostBattleSequence._get_current_crew()` | `-> Array[Resource]`, body `var crew_array: Array` | widen the **signature** (body is genuinely mixed: Resources on a fresh campaign, Dictionaries on a loaded save) |
| `AdvancementSystem.get_available_advancements()` | `-> Array[Dictionary]`, body `var advancements: Array` | narrow the **body** (callers assign into `Array[Dictionary]`) |

Both produce `Trying to return an array of type "Array" where expected return type is
"Array[X]"` — again a **runtime abort that a headless parse check cannot see**, because the
function is never called. The first was reported by the user from the editor Output panel.

New permanent guard: **`scripts/lint_typed_return_mismatch.py`** (CLEAN, detection-proven).
That makes **five** lints; all five are clean.

---

## T5-02 — Resolve Rumors: a soft-lock, a stale completion, and a stale label — FIXED

Found immediately after T5-01 unlocked the Quest path, and **caused by unlocking it**:
these three were unreachable while the rumor list was being wiped, because no Quest could
ever exist. Completing a dead gate arms whatever was behind it.

1. **SOFT-LOCK (blocker).** p.85 begins "*If you are not currently on a Quest*, roll a D6",
   so with a Quest running the step is a no-op. But `is_rumors_resolved()` returns
   `rumors_resolved` alone and the `has_active_quest` branch of `_on_roll_pressed()`
   returns *without* setting it — while `_update_ui_display()` disables the roll button in
   exactly that state. A crew on a Quest that also held a Quest Rumor ("*until the Quest is
   resolved, any time you would receive a Rumor, you receive a Quest Rumor instead*") could
   neither roll nor advance. Next Step disabled forever, mid-World-Phase.
2. **Stale deferred completion.** The 0-rumor auto-complete queues `_emit_auto_complete()`
   via `call_deferred`. The component initializes **twice** in a real run (empty aggregate,
   then real), so the empty pass queued a completion that fired a frame later against a
   5-rumor step. `_on_phase_completed()` writes that into `step_completed[RESOLVE_RUMORS]`,
   which is **checkpointed to disk** and drives the step chips — step 5 showed a green tick
   before the D6 was rolled. It survived only because `_can_advance_to_next_step()` asks
   the *component* and falls back to `step_completed` only when the component is missing;
   the chip lied while the gate held. **A deferred callback must re-check the condition
   that justified queueing it.**
3. **Stale label.** `initialize_rumors_phase()` reset every state *variable* but not
   `result_label`, so "No rumors to resolve" rendered beside a populated 5-rumor list.

Pinned by `tests/unit/test_resolve_rumors_step.gd` (4 cases). All three detection-proven in
isolation. Device-verified on build `15:00:50`: label clear, chip 5 shows current (not ✓),
roll fires, **Quest generated**, step 5 → 6 advances.

> ⚠ **A green test can prove nothing.** The first version of the stale-emit test asserted
> `is_rumors_resolved()` and **passed with the guard fully removed** — `_emit_auto_complete()`
> publishes an *event* and never touches that flag, so the assertion was structurally blind
> to the bug it was written for. Rewritten to subscribe to `CampaignTurnEventBus` and count
> `resolve_rumors` completions; it then failed with "1 completion event(s) published".
> **Assert where the damage lands, not where it is convenient.**

---

## T5-03 — Proceed to Battle renders below the fold with no scroll affordance

**Severity: HIGH (reads as a hang).** On World Phase step 6, tapping "Ready for Battle"
dims the panel and the green **⚔ Proceed to Battle** button sits *below the visible
viewport* — as does "← Back to Dashboard". Nothing indicates the page scrolls. I recorded
this as a soft-lock before finding the button by dragging; a player would reasonably
conclude the app had hung. Not a logic fault — the button exists and works.

## T5-04 — Mission Prep briefing is permanently blank

**Severity: MEDIUM (misleading).** Step 6's "Mission Briefing" always reads
`Objective: Unknown / Enemy: Unknown / Danger Level: 0 / Location: Unknown / Pay: 0 credits`
while the World Briefing directly beneath it reports Foch II, Danger 4. The mission is not
generated until `CampaignTurnController._initiate_battle_sequence()`, which runs *after*
the world phase completes — so this block is structurally too early to ever be filled.
Downstream is fine (PreBattleUI showed the full real mission). Populate it or remove it.

## T5-05 — Battle Log round tags increment per phase, not per round

**Severity: LOW.** With the header, phase bar and chips all correctly reading **Round 1**,
the log emitted `[R1] === ROUND 1 BEGINS ===`, then `[R2] Round 2`, then more `[R1]` lines;
after the next phase advance, `[R3] Round 3`. A second round counter is being incremented
on phase transitions. Reproduced across two separate battles.

## T5-06 — Record Battle Result drawer: horizontal clipping + drag-scroll does not work

**Severity: MEDIUM.** Two defects in the same drawer, on a 2560px-wide landscape tablet:
- Content is **clipped at the right edge** — "Rounds foug[ht]" and its input run off-screen.
- **Finger-drag scrolling does nothing**; only dragging the scrollbar itself scrolls. This
  is the same class as T4-01 (decorative `PanelContainer` cards defaulting to `STOP` and
  eating the drag), in a screen the T4-01 fix did not touch.

Also: checking **"Objective achieved" does not update Battle Result**, which stays "Lost".
Core Rules p.89: "To Win the battle, you must achieve the objective." The two controls can
be left contradicting each other.

## T5-08 — Post-battle results log says "Unknown" instead of crew names

**Severity: MEDIUM.** Every XP line read `Step 9: Unknown gained 3 XP` (x6) and step 13
read `Step 13: Unknown: Overhear Something Useful`. The awards themselves landed; only the
name resolution failed. Likely the same id-vs-object confusion as T5-07 in a different
consumer — worth checking with that fix in hand.

---

## ✅ NOT A BUG — Seize the Initiative "Need 8+ ... 42%" (recorded because it nearly shipped as one)

PreBattleUI showed `Need 8+ on 2D6 (Savvy +2) — 42% chance` while the Enemy Forces panel
one column over showed `Category: Hired Muscle (Seize Init -1)`. 8 = 10 − 2 − 0, so the
penalty the same screen advertised was plainly missing from the number. This codebase's
single most common defect is a modifier that is displayed and never applied, so most of a
bug report was written before the **crew roster** got checked.

**The app is right.** Core Rules p.112 ends: "*If your crew includes any Feral, you may
ignore any penalties the opponents would have imposed on you.*" **Finn Mendez is Feral**
(confirmed in the device save: `origin= FERAL`). The −1 is correctly cancelled, 8+ is the
correct target, 41.67% is the correct probability. `SeizeInitiativeSystem` implements it
exactly, skipping only `modifier.value < 0` so a *favourable* enemy modifier still counts.

The lesson is about evidence: **a modifier present in one panel and absent from another
panel's arithmetic is a LEAD.** Before calling it a wiring break, check the campaign state
that could legitimately cancel it. Reading only the code could not have settled this.

Pinned both ways by `tests/unit/test_seize_initiative_hired_muscle.gd` (6 cases), including
a Feral case, a non-Feral case, and a "Feral cancels penalties only, never bonuses" case,
so nobody later "fixes" the app into breaking p.112.

**One real (minor) gap:** the UI never tells the player *why* the −1 didn't apply. A
"Feral: enemy penalties ignored (p.112)" note would close the loop.

---

## T5-01 — Quest rumors read 0 against a campaign holding 5 — FIXED + DEVICE-VERIFIED

Found while running Test 5 on the fixed build. **World Phase Step 5 (Resolve Rumors)
displayed "Rumors: 0" and "No rumors to resolve"** while the dashboard, `resources
.quest_rumors` and `crew.quest_rumors` all held **5**.

That is not cosmetic. Core Rules p.85 step 5 is "roll D6; if equal to or below the number
of rumors, convert one to a Quest". **At zero the roll can never succeed**, so Quests are
unreachable through the World Phase — the likely mechanism behind the standing
"Quests unplayable end to end" finding.

**Root cause: one name, two meanings.** `world_phase_data` carries both the PLANET (name,
government, traits, locations) and the PHASE's own aggregate (rumors, quest, patrons,
stash). `_fetch_campaign_data()` builds the second during `_ready()` — including a correct
int-count → array conversion for rumors — and then `CampaignTurnController:711` calls

```gdscript
world_phase_data = world_data.duplicate()   # world_data is the PLANET
```

which threw the entire aggregate away. Step 5's `world_phase_data.get("rumors", [])` then
returned `[]` forever, and `.get()` on a missing key is a silent default, so nothing
errored.

**The evidence that settled it** was the persisted checkpoint, not the screen: its
`world_phase_data` is a pure planet dict —

```text
['current_location','danger_level','discovered_on_turn','government_name',
 'government_type','has_patron','id','is_complete','locations','mission_count','name',
 'patrons','population_name','population_scale','resources_extracted','special_features',
 'stash','tech_level','tech_name','traits','type','type_name','visited_locations']
```

— no `rumors` key, no `quest` key. That is the aggregate's corpse, saved to disk.

Fix: merge instead of assign. Pinned by `tests/unit/test_world_phase_data_merge.gd`
(2 cases, detection-proven — restoring the assignment fails with "dropped the rumor list",
"dropped the active quest", "dropped the patron list").

✅ **DEVICE-VERIFIED** on build `14:49:57`: Step 5 reads **"Rumors: 5"**, the list renders
Rumor 1-5, the button reads **"Roll to Resolve (D6 ≤ 5)"**, and rolling produced
**"Rolled 2 ≤ 5 rumors — QUEST GENERATED! New Quest: Mysterious Data"** — the first Quest
this codebase has ever generated. The World Briefing still showed Foch II with its traits
and locations, confirming the merge kept *both* halves of the dict.

Rumors then went 5 → 0, which is **correct**: p.85 says "remove **all** Rumors from your
roster", not one. Checked against the PDF before filing it as a bug.

**Restore path is also safe** (checked, not assumed): `restore_from_checkpoint()` assigns
`world_phase_data` straight from the persisted — and therefore corrupted — checkpoint, but
`_fetch_campaign_data()` runs *after* it (`:685` follows `:680`) and rebuilds the aggregate,
and the merge then folds the planet back in on top. Ordering holds.

**Worth noting for the same file:** `restore_from_checkpoint()` already re-derives the
**stash** rather than trusting the checkpoint's copy, under a long comment arguing that
derivable data must never be persisted. `rumors` and `quest` are equally derivable and
were not covered — the same reasoning had been applied to one of three keys.

## Side-fix — CampaignJournalScreen, the last two layout-sweep failures

Not a device finding; `verify_layout` had reported these for some time and this sprint
closed them, taking the sweep from **166/2 to 168/0 — its first fully green run**.

Both were **horizontal**, which the harness's own message does not say (it reports a max
over both axes), and that is why they read as a mysterious vertical overflow for so long:

| Case | Root MarginContainer needs | Design width | Over by |
|---|---|---|---|
| `360x640` ("small phone", design 310.3) | 359.0 | 310.3 | **48.7** |
| `393x851` ("phone portrait", design 338.8) | 347.0 | 338.8 | **8.2** |

The cause is five levels down: three buttons — Edit Notes / Attach Photo / View Photos —
in a plain `HBoxContainer`. A box's minimum is the **sum** of its children, and the detail
pane's `ScrollContainer` has `horizontal_scroll_mode = SCROLL_MODE_DISABLED`, and **a
disabled axis propagates the child's minimum straight up rather than absorbing it**. So
243px of un-wrappable buttons became 259 → 267 → 299 → 331 → 359 at the screen root.

Fix: `HFlowContainer`, exactly as this screen's own `_build_header()` already does for
the same reason. A flow container's minimum is its **widest item**, not the sum — measured
331 → 155. Pinned by `tests/unit/test_journal_screen_narrow_layout.gd` (2 cases,
detection-proven by isolated revert; the width case reproduces both harness numbers).

**Transferable:** a `ScrollContainer` with an axis disabled is not a shrink point on that
axis — it is a rigid conduit for whatever minimum sits inside it. The World Phase blocker
this same day was the mirror image (a scroll absorbing an axis silently). Same class,
opposite direction, and both are invisible on a desktop-sized window.

## ✅ Test 5 continued — Turn 2 + mid-turn kill/resume (Aug 8 2026)

Turn 2 was played on device through World Phase steps 1-5, then the app was force-stopped
mid-step-5 and relaunched. **The resume works** — and the restart is also what proved the
turn's biggest finding, because it is an A/B of the same screen with and without a fresh
`_ready()`.

What was walked and confirmed correct on device this turn:

| Step | Observed | Book check |
|---|---|---|
| 1 Travel | "3 Rivals stayed behind · 2 Patrons did not follow", "Arrived: Gamma Prime — added to Galaxy Log", credits 24→19 | p.72 New World Arrival steps 1-2 ✓ |
| 1 Travel event | D100 **93** → "Time to read a book" → Dex Kovac, Mars Stark, Finn Mendez each +1 XP | p.72 row 92-95, the **5-6** branch ("three random crew each earn +1 XP") ✓. All three branches implemented at `TravelEventResolver.gd:664-684` |
| 1 Upkeep | Crew Upkeep 1 credit (6 crew), Ship Maintenance 0, credits 19→18 | p.76 "1 credit for 4-6 crew" ✓ |
| 2 Crew tasks | All 8 tasks offered: Find a Patron (5+), Train (Auto), Trade (Table), Recruit (6+), Explore (Table), Track (6+), Repair Your Kit, Decoy (Auto); "+1 cr" spend control | pp.77-78, all eight and every target number ✓ |
| 2 Find a Patron | "Roll 4 → 5 vs 5. +1 for 1 crew · Found 1 job offer (an existing Patron)" | p.77 "roll 1D6 and add the number of crew members who are looking… 5 or higher" ✓ |
| 2 Trade | Crew Task Event dialog: "Medical pack — Receive your choice of a Stim-pack or Med-patch" | p.79 Trade Table row **19-22**, verbatim ✓ |
| 4 Equipment | Med-patch from the Trade event appears in SHIP STASH, not on a character | "one item, one home" invariant ✓ |
| — Resume | Force-stop mid-step-5 → relaunch → Continue Campaign → dashboard → Begin Turn 2 → **restored to Step 5** with travel, upkeep, tasks, job and equipment all intact | mid-turn resume **PASS** |

### W2-01 — HIGH — the World Phase renders Turn 1's data for the entire app session

`WorldPhaseController.world_phase_data` carries the phase aggregate (rumors, quest,
patrons, stash, location). It is built by `_fetch_campaign_data()`, which is called **only**
from `_setup_initial_state()` — a `_ready()`-time hook — and from the checkpoint-restore
branch (`WorldPhaseController.gd:685`). `CampaignTurnController` *shows* the existing
controller each turn (`CampaignTurnController.gd:700-714`) rather than re-creating it, and
`initialize_world_phase()` only **merges** planet keys. So nothing rebuilds the aggregate on
turn rollover.

Proven by A/B on the identical screen, same campaign, seconds apart — the only variable
being a process restart that forced `_ready()` to run again:

| Step 5 of 6 | Before restart | After restart | Dashboard (live state) |
|---|---|---|---|
| WORLD BRIEFING | Foch II | **Gamma Prime** | Gamma Prime |
| World traits | Corporate State [Patron] | **Imminent Invasion [War]** | Imminent Invasion |
| Danger Level | 4 | **2** | ●●○○○ |
| Rumors | 5 | **6** | Quest Rumors: 6 |
| Roll target | D6 ≤ 5 | **D6 ≤ 6** | — |

Player-visible consequences seen this turn:

- The briefing advertised Foch II's "**+2 when rolling to find a Patron**" while the actual
  roll correctly applied **no** such bonus (we are on Gamma Prime). The player is shown a
  modifier that does not exist.
- The accepted job read "**LOCATION: Foch II**".
- The step-5 D6 was rolled against **5** rumors instead of the campaign's **6**.
- "Current Location: Foch II" persisted in the step-1 header after "✓ Arrived: Gamma Prime"
  on the very same card.

**Mechanics are not affected** — `CrewTaskComponent._current_world_traits()` and
`InterdictionRule` read live campaign state (`gs.current_campaign`), which is why the Patron
roll was right. This is a display-integrity defect, but for a companion app whose entire job
is telling you the current state, a briefing that names the wrong planet is severe.

**Fix shape:** rebuild the aggregate at turn start. `initialize_world_phase()` is already
called once per turn from the UPKEEP branch and is the natural site — call
`_fetch_campaign_data()` there before merging the planet keys, or subscribe the controller
to `world_changed` (nothing in `src/ui/screens/world/` currently does).

### W2-02 — HIGH — the Turn 1 Quest did not persist, so p.85 re-opens every turn

Turn 1 generated a Quest on device ("Rolled 2 ≤ 5 rumors — QUEST GENERATED! New Quest:
Mysterious Data"). The end-of-turn-1 save on the device contains **no `active_quest` key in
`progress`** (walked every key; only `quest_rumors` matches `/quest|rumor/`). After a clean
process restart and reload from that file, step 5 still reads "**No Active Quest**" and
offers a fresh Quest roll.

`GameState.set_active_quest()` writes `current_campaign.progress_data["active_quest"]`
(`GameState.gd:1616-1618`), and `progress_data` **is** serialized (as `progress`), so the
write should survive. `ResolveRumorsComponent._generate_quest_from_rumors()` calls it at
`:267`, and `:284` calls `gsm.set_quest_rumors(0)` for p.85's "remove all Rumors from your
roster". Neither landed: the save shows `resources.quest_rumors = 6` (5 creation rumors + 1
gained), i.e. **the roster was never cleared**.

⚠ **UNVERIFIED which of two causes.** Either (a) the persistence block at `:260-284` never
executed — the UI half at `:236-252` demonstrably did, since the device showed the quest name
— or (b) the Quest was legitimately cleared by the p.120 post-battle "Determine Quest
progress" step (`clear_active_quest()`), in which case the missing piece is only the rumor
wipe. These need separating before a fix; do not patch on the assumption of (a).

Why it matters: with no active Quest the p.85 gate ("**If you are not currently on a
Quest**, roll a D6") passes every turn, which is exactly the overwrite scenario the code
comment at `ResolveRumorsComponent.gd:272-274` warns about, and the rumor pool never costs
anything.

### W2-03 — HIGH — finger-drag scrolling is dead on the World Phase; a required button was unreachable

On step 1 after the travel event card appeared, the content exceeded the viewport and
"Pay Upkeep" scrolled out of view. `input swipe` over the content did nothing (pixel-identical
screenshot); dragging the **scrollbar** at the right edge scrolled fine. So the container
scrolls and the touch is being swallowed before it reaches the ScrollContainer — the same
class as T5-06 and [reference_decorative_chrome_swallows_touch_scrolling], on a screen that
fix did not cover. On a tablet with no visible scrollbar affordance this reads as a hard
soft-lock.

### W2-04 — MEDIUM — "Resolve All Tasks" burns unassigned crew with no warning

Three of six crew were still unassigned when the step resolved ("Results: 3/3 succeeded").
The step then locked — "All Tasks Resolved", **Assign Task disabled** — so Mars Stark, Finn
Mendez and Nyx Ward permanently lost their turn actions. The app's own subtitle says "Each
crew member can perform one task per turn."

⚠ **Trigger UNCONFIRMED.** My tap was inside the "Assign Task" hit box by measurement, and
the auto-processing path (`CrewTaskComponent.gd:2674-2681`) suppresses the popup that did
appear, so it was not that. Regardless of how it was reached, a single tap irreversibly
destroying half a turn's crew actions with no confirm is worth fixing: gate
`_on_resolve_all_pressed()` behind a confirm when eligible-but-unassigned crew remain.

### W2-05 — MEDIUM — scroll position persists across step changes

Advancing from step 1 to step 2 kept the previous scroll offset, so step 2 opened mid-content
with its "CREW MEMBERS" / "AVAILABLE TASKS" headers above the fold. Both ItemLists appeared
to show only their last rows. This manufactured a convincing phantom bug — it read as "only
1 of 6 crew is eligible" and "only 3 of 8 tasks exist", and cost a three-file investigation
before a scroll-to-top disproved it. Reset scroll to 0 on step change.

### W2-06 — LOW — killing the app re-rolls the step-5 D6

The step-5 rumor roll ("Rolled 6 > 5 rumors — No quest this turn") was not in the checkpoint:
after the force-stop the button was live again. Harmless to state, but it is a
save-scum vector for any roll taken after the last checkpoint write.

### W2-07 — LOW — cosmetic

- Job details render the objective twice: "OBJECTIVE: Deliver" followed by a description line
  that is also just "Deliver".
- ~~Disabled "Calculate Costs" / "Pay Upkeep" give no reason.~~ **WRONG — withdrawn.** The
  hint exists and reads **"⚠ Choose 'Stay' or 'Travel' first."** It sits at the bottom of the
  page, which on the tablet was below the fold behind W2-03 — so I recorded "no reason
  given" when the reason was simply unreachable. Seen the moment the scroll fix let the page
  scroll. A second finding caused by W2-03 rather than a defect of its own.

## ✅ Test 6 — Rotation (Aug 8 2026)

Forced via `adb shell settings put system accelerometer_rotation 0` + `user_rotation 0|1`
(natural orientation on this device is portrait 1600×2560; landscape is 2560×1600).

**Portrait PASSES on both screens tested, and it is real adaptation, not squeezing:**

| Screen | Landscape | Portrait |
|---|---|---|
| Campaign Dashboard | 3 columns: CREW MANIFEST / SHIP / CURRENT WORLD | **tabbed** — `Crew · Ship · World` tabs with full-width crew cards; button bar wraps to 2 rows |
| World Phase step 5 | list left, roll button right | single column, list above the roll button; blocker hint "⚠ Resolve your rumors (or skip if you have none) to continue" visible |

Nothing clipped, no horizontal overflow, all text legible, campaign data intact across both
rotations (Turn 2, Credits 18, SP 7, Gamma Prime).

### T6-01 — MEDIUM — floating ⚠/⚙ chrome does not resize back on portrait → landscape

After rotating to portrait and back, the two floating corner buttons return **larger than
they started** and are clipped: the gear's circular background is cut by both the top edge
and the right edge, and both now overlap the header panel they previously sat clear of.
A/B crop of the identical dashboard before and after the round-trip:
`screenshots/tablet-2026-08/crop-header-ab.png`.

They appear to retain the portrait touch-target size class rather than reverting on
`layout_class_changed`. Cosmetic, but it is a one-way change that accumulates on the screen
the player sees most.

Not yet rotated: the battle screen and the creation wizard (the campaign is mid-turn and
rotating into a battle would disturb the run). Worth covering on the next pass.

## 🧪 QA Scenarios — jumping to the states that are expensive to play to (Aug 8 2026)

Built after the turn-2 pass, because the coverage gap is not "which rules are wrong", it is
"which rules a campaign cannot reach in a reasonable number of turns". Two full turns on
device produced **zero injuries, zero XP spent, zero rivals tracking us, no Quest surviving,
and no Compendium mission type**.

**Where it is.** Campaign Dashboard → **QA** button, next to Edit. Gated on
`OS.is_debug_build()`, so a release export physically cannot open it — there is no hidden
unlock gesture to discover and nothing to remember to switch off before shipping. Remote
deploy builds are debug builds, so the tablet gets it.

| Piece | Path |
|---|---|
| Loader (all mutation) | `src/core/qa/QAScenarioLoader.gd` |
| Dialog (presentation only) | `src/ui/screens/dev/QAScenarioDialog.gd` |
| Fixtures | `data/qa_scenarios/*.json` |
| Tests | `tests/unit/test_qa_scenarios.gd` (13 cases) |

### Three design decisions worth not undoing

**Fixtures are DELTAS, not save files.** A real save here is ~37KB, is coupled to
`schema_version`, and is opaque — you cannot tell from a diff what makes it "the injuries
scenario". A fixture is a small declarative delta applied to whatever campaign is loaded,
through the **same owner setters the Campaign Editor uses** (names lifted from its spin
wiring, including `story_points` → `set_story_progress`). It stays readable, survives a
schema bump because it never touches the serialized shape, and `lint_data_ownership.py`
still covers the writes. Salvage goes through `SalvageLedger` as a computed delta because a
raw `progress_data` write is exactly what that rule bans.

**It does not jump the PHASE.** Deep-linking into, say, post-battle step 8 constructs states
the real flow never produces, and then a tester spends an hour on an artifact of the jump.
This session lost real time to precisely that class twice — a stale scroll offset
manufactured a "only 1 of 6 crew eligible" bug, and a correct Seize-the-Initiative result
nearly got filed. A scenario sets campaign state and hands back; the turn is entered
normally and the app builds its own phase.

**`apply()` returns a receipt, not a bool.** The dialog prints every field it wrote and
every one it could not, because a scenario that silently skipped half its setup is worse
than no scenario — the tester believes they are in a state they are not, and files findings
against it.

### The guards that matter

`test_every_counter_key_has_a_live_setter` and `test_every_dlc_id_named_by_a_fixture_exists`
are the project's usual defect shape inverted: a fixture key with no consumer. Both are
**detection-proven** — a `credtis` typo and a disallowed `origin` crew field were injected
and produced:

```text
Fixture 'injuries_and_advancement' sets counter 'credtis', which QAScenarioLoader cannot route.
Fixture 'injuries_and_advancement' patches crew field 'origin', which is not allow-listed.
```

Without them a typo presents as "the scenario did nothing", on a tablet, hours later.

The crew allow-list (`_CREW_FIELDS`) is deliberate: an open merge would let a fixture write
`origin` as an int or drop `character_id`, both documented ways to destroy a crew member
silently.

### The four fixtures

| Fixture | Reaches |
|---|---|
| `injuries_and_advancement` | pp.94-95 injuries, p.76 Sick-Bay-release ("rejoin for battle but CANNOT PERFORM A TASK"), p.123 Character Upgrades, p.125 Advanced Training |
| `compendium_mission_types` | Compendium Salvage pp.137-147, Stealth pp.117-122, Street Fights pp.123-136, No-minis pp.66-73. **Highest-risk block** — all four were LIVE-but-unreachable until Aug 6 and that fix has never run on hardware. `JobOfferComponent._generate_compendium_missions()` gates them purely on DLC flags, so enabling the two packs is the whole setup |
| `rivals_patrons_quests` | p.85 Check-for-Rivals forced battle (3 Rivals ⇒ fires on a D6 of 1-3), p.78 Track with a real target, pp.83-84 Patron subtables, pp.119-120 Quest progress. Also the deliberate retest for W2-02 |
| `endgame_and_failure` | p.76 upkeep failure (0 credits vs a 1-credit upkeep), p.75 ship seizure (debt 74, +2/turn crosses ≥75 next rollover), p.126 Galactic War with 2 tracked Invaded worlds, pp.148-151 Black Jobs (licensed + 10 RZ turns), Compendium p.147 Scrapper |

⚠ **Not yet device-verified.** The button and dialog pass headless (45/45 across 8 suites,
parse clean, 5/5 lints clean) but have not been opened on the tablet — that needs an editor
Remote Deploy.

## 🔧 Post-build verification pass (Aug 8 2026, evening)

The QA-scenario build was deployed and **blanked the Campaign Dashboard** — process alive,
logcat clean, nothing on screen. Same signature as T5-07.

### Two bugs in the new code, both mine, both caught before they cost anyone else time

**1. `UIColors.TEXT_MUTED` does not exist.** The short-alias block defines only
`TEXT_PRIMARY` / `TEXT_SECONDARY` / `TEXT_DISABLED`; the constant is `COLOR_TEXT_MUTED`.
Referencing a missing member is a **PARSE** error, which fails the whole script at load —
and `CampaignDashboard` preloads `QAScenarioDialog`, so the dashboard died with it. I had
verified `SPACING_MD` / `TOUCH_TARGET_MIN` against the file and then assumed `TEXT_MUTED`
by symmetry. Assumed, not read.

**2. Fixed-size dialog clipped both of its controls.** `size = Vector2i(900, 620)` +
`popup_centered()` against the tablet's portrait geometry (800×1280 design px) pushed the
scenario list off the left edge and **Apply Scenario off the right** — the dialog's only two
controls, both unreachable. Now `popup_centered_ratio(0.92)`, which sizes against the parent
viewport and is correct in either orientation.

⚠ I also "fixed" a third thing that was never broken: I rewrote the static factory's
`new()` into a `load().new()` on the strength of a memory entry about `ClassName.new()`
failing inside `static func`. Isolating it (revert one change, re-run) showed **15/15 still
green** — bare `new()` on a script with no `class_name` is fine. The change was reverted and
the comment now records what is actually true. A remembered trap is a lead, not a diagnosis.

### How it was found without a redeploy

`mcp__godot__get_debug_output` cannot see a remote-deploy session (it tracks only its own
launched process), so the editor Output panel stays the only place those errors appear. The
route that worked was **run the same build on desktop via MCP** — dashboard, dialog, apply,
all inspectable, with the debug output readable. Desktop dp equivalence means the portrait
window reproduces the tablet's geometry exactly, which is how bug 2 surfaced.

**Verified working on desktop:** dialog opens, all 4 fixtures listed with unlocks and notes,
`compendium_mission_types` applied with a **full receipt and zero warnings** —
`turns_played=4, credits=40, supplies=3, story_points=4, fixers_guidebook, freelancers_handbook,
salvage_units=6` — and the campaign then entered Turn 5 World Phase normally.

### W2-01 — FIXED, detection-proven

`initialize_world_phase()` now rebuilds the aggregate **once per campaign turn**, guarded on
a new `aggregate_built_for_turn` stamp. Guarded rather than unconditional because
`_fetch_campaign_data()` ends in `_initialize_components_with_data()`, whose
`JobOfferComponent._fail_expired_job()` writes journal entries — on turn 1 the function runs
moments after `_ready()` has already fetched, so an unguarded call would duplicate them.

The live stack trace from this session's desktop run confirms the root cause independently:

```text
[5] _fetch_campaign_data  (WorldPhaseController.gd:809)
[6] _setup_initial_state  (WorldPhaseController.gd:710)
[7] _ready                (WorldPhaseController.gd:178)
```

Pinned by two new cases in `tests/unit/test_world_phase_data_merge.gd` — one that the
aggregate IS rebuilt on a new turn, one that it is NOT re-fetched on the same turn.
Reverting the fix fails the first with its intended message.

### W2-03 — FIXED: one gesture model instead of a handoff that could not work

**Root cause: the two-mode scroll handoff, and its relaxed half was broken twice over.**

`_apply_layout_for()` used to swap ownership — outer scroll AUTO + inner DISABLED when
tight, the reverse when relaxed — and the relaxed branch:

1. **restored `MOUSE_FILTER_STOP` on every card and separator.** The source comment argued
   the chrome could keep STOP because "PhaseScroll is a child and so is offered the drag
   first". That is true of `PhaseContainer`, which sits **above** PhaseScroll, and false of
   the cards **inside** it — they are deeper, are offered the event first, and STOP marks it
   handled. So the container that supposedly owned scrolling never saw a single drag.
2. **set the outer scroll to `SCROLL_MODE_DISABLED`.** `StepNavigation` and the footer live
   inside it, so on any page taller than the viewport Next Step was unreachable —
   measured at portrait geometry: `NextButton` y=**1719**, `BackToDashboardButton` y=**1795**,
   viewport 1280.

**Fix:** unify on ONE model in every layout — outer `AUTO`, inner `DISABLED` + `IGNORE`,
`PhaseContainer` `PASS`, chrome swept open. `AUTO` (not `DISABLED`) is what the relaxed
branch actually wanted: it already means "inert while the content fits", without also
meaning "cannot scroll when it does not". Every invariant the two-mode design existed to
protect survives — exactly one scrollbar, never zero, gesture always reaches the owner —
and the branch where the owner could not receive it is gone.

**⚠ Four tests had to be rewritten because they encoded the bug.**
`test_decorative_chrome_does_not_swallow_the_drag` asserted that the relaxed layout *must*
put STOP back, on the same incorrect premise as the source comment. That is worth recording
on its own: a test can encode a defect as confidently as code can, and "the tests went red"
was a lead here, not a verdict.

**Verified on desktop (MCP):** after the fix the outer scroll reaches the full page — step
chips, Back, Next Step and Back to Dashboard all brought into view, where before they could
not be reached at all.

⚠ **The touch-drag half is NOT verified.** Synthetic mouse input injected by MCP does not go
through the OS mouse→touch emulation that `ScrollContainer`'s drag path needs, so a desktop
drag cannot exercise it either way. The mouse_filter chain is now provably open (asserted in
both layouts by `test_decorative_chrome_does_not_swallow_the_drag`), which is the mechanism
the tablet measurement pointed at — but confirming the finger actually scrolls needs a
device deploy.

Sweep after the change: **59/59 tests, 5/5 lints CLEAN, layout sweep 168 passed / 0 failed.**

### W2-03 (original filing) — how it presented

Previously filed as an Android touch problem. On desktop, a mouse press-drag-release over
the World Phase content **also scrolls nothing**; only the scrollbar works. So this is a
general scroll-input defect, not a touch quirk.

Measured on the step-1 screen at portrait geometry via `get_ui_elements`:

| Control | y | Viewport |
|---|---|---|
| `NextButton` | **1609** | 1280 |
| `BackToDashboardButton` | **1685** | 1280 |

The primary navigation control sits **329px below the fold**, the content runs to ~1733px,
and the only working scroll affordance is a thin scrollbar. On a portrait tablet that reads
as — and effectively is — a soft-lock on the first step of every turn.

`tests/tools/verify_layout.gd` cannot see it: the axis is scrollable, so overflow is legal
by that check. Same blind spot as
[[reference_a_scrollable_axis_hides_overflow_from_the_sweep]].

### W2-08 — LOW — two non-canonical journal writes

Surfaced in the desktop run's shutdown output:

```text
WARNING: Journal entry has non-canonical type: 'campaign'
  JobOfferComponent.gd:1214  _fail_expired_job
WARNING: Journal entry has non-canonical tag: 'debt'
  CampaignPhaseManager.gd:895  _process_ship_debt
```

`JournalEntryTypes.validate_entry()` rejects both. Same family as the closed ledger — a
producer writing a key the consumer does not accept — and it means those two entries may not
be filterable in the journal UI.

## Test progress

| # | Test | Status |
|---|---|---|
| 0 | Deploy to device | **PASS** — installed 10:13:50, arm64-v8a, v0.9.7 |
| 1 | First boot — consent, menu, logcat | **PASS**, 3 cosmetic findings |
| 2 | Campaign creation wizard on touch | **PASS** — campaign created; 6 findings |
| 3 | Campaign Editor seed fields | **PASS** — verified in the save file; 3 findings |
| 4 | Battle at Log Only | **PASS** — campaign path now walked end to end (see Test 5). Three different objectives drawn (Patrol / Access / Fight Off), Notable Sights, a Poor Visibility condition, deployment guide, Battle Card, round machine |
| 5 | 2-3 full campaign turns | **PASS** — turn 1 full (World Phase 1-6 → battle → 14-step post-battle → Cycle Summary; required fixing T5-01, T5-02, T5-07). Turn 2 walked steps 1-5 incl. travel to a new world, and the **mid-turn app-kill + relaunch resume PASSES** (restored to step 5 with all progress). Turn 2 produced W2-01..W2-07 |
| 6 | Rotation | **PASS (dashboard + world phase)** — portrait is genuine adaptation (dashboard becomes tabbed), nothing clipped, data intact both ways. 1 finding (T6-01, chrome does not resize back). Battle screen + creation wizard not yet rotated |
| 7 | Save/load | **PASS (round-trip)** — 1 display finding; desktop-save push not run |
| 8 | Other modes smoke | **PARTIAL** — Battle Simulator PASS; the rest hidden by `A1_BUILD` |
| 9 | Performance | not run |

### Test 4 — what the Battle Simulator route DID verify

The campaign battle path is blocked, but `TacticalBattleUI` is the same scene, so
the §9 checklist was exercised through the Battle Simulator and **passed**:

| §9 item | Result |
|---|---|
| Battle launches, map renders on Vulkan/ARM (Mali-G57, Forward Mobile) | **PASS** — graph-paper 3×3 ft grid, sectors A1-D4, labelled terrain with category badges |
| Battle Card | **PASS** — objective + "Battlefield: Wilderness — 3x3 ft" |
| p.110 deployment guide | **PASS** — all three steps rendered verbatim, including the 18" separation |
| **F2 tier gating of the drawer bar** | **PASS** — at LOG_ONLY the bar is `Crew · Enemies · Intel · Dice · Reference · ✔ Record Result` with **no Tracking**; Tracking appears only after upgrading |
| **F3 mid-battle tier change** | **PASS** — badge is a real button; chooser explains "Reducing it is not possible once the battle has started"; **Log Only greyed as current**; upgrade applied, badge `[LOG ONLY]`→`[ASSISTED]`, log line "Tracking level raised to ASSISTED.", deployment zones + per-crew "Acts 2" activation tracking appeared |
| Record Result reachable at every tier | **PASS** — present in the bar at LOG_ONLY |

Not reached: the mission drawer with a real salvage job, Record Result → the
14-step post-battle, and XP/injury/loot landing on the dashboard. All of those
need the campaign path, which T4-03 blocks.

Screenshots: `screenshots/tablet-2026-08/` (49 captures)

---

## 🔧 Fix pass 2 (Aug 8 2026, late) — T3-01 + the rest of the Turn-2 block

73/73 across 8 suites · all 5 lints CLEAN · layout sweep **168 passed / 0 failed** ·
headless `--import` parse-clean. Every fix below is detection-proven by isolated
revert unless noted.

### T3-01 — FIXED: nothing yielded to the soft keyboard, because nothing could

New autoload `src/autoload/KeyboardAvoidance.gd` (registered in `project.godot`).
`DisplayServer.virtual_keyboard_get_height()` had **zero references in `src/`**, so
there was no in-repo precedent to copy and the Godot 4.6 class reference was pulled
directly. Two facts from it shaped the design:

1. **There is no keyboard show/hide signal or notification in 4.6.** The entire API
   is `virtual_keyboard_show/hide/get_height`, and `get_height()` returns 0 while
   hidden. The only usable trigger is `Viewport.gui_focus_changed`.
2. **At the instant focus fires, the keyboard is still animating in, so the height
   still reads 0.** A handler that sampled once on focus would measure zero every
   time and silently do nothing, on every device. Hence: arm on focus, poll until
   the height is stable (two equal non-zero readings), apply once, disarm, with a
   1.5s timeout so a hardware keyboard cannot leave `_process` running forever.

Also load-bearing: `virtual_keyboard_get_height()` is in **physical** px while
Control rects are in the stretched design space, and this project's square-1080
`canvas_items`+`expand` base makes the ratio differ per orientation.
`to_logical_height()` converts; without it the scroll is wrong by the stretch factor.

`ScrollContainer.follow_focus` exists as a built-in and was set **nowhere** in the
project — but it is only half a fix, since it scrolls into the ScrollContainer's own
rect and knows nothing about the keyboard. `ensure_control_visible()` is called
explicitly instead, so no persistent scene mutation is left behind.

Pinned by `tests/unit/test_keyboard_avoidance.gd` (18 cases). Two are
detection-proven: the zero-height guard (without it every bottom-anchored field
would jump on focus, desktop included) and the DISABLED-scroll skip (handing the
shift to a scroll that cannot move is a silent no-op indistinguishable from an
unwritten fix — the exact shape of W2-03).

**Known v1 gaps, deliberate:** focus inside a separate `Window` emits on that
window's viewport rather than root, so in-dialog fields are not covered; and a field
on a page too short to scroll stays occluded, because the alternative (injecting
spacer nodes into content containers) mutates trees this codebase iterates in many
places. Both wait for a real screen to reproduce them.

### W2-02 — the p.120 cause is EXCLUDED, and a bigger bug was found underneath

**Cause (b) is ruled out by evidence, not opinion.** `clear_active_quest()` assigns
`{}`; it does not erase the key. The device save was missing `active_quest`
*entirely*, so it cannot have come from that path. Pinned so the discriminator
survives (`test_clearing_a_quest_leaves_the_key_present_but_empty`).

**Cause (a) is ruled out too.** `tests/unit/test_quest_generation_persistence.gd`
(4 cases) exercises the generation step against a real campaign with no battle or
rollover in the way: the Quest is written, the Rumors are spent (p.85), and both
survive a `to_dictionary()`/`from_dictionary()` round-trip. The component is correct.

**What the investigation did find is worse than the row it started on.**
`FiveParsecsCampaignCore.to_dictionary()` returns the LIVE containers — `"crew":
crew_data`, `"progress": progress_data`, `"equipment": equipment_data` are
references, not copies (correct for the save path, since the JSON writer only
reads). `CampaignPhaseManager._store_phase_checkpoint()` stored that as a
"snapshot", **aliasing the campaign to itself**: every later mutation wrote straight
through into the checkpoint, and `rollback_to_phase()` then assigned the same object
back.

The result was worse than having no checkpoint at all. Scalar `@var`s (credits,
`quest_rumors`, turn) DID revert because ints copy by value, while every Dictionary
silently did not — so a rollback produced an **incoherent hybrid**, e.g. a Quest
still active alongside the Rumors it was supposed to have spent. The function's own
docstring promised "every canonical owner ... in one consistent shot"; it captured
only the scalars. Fixed with `.duplicate(true)` at the checkpoint site (not in
`to_dictionary()`, which is right as it stands for saving).

⚠ **Honest status: the missing `active_quest` key on the device save is still
unexplained.** The rollback path reverts `quest_rumors` to 5 (+1 later = the
observed 6) but would have LEFT `active_quest` present, so it accounts for one half
of the evidence and not the other. This row stays OPEN pending a device repro. What
is fixed is proven; what is not, is not claimed.

### W2-02b — LATENT (not active), guarded: Back on step 1 would discard the World Phase

⚠ **Downgraded after runtime verification, and this correction matters.** The section
below was written from a code read and originally called this an active bug. Driving
the real screen showed `BackButton` is `disabled: true` whenever
`current_step == UPKEEP` (`WorldPhaseController.gd:1322`, unconditional), so the
destructive path **cannot currently be reached through the UI**. Android BACK does
not reach it either — `SceneRouter._handle_go_back()` routes to `navigate_back()`,
never to `_on_back_button_pressed()`.

So this is a loaded gun with the trigger guard on, not a fired one — worth the
confirm (one line change to `:1322` arms it, and the handler's own code plainly
intends to be reachable), but it is **NOT** an explanation for W2-02 and must not be
counted as one.


Found while investigating the above. `_on_back_button_pressed()` at step 1 called
`rollback_to_phase(TRAVEL)` inline — which is not navigation, it restores the entire
campaign from the phase-entry snapshot. Upkeep paid, crew tasks resolved, the job
taken and any Quest generated all vanish, with no confirmation and no undo. Back
from step 1 is reached by pressing Back five times from step 5.

The rollback is kept (deliberately re-doing Travel is legitimate) but now confirms,
and the dialog NAMES the completed steps that will be lost. New
`CampaignPhaseManager.has_phase_checkpoint()` lets the caller tell a harmless
navigation from a destructive undo before performing it.

### W2-04 — FIXED: "Resolve All Tasks" now asks, and names who it would burn

Same defect class as W2-02b. Gated on a pure decision seam,
`CrewTaskComponent.should_confirm_resolve_all(auto_mode, stranded_count)`, so the
gate is testable without standing up the resolution pipeline.

**The automated path is explicitly exempt, and that is not a shortcut.** Both
automated callers set `_auto_resolve_mode`, call the handler, and clear it on the
NEXT LINE — a dialog there would return immediately, the flag would be false again
by the time anyone answered, and the eventual resolution would run in interactive
mode picking different outcomes.

### W2-05 — FIXED: the page rewinds on a step change, and only then

Guarded on a step stamp rather than reset unconditionally: `_show_current_step()`
has seven call sites and none is a mid-interaction refresh today, but an
unconditional rewind would yank a player to the top the first time someone adds one.
Same shape as the W2-01 turn stamp.

⚠ Both tests needed a **4000px spacer** to be meaningful. `ScrollContainer` clamps
`scroll_vertical` to 0 when the content fits, so "scroll down, assert it rewound"
passes trivially on a bare harness whether or not the fix exists. Each test now
asserts the offset actually took before asserting what happened to it.

### W2-08 — FIXED: two non-canonical journal writes (and a third site the row missed)

`"type": "campaign"` → `"campaign_event"` at **two** sites in `JobOfferComponent`
(`:764` and `:1215`; the original row named only one). `"debt"` added to
`JournalEntryTypes.TAGS` rather than retagged — ship debt is a named Core Rules p.76
mechanic with its own interest and seizure rules, and the entry's own title is "Debt
interest", so folding it into the generic `finance` would rename a book term.

### T5-06 — FIXED: the recorded result can no longer contradict the objective

Core Rules p.89, verified against the PDF: *"To Win the battle, you must achieve the
objective (even if you are subsequently chased from the battlefield, unless the
specific mission objective states otherwise)."*

This was not only a display fault. The emitted payload carried `mission_success`
derived from the objective and `victory`/`won` derived from the dropdown, and **those
feed different post-battle consumers** — one battle, two answers. `victory` is now
derived through `BattleResultsInputForm.decide_victory()`.

"Lost" + objective achieved is corrected in the UI, since p.89 admits no reading of
it. **"Fled" is deliberately NOT rewritten** — the book explicitly preserves the win
when you are chased off, and fleeing stays its own fact (`fled_early` drives the
p.123 XP rule). A live note states what will be recorded, so the screen never
contradicts itself.

### T5-08 — FIXED: "Unknown gained 3 XP" was a producer/consumer key hole, twice

`PostBattleSequence` reads `award.get("crew_name", ...)` and
`event.get("character_name", ...)`; **neither producer ever wrote those keys.**
Fixed at the producers (`ExperienceTrainingProcessor`, `CharacterEventEffects`)
rather than at the one consumer that displayed it, because both carriers are public
signals and the next listener would hit the same hole. Both Precursor branches are
stamped, not just the first — p.17 + p.126 rolls twice and either can surface, so
stamping one would leave a 50% "Unknown" for that species specifically.

---

## 🧪 Test 7 — save/load, run on DESKTOP at tablet portrait geometry (Aug 8 2026)

Run via MCP `run_project` at 800x1280 (desktop dp equivalence). Verified after fix
pass 2: 91/91 across 12 suites, all **6** lints CLEAN, `--import` parse-clean.

### PASS — a genuinely legacy save loads clean

Loaded `campaign_2026-03-07t22-39-47_1772952171.save` (created March 2026, five
months and one enum migration ago) straight into Turn 2 / World Phase Step 1.
Credits 1695, ship debt 27, world traits, locations and the current event all
rendered. **No class-(b) abort fired** — in particular the legacy float-`origin`
trap ([[reference_legacy_save_origin_is_float]]) did not trigger on this path.

Two fixes were visible in the same screen. The full page — including
StepNavigation and the footer — is reachable now (W2-03), and `BlockerHint` reads
**"⚠ Choose 'Stay' or 'Travel' first."**, which independently re-confirms the
withdrawal of the incorrect W2-07 filing.

### T7-01 — MEDIUM — after Travel, the same card shows two different worlds

Pressing "Travel to New World (5 cr)" charged 5 credits, rolled a travel event
(85, "Uneventful Trip") and printed **"✓ Arrived: Delta II"** — while the line
directly above it still read **"Current Location: Campaign_2026-03-07T22-39-47
Prime"**, and the WORLD BRIEFING card below still showed the old world's name,
type (Desert World), danger (3), traits and locations.

The state is correct; the display is stale. Same class as W2-01, in a different
consumer. Confirmed stable across two screenshots several seconds apart, so it is
not a one-frame artifact.

### T7-02 — LOW — the starting world is named after the campaign

"Campaign_2026-03-07T22-39-47 Prime". A campaign whose name is a timestamp yields
a planet called that, in the Travel card, the World Briefing and the journal's
`location` field. Worth a generated name.

### W2-08 was ~16x bigger than filed — now fixed AND permanently guarded

Stopping the session surfaced a warning no code review had found:
`Journal entry has non-canonical type: 'travel'` from
`UpkeepPhaseComponent._report_arrival_departures()`. It only appears when that exact
branch executes, which is why one turn of real play beat a static sweep.

A proper sweep then found **17 non-canonical type uses (10 names) and 27
non-canonical tag uses (19 names)** across 29 journal sites. The original row named
two. Every one push_warning()ed on use, and the consequence was not only noise: a
non-canonical type falls to `EntryType.CUSTOM`, so the entry loses its colour and
drops out of any type-filtered journal view; a non-canonical tag renders as an
unlabelled, uncoloured chip.

⚠ **The obvious grep is wrong, and this is the reusable part.** Matching
`"type": "..."` anywhere in `src/` reported ~200 hits, almost all false — weapon,
terrain, mission, world and enemy taxonomies all use the same key name. Only dicts
passed to `create_entry()` are in scope. A lint that cries wolf 200 times gets
switched off, so narrowing mattered more than catching.

- Types remapped to canonical (`travel`/`ship`/`world`/`equipment` → `event` or
  `campaign_event`, `upkeep` → `payment`, `info` → `milestone`, the four
  character/departure variants → `character_event`).
- 19 tags added to `JournalEntryTypes.TAGS`.
- `OnboardItemUseDialog` was tagging a runtime `item_id`, which can NEVER be
  canonical — moved into the title, where it belonged.
- **New sixth lint: `scripts/lint_journal_vocabulary.py`**, detection-proven
  (re-injecting one bad type fires exactly one finding and exits 1).

### MCP methodology notes for the next session

Three things cost time here and are not written down anywhere else:

1. **`get_ui_elements` cannot see into a separate `Window`.** The Load Campaign
   dialog is one, and the call times out rather than returning an empty list —
   which reads like a hung game. Use `take_screenshot` and click by coordinate for
   modal Windows. (Also note this is exactly the case the T3-01 keyboard fix
   deliberately does not cover yet.)
2. **`get_ui_elements` rects and `take_screenshot` pixels are DIFFERENT coordinate
   spaces** — a uniform ~1.16x here, no offset. Clicking at a rect coordinate read
   off a screenshot lands on the wrong control: it selected "Travel to New World"
   when "Stay in Current Location" was intended, which silently spent 5 credits and
   advanced the campaign. Verify with a known landmark before trusting raw
   coordinates.
3. **Auto-generated `@Button@NNNN` node names are not reliable targets** for
   `click_element`, and the call reports success regardless. Use stable names
   (`NextButton`, `AutoCalculateButton`) or coordinates.

### Test 8 — BLOCKED, unchanged

`MainMenu.A1_BUILD := true` hides Bug Hunt / Planetfall / Tactics / Store, so the
other-modes smoke pass still cannot run from the menu. Confirmed at runtime: the
menu renders 8 buttons and none of them is a variant gamemode.

---

## 📱 Device confirmation sprint #2 (Aug 8 2026, evening) — Lenovo TB361FU

Build under test installed **20:44**, after every fix in pass 2 landed. Driven over
adb (`/c/Users/admin/Documents/Android/Sdk/platform-tools/adb.exe`, not on PATH).
Landscape 2560x1600 @ density 320. `DEBUGGABLE` confirmed in `dumpsys package`.

**3 of 4 PASS. The fourth failed, was root-caused on the spot, and is fixed pending
one more deploy.**

### ✅ QA Scenarios — PASS, including the export-filter risk

The **QA** button renders in the dashboard footer between Export and Edit, so the
`OS.is_debug_build()` gate behaves on a real remote-deploy build. All four fixtures
loaded from `res://data/qa_scenarios/` — **which is the export-filter proof.** That
folder is new, `lint`-invisible, and Godot's export globs match across directories
([[reference_godot_export_filter_globs_cross_directories]]); the dialog's empty-state
copy exists precisely to catch it being dropped, and it was not shown.

Applying "Rivals, Patrons + an active Quest" returned a full receipt — 9 mutations,
**zero warnings**: `turns_played 8 · credits 28 · supplies 2 · story_points 5 ·
reputation 3 · quest_rumors 3 · rivals 3 · patrons += 2 · active_quest = The Hidden
Coordinates`. The dashboard then showed Turn 9, 3 patrons and 3 rivals by name.
Both dialog controls were reachable, so the portrait-clipping fix holds too.

### ✅ W2-01 — PASS, and the QA system built the test case for free

Applying the scenario moved the campaign from turn 2 to turn 9 **without a
restart** — which is exactly the condition W2-01 describes, since the pre-fix code
built its aggregate once in `_ready()` and reused it for the whole session.

Entering the World Phase showed **Turn 9 / Gamma Prime / Imminent Invasion /
Danger 2 / Imminent Invasion [War]**, matching the dashboard's CURRENT WORLD card
exactly. The aggregate rebuilt on the turn stamp. (Ship debt also read
**43 cr (+2/turn)** — the p.76 interest ladder correctly stepping to +2 above 31.)

### ✅ W2-03 / T4-01 touch-drag scroll — PASS on hardware, with a real finger

`input swipe 1280 1200 -> 1280 500` over the content scrolled the page. Asserted by
md5 of before/after screencaps, not by eye. The Travel card scrolled away and
**Next Step, ← Back and ← Back to Dashboard all came into view** — the exact
controls that were unreachable when this was filed.

This is the half no desktop test could reach: synthetic mouse input does not go
through the OS mouse->touch emulation the ScrollContainer drag path needs.

### ❌ T3-01 soft keyboard — FAILED, root-caused, FIXED (needs deploy)

Campaign Editor, tapped **Salvage units** at y=1069 of 1600 (below the midline).
`dumpsys input_method` confirmed `mInputShown=true`, and the field was completely
buried — **the page did not move at all**.

**This is the gap v1 documented as deliberate, and it turned out to be the common
case rather than the edge case.** The editor DOES have a ScrollContainer
(`CampaignEditorScreen.gd:200`), so `find_scrollable_ancestor()` resolved fine — but
its fields occupy ~870 of 1600px, so the content already fits, the scroll range is
**zero**, and `scroll_vertical += shift` clamps straight back to 0.

**Scrolling alone can never fix this: there has to be somewhere to scroll TO.** The
fix adds headroom — a spacer appended to the scroll's content while the keyboard is
up, so the range exists. Deliberately minimal: a bare `Control`, no script,
`MOUSE_FILTER_IGNORE` (a drag starting on it must still reach the scroll — the same
defect class as W2-03), always the LAST child, reserved name, removed the moment the
keyboard closes.

Two non-obvious pieces, both pinned:
- The poller now has a **HOLDING** state. It used to disarm immediately after
  applying; it has to stay alive to notice the keyboard closing, or the spacer
  becomes permanent dead space at the bottom of a form — invisible in review,
  because it only appears after someone types.
- Focusing a **second** field must leave HOLDING, or the poller sits in its
  watch-for-close branch and never re-shifts: moving between fields on a form would
  work exactly once and then silently stop.

`tests/unit/test_keyboard_avoidance.gd` is now 25 cases. `_clear_headroom` is
detection-proven (neutering it fails exactly one test, the right one).

### Still-open findings re-confirmed on the fixed build

- **T2-06** — the World Phase step strip renders `1 2 3 4 ✓ 6`: position 5 carries a
  completion check on a fresh Turn 9 Step 1. Unchanged, still open.
- **NEW (LOW) D2-01** — after a QA scenario apply, the dashboard's primary button
  still read **"Begin Turn 2"** while every other surface read Turn 9 / Turns Done 8.
  Scoped precisely: leaving and re-entering the dashboard fixed it, so
  `_update_all()` refreshes the pills, world card, patrons and rivals but not the
  button's text.
- **NOT a T4-02 sighting.** The dashboard read "Pirate raids increase local danger
  level" before the turn and "Nothing notable happens this turn" after — but a new
  turn legitimately rolls a new event, and both surfaces then AGREED. Recorded as a
  non-finding so the next person does not re-file it.

---

# Device confirmation sprint #3 — Aug 8 2026, 22:41–23:30

Build installed **22:37:24** (`versionName=0.9.7`), Lenovo TB361FU, landscape
(`ROTATION_90`, app bounds 2560×1600, `sw800dp w1280dp h800dp`, density 320).
Driven entirely over adb. Godot `print()` does **NOT** reach logcat on a
remote-deploy build — only `ViewRootImpl` motion events appear — so every claim
below is anchored on observed state, pixel measurement, or the app's own save file,
never on a debug line.

## Verdicts on the fixes that shipped in this build

| # | Verdict | Evidence |
|---|---|---|
| **T1-01** cover alpha | **PASS** | Wordmark sits on the dark card, no plate, no white halo on the anti-aliased edges |
| **T1-03** EULA sizing | **PASS** | Text region **484 logical** tall / card **629 logical** wide vs the old `minf(250)` / `minf(360)` caps — ~14 lines legible instead of ~5 |
| **T1-04** coming-soon | **PASS 4/4** | Co-op, Bug Hunt, Tactics, Planetfall each open their own distinct blurb; dimmed via `modulate`, so they still emit `pressed` |
| **T3-01** keyboard | **PASS** | See below — measured, not eyeballed |
| **D2-01** phase refresh | **PASS** | QA apply moved SP 6→5 and patrons 3→5 **live on screen**, no rebuild |
| **W2-05** scroll rewind | **PASS** | Re-entering the World Phase returns to scroll-top |
| **T4-02** world event | **PASS (no re-roll seen)** | The one event change was a **different planet** — see T8-03 |
| **T2-06** checkpoint | **PARTIAL — cross-turn case not reached** | Same-turn restore is CORRECT (BUG-030). The stale-across-turns path was never exercised, so this is *not* a pass |

### T3-01 measured, because "it looked fine" is not evidence

Focused "Salvage units" (field bottom y=1090 of 1600). The Red Zone box moved
**863 → 592** and **918 → 646**: a **271.5 px** shift.

- correct physical→logical conversion predicts **267 px**
- skipping `to_logical_height()` predicts **632 px**

271.5 lands on the first. Back-solving the keyboard height from that shift gives
**757 physical px**, matching the ~762 px measured off a screencap in an earlier
sprint by a completely different method.

**This also settles godot#86663 for this device**: a double-counted nav bar (~115 px)
would have produced a ~437 px shift. It did not. The engine's 4.5 fix holds on the
TB361FU — which is the thing the `[KeyboardAvoidance]` debug line was supposed to
tell us and could not, because remote-deploy output never reaches logcat.

Headroom teardown is clean: diffing *before-keyboard* against *after-close* gives a
single changed region, `(37,1041)–(1250,1098)` — the focus ring on that one field.
Everything else is pixel-identical, so no residual spacer.

## NEW findings

### T8-01 (HIGH) — ship debt: the rules and every display disagree, and the editor overwrites the rules

`campaign.ship_debt` is the OWNER; `ship_data["debt"]` is a display mirror that only
`GameStateManager.set_ship_debt()` keeps in sync. That setter's docblock claims
"it is written only through this setter, so there is exactly one writer." **False** —
nine sites assign the owner directly (`ShiplessSystem.gd:139/170/183`,
`PaymentProcessor.gd:835`, `CampaignEventEffects.gd:440`, `FactionFavorService.gd:195`,
`CharacterTransferService.gd:762/766`, `CampaignFinalizationService.gd:540`).
`ShiplessSystem.gd:170` (`ship_debt += interest`) is the per-turn one, so drift compounds.

Receipts — the live device save pulled via `run-as`:

```
ship_debt (owner)   = 45
ship.debt (mirror)  = 25.0
```

and across the desktop save corpus: `fresh_repro_1786212745` owner **27** / mirror **26**
(one interest tick that never reached the display), `rollover_check_1785682109` **0/12**,
`modiphius_demo_1776380212` **0/25**, `test_both_narratives_v2` **0/36**.

Not merely cosmetic: `CampaignEditorScreen` READ the mirror (`:508`) and WRITES back
through `set_ship_debt()` (`:223`) — so touching that spinbox pushes the stale value
onto the owner and **erases the accrued interest**, and with it the distance to the
p.76 seizure threshold of 75.

**FIXED.** Editor now reads `GameStateManager.get_ship_debt()`; `ShiplessSystem` syncs
the mirror at the source via `_sync_debt_mirror()`. Pinned by 3 cases in
`tests/unit/test_tablet_qa_aug08_fixes.gd`, detection-proven (reverting the one
`_sync_debt_mirror()` call fails exactly those 3 and no others).

### T8-02 (HIGH, intermittent — NOT yet root-caused) — a turn rollover ran twice on one campaign turn

`campaign.ship_debt` went **43 → 45** across two World Phase entries with the campaign
turn unchanged (Turn 9, `turns_played` 8). The only code that increments that field is
`ShiplessSystem.gd:170`, reachable **only** via
`process_debt_interest` ← `_process_ship_debt` ← `_process_turn_rollover` ← `start_new_turn()`,
whose own docblock reads "Called once per turn at the boundary between turns."

Independently corroborated by the app's own audit trail: the World Log journal shows
**two separate "Debt interest" entries at T8**, and `_process_ship_debt()` writes exactly
one entry per execution.

Everything in `_process_turn_rollover()` re-runs with it — `_clear_upkeep_lockouts()`
(erases an earned p.76 penalty), `repair_credits_spent_this_turn` and
`busy_markets_roll_used_turn` erasure (resets the pp.73-74 per-turn spend caps),
`_process_free_hull_repair()` (p.59 free HP again), and `turn_number += 1`.

**Not reproducible on demand**: four further dashboard↔World-Phase round-trips left the
debt at 45. So it is conditional, and the earlier working theory — "every Begin Turn
press re-runs rollover" — is DISPROVEN. Hypotheses ruled out so far:

- *`_on_action_pressed()` calls `start_new_turn()`* — it does not; it only
  `navigate_to("campaign_turn_controller")`.
- *`bind_campaign()` empty-`campaign_id` guard* — `campaign_id` is populated in **all 36**
  save files on disk, and in the live device save.

Remaining lead: whatever resets `CampaignPhaseManager.current_phase` to `NONE`, since
`CampaignTurnController.gd:121-126` fires `start_new_campaign_turn()` exactly on that
condition. **Left open deliberately** — guessing at a fix here would risk the turn loop.

### T8-03 (MED) — World Phase briefing keeps describing the world you left

After "Travel to New World", the dashboard and the **persisted save** both read
`high_cost` / danger 3 / Research Station + Mining Facility, while the World Phase
step-1 briefing still read Imminent Invasion / danger 2 / Military Base + Ruins. The
travel card itself rebuilt correctly (Pay buttons re-costed 28→23), which is what made
it look healthy at a glance.

Root cause: `WorldPhaseController.gd:875` guards the aggregate rebuild on the **turn
number**. Travel changes the world *within* a turn, so the guard blocks the refresh —
a direct side effect of the fix for the earlier cross-turn staleness. The guard cannot
simply be dropped: `_fetch_campaign_data()` ends in `_initialize_components_with_data()`,
which has side effects (`JobOfferComponent._fail_expired_job` writes journal entries).

**FIXED** by subscribing to the campaign's own `world_changed` arrival chokepoint (emitted
by `initialize_world()`, the single `world_data` writer) and calling the already-live,
side-effect-free `_refresh_world_briefing()`.

This also **explains away an apparent T4-02 sighting**: the CURRENT EVENT changed
("supply glut −20% prices" → "booming trade +2 credits") because it belongs to a
*different planet*, not because one planet re-rolled. Recorded so nobody re-files it.

### T8-04 (LOW) — two different planets can share a name, and the journal joins by name

The newly generated world is also called "Gamma Prime". `_arrive_at_new_world()` calls
`generate_world(turn)` for a fresh world, so this is a name-generator collision, not a
stale field. Consequence: `CampaignJournal.get_entries_by_location(name)` joins by NAME,
so the World Log for a planet **discovered on Turn 8 with 1 visit** displayed 7 entries
including a T1 one — another planet's history. Not fixed.

### T8-05 (HIGH) — the dashboard coach-mark tour is unusable and near-inescapable

Pressing "?" on the Campaign Dashboard renders a dim overlay plus a **full-height slab
~234 logical px wide** with no readable text, no step counter and no Next/Skip. Four
taps at different points did nothing; only Android Back escaped, and that leaves the
screen entirely. **Desktop has no Back key — there it is a hard soft-lock.**

Two independent causes:

1. `show_current_step()` positioned the tooltip **before** setting its text and making
   it visible, so both placement paths measured an empty hidden panel.
2. The autowrap label had no definite wrap width. A Godot 4 `Label` with autowrap derives
   its minimum **height** from its **current** width, so it reported the height of a ~1px
   line box — measured **3640 px** for three sentences. Same trap CLAUDE.md records for
   the ship-debt row.

The slab's left edge at x=747 logical is exactly `(1728-234)/2`, i.e. `_center_tooltip()`'s
formula — so the dashboard tour is *also* taking the no-target fallback, meaning its step
target paths do not resolve (the case `TutorialOverlay.gd:147` already `push_warning`s about).

**FIXED**: content and width set before placement; `_settle_tooltip_size()` waits two
frames (one to apply the width, one for the label to re-report its height) then
`reset_size()`; `_center_tooltip()` clamps to non-negative. Pinned by 3 cases,
detection-proven live (the slab test failed at 3640 px before the fix).
**The unresolved tutorial target paths are NOT fixed** — separate work.

### T1-05 (MED) — three showcase covers were 96% white plate

Un-hiding the mode buttons for T1-04 put three previously unreachable covers on screen
for the first time. `cover_bug_hunt` / `cover_planetfall` / `cover_tactics` were each
**4229×3307 RGB at ~96% pure white**, with the artwork a ~3312×430 band floating in it —
under 10% of the canvas.

**FIXED**: cropped to content and converted to RGBA by un-premultiplying against white,
same method as `cover_standard`. Round-trip proven lossless for all three (recompositing
over white reproduces the crop with **worst channel delta 0, 0 pixels off by >2**).

*Transferable*: un-hiding a control is a content change, not just a layout change — it
can surface latent asset bugs that were never rendered before.

## Verification after the fixes

`--import` parse-clean · **69/69** cases across the 5 affected suites · all **6 lints CLEAN** ·
both new fix groups detection-proven by isolated revert.

## Method notes worth keeping

- **`run-as <pkg>` works on the debug build**, so the app's private `files/` (saves,
  `legal_consent.cfg`, `settings.cfg`) is readable and writable over adb. That is how
  first-boot was forced for T1-03 **without wiping the campaign** — delete
  `legal_consent.cfg`, relaunch, test, restore. Never use `pm clear` for this.
- **Pull the save and read it** when a screen and the campaign disagree. It settled
  T8-01 and T8-03 outright, and killed the `bind_campaign` theory for T8-02.
- **Count log entries, do not compare rolled values.** Re-roll bugs are invisible when a
  D6 repeats by chance; the journal grows by one per execution regardless.
- **A single swipe that does nothing is not a broken scroll.** A 400 ms/800 px swipe reads
  as a fling; five origins at 500 ms all reached the same end-state. Nearly filed a
  false positive.
- **A second data point disproved my own first conclusion.** "Every Begin Turn press
  re-runs rollover" fit the first observation perfectly and was wrong. Test the
  generalisation before writing it down.

---

## T8-02 ROOT-CAUSED AND FIXED — the dashboard was tearing down the live turn state

The trigger was **`CampaignDashboard._setup_phase_manager()`**, called unguarded from
`_setup_screen()` on **every** dashboard visit:

```gdscript
func _setup_phase_manager() -> void:
    if phase_manager.has_method("setup"):
        phase_manager.setup(_game_state)      # -> reset_phase_tracking() -> current_phase = NONE
    var FPC = GameEnums.FiveParcsecsCampaignPhase
    phase_manager.start_phase(FPC.SETUP)
    phase_manager.start_phase(FPC.UPKEEP)
```

`setup()` is **destructive** — it calls `reset_phase_tracking()`, which sets
`current_phase = NONE`. The asymmetry is the tell: `CampaignTurnController._ready()`
calls the very same `setup()` but **guards it** —

```gdscript
if not campaign_phase_manager.game_state:
    campaign_phase_manager.setup(game_state)
```

— precisely because it is destructive. The dashboard had no guard at all, so merely
*looking at the dashboard* reset the phase manager mid-turn.

The two `start_phase()` calls were the repair for that self-inflicted reset, and they
are not reliable: `start_phase()` returns **false and leaves `current_phase`
untouched** whenever `_can_transition_to_phase()` rejects the move. Whenever the walk
back to UPKEEP does not complete, the manager is left at **NONE** — and
`CampaignTurnController.gd:122` reads NONE as "no active phase, start a fresh turn"
and calls `start_new_campaign_turn()` → `_process_turn_rollover()`.

That is the whole mechanism, and it explains the intermittency that disproved the
first theory: the outcome depends on the transition validator's verdict, not on the
button press. Pressing "Begin Turn" is *not* what re-runs the rollover — `_on_action_pressed()`
only navigates.

### Two fixes: remove the trigger, then remove the class

1. **`CampaignDashboard._setup_phase_manager()` is now guarded** the same way the turn
   controller guards it (`and not phase_manager.game_state`), and the forced
   SETUP→UPKEEP walk moved inside that guard. The dashboard is the between-turns hub;
   it has no business re-initialising an autoload that is mid-turn. Side benefit: it
   no longer writes a SETUP and an UPKEEP `_store_phase_checkpoint()` on every visit.

2. **`_process_turn_rollover()` is now idempotent per campaign turn.** A persisted
   marker `progress_data["rollover_applied_for_turn"]` gates the whole body, so any
   *future* path that reaches `start_new_turn()` twice for one turn costs a no-op
   instead of silently double-charging the player.

   Keyed on `progress_data["turns_played"]`, **not** on `turn_number` — `turn_number`
   is incremented by `start_new_turn()` itself, so a spurious call carries a fresh
   value and would defeat the guard. Persisting the marker also means an app restart
   cannot replay a turn's rollover. Legacy saves have no key, default `-1`, so the
   first post-upgrade rollover still runs — pinned by its own test.

### Verification

3 new cases in `tests/unit/test_tablet_qa_aug08_fixes.gd`:
`..._cannot_run_twice_for_the_same_campaign_turn`, `test_the_next_campaign_turn_still_gets_its_rollover`
(the guard must gate on the turn, not latch — a permanently-latched guard would stop
charging interest for the rest of the campaign, a worse bug than the original), and
`test_a_legacy_save_without_the_marker_still_rolls_over`.

**Detection-proven precisely**: disabling ONLY the early `return` — leaving the marker
write in place, so the failure cannot come from a missing key — fails exactly one
test, the double-rollover one, and nothing else.

Full run after both fixes: `--import` clean · **94/94** across 7 suites ·
**6/6 lints CLEAN** · layout sweep **168 passed / 0 failed / 1 skipped: PASS**.

> ⚠ The layout sweep needs ~3+ minutes; `--quit-after 180` truncates it silently and
> it prints only its header. That is not a failure. A/B against a reverted change
> before concluding anything from a short run — the truncated run looks identical
> with and without your edit.

### Still open from this finding

The **two** `start_phase()` calls the dashboard was making silently no-op'd whenever
`_can_transition_to_phase()` rejected them, and nothing logged it. `start_phase()`
returns a bool that most callers discard. Worth a sweep: a rejected phase transition
should not be silent.

---

## Post-fix device verification — Aug 9 2026, build installed 00:15:38

Baseline on disk before the run: `ship_debt` **45** / `ship.debt` **25.0**,
`turns_played` 8, `rollover_applied_for_turn` **absent** (legacy save).

| Finding | Verdict | Evidence |
|---|---|---|
| **T8-01** debt owner/mirror | **CONFIRMED FIXED** | Campaign Editor reads **45** where it read 25. After the turn's one rollover the save carries owner **47** / mirror **47** — in sync for the first time |
| **T8-02** double rollover | **CONFIRMED CONTAINED** | Entry 1: 45 (no rollover). Bounce 1: 47 (the one legitimate legacy catch-up). Bounces 2, 3, 4: **47, byte-identical crops**. `rollover_applied_for_turn = 8` persisted |
| **T8-05** coach-mark slab | **CONFIRMED FIXED** | Readable bubble, `1 / 6` counter, Skip + Next inside it; advances to `2 / 6`; Skip dismisses (crew-panel brightness 17.2 dimmed → 43.2 normal) |
| **T1-05** white covers | **CONFIRMED FIXED** | Bug Hunt / Planetfall / Tactics all **0.0%** pure white in the cover region; wordmark composites onto the dark card |
| **T8-03** stale briefing | **NOT device-confirmed** | The campaign had already spent its travel decision this turn. The subscription code path *does* execute without aborting (the World Phase built cleanly on ~6 entries), but the arrival repaint itself was not exercised |

### The honest reading of T8-02

The dashboard guard did **NOT** fully close the trigger. Entry 1 declined to roll over
(phase was UPKEEP), but the first *return* to the dashboard still reached
`start_new_turn()` — which is why bounce 1 applied interest. What stopped bounces 2-4
was the **idempotency marker**, not the guard.

So the backstop is load-bearing, not belt-and-braces. Shipping only the root-cause fix
would have looked correct in code review and still leaked one rollover per session.

`turns_played` held at **8** across all five entries: `turn_number` is restored from the
save on entry, so `max(current, turn_number - 1)` cannot inflate it. The campaign turn
did not drift.

Story points moved 7 → 8 in the same window. That is the SAME single rollover
(`check_turn_earning` is at line 362, inside `_process_turn_rollover`'s 205-393 body, so
the guard covers it) and turn 9 is a 3rd turn. Not a second unguarded path — checked
rather than assumed.

### Residual, now bounded

Something still resets `current_phase` to NONE on the first return to the dashboard
after a World Phase visit, so `start_new_turn()`'s NON-rollover body still runs once per
session: `turn_number += 1`, `intro_campaign.begin_campaign_turn()`,
`story_track.begin_campaign_turn()`, `campaign_turn_started.emit()`. The rollover itself
is now inert, and `turns_played` provably does not drift, but the story/intro
`begin_campaign_turn()` calls are outside the guard and were not measured.

Lead for that: `start_phase()` returns a bool that nearly every caller discards, so a
rejected phase transition is completely silent — which is what let this hide.

### Cosmetic note

The Bug Hunt / Planetfall / Tactics cover art contains TWO lockups side by side (a small
wordmark left, the large one right). The crop preserved the full content band faithfully;
whether the small lockup should be there is an art decision, not a conversion artefact.

---

# Aug 9 2026 — runtime testing session 2 (device TB361FU, build installed 00:15:38)

## ⭐ METHODOLOGY CORRECTION: device `print()` output IS retrievable

`project.godot:73` sets `file_logging/enable_file_logging=true`, so Godot writes
`user://logs/godot.log`. On a debug build that is readable over adb:

```sh
adb shell run-as com.reptarus.fiveparsecs cat files/logs/godot.log
# incremental: tail -c +<byte_mark>   (stat -c %s to take the mark first)
```

It captures **`print()`, `push_warning()` and `push_error()` WITH FULL GDSCRIPT
BACKTRACES**. Previous sessions concluded remote-deploy output was invisible because
logcat only carries `ViewRootImpl` motion events — that half is true, but logcat is not
the only channel, and every "anchor on pixels because I can't see the print" workaround
in the Aug 8 sprint was routing around a limitation that did not exist.

It paid immediately: the log named the exact unresolved tutorial target paths
(`MarginContainer/VBoxContainer/HeaderPanel`, `.../MainScroll/MainContent/LeftColumn`)
with the `TutorialOverlay.gd:171` backtrace, and proved the legacy-save load raised
**zero** errors.

Also note `adb push` under Git Bash mangles device paths (MSYS path conversion turned
`/data/local/tmp/x` into `C:/Program Files/Git/data/local/tmp/x` and silently created a
0-byte file). Prefix with `MSYS_NO_PATHCONV=1`.

## ⚠ T9-02 — the Aug 8 T8-02 guard was a REGRESSION. Replaced.

The Aug 8 fix keyed a persisted `progress_data["rollover_applied_for_turn"]` marker on
`progress_data["turns_played"]`. Driven through the PRODUCTION wiring it fails twice:

```
turn 1: tn=1 key=0 marker_was=-1 -> RAN
turn 2: tn=2 key=0 marker_was=0  -> SKIPPED    <- legitimate rollover swallowed
turn 3: tn=3 key=1 marker_was=0  -> RAN
...
spurious re-entry re-applied p.76 interest: 21 -> 22   <- and it did not block re-entry
```

**Why the key was unusable.** `turns_played`'s only live 5PFH writer is
`CampaignTurnController._on_campaign_turn_started()` (:638) — a listener on the signal
`start_new_turn()` emits at :192, i.e. THIRTEEN LINES AFTER the guard read the key. So
the key is written downstream of its own read and lags a turn at the boundary. And it is
computed as `max(current, turn_number - 1)`, so it inherits the corruption from
`turn_number` — the exact defeat I chose `turns_played` to avoid, one call later.

> **Rule: a key computed from the corrupted value is the same bug wearing a different name.**

**Why the Aug 8 tests could not see it.** They HAND-SET `turns_played` between calls,
asserting a premise rather than the live path; the listener is a UI-layer node no unit
test connects. Those three cases are retired, with the reason recorded in place.

**Why the device looked clean on Aug 8.** Bounces 2-4 flat at 47 proved the DASHBOARD
guard worked for repeat visits, not that the marker worked. Only bounce 1 leaked.

**The replacement** (`CampaignPhaseManager.start_new_turn()`, top of function): a
session-scoped `_turn_start_in_flight` latch, released by `complete_current_turn()` and
by `bind_campaign()` on identity change. Deliberately NOT persisted — a turn ending
abnormally would latch it on disk and stop every future rollover, which is far worse than
the double-charge. Being at the TOP it also covers the two per-turn narrative hooks the
old placement missed (T9-01 below).

Pinned by `tests/unit/test_rollover_guard_key_ordering.gd` (3 cases) which wires the real
listener. **Detection-proven**: disabling ONLY the latch check fails all 3, with
`interest: 21 -> 24` and `turn_number 1 -> 4`.

## T9-01 (HIGH, was latent) — the per-turn narrative hooks sat outside the guard

`start_new_turn()` calls `intro_campaign.begin_campaign_turn()` and
`story_track.begin_campaign_turn()` AFTER `_process_turn_rollover()`, so the old guard
never covered them. All three branches of `StoryTrackSystem.begin_campaign_turn()` mutate
persistent rules state:

| Branch | Second call costs |
|---|---|
| `_check_evidence_search()` :278-297 | `evidence_search_turns += 1`, a **second D6 roll**, and on a miss `evidence_pieces += 1` — p.157 gives ONE roll per turn |
| `_check_event_7_delay()` :303-307 | `delay_turns_remaining -= 1` — burns two of the three p.159 delay turns in one turn, and if the second call zeroes it, `_complete_story_track(false, …)` **LOSES the story** on a turn the player still had |
| `pending_story_event` :166-181 | consumes the flag; the second call returns null and sets `is_story_event_turn = false`, so `start_new_turn()` opens **UPKEEP instead of STORY**, the briefing is skipped, and `get_turn_modifications()` (:190) returns `{}` so the p.153 restrictions never bind |

Latent in the tablet campaign only because `story_track_enabled = false` in the save — which
is exactly why Aug 8's "no drift observed" was not evidence of safety.

## T9-03 (MED) FIXED — Campaign Editor "Turn #" was off by one

`CampaignEditorScreen.gd:501` showed raw `turns_played` (8) labelled "Turn #", while
`CampaignDashboard.gd:513` shows `turns_played + 1` as "Turn 9". A player onboarding a
physical campaign they are on turn 9 of types 9 and lands on turn 10 — and this screen
exists FOR that onboarding. The spin now speaks the dashboard's language ("Current turn #",
min 1) and `_set_turn()` converts back with `max(0, n - 1)`.

## T9-04 (OPEN — needs a decision) — the turn phase is not persisted at all

The save's only phase field is `meta.game_phase = "active"`, a campaign LIFECYCLE marker.
The turn phase (UPKEEP/WORLD/…) is never written. So every app launch comes up at NONE and
`CampaignTurnController.gd:122` reads NONE as "start a fresh turn" — by design, per its own
comment "can't resume mid-phase".

**One spurious `start_new_turn()` per app launch is therefore STRUCTURAL**, not a dashboard
bug. The new latch cannot see it (a fresh session legitimately has no latch). Closing it
means persisting the phase and restoring it in `bind_campaign()`, which changes resume
behaviour — a turn-flow change, not a QA-sprint fix.

## T9-05 (MED, OPEN) — three difficulty vocabularies, none book-exact

`data/RulesReference/DifficultyOptions.json` (Core Rules pp.64-65) gives exactly
**Easy / Normal / Challenging / Hardcore / Insanity**.

| Source | EASY | NORMAL | INSANITY |
|---|---|---|---|
| `CampaignDashboard.gd:1799-1805` | "Story" | "Standard" | **"Nightmare"** |
| `DifficultyModifiers.gd:250` | "Story (Easy)" | "Standard (Normal)" | "Insanity" |
| Campaign Editor (observed) | — | "Normal" | — |
| Battle Simulator (observed) | — | "2 - Normal" | — |

"Nightmare" is specifically forbidden: CLAUDE.md records `DifficultyLevel.NIGHTMARE` as one
of three FABRICATED enum values kept only for save compat, "**Never expose in UI**". The map
correctly uses `INSANITY` but re-labels it with the banned word, landing it on screen anyway.
A player cross-referencing their book finds no "Standard" and no "Nightmare". Needs an SSOT
pick before fixing (four call sites, one of them already correct).

## T9-08 (MED-HIGH, OPEN) — 141 of 144 shipped textures have no VRAM compression

Measured on device: **TOTAL PSS 699 MB, of which Graphics 409 MB** (EGL mtrack 130 + GL
mtrack 279). Native heap 137 MB.

Cause, verified by unzipping `build/fpfh-0.9.7-aug06c.apk` (never trust the export globs):
only **3 of 144** shipped `.ctex` files have an `.etc2` variant. At source,
**`compress/mode=0` (Lossless) in 1724 `.import` files vs `mode=2` (VRAM Compressed) in 71.**
Modes 0/1 compress on DISK but upload to the GPU as full RGBA8; only mode 2 stays compressed
in VRAM (ETC2 on Android).

Desktop QA structurally cannot find this — an RTX 3070 never complains.

⚠ Not a free fix: ETC2 is lossy and can visibly damage UI art with sharp edges and text, and
re-importing touches ~1724 files (plus the `Assets/BookImages/` gitignore wrinkle CLAUDE.md
already warns about for exactly this change). Recommend targeting the big offenders first —
`bg_00.png` (4.48 MB ctex), `enemies_3/4.png` (2.5 MB each) — not a blanket flip.

Frame stats over a 100-frame window spanning a campaign load: 50th **7 ms**, 90th **61 ms**,
95th **85 ms**, 99th 129 ms, 10% janky. The median is healthy; the tail is not, but the
window is not steady-state so this is a lead, not a verdict.

## T9-07 (LOW, OPEN) — Load dialog timestamps are UTC, not local

Dialog showed "2026-08-09 15:13" for files the device wrote at 08:13. Device is
`America/Los_Angeles` (PDT, UTC-7). Off by exactly the offset.

## ❌ T9-06 RETRACTED — "Battle Simulator does not scroll" was a FALSE POSITIVE

I nearly filed a HIGH "unplayable in landscape". It scrolls fine; LAUNCH BATTLE is reachable.

**How the false positive happened**: I compared the pre-swipe capture against `s_bar` — taken
AFTER a scrollbar drag had scrolled back to the top. Both showed the top, so I concluded
nothing moved, while the hash sequence had already told me `base != s_panel`. I read that
signal as a focus-ring change instead of opening the image.

> **Rule: when the hashes say the screen changed, OPEN the changed screenshot before
> theorising about why it didn't.** The disconfirming evidence was in hand and I reasoned
> past it toward a memory that matched the symptom
> ([[reference_a_remembered_trap_is_a_lead_not_a_diagnosis]]).

## PASSES

| Item | Result |
|---|---|
| **Rotation (plan #6)** | **PASS.** Main menu, dashboard, Campaign Editor and Battle Simulator all reflow; live rotation mid-session reflowed the dashboard from 1-column portrait to 3-column landscape with nothing clipped. No Vulkan errors in the log across ~8 rotations. Note: with `orientation=6` (SENSOR) the app still follows a `user_rotation` lock, so adb-driven rotation testing works |
| **Legacy save on hardware (plan #7)** | **PASS.** Pushed the Apr-5 desktop save (`22222222`, schema 1, crew origins `[7.0, 5.0, 6.0, 7.0]` — floats, and a `"character": "():<Resource#…"` stringified-Object artifact). Loaded with **zero errors**; only 8 benign `auto-generated id for id-less item` migration warnings. Float origins rendered as species names (**Swift**, **Precursor**); ship, world and turn state all intact. The Jun 3 `str()` guards hold on real hardware |
| **Battle Simulator (plan #8)** | **PASS.** Launches, mission generates ("VIP Escort through Sector 4"), tier chooser renders, battle UI draws with Battle Card, pre-battle checklist, trackers. Battlefield theme "Wilderness" is one of the 4 book themes |
| **Battle Simulator crew stats** | **Checked, no finding.** `BattleSimulatorSetup.gd:81-86` ranges (combat 0-2, toughness 3-5, reactions 1-3, speed 4-5, luck 0-1) all start at the human baseline and sit inside the p.123 caps in `AdvancementSystem.stat_max_values` (6/5/6/5/8/1). Randomised-but-legal, not invented |
| **T8-01 (debt mirror)** | Still holding overnight: save carries `ship_debt 47 / ship.debt 47`, editor reads 47 |

## Verification

`--import` parse-clean · `test_rollover_guard_key_ordering` 3/3 + `test_tablet_qa_aug08_fixes`
6/6 = **9/9** · new guard detection-proven by isolated revert.

---

# Aug 9 2026 — the four open findings, FIXED

## T9-08 — 812.9 MB -> 266.9 MB of shipped-texture VRAM (-546 MB, 67%)

**First measurement was wrong and is retracted.** An initial pass read source dimensions
and reported ~2 GB. It ignored `process/size_limit`, which several imports already set.
The honest before/after is computed against the git-HEAD `.import` settings:
**812.9 MB -> 266.9 MB.**

**What was actually wrong.** Not compression, and not "too much art shipping" — the export
filter was already excluding BookImages, `_raw/`, and all but one scene directory. The APK
ships only 0-byte `.import` stubs plus 246 `.ctex` (23 MB on disk). The problem was that
imports had **no size cap**, so print-resolution masters were uploaded to the GPU whole:

| | dimensions | RGBA8 VRAM |
|---|---|---|
| `scenes/story_event_01/` ×4 (bg + 3 actors) | **6000×3375**, no cap | 77.2 MB each = **309 MB** |
| `portraits/planetfall/preset_pilot.png` | 4104×6838 (28 MP) | 107 MB |
| `figures/species/k_erin_02.png` | 4104×6838 | 107 MB |

**The fix is `process/size_limit` in the `.import`, applied to 154 files.** Non-destructive:
source art is untouched, so raising a cap later is a one-line revert plus a reimport. Caps
are the largest size the surface can actually render:

| family | cap | why |
|---|---|---|
| `assets/scenes/` | 2048 | full-screen SceneStage; landscape logical viewport is 1728×1080 and SceneStage adds a 1.04 overscan + Ken Burns zoom |
| `assets/portraits/` | 1024 | CharacterCard avatars are ≤256px square; the Planetfall preview is the largest use |
| `assets/figures/` | 1280 | full-figure actors, feet-anchored, height-scaled to at most the 1080 viewport |
| `assets/covers/` | 1600 | mode cards, ~900px wide on a 2560 screen |

Deliberately NOT touched, each for a reason:
- **`assets/sheets/`** — `SheetRenderer.gd:184` loads these as the printable sheet
  background for text overlay / PDF export. Print resolution is the point, and they load
  on demand only. Checked before assuming they were orphans.
- **`assets/scenes/*/_raw/`** — per-layer export intermediates, already excluded from
  export and never loaded. Capping them is pure diff noise (it was 273 files before this
  exclusion, 154 after).
- **`assets/BookImages/`** — already excluded from export, and the directory is gitignored
  so edits there would be invisible to review (CLAUDE.md warns about exactly this for
  exactly this kind of change).

Also **dropped `assets/backgrounds/Dec_12_escape_.jpg` from export** — zero references
repo-wide. The other two backgrounds are live: `Nov_15_cityatnight.jpg` (MainMenu.tscn),
`Nov_23_Sunset2_.png` (CaptainPanel + CrewPanel).

⚠ **VRAM compression was considered and NOT applied.** Only 3 of 144 shipped textures use
ETC2 (`compress/mode=2`); the rest decode to RGBA8. Flipping them is a further ~4× win but
ETC2 is lossy and visibly damages UI art with sharp edges and text. Capping resolution was
the change that needed no quality trade-off. If more is needed, target the photographic
backgrounds first, not a blanket flip.

Pinned by `tests/unit/test_texture_import_caps.gd`, which asserts the IMPORTED texture (not
the `.import` text, so it stays honest if settings are edited without a reimport).
**Detection-proven**: removing the cap from one file makes it report
`bg_00.png imported at 6000x3375 (cap 2048) = 77.2 MB of RGBA8 VRAM`.

## T9-04 — the turn phase is now persisted, so relaunching no longer replays a rollover

**Severity was under-rated in the previous entry and is corrected here.** It is not inert.
The turn-start latch is session-scoped, so the launch-time spurious `start_new_turn()` ran
a FULL rollover: **every time the player opened the app mid-turn they were charged another
turn of p.76 debt interest, had a p.76 upkeep lockout cleared, and had their pp.73-74 spend
caps reset.** That is the measured `ship_debt 45 -> 47` from the Aug 8 device run.

Cause: the phase was never persisted. The save's only phase field is
`meta.game_phase = "active"` — a campaign LIFECYCLE marker — so every launch came up at
NONE and `CampaignTurnController.gd:122` read NONE as "start a fresh turn".

Fix, three parts:
1. `start_phase()` mirrors `current_phase` into `progress_data["current_turn_phase"]`.
   progress_data is already serialised wholesale as the save's `"progress"` block, so no
   serialiser change was needed.
2. `complete_current_turn()` sets `current_phase = NONE`. That is the honest between-turns
   state and it is what makes the persisted phase a correct discriminator: a save written
   mid-turn restores its real phase and resumes; a save written after the turn finished
   restores NONE and correctly starts the next turn. **Without this the flag would latch**
   and the campaign would resume a finished turn forever.
3. `bind_campaign()` restores it, after `reset_phase_tracking()` and before the controller's
   phase check — it is called from `CampaignTurnController.gd:108`, the check is at :121.

⚠ **The dashboard's forced SETUP -> UPKEEP walk is GONE and must not return.** `start_phase()`
now persists, so forcing UPKEEP would overwrite the real phase of a save written mid-World-
Phase and hand the player back a turn they had part-played. `bind_campaign()` is the repair.

Legacy saves carry no key, default to NONE, keep the old behaviour on first load, and are
self-healing from the first phase transition onward.

## T9-05 — one book-exact SSOT for difficulty names, and a real bug behind it

`DifficultyModifiers.get_display_name()` is now the single source, matching
`data/RulesReference/DifficultyOptions.json` (Core Rules pp.64-65) exactly:
**Easy / Normal / Challenging / Hardcore / Insanity**. The deprecated HARD/NIGHTMARE/ELITE
members resolve to the mode they alias, so the banned "Nightmare" label can no longer reach
a player.

**`FinalPanel` was not merely mis-named — it was WRONG.** It matched a contiguous 1..5
scale, but the enum interleaves the deprecated members at HARD=3 / NIGHTMARE=5 / ELITE=7:

| picked | enum | old FinalPanel showed |
|---|---|---|
| Challenging | 4 | **"Hardcore"** |
| Hardcore | 6 | **"Standard"** (fell through) |
| Insanity | 8 | **"Standard"** (fell through) |

…on the FINAL REVIEW screen, the last thing seen before committing to a campaign.

Also **deleted `EnemyGenerator._get_difficulty_name()`** — zero callers, and it encoded a
fabricated contiguous 1..5 scale including "VETERAN", a name in neither enum file and no
data JSON.

Pinned by `tests/unit/test_difficulty_display_names.gd` (4 cases), one of which reads the
RulesReference JSON so the book data and the code cannot drift apart later.
**Detection-proven**: restoring the single "Nightmare" label fails exactly one case.

## T9-07 — Load dialog timestamps now show local time

`GameState.get_date_string()` fed a file mtime to `Time.get_datetime_dict_from_unix_time()`,
which interprets the stamp as UTC — so a save written at 08:13 local rendered as "15:13" on
a UTC-7 device. Now shifted by the system zone bias. One fix covers both the dashboard's
Load dialog and MainMenu's list (both read the same `date_string`).
(`Time.get_datetime_string_from_system()` defaults to local and needed no change — only the
`from_unix_time` family is UTC.)

## Verification

`--import` parse-clean · **6/6 lints CLEAN** · **134 test cases, 0 failures**:
20 in the four new/updated suites + 114 across the seven existing suites that touch
`CampaignPhaseManager` / `DifficultyModifiers` / debt ownership / canonical field writes.
All three new fixes detection-proven by isolated revert.

157 `.import` files changed. Confirmed the skip lists held: **no** `BookImages`, **no**
`assets/sheets/`, **no** `_raw/` file was touched.

**Not yet verified on device** — needs a redeploy. The device-observable checks are:
(1) open the app mid-turn twice and confirm ship debt does NOT move,
(2) Load dialog timestamps match the device clock,
(3) dashboard footer reads "Normal" not "Standard",
(4) `dumpsys meminfo` Graphics well below the 409 MB baseline.

---

# Aug 9 2026 (13:23-13:55) — ON-DEVICE VERIFICATION of the four fixes

Build confirmed on device before testing: `lastUpdateTime=2026-08-09 13:23:09`,
`versionName=0.9.7`, package `com.reptarus.fiveparsecs`, device TB361FU (8 GB RAM,
`Vulkan 1.3.219 - Forward Mobile - ARM Mali-G57 MC2`).

## PASS — T9-04 (turn phase persisted; no replayed rollover)

Baseline save (written by the OLD build): `turns_played 8`, `ship_debt 47`,
**no** `current_turn_phase` key, plus the now-inert Aug-8 `rollover_applied_for_turn: 8`.

| event | ship_debt | turns_played | current_turn_phase |
|---|---|---|---|
| pre-load (legacy save) | 47 | 8 | *absent* |
| after load #1 + Back | **49** | 8 | **9** (UPKEEP) |
| after load #2 + Back | **49** | 8 | 9 |
| after load #3 + Back | **49** | 8 | 9 |

Load #1 charging +2 is the DOCUMENTED legacy path: a save with no phase key restores
NONE, which `CampaignTurnController.gd:122` reads as "start a fresh turn". It is a
one-time self-heal — the key is written on the first phase transition and loads #2/#3
are then flat. Under the old build every launch added +2 (the measured Aug-8 `45 -> 47`).

Two independent confirmations the phase really round-trips: the save carries
`current_turn_phase: 9`, and the dashboard header renders **"Turn 9 — Upkeep"**.

⚠ **Guard against the false pass**: "debt unchanged" is also what a MISSED TAP looks
like. Each cycle's screenshot was checked to confirm the campaign actually loaded —
load #2's World Phase card reads `Ship debt: 49 cr`, i.e. the real post-rollover value.

Incidental: the World Phase card showed `47` on load #1 while the campaign had already
rolled to 49 — a stale card built before the rollover applied. Same shape as
[[reference_a_restart_is_a_free_ab_for_stale_snapshots]]. Cosmetic, logged not fixed.

## PASS — T9-07 (local timestamps)

Load dialog rendered `Tablet QA Run (2026-08-09 08:13)` / `22222222 (2026-08-09 08:14)`;
the on-device file mtimes are `08:13` / `08:14`. Exact match. Pre-fix these rendered as
`15:13` / `15:14` (UTC on a UTC-7 device).

## PASS — T9-05 (book-exact difficulty name)

Dashboard footer reads **`Difficulty: Normal`**. The save carries `config.difficulty = 2`
(= `GlobalEnums.DifficultyLevel.NORMAL`), so this is a real value and not the fallback —
the old local map rendered 2 as "Standard".

## ⚠ T9-08 — the FIX SHIPPED, but MY DIAGNOSIS OF THE 409 MB WAS WRONG

**The caps shipped.** Verified by pulling `base.apk` off the device and parsing the
`GST2` headers of all 144 packed `.ctex`: `bg_00.png` is now **2048x1152** (was
6000x3375) and only the three print sheets exceed 2048, exactly as designed.

**But the Graphics figure did not fall — it is ~430-449 MB against a 409 MB baseline,
because that number was never our textures.** Measured on device:

| state | GL mtrack | EGL mtrack | Native Heap |
|---|---|---|---|
| cold boot, main menu | 286.5 MB | 162.5 MB | 149.1 MB |
| campaign loaded, dashboard | **277.2 MB** (DOWN 9) | 162.5 MB | **209.8 MB** (UP 60) |
| Print Sheet, 19.4 MB texture cold-loaded and ON SCREEN | 285.4 MB | 162.5 MB | 185.3 MB |

**`GL mtrack` does not track Godot's texture uploads on this Mali driver.** Loading an
entire campaign moved it DOWN 9 MB while adding 60 MB to Native Heap; cold-loading a
2764x1843 sheet and rendering it moved it +8 MB, inside its idle drift (274-287 MB
across the session with no correlation to screen content). It is a fixed allocation of
the **Forward Mobile renderer at native 2560x1600**.

Corollary: capping textures could never have moved it, and the pre-fix 812.9 MB of
texture potential was never resident either — 409 MB of total Graphics cannot contain it.

**The caps are still worth keeping** (they cut the shipped payload, cut Native Heap, and
remove genuine 77 MB-per-layer spikes when a narrative scene loads) — they simply do not
address the number that prompted them. Do not re-derive this; `GL mtrack` is the wrong
instrument. Use `Native Heap` for art, or Godot's own
`RenderingDevice.get_driver_and_device_memory_report()`.

### The lever that WOULD move it — unmeasured, needs one redeploy

Godot 4.6 docs (`tutorials/rendering/renderers.html`): Compatibility "has a **low base
rendering cost**" vs Mobile's "**medium base**", and is "the ideal choice for ... 2D
games". Risk here is unusually low: **zero `.gdshader` files repo-wide**, zero
`ShaderMaterial` use in `src/`, no 3D nodes. Scope it to
`rendering/renderer/rendering_method.mobile` so the Steam desktop build is untouched.

⚠ Tagged **UNVERIFIED**: the docs claim a lower base *rendering* cost; that it lowers
this *memory* figure is an inference, not a measurement. One redeploy settles it.

Context on urgency: the test tablet has 8 GB (4.2 GB free), so ~700 MB TOTAL PSS is not
causing pressure *here*. It matters for the low-end phones the mobile-first pivot targets.

## N1 (NEW, process) — my `export_presets.cfg` edit was a NO-OP

`assets/backgrounds/Dec_12_escape_.jpg` is still in the APK despite being in
`exclude_filter` on disk. Every OTHER background in that list IS correctly absent, and
all those files exist — so the filter syntax is fine and the entry simply never reached
the exporter. The editor owns `export_presets.cfg` and exported from its in-memory copy.

This is exactly [[feedback_export_presets_editor_only]], which I had already written and
then violated. **Export-preset changes must be made in Project > Export in the editor
UI.** Cost here is trivial (2.4 MB ETC2) — the lesson is not.

## N2 (NEW, UX) — Back from a mid-turn World Phase lands on the MAIN MENU

Not the Campaign Dashboard. The save IS flushed correctly first (verified: file rewritten,
`current_turn_phase` present), so there is no data risk — but it skips the dashboard.

## N3 (NEW, data) — 8 id-less equipment items in the legacy save

`GameState._restore_equipment_from_campaign` (`GameState.gd:1015`) auto-generates an id
for `Military Rifle`, `Rattle Gun`, `Infantry Laser`, `Shotgun`, `Scrap Pistol`,
`Handgun`, `Beam Light`, `Snooper Bot` on EVERY load. Warning-only today; it means those
items get a fresh id each load, so anything keyed on equipment id cannot be stable across
loads for legacy saves.

## Method note

`user://logs/godot.log` rotates on launch to `godot<rotation-timestamp>.log`, so the
timestamped files hold the PREVIOUS session. Reading them in the wrong order will
misattribute events between sessions.

---

# Aug 9 2026 — SHEET / PDF EXPORT: tested for the first time, broken two ways

Prompted by a direct question ("have you tested and verified the pdf exporting?"). It had
NOT been tested on device. It is broken independently on both halves: it cannot write the
file, and the sheet it would write is 94.5% empty.

## T9-10 (HIGH, FIXED) — every FileDialog in the app fails on Android

**Measured**: Print Sheet -> Save PDF -> pick the default `/storage/emulated/0` ->
**`PDF save failed (error 13)`** (`ERR_FILE_CANT_WRITE`). No file written anywhere;
`godot.log` records NOTHING, so the only evidence is the on-screen status label.

Cause: the app requests **only `android.permission.INTERNET`** (confirmed via
`dumpsys package`) at **targetSdk 35**. Under scoped storage it cannot write to shared
storage. Godot's own `FileDialog` browses the real filesystem regardless, so it cheerfully
offers `Documents/`, `Download/`, `DCIM/` — the PICK succeeds and the WRITE fails. That
split is the worst case: the player believes they saved a file that does not exist.

**Fix (Godot 4.6 docs, `class_filedialog` + `class_displayserver`)**: set
`use_native_dialog = true`. On Android this routes to the **Storage Access Framework**,
which needs no permission — the picker returns a `content://` URI, and the docs state that
URI "can be passed directly to `FileAccess` to perform read/write operations".

⚠ Two constraints that make this a PAIR, not two independent settings:
- Native dialogs are supported on Android **only for `ACCESS_FILESYSTEM`**; with
  `ACCESS_RESOURCES`/`ACCESS_USERDATA` Godot silently falls back to the custom dialog.
  So do NOT "tidy" the access mode to something more restrictive-looking.
- The write must go through `FileAccess`. `PDF.gd:137` already does.
  `SheetRenderer.export_to_png()` used `Image.save_png(path)`, for which the docs make no
  content:// promise — changed to `save_png_to_buffer()` + `FileAccess.store_buffer()`.

**This was never print-sheet-specific.** `use_native_dialog` appeared NOWHERE in `src/`,
and all SEVEN `FileDialog` sites use `ACCESS_FILESYSTEM`, so every file interchange in the
app was broken on the target platform:

| site | purpose | mode |
|---|---|---|
| `PrintSheetScreen.gd:321` | Save Sheet as PNG | SAVE |
| `PrintSheetScreen.gd:336` | Save Sheet as PDF | SAVE |
| `CampaignDashboard.gd:1987` | Export Campaign Save | SAVE |
| `CampaignDashboard.gd:2074` | Import Campaign File | OPEN |
| `MainMenu.gd:784` | Import Campaign File | OPEN |
| `CharacterDetailsScreen.gd:1200` | Select Character Portrait | OPEN |
| `CampaignJournalScreen.gd:1320` | Attach Photo | OPEN |

All seven fixed. **Not yet re-verified on device** — needs a redeploy.

Second-order UX note: the soft keyboard opens with the dialog and covers the filename
field AND the Save/Cancel row. Same family as
[[reference_no_screen_yields_to_the_soft_keyboard]]; the native dialog replaces this
chrome entirely, so it should resolve with the fix rather than needing KeyboardAvoidance.

## T9-09 (HIGH, OPEN) — the sheet renders 154 of 163 fields BLANK

On device, with a fully-populated campaign loaded (6 crew, 23 credits, ship "Far Runner"),
every field on the Crew Log rendered empty. The **Debug overlay draws all 144 rects,
perfectly calibrated** to the printed boxes — so the manifest loads and the geometry is
right. The VALUES resolve to null.

`tests/unit/test_sheet_source_paths_resolve.gd` (NEW) runs the real
`SheetRenderer._resolve_source()` against a real `FiveParsecsCampaignCore`:
**154 of 163 sources resolve to NULL.** Only 9 render.

Cause: the manifests describe a clean VIEW-MODEL that nothing builds. They ask for
`campaign.captain` / `campaign.crew[N]` / `campaign.ship`; the real properties are
`captain_data` / `crew_data["members"]` / `ship_data`. Several names have no backing data
at all.

### ⚠ Why 28 green tests never saw it

`test_sheet_field_mapping.gd` validates JSON parse, required keys, PNG existence, unique
ids, known types, in-bounds rects, and **that `source` is non-empty** — its docblock even
claims to catch "a misspelled source path". But non-empty is not resolvable:
`campaign.captain.name` passes every one of those checks and renders nothing. Textbook
[[reference_a_green_test_can_detect_nothing]] — assert where the damage lands.

### Recommended fix: build the view-model, do not rewrite 163 hand-calibrated paths

The manifest names are good and the rects are CV-calibrated against the official PNGs;
the missing piece is a view-model builder feeding `PrintSheetScreen._build_data_context()`.
Ground truth for the mapping (read from a real device save, NOT assumed):

| manifest wants | real source |
|---|---|
| `campaign.crew[N].*` | `crew_data["members"][N]` (Dictionary) |
| `campaign.captain.*` | member with `is_captain: true` (also `captain_data`) |
| `...experience` | `experience` (NOT `xp`) |
| `...notes` | `player_notes` |
| `...weapons[0].{name,range,shots,damage,traits}` | **no `weapons` key** — `equipment` is `Array[String]`; stats need an `equipment_database.json` lookup |
| `...gear_text` | non-weapon entries of `equipment` |
| `campaign.ship.hull_current` | `ship_data["hull_points"]` |
| `campaign.ship.traits_text` | join of `ship_data["traits"]` |
| `world.danger` | `world["danger_level"]` |
| `world.traits[N]` | `world["traits"]` |

Fields with NO backing data anywhere (will legitimately stay blank, or need the model
extending): `campaign.notes`, `campaign.spent_names_text`, `campaign.story_track_label`,
`campaign.story_clock`, `ship.fuel`, `ship.upgrades_text`, `world.license_required`,
`world.turns_visited`, `world.notes`.

## Verification of what landed

`--import` parse-clean. Existing `test_sheet_renderer` (14) + `test_pdf_export_router` (7)
+ `test_sheet_field_mapping` (7) = **28/28 still pass**. The two new
`test_sheet_source_paths_resolve` cases FAIL BY DESIGN and are the T9-09 worklist — they
go green when the view-model lands.

## T9-09 — FIXED: `SheetDataContext` builds the view-model the manifests address

`src/core/export/SheetDataContext.gd` (NEW, static RefCounted) projects the campaign into
the shape the manifests were written against. `PrintSheetScreen._build_data_context()`
now delegates to it instead of handing over the raw campaign Resource.

**Fix the builder, not the manifests.** The rects are CV-calibrated against the official
Modiphius PNGs and the manifest names (`hull_current`, `danger`, `gear_text`) are the
better vocabulary. The view-model matches the manifests; do NOT drift the manifests toward
the storage shape.

Mapping, all read from a real device save rather than assumed:

| manifest | source |
|---|---|
| `campaign.crew[N].*` | `crew_data["members"]`, captain excluded |
| `campaign.captain.*` | member with `is_captain: true`; `captain_data` is the fallback |
| `...experience` / `...notes` | `experience` / `player_notes` |
| `...weapons[0].*` | `equipment` name → `data/equipment_database.json` lookup |
| `...gear_text` | equipment entries that are NOT weapons |
| `campaign.ship.hull_current` | `ship_data["hull_points"]` |
| `campaign.ship.debt` | **`campaign.ship_debt`** — the canonical owner, not the `ship_data` mirror |
| `world.danger` / `world.traits[N]` | `danger_level` / `traits`, padded to 3 printed rows |

**Weapon stats are looked up, never derived.** `equipment` is `Array[String]`, so
range/shots/damage/traits come from `equipment_database.json` (the owner per CLAUDE.md).
A non-weapon returns `{}` and routes to `gear_text` — verified on the real save: Blade /
Shotgun / Colony Rifle / Shatter Axe classify as weapons, Sonic Emitter as gear.

**Blank is a value; null is a bug.** This is a print form, so a field with no backing data
resolves to `""` (an empty box to fill by hand) and never to null — null is
indistinguishable from a typo'd source path, which is exactly how the original defect hid.
The nine genuinely-unmodelled fields are listed in `_EMPTY_UNTIL_MODELLED` with reasons
(`campaign.notes`, `spent_names_text`, `ship.upgrades_text`, `ship.fuel`,
`world.license_required`, `world.turns_visited`, `world.notes`).

### Verification

**163/163 sources now resolve** (was 9/163). `--import` parse-clean · **6/6 lints CLEAN** ·
**80/80 test cases across 11 suites**, including all 28 pre-existing sheet/PDF cases.

Five new cases in `tests/unit/test_sheet_source_paths_resolve.gd`, deliberately in two
halves — resolution-only would pass trivially if the builder returned `""` for everything,
and value-only would miss a typo in a field nobody spot-checks:
1. every manifest source resolves non-null
2. resolved values equal the campaign's ACTUAL values
3. weapon stats come from `equipment_database.json`
4. non-weapons route to gear, not the weapon row
5. an EMPTY campaign still yields a fully-resolvable blank form
   ([[reference_empty_container_is_not_absence]] — a fresh campaign IS the emptiest legal
   object, and case 5 is what caught `world.traits[0]` returning null on a traitless world)

**Detection-proven by isolated revert**: pointing ship debt at the `ship_data` mirror
instead of `campaign.ship_debt` fails exactly one assertion —
`campaign.ship.debt -> 0 (expected 49)`. The fixture omits the mirror on purpose so this
stays sharp.

⚠ Still needs a device pass: T9-10 (does the SAF picker actually write?) and a visual
check that the populated sheet lands correctly inside the printed boxes.

---

# Aug 9 2026 (15:00-16:00) — deploy #2 verification, and what it exposed

## PASS — T9-10 (Android file dialogs) VERIFIED ON DEVICE

Save PDF now opens `com.google.android.documentsui/...PickActivity` — the Android Storage
Access Framework picker (confirmed via `dumpsys activity activities`), not Godot's custom
dialog. Filename pre-filled, SAVE reachable, **and no soft keyboard covering the controls**
because the native dialog owns its own layout. A real file appeared at
`/sdcard/world_record_sheet_2026-08-09T15-09-22.pdf`, **100,292 bytes** — the error-13
failure is gone. Same fix covers the other six FileDialog sites.

## PASS — T9-04 regression check

Relaunch on the new build: `debt=49 turns_played=8 phase=9`, unchanged.

## T9-11 (HIGH, FIXED) — 144 of 144 field overlays were stranded at ZERO SIZE

The sheet was STILL blank after the T9-09 data fix, on all three tabs, with a loaded
campaign. A second, independent defect that the blank data had been hiding.

Field overlays are positioned in source-PNG pixels scaled by the renderer's OWN `size`,
baked in once at `render_sheet()` time. `PrintSheetScreen` renders during setup, when the
Control is still 0x0 — so `content_scale` is 0, every Label lands at (0,0) with size 0,
and `clip_text = true` hides it permanently.

**Why nothing looked wrong:** the background is `PRESET_FULL_RECT` so it resizes itself,
and `_draw()` recomputes the debug rects EVERY FRAME — so both the sheet art and the
calibration overlay render perfectly while all 144 values are invisible. The debug overlay
proving "the rects are calibrated" was true and irrelevant.

Fix: store each field's source rect in node meta, and re-derive geometry on `resized`.
Pinned by `test_field_nodes_are_not_stranded_at_zero_size_when_rendered_before_layout`
(measured 144/144 collapsed before the fix).

## T9-11b (HIGH, FIXED) — the export clone was SCRIPTLESS

`_render_offscreen()` called `duplicate(DUPLICATE_USE_INSTANTIATION)`. Per the Godot 4.6
docs, `duplicate(flags: int = 15)` — the flags argument **REPLACES** the default bitmask
(`SIGNALS|GROUPS|SCRIPTS|USE_INSTANTIATION`) rather than adding to it. Passing
`USE_INSTANTIATION` alone is 8, which **drops `DUPLICATE_SCRIPTS`**, so the clone came back
as a bare `Control` — and the `if clone.has_method("_set_manifest_for_export")` guard below
was therefore permanently false and skipped the handoff in total silence.

Another instance of [[reference_battle_phase_data_funnel]]'s rule: a `has_method()` guard
that can never be true is not a safety net. The `else` branch now `push_warning()`s.

Fixed with `DUPLICATE_USE_INSTANTIATION | DUPLICATE_SCRIPTS`, plus `_set_manifest_for_export`
re-adopting the duplicated overlays by their meta marker (a plain `var` is not duplicated).

## T9-12 (HIGH, FIXED) — PDF export took OVER 4 MINUTES with no feedback

Measured on device: after SAVE the app sat at **50-110% CPU for 220+ seconds** with the
file stuck at 100,292 bytes and the UI silent. Raw-byte inspection: no `xref`, no
`trailer`, no `startxref`, no `%%EOF` — the write had not finished.

Confirmed inefficiency: `PDF.gd::_addImageDictionary()` emitted the image with one
`store_8()` call per colour channel — **~40.7 million GDScript calls to write 15.3 MB**.
Patched to bulk `store_buffer()` (local patch, documented at the site — re-apply if the
addon is updated), and `PdfExportRouter` now converts to `FORMAT_RGB8` up front so the
conversion runs in Godot's C++ Image code and the writer takes its single-memcpy branch.

⚠ **Honest limit: the per-byte writer is fixed and measured, but it is NOT proven to be
the whole 4 minutes.** 749K `store_8` calls should cost seconds on mobile, not minutes.
Something else on that path — plausibly the 2764x1843 SubViewport readback on a Mali-G57 —
may dominate. Needs a device re-test with the fix in before anyone claims it is solved.

Also added, per user request: `_begin_export()` / `_end_export()` put the screen into a
working state (status text + disabled buttons) and **yield two frames first**, because
setting a Label's text does not repaint it and the export then blocks the main thread —
without the yield the "Exporting…" message only appears after the work it describes.

## T9-13 (process) — the desktop suite was testing a DIFFERENT BACKEND than ships

`PdfExportRouter` prefers GodotHaru, and desktop HAS the `PDF_DOC` GDExtension. The Android
preset **excludes `addons/godotharu/*`**, so the device runs pure-GDScript GodotPDF. Every
PDF test to date validated libharu — a fully green desktop suite could never have caught
the Android defect.

The tell was in the artifact: the desktop PDF came out **792x612pt** (11x8.5in, GodotHaru's
custom page size) while GodotPDF hardcodes **612x792**. New test
`test_the_godotpdf_backend_android_ships_writes_a_complete_pdf` calls
`_export_via_godotpdf` directly — complete PDF in **352 ms**.

**Rule: when a router picks a backend by availability, a desktop test proves nothing about
the shipping platform unless it names the backend explicitly.**

## Two wrong readings of my own test, worth recording

`PackedByteArray.get_string_from_ascii()` **stops at the first null byte**, and a PDF image
stream is full of them. I twice reported a perfectly valid desktop PDF as "TRUNCATED"
because I decoded the buffer (then just its tail) before searching for `%%EOF`. The
markers were present the whole time. Search RAW BYTES (`_bytes_contain()` in the suite);
never decode a binary payload to find a token in it.

The device file, by contrast, was genuinely incomplete — that one was searched as raw bytes
in Python, and the write was still running.

## Verification

`--import` parse-clean · **6/6 lints CLEAN** · **72/72 across 10 suites**, plus the 10-case
sheet suite. Detection proofs: ship-debt canonical read (isolated revert fails exactly one
assertion), and 144/144 zero-size overlays before the T9-11 fix.

⚠ Needs deploy #3: the sheet rendering populated values on device, PDF export wall-clock
with the bulk-write fix, and whether the export progress feedback reads correctly.

---

## Deploy #3 — Aug 9 2026, TB361FU. Both prior fixes PASS; the artifact was still wrong.

### VERIFIED PASS on device

**T9-09 + T9-11 (sheet renders real values).** Print Sheet against the loaded campaign
now shows crew, ship, credits and story points. Checked the numbers rather than the
presence of numbers: all **36 crew stats match the dashboard in the right columns**
(sheet order is Reactions|Speed|Combat|Toughness|Savvy|Luck, dashboard prints C/R/T/S/Sv/L
— e.g. Bryn Ito sheet `2 5 3 4 2 1` vs dashboard `C:3 R:2 T:4 S:5 Sv:2 L:1`). Ship
`Far Runner`, Hull `35`, Debt `49`, Credits `23`, SP `9`, Patrons `0`, Rivals `1` all
agree with the dashboard. A populated sheet with transposed columns would have looked
equally convincing, which is why this was checked value by value.

**T9-10 (Android SAF picker).** `dumpsys` again shows
`com.google.android.documentsui/...PickActivity`; the save wrote a real file.

**T9-12 (export wall-clock).** Polled the output file size from `adb` while exporting:
file created at t=0.1 s, **complete and stable at t<=2.4 s** (749,922 bytes). Was over
4 minutes with a frozen UI. The status label then read `Saved PDF: ...`, so the
completion feedback works.

**⚠ The open question from deploy #2 is now CLOSED, and the answer was not what I
guessed.** I had written that 749K `store_8` calls "should cost seconds, not minutes"
and that the SubViewport readback might dominate. It does not — the readback is part of
the same <=2.4 s. The per-byte writer WAS the whole cost.

### CORRECTION to my own deploy-#2 notes

The patch comment claimed "~40.7 MILLION GDScript calls to emit 15.3 MB". **Wrong by
~54x.** `newImage()` calls `baseImage.resize(imageSize)` *before* the writer ever sees
the data (PDF.gd:115), so the stream was 612x408x3 = **749,088 bytes and 749,088 calls**
— confirmed by the file being exactly 749,922 bytes. I had sized the stream from the
sheet's own resolution without checking whether the sheet's resolution ever reached it.
Corrected at both sites.

Why per-byte was catastrophic on Android but merely slow on desktop: the Android target
writes to a SAF `content://` stream, so each `store_8` crosses the JNI bridge. VERIFIED:
the call count and both timings. INFERRED: that the JNI crossing is the ~100x.

### The artifact was still wrong in four ways — none visible from the app

Reading the exported PDF back with PyPDF2 (`mediabox`, `/Width`, `/Filter`) found what
no screenshot could:

| ID | Defect | Evidence |
|---|---|---|
| T9-17 | **No `/MediaBox` anywhere** — page, tree or raw bytes. Required and inheritable (PDF 1.7 Table 30), so every file GodotPDF ever wrote was malformed and viewers were guessing the page size. | `PdfReader(...).pages[0].mediabox` -> `None`; 0 raw occurrences |
| T9-18 | **Every export was exactly 72 DPI.** `newImage()` treats its size argument as both the pixel size to resample to AND the point rect to paint into, and the router passed the POINT rect — so the 2764x1843 sheet was downsampled to 612x408 before embedding. A "Print Sheet" feature exporting at screen resolution. | `/Width 612 /Height 408` |
| T9-18b | Stream written **uncompressed**. Survivable only because of T9-18; at native resolution it would be a 15.3 MB PDF. | no `/Filter` on the XObject |
| T9-21 | **Page was portrait** (612x792) for a 3:2 landscape sheet, so the sheet filled a 612x408 band with 47% of the paper blank and readers opened zoomed to fit the PAPER. *(User-reported mid-session — "figure out how to properly display the pdf while vertical, could just force the horizontal display for things like docs".)* | drawn rect 612x408 in a 612x792 page |

**Fixes** (three local patches to `addons/godotpdf/PDF.gd`, all documented at their sites
with a re-apply note): `setPageSize()`; a `drawSize` argument decoupling pixel resolution
from the page rect; `/MediaBox` on the Pages node; `/FlateDecode`.

`/FlateDecode` is zlib (RFC1950), **not** raw deflate — and Godot's `COMPRESSION_DEFLATE`
is the zlib-wrapped form, so it can be handed over with no reframing. VERIFIED rather
than assumed, because guessing wrong here produces a structurally valid file that no
reader can open: Godot's output starts `0x78 0x9C` and Python's strict `zlib.decompress()`
reads it. `COMPRESSION_GZIP` (`0x1F 0x8B`) would NOT work.

**Measured after, validated by PyPDF2 on a real generated file:** page 792x612pt =
11.0 x 8.5 in LANDSCAPE, image 2764x1843 `/FlateDecode` `/DeviceRGB`, stream **decodes**
to exactly 15,282,156 bytes (= 2764*1843*3, proving the zlib framing is real), **165x
compression -> 91 KB**, **251 DPI**, sheet covers **86%** of the page (was ~53%).

### Three more manifest defects, all of the same shape

| ID | Defect |
|---|---|
| T9-14 | `ship_fuel` was mapped onto the box the artwork prints **"Event"**. `ship.fuel` is one of the deliberately-blank `_EMPTY_UNTIL_MODELLED` fields, so the mis-mapping rendered blank and stayed invisible. |
| T9-15 | The box printed **"Quest Rumors"** held `spent_names` — a field for a concept that does not exist on this sheet, also deliberately blank. The campaign had 3 rumors and the box was empty. |
| T9-20 | The view-model read `story_track.clock` and `.current_event_name`. `StoryTrackSystem.serialize()` writes **`story_clock_ticks`** and **`current_event_index`** (StoryTrackSystem.gd:405, single write site CampaignPhaseManager.gd:1859). Both fields were always "" — including on an active story track. |

**T9-20 is the T9-09 lesson recurring one level up, inside the fix for T9-09.** The
"every source resolves" test passed the whole time, because **resolving is not the same
as being right**: a source path that resolves to `""` is indistinguishable from a
correct blank. Pinned now by asserting VALUES (clock 4, event 3, title
"Disrupting the Plan", rumors 3), and by a test that checks the four story-row field ids
against the x positions of the boxes **as printed on the artwork**.

*(T9-15 also corrects my own first reading: I initially recorded the Quest Rumors box as
having no field at all. It had one — the wrong one. The new test caught it because two
fields then shared a rect.)*

### T9-16 — values printed on top of their captions

Every field box has its caption ("Name", "Weapon", "Range") printed INSIDE the top of
the box in the artwork, and the manifest rects come from box-outline detection, so they
include it. The renderer centres a value in its rect:

    crew_0_name   rect h=62, caption 30  ->  centre y=31  ==  caption bottom  -> COLLIDES
    ship_name     rect h=110, caption 31 ->  centre y=55  >>  caption bottom  -> fine

which is exactly the split seen on device — names, species, weapon names and the
Range/Shots/Damage numbers collided while ship name, crew name and the stat numbers
looked fine. Fixed by measuring the caption band per field from the artwork
(`scripts/bake_sheet_label_insets.py`, re-runnable, `--check` mode for CI) and baking
`label_inset` into the manifests. Tight distribution across 144 fields: 25-26px on 74,
30-31px on 60.

**The debug overlay was actively misleading here** and has been fixed too. It drew the
manifest box only, so during deploy #2 it showed a perfectly calibrated grid at the same
moment every field node was 0x0 and every value invisible. It now draws the box faint
and the actual value region solid. *An overlay that does not draw what the renderer
draws is decoration, not instrumentation.*

### Also fixed

- **T9-19** — the status read the raw `content://com.android.externalstorage.documents/
  document/primary%3Acrew_log_...` URI wrapped over five lines. Shows the filename now.
- **T9-21b** — `src/ui/components/base/OrientationLock.gd` holds the sheet screen in
  `SENSOR_LANDSCAPE` on device (either way up, never portrait) and restores on
  `_exit_tree()`. The sheets are fixed-aspect DOCUMENTS, not layouts — there is nothing
  to reflow in portrait, so the orientation is the fix. Inert on desktop
  (`FEATURE_ORIENTATION` is false), so it is safe to wire unconditionally.

### Verification

`--headless --import` parse clean; **6/6 lints CLEAN**; `bake_sheet_label_insets --check`
in sync; **36/36 tests** across `test_pdf_export_router`, `test_sheet_renderer`,
`test_sheet_source_paths_resolve` (12), `test_orientation_lock` (3).

Three detection proofs by isolated revert, each producing only its own failures:
reverting `drawSize` -> exactly 2 failures (`/Width`, `/Height`); reverting the story
clock key -> exactly 1; and the manifest-id test caught the `spent_names` collision
live, before I knew it existed.

⚠ **Needs deploy #4:** captions clear of their values on the real screen, the sheet
screen holding landscape on device, and an exported PDF pulled off the tablet to confirm
the landscape/DPI/compression fixes survive the SAF path.

---

## Aug 9 2026 (later) — sweeping the remaining open rows. One was data corruption.

Went through the open items rather than the newest ones. The two rows filed as low-severity
UX/warning notes turned out to be sitting on top of the worst defect of the day.

### T9-23 (HIGH, data corruption, FIXED) — legacy saves DOUBLE the stash on load

Found by pulling the device's own legacy save (`22222222_1775243767.save`) and simulating
the load path against it, while chasing the harmless-looking N3 warning.

`equipment_data` on that save carries the same 8 items under THREE keys — `equipment`,
`gear` and `items` — left behind when `CampaignFinalizationService` folded the split
format into the flat list without erasing the source keys. The load heal unions
`equipment + weapons + armor + gear` and deduped by id, with this carve-out:

```gdscript
if sid.is_empty():
    # id-less items are always unique originals: the duplication bugs
    # only ever copied items that already HAD ids.
    deduped_stash.append(stash_item)
```

**That premise is false, and the device's own save falsifies it.** Measured: the 8 id-less
entries in `equipment` are BYTE-IDENTICAL to the 8 in `gear`, so the union produced 16 and
every one was waved through as a "unique original":

```
raw=21 -> deduped=19
names appearing more than once: {Military Rifle: 2, Rattle Gun: 2, Infantry Laser: 2,
                                 Shotgun: 2, Scrap Pistol: 2, Handgun: 2,
                                 Beam Light: 2, Snooper Bot: 2}
```

And it does not stay recoverable. The rehydrate immediately below generates an id per item
from `name + ticks + randi`, so the 16 copies each get a DIFFERENT id. **One save later the
doubling is baked in and no id-based dedup can ever see it again.** Load a legacy campaign,
press Save, silently own twice the gear.

**Fix**: dedup id-less items by CONTENT, but only ACROSS source keys. Two identical id-less
items inside `equipment` are two real items (two looted Handguns); the same item echoed in
`gear` is the un-erased split-format copy. Both directions are pinned, and the second test
is the one that stops the fix from becoming a different bug.

⚠ **The transferable bit: the comment stated its own assumption, and the assumption was
checkable.** "id-less items are always unique originals" was a claim about the data, sitting
one `adb pull` away from being tested against real data. A load-path carve-out justified by a
belief about what old saves look like should be run against an actual old save.

### N3 (CLOSED, benign) — id regeneration is not itself a bug

The warning fires because the auto-generated id is written to the live dict but that dict is
only persisted if something later SAVES. A legacy save loaded for testing and never re-saved
regenerates every time, correctly. `Character.equipment` stores item NAMES (the heal right
below converts id-strings back to names), so nothing persistent is keyed on the id. Benign —
but chasing it is what surfaced T9-23, which was not.

### N1 (FIXED) — the tutorial coach marks resolve nothing, and the paths were never wrong

Device log named `MarginContainer/VBoxContainer/HeaderPanel` as unresolved in scene
`CampaignDashboard`. **That exact path DOES exist in `CampaignDashboard.tscn`** — verified
line by line, and all 10 targets across both tutorials exist in their scenes.

The scene file was never the problem. The live tree is:

- `ShortScreenScroll.setup(column, pinned)` (CampaignDashboard.gd:93) MOVES every child
  after the pinned ones into a runtime-created `ContentScroll/ScrollColumn`
- `_setup_adaptive_panels()` moves the three info columns into an `AdaptivePanelGroup`
- the app bar is moved to index 0, changing which child is "first"

so `.../VBoxContainer/HeaderPanel` really is `.../VBoxContainer/ContentScroll/ScrollColumn/HeaderPanel`
by the time the tour runs. **An absolute node path is not a stable address in this app.**
These paths have now broken TWICE — once when the screens gained scroll containers, again
when they gained the short-screen scroll — and both times silently, because the no-target
branch renders a centred tooltip, which is the CORRECT output for the deliberately
target-less welcome step. A broken coach mark and a working welcome step look identical.

**Fix**: try the authored path (exact, free when it works), then fall back to searching by
LEAF NAME anywhere in the scene. Node names survive reparenting; paths do not.

⚠ `find_child(pattern, recursive, owned)` — **`owned` MUST be false**. It defaults to true,
which only matches nodes with an `owner`, and the nodes doing the reparenting here are
created at runtime with none. Probed against this engine build before relying on it: with
`owned=true` the same search returns null. That default would have shipped a fix that
changed nothing.

### T9-22 (FIXED) — a second weapon vanished from the printed sheet

From the same device save: Nyx Ward carries a Shotgun AND a Colony Rifle. The sheet printed
the Shotgun and left Gear empty. `_build_character()` collected every weapon into `weapons[]`
while the manifest addresses `weapons[0]` only — and extras could not reach Gear either,
because the gear branch only ever saw NON-weapons. Extras now overflow into Gear: a printed
record that silently loses an item is worse than one that files it in a less specific box.

*(Also checked and NOT a bug: Sonic Emitter is `type: Utility Device` in
`equipment_database.json`, so routing it to Gear was correct. Finn Mendez's blank weapon row
is correct — his equipment list is genuinely empty in the save.)*

### N2 (does NOT reproduce; fallback hardened anyway)

Re-driven on device: Dashboard -> Begin Turn 9 -> World Phase step 1 -> Android BACK
correctly returned to the **Campaign Dashboard**. Nobody navigates to the `world_phase`
scene at all (it is instantiated inside the TurnController), so `current_scene` is
`campaign_turn_controller` and the history holds `campaign_dashboard`.

The route that emptied the history on Aug 8 is still unidentified. Rather than leave an
unreproducible symptom open, the fallback itself is now correct for every route:
`navigate_back()` with empty history returns to the campaign dashboard when a campaign is
loaded, and the main menu otherwise. History CAN legitimately run dry — `clear_history()` on
new-campaign and return-to-menu, `max_history_size` trimming, no consecutive duplicates — so
this is a real fallback, not a should-never-happen.

### Mobile renderer — investigated, recommending NO change right now

VERIFIED: `project.godot` sets no renderer at all (both are at Godot defaults; the device
reports Forward Mobile). VERIFIED: **zero `.gdshader` files and zero `ShaderMaterial` uses**
repo-wide — the three `shader_type` hits are inside the `shader_library` addon's own editor
UI source, not shaders in use. So the "near-zero risk" half of the claim holds.

But the benefit is still unmeasured, and there is now a specific reason not to bundle it:
the compatibility (GLES3) renderer has documented trouble with large SubViewports —
[godot#103181](https://github.com/godotengine/godot/issues/103181) (SubViewport size is not
checked against the GPU's max texture size; oversized ones fail with "internal FrameBuffer
not ready" on gl_compatibility) and
[godot#75877](https://github.com/godotengine/godot/issues/75877) (`get_texture().get_image()`
stutters). **The sheet export renders a 2764x1843 SubViewport and reads it back** — the exact
pattern, in the feature that was just fixed and still needs device verification.

Recommendation: keep Forward Mobile for deploy #4. If the renderer is worth revisiting it
should be its OWN deploy with a before/after measurement and the sheet export re-tested
specifically — not folded into a deploy whose purpose is verifying that export. The relevant
number, from the earlier GL-mtrack work, is Forward Mobile's ~274-287 MB FIXED graphics
allocation; whether that matters depends on the minimum target device, which is a product
decision rather than a code one.

### Verification

`--headless --import` parse clean; **6/6 lints CLEAN**; **56/56 tests** across 7 suites
(`test_sheet_source_paths_resolve` 14, `test_sheet_renderer`, `test_pdf_export_router`,
`test_orientation_lock` 3, `test_tutorial_targets_resolve` 3, `test_equipment_persistence` 9,
`test_android_back_button` 7).

Detection proofs by isolated revert, each producing ONLY its own failures: the stash-doubling
dedup (2 failures naming all four doubled items, while the "two real Handguns" test correctly
stayed green), and the tutorial name-search fallback (1 failure). Earlier in the day: the PDF
`drawSize` (2) and the story clock key (1).

⚠ **Deploy #4 should verify:** the landscape sheet screen and caption clearance, an exported
PDF pulled off the tablet, the tutorial coach marks actually highlighting their targets, and
the legacy save's stash count staying at 13 across load-save-load.

---

## OPEN — sheet field alignment needs a typesetting pass (noted Aug 9 2026)

Raised by the user after seeing the deploy-#3 sheet: *"we will need to fine tune the text
boxes in the pdf export so that they line up a little better when generated."*

`label_inset` (T9-16) fixed the BLOCKING defect — values printed on top of their captions —
but it is clearance, not typesetting. It gets the text out of the way; it does not make the
form look set. What is still rough, measured against the current manifests:

| Axis | State |
|---|---|
| Horizontal padding | **None at all.** 55 of 144 crew-log fields are `align: left` and their text starts flush on the box's border stroke, touching the printed line. |
| Vertical placement | The value is CENTRED in whatever is left after the inset. On a paper form a written value sits on a line low in the box; centring floats it, and the taller the box the more it floats. |
| Baseline consistency | Nothing shares a baseline across a row. The weapon line mixes a left 18-22pt name with centred Range/Shots/Damage numbers at a different size — the manifest uses **7 distinct font sizes** (18/20/22/24/28/36/42). |
| The inset constant | The `+2px` breathing room added to the measured caption band is a value I chose, not one that was tuned. |

Not started; recording the axes so the next pass does not begin from a blank page. The
alignment code lives in `SheetRenderer._field_src_rect()` / `_build_field_node()` and the
measured geometry in `scripts/bake_sheet_label_insets.py`; both now carry this note at the
site.

⚠ **Whatever the fix is, MEASURE IT ON THE GENERATED 2764x1843 ARTIFACT, not the on-screen
preview.** The preview renders at roughly 0.6x, which hides several px of drift — the same
blind spot that let 144 zero-size overlays and a 72 DPI export both pass review on the same
screen that looked fine. Export a PNG, crop a row at full resolution, and look at it.

---

## Aug 9 2026 — the alignment pass. It was not an alignment problem.

Started as the typesetting note above. Rendering the sheet at source resolution and
MEASURING it found a correctness defect underneath: **values were printing under the
wrong column headings**.

Method: `tests/tools/emit_sheet_png.gd` renders the Crew Log at 2764x1843 with a
realistic campaign (run WITHOUT `--headless`, per docs/sop/visual-runtime-verification.md),
then the ink is measured against the artwork's own geometry in Python. Nothing below was
judged by eye on the preview — the preview renders at ~0.6x and hides all of it.

### What the artwork actually specifies (measured, not assumed)

Reading the ink profile across a caption band gives `2 2 1 0 0 0 0 10 18 12 ...`:
the box's border stroke owns columns 0-2, then four clear columns, then the caption's
first glyph at **+7**. So 7px is the artwork's OWN left inset.

Every field box is closed by a **writing rule** — the line you would write on with a pen.
It is NOT a fixed distance below the manifest rect: measured across 144 fields it is +3
to +17, mostly +16 and +9. And the weapon block's horizontal rules sit at exactly
+78 / +153 / +221 in every crew block: table top, row separator, table bottom.

### T9-24 (HIGH, correctness, FIXED) — 48 fields printed under the wrong caption

**48 of 144 fields had a rect that SPANS a printed column divider**, uniformly shifted
~50-68px right of their cell. The CV extractor found *boxes*, but inside the crew block
the boxes are multi-column tables, and it never split them.

A centred value in a rect shifted half a cell right prints under the NEXT caption. In the
test render, Blade's Range / Shots / Damage appeared under the headings **"Shots",
"Damage" and "Traits"** — a printed sheet that makes a reader misread the weapon. Nothing
was null, nothing was blank, and every source resolved. This is not polish.

### T9-25 (FIXED) — the sheet has TWO weapon slots per character, and 5 of 10 were unused

The weapon block is ONE box with five columns (Weapon | Range | Shots | Damage | Traits)
and **two writing rows** under a single set of captions. The manifest addressed slot 1
only, and parked `weapon_traits` in row 2 spanning the first four columns instead of in
row 1's Traits column.

⚠ **This makes yesterday's T9-22 fix wrong.** I had routed a second weapon into Gear
because "the printed sheet has one weapon line". It has two. A weapon belongs in a weapon
slot with its Range/Shots/Damage under the right captions; Gear is now the overflow for
weapon THREE onward. `SheetDataContext.WEAPON_SLOTS = 2`, both slots always resolve
(blank rows are correct output for an empty slot).

*The lesson: I inferred the sheet's structure from the manifest instead of from the
artwork the manifest describes. The manifest was the thing that was wrong.*

### The fixes

| Change | Where |
|---|---|
| `scripts/recalibrate_crew_log_rows.py` — re-derives every per-character rect from the printed dividers, and adds the 40 missing weapon-slot-2 fields (144 -> 184 fields) | new, `--check` for CI |
| `label_inset` + `rule_offset` baked per field from the artwork | `scripts/bake_sheet_label_insets.py` |
| `FIELD_PAD_X = 7` — measured, not chosen | `SheetRenderer` |
| Values BOTTOM-aligned to just above their writing rule, instead of centred in the box | `SheetRenderer._field_src_rect` / `_build_field_node` |
| Row 2's y/height corrected 144/74 -> 155/66 (the old values put it 9px ABOVE the separator, overlapping row 1's text) | recalibrate script |

### Measured before -> after, on the rendered 2764x1843 artifact

| Metric | Before | After |
|---|---|---|
| Fields spanning a printed divider | **48 of 144** | **0 of 184** |
| Gap from value to its writing rule | 4..34 px (spread **30**) | 7..15 px (spread **8**), median 13 |
| Left-aligned text start | 0..4 px — **on the border stroke** | 7..11 px, aligned to the caption |
| Fields clipping at a box edge | — | **0** |
| Weapon slots populated | 1 of 2 | 2 of 2 |

The residual 7-8px readings are DESCENDERS ("Bryn Ito", "Tablet QA Run"), which is correct
typography, not drift. The 8 fields outside the band are all `multiline_text`, which
correctly flows from the TOP of its box.

### The regression guard

`test_no_field_rect_spans_a_printed_column_divider` loads each sheet's artwork and fails
if any rect contains a full-height cyan rule. **Detection-proven**: restoring the
pre-recalibration manifest produces exactly one failure naming all 48 offenders.

⚠ It immediately found the same defect in the other two sheets — **2 fields in
`encounter_log_fields.json` and 3 in `world_record_sheet_fields.json`**. Those manifests
are STARTER geometry (10 and 9 fields, hand-typed round-number rects like
`[200, 80, 1200, 80]`), exactly as docs/sop/sheet-export.md describes them; they were
never run through the extractor. Pre-existing, not a regression, and NOT fixed here — the
test ratchets them at their current counts so new drift fails while the honest number
stays in the failure message. **Those two sheets still need a calibration pass of their
own.**

### Verification

`--headless --import` parse clean; **6/6 lints CLEAN**; both geometry scripts report
IN SYNC under `--check`; **65/65 tests** across 8 suites.

---

## Aug 9 2026 — the PDF read back as a DOCUMENT, not as a picture

The alignment pass above fixed what the sheet SAYS. This pass asked what the PDF
*is*: opened both backends' output with PyPDF2 and inspected /Info, /MediaBox,
the placement matrix, the image dictionary and the content stream.

**The first thing it found was that I had been auditing the wrong backend.**
`PdfExportRouter.best_available_backend()` returns `godotharu` on desktop and
`godotpdf` on Android — `addons/godotharu/*.gdextension` declares only
`linux.x86_64` and `windows.x86_64`, no Android binary. So every desktop probe
of the default path measures a backend the tablet never runs, and vice versa.
`tests/tools/emit_sheet_pdf.gd` now emits BOTH on purpose.

### T9-26 (HIGH, correctness, FIXED) — the desktop export stretched the sheet 15.9%

`_export_via_godotharu` drew `draw_image(img, 0, 0, page_w, page_h)` under a
comment claiming "no letterbox — we sized the page to match the sheet". The page
is US Letter landscape (792x612 = 1.294:1); the sheet is 2764x1843 (1.4998:1).
They have never matched.

Measured on the artifact: **DPI 251 x 217**, against a correct 251 x 251 from the
mobile path, which had the letterbox math inline. Every circle printed as an oval
and every glyph was 16% too tall — and nothing at the call site, in the logs, or
on screen showed it. Only reading the placement matrix out of the file did.

Fix: both backends now call the shared `PdfExportRouter._fit_rect()`. Two
implementations of one behaviour WILL diverge; the divergence lives in the
output, so it has to be a shared function plus an artifact check.

### T9-27 (MEDIUM-HIGH, FIXED) — every exported PDF was titled "Test", by "Nolan"

`addons/godotpdf/PDF.gd` ignored `newPDF()`, `setTitle()` and `setCreator()`
entirely and hardcoded `_addInfo("Test", "Nolan")` — the upstream author's own
test values. Confirmed on a fresh export before the fix by reading /Info back.

Not cosmetic. /Info /Title is what a PDF reader shows in its title bar, what
Chrome shows in the browser TAB, and what a file manager or archive tool indexes.
A player mailing their crew sheet was mailing a file called "Test" credited to a
stranger. Now writes the real title/creator, plus /Producer and /CreationDate
(and /Author, /Subject, /Keywords on the libharu path, which supports them).

### T9-28 (HIGH, data-corruption, FIXED) — a crew name with a paren wrote an unopenable file

GodotPDF concatenated label text straight into `(text) Tj` with no escaping. One
unbalanced `)` terminates the PDF string early and the remainder parses as
operators. "Vance (Doc) Ryu" is a legal crew name and is enough to do it.

⚠ **And `pdf.export()` still returned `true`, so the exporter reported OK.** A
success that isn't — the same class as the 94.5%-blank sheet.

Proven by isolated revert: with escaping off, PyPDF2 refuses the file outright
("Stream has ended unexpectedly"); with it on, all 8 hostile strings
round-trip byte-exact through BOTH backends.

⚠ The two backends need OPPOSITE treatment, and `docs/sop/sheet-export.md`
recorded it wrong ("GodotHaru handles this internally … Sprint 3 must pre-escape
at the SheetRenderer layer" — those clauses contradict each other). libharu
escapes internally, so pre-escaping DOUBLE-escapes. Escaping belongs at the point
the string enters the content stream, and only GodotPDF needs it there.

### T9-29 (FIXED) — the PDF is now SEARCHABLE, with the picture unchanged

0 characters of extractable text before; 322-325 now, covering 15/15 of the
values a player would search for. The sheet is still the same raster — the text
is an INVISIBLE layer (`3 Tr`), the technique a scanner's OCR layer uses.

This replaces the "Sprint 3 native text overlay" plan (est. 11-13h), which would
have re-typeset every field as VISIBLE PDF text and so needed the PDF's
typesetter to agree with Godot's on font, wrap and alignment — three ways for the
printed page to stop matching the app. Mode 3 needs none of that, which is also
why GodotPDF's missing `text_width` stopped being a blocker: an estimate moves
the selection highlight, never a printed glyph.

**The load-bearing decision is where the layer comes from.**
`_collect_text_layer()` reads the nodes the SubViewport actually rasterized, not
a second pass over the manifest — two producers for one fact is how a layer ends
up asserting a value the picture no longer shows. Blank mode yields an EMPTY
layer: "print blank to fill by hand" must not ship a hidden copy of the data.

Cost: +0.5% / +1.1% file size. Structurally verified — exactly one `Tr` mode in
each file, value `3`, set before all 90 `Tj`.

### T9-30 (MEDIUM, FIXED) — the sheet printed storage ids, not species names

The Species column read `kerin`, `genetic_uplift`, `de_converted`.
`data/character_species.json` carries a `name` for all 28 ids and
`SpeciesDataService.get_species()` already resolved it; the view-model just
passed the raw id through.

⚠ Do NOT "simplify" the lookup into string formatting. Three of the 28 come out
wrong: `kerin` -> "Kerin" (book: **K'Erin**), `de_converted` -> "De Converted"
(book: **De-converted**), `primitive_character` -> "Primitive Character" (book:
**Primitive**). The test uses exactly those three so it cannot pass by accident.

(Also learned: Godot's `String.capitalize()` is a snake_case humaniser. Feeding
it an already-space-separated string returns `"Not aA rReal sSpecies"`. Hand it
the raw id.)

### Measured, before -> after (both backends, read back with PyPDF2)

| | libharu before | libharu after | GodotPDF before | GodotPDF after |
|---|---|---|---|---|
| DPI | **251 x 217** | 251 x 251 | 251 x 251 | 251 x 251 |
| draw rect | 792x612 @ (0,0) | 792x528 @ (0,42) | 792x528 @ (0,42) | 792x528 @ (0,42) |
| /Title | ok | ok | **"Test"** | ok |
| /Creator | ok | ok | **"Nolan"** | ok |
| /CreationDate | absent | present | absent | present |
| extractable text | **0 chars** | 322 | **0 chars** | 325 |
| hostile name | corrupt file, err=0 | round-trips | corrupt file, err=0 | round-trips |
| size | 223,255 B | 224,360 B | 223,109 B | 225,669 B |

### Measured and deliberately NOT done (so nobody re-derives them)

- **PNG predictors HURT here** — Sub +8.4%, Average +30.8%, Up -4.8%, all worse
  than plain deflate. The sheet is 80.6% flat white + 10.9% flat #EBEBEB, so
  LZ77 already matches those runs and a predictor destroys the run structure.
- **/Indexed 8-bit is lossy** for ~13k px (1,342 distinct colours, top 256 cover
  99.75%) — all of it glyph antialiasing. Fringing to save 150KB is a bad trade.
- **deflate level 9** would save 9.2%, but Godot's `compress()` exposes no level.
- **Higher render DPI gains nothing** — the artwork is natively 251 DPI at 11in.
- **The 10.9% grey is IN THE ARTWORK** (10.85% source vs 10.86% render), not
  added by the exporter.

### Verification

`--headless --import` parse clean; **6/6 lints CLEAN** and `lint_orphan_assets`
`orphans=0`; **102/102 tests across 9 suites**; **5 isolated-revert detection
proofs** (letterbox / metadata / escaping / invisible-mode / species), each
naming the specific test that caught it; both artifacts re-read with PyPDF2.

⚠ One methodology note worth keeping: the detection-proof script initially had no
`finally:` restore, so an exception left an INJECTED BUG in the working tree. The
next test run then looked like flaky non-determinism rather than what it was.
Any script that mutates source to prove a test must restore in a `finally`.

⚠ **Deploy #4 should verify on device:** the landscape sheet screen, an exported
PDF pulled off the tablet and opened (check the tab title now reads the campaign
export, not "Test", and that Ctrl+F finds a crew name), the corrected column
alignment, the tutorial coach marks, and the legacy save's stash staying at 13.

---

## Aug 9 2026 — a docs pass over the same export. Two fixes, two anti-recommendations.

Went back over the PDF path against the Godot 4.6 class reference, the libharu
GDExtension's own method list, and the sheet's `.import` sidecar, specifically to
test the claims I had asserted rather than measured.

### T9-31 (FIXED, perf) — the C++ backend was slower than the GDScript one, and PNG was why

The desktop export benchmarked **215 ms against GodotPDF's 65 ms**. A C++ backend
losing to pure GDScript by 3x is not a plausible steady state, and I had let it
pass without comment in the previous section. It wasn't the PDF work — it was the
handoff:

`img.save_png_to_buffer()` -> `load_png_image_from_mem()` means **Godot
PNG-ENCODES 15 MB -> libharu PNG-DECODES it -> libharu re-compresses it with
flate.** The encode and the decode are both pure waste; the PDF never contains a
PNG at any point.

MEASURED: `save_png_to_buffer()` on a 2764x1843 RGB8 image = **~84 ms**;
`get_data()` = **~0 ms** (it hands back the buffer that already exists).

`load_raw_image_from_mem(buf, w, h, color_space, bpc)` was in the extension's
method list the whole time. Switched to it (color space 1 = HPDF_CS_DEVICE_RGB),
with the PNG path kept as a fallback for an older GodotHaru. **215 -> 141 ms.**

⚠ Verified BEYOND the byte count, because a wrong colour space gives an identical
LENGTH: inflated both backends' image streams and compared — **identical
SHA256**, `#5CBADE` intact (low red / high blue, so no BGR swap). Stream is still
`/FlateDecode`; `set_compression_mode(0x0F)` includes HPDF_COMP_IMAGE.

### T9-32 (FIXED, print correctness) — the sheet's ink sat inside the unprintable border

The page fit the sheet edge-to-edge across the full 792pt width. Measuring the
ARTWORK's ink bbox (x 46..2703 of 2764) and projecting it onto the page:

| edge | clear paper, before |
|---|---|
| left | **0.183 in** |
| right | 0.239 in |
| top / bottom | 0.83 / 0.81 in |

A consumer printer's unprintable border is typically ~0.25in, so printing at
"Actual size" **clipped the outer box borders off the form**. It survived only
because most print dialogs default to shrink-to-fit — the default was silently
rescuing the output, which is why nobody saw it.

`_fit_rect()` now insets `PRINT_MARGIN_PT = 18` (0.25in) per side: **756x504pt at
(18, 54)**, clearances 0.425 / 0.478 / 0.985 / 0.970 in. And because the same
2764 px now span 10.5in rather than 11in, **DPI goes UP: 251 -> 263.**

### ⛔ Two things the docs suggested that MEASUREMENT then vetoed

1. **`/ViewerPreferences /PrintScaling /None`.** The textbook flag for a form
   that must print at true scale. **Do not add it** — forcing 100% is exactly
   what triggers the clipping in T9-32. The shrink-to-fit default is the thing
   that was protecting the output. A spec-correct flag can be the wrong flag.
2. **ProjectSettings `compression/formats/zlib/compression_level`.** The obvious
   route to the 9.2% deflate saving noted earlier. TESTED: set it to 9, confirmed
   `ProjectSettings.get_setting()` reads back `9`, and
   `compress(COMPRESSION_DEFLATE)` returned a **byte-identical 17,937**. The 4.6
   docs say it affects "compressed scenes and resources", and that is literally
   all it affects. So the earlier claim ("no level available") was right, and is
   now right *for a checked reason*.
   (First attempt read back `-1` because I put the key under `[rendering]` —
   Godot's section is the part BEFORE the first `/`. Nearly concluded "the
   setting does nothing" from a botched test.)

### Also checked, nothing wrong

- `crew_log.png.import` is `compress/mode=0` (Lossless), `"vram_texture": false`
  — the print sheet is NOT carrying block-compression artifacts. ⚠ Worth knowing
  `detect_3d/compress_to=1` would flip it if the texture were ever used in a 3D
  material; it never is, but that is the one edit that would silently degrade
  print output.
- `COMPRESSION_ZSTD` compresses this data **5x better** than deflate (3,532 vs
  17,937 on the probe) — and is unusable, because PDF has no zstd filter. The
  `/Filter` set is Flate / LZW / RunLength / DCT / JPX / CCITT / JBIG2.

### Verification

`--headless --import` parse clean; **7/7 lints CLEAN** with `orphans=0`;
**103/103 tests across 9 suites**; **5 isolated-revert detection proofs** re-run
green after the geometry change, plus a 6th for `PRINT_MARGIN_PT` (setting it to
0 fails 3 named tests including the dedicated clearance one); both artifacts
re-read with PyPDF2 and their image streams SHA-compared. `project.godot`
confirmed unmodified.

---

## Aug 9 2026 — DEPLOY #4 on the tablet. Six fixes confirmed, one NEW data-loss bug found.

Device TB361FU, build 19:51. Launch activity is `com.godot.game.GodotAppLauncher`
(NOT `GodotApp` — `am start` on the latter throws).

### VERIFIED ON DEVICE

| | evidence |
|---|---|
| Species print BOOK NAMES | sheet shows **K'Erin** (apostrophe intact), Genetic Uplift, Traveler, Mutant, Feral, Human — while the SAVE still stores `species_id=kerin`. Storage keeps the id, display resolves the name. |
| Column alignment (T9-24) | Bryn Ito's row reads `Shatter Ax… \| 0 \| 0 \| 2 \| Melee` under Weapon/Range/Shots/Damage/Traits |
| Two weapon slots (T9-25) | Nyx Ward renders BOTH `Shotgun 12 2 1 Focused` and `Colony Rifl 18 1 0` |
| Landscape sheet screen | held landscape throughout |
| PDF metadata | `/Title` "Five Parsecs Sheet Export", `/Creator` "Five Parsecs Campaign Manager", `/Producer` GodotPDF, `/CreationDate D:20260809195751-07'00'` — **no more "Test"/"Nolan"** |
| PDF geometry | `/MediaBox [0 0 792 612]`, draw rect **756x504 at (18,54)**, **DPI 263 x 263**, margins **L0.25 R0.25 T0.75 B0.75 in** |
| Print safety | ink clearance measured on the DEVICE artifact: 0.425 / 0.478 / 0.985 / 0.970 in — clear of a 0.25in unprintable border on every edge |
| Searchable | **20/20** expected values extract, including `K'Erin` |
| Size / compression | 229,739 B, `/FlateDecode`, inflates to exactly 15,282,156 (was 749,922 uncompressed at 72 DPI) |

⚠ Nice property discovered by accident: `Shatter Axe` is visually CLIPPED to
"Shatter Ax…" in its cell but appears IN FULL in the search layer. `clip_text`
truncates the render; `_collect_text_layer` reads the Label's `.text`. A clipped
field is still findable.

### T9-33 (CRITICAL, data loss, FIXED) — a legacy save lost 5 stash items per load

Loading `22222222_1775243767.save` and pressing Save took the ship stash from
**13 items to 8**. Destroyed: Assault Blade x2, Hot Shot Pack x2, Booster Pills.
Permanent — the survivors get fresh generated ids, so the next load cannot tell.
The dashboard displayed "Gear 8" and nothing errored.

**This was a regression in T9-23's own fix, and it had TWO independent causes.**

**Cause A — an id is not a physical item.** The heal deduped id-bearing items by
id, anywhere. That save carries 5 id-bearing items with only **THREE distinct
ids**: two Assault Blades share `loot_157153_1063` and two Hot Shot Packs share
`loot_157153_6433`, because the id comes from the LOOT ROLL and names the table
entry, not the card. Two Assault Blades are two Assault Blades. 13 -> 11.

Fixed by giving both branches ONE rule — the rule the id-less branch already had:
*duplicates WITHIN the primary list are real items; an entry reappearing under a
SECONDARY key is the split-format echo.* Stated trade-off in the code: a save
written while the old write-through bug was live may keep a genuine duplicate.
A stale duplicate is recoverable; a deleted item is not.

**Cause B — a destructive reset ran BEFORE the read it destroyed.** 11 -> 8.
`_restore_equipment_from_campaign()` opened with `eq_mgr.clear_all_equipment()`,
which by design clears the CANONICAL OWNER as well as the runtime caches. But
`load_campaign()` calls `set_current_campaign(loaded)` FIRST — so that clear was
wiping `equipment_data["equipment"]` of the very campaign about to be read. The
heal then rebuilt the stash from the only thing left, the `gear` echo.

⚠ **The device log is what proved it, and it proved it by what was MISSING.**
Two observations that looked like nothing:
  - **no** "healed N duplicate stash item(s)" line — because after the wipe there
    was genuinely nothing left to dedup
  - **exactly 8** "auto-generated id" warnings — because the 8 surviving echoes
    were precisely the id-less ones
Both are the wipe's signature. An absent log line was the strongest evidence here.

Fix: the clear moved to AFTER the heal has read the stash into `deduped_stash`
and BEFORE that list is written back, with a `_stash_reset_done` flag so the
fallback path still resets when the heal's guard does not match.

### The test that had to exist

`tests/unit/test_legacy_stash_survives_load.gd` (5 cases) runs against
`tests/fixtures/saves/legacy_split_format_stash.json` — the REAL equipment block
off the tablet, trimmed. One case asserts the fixture still has colliding ids, so
the suite cannot quietly stop testing the thing it was written for.

⚠ **The direct-restore test could not see Cause B.** It calls
`_restore_equipment_from_campaign()` directly, so `gs.current_campaign` is a
different object and the clear wipes something else. Only
`test_the_full_load_campaign_path_keeps_every_stash_item`, which calls the real
`load_campaign()`, reproduces 13 -> 8. **When a bug lives in the CALLER's
ordering, a test of the callee is structurally blind to it.**

Detection-proven by isolated revert: Cause A -> 6 failures across 4 cases;
Cause B -> 1 failure, caught ONLY by the full-path case.

### Still open from this session

- `EquipmentManager.add_equipment()` rejects the second item of a colliding-id
  pair (`ERROR: Equipment with ID already exists`). The persisted stash is now
  correct at 13, and stash READS are owner-backed, but the runtime cache holds 11.
  Re-iding one of the pair would fix it and is NOT done here: ids are referenced
  elsewhere (the id->name heal below it), so that needs its own pass.
- The **dashboard** crew pills still show raw ids — `Kerin`, `GeneticUplift` —
  the same defect fixed for the sheet, via a different display path.
- `Handgun` is in the legacy stash but NOT in `equipment_database.json`; the sheet
  therefore cannot resolve its weapon stats. Needs checking against the book.
- encounter_log + world_record manifests still carry uncalibrated starter geometry.

### Verification

Device save RESTORED from its `.bak` (13 items confirmed back on disk) — the test
itself destroyed data and that had to be undone. `--headless --import` parse
clean; **7/7 lints CLEAN**, `orphans=0`; **108/108 tests across 8 suites**;
2 isolated-revert detection proofs for this fix.

---

## Aug 9 2026 — the four open items, closed. Two were bigger than filed.

### 1. Dashboard species pills (FIXED) — and it was mangling a CORRECT value

`CampaignDashboard._enum_to_display()` did
`value.replace("_", " ").to_pascal_case()`. Three of the 28 species come out wrong
that way, but the sharper finding is what it did to a post-migration save: those
store `origin = "Genetic Uplift"` — **already correct** — and `to_pascal_case()`
ate the space back out, producing "GeneticUplift". It was reformatting a value
that needed no formatting.

New `_species_to_display()` reads `species_id` against
`data/character_species.json` first, falls back to matching an already-formatted
display string, and only then falls through to the enum path — which still has to
exist, because pre-migration saves store `origin` as a **float** (`7.0` on the
device's legacy save).

Pinned by `tests/unit/test_species_display_names.gd` (5 cases) covering BOTH the
sheet and dashboard paths with the three ids that defeat string formatting:
`kerin`→K'Erin, `de_converted`→De-converted, `primitive_character`→Primitive.

### 2. "Handgun" (FIXED) — the database was right; the BOOK spells it two ways

Not a missing entry. `equipment_database.json` is complete and book-exact (36
weapons matching Core Rules pp.50-52) and HAS it as **"Hand Gun"** with the right
stats (12", 1 shot, 0 damage, Pistol — p.50).

The book itself uses both spellings: **"Handgun"** on the Low Tech Weapon Table
(p.28) and in the worked example (p.34), **"Hand gun"** in the stat table (p.50).
Save data uses the p.28 form, so the exact-name lookup missed and a real weapon
printed as GEAR with no Range/Shots/Damage.

Fixed with a normalised lookup key (`_weapon_key`: lowercase, strip spaces and
punctuation) applied to BOTH the index and the query — NOT by adding a second
database row, which would be a second source of truth for one weapon. A test
asserts the normalisation collapses no two distinct weapons together.

⚠ The existing fixture already had `"Handgun"` in its stash. It was exercising
this the whole time and only a non-empty assertion stood there.

### 3. Colliding loot ids (FIXED) — runtime cache 11 vs stash 13

`EquipmentManager.add_equipment()` keys by id and rejects a repeat, so the two
Assault Blades could not both be cached even after the stash kept both. The heal
now gives the SECOND occurrence its own id (`<id>_dup2`) while the FIRST keeps the
original — a character's equipment list can reference a stash item by id (the
id→name heal does exactly that), and that reference must keep resolving. Verified
the device save has no external references to those ids before doing it.

### 4. The two secondary sheets (RE-AUTHORED) — the manifests described a sheet that does not exist

Filed as "2 and 3 rects span a divider". That was the symptom. Rendering the
artwork with the extracted boxes numbered showed the real problem:

- **World Record** manifest had `world_type`, `danger_level`, `turns_visited` —
  **none of those boxes are printed on the sheet** — and three trait ROWS where
  the artwork prints ONE multi-line "World Traits" box. It addressed nothing in
  the sheet's three biggest sections: Invasion Status, Local Patrons Known (x3),
  Local Rivals Known (x3).
- **Encounter Log** manifest had `campaign_name`, `turn_number`, `world_name` —
  again, no such boxes — and missed Encounter Type, Deployment Conditions, Shiny
  Bits and the Outcome panel.

Both re-authored against measured geometry: encounter_log 10 → **6** fields,
world_record 9 → **20**. Fewer fields on one and double on the other, because the
count was never the point — addressing the right boxes was.

Notes on the measurement, all of which cost time:
- boxes 0-16 / 0-11 in the extractions are the **letterforms of the sheet titles**,
  false positives from the CV pass
- the extractor **MISSED the "Invading Force" box entirely**; measured it directly
  (cyan rules at y=154/318, sides x=1870/2633) rather than inferring it
- extractor index 19 is **War Progress**, not Invading Force — confirmed by cropping
- each Patron/Rival block carries ONE internal rule at exactly **+160** from its
  top (measured, identical in both columns), which splits name from Benefit/Notes
- "Shiny Bits" is a **Core Rules loot-table entry** ("Shiny bits: Gain 1 credit"),
  so mapping it to `credits_earned` is book-grounded, not a guess

⚠ **An automated centre-snap was tried first and REJECTED.** Snapping each rect to
the cell containing its centre moved `trait_3` from x=320 to x=1003, away from
trait_1/trait_2. When a starting rect is arbitrarily wrong, its centre is
arbitrary too, and snapping produces a *differently* wrong rect that no longer
trips the divider test. Measure the artwork; do not refine a bad guess.

The Enemy Types (3x5) and Enemy Weapons (4x3) tables are deliberately left
unaddressed: they are filled in BY HAND during the battle and no per-enemy stat
data exists in the campaign model. Blank boxes are correct output for a print form.

View-model gained `world.traits_text`, `campaign.patron_rows[]`,
`campaign.rival_rows[]`, `journal.last_battle.deployment_condition`, and four
documented blank-until-modelled keys (invading_force, war_progress,
license_obtained, license_not_required) — added to BOTH the populated and empty
campaign branches, since a key present in only one resolves to null on the other.

**The ratchet is gone.** `test_no_field_rect_spans_a_printed_column_divider` now
holds all three sheets to ZERO; the 2/3 allowances were removed, not raised.

### Verification

Rendered both sheets at source resolution and read the values off the artifact:
Encounter Type "Raiders", Mission "Patrol", Shiny Bits "12", Number "7", the
outcome note in the right panel, "Feral Jackals" on Rival Type 1's writing rule.
A caption collision ("Poor Visibility" printing over "Deployment Conditions") was
caught in that render and fixed by baking `label_inset` for the new fields.

All three geometry scripts IN SYNC; `--headless --import` parse clean; **7/7 lints
CLEAN** with `orphans=0`; **133/133 tests across 11 suites**.

### Open after this pass

- The re-authored sheets have NOT been seen on device — deploy #5 should print or
  export both.
- `world.notes`, `campaign.invading_force`, `campaign.war_progress`,
  `world.license_*` are genuinely unmodelled and print blank by design.

---

## Aug 9 2026 — the two secondary sheets, audited against the BOOK (T9-34)

Asked to "ensure those are accurate as well" after re-authoring both manifests
from the artwork. The geometry was fine. Almost none of the DATA was.

### The find that reframed the whole pass: the book prints these sheets

**Core Rules Appendix X, PDF pp.180-181, contains all three sheets in full.** That
is the authority on what every box means and it was one PyPDF2 call away. The
previous pass measured the artwork carefully and never asked the book what the
captions meant.

### Six defects, in order of severity

**1. Five of the Encounter Log's six boxes printed BLANK on every campaign.**

`CampaignJournal.create_entry()` assembles every entry from a FIXED key set —
`id/turn_number/timestamp/type/auto_generated/title/description/mood/tags/
characters_involved/location/photos/stats/player_notes` — and DROPS everything
else. `SheetDataContext._build_journal()` read `mission_type`,
`deployment_condition`, `enemy_faction`, `enemy_count`, `credits_earned` off the
entry's TOP LEVEL, where a journal entry has never had any of them. Only
`outcome_notes` worked, because it falls back to `description`.

Every one resolved to `""` — a legal blank on a print form, NOT null — so the
T9-09 non-null sweep passed, and so did the 28 tests. ⚠ **The suite's own fixture
was the tell**: it hand-wrote `{"type": "battle", "mission_type": "Patrol",
"enemy_faction": "Raiders", ...}`, a shape `create_entry()` cannot produce. The
test was green against a fiction.

Fixed along the project's standard funnel:
- `BattleResultNormalizer` passes `deployment_condition` + `notable_sight`
  through, and DERIVES `enemy_count` from `enemy_force.count` — the post-setup
  value (Invasion +1, Small Encounter, the Red Job base of 7 all move it), not
  the generator's pre-delta `enemy_count`. The book's "Number" column means the
  number actually faced.
- `CampaignJournal.auto_create_battle_entry()` records the scenario in `stats`.
- `_build_journal()` reads `stats` first.

Bonus: `notable_sight` on the result also repairs a first-choice read that was
always missing — `PostBattleCompletion.apply_notable_sight_reward()` looks for it
there and only then falls back to a nested `mission_data` copy most paths lack.

**2. "Shiny Bits" was mapped to credits earned. It is the p.89 NOTABLE SIGHT.**

The Notable Sights table's nine results include *"Shiny bits: Gain 1 credit"* and
*"Really shiny bits: Gain 2 credits"* — the box is named after one row of the
table it records. It sits in the pre-battle block beside Deployment Conditions
because it is step 4 of Readying For Battle, one step before the objective.
Now prints `Shiny bits — Gain 1 credit.` in the book's SENTENCE case (p.89 prints
"Person of interest", not "Person Of Interest"; `capitalize()` would get it wrong).

**3. Two blocks were written off as unmodelled and are not.**

- `world.license_*` — the note said "p.75 Interdiction is a per-roll check, not
  planet state". Wrong: `InterdictionRule` persists `{active, until_turn,
  licensed}` in `progress_data["interdiction"]`, rewritten on EVERY arrival
  precisely so an old world's licence cannot leak forward.
- `campaign.war_progress` — "a per-turn 2D6 roll, not persisted state". Wrong: the
  p.126 table maintains `invaded_planets` / `lost_planets` / `liberated_planets`,
  which are equivalent to its four results. Now prints them in the book's words
  ("Lost to Unity", "Contested — Making Ground (+1 to future rolls)", "Unity
  Victorious"). Moved to `world.*`, since the sheet documents ONE world.

`world.invading_force` genuinely stays blank, with a better reason recorded: the
phrase appears ONLY on the printed sheet and NOWHERE in the rules text of either
book, and although p.121 step 6 makes the invader "the enemy you just battled",
`record_invaded_planet()` persists only `{id, name, war_modifier}` and runs a turn
later at flee-time.

**4. "Encounter Type" meant the wrong thing.** It is which Encounter Table the
opposition came from — Criminal Elements / Hired Muscle / Interested Parties /
Roving Threats (pp.94-103) — not the individual enemy's name, which belongs in the
Enemy Types table's Name/Type column right below it. Now `enemy_category`, falling
back to the enemy name when only that was recorded.

**5. The Number column printed "7" with the Name/Type cell beside it blank.** The
app knows both. Added `enemy_name_1`; the per-enemy stat columns stay hand-filled.

**6. The licensing octagons.** ⚠ Appendix X's TEXT LAYER emits them as
"No Obtained Yes". The ARTWORK reads **Yes | Obtained | No** left to right —
cropping the PNG settled it in one look. PDF extraction returns glyph runs in
content-stream order, not reading order; trusting it would have flipped Yes/No
silently. The crop also showed **Yes and Obtained joined by a connector rule**, so
they are not three exclusive states: a licensed world ticks BOTH. And the "X"
renders centred, which would have printed over the words — the rects moved into
the clear band below each word.

### The guard that was missing

`test_every_addressed_box_prints_something_on_a_populated_campaign`: every manifest
source must render NON-BLANK against a populated campaign, with an explicit
`blank_by_design` map (each entry carrying its reason) plus a stale-exemption check
so a fixed field cannot quietly lose coverage.

It found two things on its first run — a fixture whose captain carried only a
weapon (so `gear_text` was untested) and three of my own exemptions that no
manifest addresses. Detection-proven: reverting the journal producer turns it red
(2 failures), tree restored via `finally`.

Both the test fixture and `tests/tools/emit_sheet_png.gd` now build their journal
entry through `CampaignJournal.auto_create_battle_entry()`. A probe that renders
values the app cannot produce is worse than no probe.

### Verified

Rendered both sheets at source resolution and read the values off the artifact:
`Criminal Elements` / `Poor Visibility` / `Patron — Patrol` / `Shiny bits — Gain 1
credit.` / `Gangers | 7`; `Gamma Prime`, traits line, **X under Yes AND Obtained
with No blank**, `Contested — Making Ground (+1 to future rolls).`, `Feral Jackals`
on Rival Type 1, Invading Force correctly empty.

**150/150 tests across 14 suites** · 7 lints (`orphans=0`) · 3 geometry scripts
IN SYNC · `--headless --import` parse clean.

### Open

- Still NOT seen on device — deploy #5 should print/export both.
- `world.notes`, `world.invading_force`, `world.turns_visited`, `campaign.notes`,
  `campaign.ship.upgrades_text` print blank by design, each with a recorded reason.

---

## Aug 9 2026 — DEPLOY #5 on hardware: two more device-only defects (T9-35)

Build confirmed fresh (`lastUpdateTime=2026-08-09 21:42:56`). Loaded the legacy
`22222222` campaign (6 patrons, 1 rival, Turn 2) and opened Print Sheet.

### PASS — the re-authored World Record Sheet works

Patron blocks: **Shadow Pack / Government**, **Director Ember Pike**, **Piper Blaze**
(3 of 6, correct — the sheet prints three). Rival Type 1: **Fringe Syndicate /
Corporate**. The `benefit` key is ABSENT on these patrons, so the row correctly falls
back to `type` rather than resolving `<null>`.

Licensing octagons all blank, Invading Force blank, War Progress blank — all CORRECT
for this save, and each verified against the pulled JSON first, not assumed:
`progress.interdiction` is **absent** (the arrival check never ran for this campaign,
so the app genuinely does not know — ticking "No" would assert something never
determined), and `invaded_planets` / `lost_planets` / `liberated_planets` are absent.

### FAIL 1 — the entire World block printed blank

World Name and World Traits empty, while the Campaign Dashboard one screen away showed
**"Joffre VI / Desert World / Adventurous Population"**. Both read the same
`PlanetDataManager.get_current_planet()`.

`get_current_planet() -> PlanetData` returns an **OBJECT** — an inner class consumed by
property access (`planet.visit_count` in CampaignDashboard). `_build_world()` opened with
`world if world is Dictionary else {}`, so it threw the planet away and returned an empty
dict. **On every campaign, since the sheet shipped.**

Fixed with `_as_dictionary()`, which calls `serialize()` — that method already emits
exactly the keys the manifest addresses, so it IS the conversion.

### FAIL 2 — the sheet had NEVER received a single journal entry

`PrintSheetScreen._build_data_context()` guarded on
`journal.has_method("get_entries")`. **`func get_entries` has ZERO definitions
repo-wide** — the accessor is `get_all_entries()`. A permanently-false branch, so
`entries` was ALWAYS `[]` and the whole `journal.*` namespace was empty in every
campaign on every platform.

⚠ So the Encounter Log was blank for THREE independent reasons, each of which fully
explains the symptom on its own: this, the `create_entry()` fixed key set (T9-34), and
`stats` not carrying the scenario. Fixing any one alone would have changed nothing
visible — which is exactly why "it's still blank" was never evidence the earlier fix
had failed.

CLAUDE.md already names this trap ("a `has_method()` guard on a method with ZERO
definitions is a permanently-false branch, not a safety net; grep `func <name>`") and
nothing checked it. Added **`scripts/scan_dead_has_method_guards.py`** —
**REPORT-ONLY, always exits 0**, NOT an eighth gating lint. It reports 91 names in
`src/`; most are legitimate GDExtension / platform-plugin probes (GodotSteam
`activateGameOverlayToStore`, Billing `acknowledge_purchase`, libharu `begin_text` — all
14 hits on the export path are libharu/GodotPDF and correct). The list needs triage
before it can gate anything.

### Why the suite was blind to both

Every test calls `SheetDataContext.build(campaign, world, entries)` **directly and passes
the arguments in**, so it never exercises how the SCREEN obtains them — the same shape as
the T9-23 stash bug, where testing the callee could not see a caller-ordering fault. And
the world fixture was a hand-built Dictionary: the fabricated-fixture failure from T9-34,
in the adjacent function, which I had just written up and still did not apply here.

Both now covered:
- `test_the_current_world_resolves_whether_object_or_dictionary` — the fixture is a real
  `PlanetData`; the Dictionary path is asserted too, for older callers.
- `test_the_journal_accessor_the_print_screen_calls_actually_exists` — reads the accessor
  name OUT OF PrintSheetScreen.gd so a rename breaks the test instead of the sheet, then
  asserts CampaignJournal defines it AND returns a created entry.

Both detection-proven by isolated revert (4 failures and 1 failure + 1 error), tree
restored via `finally`.

⚠ One process note: the first run of the new accessor test printed **`Exit code: 0` with
no Statistics line** — a GDScript parse error (`\.` is an invalid string escape; use
`[.]`). gdUnit4 reports "No test cases found, abort test run!" and still exits 0. Always
read the CASE COUNT, never the exit code.

### Verified

**152/152 across 14 suites** · 6 gating lints CLEAN · `orphans=0` · parse clean.

### Open

- **Both device fixes need deploy #6 to confirm on hardware.** The World block and the
  Encounter Log values have NOT yet been seen working on the tablet.
- The Encounter Log's scenario boxes will stay blank for battles fought BEFORE this
  build — the journal entries predate `stats` carrying them and there is no backfill.
  A post-deploy battle is required to see them populated.

---

## Aug 13 2026 — DEPLOY #6: the consent gate could not be scrolled (T9-36)

Predicted the expected output before opening anything, per the deploy #5 lesson.

### PASS — the legal re-consent mechanism works

Stored consent was `privacy version="1.0"`; `PRIVACY_VERSION` is now `1.1`, and the
EULA/consent screen re-prompted on launch exactly as intended. **Version 1.1 of the
policy is live on device**, so a material change to a legal document does reach
existing testers. `analytics consent=false` on device, the correct opt-in default.

### 🔴 T9-36 — neither legal document can be scrolled by touch

On the consent gate, the FIRST screen any new tester sees:

- six swipes on the privacy popup: **zero changed pixels**
- a slow 900ms drag: **zero changed pixels**
- a drag on the scrollbar itself: **zero changed pixels**
- the EULA body behind it: **zero changed pixels**

A tester can read as far as "1.1 Data Stored Locally on Your Device" and no
further, then must accept documents they are physically unable to read. That is a
consent problem, not just a UX one.

Taps work fine (the link opened the popup, OK closed it), which is exactly why the
screen looks healthy. Only the gesture is dead.

**Cause.** `Control.mouse_filter` defaults to `MOUSE_FILTER_STOP`, so a
RichTextLabel, a plain CenterContainer, or a decorative PanelContainer sitting
inside a ScrollContainer eats the drag before the ScrollContainer can interpret it.
Five such controls across three separate constructions:

| Site | Swallower |
|---|---|
| `EULAScreen` EULA body | `_eula_text` (RichTextLabel) |
| `EULAScreen` outer scroll | the card `PanelContainer` (pure chrome) |
| `EULAScreen` privacy popup | its local `rtl` |
| `LegalTextViewer` | `center` (CenterContainer) + `_rtl` |

⚠ **This is the SAME class as T4-01, which was fixed and device-verified on Aug 8**,
and the regression test for it already existed. It did not catch this because
`test_decorative_chrome_does_not_swallow_the_drag` is scoped to
`WorldPhaseController`. The rule was known, the fix was known, the test was
written, and the first screen in the app was still never covered by it.

**The transferable point:** a per-screen regression test protects that screen and
nothing else. When a trap is a DEFAULT of the toolkit rather than a mistake in one
file, the guard has to be applied per screen or made global.

Fixed at all five sites. New suite `tests/unit/test_legal_screens_scroll.gd` walks
every ScrollContainer on the three legal screens and fails on any non-interactive
`STOP` descendant. Detection-proven: reverting all five fixes produces 4 failures.

⚠ Its first run found a real sixth item and one of MY OWN false positives: the
privacy `LinkButton` was flagged because `node is Button` is false for
`LinkButton`, which extends `BaseButton` without extending `Button`. The check now
tests `BaseButton`.

### Verified

`verify_legal_docs` PASS (4 docs) · `test_legal_screens_scroll` 3/3 ·
`test_world_phase_step_viewport` 18/18 (the original T4-01 suite, no regression) ·
7 lints CLEAN · `--headless --import` parse clean.

### Open

- **T9-36 is fixed but NOT device-verified.** The next deploy must repeat the swipe
  test on both documents.
- **Placeholders are visible to testers**, confirmed on screen in the first
  paragraph: "Last Updated: [DATE OF RELEASE]" and "contact us at [CONTACT EMAIL -
  TO BE ADDED BEFORE RELEASE]". Present in the EULA too.
- The sheet fixes from deploy #5 were not re-checked this pass; the consent gate
  took the session.

---

## Aug 13 2026 — DEPLOY #7 on hardware: T9-36/T9-37 verified, T9-38 found (sheets)

Build `lastUpdateTime=2026-08-13 10:54:33`, device TB361FU, `versionName=0.9.7`,
menu shows `v0.9.7-alpha1`.

### PASS — T9-36, both documents now scroll

Measured by pixel-diffing a screencap before and after a swipe, not by eye:

| Surface | Before the fix | After |
|---|---|---|
| EULA body | 0 px changed | changed region (853,436)–(1707,1155) |
| Privacy popup | 0 px changed | changed region (853,518)–(1617,1272) |

The `PRIVACY_VERSION` bump to 1.1 re-prompted correctly on launch — the consent
gate appeared for a device that had already accepted 1.0, which is the whole point
of the version gate. Accepting both then routed to MainMenu.

### PASS — T9-37, bulleted bold no longer prints its markers

Section 1.1's six bullets render as intended:

```
 • Campaign save files — your campaign progress, crew data, and game state
 • App settings — display, audio, gameplay, and accessibility preferences
```

Previously every one of them printed `• **Campaign save files** — ...` with the
asterisks showing. Bold is real, the cyan bullet glyph survived, and §1.2's
non-bullet bold (which always worked, being the `else` branch) is unchanged.

Placeholders confirmed still visible and intact: "Version 1.1", "Last Updated:
[DATE OF RELEASE]", "contact us at [CONTACT EMAIL - TO BE ADDED BEFORE RELEASE]".

### 🟠 T9-38 — the World Record Sheet printed a raw storage id (FIXED)

**Screen**: Print Sheet → World Record, campaign `22222222` on Joffre VI.
**Expected**: World Traits box reads "Adventurous Population" (Core Rules pp.72-75,
D100 75-76, `data/world_traits.json`).
**Observed**: it read `adventurous_population` — the raw snake_case id, on the
artifact the player prints and keeps. The Campaign Dashboard, two taps away, showed
"Adventurous Population" for the same world in the same session.

**Cause.** `SheetDataContext` passed trait ids through `_join_names()`, which
returns a String unchanged. There was no humanisation step at all on the sheet path.

**What made it survive.** Three surfaces each re-derived the display name
independently and *none* read the file that owns it:

| Surface | What it did |
|---|---|
| `CampaignDashboard` | `str(t).capitalize()` |
| `PlanetDetailBuilder` (dashboard overlay + Galaxy Log popup) | `str(t).capitalize()` |
| `SheetDataContext` (printed sheet) | nothing — raw id |

`capitalize()` agrees with all 42 book names **today**. That is a coincidence, not
a contract: a trait carrying an apostrophe, a hyphen or a numeral would print
something the book does not say, silently, on three surfaces at once. This is the
CLAUDE.md trap "a displayed value that exists nowhere else is a lie waiting to be
found" — the name was being *computed* rather than *read*.

**Fix.** `WorldTraitEffects.display_name(id)` — that file already parses
`world_traits.json` and was discarding the `name` field. All three surfaces now
call it. Unknown ids (a Compendium trait, a hand-written save) fall back to the old
transform rather than printing an empty box.

### The fixture was fabricated in the same way as the journal one

`_world()` in `test_sheet_source_paths_resolve.gd` stored
`["High Cost", "Booming Trade", "Fringe"]` — *display names*, when the producer
stores *ids*; and two of those three are not traits in the book at all. So the
suite asserted against a shape the app cannot produce and could not have caught
this. Corrected to real ids (`high_cost`, `booming_economy`,
`adventurous_population`), confirmed against the device's own save
(`world.traits == ["adventurous_population"]`).

Same failure as the `create_entry()` fixture on Aug 9. **Build fixtures from the
real producer, or from real device data — never by hand.**

### Not defects (checked, correct as-is)

- **Encounter Log blank.** The loaded campaign has zero journal entries; its 3W/0L
  came from editor-set counters, not played battles. Predicted from the pulled save
  *before* looking at the screen, and the screen matched. The re-authored geometry
  IS verified: every caption sits above its own box, nothing spans a divider.
- **All three Licensing octagons blank.** `progress_data` carries no `interdiction`
  record, so `_licensing()` correctly returns blank and the player circles one by
  hand. (Lead, not a verdict: the record is written on every *arrival*, and this
  campaign was built in the editor rather than travelled into. Worth confirming on
  a campaign that has actually travelled.)
- **Crew Log weapon/gear rows blank.** All 13 items are in the ship stash and none
  are assigned; the stash box lists all 13. Consistent with the campaign.

### Verified

`test_sheet_source_paths_resolve` 26/26 (was 23, +3 new) ·
`test_world_trait_effects` 19/19 · `test_final_partial_rows` 23/23 (the accessor
must-have-a-live-consumer guard still passes with the new accessor) ·
`test_legal_screens_scroll` 3/3 · **71/71 total** · 6 gating lints CLEAN ·
`lint_orphan_assets` orphans=0 / test_only=40 (the known tier-7 backlog) ·
`--headless --import` parse clean.

**Detection-proven**: reverting only the two `_trait_names` call sites fails
`test_world_traits_print_the_book_name_not_the_storage_id` on all four assertions.
`test_every_world_trait_id_resolves_to_its_book_name` is driven BY the JSON, so it
grows teeth the moment a trait lands whose printed name is not its title-cased id.

### Open

- **T9-38 is fixed but NOT device-verified.** Next deploy: reopen World Record on
  Joffre VI and confirm the box reads "Adventurous Population".
- **The Encounter Log has still never been seen with real data.** It needs a battle
  recorded *on a build carrying the Aug 9 `auto_create_battle_entry()` fix* — the
  only battle entry on the device predates it and carries just the four legacy
  stats keys. Play one battle to completion on device.

---

## Aug 13 2026 — DEPLOY #8: a full campaign turn played on device (T9-39..T9-45)

Build `lastUpdateTime=2026-08-13 11:56:24`. First time a complete turn has been
played end to end on hardware: World Phase 6 steps → Patron job → PreBattle →
TacticalBattleUI → Record Result → the 14-step post-battle → turn rollover to Turn 3.

### PASS — T9-38 verified

World Record Sheet now prints **"Adventurous Population"** where deploy #7 printed
`adventurous_population`. Dashboard unchanged (it reads the same SSOT now). The
Licensing octagons print **Yes — Obtained | No** with the connector, matching the
artwork rather than the PDF text layer's misleading order.

### PASS — the engine question CLAUDE.md left open is answered

```
[KeyboardAvoidance] raw=760 window_h=1600 logical_vp_h=1379.3 -> kb_logical=655.2 | field_bottom=894.0 shift=181.9
```

`raw=760` matches the keyboard's measured height on this tablet (~762 of 1600 px),
so **the nav-bar double-count of godot#86663 is confirmed ABSENT in 4.6** — it was
fixed at milestone 4.5, and this is the direct measurement CLAUDE.md asked for
rather than an assumption.

### PASS — other things that worked

- The 14-step post-battle sequence ran to completion, every step ✓.
- **The Notable Sight's +2 XP flowed all the way through**: Zephyr Flynn gained
  4 XP where every other crew member gained 2, from a checkbox ticked in the
  Record drawer (p.89).
- Loot ("Shock Attachment"), a Campaign Event adding a Patron, and a Character
  Event ("Drew Thorne: Melancholy") all fired.
- Turn rollover Turn 2 → Turn 3; "Continue to Next Cycle" correctly gated behind
  "Save your campaign before continuing".
- The crew-task gate explains itself ("Assign at least one crew task, then Resolve
  All Tasks") instead of just disabling the button.

---

### 🔴 T9-39 (BLOCKER on touch) — the resolve-tasks confirmation has no reachable buttons

**Screen**: World Phase → Crew Tasks → "Resolve All Tasks".
**Observed**: the `ConfirmationDialog` in `CrewTaskComponent._on_resolve_all_pressed()`
renders taller than the 1600px viewport. Measured: its background runs from y=5 to
y=1600 with no bottom edge, and the region below the text is empty grey to the
screen edge. **"Resolve anyway" and "Go back and assign" are off-screen.**

I only got past it by sending a hardware `KEYCODE_ENTER` over adb — which a tablet
user does not have. The ✕ dismisses, so the step cannot be completed at all: the
World Phase is unadvanceable, which blocks the entire campaign turn.

Cause: a `Label` with `AUTOWRAP_WORD_SMART` added directly to the dialog, sized by
`popup_centered()` with no size cap against the viewport.

**Made universal by T9-40** — the stranded list is never empty, so this dialog
fires on EVERY resolve, not just when crew are genuinely unassigned.

### 🔴 T9-40 (HIGH, legacy saves) — three different derivations of the same crew id

`CrewTaskComponent` derives `crew_id` three incompatible ways:

| Line | Path | Derivation |
|---|---|---|
| `:214`, `:464` | populate + **assign** | `character_id` then fallback `"crew_%d"` (POSITIONAL) |
| `:574` | `_unassigned_eligible_crew()` | `id` then `character_id` then `""` |
| `:1706` | a third consumer | `id` then `character_name` then `"unknown"` |

The device's loaded campaign carries `id` but **no `character_id`**, so assign keys
`assigned_tasks["crew_0"]` while the stranded check looks up `"2873092675"`. Every
crew member is therefore always reported as having no task.

**Observed**: the dialog said *"6 crew have no task"* and listed Zephyr Flynn — while
the list behind it read **"Zephyr Flynn [EXPLORE]"**.

### 🔴 T9-41 (HIGH, legacy saves, silent data loss) — equipment "assigned" but not persisted

`AssignEquipmentComponent._do_transfer_to_crew()` (`:371`) reads
`member.character_id`; absent on a legacy save, so `_persist_to_character("")` fails.
It pushes a warning — and then `:378-381` **remove the item from the stash and add it
to the character anyway**. The UI shows "Zephyr Flynn (1 item)" and the stash shrinks,
while the campaign records neither.

Device log, one per item assigned:

```
WARNING: AssignEquipmentComponent: crew transfer not persisted (military_rifle_3495_...)
WARNING: AssignEquipmentComponent: crew transfer not persisted (rattle_gun_3495_...)
WARNING: AssignEquipmentComponent: crew transfer not persisted (infantry_laser_3495_...)
```

This violates the tabletop invariant "one item, one home" in the view while leaving
the model untouched.

### Scoping T9-40/T9-41 — it is a LEGACY-SAVE class, and the evidence is on the device

Both hinge on `character_id`. `Character.to_dictionary()` (`Character.gd:1374-1379`)
emits BOTH `id` and `character_id` and says so in its docblock, so the natural
assumption is "this cannot happen". The two saves on the tablet settle it:

| Save | Created | `character_id` | `equipment` | `status` | `species_backfilled` |
|---|---|---|---|---|---|
| `tablet_qa_run` | **2026-08-08** | yes | yes | yes | — |
| `22222222` (the one loaded) | **2026-04-03** | **no** | no | no | **true** |

The April save predates those keys and was migrated in (hence the backfill marker).
So a fresh campaign is fine and **every alpha tester carrying a pre-May save is not**.
Same family as [[reference_legacy_save_origin_is_float]].

### 🟠 T9-42 (MEDIUM, rules) — "Pay 1 story point" is offered, and free, at 0 SP

Explore result 97-100 fired. The dialog offered "Pay 1 story point" with the campaign
at **SP: 0**, accepted it, and printed **"Paid the cost"**.
`CrewTaskComponent.gd:3494-3497` charges with no affordability guard, and
`GameStateManager.modify_story_progress()` clamps at `max(0, ...)` — so the player
keeps the crew member for nothing. Textbook "check the price you charge against the
price you check".

**The rule is also implemented at the wrong TIME.** Core Rules p.82, verbatim:

> "This place is rather nice, really. **When you are ready to leave this world, unless
> it is being Invaded, you must pay 1 story point or this crew member will decide to
> stay behind. If they do, you can keep their equipment, though.**"

Three deviations: the payment is due **on departure**, not immediately; there is an
**Invasion exemption**; and the crew member's **equipment is retained**. The JSON
paraphrase (`data/exploration_table.json`) flattens all three to "Pay 1 story point or
one crew member leaves the crew" — and says "one crew member" where the book says
"this crew member".

### 🔴 T9-43 (HIGH) — the Aug 9 Encounter Log fix reads keys nothing writes

The Aug 9 fix taught `CampaignJournal.auto_create_battle_entry()` to record
`mission_type` / `enemy_category` / `deployment_condition` / `enemy_count` /
`notable_sight` into `stats`. It works — **when the dict it is handed carries them.**

`PostBattleCompletion.create_battle_journal_entry()` (`:130-139`) builds that dict as
**another explicit key literal**:

```gdscript
var entry_data: Dictionary = {
    "turn":..., "location":..., "outcome":..., "casualties":...,
    "loot":..., "xp":..., "crew_ids":..., "enemy_type":...,
}
```

None of the five new keys are in it. So the SECOND fixed-key-set chokepoint was fixed
while the FIRST one, one level upstream, still drops them — the very defect shape the
Aug 9 entry above documents, committed one level above where the fix was aimed.

**Why the test did not catch it**: `test_sheet_source_paths_resolve` builds its fixture
by calling `auto_create_battle_entry()` directly and passing the keys IN. That is the
callee. The defect is in the caller. Exactly
[[reference_test_the_screen_not_just_the_builder]], repeated.

Measured on the real entry written by a real battle:

```
battle_result 'defeat'   casualties 0   loot_earned 0
enemy_type 'Mutants'     objective 'Move Through'   xp_gained 0
```

`xp_gained 0` and `loot_earned 0` are also wrong — 14 XP was awarded and a Shock
Attachment was found in the same sequence.

**And the sheet shows the consequence.** With the intended keys absent, the fallback
chain fills the wrong boxes:

| Box | Printed | Should be |
|---|---|---|
| Encounter Type | `Mutants` | `Interested Parties` (the p.94-103 table) |
| Mission | `Move Through` | `Patron` |
| Deployment Conditions | *blank* | `Small Encounter` |
| Shiny Bits | *blank* | `Peculiar Item` |

A fallback that silently promotes a different field into a labelled box is worse than
a blank one: the sheet is confidently wrong rather than honestly empty.

### 🔴 T9-44 (HIGH, rules + presentation) — a Rival attack MERGED with a Patron job

The saved mission carries both identities at once:

```
mission_source     rival             rival_name         Fringe Syndicate
source             rival             rival_attack_type  BROUGHT_FRIENDS
patron             Regional Agent    patron_type        regular      pay  5
enemy_type         Mutants           enemy_category     interested_parties
```

Consequence chain, all observed:

1. Job Offers presented "Secure (regular) - +5 cr" from Regional Agent; I accepted it.
2. Mission Prep briefed "Pay: 5 credits".
3. PreBattleUI printed **"HOW YOU WIN: There is no Win condition against Rivals (p.91)"**
   on that Patron job, and applied Brought Friends (+1 enemy).
4. The Battle Card still rolled and displayed a p.89 objective (Move Through).
5. The Record drawer stated **"Recorded as a WIN — to win the battle you must achieve
   the objective (Core Rules p.89)"** and I ticked Objective achieved + Held the field.
6. `BattleSetupRules._apply_rival_attack()` had set `no_win_condition = true`, so
   `TacticalBattleUI._has_no_win_condition()` forced `success = false`.
7. `PostBattlePhase.mission_successful` = false → **journal outcome 'defeat'**, and
   **payment 1 credit** instead of 5 + 1 danger pay.
8. The printed sheet reads **"Battle vs Mutants - Defeat | Objective: Move Through
   (achieved)"** — self-contradicting on the artifact the player keeps.

⚠ **Step 6 is book-CORRECT in isolation** (p.91 really does say there is no Win
condition against Rivals). The defect is that a Rival attack (p.85) should have
*superseded* the job rather than being merged into it — and that five surfaces went on
presenting it as a winnable 5-credit Patron mission after the engine had decided it
was not. Do not "fix" this by deleting the `no_win_condition` override.

### 🟠 T9-45 (MEDIUM, touch) — two more screens cannot be touch-drag scrolled

Same class as T4-01. Both are scrollable only by grabbing the thin scrollbar at the
screen edge:

- **Record Battle Result drawer** — its content is wall-to-wall `CheckBox` / `SpinBox` /
  `OptionButton`, all `MOUSE_FILTER_STOP`, so a drag finds a STOP child almost
  everywhere. The "Submit Battle Results" button sits below the fold.
- **World Phase page** — drags over the Travel/Upkeep panels do nothing; the scrollbar
  works.

Measured both ways: swipes at x=2280 and x=2080 changed nothing; a drag on the
scrollbar at x=2538 scrolled normally.

### Verified this pass

T9-38 on device · KeyboardAvoidance `raw=760` · post-battle 14/14 · Notable Sight XP
(4 vs 2) · turn rollover · save gate · Encounter Log printing real data for the first
time (3 of 7 boxes, 2 of them fallbacks in the wrong slot).

### Open

- T9-39 blocks the campaign turn on touch. Highest priority.
- T9-40 / T9-41 hit every legacy save. T9-41 is silent.
- T9-43 needs the five keys added to `create_battle_journal_entry`'s literal, plus a
  test that drives THAT function rather than `auto_create_battle_entry`.
- T9-44 needs a decision on p.85 supersede-vs-merge before any code change.
- T9-42 needs the affordability guard AND the p.82 timing/exemption/equipment clauses.

### FIXED Aug 13 2026 — T9-39 + T9-40 + T9-41 (one root cause and one sizing bug)

T9-40 and T9-41 turned out to be the same defect in two panels: **a crew member's
id resolved by a different rule at every site**, on a save shape that carries `id`
and no `character_id`. T9-39 is separate but was made universal by T9-40, so the
three ship together.

**`CrewTaskComponent.crew_key(member)`** is now the only way to key
`assigned_tasks`. All three old derivations (`:214`, `:464`, `:574`, `:1706`) route
through it: `character_id` → `id` → `name:<name>`.

The positional `"crew_%d"` fallback is gone, and it was the worse half.
`_get_eligible_crew()` is a FILTERED subset of `crew_data`, so with one crew member
in Sick Bay `crew_data[2]` and `eligible[2]` are different characters — `"crew_2"`
addressed whoever the caller happened to be holding. **A key into a shared
Dictionary must never depend on position.** `test_the_key_does_not_depend_on_position_in_the_list`
pins exactly that.

**`AssignEquipmentComponent._character_key(member)`** does the same for both
transfer directions. `EquipmentTransferService._find_crew_member()` already matched
on `character_id` OR `id` (`:183`), so the service could always have found these
members — the caller simply never handed it anything to look up.

Both transfer paths now also **refuse the move when a live campaign rejects the
write**, instead of mirroring it locally regardless. The old code removed the item
from the stash and showed it on the character after the persist failed, so the
screen stated an outcome the model did not hold. With no campaign (creation
preview, tests) the local mirror IS the model, so `_has_live_campaign()` keeps that
path working rather than making the panel inert.

**`CrewTaskComponent.confirm_dialog_size(viewport)`** caps the resolve-tasks dialog
at 80% of the viewport with 280x200 floors, and its Label now sits in a
`ScrollContainer` with a small minimum width so a long name list overflows instead
of growing the frame. Kept static and pure so the invariant is assertable without
standing up a Window.

#### Detection-proven, each fix reverted in isolation

| Reverted | Result |
|---|---|
| `crew_key`'s `id` fallback | 2 failures |
| `confirm_dialog_size`'s viewport cap | 3 failures |
| `_character_key`'s `id` fallback | 2 failures |

⚠ The first proof initially reported ANCHOR MISSING and looked like a passing
revert. It was neither: `CrewTaskComponent.gd` is **CRLF** while
`AssignEquipmentComponent.gd` is **LF**, so an `\n` anchor could not match the
former. A revert harness that silently fails to apply is indistinguishable from a
test that cannot detect — normalise line endings before matching, and always
confirm the revert actually applied before reading the result.

#### Gates

`test_crew_task_legacy_save_keys` 10/10 (new) · `test_world_phase_step_viewport`
18/18 · `test_equipment_transfer_service` 10/10 · `test_equipment_persistence` 9/9 ·
**47/47** · 6 gating lints CLEAN · `orphans=0` / `test_only=40` (unchanged) ·
`--headless --import` parse clean.

#### The fixture is the device's own save

`tests/unit/test_crew_task_legacy_save_keys.gd` builds its crew from the exact key
set read off the tablet with `adb run-as … cat files/saves/22222222_*.save`, and
keeps a modern member alongside so the fix cannot regress current campaigns.
Hand-writing it from `to_dictionary()`'s key list would have reproduced the exact
blindness that let all three ship: that function DOES emit `character_id`, so
reasoning from the producer says the defect is impossible.

#### Still open from deploy #8

T9-42, T9-43, T9-44, T9-45 are untouched. T9-44 needs the p.85 supersede-vs-merge
decision before any code changes.

### FIXED Aug 13 2026 — T9-44, the Rival ambush now REPLACES the job (p.85)

The ordering was already right: `_check_rival_encounter_backend()` runs before the
enemy force, objective and Notable Sight are generated, and
`_apply_rival_ambush_override()` existed with a docblock quoting the rule. The
override was simply **incomplete in three ways**, and each one was a key mismatch
rather than missing logic.

#### 1. The erase list named keys the producer does not write

It erased `patron_name`. `JobOfferComponent` writes **`patron`** (`:729`). Nothing
erased `pay` (`:703`), `patron_type`, `job_type` or `objective_description`
(`:696`). So the mission reached the battle still carrying
`patron: "Regional Agent"`, `pay: 5`, `title: "Secure Mission"`, and Mission Prep
briefed a five-credit Secure contract for a grudge match the crew was ambushed
into.

The list is now written **against JobOfferComponent.gd:688-731**, the accepted-job
builder, rather than from memory — writing it from memory is exactly how it went
wrong the first time.

#### 2. The displaced job's enemy fought the Rival battle

`enemy_type` is not blank on arrival: the Patron job put its own enemy there, and
`EnemyGenerator` honours **any** non-empty preset (`:576-580`), taking the category
from that template. So the ambush was fought against the Patron's **Mutants** off
the **Interested Parties** column, and `_roll_encounter_category("rival")` — which
already maps correctly to the p.94 **Unknown Rival** column — never ran.

That column difference is a real mechanic, not flavour: the Unknown Rival column
has no Roving Threats entry at all, and p.101 says why — "Enemies from this list
never become Rivals."

`enemy_type` is now pinned when the Rival has an established type (p.92) and
**erased** when it does not, so the correct column is rolled. `enemy_category` is
always dropped.

⚠ A starting Rival's `type` is a FACTION CATEGORY (`"Corporate"`), not an enemy
type — verified against `data/enemy_types.json`, which has `Mutants` and `Gangers`
but no `Corporate`. Those crews have never been fought, so p.92 has nothing to keep
the same and rolling is correct. Only battle-created Rivals
(`RivalPatronResolver._append_rival`, which writes a real enemy type) get pinned.

#### 3. p.92 could not reach the mission, because of a THIRD key literal

`RivalEncounterCheck.check()` computes `rival_type` and `is_elite` (`:145-147`).
The inline `encounter_data` literal in `_check_rival_encounter_backend` did not name
them, so both were dropped between producer and consumer and the override read
`rival_type` as `""` forever.

Extracted to **`build_encounter_data(check, attack)`** — static and pure, matching
the `should_confirm_resolve_all()` seam pattern — so the handoff itself is
assertable.

#### ⚠ The test I wrote first could not detect defect 3

The consumer tests hand `_apply_rival_ambush_override` an encounter dict that
already contains `rival_type`, so they exercise the CONSUMER and are blind to the
producer dropping it. **Reverting the carry produced 0 failures.** That is the same
blindness as T9-43 one day earlier, reproduced while fixing its sibling.

`test_the_encounter_handoff_carries_everything_the_override_reads` now drives the
real producer against real `RivalEncounterCheck` output. Re-proven: reverting the
carry fails it with "p.92 needs the established type to survive the handoff".

The fixture uses **six** Rivals so the p.85 D6 always lands at or below the count —
the encounter is guaranteed by the rule, not by a lucky seed. The first version
seeded one Rival and failed because the roll has to be exactly 1.

#### Detection-proven, each half reverted alone

| Reverted | Failures |
|---|---|
| erase list back to `patron_name`-only | 1 |
| `enemy_type` clear | 2 |
| `rival_type` carry | 1 (was **0** before the handoff test existed) |
| briefing strings | 2 |

#### Gates

`test_rival_ambush_replaces_the_job` 8/8 (new) · `test_patron_gate_and_rival_ambush`
12/12 · `test_crew_task_legacy_save_keys` 10/10 · `test_zone_job_opposition` 7/7 ·
**37/37** · 6 gating lints CLEAN · `orphans=0` · `--headless --import` parse clean.

#### What is deliberately NOT changed

The player is still offered and can still accept a job in World Phase step 3, and
the Rival check still happens at battle time. p.85 puts the check first *within*
step 6, so the ideal flow gates job selection behind it. That is a UI-ordering
change across JobOfferComponent and the step sequencer, and it is not what makes
the OUTCOME wrong — the outcome is now book-correct either way. Filed as a separate
item rather than smuggled in here.

Also unchanged: the accepted offer is **not** cancelled. p.85 is explicit — "Quests
and Rumors remain, but a Patron job will fail if the time to complete it has
expired" — so detaching this battle from the job must leave the offer and its Time
Frame ticking, which is what `progress_data["patron_job_offers"]` already does.


### CORRECTION Aug 13 2026 — the T9-44 entry above named the WRONG PRODUCER

The section above says the erase list was "written against JobOfferComponent.gd:688-731,
the accepted-job builder, rather than from memory". **That was still the wrong file**, and
the entry is left in place with this correction under it because the mistake is the point.

`JobOfferComponent` builds the OFFER. `mission_data` is built by a second, separate
literal — `WorldPhaseController._on_world_phase_completed` (`:1842-1941`) — which
reshapes the accepted job, renames some keys and **adds keys of its own**. Reading only
the first producer missed four:

| Key | Written | Consumer | What a Rival ambush inherited |
|---|---|---|---|
| `compendium_mission` | `:1940` | `TacticalBattleUI:5074` | `job_results.duplicate(true)` — **the whole job dict**, patron and pay included |
| `type` | `:1939` | `TacticalBattleUI:5073-5080` | a displaced Salvage/Stealth/Street Fight job opened ITS panel on the grudge match |
| `battle_type` | `:1917` | `CTC:1435` (has-guard), `BattleSetupData:72` | the displaced job's answer, kept because the stamp only fires when the key is absent |
| `danger_level` | `:1856` | none in `core/battle` (checked) | inert, but still job identity |

`compendium_mission` is the one that mattered: erasing the top-level `patron`/`pay` while
leaving a deep copy of the entire job nested one key down **moves** the payload rather
than removing it.

**The transferable rule: "I read the producer" is only true if you read the producer of
the DICT YOU ARE EDITING.** Two literals in series, and the second is the one whose keys
reach the consumer. Follow the value forward from the field you can see on the device to
the literal that last wrote it, rather than backward from the name that sounds right.

#### The list is no longer maintained by hand

`test_the_erase_list_covers_the_real_producer` reads `WorldPhaseController.gd`, collects
every key its `mission_dict` literal writes, builds a mission carrying all of them, runs
the real override, and requires each key to be **either erased or named in `KEEP` with a
reason**. Add a key to the flattener without deciding what a Rival ambush does with it
and the test goes red. The reverse is asserted too, so the list cannot be "fixed" by
erasing everything.

`KEEP` currently holds `location`, the four overwritten keys, `enemy_type` (conditional,
p.92), and `is_red_zone`/`is_black_zone` — **the zone is a TRAVEL decision taken at World
Step 0** (`UpkeepPhaseComponent.get_selected_zone`), not part of the job, so the crew is
still in that zone when the Rival finds them. p.149 on the Threat Condition: "applied to
the mission, regardless of its type." Flagged as a judgment call, not a certainty.

Detection-proven, each half reverted alone against a **file backup**: erase list 2 ·
`enemy_type` clear 2 · `rival_type` carry 1 · briefing strings 2 · compendium pair 3 ·
`battle_type` 1 · `danger_level` 1. Gates: 44/44, parse clean.

⚠ **I destroyed this fix mid-review by using `git checkout -- <file>` to undo a revert.**
Nothing was staged, so it restored from HEAD and took the whole uncommitted change with
it. Rebuilt from the verbatim region read earlier in the session and re-verified 44/44.
**A revert harness must restore from a backup copy, never from git, while the work is
uncommitted.**

#### Five `%r` format specifiers removed from three test files

`%r` is Python. GDScript raises "String formatting error: unsupported format character"
and renders nothing — in all five cases inside `override_failure_message`, so the message
was garbage **exactly when the test fired**. The suite was green and printing six errors
per run. Fixed in `test_rival_ambush_replaces_the_job`, `test_sheet_source_paths_resolve`,
`test_species_display_names`.

---

## Aug 13 2026 — pre-deploy review of the still-open rows (no code changed)

Each row below was re-read against the actual source. Two ledger claims did not survive.

### T9-42 — VERIFIED against the PDF, and it is FOUR defects, not one

Book text confirmed from the PDF itself (page index 81 = printed p.82), not from
`docs/core_rules.md`:

> "97-100 This place is rather nice, really. When you are ready to leave this world,
> unless it is being Invaded, you must pay 1 story point or this crew member will decide
> to stay behind. If they do, you can keep their equipment, though."

⚠ It does not extract with a naive substring search — `extract_text()` breaks the line, so
`"rather nice"` matches only the p.129 Character Events row. Normalise whitespace first.

1. **No affordability guard.** `CrewTaskComponent.gd:3565-3568` calls
   `modify_story_progress(-1)`, and `GameStateManager.gd:354` clamps
   `set_story_progress(max(0, ...))`. At 0 SP the charge is a silent no-op and the dialog
   prints "Paid the cost".
2. **Wrong time.** Due "when you are ready to leave this world"; charged immediately. The
   JSON schema already supports `deferred_trigger` and this row does not use it.
3. **No Invasion exemption.**
4. **Equipment not retained.** `_remove_crew_member` (`:4085`) drops the member; their
   `Character.equipment` goes with them. The book grants it to the player.

The data file is where the rule is lost, not just the UI — `data/exploration_table.json`
[97,100] reads `"Pay 1 story point or one crew member leaves the crew"`, which drops all
three clauses and says "one crew member" where the book says "this crew member" (the one
who explored).

**Bonus finding:** `_remove_crew_member` bypasses the sanctioned chokepoint.
`FiveParsecsCampaignCore.remove_crew_member()` (`:184`) exists precisely for this and
rebuilds `_crew_id_index`; the component instead calls `members.remove_at(i)` on the live
array, leaving the index stale.

### T9-43 — CONFIRMED, and the cause is bigger than the key literal

The literal in `create_battle_journal_entry` (`:130-139`) omitting the five scenario keys
is real. But two of the keys it DOES carry are structurally zero:

- **`loot` is always 0.** `PostBattlePhase:329` does
  `var gathered_loot: Array = _loot.process_loot_gathering(_ctx)` then emits it — and
  **never assigns `loot_earned`**. The field is declared (`:100`), synced to the context
  (`:200`) and read (`:477`, and `ctx.loot_earned.size()` in the journal), and written
  nowhere. `get_results()["loot_earned"]` is `[]` on every battle ever played.
- **`xp` is always 0.** The literal reads `battle_result["xp_earned"]`; the only writer of
  that key repo-wide is `BattleResults.gd:190`, which is not on the live post-battle path.
  `ExperienceTrainingProcessor` returns `xp_awards` (`{crew_id, xp}`), which
  `PostBattlePhase:343-344` emits and discards the same way.

Contrast injuries, which is handled correctly: `injuries_sustained` is assigned from the
battle data (`:228`) and `_processed_injuries` from the processor's return (`:336`).

**So it is one shape twice: the orchestrator emits a subsystem's return value and drops it
on the floor, and a later step reads a field nobody filled.** The fix is to assign the
returns, not to add keys to the literal.

### T9-45 — the World Phase fix EXISTS and is skipping these widgets on purpose

`WorldPhaseController._open_content_to_scroll_gesture()` / `_open_subtree()` (`:488-519`)
already sweep the subtree turning `MOUSE_FILTER_STOP` into `PASS`. It is not missing.

`:501` guards on `c.focus_mode == Control.FOCUS_NONE` — the deliberate line between
"chrome" and "controls", so that dragging over a list still scrolls THAT list. **CheckBox,
SpinBox and OptionButton are all focusable, so the sweep skips them by design** — and the
Record Battle Result drawer is wall-to-wall exactly those.

Checked before assuming a deadzone fix: `project.godot:104` already sets
`common/default_scroll_deadzone=16` project-wide, and `BaseCampaignPanel.tscn:50` sets it
too. Per the Godot 4.6 docs, `Control.mouse_force_pass_scroll_events` (default true) is
**scroll-wheel only**; there is no documented path by which a STOP child lets a touch drag
reach the parent. So the deadzone cannot help until the event arrives, and relaxing
`mouse_filter` is the only lever.

The real distinction is not focusability but **"does this widget consume a DRAG?"** A
CheckBox consumes a click and has no drag gesture of its own, so swallowing one is pure
loss; a LineEdit or ItemList genuinely needs its own. Any fix needs that allowlist
decision, which is why nothing was changed here.


## Aug 13 2026 — T9-42, T9-43 and T9-45 FIXED (the review's three open rows)

All three turned out to be the same defect family as T9-44: a value produced
correctly and then dropped, or a rule implemented at the wrong point in the flow.

### FIXED — T9-43, the Encounter Log recorded 0 XP and 0 loot

Three independent causes, each sufficient on its own.

**1. `loot_earned` was never assigned.** `PostBattlePhase:329` called
`_loot.process_loot_gathering(_ctx)`, emitted the return and dropped it. The field
was declared (`:100`), synced into the context (`:200`) and read by two consumers
— the journal's loot box and `get_results()["loot_earned"]` — and written by
nothing. **Every battle ever played reported zero loot.**

⚠ The fix MUTATES the array (`loot_earned.assign(...)`) rather than rebinding it.
`_sync_context()` runs ONCE (`:230`) and binds `_ctx.loot_earned` to that array
OBJECT, so `loot_earned = gathered_loot` would hand the orchestrator a new array
while the context kept the old empty one — a fix that looks right and changes
nothing. Pinned: the `lootrebind` revert case fails.

**2. `xp_earned` had no producer.** The entry reads
`battle_result["xp_earned"]`; the only writer of that key repo-wide is
`BattleResults.gd:190`, which is not on this path. `ExperienceTrainingProcessor`
returns per-crew `{crew_id, xp}` awards which `:343` emitted and discarded. The
orchestrator now totals them at the one place that has them all.

**3. The five scenario keys.** The Aug 9 fix taught
`auto_create_battle_entry()` to record mission_type / enemy_category /
deployment_condition / enemy_count / notable_sight into `stats` for the printable
Encounter Log — but only on the dict it is HANDED, and
`create_battle_journal_entry`'s literal named none of them.

Contrast injuries, which was always right: `injuries_sustained` is assigned from
the battle data (`:228`) and `_processed_injuries` from the processor's return
(`:336`). The correct pattern was sitting two lines away from both bugs.

Detection-proven: loot 1 · loot-rebind 1 · xp 1 · scenario 5.

⚠ **My first XP test could not detect its own defect (0 failures).** It set
`xp_earned` on the battle result and handed it in — testing the journal while the
bug sat in the orchestrator. That is the THIRD time in this session I wrote a
test that passes the missing key in itself. Replaced with one that runs the real
pipeline and asserts the orchestrator recorded a total at all.

### FIXED — T9-42, "Pay 1 story point" was offered, and free, at 0 SP

New SSOT: **`src/core/world/DepartureObligation.gd`**. All four p.82 rules, none
of which were honoured:

| Book | Was | Now |
|---|---|---|
| "you must pay 1 story point" | `modify_story_progress(-1)` clamps at `max(0,…)`, so at 0 SP the charge was a silent no-op and the dialog printed "Paid the cost" | `can_pay()` checked BEFORE charging; no story point, no deal |
| "when you are ready to leave this world" | charged the instant the Explore result came up | recorded, settled at `UpkeepPhaseComponent._on_travel_pressed()` |
| "unless it is being Invaded" | no exemption | waived entirely when `fleeing` |
| "you can keep their equipment, though" | gear deleted with the character | moved to the ship stash via EquipmentTransferService before removal |

Also carries the **p.65 Insanity gate** (story points entirely disabled), which I
had missed and picked up by mirroring `TravelEventResolver._add_story_points` —
that file already solved the identical "parameterised by campaign, cannot
delegate to a singleton bound to a different one" problem, including the
`# lint:ignore` on the fallback write. `lint_data_ownership` caught my first
version, correctly.

**`CrewTaskComponent._remove_crew_member()` DELETED.** Its only caller was the
PAY_OR_LOSE handler, so it was genuinely dead rather than a missing wire — and it
was the buggy version: `members.remove_at()` on the live array, bypassing
`FiveParsecsCampaignCore.remove_crew_member()`, and no equipment retention.

Both data files corrected to the book's wording. They had flattened the rule to
"Pay 1 story point or one crew member leaves the crew" — dropping all three
qualifiers and saying "one crew member" where the book says "this crew member".

⚠ **Stated deviation:** the player's pay/decline answer is taken when the Explore
result comes up and carried forward as a `pay_intent`; departure decides whether
they CAN pay. The book implies the choice is made at departure. Every OUTCOME is
book-correct; what is missing is the ability to change your mind after earning a
story point in between. Deliberately not restructured — making `_on_travel_pressed`
await a dialog would rework a critical path right before a deploy.

Detection-proven: affordability 7 · equipment 2 · Invasion exemption 2.

### FIXED — T9-45, two screens could only be scrolled by the scrollbar

New shared helper: **`src/ui/components/common/TouchScrollOpener.gd`**.

The World Phase sweep already existed and was **skipping these widgets on
purpose**: `_open_subtree` guarded on `focus_mode == Control.FOCUS_NONE` to avoid
competing with widgets that scroll themselves. CheckBox, SpinBox and OptionButton
are all focusable — and the Record Battle Result drawer is wall-to-wall exactly
those three.

Relaxing them is safe because **PASS still delivers the event to the control
FIRST**; a widget that genuinely handles a drag keeps handling it, and only
unhandled events propagate. Containers with their own inner scroll
(ScrollContainer / Tree / ItemList / TextEdit / RichTextLabel / GraphEdit) are
still skipped outright.

Checked before assuming, rather than reaching for the obvious lever:
`project.godot:104` already sets `common/default_scroll_deadzone=16` project-wide,
and per the Godot 4.6 docs `Control.mouse_force_pass_scroll_events` (default true)
covers **scroll wheel only**. A deadzone cannot help with an event that never
arrives, so `mouse_filter` is the only lever.

**`BattleResultsInputForm.gd:97-102` is the receipt for this being the right
fix.** A July session recorded that "the drawer's ScrollContainer does NOT
vertical-touch-scroll on the tablet" and worked around it by tightening the form's
spacing so everything would FIT. T9-45 is that height budget finally overrunning
when the Mission Objective section landed. Fixing the scroll retires the
workaround.

Applied in `SlideOverDrawer.set_content()` (so EVERY drawer benefits, not just
this one) — **deferred one frame**, because children built in the content's own
`_ready()` do not exist at `add_child` time and a sweep that runs before them is
a fix that silently does nothing.

`WorldPhaseController._open_subtree` now delegates to the shared helper; the old
narrow implementation is deleted rather than kept "for reference".

Detection-proven: focus-mode rule 5 · skip list 4.

### Gates

123/123 across 12 suites · all 6 gating lints exit 0 · `orphans=0` /
`test_only=40` · `--headless --import` parse clean.

### Still open after this

- The p.85 job-selection ORDERING (offer a job before the Rival check). Outcome
  is book-correct either way since T9-44; this is UI sequencing.
- T9-42's pay/decline timing, above.
- Everything here is DESKTOP-verified only. The three device-facing claims —
  the drawer drag-scrolls, the World Phase page drag-scrolls, and a Rival ambush
  briefs as itself — need the next deploy. **Treat a green suite as saying
  nothing about device behaviour** (the standing lesson from this whole sprint).


## Aug 13 2026 — DEPLOY #9 on hardware (build `lastUpdateTime=2026-08-13 15:01:39`)

Device TB361FU, 2560x1600 landscape. A full World Phase played end to end on the
new build, plus a battle opened to the Record Result drawer.

### VERIFIED — T9-45, both screens, by pixel diff

| Screen | Gesture | Aug 13 deploy #8 | Deploy #9 |
|---|---|---|---|
| World Phase page | swipe mid-content | 0 px changed | **2,743,062 px** |
| World Phase page | swipe STARTING ON a focusable Button (the Upkeep "?") | — | **2,743,062 px**, no dialog opened |
| Record Battle Result drawer | swipe STARTING ON a CheckBox | scrollbar only | **299,722 px** in the drawer region |

The drawer now reveals CREW INJURIES, the p.123 XP CREDIT block and — the point of
the whole row — **"Submit Battle Results", previously below an unreachable fold**.

**The PASS semantics behaved exactly as the docs predicted.** After the drag the
"?" button showed focus styling and every casualty CheckBox was still UNCHECKED:
the control received the event first, declined to handle a drag, and the
ScrollContainer took it. That is what makes widening the sweep safe, and it is now
observed rather than argued.

This also retires the workaround at `BattleResultsInputForm.gd:97-102`, where a
July session tightened the form's spacing on-device because "the drawer's
ScrollContainer does NOT vertical-touch-scroll on the tablet".

### VERIFIED — T9-39 and T9-40, in one screenshot

The resolve-all confirmation renders with **both buttons on-screen** ("Go back and
assign" / "Resolve anyway"), and it named exactly the four crew with no task —
Lieutenant Casey Flynn, Doctor Indigo Ashford, Officer Kai Ashford, Drew Thorne —
correctly excluding Zephyr [EXPLORE] and Dex [TRADE].

That exclusion is the real T9-40 evidence: the list is built from the same
`crew_key()` the assignments are stored under, so naming the right people proves
the key resolves per-character rather than by position.

### VERIFIED — T9-41, on disk

Gave Zephyr Flynn the Military Rifle at World Phase step 4, then pulled the save:

```
Zephyr Flynn -> ['Military Rifle']
stash count: 14   stash has Military Rifle: False
```

T9-41 was a SILENT failure — the panel showed the item while the model never got
it — so the UI showing "1 item" proves nothing and the save file is the only real
evidence. The item moved; it was not copied.

### 🔴 NEW — T9-46: a starting Rival's faction category was pinned as the enemy

Found by reading the device's actual save rather than by any test. The campaign's
only Rival is, verbatim:

```json
{"hostility": 5.0, "id": "starting_rival_1775243676_0", "is_starting_rival": true,
 "name": "Fringe Syndicate", "source_character": "Zephyr Flynn",
 "strength": 1.0, "type": "Corporate"}
```

`RivalEncounterCheck.rival_type_of()` forwards `type` verbatim, and yesterday's
T9-44 fix pinned any NON-EMPTY value as `mission_data["enemy_type"]`. But
"Corporate" is a FACTION category — it is not one of the 60 names in
`data/enemy_types.json` (checked, not assumed).

Consequences, and they split:
- The FIGHT was still correct. `EnemyGenerator._find_enemy_template_by_name()`
  finds nothing, the template stays empty, and it falls through to
  `_roll_encounter_category("rival")` → the p.94 Unknown Rival column.
- The RECORD was wrong. `enemy_type` is what the briefing prints and what
  `create_battle_journal_entry` now forwards into the Encounter Log, so the sheet
  would name an enemy that never existed. Same class as T9-38: a displayed value
  that is not the one the mechanic used.

Fixed with `EnemyGenerator.is_known_enemy_type()` — a static, load-once name set
built from the same JSON the generator reads — so the type is pinned only when it
is a real enemy. Detection-proven: reverting to the non-empty check fails 1.

⚠ **MY FIXTURE WAS WRONG AND ONLY THE DEVICE KNEW.**
`test_a_starting_rival_with_no_established_type_rolls_normally` passed an EMPTY
`rival_type`, because I assumed a starting Rival carries none. It carries a faction
category. The test passed for a case that does not occur while the real case went
unchecked. I had built the T9-40 fixture from the device's real crew keys for
exactly this reason and then did not do the same for the rival record. The fixture
now uses the save's real shape.

### NOT VERIFIED — the T9-44 ambush itself

The p.85 check is `D6 <= rival count`, and this campaign has ONE Rival, so the
ambush fires 1 turn in 6. It did not fire this turn. What was confirmed is the
CONTROL case: the Patron job reached the battle intact and correct — "Fight Off",
Sand Runners, Roving Threats, pay 7 — which is the un-ambushed path behaving
properly, and it demonstrates the preset-honouring behaviour at
`EnemyGenerator:576-580` that T9-44 exists to interrupt.

⚠ A stale `current_mission` in the save nearly read as a live defect: it still held
the PREVIOUS session's ambushed mission (`mission_source: rival` alongside
`patron: Regional Agent`, `pay: 5`, `title: Secure Mission`), which is the deploy
#8 record, not this build's output. The save was written at turn rollover, before
the new mission was persisted. **Stale data is not a failed fix** — the same trap
as the Aug 9 sheet session.

To verify T9-44 on hardware, the campaign needs several Rivals so the D6 cannot
miss. Cheapest route: add rivals via the Campaign Editor, or edit `/crew/rivals`
in the pulled save and push it back.

### Gates after the T9-46 fix

125/125 across 12 suites · all 6 gating lints exit 0 · `orphans=0` /
`test_only=40` · `--headless --import` parse clean.


### VERIFIED ON DEVICE — T9-44, the Rival ambush REPLACES the job (p.85)

The 1-in-6 roll was the only thing standing between the fix and a verification, so
the roll was removed rather than waited on: the pulled save was edited to carry SIX
Rivals (`/crew/rivals` + `/resources/rivals`), pushed back with
`adb push` + `run-as cp`, and the campaign reloaded. `D6 <= 6` cannot miss.

Accepted a real Patron job first, so there was a payload to strip — "Protect",
Patron **Reputable Contractor**, Pay 7, Danger Pay +3, enemy **Isolationists**,
Hot Job hazard. Then Proceed to Battle. PreBattleUI, verbatim:

```
Mission Info
  Rival Attack: QA Rival 2
  QA Rival 2 has tracked you down (Core Rules p.85). Straight-up fight.
  No modifications.
  Battle Type: STANDARD

Before You Deploy
  HOW YOU WIN: There is no Win condition against Rivals — Hold the Field to
  improve your chance of chasing them off (p.91).
  Deployment: Caught Off Guard

Enemy Forces
  Skulker Brigands  ×6   Category: Criminal Elements
```

Every one of the job's keys is GONE from the briefing: no Protect objective, no
Isolationists, no Pay 7, no Patron, no Danger Pay, no Hot Job. The p.91 no-win
rule is stated. The enemy was rolled fresh rather than inherited.

Compare the CONTROL case captured an hour earlier on the same build, where the
ambush did not fire: "Fight Off Mission … Enemy: Sand Runners … Pay: 7 credits".
Same code path, same session — the difference is entirely the p.85 check.

### T9-46 on the same screen: mechanism confirmed, record impact still inferred

The Rival the check picked, **QA Rival 2**, carries `type: "Corporate"` — one of the
faction categories deliberately seeded into the test save precisely to exercise
this. On this build (which predates the validator) the override pins any non-empty
type, so `mission_data["enemy_type"] == "Corporate"` at that moment.

What the screen proves: the FIGHT was unaffected — the opposition is Skulker
Brigands off **Criminal Elements**, i.e. rolled from the p.94 column rather than
from a template named "Corporate", exactly as predicted. The briefing never prints
`enemy_type` for a Rival attack, so nothing user-visible is wrong HERE.

What remains unobserved: the RECORD. `enemy_type` is what
`create_battle_journal_entry` now forwards into `stats`, so the Encounter Log would
name "Corporate". That needs a build carrying both the T9-43 journal fix and the
T9-46 validator, then a completed post-battle. **Labelled INFERRED, not verified.**

### Method notes worth keeping

- **Editing the save is the cheap way to make a probabilistic rule fire.** A 1-in-6
  gate turns an hour of replaying turns into a coin flip; six rivals turns it into a
  single deterministic run. Pull → edit JSON → `adb push` to `/data/local/tmp` →
  `run-as cp` into `files/saves/` → force-stop → relaunch.
- Seed the fixture to exercise the EDGE: the six rivals were given a deliberate mix
  of `Corporate` / `Gangers` / `Mutants` so whichever the check picked would test
  either the validated-pin or the erase branch.
- `dev_6rivals.save` is kept in the session scratchpad; re-pushing it is a one-liner
  whenever an ambush needs to be forced again. The device was restored to its real
  save afterwards so no doctored rival list is left behind.
- ⚠ `current_mission` is written to the save at turn rollover, NOT mid-battle, so a
  mission cannot be read back off disk while its battle is still open. The
  screenshot is the evidence at that point in the flow, not the save file.


## Aug 13 2026 — CLOSE-OUT before the next deploy

The session had drifted into a perpetual bug hunt: every fix spawned a fresh
investigation and the tablet kept receding. This pass closes the list. A binding
**stop rule** applied: anything newly discovered is written down as a row, not worked.

### Gate 0 — API assumptions checked against the Godot 4.6 docs, not memory

Three of the day's fixes leaned on APIs that had been assumed. Checked before anything
else so the close-out could not introduce new problems of its own.

| Assumption | Docs | Outcome |
|---|---|---|
| `Array.assign()` mutates in place rather than rebinding | "Unlike the `=` operator, the `assign()` method copies the **contents** of the array, not the reference"; "Resizes the array to match" | **CONFIRMED** — `loot_earned.assign(gathered_loot)` is correct and its code comment is accurate |
| `static var` on an ordinary class | Documented GDScript 4 feature (`static var max_id = 0`) | **CONFIRMED** — `EnemyGenerator._known_enemy_names` is fine; lazy-load kept over `_static_init()` to dodge load-order surprises |
| `SomeClass.static_method.call_deferred(arg)` | **Not documented.** The Callable docs only cover instance methods | **CHANGED** — `SlideOverDrawer.set_content()` now defers `_open_content_to_touch_scroll()`, a one-line instance method, matching the `_check_pending_transfers.call_deferred()` idiom used elsewhere. An unverified deferred call that silently no-ops would have left the drawer as broken as before while looking fixed |

### Gate A — the `test_ui_backend_bridge` failures are PRE-EXISTING

`tests/integration/test_ui_backend_bridge.gd` fails 3 tests (`turn_number` not
advancing — the `CampaignPhaseManager._turn_start_in_flight` latch at `:227`).

**The first attempt to attribute them was measured with a broken instrument, and very
nearly got a correct fix reverted.** The control was written with
`git show HEAD:$f | Set-Content -NoNewline`, and in PowerShell `git show` yields an
ARRAY OF LINES which `-NoNewline` concatenates with no separator — a single-line,
unparseable file. With `PostBattlePhase.gd` failing to parse,
`post_battle_phase_handler` was never created and this suite's many `has_method()`
guards took different paths and PASSED. That produced a confident, entirely false
"HEAD passes, your change broke it", and a bisect that inherited the flaw and returned
a self-contradictory answer (either edit alone failed; both reverted passed).

Redone with a byte-exact `git show … > file` Bash redirect **and an explicit assertion
that the control parses** (890 lines, not 1): **HEAD fails the same 3 tests.**
Pre-existing. Accepted.

⚠ **The transferable rule: a control that does not parse is not a control.** Any
revert-comparison must assert the reverted file is still a valid program before its
result means anything — line count and a parse check, every time.

### Accepted pre-existing failures (do NOT re-chase these)

Full sweep: **2,827 unit cases / 10 failures**, **379 integration cases**. Every failure
below predates today's work — confirmed by the target files being unmodified and, for
the bridge, by failing identically at HEAD.

| Suite | Fails | Note |
|---|---|---|
| `test_main_menu_coming_soon` | 6 | `MainMenu.gd` untouched |
| `test_patron_job_effects` | 1 | `test_every_crew_task_allows_two_characters` |
| `test_training_and_reward_wiring` | 2 | one scans `ShipManager.gd` (untouched); the other is a **false positive by construction** — `src.substr(find("func _offer_merchant_reroll"))` takes everything to EOF then forbids `maxi(`, so it flags recruiting code 3,000 lines later. Zero `maxi(` were added to that file |
| `test_expanded_quest_progression` | 1 | files untouched |
| `test_ui_backend_bridge` | 3 | proven identical at HEAD (Gate A) |
| `test_job_offer_component` | flaky | passes 17/17 alone; batch-order pollution only |

**Tooling, not product:** running all of `tests/unit` in one process crashes at ~97
suites (resource exhaustion). Batches of 40 complete cleanly — use batches.

**Deferred by decision, not oversight:** the p.85 job-selection ORDERING (outcome is
already book-correct since T9-44; this is UI sequencing); the p.82 pay/decline timing
deviation (every outcome book-correct, only "change your mind later" is missing); and
the two fragile tests above.

**Rules call recorded:** `is_red_zone` / `is_black_zone` are KEPT through a Rival
ambush. The zone is a travel decision taken at World Step 0
(`UpkeepPhaseComponent.get_selected_zone`), not job payload, and p.149 says the Threat
Condition is "applied to the mission, regardless of its type".

### Gates at close-out

Targeted 14 suites **161/161** · unit 2,827 cases / 10 accepted failures · integration
379 cases (bridge 3 accepted; batch 0 clean at 167/167 on an unpolluted run) · all six
gating lints exit 0 · `orphans=0` / `test_only=40` · `--headless --import` parse clean.

### Still to verify on hardware (one battle, then stop)

1. **T9-46** — a Rival ambush must never record "Corporate" (or any faction category)
   as the enemy; the Encounter Log should name the *generated* opposition.
2. **T9-43** — that same battle's journal entry must carry real XP and loot counts
   rather than 0, plus mission_type / enemy_category / deployment_condition /
   enemy_count / notable_sight.
3. **T9-42** — only if an Explore 97-100 turns up on its own (4%). Not worth grinding
   for; otherwise it stands as desk-verified.

Force the ambush rather than waiting on the 1-in-6: re-push `dev_6rivals.save` from the
session scratchpad (`adb push` → `run-as cp` → force-stop → relaunch), pick a
`Corporate` Rival, and play the battle through Record Result and the 14-step
post-battle. Restore the real save afterwards.

---

## Aug 13 2026 — DEPLOY #10 on hardware: Gate C answered, plus one self-inflicted regression

Build `0.9.7`, `lastUpdateTime 2026-08-13 18:33:58` (the 15:01:39 build predates the
T9-46 validator and the T9-43 journal forwarding, so freshness was checked first, not
assumed). Device TB361FU, landscape 2560x1600.

**Both Gate C rows answered, and a third defect found IN MY OWN FIX and closed.**

### T9-46 — VERIFIED, on the branch that actually discriminates the fix

A Rival ambush must never record a faction category as the enemy.

The first ambush of the session fired on **QA Rival 1, type `Mutants`** and rendered
`Enemy: Mutants` correctly — but that run proves nothing: `Mutants` IS one of the 93
names in `data/enemy_types.json`, so the validator takes the PASS-THROUGH branch and a
build without the fix renders the identical screen. *A check that behaves the same with
and without the fix verifies nothing.*

So the fixture was rewritten to make all six Rivals `type: "Corporate"` — confirmed
absent from `enemy_types.json` while Mutants / Gangers / Isolationists are present —
forcing the REJECT branch. Two independent ambushes followed:

| Ambusher (type) | Enemy generated | Where seen |
|---|---|---|
| QA Rival 2 (`Corporate`) | **Colonial Militia** | pre-battle table (+1 numbers, Panic 1-2, Spd 4", CMB +1, TGH 3, AI Cautious, Military Rifle/Blade, "Home field advantage" rule), battle card, all 4 unit names |
| QA Rival 1 (`Corporate`) | **Skulker Brigands** | pre-battle table (Criminal Elements, Count 7, Seize Init -1), battle card, all 7 unit names |

Never "Corporate" anywhere, a DIFFERENT real enemy each time (so the generator is
genuinely rolling, not falling back to a constant), and each with real stats, weapons
and special rules. The p.85 sub-table also rolled a different condition per ambush
("Add 1 additional enemy / set up in or adjacent to a building", "Deploy one fewer crew,
cannot Seize the Initiative", "Small Encounter"), matching the p.91 Ambush line rendered
beneath it.

T9-44 re-confirmed in the same runs: briefing titled `Rival Attack: QA Rival 2`, and the
accepted job's whole payload gone — no "Reputable Contractor", no 7-credit pay, no +3
danger pay, no "Hot Job" hazard, enemy no longer Isolationists.

### T9-46b — the fix was half a fix, and the device caught it (FIXED, detection-proven)

The battle above generated Skulker Brigands. Its journal entry recorded:

```
"description": "Battle vs Unknown - Defeat\n | Objective: Access (achieved)"
```

`CampaignJournal.create_battle_journal_entry` reads
`battle_result.get("enemy_type", "Unknown")` (`CampaignJournal.gd:768-772`). The T9-46
guard ERASES `enemy_type` when it is not a real enemy name — correct for the FIGHT,
because `EnemyGenerator` honours any non-empty `enemy_type` as a preset — but nothing
put the rolled name back, so the permanent record lost the enemy entirely.

**This was a REGRESSION I introduced, not a pre-existing gap**, and the same save proves
it: the campaign's previous battle, written by the build before the guard landed, reads
`"Battle vs Mutants - Defeat"`. Same journal writer, same ambush path, a name before and
no name after.

Fixed by `CampaignTurnController.stamp_rolled_enemy_type()` — a pure static seam called
from `_initiate_battle_sequence` immediately after `generate_enemies_as_dicts()`, which
stamps `first_enemy["type"]` back onto the mission when `enemy_type` is absent or blank.
Fills only when empty, so a Patron job or a Rival whose type IS a real enemy name keeps
its own, and re-entering a battle stays on the same opponent instead of rerolling one.

⚠ **The transferable rule: REMOVING A WRONG VALUE IS NOT THE SAME AS SUPPLYING THE RIGHT
ONE.** A guard that erases a key owes an answer to "who else reads it?" — here the
briefing, the journal and the Encounter Log all did. My own code comment at
`CampaignTurnController.gd:629-631` had *named* the journal as a consumer and I still
shipped the erase alone.

6 new cases in `tests/unit/test_rival_ambush_replaces_the_job.gd` (18 total, all green).
Detection-proven: neutering `stamp_rolled_enemy_type` to a bare `return` fails exactly
`test_the_rolled_enemy_is_stamped_back_for_the_record`,
`test_the_journal_never_falls_back_to_unknown_after_an_ambush` and
`test_a_blank_enemy_type_is_treated_as_absent`, with the case count still 18/18 (so it is
a real failure, not a parse error). Reverted from a `Copy-Item` backup, never
`git checkout --`.

### T9-43 — VERIFIED

Same battle, played through Record Result and all 14 post-battle steps. On-screen Battle
Results: payment 6 credits, +2 scrap, **Loot found: Seeker Sight**, and XP to every crew
member (Zephyr Flynn +4; Casey Flynn / Dex Jones / Indigo Ashford / Kai Ashford / Drew
Thorne +2 each = **14**). The journal entry's `stats`:

```json
"loot_earned": 1,          "xp_gained": 14,
"deployment_condition": "Small Encounter",
"enemy_category": "criminal_elements",
"enemy_count": 7,
"notable_sight": "NOTHING",
"objective": "Access"
```

Real counts, not zeros, and `xp_gained` matches the on-screen award exactly. All five
scenario keys forwarded through `PostBattleCompletion`.

### T9-42 — not exercised; stands desk-verified

Both Explore rolls (the task caps at 2 crew, `[FULL 2/2]`) came up "Arms dealer",
"Package delivered" and "Get in a bad fight" across two runs — no 97-100. Per plan, not
ground for.

### New rows found on the way (NOT worked — stop rule)

| # | Finding |
|---|---|
| **T9-47** | The Crew Task Event **item-discard dialog** renders raw serialized Dictionaries: the OptionButton label reads `{ "condition": "damaged", "id": "military_rif…` and the result line reads `Discarded: { …, "name": "Military Rifle", … }`. The dict carries `"name"` right there. Its confirm button also renders **blank**, and the dialog has a horizontal scrollbar because content overflows its width. The mechanic itself is correct (the item is discarded). Same family as T9-38 — a raw value displayed where the owning field holds the real name. |
| **T9-48** | A p.85 ambush whose condition is "**Cannot** Seize the Initiative" still shows a live Seize the Initiative panel offering a roll; the requirement moves 7+ to 8+ (58% to 42%), i.e. a **-1 modifier where the text states a prohibition**. Needs p.85/p.91 adjudication before touching. |
| **T9-49** | A battle recorded as a **WIN** (objective achieved, `Won`, Held the field) is journalled `"battle_result": "defeat"` / `"mood": "defeat"`, while the same entry's description says `Objective: Access (achieved)`. **PRE-EXISTING** — the turn-2 entry written by the previous build has the identical contradiction (`"Battle vs Mutants - Defeat … Objective: Move Through (achieved)"`). |
| **T9-50** | Resuming a `world_phase_checkpoint` at Step 6/6 lands on Mission Prep with a **blank briefing** (Objective/Enemy/Location `Unknown`, Pay 0) even though `progress.world_phase_results.mission_data` holds the full job. Confirmed by contrast: a clean Step 1 to 6 walk of the same save renders the real briefing. Only the checkpoint path is affected. |

### Two false alarms worth recording, because both cost real time

1. **"The app hangs on Ready for Battle."** It does not.
   `MissionPrepComponent._on_ready_for_battle_pressed()` (`:257-275`) only sets
   `prep_completed`, publishes `MISSION_PREPARED` and calls `_update_ui_display()`,
   which DISABLES the buttons. The phase still advances via a separate
   **"Proceed to Battle"** control below the fold. I read the greyed-out controls as a
   stuck full-screen transition overlay — twice.
   **What settled it was measuring instead of looking**: a pixel diff showed the
   background byte-identical before and after (`(10,13,20)` both) with changes confined
   to `y=739..1406`. A real overlay dims every pixel. *If a screen looks "dimmed", diff
   it before diagnosing it.*
2. **`adb shell input keyevent KEYCODE_BACK` to dismiss the soft keyboard propagates into
   the app's back handler** and abandoned a battle in progress, losing it. Commit SpinBox
   edits with `KEYCODE_ENTER` alone. Also: swiping to scroll over a focused SpinBox types
   the gesture into it (the field became `4pp pp`) — scroll on the drawer's left edge,
   away from inputs.

### Gates after the T9-46b fix

`test_rival_ambush_replaces_the_job` **18/18** · `test_battle_journal_handoff` 8/8 ·
`test_zone_job_opposition` 7/7 · `test_departure_obligation_p82` 12/12 ·
`test_touch_scroll_opener` 7/7 (**52 cases, 0 failures**) · all six gating lints exit 0 ·
`--headless --import` parse clean.


---

## Aug 13 2026 — T9-47/48/49/50 worked (the deploy-#10 backlog, closed)

All four rows logged during deploy #10, investigated and fixed. Three turned out to be
more serious than the screenshots suggested; one changed shape entirely once the book
was consulted.

### T9-47 — the discard dialog was a DATA bug, not a display bug (FIXED)

The item-discard dialog labelled its button with a whole serialized Dictionary, which
read as cosmetic. It was not: **the label IS the identifier.** It is bound into the
button's callback, becomes `_outcome["discarded_item"]`, and is handed to
`CrewTaskComponent._remove_from_crew_equipment()`, which matched with
`if item_name in equip` — a String tested against Dictionaries. Never equal, so the
erase never ran.

**PROVEN AGAINST THE PULLED SAVE, not inferred.** Zephyr Flynn's `equipment` array is
byte-identical before and after a "Bad fight - lose one item" event:

```json
[{"condition":"damaged","id":"military_rifle_3495_8386","name":"Military Rifle",
  "owner":"Zephyr Flynn","quality_modifier":-1.0,"source":"shared_pool",
  "source_table":"crew_base","type":"Weapon"}]
```

Every p.82 item loss routed through this dialog was unenforceable. The array legitimately
holds EITHER shape — plain names (what `Character.to_dictionary()` emits) or full item
Dictionaries (what a live save carries) — and the two-shape rule was already written
correctly at ONE site (`CrewTaskEventDialog.gd:725`, the loot summary) and nowhere else.
That line is now `CrewTaskEventDialog.item_display_name()`, the single source used by the
discard, sell, trade and loot lists, and by the matcher — so the item removed is exactly
the one the player clicked.

Fixed sites: discard list, sell list (its checkbox text IS what `sold_items` collects),
trade list, loot outcome lines, and `_remove_from_crew_equipment` (now index-based, and
removes ONE entry — "lose one item" means one, even with duplicates).

`tests/unit/test_crew_task_item_loss_applies.gd`, 8 cases, built on the verbatim device
item. Detection-proven: restoring the old `in`/`erase` matcher fails exactly the three
Dictionary-shaped removal cases while the plain-String case still passes — which is
precisely why this survived so long.

### T9-48 — a prohibition rendered as a modifier (FIXED)

Core Rules p.91 verbatim: "**Ambush** — You can deploy one crew member less than standard
(5 in a typical campaign) for this fight, **and cannot roll to Seize the Initiative**."

The device showed the header "Cannot Seize the Initiative" and, two blocks above, a live
"Need 8+ on 2D6 (Savvy +2) — 42% chance". The 8+ is the normal 7+ with the Rival -1
applied, so it read as a HARDER roll rather than NO roll — the most convincing possible
wrong answer.

The rule was never missing. `BattleSetupRules` computes `can_seize_initiative = false`
(:288) with the p.91 citation, `CampaignTurnController` carries it into
`mission_data["initiative_context"]` alongside a ready-made reason string (:1371-1373),
and `InitiativeCalculator` honours it (`_set_seize_forbidden`, :218-236). **`PreBattleUI`
read `required_roll` / `highest_savvy` / `success_probability` out of that same
dictionary and never looked at `can_seize`.** Fixed to render the reason instead of a
roll, in the screen's own warning amber.

⚠ **The rule: whenever two surfaces show one mechanic, BOTH have to read the flag that
gates it.** One consumer honouring it is not coverage.

### T9-49 — TWO keys answering "did you win", and p.91 applied to only one (FIXED)

Filed as "a win journalled as a defeat". The book reframed it. Core Rules p.91:
"**There is no Win condition against Rivals**, but if you Hold the Field, you have an
increased chance of permanently chasing them off." p.92 says the same of an Invasion.

So `success = false` on a Rival battle is **correct and deliberate** — `TacticalBattleUI`
forces it (`_has_no_win_condition()`, :5997) and `PaymentProcessor` depends on it for the
p.120 payment gate. Two real defects sat on top of that:

1. **The record called it a defeat.** `"victory" if mission_successful else "defeat"` has
   no third branch, so every Rival and Invasion battle was stamped `defeat` however well
   it went — the observed entry said `"battle_result": "defeat"`, mood `defeat`, and
   `"Battle vs ... - Defeat | Objective: Access (achieved)"`, contradicting itself inside
   one entry. Now `PostBattleCompletion._outcome_word()` returns the book's own
   vocabulary: **"held the field"** or **"withdrew"**. Values stay human-readable because
   they print raw into the Encounter Log's result box (`SheetDataContext.gd:622`) and,
   via `.capitalize()`, into the description. `_determine_battle_mood` matches only
   victory/defeat and correctly falls through to `neutral`.
2. **The W/L tally counted it as a WIN.** `CampaignTurnController:2103` reads
   `battle_results["victory"] or ["won"]` — which `TacticalBattleUI` writes UNGATED at
   :6001-6002, right beside the gated `success`. Measured: one Rival ambush moved the
   dashboard 4W→5W while its own journal said defeat.
   ⚠ **`battles_won` is RULES-BEARING**: `VictoryChecker` reads it for the p.64
   conditions "**Win 20 / 50 / 100 tabletop battles**" (verbatim, PDF p.64). Counting an
   unwinnable battle advances a victory condition the player did not earn. Such a battle
   now moves NEITHER counter; `missions_completed` still increments, because the battle
   WAS fought — it simply has no W/L to record.

6 cases added to `tests/unit/test_battle_journal_handoff.gd` (14 total). Detection-proven:
restoring the two-branch expression fails exactly the three no-win-condition cases while
the ordinary victory/defeat guards keep passing.

### T9-50 — the resume lost the player's accepted job (FIXED)

Resuming a checkpoint at Step 6/6 rendered "Objective: Unknown / Enemy: Unknown / Pay: 0"
while the save still held the whole job elsewhere. `_refresh_mission_prep()` reads the
mission from `job_offer_component.get_accepted_job()` **and nowhere else** — pure
in-memory state — and `save_checkpoint()` builds `_checkpoint_data` from a FIXED KEY
LITERAL (`current_step` / `step_completed` / `world_phase_data` / `automation_enabled` /
`turn_number` / `timestamp`) that never named the job. So the resume rebuilt the
component empty. Not merely a blank briefing: the accepted job was gone.

⚠ **The tempting fix is wrong.** Falling back to `world_phase_results.mission_data` would
show TURN 2's job on a turn-3 resume, because that key is written at phase COMPLETION. A
stale mission presented as the current one is worse than a blank one. The job has to be
in the checkpoint.

`JobOfferComponent.restore_step_results()` is now the inverse of the existing
`get_step_results()`, and the checkpoint stores that bundle rather than re-listing its
fields (which is how the literal drifted in the first place). Pre-fix saves carry no
`job_offers` key, restore to `{}`, and are no worse off than today.

`tests/unit/test_world_phase_checkpoint_keeps_the_job.gd`, 6 cases. Detection-proven:
neutering `restore_step_results` fails the round-trip case.

### Gates

`test_world_phase_checkpoint_keeps_the_job` 6/6 · `test_crew_task_item_loss_applies` 8/8 ·
`test_battle_journal_handoff` 14/14 · `test_rival_ambush_replaces_the_job` 18/18 ·
`test_crew_task_legacy_save_keys` 10/10 · `test_job_offer_component` 17/17 —
**73 cases, 0 failures**. All six gating lints exit 0. `--headless --import` parse clean.

⚠ Tooling note: `-a tests/unit/test_job_offer_component.gd` produced NO OUTPUT AT ALL —
the suite lives in `tests/integration/phase4_world/`. A wrong `-a` path is a silent skip,
not an error. Always reconcile the number of `Statistics:` lines against the number of
suites requested.

### Still open from deploy #10

Nothing. T9-42 remains desk-verified (no 97-100 Explore roll came up in four attempts).
None of these four fixes has been exercised on hardware yet — they want a deploy #11 pass:
a Rival ambush (journal must read "held the field"/"withdrew", W/L must not move, the
Seize panel must state the prohibition), a "lose one item" event (the crew member must
actually lose it), and a mid-World-Phase quit/resume (the briefing must survive).


---

## Aug 13 2026 — T9-51: swept for the T9-47 CLASS downstream, found two dead p.130 events

Rather than hunt at random before the next deploy, the two defect classes proven on
hardware today were each swept as a class. Both sweeps were bounded and both are now
closed.

### Sweep 1 — "a rule computed into a bundle that nothing reads" (T9-48's shape): CLEAN

Census of all 21 keys `BattleSetupRules` writes, counting consumers OUTSIDE that file.
**Every key has at least one**, and each of the eight single-consumer keys resolves to a
real enforcement site, not a label:

| key | sole consumer |
|---|---|
| `crew_cap_delta` / `crew_cap_max` | `CampaignTurnController:1695` / `:1699` (deploy cap) |
| `early_leave_is_casualty` | `BattleRoundHUD:615` |
| `flee_before_round` | `PaymentProcessor:57` |
| `force_enemy_ai` | `CampaignTurnController:1277` — and it IS applied (:1278-1286); the `_ai_override` underscore is naming style, not a dead assignment |
| `panic_range_delta` | `TacticalBattleUI:5674` |
| `round_one` | `TacticalBattleUI:3720` |
| `setup_notes` | `PreBattleUI:255` — legitimately a display |

No further instances. T9-48 was the only one.

### Sweep 2 — "a name matched against an array that may hold Dictionaries" (T9-47's shape)

Checked and cleared first, so the finding below is not a guess:

- `Character.equipment` is `@export var equipment: Array[String]` (Character.gd:129) —
  **typed**, so a Dictionary cannot land there and the `weapons` / `items` getters
  (:230-246, which call `.to_lower()` per element) are safe.
- `EquipmentTransferService._set_member_equipment` already guards the typed case with
  `.assign(_as_string_array(...))` and documents why (:204-211).

So the class is confined to the SERIALIZED crew-member Dictionary, whose `equipment`
holds full item Dictionaries — which is what a save actually carries.

### T9-51 — two p.130 Character Events were dead on any saved campaign (FIXED)

`CharacterEventEffects._get_character_equipment()` returns both shapes. Two handlers
assigned an element straight into a String:

```gdscript
var damaged_item: String = equip_list[dmg_idx]     # :614  "Don't Make Them Like They Used To"
lost_item_name           = equip_for_loss[loss_idx] # :635  "Where Did It Go"
```

In Godot that is a runtime type error, which **ABORTS the enclosing function**. Silently —
the app keeps running, the event simply never happens: no status effect applied, no item
removed, no return text. For "Where Did It Go" the abort lands BEFORE the removal on the
following lines, so the item is neither lost nor recoverable and the p.130 "next turn
D6+Savvy 5+ = returns" roll never exists.

Crew members are canonically Dictionaries, so this is the COMMON case, not an edge:
**two of the thirty pp.128-130 Character Events did nothing on any campaign that had been
saved and loaded.**

Fixed with `_equipment_entry_name()`, the core-side sibling of the UI's
`CrewTaskEventDialog.item_display_name()` (deliberately not imported — core must not
depend on a UI dialog).

`tests/unit/test_character_event_item_effects.gd`, 7 cases, driving the real dispatcher
with the verbatim device item. Detection-proven: restoring the raw assignments fails
exactly the two dictionary-shape event tests **and reports 2 ERRORS** — the aborts
themselves — while the Array[String] regression guard keeps passing.

⚠ **The transferable rule: a typed local is an assertion about a shape you did not
check.** `var x: String = some_array[i]` reads as harmless and is a silent whole-function
abort the moment that array holds anything else. Grep
`: String = <array>[` before trusting any handler that touches equipment.

### Gates

`test_character_event_item_effects` 7/7 · `test_crew_task_item_loss_applies` 8/8 ·
`test_world_phase_checkpoint_keeps_the_job` 6/6 · `test_battle_journal_handoff` 14/14 ·
`test_rival_ambush_replaces_the_job` 18/18 · `test_character_event_effects_wiring` 14/14 ·
`test_character_event_crew_resolution` 3/3 — **70 cases, 0 failures**. Six gating lints
exit 0. `--headless --import` parse clean.


---

## Aug 13 2026 — DEPLOY #11: T9-50 was still broken on device, and the fix was mine

Build `0.9.7`, `lastUpdateTime 2026-08-13 20:44:59`. Verification pass over the six
fixes queued from deploy #10. **One genuine device finding, one book-verified non-bug,
and four fixes that this pass could not reach.**

### T9-50 — FAILED on device, root-caused, re-fixed (needs one more build)

The checkpoint half worked. Pulled from the device mid-World-Phase, the save contained
what the previous fix added:

```
checkpoint keys: [automation_enabled, current_step, job_offers, step_completed,
                  timestamp, turn_number, world_phase_data]
job_offers.job_accepted: True | selected_job_index: 0
job_offers.accepted_job.patron_name: "Reputable Contractor"  enemy: "Isolationists"  pay: 7.0
```

And the resumed briefing STILL read `Objective: Unknown / Enemy: Unknown / Danger Level:
0 / Location: Unknown / Pay: 0 credits`, on a cold force-stop + relaunch.

**Cause — ordering, and it was my own fix that was wrong.** `_setup_initial_state()`
runs, in this order:

```gdscript
restore_from_checkpoint()      # restored the accepted job (my fix)
_create_step_indicators()
_fetch_campaign_data()         # -> _initialize_components_with_data()
                               #    -> job_offer_component.initialize_job_offers(...)
                               #       REBUILDS the component, discarding it
_show_current_step()           # -> _refresh_mission_prep() -> get_accepted_job() -> {}
```

The restore was silently undone two lines later, and the symptom is **indistinguishable
from having no fix at all** — which is exactly why the data-layer check (job present in
the save) was not sufficient evidence.

Re-fixed by splitting the restore into `_restore_job_offers_from_checkpoint()` and
calling it AFTER `_fetch_campaign_data()`. The test now asserts the ORDER inside the
checkpoint branch (`_fetch_campaign_data` < restore < `_show_current_step`) rather than
the mere presence of the call — the previous anchor test passed while the feature was
broken, because presence was all it checked.

⚠ **Transferable: "the data is persisted" is not "the feature works."** A restore that
runs before re-initialization is worse than no restore, because it looks correct in the
save file.

### "Make a new friend" cannot be declined — NOT A BUG (book-verified)

Twice this pass the app appeared to hang on a Crew Task Event whose Continue button did
nothing. It was neither a hang nor a defect:

- `_on_continue_pressed()` returns early on `not _action_taken` ("Must take action
  first"), and only the simple event types auto-set that flag (:213-243).
- `EventType.RECRUIT` builds ONLY a "Recruit New Crew Member" button — no decline.
- Core Rules p.82 verbatim (PDF idx 80): *"19-21 **Make a new friend** — Roll up a new
  character and **add them to the crew**. If your character is Feral, the new character
  is also Feral."*

Mandatory in the book, so forcing the action is correct. **I did not "fix" the app out of
rules compliance**, which was the live risk here — the same discipline as the Feral
modifier row.

The first apparent hang also produced a false alarm worth recording: a zero-pixel diff
after a tap looked like a freeze, but the app was alive at 51.8% CPU and simply had the
button already in its pressed state. A later diff showed only the button's own rect
changing — which is what proved the app was rendering and the HANDLER was the thing
declining to act.

### Not reached this pass — T9-46b, T9-47, T9-48, T9-49, T9-51

All five need a specific random event that three world-phase walks did not produce:

- T9-46b / T9-48 / T9-49 need a **p.85 Rival ambush**. Walk 1 rolled no ambush; walk 2
  assigned the Decoy task, which grants "+1 to Rival avoidance roll per crew assigned"
  and actively worked against the test; walk 3 was lost to tap-coordinate drift after
  the page scroll position changed.
- T9-47 needs the Explore "lose one item" row; four Explore rolls across the pass gave
  Got yourself noticed / Make a new friend / Had a nice chat / Information broker.
- T9-51 needs one of two p.130 Character Events post-battle.

They remain **unit-verified and detection-proven** (each fails on isolated revert) but
**not device-confirmed**. Recorded as such rather than implied — a fix that has not been
seen working on hardware is not a verified fix, which is the whole lesson of T9-50 above.

### Device left clean

Real save restored byte-identically (38562 b, single Corporate rival, turn 2); QA
fixtures and `/data/local/tmp` scratch files removed.

### Gates

`test_world_phase_checkpoint_keeps_the_job` 7/7 (one new ordering case) ·
`test_character_event_item_effects` 7/7 · `test_crew_task_item_loss_applies` 8/8 ·
`test_battle_journal_handoff` 14/14 · `test_rival_ambush_replaces_the_job` 18/18 ·
six gating lints exit 0 · `--headless --import` parse clean.


---

## Aug 14 2026 — DEPLOY #12: T9-50 failed a SECOND time; there were two producers

Build `0.9.7`, `lastUpdateTime 2026-08-14 08:09:24` (confirmed newer than the
`WorldPhaseController.gd` edit at 2026-08-13 21:14:28, so the deploy #11 reorder WAS in
this APK). One deterministic check, run to a conclusion.

### T9-50 — FAILED AGAIN. Root cause: a SECOND caller of `initialize_job_offers()`

Deploy #11 fixed the ordering so the restore ran after `_fetch_campaign_data()`. On
hardware it still lost the job.

**The run.** Turn 3, walked Back from Mission Prep to Step 3 Job Offers, accepted the one
offer on the board — Patron "Reputable Contractor", Objective "Protect", Enemy
"Isolationists", pay 7cr (+3 danger), Danger Level 1, Hot Job hazard, Joffre VI. Step
strip went `1 2 3 4 ✓ 6` to `1 2 ✓ 4 ✓ 6`, both buttons greyed: accepted. Pressed Back to
Dashboard (one of only two `save_checkpoint()` triggers, the other being proceed-to-battle).

**The data half passed.** Save grew 38562 to 39513 b and the checkpoint on disk held:

```
checkpoint keys: [automation_enabled, current_step, job_offers, step_completed,
                  timestamp, turn_number, world_phase_data]
current_step: 2 | turn_number: 2 | turns_played: 2.0     <- not stale, will restore
job_offers: job_accepted=True selected_job_index=0 available_jobs=1
  patron_name=Reputable Contractor  job_type=Protect  enemy_type=Isolationists
  pay=7.0  danger_pay=3.0  danger_level=1.0  location=Joffre VI
```

**Force-stop, relaunch, Continue, Begin Turn 3 — and the job was gone.** Landed on the
right step (3 of 6, from `current_step: 2`) with two UNRELATED offers ("Eliminate +5cr",
"Fight Off +6cr"), Accept Job disabled, the step-3 checkmark cleared, and the blocker
"⚠ Accept a job offer (or decline all) to continue".

**Cause.** `initialize_job_offers()` has TWO callers, not one:

```
_setup_initial_state() checkpoint branch:
  _fetch_campaign_data()                  -> _initialize_components_with_data()
                                             -> initialize_job_offers()   PRODUCER #1
  _restore_job_offers_from_checkpoint()   -> restores the job             OK
  _show_current_step()                    -> _refresh_job_offers() (:1177)
                                             -> initialize_job_offers()   PRODUCER #2  CLOBBERS
```

`initialize_job_offers()` sets `job_accepted = false` unconditionally
(`JobOfferComponent.gd:200`). Deploy #11 ordered the restore against producer #1 and never
saw producer #2.

⚠ **This is the two-producer trap from Aug 13, repeated by me on the same feature.**
"I found the producer" is only true once you have COUNTED them. Ordering a fix against one
caller of a non-idempotent function is not a fix, it is a race you happen to lose.

**The fix is a guard, not more ordering** — and the idiom already existed six lines above
in the same file. `_refresh_rumors()` carries exactly this guard, with the comment "that
would wipe the player's rumor resolution on back-navigation". `_refresh_job_offers()`
never got the equivalent. It has one now: skip re-initialisation when
`get_accepted_job()` is non-empty. Order-independent, so a third producer cannot
reintroduce the bug.

### Bonus: this also fixes a plain back-navigation bug needing NO restart

Because `_show_current_step()` runs `_refresh_job_offers()` on every arrival at the step,
accepting a job, stepping forward, then pressing Back re-rolled the board and silently
discarded the acceptance. No app restart, no checkpoint involved. Observed directly this
session: arriving at Job Offers via Back produced a freshly rolled board every time.

Also worth recording: `initialize_job_offers()` is NOT idempotent beyond the flag. It
expires stale offers (`_fail_expired_job`) and CONSUMES `patron_offers_owed`
(`_consume_patron_offers_owed`). Calling it twice per step entry was spending p.77 offer
credit twice.

### Corrected non-finding: the "skipped World Phase" was an off-by-one in MY reading

I first read the resume landing on Step 6 of 6 as the whole World Phase being skipped on a
new turn. It is not a bug. `_current_campaign_turn()` reads `turns_played`, and
`CampaignTurnController` writes `turns_played = turn_number - 1`, so displayed Turn 3 means
`turns_played = 2`, which equals the checkpoint's `turn_number: 2`. The checkpoint belongs
to the current turn and restoring it is correct. `is_checkpoint_stale()` is internally
consistent because both sides use `turns_played`.

⚠ The checkpoint stamps a COMPLETED count while the UI shows that count plus one. Two
different numbers both called "turn". Anyone diffing a checkpoint against a screenshot will
be off by one every time.

The user's real save also carries a LEGACY checkpoint with no `job_offers` key at all;
resuming it restores to `{}` and renders the blank briefing, which is the documented
`test_an_empty_checkpoint_is_harmless` behaviour, not a defect.

### Tests

`tests/unit/test_world_phase_checkpoint_keeps_the_job.gd` 7 -> 10 cases. The three new ones
are BEHAVIOURAL on purpose: the previous anchor for this bug asserted a call was PRESENT in
the source and stayed green while the feature was broken.

- `test_re_initialising_clears_the_acceptance` — pins the hazard the guard exists for.
- `test_an_accepted_job_survives_arriving_at_the_step_again` — drives the real
  `_refresh_job_offers()`. ⚠ The controller MUST be added to the tree: detached, its
  absolute-path `/root/GameState` lookup ERRORS and aborts the function, so the job would
  survive for the wrong reason and the test would pass with the guard removed.
- `test_the_step_still_initialises_when_nothing_is_accepted_yet` — the guard must not break
  first arrival, when Crew Tasks may have turned up new patrons.

**Detection-proven by isolated revert** (file backed up with `Copy-Item`, never
`git checkout`): guard removed gives 10 cases / 2 failures, guard restored gives 10 / 0.
Case count identical both ways, so it is not a parse error masquerading as a pass.

### Gates

7 suites requested, 7 executed, **78 cases, 0 failures** —
`test_world_phase_checkpoint_keeps_the_job` 10 · `test_crew_task_item_loss_applies` 8 ·
`test_character_event_item_effects` 7 · `test_battle_journal_handoff` 14 ·
`test_rival_ambush_replaces_the_job` 18 · `test_job_offer_component` 17 (unchanged by the
guard) · `test_world_phase_data_merge` 4. Six gating lints exit 0.
`--headless --import` parse clean.

### Device left clean

User's real save restored and verified BYTE-IDENTICAL by SHA256
(`99418F2807714F76140D850E5CCCDA587EDDF0A78C0BD95552864260C6ABF8B9`, 38562 b).
`/data/local/tmp` scratch files removed.

### Still not device-confirmed

The `_refresh_job_offers()` guard itself, plus T9-46b / T9-47 / T9-48 / T9-49 / T9-51 from
deploy #11 (each needs a specific random event that has not come up in five world-phase
walks). All are unit-verified and detection-proven. Given T9-50 has now failed on hardware
TWICE after passing every desk gate, that distinction is the point, not a formality.

---

## Aug 14 2026 — CORRECTION to the deploy #12 entry above: producer #2 was NOT the cause

The section above names `_refresh_job_offers()` (producer #2) as the T9-50 cause. **That is
wrong.** It is a real and separate bug, now fixed, but it does not explain T9-50. Verified
before re-deploying, at the user's insistence, on the SAME build.

### The experiment that disproved it

Producer #2 is only reachable at the JOB_OFFERS step — `_show_current_step()` calls
`_refresh_job_offers()` only when `current_step == JOB_OFFERS`. At MISSION_PREP it calls
`_refresh_mission_prep()` instead. So resuming a checkpoint stamped at MISSION_PREP is a
clean control: if producer #2 were the cause, that resume would work.

Built exactly that checkpoint on device (accept job -> Confirm Equipment -> Next -> Next ->
Back to Dashboard):

```
current_step: 5 (MISSION_PREP) | turn_number: 2 | turns_played: 2.0
job_accepted: True | idx: 0
accepted_job: Reputable Contractor | Isolationists | pay 7.0
```

In-session control BEFORE the restart: briefing read "Objective: Protect / Enemy:
Isolationists / Danger Level: 1 / Location: Joffre VI / Pay: 7 credits". Correct.

After force-stop + relaunch + resume: **"Objective: Unknown / Enemy: Unknown / Danger
Level: 0 / Location: Unknown / Pay: 0 credits"** — blank, with producer #2 unreachable.

### The actual cause: `initialize_world_phase()`, a THIRD producer on a path `_ready()` cannot see

`initialize_world_phase()` (:892) is the orchestrator entry point. Its own comment
(:900-902) records that **CampaignTurnController SHOWS this controller each turn rather
than re-creating it**, so it runs AFTER `_ready()` has already restored:

```
_ready() -> _setup_initial_state() -> checkpoint branch
     _fetch_campaign_data() -> _initialize_components_with_data()      [P1]
     _restore_job_offers_from_checkpoint()          <- restores, correctly
     _show_current_step() -> _refresh_mission_prep()  <- briefing CORRECT at this instant

CampaignTurnController -> initialize_world_phase(ship, crew, world_data)
     _generate_turn_world_event()                    <- world event re-rolls
     _initialize_components_with_data()              [P3, UNCONDITIONAL at :961]
         initialize_job_offers()      -> job_accepted = false
         initialize_mission_prep(world_phase_data.get("mission", {}))
                                      -> {} -> BRIEFING BLANKED
     if not has_checkpoint(): reset + _show_current_step()   <- SKIPPED (checkpoint valid)
                                                             so nothing re-renders
```

Two details make this invisible to the obvious reading. `world_phase_data["mission"]` does
not exist — the mission lives in `job_offer_component.get_accepted_job()` — so MissionPrep
is re-initialised with `{}`. And the `if not has_checkpoint()` guard means the very case
that needs a re-render is the one that does not get one.

**The corroboration was already in the screenshots and I misread it.** The world's Current
Event changed across the resume, "A supply glut drops market prices by 20%" ->
"Nothing notable happens this turn". `_generate_turn_world_event()` is the only thing that
rolls it and `initialize_world_phase()` is its only caller. That was proof this function
ran after the restore, sitting in a capture I had already looked at.

**Fix**: `initialize_world_phase()` now early-returns on the fresh-turn branch and, when a
valid checkpoint exists, re-adopts the job and re-renders the step.

### Both fixes stand, and they are independent

- `initialize_world_phase()` re-adopt — **the actual T9-50 fix**.
- `_refresh_job_offers()` guard — a genuine separate defect: accept a job, step forward,
  press Back, and the board re-rolled the acceptance away. No restart, no checkpoint.
  Also stops `initialize_job_offers()` double-spending `patron_offers_owed` per step entry.

Reverting either fails only its own test, with the other 11 green.

### ⚠ The transferable rule, third time of asking

**A fix ordered against SOME callers is not a fix.** Three attempts:

1. Ordered against `_initialize_components_with_data()` via `_fetch_campaign_data()` — failed.
2. Ordered against `_refresh_job_offers()` — failed.
3. Handled the orchestrator entry point — the one `_ready()` cannot see.

`grep "initialize_job_offers"` returns three call sites in one file. Counting them first
would have found this on day one. And when a screen is REUSED rather than re-created
between turns, `_ready()` is not the whole initialisation story — find the orchestrator
entry point and read it before reasoning about ordering at all.

### Tests

`test_world_phase_checkpoint_keeps_the_job.gd` 10 -> 12 cases.
`test_the_orchestrator_entry_point_does_not_destroy_a_restored_job` drives the real
`initialize_world_phase()` over a live checkpoint; `test_a_fresh_turn_entry_still_resets`
pins that the new early-return does not swallow the reset path.

⚠ Fixture trap worth remembering: `has_checkpoint()` DISCARDS `_checkpoint_data` as a side
effect when `turn_number` differs from `_current_campaign_turn()`, so a hardcoded turn
number silently emptied the checkpoint and the test failed with the fix IN. The fixture now
takes the turn from the controller at runtime.

Detection-proven by isolated revert (backed up with `Copy-Item`, never `git checkout`):
12 cases / 1 test failing reverted, 12 / 0 restored.

### Gates

6 suites requested, 6 executed, **64 cases, 0 failures** —
`test_world_phase_checkpoint_keeps_the_job` 12 · `test_job_offer_component` 17 ·
`test_world_phase_data_merge` 4 · `test_world_phase_effects` 16 ·
`test_crew_task_item_loss_applies` 8 · `test_character_event_item_effects` 7.
Six gating lints exit 0.

### Status

**NOT device-confirmed.** Both fixes are desk-verified and detection-proven; the T9-50 fix
has now been wrong twice, so it needs the same Mission-Prep resume check run against a new
build before anyone calls it done. The check is deterministic and takes about five minutes.

---

## Aug 14 2026 — DEPLOY #13: T9-50 VERIFIED ON HARDWARE. Closed.

Build `0.9.7`, `lastUpdateTime 2026-08-14 10:34:17`, newer than the
`WorldPhaseController.gd` fix at 10:21:43 — the fix is in this APK.

### T9-50 — PASSES (third fix, first hardware pass)

Deterministic check, no dice involved.

1. Walked back to Step 3 Job Offers, accepted "Protect (regular) - +7 cr" —
   Patron **Reputable Contractor**, Enemy **Isolationists**, Danger 1, Joffre VI.
2. Confirm Equipment -> Next -> Next -> Step 6 Mission Prep. **In-session control:**
   "Objective: Protect / Enemy: Isolationists / Danger Level: 1 / Location: Joffre VI /
   Pay: 7 credits". Correct.
3. Back to Dashboard. Checkpoint on disk verified:
   `current_step: 5 | turn_number: 2 | turns_played: 2.0 | job_accepted: True |
   Reputable Contractor | Isolationists | 7.0`
4. **Force-stop, relaunch, Continue, Begin Turn 3.**

**RESULT: "Objective: Protect / Enemy: Isolationists / Danger Level: 1 / Location:
Joffre VI / Pay: 7 credits"** — byte-for-byte the pre-restart briefing.

The two previous builds failed this exact check. T9-50 is CLOSED.

### The back-navigation guard — also PASSES

Second, independent fix, verified in the same run. From the resumed Mission Prep, walked
Back three steps to Job Offers: the board still showed the SAME
"Protect (regular) - +7 cr - Any time" with **Reroll Jobs and Accept Job both greyed** —
the acceptance held.

On the deploy #12 build this identical action produced a re-rolled board
("Eliminate +5 cr", "Fight Off +6 cr") with Accept Job ENABLED and the step's checkmark
cleared. The two states are visually unambiguous, so this is a discriminating check and
not a pass-either-way one.

### What actually fixed it, for the record

Neither of the first two fixes. The cause was `initialize_world_phase()` (:892), the
orchestrator entry point that `CampaignTurnController` calls AFTER `_ready()` has already
restored the checkpoint, re-running `_initialize_components_with_data()` unconditionally
and blanking both the job and the MissionPrep briefing — with its `if not has_checkpoint()`
guard skipping the `_show_current_step()` that would have repaired it.

Full disproof and mechanism in the correction section above.

### Device left clean

Real save restored and verified BYTE-IDENTICAL by SHA256 (38562 b). App-written `.bak`
removed (did not exist before this session). Screen timeout restored to 120 s.
`/data/local/tmp` scratch cleared.

### Status of the queue

| Row | State |
|---|---|
| T9-50 checkpoint resume | **VERIFIED on hardware** |
| `_refresh_job_offers()` back-nav guard | **VERIFIED on hardware** |
| T9-46b, T9-47, T9-48, T9-49, T9-51 | unit-verified + detection-proven, **awaiting the random event that triggers each** |

---

## Aug 14 2026 — DEPLOY #13b: T9-46b and T9-49 VERIFIED by FORCING the p.85 roll

Same build (`lastUpdateTime 2026-08-14 10:34:17`). Rather than wait on dice, the p.85 check
was made DETERMINISTIC with a save-file fixture.

### The fixture: 6 Rivals makes the p.85 roll unlosable

`RivalEncounterCheck.check()` rolls D6 and fires on a result <= the Rival count
(`CampaignTurnController:496-531`, reading the canonical `campaign.rivals`). Six Rivals
means D6 <= 6, i.e. **every turn**. Built by editing the pulled save:
`resources.rivals` + `crew.rivals` = 6 entries, **all typed `Corporate`**, which is not a
valid enemy type — so the T9-46b validator MUST reject it and stamp the generated enemy
instead. A fixture that could have passed either way would have proved nothing.

Fired first attempt: **"Rival Attack: Karn Brokerage — has tracked you down (Core Rules
p.85). Straight-up fight. No modifications."**

### T9-46b — VERIFIED

Journal, turn 3:

```
type battle | mood neutral | title 'Battle: Joffre VI'
desc  'Battle vs Tech Zealots - Held The Field'
stats enemy_type "Tech Zealots" | enemy_count 4 | enemy_category "interested_parties"
      deployment_condition "Bitter Struggle" | loot_earned 1 | notable_sight present
```

`enemy_type` is the GENERATED enemy, not the Rival's bogus `Corporate` and not `Unknown`.
The deploy-#10 regression (erasing the invalid type left the journal recording
"Battle vs Unknown" forever) is closed. Contrast the turn-2 entry written by the older
build in the same save: `'Battle vs Mutants - Defeat'`.

### T9-49 — VERIFIED, both halves

PreBattleUI stated the precondition outright: *"HOW YOU WIN: There is no Win condition
against Rivals — Hold the Field to improve your chance of chasing them off (p.91)."*

1. **The counter did not move.** Campaign Cycle Summary after the battle:
   `Battles 4W / 0L` (unchanged from the pre-battle baseline) while
   `Missions Completed` went **4 -> 5**. Persisted save agrees:
   `battles_won 4.0 | battles_lost 0.0 | missions_completed 5.0`.
   The ledger records this exact situation moving 4W -> 5W on the previous build.
2. **The journal used the book's vocabulary**, not victory/defeat:
   `battle_result: "held the field"`, description "Held The Field", `mood: neutral`.
   That is `PostBattleCompletion._outcome_word()` working.

### T9-48 — HALF verified

The non-prohibition branch renders correctly: a normal battle showed
**"Need 7+ on 2D6 (Savvy +2) — 58% chance"** and the Rival Showdown showed
**"Need 8+ ... 42%"** (7+ with the p.91 Rival -1). Correct percentages, so the old
double-scaling bug ("4167%") is gone.

The PROHIBITION branch still needs a Rival **AMBUSH**, which is `roll_range [1,1]` on a D10
(`data/mission_tables/rival_involvement.json`) — 10% per ambush, and per
`CampaignTurnController:1370` it is the only scenario in the battle chapter that forbids the
roll. Not reached. **Forcing it would require widening that roll_range, which the user
declined** (correctly — it means testing a build whose rules data differs from ship).

### T9-47 / T9-51 — not reachable through sanctioned tools

Both need a specific table row that no in-app tool can force:

- T9-47: "Gambling problem" (`exploration_events.json` roll 51-53) or "A chance to unload
  some stuff" (`trade_results.json` 76-78).
- T9-51: character event D100 88-94 (`character_events.json`).

QA scenarios (`QAScenarioLoader`) apply counters / DLC / compendium progress / crew patches
/ narrative (rivals, patrons, quest). The Campaign Editor sets scalars (turn, credits,
supplies, story points, reputation, debt, red-zone turns, salvage) plus crew. **Neither
touches a table roll**, and `MissionTableManager` uses bare `randi_range()` with no
injectable dice seam. Left on their detection-proven unit tests.

### ⚠ Two wrong calls I made during this run, both corrected

1. **"Ready for Battle" is not the battle launcher.** It COMPLETES the Mission Prep step;
   a separate green **"Proceed to Battle"** button then appears at the BOTTOM of the page,
   below the fold. I read the greyed button + dimmed card as a stuck transition and chased
   it across three runs, including a control on the original save. There was never a defect.
   A pixel-diff showing "nothing changed" told me the screen had SETTLED — I read it as
   "hung" instead of "settled, look elsewhere on the page".
2. **CPU is not evidence without a baseline.** I called ~55% CPU a busy loop. Measured
   afterwards: this app idles at **32% on the main menu and 37% on the dashboard**, with CPU
   time climbing steadily (Godot renders continuously). 55% is unremarkable. Take the
   baseline BEFORE citing a number as anomalous.

### Device wrangling notes worth keeping

- **`KEYCODE_WAKEUP` does not turn this panel on; `KEYCODE_POWER` does.** Swipes sent to a
  dark screen do nothing, so the unlock silently fails. Check
  `dumpsys display | grep mScreenState` and only then swipe.
- Launching the app against an off screen fails hard:
  `ERROR: Failed to create vulkan window. Unable to create DisplayServer` — the process
  runs with no rendering surface and the screen stays black. Not a save-file problem.
- `wm dismiss-keyguard`, `cmd statusbar collapse` and short swipes all failed; a long swipe
  (1280,1450 -> 1280,250 over 400ms) with the panel confirmed ON worked.
- `adb logcat` returns nothing for this app on this device; `user://logs/godot.log` via
  `run-as` is the only usable log, and it captures engine errors but rotates on launch.

### Device left clean

Real save restored, verified BYTE-IDENTICAL by SHA256 (38562 b). App-written `.bak`
removed. Screen timeout restored to 120 s. `/data/local/tmp` cleared.

### Status

| Row | State |
|---|---|
| T9-50 checkpoint resume | **VERIFIED on hardware** (deploy #13) |
| `_refresh_job_offers()` back-nav guard | **VERIFIED on hardware** (deploy #13) |
| T9-46b enemy-type stamping | **VERIFIED on hardware** |
| T9-49 no-win-condition W/L + journal wording | **VERIFIED on hardware** |
| T9-48 Seize display | normal branch verified; **prohibition branch unreached** (needs D10=1) |
| T9-47, T9-51 | unit-verified + detection-proven only; no tool can force the roll |

---

# Deploy #14 — 2026-09-04 — battle-phase sprint walk (plan step 5)

**Device**: Lenovo TB361FU, 1600x2560 physical @ density 320 = **800x1280 dp**.
**Build**: commit `92466e57a`, debug APK.
**Screenshots**: `screenshots/tablet-2026-09/` (14 kept); full set + the raw
findings file in the session scratchpad.

## ⭐ The deploy route changed: CLI export WORKS

The standing claim that CLI `--export-debug` is "blocked by the engine's autoload
bug (336 `Identifier \"Talo\" not declared`)" is **wrong about causation**. The
Talo lines are the benign autoload artifact this repo already documents for
`--check-only`, and they are printed **after** the failure. The real error is
line 49 of 395:

```
ERROR: Export: Invalid filename! Android App Bundle requires the *.aab extension.
ERROR: Project export for preset "fiveparsecsfromhometest" failed.
```

`export_presets.cfg` sets `gradle_build/export_format=1` (**AAB**) while
`export_path` says `.apk`. Set `export_format=0` and it builds a valid 60 MB APK
(`scripts/verify_apk.py` PASS) that installs and runs clean. Editor Remote Deploy
always builds an APK regardless of that field, which is why the two paths never
agreed. **Gradle takes >10 min cold — background it, and check for the file
rather than trusting a timeout.** Control: `--headless --import` emits **0** Talo
errors on the same project. See `reference_cli_android_export_is_not_talo_blocked`.

## Verified FIXED / not reproduced

| Item | Evidence |
|---|---|
| **T5-04** blank Mission Prep briefing | Renders Objective/Enemy/Danger/Location/Pay in full (`22_step6.png`) |
| **T5-03** "Proceed to Battle" below the fold | Appears in the FIXED footer, fully visible (`23_ready.png`). "Ready for Battle" greying out is correct — it completes the step |
| Aug #6 equipment empty after Load | Crew show 2/2/1/1/1/1 items, stash lists 6 with `[DAMAGED]` flags |
| Aug #2 Android BACK quits the app | Did NOT reproduce — BACK returned to the dashboard correctly |
| **Phase 1** entry sequence | Battle Card + p.110 deployment card + checklist + fixed Begin Battle, all at **LOG_ONLY**, which previously saw none of it (`25_battle_entry.png`) |
| **Phase 2** reaction roll | "Start Quick Actions" (the control that used to SKIP the roll) now rolls and does **not** advance; button becomes "Continue to Quick Actions". Pool `[3,4,2,1,3,1] → 3 Quick · 3 Slow`, die ≤ Reactions, book-correct (`29_rolled.png`) |
| **Phase 2** seize | Pre-battle "Need 8+ on 2D6 (Savvy +2) — 42%" = P(2D6≥8) = 15/36 exactly |
| **T5-05** feed round tag | `[R0]` for deployment, `[R1]` for round events — correct |
| **Phase 3** no hit points | No HP bar, no "x / y HP" on any card; "Hit" has replaced "Damage" |
| **Phase 5** tier copy + persistence | The three SSOT descriptions render verbatim; only 3 radios (the duplicate-card fix holds) |
| **Phase 6** Record Result | Persistent green button in the app bar, not a popup entry |
| **Phase 8** coach marks | Auto-ran on first combat, advance correctly, target the right nodes |
| Phase 1 bonus (objective counter) | Enemy pill tracked 6 → 5 → 2 as figures were marked down |
| Errata "Lay Low (pay 1D6+1 cr)" | Live and visible on the Mission Prep footer |

## New findings — 11, ledger `T10-01`..`T10-11`

| ID | Severity | Summary |
|---|---|---|
| T10-11 | **BLOCKER** | World Phase has **no navigation footer** when entered via dashboard "Begin Turn 21" — no Next Step/pips/Back. Campaign cannot advance. Present on the Load-Campaign entry path, absent on the Begin-Turn path |
| T10-06 | HIGH | **Phase 4 battle checkpoint does not survive process death** — `active_battle` is never written to disk (`grep` on the live save = 0). Desktop "resume" passed because it re-entered in the same process |
| T10-05 | HIGH | **Every control inside `CharacterStatusCard` is dead to touch** in a drawer (Stun/Hit/Aim/Snap/?). `Mark Down`, added directly to the drawer body, works — so all of Phase 3 is unreachable on the launch platform |
| T10-04 | HIGH | Mark Down confirm opens on OverlayLayer **L10, behind DrawerLayer L92** — dimmed screen, nothing to tap |
| T10-09 | HIGH | Touch-drag scroll dead again in the landscape World Phase. Control: content drag = **0 px** changed, scrollbar drag = **1,442,658 px** |
| T10-03 | HIGH | Patron job card shows a **fabricated objective** ("Secure") that battle setup then correctly re-rolls (rolled Protect). Core Rules p.89 step 5 says Patron missions roll for the objective; p.83 gives a job no objective. The player builds the wrong table |
| T10-10 | MED-HIGH | World "CURRENT EVENT" shown ≠ persisted. Save holds "Worker shortages"; screen showed "Pirate raids". It is a live rules modifier |
| T10-01 | HIGH | Crew Tasks "Resolve without them?" dialog renders **completely empty** — 900,000 px of one luminance value. Asks the player to confirm an irreversible action with zero information |
| T10-02 | LOW-MED | `⚔` has no glyph in Montserrat; the primary confirm reads as a cancel **✗**. 5 sites incl. the rivals counter |
| T10-07 | LOW | Two exclusive dialogs stack on campaign load (`DLCRequirementDialog.gd:34`) |
| T10-08 | LOW | "Undo Mark Down" persists after the confirm is **cancelled** |

## Not completed, and why

- **Enemy-drawer touch-drag scroll in landscape** (the plan's explicit item) is
  **blocked by T10-11** — after the first battle no further battle can be reached.
  Partial coverage: in PORTRAIT the enemy drawer does not overflow at 800x1280 dp
  so there is nothing to scroll, and the same gesture mechanism was measured
  broken on the landscape World Phase (T10-09) with a scrollbar control.
- Four Mark Downs WERE performed (6 → 2 enemies) before the drawer test.

## Method notes worth keeping

- `adb` is a Windows binary: give it `C:/...` paths, not Git Bash `/c/...`.
  Push into the app sandbox via `/data/local/tmp` + `run-as cp`.
- A byte-identical screenshot pair is the cheapest "did that control do anything"
  test there is, and md5 beats eyeballing. But **pair it with a control** — three
  times here a dead-looking control was my own bad coordinate, and once ("Hit")
  the control (`Mark Down`, same drawer) is what turned it into a real finding.
- Locate buttons by colour/text bbox from the screenshot before tapping; blind
  coordinate arithmetic cost several wasted taps.

---

# Deploy #15 — 2026-09-04 — the two open gaps, T10-09 and T10-02

Lenovo TB361FU, 1600x2560 @ density 320 = 800x1280 dp, **landscape**
(`user_rotation 1`). CLI `--export-debug` APK, verified with `scripts/verify_apk.py`
(PASS, 2416 entries). Working tree on top of `92466e57a`.

**Both findings were misdiagnosed in deploy #14, and both diagnoses are now
corrected by measurement.** Neither correction was reachable by reading code —
one needed a cmap parse, the other needed instrumentation on the device.

## T10-09 — NOT A DEFECT. It was my measurement.

**Deploy #14 recorded:** *"swipe over the CONTENT -> 0 pixels changed; swipe over
the SCROLLBAR -> 1,442,658 pixels changed. So the scroll range EXISTS and only
the drag-over-content path is broken."*

**Deploy #15 measures, with `ScrollContainer.scroll_started` (an Android-only
signal that fires ONLY for a touch drag on the scrollable area, never for the
scrollbar — Godot 4.6 docs):**

```
[TouchChainProbe:WorldPhase] touch #1 at (1103, 1077)
  scroll ContentScroll  v=0  max=1341 page=1173  scrollable_span=168
  under the finger, DEEPEST FIRST:
    IGNORE  Label / PASS HBoxContainer / PASS VBoxContainer
    PASS    PanelContainer  WorldBriefingCard
    PASS    VBoxContainer   PhaseContentVBox
    IGNORE  ScrollContainer PhaseScroll
    PASS    PanelContainer  PhaseContainer
    PASS    ScrollContainer ContentScroll
[TouchChainProbe:WorldPhase] scroll_started on ContentScroll — THE GESTURE ARRIVED
```

The gesture arrives. The chain is clean. **The scrollable span is 168 px** — the
content overflows by almost nothing — and after that one swipe `v=168`, i.e. the
scroll was already at its maximum.

**What actually happened in deploy #14:** the content swipe was
`1280 1250 -> 1280 450`, i.e. UPWARD (scrolling toward the bottom). The
"control" scrollbar drag was `2470 600 -> 2470 1100`, i.e. DOWNWARD (scrolling
back to the top). If the view was already at the bottom, the first has nothing
left to travel and the second has the whole range. **I compared an exhausted
direction against a fresh one and called the gesture dead.**

Verified today in BOTH directions and on BOTH steps:

| Step | span | content drag up | content drag down |
|---|---|---|---|
| 2 of 6 (Crew Tasks) | 168 px | scrolls, `scroll_started` fires | returns to a **byte-identical** screenshot (md5 `5f5eeb60`) |
| 1 of 6 (Upkeep) | 414 px | scrolls, `scroll_started` fires | — |

The nav (`1 2 3 4 ✓ 6`, `← Back`, `Next Step`, `← Back to Dashboard`) is reachable
by that drag. **T10-09 is closed as NOT REPRODUCED.**

> **The rule:** a control test needs the control to differ in ONE variable. Mine
> differed in two — where the finger was AND which direction it travelled — so it
> could not distinguish "the gesture is blocked" from "this direction is spent".
> Same family as [[reference_a_bypass_walk_yields_false_and_real_findings]].

## T10-02 — the glyph was never missing; it is illegible at size

**Deploy #14 recorded:** *"U+2694 CROSSED SWORDS; Montserrat has no glyph, so it
falls back to a thin cross."* First half right, conclusion wrong.

**Desk evidence** — a format-4/12 cmap parse of all four bundled `.ttf`s:

| Codepoint | Montserrat Reg/Semi/Bold | CourierPrime |
|---|---|---|
| ⚔ ⚙ 💰 🌍 👤 👥 🚀 💾 | no | no |
| **✓ ✗ ★** | **no** | **no** |
| → | YES | no |

The load-bearing row is ✓ / ✗ / ★: deploy #14 lists those as *already proven to
render on this device*, and no bundled font has them. **So Android system
fallback is live** — which is exactly what `allow_system_fallback=true` in every
`.ttf.import` enables.

**Device evidence** — the Battle Simulator row on the Campaign Dashboard,
magnified 8x from a full-resolution screencap, is unmistakably **two crossed
blades with crossguards**. Not tofu. The ⚠ and ⚙ chrome glyphs render too.

So the defect is real but it is **legibility, not coverage**: at the button's
~16 px, monochrome, the thin strokes collapse into an ✗ on the green button that
STARTS a battle. Adding a `SystemFont` fallback — the fix deploy #14 implied —
would have changed nothing.

**Fixed** by removing the glyph from `WorldPhaseController.tscn`'s
`ProceedToBattleButton`, the only site where the pictograph inverts a control's
meaning. Pinned by `tests/unit/test_primary_cta_glyphs.gd` (2 cases), which reads
`PackedScene.get_state()` rather than scanning text, and is detection-proven:
restoring the ⚔ gives exactly 1 failure naming the node and codepoint.

## Shipped this deploy

- `src/ui/components/common/TouchChainProbe.gd` — debug-only (`OS.is_debug_build()`;
  `attach()` returns null in a release build). Dumps the control chain under the
  finger with each node's `mouse_filter`, lists hit-testable controls on higher
  CanvasLayers, reports every watched scroll's live span, and re-runs the
  idempotent touch sweep to report whether it was stale.
- `WorldPhaseController` wires it, watching `ContentScroll` and `PhaseScroll`.
- `test_primary_cta_glyphs.gd` (new, 2 cases) + a widened `_all_label_text()` in
  `test_destructive_actions_confirm.gd`.

## Method notes

- **`ScrollContainer.scroll_started` is the right instrument for this whole defect
  class.** It fires only for a touch drag on the scrollable area — never the
  scrollbar — and only on Android/iOS. It answers "did the gesture arrive" with a
  yes/no instead of a pixel-diff's "nothing moved".
- **A probe that over-reports invents work.** The first version swept the whole
  screen and announced "SWEEP WAS STALE — opened 2"; one of the two was the
  `Background` ColorRect, a sibling production deliberately never sweeps and which
  blocks nothing. It now takes an explicit `set_sweep_root()` so the verdict
  compares like with like.
- **A `--script` SceneTree probe cannot load these screens at all.** Autoloads are
  not registered there, so `WorldPhaseController.gd:1345`'s bare `TweenFX` fails to
  compile, `_ready()` never runs, and `tests/tools/probe_world_phase_drag.gd`
  reported "51 STOP controls AFTER THE SWEEP" against a tree the sweep had never
  touched. Whether a screen probes headlessly is decided by whether it names
  autoloads as bare identifiers or resolves them via `get_node_or_null("/root/X")`
  — nothing meaningful. **Discard that probe's numbers.**
- **Read the gdUnit4 case COUNT, not the failure line.** A batch reported 17 and
  25 cases with a "failure" that vanished at the full 28/30. The partial run was
  the artefact; the failure was not real.
- The tablet has a secure lock and re-dozes fast. `adb shell svc power stayon usb`
  first; a locked screen returns a 19,838-byte all-black screencap, which is the
  cheapest way to notice.
