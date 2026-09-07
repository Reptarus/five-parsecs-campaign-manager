# Tablet walk findings — deploy #19 (2026-09-05, versionCode 6, TB361FU HNQ05SR3)

Working list from the device walk. Evidence for each is a screenshot, a device log line,
or a pulled save file (all in the session scratchpad `walk19/`).

## VERIFIED PASS on hardware

| Item | Evidence |
|---|---|
| **T11-07** density double-count | 3 `[T11-07]` lines: `content_scale=0.7830` at boot, portrait and back, while `dpi` went **1.000 → 2.000**. Landscape frames before/after byte-identical (md5 `449ca051…`). Rotation confirmed at the window manager each time. |
| **T11-08** p.13 blurb | Card reads "Core Rules p.13 — how your crew are chosen" (the "six" is gone). |
| **T11-09** coercion | 7 Randomize All rolls, Standard + crew 4: never >2 Primary Aliens, never >1 Bot. Roll 6 (Feral + Bot + Human, Swift captain) hit **both** caps at once. |
| **T11-09** detection | Device log: `Standard Method: at most 1 Bot (p.13) - have 2`. |
| **T11-11** keyboard, BugReportDialog | `logical_vp_h=680.0 … field_bottom=519.0 shift=174.0`; field lifted clear, typed, layout restored on dismiss. The 680.0 is the control's OWN viewport (root is 1379.3) — proof the fix is live. |
| **T11-12** CaptainPanel | Info block vertically centred, empty and populated. |
| **T10-01** dialog autowrap | Unassigned-crew confirm wraps and is fully readable. |
| **T10-06** battle resume | Save carries `progress.active_battle` (17 keys, round 1, 6 crew); resumed "6 crew and 6 enemies restored". |
| **T9-47** BOTH halves ⭐ | Explore forced 51 → **"Gambling problem"** (51-53, discard 1 item), item discarded. Trade forced 76 → **"A chance to unload some stuff"** (76-78), **"Sold 1 weapon(s) for 2 credits"**. Was desk-only since Aug 14. |

### Added by the Sep 5 continuation (sheets, PDF, settings, legal)

- **Printable sheets — all three tabs render populated and legible on device.** Crew Log
  (SP 10, stash, credits, ship, all six crew with stats/XP), Encounter Log
  (`interested_parties` / Delayed / Move Through / Documentation / Salvage Team 6 /
  "Battle vs Salvage Team - Defeat"), World Record (Gamma Prime, High Cost, Licensing "No",
  two Rivals). **T11-06's source-coordinate field layer is holding on hardware.**
- **PDF export on the Android backend — VERIFIED PASS end to end.** Save PDF opened the
  Android **native file dialog** (T9-10's `use_native_dialog`, confirmed live) with a
  sensible default name, wrote `/sdcard/world_record_sheet_2026-09-05T13-28-49.pdf`
  (117,063 bytes), and PyPDF2 read it back: **1 page, 792 x 612 pt** (US Letter landscape,
  correct) with the invisible searchable text layer extracting all six populated values
  including the `X` in the Licensing "No" octagon. Read back with a library that did not
  write it, per the SOP.
- **T11-07 re-confirmed on a cold launch** — main menu in landscape shows all ten buttons
  with "Settings" fully on-screen, title unwrapped, intro text unclipped.
- **`legal_viewer` route works from the Main Menu** — the footer "Privacy" link and
  Main Menu -> Settings -> Privacy Policy both open the document, markdown -> BBCode
  rendering correct, and the `[DATE OF RELEASE]` / `[CONTACT EMAIL ...]` placeholders show
  as the deliberate ones the legal checklist documents. (It is only the paused in-campaign
  overlay that breaks it — T11-27.)
- **`LegalTextViewer` scrolls correctly by touch drag** (diff bbox 811,202-2522,1488).
  Worth recording because it was on T11-26's 48-screen exposure list: absence of the
  touch-scroll helper is NOT by itself the defect, which is exactly why that list is a
  probe queue and not a finding.
- **T11-04 VERIFIED FIXED on device, in portrait** — the configuration the fix was actually
  about. Rotated with read-back confirmation (`accelerometer_rotation=0`, `user_rotation=0`,
  `mCurrentRotation=ROTATION_0`, capture 1600x2560). The **Accessibility Settings** panel —
  whose hardcoded 600 px minimum was the first of the three stacked width drivers — now
  fits entirely: Visual Theme dropdown, Color Preview, Apply Theme, Reduce Animations and
  Font Size all render inside the viewport. A pixel scan of the last column over the full
  page height returns mean brightness **14.3** (pure background), so nothing is clipped at
  the right edge. Touch & Haptics is visible too.
- **Responsive collapse verified in portrait** — Manage Crew drops from a 3-column grid to
  a single column cleanly, no overflow, footer buttons still reachable.

## OPEN — found by this walk

**T11-17 (HIGH) — the battlefield is REGENERATED and overwritten on battle resume.**
Proven from the save, not pixels:
```
seed    before = 4055150519    after = 341922859
sectors EQUAL: False
A1      before: ["LINEAR: Natural feature (hedgerow or line of trees)", "Scatter: Small rock"]
        after : ["SMALL: Cluster of plants"]
```
`active_battle` (crew/enemies) restores correctly; only `active_battlefield` does not. The
new terrain was then SAVED OVER the old (file mtime 11:00 → 11:36). This contradicts
CLAUDE.md twice — *"survives save/reload"* and *"Full sectors persist — a generator code
change never rewrites an in-progress physical table"* — and `TacticalBattleUI` is
documented as "consume-first". For a tabletop companion this is the serious one: the
player has physically built that terrain, and the "resumed intact" message tells them
nothing was lost. Evidence: `save_before.json` / `save_after.json`.

**T11-19 (MED) — the forced-roll seam does not reach the post-battle Character Event.**
Queued `character event=[88]`; the Character Event resolved as *"Dex Kovac: Not the Same
Person"*, which is `roll_range [27,29]` in `data/campaign_tables/character_events.json`
(88-91 is "Don't Make Them Like They Used To"). Afterwards the queue still read
`[pending: rival attack type=[1], character event=[88]]` — the value was never consumed,
while `exploration table` and `trade table` were. So the seam works; this one path does
not consult it. ~~**T9-51 therefore remains unverifiable on device.**~~

> ⚠ **CORRECTED 2026-09-06 — that trailing verdict is now FALSE, and T9-51 is
> CLOSED on hardware.** T11-19 was fixed and re-verified on deploy #22 Pass C, and
> the same two cycles covered BOTH of T9-51's rows. See § Pass C "Re-confirmed in
> passing". The #19 observation above stands as written; only its forward-looking
> conclusion was overtaken.

**T11-15 (MED) — keyboard avoidance under-shifts in the QA dialog, hiding the field it
targets.** `shift=511.3` was computed but the dialog moved ~64 px, leaving the focused
SpinBox AND "Queue Roll" behind the keyboard. The documented "scrolling alone is not
enough" trap: `scroll_vertical += shift` clamps to the container's range and reports
success. Opposite outcome to T11-11 on the same code path, decided by available slack.

**T11-18 (MED) — Record Battle Result drawer clips its right edge in landscape.**
"Rounds foug[ht]" truncated and its SpinBox runs off-screen (stepper arrows unreachable);
"…removed from p[lay]", "…opposite table edg[e]" also cut. Confirmed settled (byte-identical
5 s apart) and every sampled pixel of the final screen column has content.

**T11-16 (LOW/UX) — dashboard gives no sign a battle is in progress.**
`Continue Campaign` → dashboard offering "Begin Turn 9" with no resume affordance, while
`Load Campaign` on the same save resumed straight into the battle. Pressing "Begin Turn 9"
does resume correctly (no data loss), so this is a labelling/affordance gap.

> ⚠ **CORRECTION (Sep 5, fixit sprint).** The second half of this row as first written —
> *"`game_phase` is absent from the save file entirely"* — is **WRONG**. It is
> `meta.game_phase = "active"` (`FiveParsecsCampaignCore.gd:420/627`); the original note
> read the TOP level of the save. That field is a lifecycle marker anyway and could not
> distinguish these two states. What does is the battle CHECKPOINT
> (`progress_data.active_battle`), and that is what the fix reads.

**T11-20 (LOW) — turn counter may not increment on "Continue to Next Cycle".**
Header read "Turn 9" before and after completing the cycle (Turns Played 8). Unconfirmed —
needs a save-file check, and the display convention is `turns_played + 1`.

> ⚠ **CONFIRMED (Sep 5, fixit sprint) — this is a real data defect, not a display one.**
> Measured: `CampaignPhaseManager.bind_campaign()` resets `turn_number = 0` for a new
> campaign identity and restores the PHASE but never the turn.
> `CampaignTurnController._on_campaign_turn_started()` then writes
> `turns_played = max(current, turn_number - 1)`. The `max()` exists so a stale LOW value
> cannot lower a real count — and that is exactly what freezes it: after a reload
> `turn_number` restarts at 0, so the write is `max(8, -1) = 8`, then `max(8, 0) = 8`, and
> `turns_played` cannot move again until `turn_number` has climbed past 9. Probe output
> before the fix: `turn_number 0 -> 1 -> 2` while `turns_played` sat at 8 throughout.
> **Neither half is wrong on its own**, which is why it survived. The missing piece was
> the restore.

**T11-21 (LOW/UX) — the unassigned-crew confirm dialog reserves nearly the full screen
height for six lines of text.** Cosmetic.

**T11-22 (LOW) — Crew Log: the second weapon row sits ON the weapon box's bottom border.**
Nyx Ward's "Colony Rifle 18 1 0" is drawn on the border line with the descenders clipped,
and the row slot ABOVE it is empty — so weapon 2 lands in the last row instead of the next
one. The other five crew have one weapon each and are unaffected. Everything else on the
Crew Log renders correctly (T11-06's source-coordinate field layer is holding on device).

**T11-23 (LOW) — Encounter Log prints a raw id: "Encounter Type: interested_parties".**
`SheetDataContext.gd:617` passes `enemy_category` straight through
(`"encounter_type": category if not category.is_empty() else enemy_name`), and its own
comment names the intended display form: "Criminal Elements / Hired Muscle / Interested
Parties / Roving Threats, pp.94-103". The transform already exists 40 lines below in the
same file — `_sight_label()` does `to_lower().replace("_", " ")` + sentence case, and
documents WHY sentence case (the book prints them that way). Snake_case on a printed
deliverable.

**T11-24 (LOW/enhancement) — Encounter Log enemy table: Panic / Speed / Combat / Toughness
/ AI columns print blank.** NOT a null-resolution bug — verified against
`data/sheets/core/encounter_log_fields.json`, which addresses only `enemy_name_1` and
`enemy_number_1`; the five stat columns have no field entry at all, so blank is what the
manifest asks for and the SOP's "blank is a legitimate value" rule covers it. But the
values exist in the enemy tables, so this is a fillable gap rather than correct-by-design:
a companion app printing a sheet the player then hand-copies from the Bestiary is doing
half the job. Enhancement, not a defect.

**T11-25 (MED) — a Rival is NAMED with a UI description string.** World Record Sheet,
Local Rivals Known, row 2: **Rival Type = "Old nemesis (persistent, +1 enemies)"**, Notes =
"Corporate". Source found: `CampaignEventEffects.gd:113` calls
`ctx.add_rival("Old nemesis (persistent, +1 enemies)")` — passing the human-readable effect
text where a rival name belongs, while the very next line returns that same text as the
event's result message. The sheet is printing faithfully; the producer stored a sentence.
This leaks anywhere a rival name is shown (dashboard, journal, Patrons & Rivals, sheet).
Contrast row 1, which is correct: Type "Feral Jackals" / Notes "Mercenary Band".

**T11-26 (HIGH) — the Options screen does not scroll from a touch drag inside any section
card.** Only a drag on the bare background BETWEEN cards, or on the ~8 px scrollbar, moves
it. Eight probes, one rule explains all of them:

| Probe | Start point | Result |
|---|---|---|
| `S_slow_mid` (1280,1300) | inside Gameplay card | no scroll |
| `S_left_col` (400,1300) | inside Gameplay card | no scroll |
| `S_right_col` (2300,1300) | inside Gameplay card | no scroll |
| `S3_edge` (2495,1300) | inside card, left of the scrollbar | no scroll |
| `S5_card` (1280,500) | inside a card | 19 px highlight strip only |
| `S_long` (1280,1450) | below the ScrollContainer entirely | slider highlight only |
| `S4_gap` (1280,272) | bare background between cards | **full-page scroll** |
| `S1_bar` (2512,300) | the scrollbar | **full-page scroll** |

**Positive control**: the identical gesture (2100,1300)→(2100,500) @900 ms scrolled the
dashboard's CURRENT WORLD panel, diff bbox (1728,350)-(2512,1417) — so `adb input swipe`
does drive touch scroll in this app, and the settings failure is real.

**Root cause, verified in source.** `SettingsScreen._create_section_card()`
(`SettingsScreen.gd:831`) builds a bare `PanelContainer.new()` and never sets
`mouse_filter`, so it keeps the `MOUSE_FILTER_STOP` default and swallows the drag; each
card also holds an `HSeparator`, the second known swallower. The fix already exists in the
codebase three times over and this screen reaches none of it — `SettingsScreen extends
Control` directly, so it inherits neither `BaseCampaignPanel._fix_touch_scroll_filters()`
(`:885`, and `:828` is literally `panel.mouse_filter = MOUSE_FILTER_PASS  # Allow touch
scroll through cards`) nor `BasePhasePanel`'s copy (`:478`), and it never uses
`TouchScrollOpener`. Same shape as "a fix ordered against SOME callers is not a fix".

**Stranded below the fold**: Touch & Haptics, Accessibility, Expansions, Difficulty
Toggles, Legal & Privacy (all four documents), Data & Privacy (Share Anonymous Usage Data,
Export My Data, Delete All Data), About, Report a Bug, Telemetry diagnostics. An 8 px
scrollbar is far under the 48 dp touch floor, so in practice none of it is reachable.

⚠ **Scope, not yet measured**: 48 screens build a `ScrollContainer`, extend a Control-ish
base, and never reference any of the three fixes. That grep proves only that the helper is
ABSENT, not that each screen swallows touch — a screen is only affected if it also puts
STOP-default containers inside the scroll. The 5PFH-relevant names are `PreBattleUI`,
`BattleSimulatorSetupPanel`, `CrewPanel`, `EULAScreen`, `LegalTextViewer`, `MainMenu`,
`SettingsScreen`, `ShipManager`; the rest are Bug Hunt / Planetfall / Tactics (alpha-2).
Each needs the probe above before being called a defect.

⚠ **T11-26 and T11-27 are independent.** Re-probed the SAME screen in SCENE mode (reached
from Main Menu -> Settings, so the SceneTree is NOT paused): an in-card drag still produced
only an 18 px band, bbox (281,391)-(1994,409). So the swallowed scroll is the cards, not
the pause, and fixing either one leaves the other live.

**T11-27 (HIGH) — every scene navigation offered inside the in-campaign Settings overlay is
dead, because the overlay pauses the SceneTree and the fade tween cannot advance.**

Dead controls (all of them reachable ONLY from that overlay's own content): Privacy Policy,
Terms of Service / EULA, Open Source Licenses, Credits, **Browse Expansions** (the store).
`< Back` still works, because it closes the overlay rather than routing.

**Evidence chain, both ends verified.**
1. Device: tapping any of them moves the focus ring and nothing else. Diffs are a ~56 px
   band (the ring), never the full-page bbox a navigation produces.
2. logcat (NOT `godot.log` — `push_warning` goes to the Android log, which is why the
   in-app log was silent and this looked like a dead button):
   `E/godot: WARNING: TransitionManager: Safety timeout - forcing transition cancel`
   `GDScript backtrace: [0] <anonymous lambda> (res://src/autoload/TransitionManager.gd:88)`
   That proves `pressed` fired, `navigate_to` ran, and `fade_to_scene` was entered.
3. Source, half one: `SettingsOverlay._show_settings_overlay()` ends with
   `get_tree().paused = true` (`SettingsOverlay.gd:203`); `_hide_settings_overlay()`
   restores it (`:212`).
4. Source, half two: `TransitionManager` sets **no `process_mode`**, so it inherits the
   pause. `fade_to_scene()` awaits `_fade_out()`, which awaits `_tween.finished`
   (`TransitionManager.gd:284`) — a tween bound to a paused node never advances, so the
   await never returns and `change_scene_to_file` (`:95`) is never reached. The 5 s safety
   timer (`:86-89`) then cancels, leaving no trace in the app's own log.
5. Control: from the **Main Menu** the same four buttons work — Settings is a real scene
   there, not the paused overlay. Verified twice on a fresh launch: the footer "Privacy"
   link opened the policy (diff bbox 0,0-2560,1600), and Main Menu -> Settings -> Privacy
   Policy navigated (diff bbox 37,13-2548,1572), both with an empty logcat.

⚠ **I mis-called this twice before landing it, both times by trusting md5 "CHANGED" as
navigation.** A focus ring changes the md5. The bbox HEIGHT is the discriminator: a real
navigation is full-page, a focus ring is a ~20-56 px band. Diff, do not hash.

⚠ The fix is not simply "unpause": the overlay pauses on purpose. Either give
`TransitionManager` `PROCESS_MODE_ALWAYS`, or have these controls close the overlay before
routing. Whichever is chosen, **grep every other autoload that awaits a tween** — the same
pause reaches all of them.

**T11-28 (HIGH) — the Compendium list has the same swallowed-drag defect, and here a drag
also MISFIRES AS A TAP.** Compendium -> Enemies (60 items, Core Rules pp.93-101):

- Touch drag starting on a list row: **bbox None** — not one pixel moved. The list does not
  scroll.
- Worse than T11-26: the same drag can be consumed as a CLICK. Two separate drags opened
  the **"Punks"** and **"Brat Gang"** detail popups instead of scrolling. On a touch device
  a list row must distinguish a tap from a drag; this one does not.
- Drag on the scrollbar: scrolls correctly (bbox 37,389-2522,1572, list advanced from
  Criminal Elements through Interested Parties into Roving Threats).

**The scrollbar was measured, not estimated.** Scanning columns 2495-2545 for mean
brightness over the list band gives a bright strip at **x = 2513-2520 — 8 physical px**. At
this device's density 320 (2.0x) that is **4 dp**, against Android's 48 dp touch-target
floor: the only working scroll affordance on the screen is **12x under the minimum**.

⚠ This confirms the class is systemic rather than a `SettingsScreen` quirk — two screens
with different implementations, same behaviour. It also justifies probing the rest of
T11-26's list rather than assuming.

⚠ **Method note for the fix phase**: I mis-read this twice by trusting a non-empty diff as
"it scrolled". A popup opening is a large diff. The discriminator is *what* changed —
render the frame, do not just measure it. Locating the scrollbar by pixel scan (above) is
what finally made the control reliable; a 5 px error had been landing my "scrollbar" drags
on a row.

**Corroborates T11-24**: the Enemies entries carry full Bestiary stats (e.g. **"Salvage
Team — T:4 Spd:4 AI:C"**, the exact enemy whose Panic/Speed/Combat/Toughness/AI columns
print blank on the Encounter Log; "Punks — Numbers +3, Panic 1-3, Speed 4", Combat Skill
+0, Toughness 3, AI:A, Weapons 1A, Careless, Bad shots"). The data the sheet leaves blank
is already in the app and rendering correctly one screen away.

**T11-29 (MED) — Patrons & Rivals shows "Unknown" for every field a real campaign rival
has.** Both live rivals render as `Threat: Unknown | Unknown` / `Status: Unknown` in the
list; selecting one gives a Details pane where **Status, Relationship and Threat Level are
label-only, with nothing after the colon**. Name and Type are correct ("Feral Jackals" /
"Mercenary Band"), so the screen is reaching the rival — it is reading keys the rival does
not carry.

**Root cause shape: the screen has its OWN parallel generator, and only its output fits its
display code.** `src/ui/screens/world/PatronRivalManager.gd:358-367` (`_generate_rival`,
behind this screen's own "Generate Rival" button) mints a dict with `status: "Active"`,
`threat_level`, `relationship` — exactly the keys the display reads. The campaign's REAL
rivals come from `RivalPatronResolver` and from `CampaignEventEffects.add_rival()`, neither
of which writes that trio (`RivalPatronResolver.gd:842` writes `threat_level` only on the
psi-hunter path). So the screen renders correctly for rivals it created itself and
degrades for every rival the campaign actually produced — the classic "a consumer reads a
key no producer writes", with a self-consistent parallel model hiding it.

⚠ **Two renderings of the same absence on one screen**: the list prints the literal string
"Unknown" while the Details pane prints blank. "Unknown" is the worse of the two — it
asserts a value where the sheet SOP's rule would want a blank. Pick one at fix time.

⚠ **Lead, not a claim**: `PatronRivalManager.gd:141-200` carries hardcoded patron/rival
templates with `relationship_range` and `threat_levels` arrays. I have NOT checked these
against the Core Rules; if they are invented they are a data-integrity issue in their own
right (`GAME_BALANCE_ESTIMATE` = fabricated = remove). Verify against the book before
touching this screen.

**T11-30 (LOW) — Ship Management cosmetics.** "Hull Points: `35` / `35.0`" prints the max as
a float against an int current, and "Travel Cost: 6 credit" is singular. Everything else on
the screen is correct, including **"Ship Traits: - Fuel Hog" with its header intact**,
which is the D-e `%TraitsContainer` fix verified on device.

**T11-31 (MED) — Manage Crew prints raw enum keys as the roster, and mangles a book
species name.** Crew 6/6 renders, but the subtitle line is the enum key, not the label:

| Card | Rendered | Problem |
|---|---|---|
| [Captain] Bryn Ito | `Genetic Uplift / ENFORCER` | class is a raw key |
| Dex Kovac | `Traveler / GANGER` | class is a raw key |
| Yuri Drake | `Mutant / BOUNTY_HUNTER` | raw key, underscore shown |
| Mars Stark | `KERIN / ENFORCER` | **species mangled** |
| Finn Mendez | `FERAL / TRADER` | species raw |
| Nyx Ward | `HUMAN / AGITATOR` | species raw |

Three things make this more than cosmetic. (1) **The same field renders two ways in one
list** — "Genetic Uplift"/"Traveler"/"Mutant" are display-cased while "KERIN"/"FERAL"/
"HUMAN" are raw, so some members carry a label and some carry a key and the screen does not
normalise either. (2) **`KERIN` is not the book's name — it is `K'Erin`** (Core Rules p.16),
and the apostrophe is exactly the character a naive `to_upper()`/key round-trip drops. The
CampaignDashboard renders the same crew correctly ("K'Erin", "Enforcer", "BountyHunter"
pills), so the transform exists and this screen does not use it. (3) It is the same defect
family as T11-14 — key-vs-label confusion on a surface the player reads.

**T11-32 (MED) — the Campaign Journal detail pane prints raw character IDs instead of
names.** The Turn 9 battle entry reads:
`Characters: char_498964_9495, char_690708_7921, char_690714_9647, char_690716_1964,
char_690719_3101, char_690722_2568` — six internal ids where six crew names belong. The
entry is otherwise correct and rich (result, casualties, deployment condition, enemy, loot,
notable sight, objective, XP).

**T11-33 (LOW) — integer quantities print with a trailing `.0` on player-facing surfaces.**
Same journal entry: `Casualties: 0.0`, `Enemy Count: 6.0`, `Loot Earned: 1.0`,
`Xp Gained: 12.0`; and Ship Management's `Hull Points: 35 / 35.0` (T11-30). This is Godot's
JSON parser returning every number as float — the documented gotcha — reaching the UI
unformatted. One shared int-format helper at the display boundary fixes the class.

**T11-34 (LOW) — the journal is where T11-23's raw id actually originates, and the
sentence-case transform is applied inconsistently.** The same entry shows
`Enemy Category: interested_parties` and `Notable Sight: DOCUMENTATION`, while the printed
Encounter Log renders the sight correctly as "Documentation — Gain 1 Quest Rumor." So
`SheetDataContext._sight_label()` prettifies the sight for the sheet but nothing prettifies
it for the journal, and nothing prettifies the category on either surface. **Fix the
display transform once, at a shared boundary** — three surfaces currently disagree about
whether a stored token is presentable.

⚠ **Theme across T11-23 / T11-25 / T11-29 / T11-31 / T11-32 / T11-34**: this walk found six
independent places where a stored token and a display string are confused — raw ids shown,
descriptions stored as names, enum keys printed, a book name mangled, and one transform
applied on one surface but not its sibling. That is a single systemic gap (no display-name
boundary), not six unrelated cosmetics, and it should be scoped as one fix.

## Discovered during the fixit sprint (not from the device walk)

**T11-35 (MED) — Campaign Event 89-91 "Got Noticed" named both its riders and applied
neither.** Core Rules p.128, verbatim: *"You got noticed by someone you'd rather avoid.
Add a Rival. If you currently are on a Quest, the next campaign turn is automatically a
battle against the new Rival, and they will add +1 to the number of enemies."*
`CampaignEventEffects.gd` returned the text *"forced battle next turn if on Quest, +1
enemies"* and did neither. ⚠ **Note the scope of the conditional**: it governs the whole
second sentence, so the forced battle AND the +1 enemies are both Quest-only — which is
also how the shipped table encodes it (`quest_forced_battle` / `enemy_bonus_if_quest`).
Off-Quest it is a plain "Add a Rival". ⚠ The rolls are **89-91**; an earlier working note
said 88-91.

**T11-36 (MED) — `HubFeatureCard` fired twice per tap.** It listened to
`InputEventMouseButton` AND `InputEventScreenTouch` (`:137`/`:140`). This project sets
`pointing/emulate_touch_from_mouse=true` (`project.godot:109`) and leaves
`emulate_mouse_from_touch` at its default `true`, so ONE physical tap arrives as both and
emitted `card_pressed` twice — across 52 references on 6 screens. Fixed by the same
`TapGesture` component as T11-28, which listens to the mouse family only (touch is already
translated into it).

---

## Status after the Sep 5 fixit sprint

All 19 walked findings plus the two above are **fixed at the desk and detection-proven by
isolated revert**. Desk gates: `tests/unit` **3085 headless + 27 windowed = 3112 cases, 0
errors, 0 failures** (baseline 3016); all **8 gating lints** exit 0; `git diff -- data/`
lists ONLY `crew_log_fields.json` and `encounter_log_fields.json` — no rules JSON touched.

⚠ **NONE of it is hardware-verified yet.** Deploy #20 is the outstanding step, and for the
touch findings in particular the device is the only authority: Godot does not deliver
`InputEvent`s in headless mode, so the unit cases pin the STATE the fixes leave behind
(mouse filters, tap discrimination, geometry) and not the gesture itself.

Two rows changed shape under investigation and the entries above were corrected in place
rather than rewritten: **T11-16**'s `game_phase` clause was wrong, and **T11-20** turned
out to be a confirmed data defect rather than the display nit it was filed as.

**T11-22 carried further than the row described.** The finding was row-2 weapon baselines
sitting on the box border; the baker's `spanning[-1]` rule (take the FARTHEST rule in the
h-6..h+18 window) had mis-baked **128 of 184** crew-log fields, not 40. Verified against
the artwork before and after: `captain_name`'s box bottom is y=774, its own closing rule is
at y=777-778, and the next box's TOP border is at y=790 — the old offset pointed at 790. A
before/after render of the same campaign shows the captain's name struck through by its own
box border in the old build and sitting cleanly inside the box in the new one.

## Deploy #20 — hardware verification of the fixes (2026-09-05, TB361FU HNQ05SR3)

Built via CLI (`export_format` 1->0, `--export-debug`, preset restored after), `verify_apk.py`
**PASS** (59.0 MB, 2643 entries, no leaked paths), `adb install -r` Success.

⚠ **Build identity was proven, not assumed.** `versionCode` is unchanged at 6, so the
install alone proves nothing. The positive marker is
`[T11-26] SettingsScreen touch-scroll filters opened: 52` — a print that does not exist in
the previous build. It appeared on both the scene-mode and overlay-mode Settings screens,
and 52 matches the 51 the desk test measures (the mobile branch builds one extra control).

| Finding | Result on hardware |
|---|---|
| **T11-27** in-campaign Settings navigation ⭐ | **PASS.** Gear -> overlay -> Privacy Policy opened the document (diff 97% of page, then settled on the rendered policy). No `Safety timeout` around it and **no `fade_to_scene ... while paused` push_error** — the new loud tell stayed silent, which is the positive proof the unpause ordering worked. On #19 this same tap produced only a ~56px focus-ring band. |
| **T11-26** Options scrolls from an in-card drag | **PASS in BOTH modes.** Scene mode: drag on card text scrolled 79% of the page (Audio/Display off the top, Touch & Haptics + Accessibility in). Overlay mode: 82%. Header pinned, no toggle flipped. |
| **T11-28** Compendium list ⭐ | **PASS, both halves.** A 600px drag over a row SCROLLED the list (Criminal Elements -> Hired Muscle) and opened **no** popup — on #19 this opened a detail popup. A tap on a row still opens its detail ("Precursor Exiles" with its stat block). |
| **T11-29** Patrons & Rivals | **PASS.** No "Unknown" anywhere; the three fabricating buttons (Generate Patron / Generate Rival / Manage Jobs) are gone; rows now lead with the enemy TYPE. |
| **T11-31** display-name SSOT | **PASS.** Manage Crew reads "Genetic Uplift / Enforcer", "Traveler / Ganger", **"K'Erin / Enforcer"** (the apostrophe — this was `KERIN`) and "Mutant / **Bounty Hunter**" (was `BOUNTY_HUNTER`). |
| **T11-36** HubFeatureCard | **PASS, with one unexplained miss.** 5 of 6 plain `adb input tap`s navigated, one navigation each. The miss was the FIRST tap after arriving on the dashboard; the same card and coordinate then navigated twice in a row, and a 120ms press worked immediately. Recorded rather than explained away. |
| **T11-16** premise | **CORRECTED from the pulled save**: `meta.game_phase = "active"` IS present. The resume branch was NOT exercised — this save has no `active_battle`, so "Begin Turn 9" is correct for it. Still owed: force-stop mid-battle and re-open. |

### Not walked on deploy #20

T11-15 (keyboard shortfall on the QA dialog), T11-17 (needs a mid-battle force-stop),
T11-18 (Record Battle Result drawer), T11-19/T11-25/T11-35 (need forced campaign-event
rolls and a Rival battle), T11-20 (needs a completed cycle), T11-21, T11-22/T11-24 (sheets
export + PyPDF2 read-back), T11-30/32/33/34.

### ⚠ T11-25's fix is FORWARD-LOOKING — existing saves are not repaired

The pulled save still carries the pre-fix record verbatim:
`{"hostility": 4, "id": "rival_879341_156", "name": "Old nemesis (persistent, +1 enemies)",
"resources": 1, "source": "event", "type": "Corporate"}` — the effect string as the name,
the invented type, and the two dead keys. The producer is fixed; the record is not. A
load-time normalisation (or an explicit decision to leave legacy rivals alone) is owed.

### T11-37 (NEW, LOW) — the 5s transition safety timer fires on slow scene builds

Four `TransitionManager: Safety timeout — forcing transition cancel` warnings across ~10
navigations, and **every one of those navigations visibly completed**. Crucially the new
paused-tree `push_error` never fired, so these are NOT the T11-27 case. The likely cause is
simply that a heavy scene (the 230-item Compendium, the dashboard) takes longer than 5s to
build and fade in on a Mali-G57, so the timer cancels an already-finished transition.
Benign but noisy, and it makes the one warning that DOES matter harder to spot. Worth
either widening the timeout or having it check real completion rather than elapsed time.

### T11-38 (NEW, MED) — three rival shapes coexist, and the viewer reads keys none of them carry

Found at the desk during the deploy #21 dry run, **before** any device time, by censusing
the real saves rather than screenshotting the screen.

`PatronRivalManager._rival_provenance()` (`:283-294`) renders a rival's origin, planet and
"since turn N" from `origin` / `planet_id` / `created_turn`, and its own docblock (`:229`)
names the shape it expects. Census of **40 save files — 25 rival records, 100 % Dictionary,
and ZERO carrying any of those three keys**:

| Count | Key set | Producer |
|---|---|---|
| **22 / 25** | `hostility, id, is_starting_rival, name, source_character, strength, type` | `CharacterGeneration._create_starting_rival()` — carries `hostility`/`strength`, two of the dead keys this sprint deleted from `PostBattleContext.add_rival()` |
| 2 / 25 | `equipment_bonus, name, relationship, special_rules, status, threat_level, type` | the old PatronRivalManager fabricated shape (T11-29) |
| 1 / 25 | row 1 minus `source_character` | same as row 1 |
| **0 / 25** | `planet_id`, `created_turn`, `origin` | `RivalPatronResolver._append_rival()` — **the canonical shape** |

Confirmed on the live device save (`tablet_qa_run_1786210201.save`), which holds all three
shapes in one campaign:

```
rivals (canonical) = 2   [resources.rivals]
    Feral Jackals                          type=Mercenary Band
        provenance:NONE   dead:hostility,strength          <- _create_starting_rival
    Old nemesis (persistent, +1 enemies)   type=Corporate
        provenance:NONE   dead:hostility,resources         <- pre-sprint add_rival
crew.rivals        = 4   (creation-wizard leftover, no live consumer)
```

So the sprint's "one concept, one shape" fix corrected `add_rival()` and left the
**dominant** producer untouched — `_create_starting_rival()` is live at four call sites
(`CharacterGeneration:403`, `CampaignCreationCoordinator:491`, `CrewTaskComponent:4287`,
`QAScenarioLoader:266`).

⚠ **T11-29's deploy #20 PASS still stands and must not be re-litigated.** That fix was
"blank, never the string Unknown", and blank is exactly what these render.

⚠ **This finding's real value was pre-empting a false one.** Without the census I would
have met the empty provenance line during the deploy #21 walk and filed it as a regression
against my own T11-29 fix. It also rescopes the deferred legacy-rival decision from one bad
record on one save to **88 % of all rival records**.

⚠ **Two facts about the save format, established from source, that a walk needs.**
`campaign.rivals` (`FiveParsecsCampaignCore.gd:52`) serialises into the **`resources`**
block (`:444`) and loads back from it (`:663`). `crew.rivals` is a DIFFERENT array written
only by `CampaignCreationCoordinator` (`:398`/`:463`) into wizard state, with no live
consumer — on this save the two hold 2 and 4 *different* records. Asserting against the
wrong one reports rivals nothing reads.

**Not a defect, recorded so it is not rediscovered:** `_prior_rivals()`
(`CampaignEventEffects.gd:85-102`) keeps only `if r is Dictionary`, and
`RivalPatronResolver.gd:872-874` documents `rivals` as a mixed Array of Strings and
Dictionaries (`CharacterGeneration.gd:1441-1482` appends bare strings). The Old Nemesis
chooser would therefore omit a String-form rival — but the census found **zero** across 40
saves, so this is latent and unobserved, not a live gap.

### T11-19b (NEW, MED — FIXED at the desk) — the forced-roll seam reached only one of two sibling rolls

T11-19 fixed `CharacterEventEffects` and stopped there. `CampaignEventEffects.process_campaign_event()`
kept a bare `randi_range(1, 100)` and `QAScenarioDialog.FORCEABLE_ROLLS` had no Campaign
Event entry — so **T11-25 (Old Nemesis, 21-23) and T11-35 (Got Noticed, 89-91) were
unreachable on device**, at 3-in-100 per battle. Fixed by routing through
`DiceManager.roll_campaign_event()`, which had **zero callers repo-wide** — a dead
provider, and the correct API for p.125 step 12. Reached via `Engine.get_main_loop().root`
because this class is RefCounted. 3 new cases in `test_dice_forced_results.gd`, including a
collision guard (both keys contain "Event"); detection-proven — reverting produced *"The
backend Campaign Event rolled 18 instead of the queued 21 — the forced-roll seam does not
reach it."*

## Deploy #21 — hardware walk (2026-09-05, TB361FU HNQ05SR3)

Built via CLI (`export_format` 1→0, `--export-debug`, preset restored automatically even
on failure), `verify_apk.py` **PASS** (59.0 MB, 2643 entries, no leaked paths), installed.
Desk gates before building: **3088 headless + 27 windowed = 3115 cases, 0 failures**
(baseline 3112 + 3 new), all 8 lints exit 0, `git diff -- data/` unchanged.

⚠ **Build identity is a VISIBLE marker this time, not a log grep.** Deploy #20's marker
(`[T11-26] … opened: 52`) now exists in the installed build and can no longer discriminate.
The new one is the **"Campaign Event (D100)" row in the QA roll picker** — an entry that
exists in no previous build, on the first screen of the walk. Confirmed present.

| Finding | Result |
|---|---|
| **T11-15** keyboard avoidance in the QA dialog ⭐ | **PASS.** The forced-roll row scrolled from y≈1044 to y≈491 — a **~553px lift** — putting the focused SpinBox, "Queue Roll" and "Clear" all above the keyboard line at y≈655. On #19 this dialog requested 511.3px and delivered **64px**. ⚠ **Both halves confirmed**: `[T11-15]` prints ONLY when the window-move fallback falls short (`KeyboardAvoidance.gd:161`), and it never fired — so the fallback was not taken at all and the new ScrollContainer did the work. |
| **T11-19b** campaign-event roll seam | **PASS.** "Campaign Event (D100)" present in the picker; selecting it auto-filled the target **21** and rendered the note *"T11-25 - 21-23 Old Nemesis; T11-35 - 89-91 Got Noticed (needs an active Quest)"*. |
| **T11-39** QA scenario list ⭐ | **Regression FOUND on device and FIXED** — see below. After the fix all four fixtures render, including "Rivals, Patrons + an active Q…", with the detail pane populated. |
| **T11-38** rival provenance | **CONFIRMED visually.** Both rivals render type-led (`Mercenary Band` / `Corporate`) with **no provenance line at all** — no origin, no planet, no "since turn N" — because neither carries `origin`/`planet_id`/`created_turn`. Exactly what the 40-save census predicted. |
| **T11-29** Patrons & Rivals | **PASS still holds.** No "Unknown" anywhere, rows lead with the enemy TYPE, no fabricating buttons. Do not re-litigate on the blank provenance line — that is T11-38 and a different cause. |
| **T11-25** legacy record | Visible on **two** surfaces, not just the sheet: the dashboard RIVALS panel and Patrons & Rivals both print `Old nemesis (persistent, +1 enemies)` where a name belongs. |
| **T11-07** density double-count | **Re-confirmed, more strongly than #19.** Five `[T11-07]` lines across four orientation flips: `dpi` moves **1.000 → 2.000** while `content_scale` holds at **0.7830** every time. |
| **T11-27** paused-tree guard | The new `push_error` never fired (0 occurrences). |
| **T11-37** transition safety timer | **0** `Safety timeout` warnings this leg, against 4 on #20. ⚠ Not yet conclusive — this leg opened no Compendium and no heavy scene, which is the suspected trigger. |

### T11-39 (NEW, MED — found on device, fixed) — the T11-15 fix made the QA scenario list invisible

The dialog opened with the forced-roll row and **~900px of empty space** where the scenario
list and detail pane belong, so the entire fixture feature was unreachable — and the
fixture is what Leg 3 needs.

**Cause.** The T11-15 fix wrapped the dialog content in a `ScrollContainer` so keyboard
avoidance had something to move. Godot 4.6 (`gui_containers.html`, Context7-verified): a
ScrollContainer *"accepts a single child node and adds scrollbars if the child node's size
exceeds the container's dimensions. **Both vertical and horizontal size options are
respected**."* `_build_ui()` set `root.size_flags_horizontal` and **never set
`size_flags_vertical`**, so the scroll sized the inner VBox to its MINIMUM height and the
`split` below it could claim no leftover space — and `_list.custom_minimum_size` was
`Vector2(280, 0)`, **zero minimum height**, so the collapse went all the way to nothing
rather than merely looking cramped. Two causes, and the second is why it vanished instead
of looking wrong.

⚠ **The T11-15 fix was itself detection-proven and desk-green.** What no test asserted was
that its NEIGHBOUR still rendered. A fix can solve its own finding and break the control
beside it; `test_qa_scenario_dialog_shows_its_list` now pins both halves, each
detection-proven by isolated revert.

⚠ **My first version of that guard was a false green, and running the proof is what caught
it.** I asserted `(size_flags_vertical & Control.SIZE_EXPAND_FILL) != 0`. But
`SIZE_EXPAND_FILL` is the COMPOSITE `SIZE_FILL | SIZE_EXPAND == 3`, and a Container
defaults to `SIZE_FILL == 1` — so the mask returns 1, non-zero, for **exactly the default
state the bug is made of**, and a faithful revert stayed green. The discriminating bit is
`SIZE_EXPAND` alone. *Never mask against a composite flag to detect the absence of one of
its bits.*

### Method notes from this deploy (both cost real time)

- ⚠ **`user_rotation` does not map to orientation by name on this device.** Measured by
  capture dimensions, which is the only ground truth: `0` → PORTRAIT, `1` → PORTRAIT
  (despite `mCurrentRotation=ROTATION_90`), **`3` → LANDSCAPE**. `wm size` reports the
  physical panel 1600x2560 at every rotation and is useless here. Worse, **writing the
  setting re-triggers a layout and can flip the app**: a capture taken before a
  `settings put` was landscape and the one after was portrait with nothing else changed.
  Set it once, verify by capture size, then leave it alone — a tap sent against stale
  coordinates lands on nothing and reads as a dead control.
- ⚠ **A first tap after arriving on a screen can only move focus.** MainMenu's "Continue
  Campaign" produced a 56px focus-ring bbox on tap 1 and a 100% navigation on tap 2. This
  is the same shape as T11-36's "unexplained miss" on deploy #20 — and it reproduces here
  on a plain `Button`, not a `HubFeatureCard`, so it is not a `TapGesture` defect. Recorded
  as a pattern rather than explained; the bbox-height discriminator is what makes it
  visible at all, since the md5 changes either way.

## Deploy #21 — the DESK pass, run against the pulled device save

The tablet save was pulled and used as the fixture (57 KB; it carries the campaign
*and* `qol_data.journal` — 34 entries — so one file is the whole state). Six of the
thirteen open rows turned out to need **no play-through at all**: they are formatter
fixes whose inputs already sit in that save in exactly the shape that broke, produced
by real play.

⚠ **Not a hand-authored fixture, and that distinction is load-bearing.**
`CampaignJournal.create_entry()` passes `stats` through wholesale (`:88`), so a
fabricated entry survives the chokepoint intact and prints perfectly — proving the
renderer works while bypassing `auto_create_battle_entry()` (`:234-296`), which is the
producer T11-24 exists to test. This project has already validated a shape the app
cannot produce three times.

Tooling: `tests/tools/probe_deploy21_data.gd` (headless, 36 checks) and
`tests/tools/probe_deploy21_render.gd` (windowed — it builds a real `SheetRenderer`).
Both mirror `PrintSheetScreen._build_data_context()` (`:279-307`) line for line, because
both device-only sheet defects lived in those three fetch lines rather than in `build()`.

| Row | Desk verdict | Evidence |
|---|---|---|
| **T11-24** | **PASS** | all seven Encounter Log columns resolve to the book row — `Salvage Team \| 6 \| 1-3 \| 4" \| +0 \| 4 \| C` (`data/enemy_types.json`, category *Interested Parties*). Derived from the enemy NAME via `EnemyGenerator.get_enemy_stat_block()`, not from the journal, so the existing entry is sufficient. |
| **T11-23** | **PASS** | `encounter_type` → `Interested Parties` |
| **T11-32** | **PASS** | all six `char_*` ids resolve — `char_498964_9495` → *Bryn Ito*, etc. |
| **T11-33** | **PASS** | clean on BOTH arms present in the one save: `casualties: 0` (int, turn 9) and `0.0` (float, turn 1) |
| **T11-34** | **FAIL → fixed** | see below |
| **T11-22** | **PASS** | 216 fields, 0 offenders; **24 crew-log fields grow** to fit their line height and every one keeps its bottom on its rule |
| **T11-30** | **PASS** (helper + call sites) | `ship.max_hull` is `35.0` in the save; `DisplayText.number()` → `35`, `pluralize(6,"credit")` → `6 credits`, both wired at `ShipManager.gd` |

### T11-34 was only HALF fixed, and the desk pass is what caught it

`CampaignJournalScreen`'s Details block sent **every** stat value through
`DisplayText.number()` (`:909`), which corrects a number and returns a String
**unchanged**. So on the real device data the journal rendered:

```
Enemy count: 6                      <- fixed
Enemy category: interested_parties  <- still raw
Notable sight: DOCUMENTATION        <- still raw
```

correct figures beside raw storage tokens, while the printed Encounter Log rendered both
properly — which is precisely the state the finding was filed in ("three surfaces
currently disagree about whether a stored token is presentable").

⚠ **The 11-case suite was green throughout.** It covered `title_case()` and the SHEET's
`encounter_type`; nothing exercised the journal's own Details block, the surface the
finding actually named.

**Fix** — one shared boundary, as the finding asked. `DisplayText.stat_value()` routes
this project's two storage spellings onto the two conventions the book uses:

| Input | → | Why |
|---|---|---|
| `interested_parties` | `Interested Parties` | pp.94-103 encounter tables are Title Case |
| `DOCUMENTATION` | `Documentation` | p.89 Notable Sights are sentence case |
| `Salvage Team`, `K'Erin`, `Gain 1 Quest Rumor.` | unchanged | mixed case owns its spelling |

`SheetDataContext._sight_label()` now calls the same `sentence_case()` instead of keeping
a private copy, so the two surfaces cannot drift apart again. Pinned by five new cases in
`tests/unit/test_display_text.gd` (11 → 16), detection-proven on both arms independently:
reverting the CALL SITE fails 1 case, reverting the HELPER fails 2.

⚠ **A live bug in the new helper was caught by its own "leaves alone" case**, not in the
field: `capitalize()` inserts a space before an interior digit run, so `"1-3"` came out as
`"1- 3"`. A value with no cased letters is now handed back untouched. Writing the negative
arm is what found it — asserting only that the transform *works* would have shipped it.

### Two probes of mine were false greens before they were useful

Recorded because both are the project's own documented traps, met from the inside:

1. **The first detection proof could not have failed.** The probe exercised the HELPER,
   so reverting the CALL SITE left it green — and the call site is exactly what was wrong
   (`number()` vs `stat_value()`). This is `T11-05`'s "the helper was never the missing
   piece, the CALL was", and the fix is that the probe now asserts both.
2. **The T11-22 probe reported "216 fields checked" while scanning ZERO pixels.** Its scan
   band ran from `rect.y + rule_offset` down to `rect.y + rect.h` — but **the rule sits
   3-4px BELOW the box bottom**, so `y0 > y1` for all 184 fields and the loop body never
   executed. It stayed green through a faithful revert. Two further versions were also
   non-discriminating: counting ink below a rule flags the crew log's legitimate SECOND
   weapon row and the rival detail line (11 false positives), and excluding neighbours to
   remove those also masks the real defect, because the 24 affected fields are stat boxes
   in a dense table where the strip below each rule belongs to the next row. **Pixels were
   the wrong instrument.** The probe now asserts the geometry invariant directly — a
   field's rect bottom must stay on `rect.y + rule_offset - FIELD_BASELINE_GAP`, because
   the fix grows the box UP — and reverting produces exactly 24 offenders at +4/+5px,
   matching the 24 the instrumentation counts as growing. It also fails loudly if nothing
   grew, so a run that never exercises the invariant can no longer read as a pass.
   `SheetRenderer` now stamps `sheet_field_id` on each node so a probe can pair back.

## Deploy #22 — Pass A on hardware (2026-09-05, TB361FU HNQ05SR3)

Rebuilt after the desk pass, because the T11-34 fix postdated the installed APK.
`scripts/verify_apk.py` PASS (59.0 MB, 2643 entries, no forbidden paths).

⭐ **Build identity is now proven by HASH, not by a visible marker.** The installed
`base.apk` md5 is compared against the local artifact:

```
local     93f91e6044f579bb46781c7664503c21
installed 93f91e6044f579bb46781c7664503c21  /data/app/~~lIPI.../base.apk
```

This replaces the "look for a new string in the UI" method, which has two flaws that
cost time on #20 and #21: a visible marker is **burned** once it exists in both builds,
and when the marker IS the fix under test, its absence cannot distinguish "old build"
from "the fix is broken". `adb shell md5sum $(pm path <pkg>)` has neither problem.

### Results — eight rows verified, no failures

| Row | Verdict | Evidence |
|---|---|---|
| **T11-16** (negative branch) | **PASS** | Dashboard reads **"Begin Turn 9"**, header "Turn 9 — Upkeep", on a save with no `active_battle`. This proves `BattleCheckpoint.is_valid()`'s turn gate is LIVE rather than the label being stuck on "Resume" — a control a played battle cannot produce. |
| **T11-30** | **PASS** both halves | Ship Management: `Hull Points: 35 / 35` (raw value in the save is the float `35.0`) and `Travel Cost: 6 credits` pluralised. ⚠ Checked on Ship Management, NOT the dashboard, which already rendered `35 / 35` and would have passed for the wrong reason. |
| **T11-32** | **PASS** | Journal: `Characters: Bryn Ito, Dex Kovac, Yuri Drake, Mars Stark, Finn Mendez, Nyx Ward` — six names, no `char_498964_9495`. |
| **T11-33** | **PASS** | `Casualties: 0` · `Enemy Count: 6` · `Loot Earned: 1` · `Xp Gained: 12` — every whole float clean. |
| **T11-34** | **PASS** (the fix made this session) | `Enemy Category: Interested Parties` · `Notable Sight: Documentation`, with `Salvage Team` / `Delayed` / `Move Through` / `Gain 1 Quest Rumor.` all left alone. One crop shows every branch of `stat_value()` at once. |
| **T11-22** | **PASS** | Crew Log renders with no value struck through by a border, and the case the finding named is visible: **Nyx Ward's second weapon (`Colony Rifle 18 1 0`) sits in its own row inside the box**, under `Shotgun 12 2 1 Focused`. |
| **T11-23** | **PASS** | Encounter Log `Encounter Type: Interested Parties`. |
| **T11-24** | **PASS** | The full seven-column row, matching the desk prediction and `data/enemy_types.json` exactly: **Salvage Team \| 6 \| 1-3 \| 4" \| +0 \| 4 \| C**. Speed keeps the inch mark; Combat Skill is the signed `+0`. |

**PDF read-back** (Android backend, PyPDF2 — a library that did not write it):
`encounter_log_2026-09-05T20-29-34.pdf`, 125,221 bytes, **1 page, 792 x 612 pt** (US
Letter landscape). The invisible searchable layer carries all seven stat values:

```
Interested Parties Delayed
Move Through Documentation — Gain 1 Quest Rumor.
Salvage Team 61-3 4" +0 4 C
Battle vs Salvage Team - Defeat | Objective: Move Through (failed)
```

⚠ `PyPDF2` prints `incorrect startxref pointer(1)` and recovers; the parse is sound. A
`UnicodeEncodeError` on the em-dash is the Windows console (cp1252), not the PDF — set
`PYTHONIOENCODING=utf-8`.

**T11-37 — 0 Safety timeouts** across ~8 navigations (dashboard → ship → journal →
sheets → tab switch → PDF export → native file dialog → rivals), against deploy #20's
4-in-~10. Two clean legs now. **T11-27 — 0 paused-tree errors.** Frame rate held
~60 fps throughout (`BufferQueueProducer fps=59.4-60.3`).

**T11-38 re-confirmed on its own screen**, not merely the dashboard: `Mercenary Band /
Feral Jackals` and `Corporate / Old nemesis (persistent, +1 enemies)` both render
type-led with **no provenance line**, matching the 40-save census (0 of 25 records carry
`origin` / `planet_id` / `created_turn`). This is the CONTROL for the battle leg — a
rival created by `_append_rival` during the walk should show origin/planet/turn beside
these two, which is the one-variable A/B that identifies the canonical producer.
**T11-29's PASS still holds** — nothing renders "Unknown".

### Method note — a byte-size change is a navigation signal the diff missed

`walk21.py tap` waits 2 s, then diffs before/after. On "Continue Campaign" that reported
**IDENTICAL — the control did nothing**, twice, and it was wrong both times: the campaign
load takes longer than 2 s, so BOTH frames in the diff were pre-navigation. The tell was
the capture SIZE across commands — 2,225,382 bytes (main menu) then 361,800 (dashboard).
⚠ A diff bounded inside one command cannot see a transition slower than its own wait;
compare across commands, or wait on the destination rather than on a timer.

## Dry run of the battle leg — traced through source before touching the device

Eight questions, each answered by reading the code rather than by trying it on hardware.
Two changed the plan; two are traps that would have produced a false verdict.

| # | Question | Answer |
|---|---|---|
| **Q1** | T11-21's measurable? | `confirm_dialog_size()` opens at **0.8 of the viewport on both axes** (the CAP), then `_shrink_dialog_to_content` — **`call_deferred`, one frame later** — sets the height to `clamp(content_min, 200, vp*0.8)` and re-centres. ⚠ **A screenshot taken before that frame captures the pre-shrink state and reads as a FAILURE.** Expect ~250-400px on a 1379px viewport, width unchanged (autowrap needs it). |
| **Q3** | When does the checkpoint arm? | `BattleRoundTracker` sits at **round 0** until `_begin_combat()` — the pre-battle checklist's **"Begin Battle"** button. `start_battle()` emits `phase_changed` → `_on_round_phase_changed` → `_queue_checkpoint_save()` → written on that frame. **S2 arms on Begin Battle; no combat action needed.** |
| **Q4** | How is the T11-18 drawer opened? | "Record Result" has its **own persistent app-bar button** in landscape (`TacticalBattleUI:1566`); the panels-menu entry is the portrait-only twin. |
| **Q5** | Is QA reachable with a battle active? | **Yes.** `_add_qa_scenarios_button()` gates only on `OS.is_debug_build()` and a loaded campaign — no battle-state dependency. The relaunch after a restore lands on the dashboard, where the button is. |
| **Q6** | Does the forced queue survive the navigation? | **Yes.** `DiceManager` is an autoload, and the ONLY production caller of `clear_forced_results()` is the QA dialog's own Clear button (`:332-333`). Nothing clears on scene change, battle start or campaign load. |
| **Q7** | T11-25's chooser? | `ItemChoicePopup` titled **"An Old Nemesis"**, confirm button **"Face Them"**, modal — `_on_close_requested` refuses to close without a selection. On this save it lists exactly three options (see the trap below). |
| **Q8** | Does LOG_ONLY reach post-battle? | **Yes.** `_normalize_battle_results` (`CampaignTurnController:1857`) names *"LOG_ONLY manual record"* as one of its four paths into the post-battle consumer chain. |
| **Q9** | Is step 12 gated? | No. `_intro_allows()` returns true unconditionally when `_intro_gating_active` is false, and this save carries **no intro-campaign keys at all**. |

### ⭐ Pass C is TWO cycles, not three

`PostBattlePhase` runs `_campaign_events.process_campaign_event()` (`:242`) and
`_process_character_event_step()` (`:249`) **sequentially in the same post-battle run**.
So one post-battle consumes a queued Character Event *and* a queued Campaign Event:

- **Cycle 1** — queue `Character Event = 88` **and** `Campaign Event = 21` → observes
  **T11-19 and T11-25 together**
- **Cycle 2** — queue `Campaign Event = 89` → **T11-35**, and leaves
  `forced_rival_battle` set going into Pass D

### ⚠ Trap: two of the three chooser options are wrong to pick

Labels are built as `name (type)` from `_prior_rivals()`, plus a fixed tail option, so on
this save the popup reads:

1. `Feral Jackals (Mercenary Band)` ← **pick this**
2. `Old nemesis (persistent, +1 enemies) (Corporate)`
3. `Roll up a new Rival`

Option 2 is the **untreated legacy record** whose NAME already contains the effect text —
stamping the p.126 riders onto it would compound them on a record that is itself the
subject of the T11-25 legacy question, and the resulting save could not distinguish "the
fix stamped this" from "it was already like that". Option 3 creates a new rival and so
tests the wrong branch (the finding is about selecting a PRIOR rival, and the count must
stay at 2). **Pick option 1.**

### T11-19's row, verified against the data file

`data/campaign_tables/character_events.json` (`_source: Core Rules pp.128-130`), roll
**88-91** = *"Don't Make Them Like They Used To"* — `item_damage`, "a random item carried
by the character is damaged, and must be Repaired before it can be used again". Carries a
`species_exceptions` entry for **Engineer** ("Not affected"); no crew member on this save
is an Engineer (Enforcer / Ganger / Bounty Hunter / Enforcer / Trader / Agitator), so the
effect will apply and a null result would be a real finding rather than the exception.

## Deploy #22 — Pass B on hardware: the one battle (2026-09-05, TB361FU HNQ05SR3)

Installed build re-verified by md5 before starting: `93f91e6044f579bb46781c7664503c21`,
byte-identical to `build/deploy21.apk`. ⚠ `accelerometer_rotation` had **reset itself to
`1` again** between sessions — re-asserted to `0` with `user_rotation 1`, and confirmed
`mCurrentRotation=ROTATION_90` in `dumpsys window` before any capture. That reset is now
twice-observed; treat re-asserting it as part of every device leg, never once per session.

Route: dashboard → Begin Turn 9 → World Phase (the checkpoint restored straight to
**Step 2 of 6, Crew Tasks**, as predicted) → job offers → equipment → rumors → mission
prep → PreBattleUI (LOG_ONLY) → TacticalBattleUI → **force-stop** → relaunch → resume.

### Results — four rows, all PASS

| Row | Verdict | Evidence |
|---|---|---|
| **T11-21** | **PASS** | Measured by a one-variable A/B — the only difference between the two frames IS the dialog, so the diff bbox is its exact footprint. **Height 398 px = 24.9 % of 1600**, against `confirm_dialog_size()`'s `0.8` cap of 1280 px: **882 px / 55 % of the screen reclaimed**. Width 2066 px stays at the cap, which is CORRECT — `dialog_autowrap` needs a width to wrap against. Taken on the **worst case**: one crew assigned, **five stranded**, the longest message the dialog can produce. Title, all five names, the `Core Rules pp.77-78` citation and both buttons are on-screen. |
| **T11-16** (positive branch) | **PASS** | After a real process death (pid 8687 → none → 18749) the dashboard button reads **"Resume Battle — Turn 9"**. With Pass A's negative branch ("Begin Turn 9", no `active_battle`) this pins BOTH directions on the same campaign — the label tracks checkpoint state rather than being stuck on. |
| **T11-17** | **PASS**, and the fix was **exercised** | Seed `2982481273` and **all 16 sectors** byte-equal across the force-stop. ⭐ The decisive evidence is the log: run 2 printed **`[T11-17] cache MISS, recovered from campaign owner: seed=2982481273.0 sectors=16`**, which run 1 did not. The cache miss IS the defect condition — the state that used to regenerate the terrain and save over the player's physical table. It occurred, and the owner read-through caught it. |
| **T11-18** | **PASS** on all three criteria | (1) The OUTCOME row **wrapped** onto two lines — `Battle Result / [Lost] / Held the field` then `Rounds fought / [1] ▲▼` — which is the `HFlowContainer` fix visibly working instead of overflowing. (2) Both stepper pairs fully on-screen; `Defeated: [0] ▲▼ / 5 total` keeps its suffix. (3) No horizontal scroll range: content ends at x=2529, the **vertical** scrollbar occupies 2532-2541, then **18 px of clean background margin**; the bottom 17 rows are pure background and y=1598-1599 is a 1 px border, not a scroll grabber. |

**⭐ The checkpoint arms on "Begin Battle", with no combat action** — the dry run's Q3,
now confirmed on hardware. `active_battle` went **0 → 16 keys** and
`active_battlefield.seed` **`None` → `2982481273`** on that single press, save 57,736 →
70,861 bytes. This is what let the battle leg cost one press instead of a played round.

**T11-37 — 0 Safety timeouts** and **T11-27 — 0 paused-tree errors** on BOTH runs.
Four clean legs now. **T11-07 re-confirmed** in the same log: `content_scale` holds at
`0.7830` while `dpi` moves `1.000 → 2.000` across a rotation.

**T11-01 re-confirmed incidentally** — PreBattleUI's footer ("Back" / "Confirm
Deployment") renders complete on this tablet in landscape.

### Two NEW findings opened by this leg

**T11-40 (LOW/UX) — the World Phase footer navigation buttons are vertically clipped.**
Found with a one-variable control, same button on the same screen, only the step's
content height differing:

| Step | Content | `Next Step` | Page bg below |
|---|---|---|---|
| 4 · Assign Equipment | short | y 1447-1510, **h=64 px**, complete rounded border | 89 px |
| 2 · Crew Tasks | tall | y 1554-1590, **h=37 px**, no bottom border | 9 px |

The raw column at x=2400 shows button fill to y=1578, the white glyph of the label to
y=1590, then an abrupt snap to page background `rgb(10,13,20)` at y=1591 — the label is
sliced mid-stroke and the button's bottom border never renders. **27 px is cut.** It is
NOT the screen edge (9 rows of background sit below it), so the clip is a CONTAINER
boundary, and it tracks content height — the footer is not pinned, it flows. Same shape
as T11-01 / `ShortScreenScroll`, on a screen that sweep never covered. `← Back` and the
step pills are cut identically. Distinct from the fixed **T10-11** (footer entirely
absent on the Begin-Turn path): the footer is present here.

**T11-41 (LOW) — whole floats print `.0` in the Record Battle Result drawer.** The fifth
instance of the T11-33 class, on a surface that fix never reached:

```
Bryn Ito  CS:3.0 R:2.0 T:4.0 Spd:5.0     <- the drawer
Bryn Ito  C3 T4 Sv2 R2                   <- the battle crew rail, SAME screenshot
```

Two surfaces on one screen disagree about the same six characters' same stats — the
T11-34 split shape exactly, with the control visible in the same frame. Source confirmed,
not inferred: `src/ui/components/battle/BattleResultsInputForm.gd:630` builds the line
with four raw `str()` calls on values loaded from JSON, and Godot's parser returns every
number as a float. ⚠ **No value on that line can legitimately be fractional** — Combat
Skill, Reactions and Toughness are integers, and character Speed is a whole number of
inches (Core Rules p.94 prints Speed with the inch mark). Fix by routing all four through
the existing `DisplayText.number()` boundary; do NOT add a fifth private copy of the
transform, which is how T11-31 happened.

### Battle state carried into Pass C

Patron job **"Fight Off" / Reputable Official / Local Government**, enemy **5 × Enforcers**
(Tactical), Deliver objective (p.90), **Gloomy** condition (p.88), Curious Item notable
sight (p.89), 3×3 ft table, seed `2982481273`. ⚠ The job carries
`HAZARDS: Dangerous Job: Increase enemy force numbers by +1` — a **Patron** +1, structurally
identical in effect to the +1 that T11-25 and T11-35 grant. Pass D's forced Rival battle
must be confirmed to carry NO Patron hazard, or the two +1s become indistinguishable and
the attribution the plan already dissolved once comes back.

**Restore point for Pass C**: `walk21/save_S3_presubmit.json` (71,853 B, md5
`2df5169daaad1518b7678776c8ab70a8`), byte-identical to the post-resume pull — opening the
drawer mutates nothing. Battle active at Round 1, nothing submitted.


## Deploy #22 — Pass C on hardware: the forced rolls (2026-09-05, TB361FU HNQ05SR3)

Two restores of `save_S3_presubmit.json`, each its own post-battle. Every row below was
predicted in the dry run before the device was touched; the dry run's three corrections
and two eliminated hazards all held.

**Method note that made this cheap:** a new `walk21.py restore` command —
`adb push` → `/data/local/tmp/` → `run-as cp` into BOTH `<id>.save` and `<id>.save.bak`,
then an **on-device `md5sum` read-back** of each. It reported `restore VERIFIED` on first
use and on every later use, and the two cycles produced **byte-identical** dashboard
(365,777 B) and battle (374,934 B) captures — so the restore is exact, not approximately
exact. ⚠ It also repaired a live divergence found at the start of the leg: `.save` was
71,853 B (S3) while `.save.bak` was 70,861 B (S2, mid-battle), i.e. the fallback reader
would have silently loaded a *mid-battle* generation had the primary ever failed to parse.

### The four rows

| Row | Verdict | Evidence |
|---|---|---|
| **T11-19** | **PASS** | Forced `Character Event = 88` was **consumed** (on #19 it stayed `[pending: character event=88]` and never fired). Row 88-91 fired on **Nyx Ward**, and her `status_effects` now carries `{"type":"item_damaged","damaged_item":"Shotgun","source_event":"Don't Make Them Like They Used To","duration":0}` — exactly the shape `CharacterEventEffects.gd:651-658` writes. Artifact `walk21/save_C1_saved.json`. |
| **T11-25** | **PASS** | Forced `Campaign Event = 21` → Old Nemesis. Chooser offered exactly 3 options; picking **Feral Jackals** set `persistent=true`, `enemy_count_bonus=1`, `source_event="Old Nemesis"` on **that rival only** — the other rival stayed `riders:-` — and created **no** new rival (`resources.rivals` stayed at **2**). Artifact `walk21/save_C1_saved.json`. |
| **T11-35** | **PASS** | Forced `Campaign Event = 89` → Got Noticed. New rival `{"name":"Unwanted attention","id":"rival_228764_194","origin":"campaign_event","planet_id":"planet_9","created_turn":9,"source_event":"Got Noticed","enemy_count_bonus":1,"type":"Black Dragon Mercs"}`, and `progress_data.forced_rival_battle` **equals that id**. The Quest gate (`has_active_quest()`) resolved true, which is what applied the `enemy_count_bonus`. Artifact `walk21/save_C2_gotnoticed.json`. |
| **T11-20** | **PASS, both arms** | Arm 1: completing turn 9 took `turns_played` **8 → 9** (int). Arm 2 — the one where the defect lived — is proven by the ARTIFACT, not the screen: `walk21/save_C1_turn10.json` persists `turns_played = 9`. See the citation correction below. |

⚠ **T11-20 nearly went down as a false FAIL, and the reason is a method rule.** The first
pull after "Continue to Next Cycle" read `turns_played 8.0` while the Cycle Summary
displayed 9 — which is exactly the defect's signature. It is not the defect: that save was
written *during* the transition (`current_turn_phase 13` = Retirement) and therefore
predates the new turn's `_on_campaign_turn_started()` write. Forcing a save once Turn 10
was actually running read **9**. **A counter pulled mid-transition reads the pre-transition
value — force a save after the new turn has started, or the reading is inconclusive rather
than negative.** There is no `[T11-20]` print to disambiguate it, unlike T11-17.

⚠ **CORRECTED 2026-09-06 — arm 2 was cited to a reading that cannot disagree.**
This row originally cited the dashboard ("Begin Turn 10"). The dashboard derives its
turn as `turns_played + 1` and **never reads `turn_number`**
([CampaignDashboard.gd:1921](src/ui/screens/campaign/CampaignDashboard.gd#L1921),
`:1956`; same at `:525`/`:578`), so it renders "Begin Turn 10" identically with and
without the fix — the [[reference_a_diagnostic_that_cannot_disagree]] shape. The
verdict was right; the evidence named for it proved nothing.

**The discriminating evidence is the persisted counter.** In normal 5PFH play the SOLE
live writer of `turns_played` is
[CampaignTurnController.gd:824](src/ui/screens/campaign/CampaignTurnController.gd#L824),
`max(current, turn_number - 1)` — see **T11-46** below for why nothing else writes it.
Chronology of the pulled saves:

| artifact | `turns_played` | `current_turn_phase` | what it is |
|---|---|---|---|
| `save_S3_presubmit.json` … `save_C1_afterturn.json` | `8.0` (float) | 5 → 13 | JSON round-trip value, never rewritten |
| **`save_C1_turn10.json`** | **`9`** (int) | **9** (UPKEEP) | freshly WRITTEN by GDScript, Turn 10 running |

The int-vs-float split is itself the tell: a float came out of `JSON.parse`, an int was
written by this session. On disk `current` was **8** when that session began (the S3
restore), and `bind_campaign()` resets `turn_number = 0` on every load — so **without**
`_restore_turn_number_from_campaign` the write would have been `max(8, 0) = 8`. The
observed **9** is unreachable for the buggy build. The argument holds whether the 22:35
save came from the 22:23 relaunch's session or from a second relaunch after the cycle,
because `current` on disk was 8 either way.

### Re-confirmed in passing (no extra device time)

- **T11-38 — evidence now COMPLETE, in one file.** `save_C2_gotnoticed.json` holds the
  one-variable A/B: the rival `_append_rival` just wrote carries
  `origin`/`planet_id`/`created_turn`; both legacy rivals carry **none of the three**.
- **T11-16** both branches (Resume Battle — Turn 9 after restore; Begin Turn 10 after the
  turn rolled over). **T11-17** — `[T11-17] cache MISS, recovered from campaign owner:
  seed=2982481273.0 sectors=16` fired again on relaunch. **T11-37 = 0** safety timeouts and
  **T11-27 = 0** paused-tree errors, with **0 warn/error in 17,143 logcat lines**.
- **T11-39 fixed** — the QA dialog now renders list + detail pane + forced-roll row (it
  previously opened with ~900 px of dead space). **T11-15 working** — typing into the
  forced-roll value field raised the keyboard and the dialog **shifted up** so the field
  under edit stayed visible.
- **T11-41 still live** (expected, unfixed): the drawer shows `CS:3.0 R:2.0 T:4.0 Spd:5.0`.
- ⭐ **T9-51 CLOSED on hardware — both rows, from a stronger control than was planned.**
  The two cycles restored the **identical** `save_S3_presubmit.json`, so the queued roll
  was the only variable between them. Cycle 1 (forced `88`) fired row `[88,91]` *"Don't
  Make Them Like They Used To"* on **Nyx Ward**; cycle 2 (nothing queued) rolled
  naturally into row `[92,94]` *"Where Did It Go"* on **Mars Stark**. Those two bands are
  exactly T9-51's scope (`data/campaign_tables/character_events.json`, `_source: Core
  Rules pp.128-130`). The defect was a silent whole-function ABORT leaving **no status
  effect, no item removed, no return text** on any saved-and-loaded campaign; both
  effects are now present verbatim in the pulled saves, on a campaign that had been
  through save/load:
  `{"type":"item_damaged","damaged_item":"Shotgun","duration":0}`
  (`save_C1_saved.json`) and
  `{"type":"item_lost_recovery","lost_item":"Sonic Emitter","duration":1,"savvy_check_target":5}`
  (`save_C2_gotnoticed.json`) — the second of which *is* the p.130 "next turn D6+Savvy
  5+ = returns" recovery the abort used to erase. The deploy #19 line near the top of
  this document calling T9-51 unverifiable is corrected there.

### The dry run's predictions, scored

Confirmed on device: the two queue keys coexist (`[pending: character event=[88],
campaign event=[21]]`); dropdown order (**Character Event = index 3, Campaign Event =
index 4**); both rolls land in **one** post-battle (step 12 then step 13); the nemesis
chooser lists exactly 3 options in `campaign.rivals` order; **the nemesis popup does NOT
suspend the pipeline** (it sat open while the sequence ran to "Step 14 of 14"); the two
cycles are independent (cycle 2 discarded cycle 1's nemesis riders, as predicted).

Hazards that did not materialise, as predicted by the crew census: **no Precursor**
(no double-roll, no pipeline suspension) and **no Engineer** (no `species_exceptions`
exemption). The accepted 1-in-6 vacuous-effect risk also did not fire — the event selected
Nyx Ward (2 items), not Finn Mendez (0 items).

**One dry-run claim was wrong:** "the dashboard is exactly where the relaunch lands." The
relaunch lands on the **main menu**; reaching the QA dialog needs a **Continue Campaign**
tap first. Cheap, but it would have cost a confused minute mid-walk.


## Deploy #22 — Pass D on hardware: the forced Rival battle (2026-09-06, TB361FU HNQ05SR3)

The last device leg. Turn 10's World Phase walked end to end (6 steps), then **Proceed to
Battle** fired `_check_rival_encounter_backend` → the p.128 forced branch. Every assertion
below is re-derived from `walk21/save_D2_battle.json` (80,528 B, the round-1 checkpoint),
not from the screen.

**Pickup was free:** the app survived overnight at the same pid with Turn 10 live in memory,
and the on-disk save was still md5-identical to `save_C2_turn10.json`.

⚠ **That filename is a MISLABEL — corrected here rather than renamed, so the
artifact and the record still match.** `save_C2_turn10.json` does **not** hold Turn 10:
it reads `turns_played 8.0` with `current_turn_phase 13` (RETIREMENT), i.e. **end of
turn 9, mid-transition**, pulled before `_on_campaign_turn_started()` had written the
new count — the same mid-transition shape the Pass C method note warns about. What
makes it the right Pass D restore point is not its turn number but
`progress.forced_rival_battle = "rival_228764_194"`, which is the state Pass D
consumes. The genuine Turn-10 artifact is `save_C1_turn10.json` (`turns_played 9`,
phase 9).

### T11-35 — the battle side. **PASS**

| Assertion | Observed | |
|---|---|---|
| encounter is FORCED, no D6 | `forced: true`, `roll: 0` | PASS |
| against the right Rival | `rival_id: rival_228764_194`, `rival_name: "Unwanted attention"` | PASS |
| the book's own reason | *"Unwanted attention forces a battle this turn (Core Rules p.128 - Got Noticed while on a Quest)."* | PASS |
| the +1 reaches the mission | `mission_data.rival_enemy_count_bonus: 1` — the exact key `EnemyGenerator.gd:778` sums | PASS |
| carried by the encounter | `rival_encounter.rival_enemy_count_bonus: 1` | PASS |
| flag consumed exactly once | `progress.forced_rival_battle` **erased** (x0 occurrences in the save) | PASS |
| p.92 same type | `rival_type` / `enemy_type` = `Black Dragon Mercs` — the type stamped at the Rival's birth | PASS |

**T11-25 closes transitively here**, as planned: `_stamp_rival()` is the shared factoring
between the p.85 rolled path and the p.128 forced path, and it is what carried
`rival_enemy_count_bonus` onto this encounter.

### The attribution guard — resolved, and by a different route than the plan expected

The dry run's worry was that a `dangerous_job` hazard would supply a second, indistinguishable
+1. **It cannot**: `_apply_rival_ambush_override`'s erase list contains `"hazards"`, so the
displaced Patron payload is gone. Measured — **0 of 16 Patron keys leaked**:

> `hazards · benefits · conditions · patron · patron_name · patron_id · patron_type · pay ·
> danger_pay · job_id · job_type · time_frame · compendium_mission · type ·
> objective_description · is_affiliated_patron_job` — all ABSENT.

That makes this leg a live hardware test of the **T9-44 erase list**, not just of T11-35.
The control is real: the accepted job was *Deliver (Corporation), Sector Agent, +4 cr, enemy
**Zealots***, briefed on screen at Mission Prep one tap earlier. None of it reached the battle
— `mission_source`/`source` both read `rival`, and the enemy is Black Dragon Mercs.

**A second +1 did turn up, from an unplanned source, and it is separable.** The p.91 attack
type rolled `BROUGHT_FRIENDS` (+1 enemy). The two bonuses are applied by different layers:
`EnemyGenerator` sums `rival_enemy_count_bonus` into its count, while
`BattleSetupRules.apply_enemy_delta()` appends the p.91 figure afterwards and **labels it**.
The fielded force proves the split:

```
Black Dragon Mercs Lieutenant                  role=lieutenant     <- generator
Black Dragon Mercs                x4           role=standard       <- generator
Black Dragon Mercs Specialist                  role=specialist     <- generator   (6 total)
Black Dragon Mercs Specialist (Reinforcement)  role=standard       <- p.91 BROUGHT_FRIENDS
```

So the generator's six carry the Got Noticed +1; the labelled seventh is p.91's.
⚠ The count total alone would NOT have isolated it — the label is what makes it clean.

### Re-confirmed in passing

- **T11-07 across an unplanned overnight rotation.** The device auto-rotated to portrait and
  back on its own; `content_scale` held at **0.7830** through all three samples while `dpi`
  moved 1.000 → 2.000 (`win=2560x1600 dpi=1.000` · `win=1600x2560 dpi=2.000` ·
  `win=2560x1600 dpi=2.000`). A stronger test than the deliberate A/B, because nothing was
  staged.
- **T11-21** — the "Resolve without them?" dialog occupied y 586..982 of 1600 = **24.8%** of
  viewport height, and cites Core Rules pp.77-78 correctly.
- **p.76 upkeep is right on a High Cost world**: crew 6, trait "+2 for Upkeep purposes" = 8,
  charged **3 cr** (1 for 4-6, +1 per member past 6). Credits 21 → 18.
- The **Quest gate is still live** — step 5 auto-completed with *"Quest Active: The Hidden
  Coordinates … nothing to resolve"*, which is the same `has_active_quest()` the Got Noticed
  rider depended on.
- **Lay Low** offers *"pay 1D6+1 cr"* — the errata cost, not the book-literal one.

### T11-45 — a duplicated reinforcement keeps the NAME of the role it is not (LOW)

`BattleSetupRules.apply_enemy_delta()` (`:397-411`) duplicates the last figure, then
deliberately downgrades it — `role = "standard"`, `is_leader = false`,
`is_unique_individual = false` — with a correct comment: *"the book adds a rank-and-file body,
not a second Lieutenant."* But it builds the new name as `"%s (%s)"` off the duplicated
figure, so when the last figure happens to be a Specialist the roster reads **"Black Dragon
Mercs Specialist (Reinforcement)" with `role: standard`**. Confirmed in
`save_D2_battle.json`. A player reading the enemy list fields a Specialist figure for a body
the rules say is rank-and-file. Cosmetic, but on a companion app the roster IS the
instruction. Fix: build the name from the base enemy type rather than from `out[-1]`.


### T11-46 — `GameState.advance_turn()` is a zero-caller provider that live code names as its authority (LOW)

Found while re-deriving T11-20's evidence. `CampaignTurnController.gd:816-820`
justifies its `max()` write like this:

> *"GameState.advance_turn() is the MONOTONIC authority for turns_played (it does += 1
> at each turn's RETIREMENT). This turn-start sync must only ever RAISE turns_played …
> the old unconditional write clobbered advance_turn's already-incremented value back
> down."*

**That collaboration does not happen.** `GameState.advance_turn()`
([GameState.gd:1665](src/core/state/GameState.gd#L1665)) has **one definition and zero
callers in `src/`**. Every `advance_turn()` call site resolves to a *different* class's
method — `BugHuntCampaignCore` (`:311`), `PlanetfallCampaignCore` (`:555`),
`TacticsCampaignCore` (`:354`), `IntroductoryCampaignManager` (`:91`) — all reached
through `campaign.has_method("advance_turn")` guards on the CAMPAIGN object, never on
GameState. Its only caller repo-wide is `tests/unit/test_turn_counter_advance.gd:32`,
its own test. The `increment_turns_played()` call that used to sit beside it was removed
(`:830-832`).

So in standard 5PFH the `max()` at `:824` is not a non-regressing *sync* running
alongside a monotonic authority — **it is the only thing that writes `turns_played` at
all.**

**Why this is a row and not a comment tidy.** It makes T11-20's freeze TOTAL rather than
partial: there was no second, monotonic path that could have rescued the counter, which
is exactly what the pre-fix probe measured (`turn_number 0 → 1 → 2` while `turns_played`
sat at 8). And the comment actively misdirects the next person to edit `:824`, who will
believe a second writer is keeping the value honest. Same shape as
[[reference_a_dead_chapter_can_have_nothing_wrong_with_it]] — correct code, no caller —
with the added hazard that **live code documents it as live**, which no orphan or
dead-guard lint can see.

⚠ **Do not "fix" this by deleting `advance_turn()`.** It is the correct monotonic
implementation and its docblock records a real historical defect (the self-referential
`turns_played = _turn_number - 1` fixed point that froze every loaded save at turn 2).
This is a wire-or-document call: either route the 5PFH turn advance through it, or
correct `:816-820` to say the `max()` write is the sole writer. Owner's decision.

## The desk pass — 2026-09-06 (after the device legs closed)

All device legs were finished before any of this was applied, so the
"installed APK matches source" invariant the whole walk was run under is now
deliberately ended. **A rebuild is required before any further device work.**

### Fixed

| Row | Fix | Where |
|---|---|---|
| **T11-41** | Four raw `str()` calls routed through the shared `DisplayText.number()` boundary — no fifth private copy | `BattleResultsInputForm.gd:2,633-645` |
| **T11-42** | The subtitle `Label` now wraps, so it stops setting a 609 px container minimum against a 380 px window; buttons gained `clip_text` + ellipsis as the regression guard, and the popup now fits BOTH axes to its content (380–560 px) | `ItemChoicePopup.gd` |
| **T11-43** | `SpinBox.apply()` commits the typed text before `.value` is read | `QAScenarioDialog.gd:321-329` |
| **T11-44** | 8 producer sites → canonical moods; `MOOD_LEGACY_ALIASES` added for entries ALREADY IN SAVES; one `resolve_mood()` replaces three copies of the lookup; **`lint_journal_vocabulary.py` extended to the third vocabulary** | `JournalEntryTypes.gd`, `CampaignPhaseManager.gd`, `CharacterEventEffects.gd`, `PostBattlePhase.gd`, `scripts/lint_journal_vocabulary.py` |
| **T11-45** | The reinforcement's name is built from the base enemy `type`, not from the figure it was duplicated off | `BattleSetupRules.gd:404-414` |

**T11-44's lint half is detection-proven, both arms** — reverted one at a time,
never in a batch: a simple literal (`"triumph"` → `"positive"`) and the ELSE half of
the ternary (`"defeat"` → `"negative"`). The second matters because a single-literal
matcher would have validated the true arm and skipped the false one silently, and at
that site **both** arms were wrong. ⚠ The first version of the mood check also
reported a FALSE POSITIVE — it read the dict key in
`"mood": "somber" if d.get("detected", false) else "neutral"` as a bad mood. Call
arguments are now stripped before the literals are read; this lint's own docstring
is about why a noisy lint gets switched off.

### T11-40 — HALF done, and the half that is done is the one that let it hide

**Closed:** the harness gap. `WorldPhaseController.tscn` has been in
`verify_layout.gd`'s `SCREENS` list all along, and the sweep stayed green while the
tablet clipped 27 px off `Next Step` — because `screen_populator.gd` covered seven
screens and not this one, so all six phase panes were measured EMPTY, and an empty
pane is short. That is [[reference_an_unpopulated_screen_hides_the_defect]] (T11-01)
one screen along. `_post_world_phase()` now calls `initialize_world_phase()` with
`ship_data` / `crew_data.members` / `world_data` read off the loaded campaign
**exactly as `CampaignTurnController.gd:893-897` reads them** — same keys, same
fallbacks; a hand-built fixture would populate the screen with a shape the app never
produces, which is the failure this whole layer exists to avoid.

**Then the populated sweep was RUN** (windowed, campaign loaded, 8 screens hooked):
`passed=161 failed=7 skipped=0`, and **WorldPhaseController passed at every size** —
including the 48 dp touch-target floor that T11-40's 37 px button should trip. That
negative is what led to the real geometry, and to **T11-47** below.

**Reproduced at TRUE device pixels** (`tests/tools/probe_world_phase_footer.gd`,
windowed, same campaign):

| window | design | layout | footer on entry |
|---|---|---|---|
| 1280x800 (the sweep's "tablet landscape") | 1103x689 | **tight** | 712 px below the fold |
| **2560x1600 (the actual tablet)** | 2207x1379 | **tight** | **41.7 px below the fold** |
| 1600x2560 (tablet portrait) | 1379x2207 | relaxed — nav PINNED | fully on screen |

The 2560x1600 landscape row is T11-40 **in kind**: the World Phase stays in the TIGHT
layout, so `_apply_nav_pinning()` leaves the nav inside `ContentScroll` by design, and
the footer sits just below the fold on entry — present but cut, which is exactly what
distinguished T11-40 from T10-11 ("the footer is present here"). ⚠ The exact cut is
not claimed to match: the device measured 27 px on a different step at an unknown
scroll offset.

**Two hypotheses were killed by measurement, which is why no fix is being written:**

1. *"A tall step flips `_is_tight()`."* — **wrong.** `_phase_viewport_budget()`
   (`:331-362`) is built from `get_combined_minimum_size()` in fixed RELAXED units and
   explicitly EXCLUDES `PhaseContainer`; its docblock names the exact oscillation this
   assumed. Step content cannot move the decision.
2. *"The nav cannot be scrolled fully into view."* — **wrong.** At max scroll every
   control measures **100% visible** (56.0 of 56.0, 51.0 of 51.0) at both landscape
   sizes. So this is a first-paint scroll-offset problem, not a clipping one.

**The open question, stated so it is not re-derived:** at 1379 design px of height the
budget arithmetic should comfortably clear `MIN_PHASE_VIEWPORT_DESIGN_PX = 320`
(fixed chrome is roughly 330 of 1379), yet landscape still resolves TIGHT while
PORTRAIT at the same device resolves RELAXED. One candidate is a latch: the budget
loop subtracts the minimums of `ContentColumn`'s children, but `_apply_nav_pinning()`
MOVES `Controls`/`HSeparator2`/`Footer` out of that column whenever the layout is
relaxed — so the nav is subtracted while tight and not subtracted while relaxed, and
each state measures in the direction that preserves it. The docblock is careful to
keep the UNITS monotonic; the node LOCATION is a second input that moves with the
answer. **Unverified.** Fixing branch selection without knowing why risks breaking the
733x338 phone-on-its-side case the tight branch exists for, which is documented at
`_apply_nav_pinning()`.

⚠ Probe artifact, so it is not read as a finding: in the PORTRAIT (relaxed) row the
probe reports the nav "0.0 of 56.0 px visible" at max scroll. That is meaningless
there — relaxed layout puts the nav OUTSIDE `ContentScroll`, and the probe measures
visibility against the scroll's rect. The pinned `Footer y 2058..2106` inside a 2207 px
viewport is the number that matters, and it fits.

### The sweep, re-run at eight sizes — and what it still cannot see

`passed=217 failed=7 skipped=0`. The two true-pixel rows add **56 checks and ZERO new
failures**: at the tablet's real design space every screen passes, WorldPhaseController
included. All 7 failures sit at the smaller dp rows.

**Provenance established by the one-variable A/B the harness exists for.** A control run
with `-- populate=off` returns the **identical** `passed=217 failed=7` and the same seven
rows, so none of them comes from the fixture layer or from today's edits — they are
pre-existing, on three screens this pass did not touch:

| Screen | Sizes | Finding |
|---|---|---|
| `CampaignDashboard` | phone landscape, tablet landscape | a `"Corporate"` Label autowraps inside an HBoxContainer and collapses to a 1px-wide slab |
| `CampaignJournalScreen` | tablet landscape | `MarginContainer` off-screen by 14.3 px |
| `GalaxyLogScreen` | 4 of 6 dp rows | off-screen by 3.0 / 13.0 / 119.0 / 188.5 px, plus a SettingsOverlay band collision |

⚠ Also worth knowing: the control run printed `campaign state: campaign loaded` even with
no `campaign=` argument — `GameState` restores `last_campaign` at boot, so "no campaign"
is not the default and cannot be assumed.

⭐ **The sweep structurally cannot close T11-40, and that is now measured rather than
suspected.** Its `off-screen by N px` assertion deliberately exempts content inside a
`ScrollContainer` — correctly, since scrolled content is *meant* to exceed the viewport —
and in the tight layout the World Phase nav IS inside one. So the populator was necessary
but is not sufficient. Closing the harness half properly needs a **unit** assertion that a
primary navigation control is on screen at first paint, which is exactly the precedent
T11-01 set when it pinned the footer half in `tests/unit/test_short_screen_scroll.gd`
rather than in the sweep.

### T11-47 — the layout sweep's device-equivalence premise was silently invalidated by the T11-07 fix (MEDIUM, harness)

`verify_layout.gd`'s docblock stated that *"on BOTH desktop and device the design
space is (window_**dp** / EFFECTIVE_SCALE)"*, so a desktop window sized to a device's
dp reproduces that device's layout arithmetic. **That held only while
`content_scale_factor` still multiplied by display density.**

```
before T11-07:  design = window_px / (1.16 * dpi)   -> device 2560x1600 @dpi2 = 1103x689
after  T11-07:  design = window_px / 1.16           -> device 2560x1600       = 2207x1379
```

Measured both ends rather than derived: this desktop at a 1280x800 window prints
`content_scale=1.5660` and a design space of **1103x689**; the tablet prints
`content_scale=0.7830` at **2560x1600** physical (confirmed from the deploy #21/22
screenshots, all 2560x1600). Since `design = window / 1.16` on both, the tablet's
design space is **2207x1379 — exactly twice** the row the sweep calls "tablet
landscape".

**So every "tablet" verdict this sweep has produced since T11-07 was measured at half
the device's design space.** Nothing errored and no row went red; the rows simply
stopped naming the devices they are named after. It is also why the populated sweep
passed WorldPhaseController while the real device clipped its footer: at 1103x689 the
nav is 712 px below the fold and *inside a scroll*, which the sweep correctly exempts;
at the true 2207x1379 it is 41.7 px below the fold, the actual symptom.

**Fixed here:** the docblock is corrected at the claim, and two TRUE-PIXEL rows
(`2560x1600`, `1600x2560`) are added **alongside** the dp ladder rather than replacing
it — the smaller rows still exercise real breakpoints, and silently re-pointing them
would invalidate every verdict already recorded against those names.

⭐ **The transferable rule: a harness whose premise is an equation about PRODUCTION
code is invalidated the moment that code is fixed, and nothing will fail to tell
you.** T11-07 was a good fix, verified on hardware, and it quietly changed what every
row of an unrelated harness meant. When a fix changes a scaling or coordinate
formula, grep the harnesses for the old one.

Two hypotheses were formed and one was DISPROVED at source, which is why no fix was
written:

1. *"A tall step flips `_is_tight()`, which un-pins the nav by design."* — **wrong.**
   `_phase_viewport_budget()` (`:331-362`) is built from `get_combined_minimum_size()`,
   measured in fixed RELAXED units, and explicitly EXCLUDES `PhaseContainer` — the
   docblock says why in terms of the exact oscillation this hypothesis assumed. Step
   content cannot move the decision.
2. *A latch in that same budget.* — open, and worth a look when the sweep runs. The
   loop subtracts the minimums of `ContentColumn`'s children, but `_apply_nav_pinning()`
   MOVES `Controls`/`HSeparator2`/`Footer` out of that column whenever the layout is
   relaxed. So the nav is subtracted while tight and not subtracted while relaxed —
   each state measures in the direction that preserves itself. The docblock takes care
   to keep the UNITS monotonic; the node LOCATION is a second input that moves with
   the answer.

⚠ **Reproducing it needs a WINDOWED `verify_layout` run** (populated, at tablet
landscape). `--headless` cannot do it: `DisplayServer` returns dummy values, so
`window_set_size()` does nothing and every screen measures at the default rect — the
probe run for this row came back with `window.size = (1, 1)`. A windowed run opens a
focus-stealing window, so it is left for the owner to trigger. Writing a layout fix
for a symptom that has not been reproduced is exactly the T11-18 mistake, where a
confidently-worded causal note turned out to name 40% of the cause.

### Noted, not fixed — `test_turn_counter_advance.gd` exits 101 while PASSING

9 cases, 0 failures, **9 orphans** — one per test, "on test setup". `before_test()`
builds `auto_free(GameStateScript.new())`, a detached Node that gdUnit4 counts as an
orphan at the setup boundary. An untouched control suite exits **0** with 0 orphans,
so this is specific to this suite, and it arrived with the Sep 5 sprint's own new
restore tests rather than with today's edits. It is not a failure and the recorded
gate reads the CASE COUNT, not the exit code — but a passing suite that returns
non-zero is how a team learns to ignore exit codes, so it is recorded rather than
quietly left. Not fixed here: re-plumbing a green suite to silence a warning, at the
end of a batch, buys nothing for the product and can cost a real test.

### Gates after the desk pass

- **11 lints exit 0** (`lint_journal_vocabulary` CLEAN *with* the new mood check).
- Directly-affected suites: **86 cases / 6 suites / 0 errors / 0 failures**
  (`test_battle_results_input_form`, `test_battle_setup_rules`,
  `test_character_event_item_effects`, `test_character_event_effects_wiring`,
  `test_turn_counter_advance`, `test_qa_scenarios`).
- `lint_multiline_statement_breaks`: **873 scripts, 0 findings** — the guard that
  matters most here, since this pass inserted `const` declarations into two files.
- ⚠ **The full suite has NOT been re-run**, and the sheet/geometry suites have not
  been re-run windowed. Nothing is committed.

## OPEN — new findings from Pass C (2026-09-05)

### T11-42 — the Old Nemesis chooser renders three BLANK buttons (MEDIUM, player-facing)

Forcing `Campaign Event = 21` opened the "An Old Nemesis" popup with **three blue buttons
carrying no label text at all**, and the body prompt clipped mid-sentence at the panel's
right edge (*"An old nemesis has tracked you down (Core R"*). Evidence:
`walk21/C28_nemesis_popup.png` (2× crop).

**The data is fine — the rendering is not.** `PostBattleSequence._on_backend_nemesis_choice`
(`:793-814`) builds `labels` by iterating `choice["options"]` and **skips any empty label**
(`if label.is_empty(): continue`); three buttons appeared, so all three labels were
non-empty strings. `CampaignEventEffects` (`:242-248`) composes them as
`"<name> (<type>)"` — here "Feral Jackals (Mercenary Band)", "Old nemesis (persistent, +1
enemies) (Corporate)", "Roll up a new Rival". The strings exist and reach the popup.

⚠ **CORRECTED 2026-09-06 — the cause recorded here was wrong.** This row said "the
`ItemChoicePopup` presentation drops them". Source disproves that: `btn.text =
str(option_name)` is set for every option
([ItemChoicePopup.gd:94](src/ui/components/dialogs/ItemChoicePopup.gd#L94)) and the
colours are `COLOR_TEXT_PRIMARY` on `COLOR_ACCENT` (`:123`), i.e. light-on-blue, not
invisible. Nothing is dropped — the labels are rendered **outside the window's visible
rect**.

**The measured chain** (`tests/tools/probe_item_choice_popup.gd`, headless):

1. `CampaignEventEffects` passes a ~100-character prose prompt as `result_name`.
2. `show_choices()` builds it as a **`Label` with autowrap OFF** (`:73-80` — no
   `autowrap_mode` is ever set), so its minimum width is the whole string on one line.
3. That Label is the widest child of the `VBoxContainer`, so it sets the container
   minimum: **609 px** measured at `font_size 14`, and more at device scale.
4. The Window's width is **hard-fixed at 380** in `_init()` (`:23`); `show_choices()`
   adjusts only the HEIGHT (`:39-40`), and `unresizable = true`.
5. Every Button is `SIZE_EXPAND_FILL`, so each is stretched to the container width
   (probe: **577 px**), far past the 380 px window.
6. Button text is centre-aligned — so its centre lands beyond the window's right clip
   and **none of it is inside the visible rect**.

⭐ **The buttons' own labels were never the problem: the widest needs 363 px and would
have fitted in 380.** This is T11-18 again — *an overflow figure names the outermost
consequence, never the cause*; walk the min-width SPINE. `C28_nemesis_popup.png` shows
it directly: the blue buttons run off the right edge of the window, and the prompt Label
above them is clipped mid-word at that same edge — one cause, two symptoms, and the
clipped prose was the visible half all along.

**Fix direction is therefore the LABEL, not the buttons.** Set `autowrap_mode` on the
subtitle so the container minimum collapses to the window width, which un-stretches the
buttons on its own; add `clip_text` + `OVERRUN_TRIM_ELLIPSIS` on the buttons as the
regression guard so no future long option can reproduce it. Widening the window is the
wrong lever — 380 px is deliberate, and a prose string has no bounded width.

**Why this matters more than a cosmetic nit.** T11-25's whole purpose was to restore the
p.126 choice — *"Select a prior Rival, or roll up a new one"* — to the player. A chooser
with three visually identical blank buttons **implements the choice and withholds it**,
which is the [[reference_a_checked_rule_shown_to_nobody]] shape (T11-13) again: correct
backend, no user-facing surface. The popup also "refuses to close without a selection" by
design, so the player must pick one of three indistinguishable options to proceed.

⚠ **Scope beyond this row.** `ItemChoicePopup` is shared — `PostBattleSequence` uses the
same component for the Compendium p.137 illegal-salvage consequence (`_show_illegal_salvage_choice`),
so that prompt is likely blank too. Check both before calling this fixed.

⚠ **The walk only got the right answer by reading source.** With no labels, the selection
had to be made by ORDER, verified against `_on_backend_nemesis_choice` (labels are appended
in `options` order) and `_prior_rivals` (which returns `campaign.rivals` order). Button 1 =
Feral Jackals. Confirmed after the fact by the result line *"Feral Jackals is now an old
nemesis"*. A player has no such recourse.

### T11-43 — Queue Roll reads the PREVIOUS value when one is typed (LOW, debug-only tool)

Typing `89` into the forced-roll SpinBox and pressing **Queue Roll** queued **21** — the
value the dropdown had auto-filled. The status line said *"Queued 21 … [pending: campaign
event=[21]]"* while the field visibly displayed **89**. Pressing **Clear** and then
**Queue Roll** a second time — same visible field, no retyping — queued **89** correctly.

**Cause:** `QAScenarioDialog._on_queue_roll_pressed` reads `int(_roll_value.value)`. A
Godot `SpinBox` only parses its `LineEdit` text into `.value` on focus-loss or submit, so
a value typed and immediately followed by a button press is read at its *pre-edit* value.
The second press succeeded because focus had by then left the field.

**Impact is confined to the debug QA tool**, but it silently arms the wrong table row —
and the whole point of the seam is to reach a row you cannot otherwise reach, so a
tester chasing 89 would get 21 and a completely different rule. The status line is honest
(it names the value actually queued), which is the only reason this was caught.

**Fix direction:** call `_roll_value.apply()` (or read `_roll_value.get_line_edit().text`)
before reading `.value`, and/or set the value from the dropdown's `target` via
`set_value_no_signal` so the common path needs no typing at all.

⚠ Recorded as a **walk-method note, not a defect**: on the Campaign Cycle Summary the
button column **reflows upward ~45 px once "Save Campaign" is pressed** (the "Save your
campaign before continuing" warning disappears), which moves **"Retire the Crew (End
Campaign)"** — an irreversible action — into roughly where "Continue to Next Cycle" sat.
Scripted taps using a pre-save coordinate can land on it. A human re-reads the screen, so
this is a scripting hazard rather than a player-facing one.


### T11-44 — journal entries carry a MOOD outside the canonical vocabulary (MEDIUM, 8 sites)

Found in cycle 2's `godot.log`, recovered from the device before the next launch rotated
it away. Fired during the turn-9 → turn-10 rollover:

```
WARNING: Journal entry has non-canonical mood: 'positive'
   at: push_warning (core/variant/variant_utility.cpp:1034)
   GDScript backtrace (most recent call first):
       [0] validate_entry (res://src/core/campaign/JournalEntryTypes.gd:364)
       [1] create_entry (res://src/core/campaign/CampaignJournal.gd:93)
       [2] _on_character_event_expired (res://src/core/campaign/CampaignPhaseManager.gd:692)
       [3] _process_character_event_effects (res://src/core/campaign/CampaignPhaseManager.gd:644)
       [4] _process_turn_rollover (res://src/core/campaign/CampaignPhaseManager.gd:366)
       [5] start_new_turn (res://src/core/campaign/CampaignPhaseManager.gd:242)
```

`MOOD_STRING_TO_ENUM` (`JournalEntryTypes.gd:138-146`) accepts exactly eight values —
`triumph · defeat · neutral · somber · exciting · relieved · desperate · triumphant`.
**Eight `create_entry()` sites pass something else**, and every one falls silently back to
`Mood.NEUTRAL` through `mood_to_color()` / `mood_to_label()` (`:324-330`), so the entry
renders with the wrong label AND the wrong colour:

| Mood passed | Sites |
|---|---|
| `"positive"` | `CampaignPhaseManager.gd:674`, `:702` |
| `"negative"` | `CampaignPhaseManager.gd:702`, `CharacterEventEffects.gd:374` |
| `"informative"` | `CampaignPhaseManager.gd:2026`, `:2074` |
| `"discovery"` | `PostBattlePhase.gd:867`, `:883` |
| `"bittersweet"` | `PostBattlePhase.gd:947` |

⚠ **This is the exact class `scripts/lint_journal_vocabulary.py` was built for, in the one
vocabulary it does not cover.** That lint validates `type` and `tags` and contains **zero**
references to `mood` — so it reports **CLEAN** while all eight sites are live. The fix is
two-part and the lint half is the one that matters: map each value onto a canonical mood
(or add the members to `Mood` if the book warrants them), *and* extend the lint to the
third vocabulary, or this returns.

⚠ **Reached on the path Pass C's own evidence travels.** `_on_character_event_expired` is
the countdown/expiry handler for the status effects T11-19 creates, so every forced or
natural Character Event that leaves a timed effect writes one of these entries at the next
rollover.

⚠ **Corrects a CLAUDE.md gotcha.** That entry states `push_warning` / `push_error` go to
"Android logcat, **never** to `user://logs/godot.log`". This warning was read out of
`godot.log` with a full GDScript backtrace attached. The logcat-only half is still worth
keeping as a caution — but "never" is too strong, and a walk that skips `godot.log` on that
basis can miss a finding.


## Not reachable this walk

- ~~**T9-48** (Rival AMBUSH, D10=1) — queued and still pending; needs an actual Rival
  attack, which is a per-turn D6 gate. Would take several turns of grinding.~~
  ✅ **CORRECTED 2026-09-06 — CLOSED on deploy #23.** The reasoning above was wrong in a
  useful way: it treated the p.85 Rival-tracking D6 as the gate, when the D1 snapshot
  already carried `forced_rival_battle` armed, so the encounter was guaranteed and only
  the p.91 attack-type D10 was left to force. **No grinding was needed — the row was
  one restore and one queued roll away for three sprints.** See § deploy #23.
- Checklist §3 legibility as a formal pass; A5 `gl_compatibility` measurement (needs a rebuild).


## Deploy #23 — 2026-09-06 (versionCode 7, TB361FU HNQ05SR3, 2560x1600)

The rebuild that carries the Sep 6 desk pass. **Every fix it carries has a hardware
verdict, T9-48 is closed, and the walk opened one new finding.** Build identity was
provable from the artifact alone this time (`versionCode 6 -> 7`), so no marker print was
needed.

Method: three restores of saves this campaign actually produced
(`save_S3_presubmit.json` once, `save_save_D1_forcedbattle.json` twice), each followed by
a force-stop, a relaunch, and arming the forced-roll queue from the dashboard.

### Verdicts

| Row | Verdict | Evidence |
|---|---|---|
| **T11-41** whole floats in the drawer | **PASS** | `A3_drawer_crew_2x.png` — all six lines read `CS:3 R:2 T:4 Spd:5`, with the battle rail's `C3 T4 Sv2 R2` in the SAME frame. #22 showed `CS:3.0 R:2.0 T:4.0 Spd:5.0`. |
| **T11-42** blank nemesis buttons | **PASS** | `A4_nemesis_2x.png` — all three labels legible, the p.126 prose WRAPPED across five lines, buttons inside the window (popup measured **455 device px, about 392 design px**, inside the 380-560 clamp). |
| **T11-43** SpinBox reads the pre-edit value | **PASS, twice** | `A1_queued_row.png`: typed 89 over an auto-filled 21 and pressed Queue without leaving the field, status read *Queued 89 ... [pending: campaign event=[89]]*. Repeated on a D10 in `B1_queued_row.png` (*Queued 2* over an auto-filled 1). |
| **T11-44** non-canonical moods | **PASS, both halves** | *Producer:* a full battle + post-battle + turn rollover wrote 5 new journal entries, **every one canonical**, and **zero** `non-canonical mood` warnings in godot.log AND logcat (0 warn/error in 17,413 logcat lines). *Legacy alias:* `B0_lostitem_2x.png` — the turn-8 entry stored as `mood: "positive"` now renders **Triumph** with an emerald title where #22 rendered Neutral in grey. |
| **T11-45** reinforcement keeps the wrong role name | **PASS, strong control** | `save_B1.json` — the last GENERATED figure is a Specialist, and the addition reads **`Black Dragon Mercs (Reinforcement)` role=standard**. Pre-fix that same roster produced *Black Dragon Mercs Specialist (Reinforcement)* with `role: standard`, the name contradicting the role on one line. |
| **T9-48** prohibition rendered as a modifier | **CLOSED ON HARDWARE** | see below |
| **T11-48** | **NEW, OPEN** | see below |

**Re-confirmed in passing:** T11-15 (the QA dialog shifted up and kept the field under
edit visible while the IME was open), T11-16 (*Resume Battle — Turn 9* after a restore),
T11-17 (`cache MISS, recovered from campaign owner: seed=2982481273.0 sectors=16` — the
seed survived the restore), T11-18 (the Record Result drawer renders complete in landscape
with no horizontal clipping), T11-20 (turn advanced 9 -> 10 across the rollover), T11-21
(the *Resolve without them?* dialog at **24.8%** of viewport height, citing pp.77-78),
T11-25 (`resources.rivals` stayed at 2 and Feral Jackals gained `persistent` +
`enemy_count_bonus`), T11-27 and T11-37 (**0** paused-tree errors, **0** safety timeouts
across all three legs), and the **T9-44 erase list** (an accepted Deliver / Sector Agent /
Zealots job leaked **0 of 16** Patron keys into the rival battle).

### T9-48 — CLOSED ON HARDWARE, open since 2026-08-14

The prohibition branch needed a Rival **AMBUSH** (`roll_range [1,1]` on a D10, about 10%
per ambush), which is why three sprints failed to reach it. It turned out to be one tap
away the whole time: the D1 snapshot sits at Mission Prep with `forced_rival_battle`
armed, and `MissionTableManager.roll_rival_attack_type()` routes its D10 through
`DiceManager.legacy_randi_range()` — a forceable context key already in the QA dropdown.

**A one-variable A/B, identical restore, only the queued roll differing:**

| | B1 (queued **2**) | B2 (queued **1**) |
|---|---|---|
| `rival_attack_type` | `BROUGHT_FRIENDS` | **`AMBUSH`** |
| Seize block on screen | *Need 7+ on 2D6 (Savvy +2) — 58% chance* (blue) | **amber: *Ambushed by a Rival — no Seize the Initiative roll (Core Rules p.91)*, and NO roll line at all** |
| `setup_rules.can_seize_initiative` | `true` | **`false`** |
| `setup_rules.crew_cap_delta` | `0` | **`-1`** |
| `setup_rules.enemy_delta` | `1` | `0` |

Evidence: `B2_seize_2x.png` / `B1_seize_2x.png`, `save_B2.json` / `save_B1.json`.
Measured on 2026-08-13 this same surface rendered *Need 8+ on 2D6 (Savvy +2) — 42%
chance* for an Ambush: the normal 7+ with the p.91 Rival -1 applied, i.e. **a harder roll
rather than no roll, which is the most convincing possible wrong answer.** It now prints
the prohibition and suppresses the roll.

⚠ The briefing also states the other half — *Deploy one fewer crew than standard* — and
`crew_cap_delta = -1` is computed and stamped. **That half does NOT bind. See T11-48.**

### T11-48 — the crew the player selects is discarded; three deployment rules never bind (MEDIUM, NEW)

Found by checking a number rather than assuming it: the AMBUSH battle deployed **CREW 6/6**
(`B2_rail.png`) under a cap that had just been computed as **5**.

`PreBattleUI` is correct throughout. `setup_crew_selection(crew, max_deploy)` pre-selects
up to the cap (`:922-925`), `_on_character_selected()` refuses a toggle past it
(`:937-943`), and `_update_deploy_label()` prints *Deploying N / M max*. The caller is
correct too: `CampaignTurnController._launch_pre_battle_directly()` computes
`deploy_limit = campaign_crew_size + crew_cap_delta`, applies the p.84 `crew_cap_max`
ceiling AFTER the deltas, and passes it in (`:1837-1847`).

**Then nothing reads the answer.** `_on_deployment_confirmed()` rebuilds the battle crew
from scratch:

```gdscript
var crew_data = _deployable(game_state.get_active_crew())   # :2777 - the WHOLE roster
```

`PreBattleUI.get_selected_crew()` (`:1151`) has **ZERO callers repo-wide** (`src/` and
`tests/`), and the `crew_selected` signal is emitted twice inside PreBattleUI and
connected by nobody. ⚠ The same handler DOES reach into PreBattleUI on the adjacent lines
for `selected_representation_mode` (`:2768`) and `selected_tier` (`:2784`) — so the tier
and the combat mode cross the boundary and the crew does not.

**Three book rules ride on that discarded value:**

- p.91 Rival **Ambush** — *you can deploy one crew member less than standard* (`crew_cap_delta -1`)
- p.88 **Small Encounter** — *a random crew member sits out* (same delta path)
- p.84 **Small Squad** — *You cannot deploy more than 4 crew* (`crew_cap_max`, the absolute ceiling)

⚠ **The comment at `:1835-1836` says the cap "was previously always the full campaign crew
size, so neither ever bit".** The fix that comment describes went into COMPUTING
`deploy_limit` correctly, and the computed value still never reaches the battle. This is
the implemented-but-never-called shape with the extra twist that a previous fix already
landed on the producing half.

⚠ Separately, and possibly why nobody noticed: on this tablet in landscape the Select Crew
panel renders **empty and below the fold**, and the Mission Info column would not scroll to
it across four attempted gestures (`B2_selectcrew.png`). So the player cannot see the
*Deploying N / M max* label either. Whether that is a second defect or the same layout
family as T11-40 is **not established** — recorded as observed, not diagnosed, because
guessing a cause is what produced the wrong T11-42 note.

**NOT fixed here.** It is outside this sprint's scope (verify the five carried fixes plus
T9-48), it changes battle composition, and it needs its own detection proof plus a unit
test pinning "the deployed crew equals the selected crew" across all three cap sources.

### T11-46 — CLOSED at the desk (comment corrected, no behaviour change)

Owner's decision: correct the comment, leave `GameState.advance_turn()` alone. Applied at
`CampaignTurnController._on_campaign_turn_started()` (the `max()` write is named as the
SOLE 5PFH writer, with the full zero-caller trace and the reason deleting `advance_turn()`
would be wrong), at `_on_campaign_turn_completed()` (**a second stale comment making the
same claim, found while fixing the first**), and as a docblock note on
`GameState.advance_turn()` itself. Re-routing the 5PFH turn advance stays available as an
owner's call; it is a behaviour change to a counter whose fix was just verified on
hardware, so it is not a tidy-up.

### T11-40 — the latch is PROVEN (diagnosis only, no fix this sprint)

`tests/tools/probe_world_phase_footer.gd` now measures `_phase_viewport_budget()` in BOTH
pinning states at the same size. **The budget depends on where the nav currently lives:**

| window | viewport | nav INSIDE ContentColumn | nav PINNED outside | threshold |
|---|---|---|---|---|
| 1280x800 | 689.7 | **244.7 -> tight** | **502.7 -> relaxed** | 320 |
| 2560x1600 | 1379.3 | 925.3 -> relaxed | 1190.3 -> relaxed | 320 |
| 1600x2560 | 2206.9 | 1757.9 -> relaxed | 2015.9 -> relaxed | 320 |

The 1280x800 row is a genuine **latch**: 244.7 < 320 keeps the nav inside, which keeps the
budget at 244.7; 502.7 > 320 keeps it outside, which keeps the budget at 502.7. **Both
states are stable fixed points, so the layout is decided by whichever one it happens to
reach first.** The delta is **258.0 px**, exactly `Controls 134 + HSeparator2 4 + Footer 48
+ 3 x RELAXED_SEPARATION_PX 24` — the nav's own contribution, subtracted only while it is
inside the column.

**The docblock at `_phase_viewport_budget()` is careful to keep the UNITS monotonic (it
measures in fixed RELAXED units precisely to stop the answer feeding back). Node LOCATION
is a second input, and it moves with the answer.**

⚠ **A correction to the earlier note in this document.** It said landscape "resolves TIGHT
while portrait resolves RELAXED" at the device size. Measured: at 2560x1600 `_is_tight()`
returns **false** in both pinning states — but the VBox children listing shows the nav
still INSIDE `ContentScroll`, i.e. the **tight ARRANGEMENT with a relaxed DECISION**. The
two are out of sync, which is why the footer sits below the fold on a screen the code
considers roomy. That is a sharper statement of T11-40 than the original.

At max scroll every nav control is 100% visible at both landscape sizes, so this remains a
first-paint scroll-offset problem, not a clipping one — and the sweep still cannot see it,
because content inside a `ScrollContainer` is legitimately allowed to exceed the viewport.

**Fix shape (unwritten, for the owner):** make the budget location-independent — subtract
the nav's minimum wherever it lives, or exclude it symmetrically — and re-apply
`_apply_nav_pinning()` whenever the decision changes. Closure belongs in a unit test
asserting the two budgets are EQUAL, plus the 733x338 phone-on-its-side case the tight
branch exists for.

### Walk-method defect found and fixed (affects how #21/#22 were driven)

`walk21.py`'s `_wait()` shelled out to Windows `timeout /t N /nobreak`. That command
**aborts instantly** with *Input redirection is not supported* whenever stdin is not a
console, which it is not under this harness — so **every wait in the deploy #21 and #22
walks was a no-op**, covered up by adb's own latency. Measured on #23: a tap followed by a
screenshot returned a **byte-identical** frame and `walk21.py diff` reported *IDENTICAL —
the control did nothing*, which reads exactly like a dead button. Replaced with
`time.sleep`. ⚠ It did not invalidate the #21/#22 verdicts, which were artifact-based, but
it is a live false-negative generator for any screenshot-driven step.

### Gates

Full `tests/unit` headless in 9 batches of at most 34 suites: **281 suites, 3,094 cases, 0
failures, 0 errors, no signal 11.** Exit 101 on several batches is gdUnit4's ORPHAN code
(269 suites report `0 orphans`, 10 report some), not a failure. ⚠ The runner's own crash
heuristic produced a FALSE POSITIVE by matching the `crash_site` battlefield theme; it was
checked against `signal 11` / `SIGSEGV` before being believed.


## The desk pass after deploy #23 — 2026-09-06, T11-48 and T11-40 FIXED

Both were opened by the deploy #23 walk and are now fixed at the desk, each
detection-proven by isolated revert and pinned by a new unit suite. **Neither has a
device verdict yet** — they need a deploy #24.

### T11-48 — FIXED (the selection now reaches the battle)

| Part | Change | Where |
|---|---|---|
| The rule | New `apply_crew_selection(roster, chosen)`, a pure static beside `apply_enemy_delta()` — its enemy-side analogue — so it is testable with no tree, matching that file's stated design | `BattleSetupRules.gd` |
| The widget | `setup_crew_selection()` made IDEMPOTENT: it cleared neither the panel nor `selected_crew`, so a re-entry stacked a duplicate button list and kept the OLD picks (the pre-select loop only fills up to `_max_deploy`, so every new button rendered unpressed while stale picks stayed live) | `PreBattleUI.gd` |
| The consumer | `_on_deployment_confirmed()` now filters the roster through the rule | `CampaignTurnController.gd` |

**Identity is `FPCM_BattleCheckpoint.member_key()`**, the rule the battle checkpoint
already filters a roster with, and whose docblock asks callers to reuse it so two
copies cannot drift. Object equality would have been the wrong tool: the selection
holds the items handed to `setup_crew_selection()` while the handler re-reads
`get_active_crew()`, so whether those are the same instances is an implementation
detail of the getter.

**Every ambiguous input returns the roster untouched** — an empty selection, a
selection carrying no usable key, or a filter matching nobody. An empty selection
means the selector never ran (its caller guards on a non-empty roster, and Confirm
stays disabled while nothing is picked), NOT that the player chose to field nobody.
Fielding an empty force off a matching failure would be worse than the defect.

**Pinned by `tests/unit/test_deployment_selection.gd` (17 cases)**: the filtering, the
four fallbacks, the three cap SOURCES each to its page, the ceiling-after-deltas
ordering, an end-to-end pass through a real `PreBattleUI`, and the call site itself.

⚠ **The call site is asserted deliberately.** Every other case in that suite calls the
rule directly and would STILL PASS with the handler ignoring it again — which is
precisely what T11-48 was. The scan is anchored on the enabling form
(`crew_data = BattleSetupRulesClass.apply_crew_selection`) and paired with a
`can_instantiate()` case, because a source scan proves the right words are present and
never that the file compiles.

**Detection-proven, three arms, one at a time** (gdUnit4 aborts a suite after its
first failure, so a batched revert would hide which case is load-bearing):

| Reverted | Case that went red |
|---|---|
| the consumer stops calling the rule | `test_the_confirm_handler_actually_consumes_the_selection` |
| the widget stops clearing its state | `test_setup_crew_selection_is_idempotent` |
| the rule stops filtering | `test_a_selection_of_five_fields_exactly_those_five` |

⚠ **A fixture-shape correction worth keeping.** The first Small Squad case put
`max_deploy_crew` at the TOP level of `mission_data` and read 0. The real shape hangs
the condition off the job (`{"conditions": ["small_squad"]}`) and
`PatronJobEffects._resolve()` accepts a bare id, so the 4 now comes out of the shipped
`data/patron_generation.json` instead of being retyped in the test.

### T11-40 — FIXED (the budget no longer depends on the layout it produces)

`_phase_viewport_budget()` subtracted the minimum of every visible non-Phase child of
`ContentColumn`, and `_apply_nav_pinning()` moves Controls / HSeparator2 / Footer out
of that column when relaxed. The nav is now subtracted ALWAYS, by name, wherever it is
parented, and the column loop skips those three names so nothing is counted twice.

That is not merely consistent, it is correct: the nav costs its height in both
arrangements — inside the column it is scrolled content, pinned outside it sits
between the scroll and the screen edge.

**Measured before and after, same probe, same campaign:**

| window | viewport | nav inside | nav pinned | after the fix |
|---|---|---|---|---|
| 1280x800 | 689.7 | 244.7 -> tight | 502.7 -> relaxed | **244.7 both -> tight** |
| 2560x1600 | 1379.3 | 925.3 | 1190.3 | **921.3 both -> relaxed** |
| 1600x2560 | 2206.9 | 1757.9 | 2015.9 | **1757.9 both -> relaxed** |

At the true device size the nav is now PINNED and the footer ends at y 1279 of a
1379.3 px viewport — fully on screen. That is T11-40's symptom resolved. The 1280x800
row stays TIGHT, which is correct: it is the genuinely cramped case the tight branch
exists for, and scrolling to the nav there beats pinning it.

**Pinned by `tests/unit/test_world_phase_budget.gd` (4 cases)** and detection-proven:
reverting to the pre-fix body fails
`test_the_budget_does_not_depend_on_where_the_nav_is_parented` immediately. The cases
are deliberately SIZE-INDEPENDENT — headless gives a dummy DisplayServer where
`window_set_size()` does nothing, so a case pinned to 1280x800 would assert against
whatever rect the harness happened to provide. The invariant needs no particular size.

⚠ **A probe artifact was corrected rather than filed as a finding.** The first run
showed 2560x1600 with a relaxed DECISION beside a tight ARRANGEMENT, which reads like
a product desync. It is the probe: it adds the instance immediately after
`window_set_size()`, so `_ready()` decides on the PREVIOUS size — the same
one-size-behind trap as T11-04. The probe now re-runs `_apply_vertical_compaction()`
once the size has settled, which is the faithful stand-in for the `size_changed` /
`layout_class_changed` the device delivers. In the product both triggers are wired.

### Gates

Layout sweep at eight sizes: **passed=222 failed=2**, and WorldPhaseController passes
at every size. ⚠ **That is NOT a like-for-like improvement on the 217/7 recorded
above** — the desktop fixture campaign was replaced with the walk's D1 snapshot for
the probe, so the journal and galaxy screens render different content. The claim that
holds is the narrow one: **no NEW failures, and the two that remain are among the
seven already filed** (the `CampaignDashboard` "Corporate" Label slab).


## Deploy #24 walked on hardware — 2026-09-06. T11-48 PASS, T11-40 PASS

`build/deploy24.apk`, **versionCode 8**, installed over #23 and md5-verified against
the built artifact on the device (`c84bfffe08867e8995312d4c1ff8ad6e`, both sides).
Lenovo TB361FU, landscape (`mCurrentRotation=ROTATION_90`), fixture
`walk21/save_save_D1_forcedbattle.json` restored and md5-verified into BOTH `.save`
and `.save.bak`, then force-stopped so `bind_campaign()` re-reads it.

### T11-48 — PASS. The selection now reaches the table.

Forced the p.91 attack-type D10 to **1 = AMBUSH** from the QA dialog after the
relaunch (the force-stop wipes `DiceManager._forced_results`, so it must be armed from
the dashboard), then walked all six World Phase steps to the battle.

**A one-variable A/B against deploy #23's own artifact.** `save_B2.json` was pulled
from the SAME snapshot, the SAME forced roll and the SAME rival on the pre-fix build,
so every input below is identical and exactly one output moved:

| | deploy #23 (vc7, pre-fix) | deploy #24 (vc8, fixed) |
|---|---|---|
| mission | Rival Attack: Unwanted attention | *same* |
| `rival_attack_type` | AMBUSH | AMBUSH |
| `setup_rules.crew_cap_delta` | -1 | -1 |
| `setup_rules.can_seize_initiative` | false | false |
| `campaign_crew_size` | 6 | 6 |
| roster (`crew.members`) | 6 | 6 |
| **`progress.active_battle.crew`** | **6** | **5** |

The battle screen agrees with the save: the crew rail reads **`CREW 5 / 5`** and
`ACTIVATED 0/5`, listing Bryn Ito, Dex Kovac, Yuri Drake, Mars Stark and Finn Mendez.
**Nyx Ward sat the battle out** — which is the p.91 Ambush reduction, on the table,
for the first time.

⭐ **The fixture is what makes this discriminating.** All six crew are ACTIVE, none
in Sick Bay and none carrying a `skip_next_battle` status, so `_deployable()` filters
nobody — the only thing in the app that can turn 6 into 5 here is
`BattleSetupRules.apply_crew_selection()`. Had a crew member been unavailable for any
other reason, a 5 would have proved nothing.

⚠ **The `Deploying 5 / 5 max` counter was NOT read on screen, and that is not a
failure of the fix.** The Select Crew pane is pane 4 of 4 against `max_columns = 3`, so
it wraps to row 2 and is allocated header height only at 2560x1600 — the same
clipping recorded at the deploy #23 row above, present in `B2_selectcrew.png` on the
PRE-FIX build (where the header was additionally sliced mid-glyph). It is therefore
**pre-existing and NOT a regression from this fix**; if anything the header now renders
whole. The selection still binds because `setup_crew_selection()` pre-selects up to
`_max_deploy` programmatically, which is precisely what the save then proves. Note the
outer scroll IS live — dragging the scrollbar at x=2532 scrolls the page — but a
touch-swipe over any pane does not reach it; recorded as observed, not diagnosed.

Artifacts: `V3_queued_crop.png` (roll armed), `VP_prebattle.png` (the amber
*"Ambushed by a Rival — no Seize the Initiative roll (Core Rules p.91)"* with no
"Need N+ on 2D6" line), `X2_battle.png` (`CREW 5 / 5`), `save_V_ambush.json`.

### T11-40 — PASS. Measured with the finding's own instrument.

The original row was established by a one-variable control: the same `Next Step` button
on the same screen, differing only in the step's content height. Both arms were re-run
on #24 and the raw column at **x=2400** re-walked, exactly as the row describes.

| Step | Content | deploy #23 (pre-fix) | deploy #24 |
|---|---|---|---|
| 4 · Assign Equipment | short | y 1447-1510, h=**64**, 89 px bg below | y 1381-1446, h=**66**, **122 px** below |
| 2 · Crew Tasks | tall | y 1554-1590, h=**37**, 9 px bg below | y 1381-1446, h=**66**, **122 px** below |

The 27 px that used to be cut are back: the label is no longer sliced mid-stroke, the
bottom border renders, and `← Back to Dashboard` sits at y 1507-1562 with 37 px of
page background beneath it.

⭐ **The stronger result is that the button stopped MOVING.** The row's diagnosis
was *"it tracks content height — the footer is not pinned, it flows"*. On #24 the
Crew Tasks content grew from a 61 px band to a 94 px band when the task results
rendered, and the button stayed at **y 1381..1446 through both**, and reported the
identical rect on Steps 1, 2 and 4. The budget no longer depends on the arrangement it
produces, which is the desk fix reproducing on hardware.

Artifacts: `V9_s1_after.png`, `VC_tasksdone.png`, `VK_s3_after.png`, and the column
scans from `col_t1140.py`.

### Regressions checked, none found

`logcat` **0 warn/error** across the walk; `Safety timeout = 0` (T11-37 holds);
paused-tree errors **0** (T11-27 holds); `godot.log` clean of `SCRIPT ERROR` /
`Nonexistent` / `Invalid call` / `Parse Error`; `[T11-07] dpi=1.000 ->
content_scale=0.7830` (the density double-count stays fixed); `[T11-17] branch=CONSUME
bf_seed=3803264237` (the battlefield contract was consumed, not regenerated).

The tablet was handed back on `walk21/dev_now_0906.json` — the exact state it was
in before this walk, md5-verified into both `.save` and `.save.bak` — with the app
force-stopped and `svc power stayon` restored to false.
