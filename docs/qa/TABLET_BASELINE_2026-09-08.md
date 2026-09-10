# Tablet baseline — deploy #27, A5 arm A + §1/§4/§6 (2026-09-08)

**Taken BEFORE flashing deploy #28**, because arm A is only measurable on the build that is
already installed. Device: **Lenovo TB361FU**, Android **16** (SDK 36), `arm64-v8a`, 2560×1600.
Installed build: `com.reptarus.fiveparsecs` **versionCode 11 / 0.9.7**, installed 2026-09-07
14:11 — this is deploy #27.

Session ran ~12 min continuously, mains-powered, battery 100%, landscape (`ROTATION_90`).
`screen_off_timeout` was already 1800000; **nothing was changed, so nothing needs restoring.**

---

## ⚠ Three instrument corrections — read before reusing any of these numbers

**1. `dumpsys thermalservice` prints TWO temperature blocks and only one is live.**

```
Cached temperatures:                 <- STALE
	CPU 52.777   GPU 52.777   NPU 53.465
Current temperatures from HAL:       <- LIVE
	CPU 29.128   GPU 28.945   NPU 28.639   SKIN 25.72   BATTERY 23.9
```

A `grep 'Temperature{'` without the section headers returns both and the first block wins.
Doing that here would have recorded **52.8 °C as the idle baseline**, against a true idle of
**29.1 °C** — and then every later under-load sample would have read *cooler than idle*.
**Always `sed -n '/Current temperatures from HAL/,/Current cooling/p'` first.**

**2. `POWER_AMPLIFIER` is a stub sensor — exclude it.** It reports `mValue=125.0,
mStatus=6` (SHUTDOWN) identically in both blocks, never moves, and sits above its own
110 °C shutdown threshold — while device-level `Thermal Status: 0`. If the framework
believed it, the device status could not be 0. Treated as a sentinel, not a reading.

**3. `Graphics`, not `Native Heap`, is the A5 instrument.** The plan specified
"`dumpsys meminfo` (Native Heap / TOTAL PSS)". Measurement shows those rows separate
cleanly, and the plan picked the wrong one:

| Transition | Native Heap | Graphics |
|---|---|---|
| main menu → campaign loaded | 142,920 → **204,752** (+61.8 MB) | 432,624 → 432,380 (**flat**) |

Loading a campaign moves Native Heap by 62 MB and leaves Graphics untouched. So
**Native Heap = game state, Graphics = the renderer's allocation** — and A5 changes the
renderer. `Graphics` is also 63 % of total PSS here, so measuring Native Heap would have
missed most of the effect while drowning in campaign-data noise.

`Graphics` = `EGL mtrack` + `GL mtrack` exactly (146,268 + 284,308 = 430,576). ⚠ Note this
qualifies CLAUDE.md's "never `GL mtrack`" guidance from T9-08: on this Mali-G57 driver
`GL mtrack` is *not* zero and is the larger half of Graphics. The safe rule is to read the
**`Graphics` row of App Summary**, which composes both.

---

## A5 arm A — the baseline configuration, from the device

`project.godot` pins **no** `rendering_method`, so arm A was an assumption. The device log
settles it:

```
Godot Engine v4.6.stable.official.89cea1439
Vulkan 1.3.219 - Forward Mobile - Using Device #0: ARM - Mali-G57 MC2
```

**Arm A = Forward Mobile on Vulkan 1.3.219, Mali-G57 MC2.** Phase 3's "pin the baseline in
`project.godot`" now has a verified value to pin rather than a guess. It also confirms the
plan's instrument reasoning: `RenderingDevice` exists on arm A (Vulkan) and will not on arm B
(`gl_compatibility` → OpenGL), which is why the cross-arm instrument has to be `dumpsys`.

### Memory (KB, `dumpsys meminfo` App Summary)

| State | Java Heap | Native Heap | Code | Graphics | **TOTAL PSS** |
|---|---|---|---|---|---|
| Main menu | 12,236 | 142,920 | 80,008 | 432,624 | **688,989** (673 MB) |
| Campaign loaded (turn 10, 6 crew) | 13,696 | 204,752 | 80,040 | 432,380 | **756,670** (739 MB) |
| Print Sheet open (preview) | 13,592 | 187,684 | 80,092 | 432,380 | **739,560** (722 MB) |
| After PNG export, back in-app | — | 187,656 | — | 432,768 | **732,435** (715 MB) |

**Graphics is flat at ~432 MB across every state** (spread 388 KB = 0.09 %). That stability is
what makes it a good arm-B comparator: any movement under `gl_compatibility` is the renderer,
not the workload.

⚠ **The export peak was NOT captured.** Opening Print Sheet does not allocate the 2764×1843
SubViewport — the preview renders into the existing viewport, and only `export_to_png`
allocates it (`docs/sop/sheet-export.md`). Polling `dumpsys` at ~1.5 s intervals across the
export never saw a rise, so the allocation is shorter-lived than the sampling interval. Do not
read the flat numbers as "the export is free" — it is **unmeasured**, and catching it needs
in-app instrumentation, not `dumpsys`.

### Cold start

`am start -W`, process not running: **`LaunchState: COLD`, `TotalTime: 979 ms`,
`WaitTime: 985 ms`.** ⚠ That is time-to-first-frame of the activity, which for a Godot app is
not necessarily an interactive main menu — treat it as a launch-cost figure, not "time until
the player can tap".

### CPU

**52.5 %** on the Print Sheet screen, `top -d 2 -n 2` (second sample; a single `-n 1` sample
read 59.2 % and is not trustworthy). CLAUDE.md records 32 % main menu / 37 % dashboard — the
Print Sheet had **no prior baseline**, so this is a new data point for a continuously-rendering
screen, **not** evidence of a regression against those two.

---

## §4 Performance / thermals — **PASS**, and the first thermal data this project has

Live HAL temperatures across the session:

| Point | CPU | GPU | SKIN | Battery | Status |
|---|---|---|---|---|---|
| Ambient (app not running) | 29.1 | 28.9 | 25.7 | 23.9 | 0 |
| Main menu, +12 s | 37.2 | 37.2 | 28.6 | 23.9 | 0 |
| Campaign loaded | 40.8 | — | 29.8 | 24.3 | 0 |
| Print Sheet | 40.5 | — | 30.0 | — | 0 |
| ~12 min sustained | 38.5 | 38.5 | 30.2 | 24.7 | 0 |

**CPU plateaus at 38-41 °C; SKIN plateaus at ~30 °C.** `Thermal Status` never left **0**
(`THERMAL_STATUS_NONE`) — no throttling at any point.

The device's own throttling thresholds, which is what §4 was missing (the SOP at
`docs/sop/android-runtime-testing.md:256-267` defines only FPS/frame-time/draw-call limits and
has no thermal axis at all). Array index = thermal status; 0-2 are `NaN` on this device:

| Sensor | SEVERE(3) | CRITICAL(4) | EMERGENCY(5) | SHUTDOWN(6) | measured peak | headroom |
|---|---|---|---|---|---|---|
| CPU | 85.0 | 90.0 | 100.0 | 117.0 | 40.8 | **44.2** |
| GPU | 85.0 | 90.0 | 100.0 | 117.0 | 38.5 | **46.5** |
| **SKIN** | **50.0** | 70.0 | 80.0 | 90.0 | **30.2** | **19.8** |
| Battery | 50.0 | 55.0 | 59.0 | 60.0 | 24.7 | 25.3 |

**SKIN is the binding sensor on a handheld** — it throttles first (50 °C) and it is what the
player feels. ~20 °C of headroom under sustained play.

⚠ CPU, GPU and NPU report byte-identical values at every sample (37.215 / 38.499 …). They are
one SoC sensor surfaced three times, **not three independent measurements** — do not average
them or report them as corroborating.

---

## §6 Scoped storage — **PASS** (the plan's flagged silent-failure risk does not reproduce)

The concern on record: at targetSdk 35 with no storage permission, a plain dialog write
**fails silently with error 13**. Walked end to end:

1. Print Sheet → **Save PNG**
2. Godot hands off to the **Android SAF picker**
   (`com.google.android.documentsui/…PickActivity`), filename pre-filled
   `crew_log_2026-09-08T08-48-44.png`
3. SAVE → app returns to foreground
4. **File on disk**: `/sdcard/crew_log_2026-09-08T08-48-44.png`, **243,816 bytes**
5. **Artifact verified, not assumed**: PNG header reads **2764×1843**, bitdepth 8, colortype 2
   (RGB) — an exact match for the size `docs/sop/sheet-export.md` documents

So `ACCESS_FILESYSTEM` + `use_native_dialog=true` (`PrintSheetScreen.gd:363-381`) is the
correct mitigation and it works on hardware. **This is the arm-B regression target**: if
`gl_compatibility` breaks the large SubViewport (godot#103181), this is the operation that
fails, and there is now a passing reference to compare against.

### ⚠ New observation — `VK_ERROR_SURFACE_LOST_KHR` on every background

```
ERROR: QueuePresentKHR failed with error: VK_ERROR_SURFACE_LOST_KHR
   at: command_queue_execute_and_present (drivers/vulkan/rendering_device_driver_vulkan.cpp:3064)
```

Logged when the SAF picker takes the foreground. The app **recovers cleanly** — it returned to
foreground and Graphics came back to 432,768 KB (vs 432,624 at main menu, 0.03 % apart) — so
this is not currently a defect. Recorded because it is an ERROR-level line that will appear in
any future log around a file dialog, and it should not be re-diagnosed as a new fault.

It also explains a measurement trap: memory appeared to **drop 143 MB** during "the export"
(Graphics 426,224 → 282,628). That was the swapchain being released while the app was
backgrounded by the picker — **not** the export. Anything sampled while a native dialog is up
is measuring a backgrounded app.

---

## §1 Safe-area — one incidental observation

Main menu and dashboard both render correctly at 2560×1600 landscape with no system-bar
collision — consistent with `export_presets.cfg:60` `screen/immersive_mode=true` hiding the
bars. **This is not a §1 tick**: immersive mode hiding the bars is exactly the case where a
missing inset implementation and a correct one look identical. The Phase 1 inset code still
needs a device with a real cutout, or a forced non-immersive run, to be discriminating.

---

## Not captured this session

- **Export-peak memory** — shorter-lived than `dumpsys` polling; needs in-app instrumentation.
- **Frame pacing / draw calls** — needs the remote debugger, not `dumpsys`.
- **Memory across 5 turns** — the campaign is mid-battle at turn 10; playing turns would
  mutate a save that later phases of this sprint still need.

---

## What deploy #28 will carry (desk work completed 2026-09-08)

Gates at hand-off: **3,215 unit cases / 0 errors / 0 failures** (baseline 3,205 + 10 new),
**all 11 lints exit 0**, `git diff -- data/` **empty**, and no line-ending flips across the
28 modified `.gd` files (two pre-existing CRLF files normalised back to LF to keep the diff
readable).

| Phase | Contents |
|---|---|
| 0 | Six stale docs corrected (`MissionSelectionUI` retraction, contrast table, checklist) |
| 1 | Safe-area insets unified into `PortraitChrome.compute_safe_area_insets()`; `MainMenu` brought onto it; 8 tests, detection-proven |
| 2 | **445 → 0** STOP-filtered controls across all 27 screens |
| 3 | `rendering_method` / `.mobile` pinned at the values the device reported |

### \u00a72 in four tiers

| Tier | Fix | Recovered |
|---|---|---|
| Base classes | `BaseCampaignPanel` / `BasePhasePanel` delegated to `TouchScrollOpener`; `CampaignScreenBase` given a sweep it never had | ~60 |
| `extends Control` screens | 12 screens + `CaptainPanel` / `CrewPanel` | ~340 |
| `super._ready()` skippers | 4 screens that hand-invoke the base's `_ready()` parts | ~26 |
| Late / conditional populate | `FinalPanel`, `ShipPanel`, `WorldPhaseComponent`, `UpkeepPhaseComponent` | ~47 |

### The one finding worth walking on device

The **Step 0 travel panel** (`UpkeepPhaseComponent`) swallowed touch drags — `TravelPanel`
plus five Buttons, **including the Red Zone and Black Zone entry buttons**. It is built
CONDITIONALLY (those buttons exist only at 10+ turns with a licence), so a fresh-campaign
desk run reports the screen clean and only an advanced campaign reproduces it.

\u2b50 This also **resolves the deploy #24 row** that recorded two candidates \u2014 *"(a) ORDER
... (b) `_SKIP` ... needs desk introspection to separate"* \u2014 and was never settled. It is
**ORDER**: the sweep ran from the layout paths and never after a step rebuild.

\u26a0 **Desk-green still says nothing about the gesture on hardware.** The sweep measures
mouse filters; `tests/unit/test_touch_pass_is_safe_for_buttons.gd` drives real drags and taps
headless. Neither reaches the physical digitiser, fling momentum, or long-press text
selection. Spot-check those on #28.

### Corrected on the way

An earlier note in this session called the `has_method`-on-Dictionary abort in
`CharacterDetailsScreen` a live player defect on loaded saves. **It is not.** Both production
producers normalise first \u2014 `CrewManagementScreen._on_card_view_details(character: Character)`
is typed, and `_on_dict_card_tapped()` converts via `Character.new()` + `from_dictionary()`
and stores the original under `source_crew_dict`. The Dictionary came from the test fixture
(`tests/tools/screen_populator.gd`), which built a state the app cannot reach. The fixture now
mirrors the real navigator; `CharacterDetailsScreen` went from **85 to 175 nodes**, confirming
it had been aborting half-way through its build. The `_char_has()` guard added to that screen
is hardening, not a bug fix.


---

# Deploy #28 — the sprint on hardware (2026-09-08, versionCode 11)

Built by the owner via editor Remote Deploy. Walked the same day.

⚠ **`versionCode` was NOT bumped — #28 reports 11, exactly as #27 did.** So the version
string cannot tell the two builds apart. The discriminator is
`dumpsys package … lastUpdateTime = 2026-09-08 11:12:43`, plus the bytecode A/B below.
Bump `version/code` in `export_presets.cfg` before the next deploy, or every future walk
inherits this ambiguity.

## Phase 4 gate — PASS, against the bytes on the device

Remote Deploy exports to a temp path, so **there is no artifact in `build/`**. The APK was
pulled back off the tablet instead, which is strictly better — it audits what is installed
rather than what was produced:

```
adb shell pm path com.reptarus.fiveparsecs
adb pull /data/app/~~ZRw8…/base.apk deploy28_from_device.apk    # 61,926,465 bytes
python scripts/verify_apk.py deploy28_from_device.apk --expect …
  leak check ...... PASS (no forbidden paths)
  md check ........ PASS (only the 4 legal docs)
  freshness ....... PASS (all 5 expected scripts present)
  RESULT: PASS          # 2645 entries, 59.1 MB
```

⚠ **`--expect` is a FILENAME check, not a freshness check.** All five of those names existed
in #27 too, so that row cannot distinguish the builds and must not be read as if it does. The
real freshness proof is an **encoding-independent bytecode A/B** of #28 against
`build/deploy27.apk`:

| Measure | Result |
|---|---|
| `.gdc` entries | #28 = 600, #27 = 599 |
| Changed bytecode | **57 files** |
| New in #28 | 1 (`TacticsOperationalRules.gdc`) |
| Sprint files present in the changed set | **27 of 27** |

The remaining ~30 are the Tactics / legacy-rival / colour-token work committed after #27 was
built, which reconciles exactly.

⭐ **A first attempt at this proof was wrong, and its control is what caught it.** Searching
the `.gdc` for the identifier `_open_touch_chain` returned "no" — but so did the control
probes (`_subscribe`, `_check_pending_transfers`), which are pre-existing methods that must be
present. Identifiers are not stored as raw ASCII in GDScript bytecode. **Had the control been
omitted, the natural conclusion would have been "the sprint did not ship".** Byte-diffing whole
entries needs no knowledge of the format at all.

## Renderer — measured, because the config pin cannot survive

⚠ **The Phase 3 baseline pin is GONE, and it cannot be kept this way.**
`git diff -- project.godot` is empty and `grep -c rendering_method project.godot` returns
**0**: the editor rewrote the file on save and dropped both lines, because `ProjectSettings`
only persists values that differ from the engine default — and `forward_plus` / `mobile` *are*
the defaults. Re-adding them will be undone by the next editor save.

**Read the renderer off the device instead.** `user://logs/godot.log`, first lines:

```
Godot Engine v4.6.stable.official.89cea1439
Vulkan 1.3.219 - Forward Mobile - Using Device #0: ARM - Mali-G57 MC2
```

That is arm A, stated by the running app rather than inferred from a config file, and it is
renderer-agnostic. **Arm B is unaffected by the stripping problem**: `gl_compatibility` is a
non-default value, so it will persist normally.

Also confirmed live on #28: `[T11-07] win=2560x1600 dpi=1.000 -> content_scale=0.7830` — the
density double-count fix is in and correct.

## Arm A on #28 — cold-launched, main menu, landscape

| Metric | #27 | #28 | Δ |
|---|---|---|---|
| Cold start (`am start -W`, `LaunchState: COLD`) | 979 ms | **796 ms** | −18.7 % |
| Native Heap | 142,920 | 144,680 | +1.2 % |
| Graphics (EGL+GL) | 432,624 | **446,996** | +3.3 % |
| TOTAL PSS | 688,989 | 716,126 | +3.9 % |

⚠ **A first reading said +11.9 % and was an artifact.** Sampled on the warm session Remote
Deploy left running, Graphics read **483,952**. That session had six minutes of uptime, a
`VK_ERROR_SURFACE_LOST_KHR` resume in its rotated log, and an expansion pane open. A
force-stop and cold launch took it to 446,996. **Cold-launch before comparing memory, or the
previous session's state is folded into the number.**

Sampling noise is itself non-trivial: Graphics read 449,044 / 455,200 / 446,996 at t+8/15/25 s,
a spread of 8,204 KB (**1.8 %**). A +3.3 % delta against 1.8 % scatter, with legitimately added
code in between, is **not a finding** — it is the arm-A figure.

### Thermal — Status 0, and the absolutes are not comparable

CPU 43.7 · GPU 43.7 · NPU 43.7 · SKIN 34.8 · Battery 29.1 · **`Thermal Status: 0`** (no
throttling at any point).

⚠ **Do not read CPU 43.7 against #27's 37.2 as a regression.** Battery temperature — the best
available proxy for the device's own baseline heat — was **23.9 °C** when #27 was measured and
**29.1 °C** here. The whole tablet is ~5 °C warmer today. Only the throttling state is
comparable across days without an ambient control.

## §2 touch — PASS on hardware, both halves

| Surface | Drag scrolls | Tap still works | Notes |
|---|---|---|---|
| Dashboard `CURRENT WORLD` | ✅ | ✅ | `CampaignScreenBase` had **no sweep at all** before this sprint |
| `CompendiumCategoryView` (65 items) | ✅ | ✅ | opened *Area* → "Core Rules p.51" |
| `PreBattleUI` Mission Info | ✅ | ✅ | deploy #27 fix, no regression |

**The safety half is the one that mattered, and it holds.** On PreBattleUI the drag passed
directly over both radio groups and changed neither — Combat Mode stayed "Play on my table",
Tracking stayed "Log Only", and the summary line still read `Mode: Play on table · Tracking:
Log Only`. On the Compendium the drag crossed ~10 list rows and opened none. That is precisely
the property the Godot 4.6 class reference could **not** confirm (it documents
`NOTIFICATION_SCROLL_BEGIN` but says nothing about `BaseButton` acting on it), which is why
`tests/unit/test_touch_pass_is_safe_for_buttons.gd` exists — now corroborated on the real
digitiser.

**Positive proof, not inference:** the live log carries
`[TouchChainProbe:PreBattle] scroll_started on ContentScroll — THE GESTURE ARRIVED`. That
signal fires only for a touch drag on the scrollable area.

**Fling momentum PASS**, observed accidentally and therefore convincingly: a tap aimed at
"Heavy Cover" landed on "Area", because the list was still travelling when the frame was
captured. Headless cannot reach this.

⚠ **One false alarm, settled by reading code.** Tapping a dashboard crew card produced a
byte-identical frame. `CampaignDashboard._build_crew_card()` connects **no input at all** — no
`gui_input`, no `pressed`, no `TapGesture` — so the manifest is display-only and "nothing
happened" is correct. Crew are opened via *Manage Crew*. One grep, no defect.

**Zero errors in `godot.log` for the whole session** — no `SCRIPT ERROR`, no `Parse Error`, no
"Nonexistent function" — across 28 modified scripts including three base classes.

## §1 safe area — STRUCTURALLY UNVERIFIABLE ON THIS TABLET

`dumpsys window displays` reports `cur=2560x1600 app=2560x1600`: the app rect **equals** the
full display, no insets are carved out, and the TB361FU has no display cutout. Under
`screen/immersive_mode=true` the safe area is therefore the whole screen.

The §1 build work stands and its no-op case is unit-covered, but **this hardware cannot tell a
correct implementation from a broken one** — a naive version looks identical. This is the
sprint plan's own Risk 1, now confirmed by measurement rather than predicted. Verifying §1
needs a device with a cutout, or a forced non-immersive run.

## Rules check — the Red Zone gate is CORRECT (no defect)

The dashboard reads "Turn 10" while `progress.turns_played` is **9**, and the zone gate is
`if turns_played < 10: return` (`UpkeepPhaseComponent.gd:2611`). That looked like an
off-by-one. It is not. **Core Rules p.148, verbatim:**

> - Have played 10 campaign turns or more.
> - Pay a 15 credit licensing fee. (A Broker in the crew can reduce the cost by 2 credits)
> - You must have at least 7 crew members at the time of application.

`turns_played` *is* the completed count, so `>= 10` is the book's reading, and the dashboard's
"+1" is the documented in-progress convention. All three requirements are enforced in
`RedZoneSystem.can_obtain_license()` (`src/core/mission/RedZoneSystem.gd:42-104`) — including
the 7-crew minimum and the Broker discount — and `purchase_license()` re-checks eligibility
before charging, so the "check the price you charge against the price you check" trap is
avoided. **Verified, and clean.**

## NOT verified, and why

- **The Step 0 travel panel** — the one genuinely new defect this sprint found. It needs
  `turns_played >= 10`; the QA campaign sits at 9. Bumping it via the in-app Campaign Editor
  worked (`turns_played = 10` on disk, verified), but turn 11 has a **Rival attack armed**, so
  `Begin Turn 11` goes straight to PreBattleUI and never reaches the world phase. Reaching it
  needs a turn with no forced battle. **Still desk-verified only** (instrumented: "opened 0"
  before the fix, 13 and 6 after).
- Pressing **Back** from PreBattleUI landed on a stalled *"Battle Phase — Waiting for mission
  data…"* screen. **Not filed as a defect**: it was reached from a state built by editing
  `turns_played` mid-battle, and deep-linked states the real flow never produces generate false
  findings.
- §3 legibility, §5 haptics / review / bug-reporter, §6 storage round-trip, T9-42.

## The campaign was left exactly as found

`tablet_qa_run_1786210201.save` was backed up before the edit, restored after, and verified
**byte-identical** (`md5 39a09fc4913d`, `turns_played 9.0`).


---

# T11-49 — a standalone Battle Simulator battle DESTROYS the campaign's in-progress battle

**Found on deploy #28, 2026-09-08, during the Pass A / A1 touch walk.** Not on any checklist
and not in any finding family — it was hit while choosing a *safe* route for a touch test.
Severity **HIGH**: silent, irreversible loss of an in-progress campaign battle, caused by an
action the UI advertises as *"Run a standalone battle - no campaign required."*

## What was measured

`progress.active_battle` in `tablet_qa_run_1786210201.save`, before and after launching one
Battle Simulator battle and reaching Round 1:

| `active_battle` | BEFORE | AFTER |
|---|---|---|
| `mission_data.title` | `Rival Attack: Unwanted attention` | `Ambush in Sector 79` |
| crew keys | `char_498964_9495` ... (6 real `character_id`s) | `Mars Vega`, `Ash Zhang`, ... (6 simulator names) |
| `enemies` | 7 | 6 |
| `tier` | 0 (LOG_ONLY) | 2 (FULL_ORACLE) |
| file | 81,221 B, md5 `86c4b77c` | 67,487 B, md5 `3ebea16c` |

The campaign's real p.85 Rival Attack - the one the dashboard offers as **"Resume Battle -
Turn 10"** - was overwritten by the simulator's fight. Resuming would restore the wrong battle.

⚠ **This paragraph originally said the write reached disk only because backgrounding the
app triggered `GameState._notification`'s autosave. A second reproduction DISPROVED that, and
the corrected reading is worse.** Run 2 was exited with `am force-stop`, which SIGKILLs the
process so no lifecycle handler runs, and the campaign save on disk had still been rewritten.
The checkpoint write persists on its own; no Home press, no explicit save, and no clean exit
is required. Backgrounding was never the mechanism - it was a coincidence of run 1.

### Reproduction 2 - independent, and a different route

| | Run 1 | Run 2 |
|---|---|---|
| Entry | Campaign Dashboard -> Battle Simulator | **Main menu -> Battle Simulator** (Continue never pressed) |
| Battle | Ambush in Sector 79, 6 crew, 6 enemies | **The Sector 52 Incident**, 4 crew, 8 enemies |
| Exit | `KEYCODE_HOME` (autosave) | **`am force-stop`** (no handler runs) |
| `active_battle.mission_data.title` after | `Ambush in Sector 79` | `The Sector 52 Incident` |
| `active_battle.crew` keys after | `Mars Vega`, `Ash Zhang`, ... | `Xen Ortiz`, `Kai Zhang`, `Indigo Vega`, ... |
| `active_battle.tier` after | 0 -> 2 | 0 -> 2 |
| campaign save md5 | `86c4b77c` -> `3ebea16c` | `86c4b77c` -> `9248e76b` |

Both runs left `active_battlefield.seed` at `1773741958` with 16 sectors, i.e. the terrain
survived both times for the same reason (same-seed re-persist), while `active_battle` was
destroyed both times.

## Root cause - one false negative, three consumers

`TacticalBattleUI._is_standalone_battle()` (`:987-1002`) has exactly two signals, either
sufficient:

```gdscript
if not _battle_mode_id.is_empty():   # bug_hunt / planetfall / tactics
    return true
var gs = get_node_or_null("/root/GameState")
if gs == null:
    return true
return gs.get("current_campaign") == null
```

Its docblock claims the second signal covers *"Battle Simulator, MCP/demo, tier-select mode"*.
**It does not.** Battle Simulator is 5PFH-flavoured, so it sets no `_battle_mode_id`; and
`current_campaign` is non-null because `GameState._ready()` calls
`_try_auto_load_last_campaign()` (`:112`), which gates ONLY on `last_campaign` being non-empty
and the file existing (`:150-156`). So once the player has any save at all, a campaign is
loaded into `current_campaign` at **every** boot and that second signal can never fire.

⭐ **The entry point is NOT the variable, and the control arm is what proved it.** The first
run reached Battle Simulator from the Campaign Dashboard, which made "launched from a loaded
campaign" the obvious suspect. A second run launched the app fresh, went
**main menu -> Battle Simulator without pressing Continue**, and the log still read
`standalone=false` and still recovered `seed=1773741958` - the campaign's own. Had that arm
been skipped, the finding would have been filed with the wrong cause and a fix scoped to the
dashboard route would have changed nothing.

⚠ Incidental: `game_settings["auto_load_last_campaign"]` (`GameState.gd:79`, default **false**)
has **zero readers** repo-wide. The auto-load it names runs unconditionally.

Three consumers read that false negative:

| Site | Guard | Consequence |
|---|---|---|
| `_queue_checkpoint_save()` `:5522` | `if _is_standalone_battle(): return` | **MEASURED** - the simulator's fight is checkpointed into `campaign.progress_data["active_battle"]`, destroying the real one |
| `_persist_battlefield_contract()` `:7915` | same | **MEASURED (consume half)** - the standalone battle rendered the CAMPAIGN's table |
| `_maybe_show_battle_tour()` `:2990` | `if _is_standalone_battle() and not force:` | cosmetic, opposite direction (tour shows where it should not) |

## The battlefield half - consumed, and one press from being overwritten

The Battle Card of a *standalone* battle was drawn from the campaign's saved contract. Every
line matches the save:

| Battle Card | `active_battlefield` in the save |
|---|---|
| consumed `seed=1773741958`, 16 sectors | `seed = 1773741958.0`, `sectors: 16` |
| "Enemy: 7 x opponents" | `enemy_count = 7.0` |
| "Condition: Caught Off Guard" | `deployment_condition.condition_id = 'CAUGHT_OFF_GUARD'` |
| "Battlefield: Your Table - 3x3 ft" | `theme_name = 'Your Table'`, `table_size_ft = 3.0` |
| "Tactical - advance to cover" | `enemy_ai = 'T'` |

Log, verbatim:

```
[T11-17] cache MISS, recovered from campaign owner: seed=1773741958.0 sectors=16
[T11-17] setup branch=CONSUME stored_sectors=16 owner_sectors=16 standalone=false bf_seed=1773741958.0
```

`active_battlefield` itself SURVIVED, and only by luck: because the battle consumed the
campaign's map, the re-persist carried the same seed, and T11-17's seed guard (`:7952`) only
refuses a **differently**-seeded write.

⚠ **INFERRED, NOT MEASURED** (deliberately not run, because it destroys the player's physical
table layout): pressing **Regenerate** sets `_regenerate_requested = true` (`:7727`), which
makes `player_asked` true at `:7947` and bypasses that seed guard - so the campaign's terrain
would be overwritten too. That is the T11-17 defect resurrected through this hole. The source
chain is complete; the device confirmation is owed.

## Why the existing guards did not catch it

Both `:5522` and `:7915` are *correct* guards protecting the *right* thing. Neither is
mis-written. They both delegate the ownership question to one predicate, and that predicate
answers it by **absence** - "no mode id, and no campaign" - rather than by a positive
statement of ownership. An absence-based test is only as good as the assumption that nothing
else can produce the absence, and boot-time auto-load quietly falsified it.

Same family as [[reference_empty_container_is_not_absence]]: guard on the OWNER, not on the
emptiness of a container. A battle should be asked *"who owns your persistence?"* and answer
from something its launcher set, not from what happens to be null.

## Campaign safety

Backed up (`md5 86c4b77c`, 81,221 B) and verified byte-identical BEFORE the test; restored to
`.save` and `.save.bak` after, both re-verified `86c4b77c`. The second (control-arm) battle was
exited with `am force-stop`, which kills the process so the autosave handler never runs - the
save was `86c4b77c` immediately before and after. **Net change to the QA campaign: none.**


---

# Pass A / A1 - §2 touch physics on deploy #28 (2026-09-08)

Cold start this session: **899 ms**, `LaunchState: COLD` (vs 796/817 earlier today, 979 on #27).

| Box | Prediction | Result | Evidence |
|---|---|---|---|
| Drawer touch-scroll | PASS | **PASS** | Crew drawer, frame `7d06483a` -> `9227251d`; list moved Bryn Ito/Dex Kovac -> Yuri Drake..Nyx Ward |
| Drag over Button children must not fire them | PASS | **PASS** | drag STARTED on Mars Stark's `Aim` and crossed 3 more button rows: no stun markers, nobody marked down, battle log unchanged |
| Tap still works (control arm) | - | **PASS** | tap on the same button class opened Keyword Info "Damage", cite *Rules p.54* |
| Fling momentum | PASS | **PASS** (harness caveat) | see below |
| Long-press text selection vs scroll | **FAIL expected** | **FAIL CONFIRMED** | slow drag over `DebugScreen._log_display` produced a visible blue selection, not a scroll |
| Multi-touch double-fire (`UnitActivationCard`) | FAIL expected | **NOT ANSWERED** | could not surface the Tracking drawer on device this session |

## Fling momentum - the A/B that worked after direct sampling failed

Sampling the frame at +0.08 / 0.25 / 0.5 / 1.0 / 2.0 s after a fling showed **one jump then
nothing**, on two different surfaces. That reads as "no inertia" and it is wrong: an
`adb exec-out screencap` takes ~100-200 ms, so the entire inertia tail is over before the first
sample lands. **A measurement whose resolution is coarser than the effect cannot see the effect,
and it returns a confident negative rather than an error.**

Measuring the CONSEQUENCE instead settles it. Same list, same start position, same 800 px drag
distance, only swipe DURATION varied:

| duration | landed at (65-item alphabetical Keywords list) |
|---|---|
| 600 ms | Damage / Line of Sight |
| 250 ms | **Luck** (deepest) |
| 60 ms | Auto / Bulky (shallowest) |

Three different depths from an identical drag distance means velocity IS conveyed and inertia IS
applied - a 1:1 drag would land all three at the same offset.

⚠ **The relation is NON-MONOTONIC, and that is the harness, not the app.** The fastest swipe
travelled least, because `adb shell input swipe` synthesises very few intermediate MOVE events at
60 ms, so the drag itself under-delivers. `input motionevent` does not exist on this device
(`input` offers only text / keyevent / tap / swipe / draganddrop / press / roll), so a true
velocity ramp cannot be sent over adb at all. Do not read the ordering as an app property.

## The dual-family inventory is exactly TWO controls

Repo-wide, only two live `.gd` files handle `InputEventScreenTouch` **and**
`InputEventMouseButton` in one handler - the T11-36 double-fire shape:

| Site | Reachability |
|---|---|
| `UnitActivationCard.gd:282-292` | LIVE. `gui_input` connected at `:60`; `_handle_tap()` TOGGLES `is_activated`, so a double-fire shows up as "the card does nothing" |
| `CharacterCard.gd:88-98` | **LATENT.** `CrewManagementScreen._create_character_card_entry()` builds it only when `character is Character`; a LOADED save yields Dictionaries, which take the fixed `TapGestureRef.connect_tap` path at `:174-177`. The one instance reachable from a loaded save is the embedded card in `CharacterDetailsScreen.tscn`, whose `card_tapped` is connected NOWHERE |

`TapGesture.gd` is the correct implementation and its docblock records why it ignores the touch
family deliberately.

⭐ **Incidental control arm, free:** two taps on the Battle Simulator crew stepper moved 4 -> 6
exactly. `StepperControl` uses `Button.pressed`, which is structurally immune to this shape.

## Keyboard avoidance - a correct no-op, confirmed by its own instrument

Focusing the crew-size SpinBox opened the IME. The app logged:

```
[KeyboardAvoidance] raw=760 window_h=1600 logical_vp_h=1379.3 -> kb_logical=655.2 | field_bottom=229.0 shift=0.0
```

`shift=0.0` is CORRECT - the field bottom (229.0) sits far above the keyboard line (655.2), so
no avoidance was owed. `raw=760` matches the ~762 px measured on this device in August, and the
window did not resize, consistent with the recorded overlay-only behaviour.

## Not answered this session, and why

- **`UnitActivationCard` double-fire.** The Tracking drawer sits behind the modal Pre-Battle
  Setup Checklist until Begin Battle, and pressing Begin Battle in a standalone battle triggers
  T11-49. In the campaign's own LOG_ONLY battle the Tracking button is not present at all.
  It is also surfaced by the Quick / Slow Actions phases (`:4117`, `:4190`); Quick Actions was
  entered and did not produce a visible tracker. Needs one more targeted attempt.
- **HelpScreen `_content_label` drag.** Source-verified, NOT device-tested: it sets
  `scroll_active = false` ("outer ScrollContainer handles scrolling") and never sets
  `mouse_filter` (RichTextLabel defaults STOP) nor `selection_enabled` (defaults false), while
  `TouchScrollOpener._SKIP` contains `"RichTextLabel"`, so the sweep leaves it STOP. Predicted:
  the drag is SWALLOWED - it neither scrolls nor selects. Control arm is EULA, which sets
  `_eula_text.mouse_filter = MOUSE_FILTER_IGNORE` explicitly (`EULAScreen.gd:181`).
  ⚠ Reaching it is awkward: `navigate_to("help")` has exactly ONE call site repo-wide,
  `StoreScreen.gd:310`, a footer link on the Expansions page.
- **PreBattle crew-selection drag** - no PreBattleUI was reachable while the campaign already
  had a battle in progress.

---

# T11-50 - the Debug & Support log pane is permanently empty

The screen states *"This page helps debug issues. Copy the log below and include it when
reporting bugs."* The pane below reads **"No log entries captured yet."** in a session that had
already written a real `godot.log` to disk.

`DebugScreen._refresh_log()` (`:169`) reads `_log_buffer`, and `_log_buffer` is written in
exactly one place - `DebugScreen.log_message()` (`:237-246`), a static API with **zero callers
anywhere in `src/`**. (The `_log_message(` hits in `TacticalBattleUI` are a different, private
battle-log method - the underscore matters.) `_get_log_text()` (`:214`) reads the same dead
buffer, so **COPY TO CLIPBOARD and EMAIL SUPPORT ship only the 4-line System Info header**,
never a log.

⭐ **Half of this was already known, and written down at the wrong site.**
`BugReportContext.read_log_tail()` carries the note: *"DebugScreen._log_buffer looks like the
right source but is never written to from anywhere in src/, so it is always empty. This reads
the real engine log instead."* The BUG REPORTER was therefore fixed by reading
`user://logs/godot.log` directly - and the Debug screen, the surface that actually tells the
user to copy a log, never got the same treatment. **A note recording a defect beside the code
that WORKS AROUND it does not fix the code that still has it.** Same family as
[[reference_implemented_but_never_called]], one step removed: the knowledge existed, the fix
existed, and neither reached the second consumer.

Severity low - the bug reporter, the path that matters for support, is unaffected. Fix is small:
point `_refresh_log()` / `_get_log_text()` at `BugReportContext.read_log_tail()`.

⚠ Consequence for the A4 box: "Attach app log (N lines)" should still be non-zero, because the
reporter does not use this buffer. Verify that box against the REPORTER, not against this screen.

---

## Campaign safety for this section

`tablet_qa_run_1786210201.save` verified `86c4b77c` / 81,221 B before the walk. It was written
three times during it - once legitimately (the campaign's own battle checkpointing a phase
advance, i.e. the feature working) and twice by T11-49. Restored from the verified backup after
each, and confirmed `86c4b77c` on both `.save` and `.save.bak` at the end.

⭐ The legitimate write is the CONTROL ARM for T11-49's first consequence: same code path, same
function, faithful when the battle really is the campaign's - `turn 9`, `tier 0`, identical crew
keys, mission still `Rival Attack: Unwanted attention`, 7 enemies, and
`react_slots [2,1,2,2,1,2]` matching the logged "2 Quick · 4 Slow" exactly. Only `phase`
0 -> 1 moved. **The checkpoint is not broken; the ownership predicate in front of it is.**


---

# T11-49, continued — the ADJACENT sweep found the worst consequence

The owner asked for adjacent issues to be confirmed BEFORE patching, so one build could
carry the whole family. That sweep changed the finding's severity: the two consequences
measured first (overwrite) are not the dangerous ones.

## ⭐ Consequence 2: pressing **Return** ERASES the campaign's battle

`_clear_battle_checkpoint()` (`TacticalBattleUI.gd:5664`) calls
`GameState.clear_active_battle()` — which does `progress_data.erase("active_battle")` —
and then `save_campaign()` to flush the erase. **It had no ownership test of any kind**,
while both of its siblings had one.

Its two callers are `_on_record_result()` (`:3318`) and `_on_return_to_battle_resolution()`
(`:6821`) — the **Record Result** button and the **Return** button. Return is the ordinary
way to leave the Battle Simulator.

Measured on deploy #28:

```
active_battle present   BEFORE: True   AFTER: False
save file               81,221 B  ->   63,641 B
```

The campaign's in-progress p.85 Rival Attack was **deleted**, not overwritten. The
dashboard stops offering "Resume Battle — Turn 10", and re-entering MISSION re-rolls
enemies, objective and battlefield under a table the player has already physically built
— which is, verbatim, the failure `BattleCheckpoint`'s own docblock says it exists to
prevent.

⚠ **My first two runs missed this only by luck**: both were exited with `am force-stop`
or Home, never with Return or Record Result.

## Consequence 4: a standalone battle can spend a once-per-campaign Star

The in-battle Stars of the Story popup (`:8879`) gated on
`_is_bug_hunt_mode or _is_planetfall_mode` — a THIRD, different notion of ownership — so a
standalone battle read the loaded campaign's stars and would write them back on use
(`campaign.stars_of_the_story = stars.serialize()`), spending an ability the book allows
once per campaign (Core Rules p.67) and logging it to the campaign journal.
Source-verified; not device-measured (confirming it would burn a real Star).

## The structural core: three different ownership tests in one file

| Site | Ownership test | State |
|---|---|---|
| `_queue_checkpoint_save` `:5522` | `_is_standalone_battle()` | predicate returned false |
| `_persist_battlefield_contract` `:7915` | `_is_standalone_battle()` | predicate returned false |
| `_clear_battle_checkpoint` `:5664` | **none** | erased unconditionally |
| Stars popup `:8879` | `_is_bug_hunt_mode or _is_planetfall_mode` | different test again |
| `_maybe_show_battle_tour` `:2990` | `_is_standalone_battle()` | cosmetic, opposite direction |

⭐ **The blast radius is exactly one file, and that is a finding in itself.** A repo-wide
sweep for the same absence-based shape returned 18 other `current_campaign == null` sites,
and every one is a plain null-guard inside a screen that is only reachable WITH a campaign
(World Phase, Ship Manager, PostBattle, CrewTask). `TacticalBattleUI` is the only screen
shared between the campaign and a standalone mode, so it is the only place where "is there
a campaign?" and "is this campaign MINE?" can diverge.

---

# Build #29 — the fix set (versionCode 12)

## The fix is a POSITIVE ownership signal

`mission_data["standalone"] = true`, stamped by `BattleSimulatorSetup
.generate_battle_context()`, read once into `TacticalBattleUI._standalone_declared` at the
top of `initialize_battle()`, and consulted first by `_is_standalone_battle()`.

⚠ **It deliberately does NOT reuse `battle_mode`, and that is not a style choice.** That
field is passed to `BattleResolverRouter.resolve()` and is read by
`CampaignTurnController._should_present_narrative_wrap()`, which vetoes the narrative wrap
for any non-empty, non-`"standard"` value. Stamping a mode there would have silently
changed auto-resolve routing as a side effect of a data-safety fix. A test pins this
(`test_the_declaration_does_not_ride_on_battle_mode`).

| # | Change | File |
|---|---|---|
| 1 | stamp `standalone` on the simulator's mission | `BattleSimulatorSetup.gd` |
| 2 | `_standalone_declared` + read it in `initialize_battle` | `TacticalBattleUI.gd` |
| 3 | predicate honours the declaration first | `TacticalBattleUI.gd:987` |
| 4 | the MCP/demo tier-select path declares itself too | `TacticalBattleUI.gd` `_check_standalone_mode` |
| 5 | **guard the ERASE** | `TacticalBattleUI.gd:5664` |
| 6 | guard Stars of the Story | `TacticalBattleUI.gd:8879` |
| 7 | standalone takes the FALLBACK terrain branch, not CONSUME | `TacticalBattleUI.gd` |
| 8 | correct the docblock that claimed the two absences covered Battle Simulator | `TacticalBattleUI.gd` |

Also in #29: **T11-36** double-fire fixed on both remaining controls
(`UnitActivationCard`, `CharacterCard` — both migrated to `TapGesture`), **T11-50**
(Debug screen reads the real engine log), and the **§1 safe-area instrument** in
`PortraitChrome.safe_area_insets_design_px()`.

## Verification

- **Detection-proven, four arms, each reverted ALONE and restored:** producer stamp →
  `test_battle_simulator_declares_itself_standalone` FAILED; predicate →
  `test_declared_standalone_wins_even_with_a_campaign_loaded` FAILED;
  `UnitActivationCard` touch branch restored → `..._toggles_exactly_once` FAILED;
  `CharacterCard` touch branch restored → `..._emits_card_tapped_exactly_once` FAILED.
  Green again after every restore.
- New suites: `tests/unit/test_standalone_battle_ownership.gd` (4 cases),
  `tests/unit/test_card_tap_single_fire.gd` (3 cases).
- All 8 lints exit 0; orphan lint `files=561 reachable=561 test_only=0 orphans=0`.

## ⚠ Two test fixtures had to be corrected, and neither was "make the test agree"

1. **`test_character_card.gd::test_card_tapped_signal_emits` was a FALSE GREEN.** Its only
   assertion sat inside `if card_instance.has_method("_gui_input")`. Deleting that override
   made the guard false, so the case passed having checked nothing — it would have reported
   success on a card whose tap handling had been removed entirely. Rewritten to drive the
   live `gui_input` path and assert a COUNT.
2. **`test_battlefield_writeback_guard.gd`'s fixture enumerated the ownership signals.** Its
   own comment says why it clears them ("both would early-return before the guard, making
   this suite vacuously green") — it just listed the TWO that existed when it was written.
   Adding a third broke it. The fix restores the fixture's stated intent AND makes it
   **assert its own premise**: it now fails with a message naming the cause if a fourth
   signal is ever added, instead of reporting a guard regression that is really a fixture
   gap. ⭐ That is the [[reference_instrument_the_probes_own_premise]] lesson applied to a
   fixture rather than a probe: a hand-maintained list of things to neutralise is only
   correct while the list is complete, so make the incompleteness loud.

## Deliberately NOT in #29

**Renderer arm B (`gl_compatibility`).** It is a MEASUREMENT, not a fix, and flipping the
renderer in the same build that must verify a data-loss fix would confound both: a
regression could not be attributed. It stays a separate 15-minute flash whenever the owner
wants the number.

**`auto_load_last_campaign`.** The setting (`GameState.gd:79`, default `false`) has zero
readers, and `_try_auto_load_last_campaign()` runs unconditionally. Wiring it would change
boot behaviour for every user (Continue would stop working as it does today), and deleting
it is an owner call. Recorded, not touched.


---

# Deploy #29 walked — T11-49 FIXED ON HARDWARE (2026-09-08, versionCode 12)

Built CLI (`--export-debug`, 50 s, 61.9 MB), `verify_apk.py` **PASS** (2645 entries, no
leaked paths, only the 4 legal docs), installed with `-r`. **`versionCode=12`** — the first
build since #26 that the version string alone can distinguish, #27 and #28 having both
shipped as 11.

## The decisive test: drive the exact #28 destruction path

| Step | #28 (before the fix) | #29 (after) |
|---|---|---|
| baseline save | `86c4b77c` | `86c4b77c` |
| main menu → Battle Simulator → Full Oracle | — | `86c4b77c` |
| **Begin Battle** | `3ebea16c` / `9248e76b` — **checkpoint OVERWROTE the campaign** | **`86c4b77c` unchanged** |
| Roll Initiative → Continue | — | `86c4b77c` |
| **Return** | `3c785d6c` — **`active_battle` ERASED**, 81,221 → 63,641 B | **`86c4b77c` unchanged** |

`[T11-17] setup branch=... standalone=true` — the predicate now answers correctly.

⚠ **The first verification run was NOT valid and is recorded rather than quietly redone.**
Its BEGIN BATTLE and RETURN frames were byte-identical (`65c6e416`), which the harness
printed but the verdict line ignored — the Seize the Initiative dialog was still up, so
Return was never pressed and the run proved only the Begin Battle half. The rerun captured
a frame after every tap and each one MOVED (`64880bf0` → `6a63c80b` → `eda11ad7`), ending on
the Battle Simulator setup screen, which is what proves Return actually navigated. **A
green verdict from a probe that never delivered its stimulus is the failure mode this
project keeps rediscovering** — see [[reference_instrument_the_probes_own_premise]].

## The other fixes, on device

- **Terrain FALLBACK (fix #7) — VISIBLY CORRECT.** The standalone battle's Tracking drawer
  now shows a freshly generated table (*"Wilderness — Natural terrain with rocks,
  vegetation and uneven ground. Notable features: 1 | Grid: 4x4 sectors"* plus a full
  16-sector layout) instead of the campaign's saved contract, which is what #28 rendered.
- **T11-50 — FIXED.** The Debug & Support pane now prints the real engine log (engine
  banner, `[T11-07]`, `[SAFEAREA]`, `[T11-26] SettingsScreen touch-scroll filters opened:
  52`) where #28 read *"No log entries captured yet."*
- **§1 safe-area instrument — WORKING, and it answers the question #28 could not:**
  ```
  [SAFEAREA] win=(2560, 1600) raw=[P: (0, 0), S: (2560, 1600)] vp=(2206.896, 1379.31)
             -> { "left": 0, "top": 0, "right": 0, "bottom": 0 }
  ```
  The RAW rect **equals the full window**, so the all-zeros result is the DEVICE's honest
  answer under `immersive_mode`, not our math zeroing a real inset. That distinction is
  invisible in a screenshot and is exactly why §1 was unverifiable before. The remaining
  §1 work is the cutout-emulation walk, which now has a readout to check against.

## ⚠ One stale diagnostic found BY the verification, and corrected

The log printed `setup branch=CONSUME` while the code had already taken FALLBACK: the
debug line at `:7202` carried its own copy of the branch condition
(`"CONSUME" if not stored_sectors.is_empty() else "FALLBACK"`) and fix #7 changed only the
real `if` below it. The terrain on screen proved which branch actually ran. Corrected so
the label reproduces the real condition, with a note at the site — **a diagnostic that
disagrees with its own code is worse than none, because it is read as evidence.** Same
family as [[reference_a_diagnostic_that_cannot_disagree]]. The correction is in source; the
#29 log line still carries the stale label.

## Still not answered

**The `UnitActivationCard` double-fire box.** It is FIXED and detection-proven at the desk
(reverting the touch branch turns `test_unit_activation_card_toggles_exactly_once` red),
but the on-device surface was still not located: the bottom-bar **Tracking** drawer turns
out to be the TERRAIN / sector panel, not `ActivationTrackerPanel`. The tracker is surfaced
by `_surface_phase_component()` into `phase_content` during Quick/Slow Actions, and that
region was not identified this session. ⚠ The unit test drives the exact three-event
sequence a device produces (touch, then its synthesised mouse press/release), so the desk
proof is faithful to the hardware path — but it is a desk proof, and this file's own
standing rule is that desk-green says nothing about touch.

## Campaign safety

`tablet_qa_run_1786210201.save` verified `86c4b77c` / 81,221 B before the build, survived
the `-r` install unchanged, and read `86c4b77c` after every step of both verification runs
including the two that destroyed it on #28. **No restore was needed on #29** — the first
session today where a standalone battle left the campaign alone.


---

# ⚠ STILL OPEN after deploy #29 — the ledger (2026-09-08)

Written down because the last 15 deploys were organised by FINDING FAMILY and never went
near a checklist section nobody had filed a finding against. This is that list, so the
next session inherits it instead of re-deriving it.

## Defects fixed at the desk but NOT confirmed on glass

| Item | State | What is missing |
|---|---|---|
| **`UnitActivationCard` double-fire** | FIXED, detection-proven at the desk (reverting the touch branch turns `test_unit_activation_card_toggles_exactly_once` red), shipped in #29 | The on-device surface was never located. The bottom-bar **Tracking** drawer is the TERRAIN/sector panel, not `ActivationTrackerPanel`; the tracker is surfaced by `_surface_phase_component()` into `phase_content` during **Quick / Slow Actions**. Reach that phase and tap a unit card. ⚠ Desk-green says nothing about touch — this file's own standing rule. |
| **`CharacterCard` double-fire** | FIXED and shipped in #29 | Same: the fix is proven by a unit case that emits the real three-event device sequence, not by a finger. |
| **HelpScreen `_content_label` drag** | Source-verified PREDICTION only | `TouchScrollOpener._SKIP` contains `"RichTextLabel"` (`TouchScrollOpener.gd:41-44`) and `HelpScreen.gd:184` never sets `mouse_filter`, so it stays STOP even though the sweep ran. Prediction: the drag is swallowed. Control arm is EULA (`EULAScreen.gd:181` sets `MOUSE_FILTER_IGNORE` explicitly, so it MUST scroll). Reachable only via `StoreScreen.gd:310`. |

## Checklist boxes still unticked — 25 of the original 29

| § | Boxes | Blocker / next action |
|---|---|---|
| **§1 safe area** | 4 | **Unblocked by #29.** The `[SAFEAREA]` instrument now prints the raw rect, so a real inset can be told apart from our math zeroing one. Needs `cmd overlay enable com.android.internal.display.cutout.emulation.tall` (and `waterfall` for the L/R case). |
| **§2 touch physics** | 2 of 5 | Multi-touch double-fire and long-press text selection (`DebugScreen.gd:122`, the only `selection_enabled = true` long scrollable surface). The other 3 were ticked on #28. |
| **§3 legibility** | 4 | **Deferred by owner decision.** Not signable from screenshots — "only a hand says whether it is comfortable". |
| **§4 perf / thermal** | 4 of 5 | Cold start is ticked (796/817 ms vs #27's 979). Remaining: dashboard frame pacing, battlefield pan/zoom (**expected UNTESTABLE — that is the finding**, see below), 15-min thermal, memory across 5 turns. The last two run together. |
| **§5 plugins** | 2 answerable of 4 | Review flow + bug reporter. **Haptics is BLOCKED — no vibrator on this hardware** (`isVibratorControllerRegistered = false`, `capabilities = []`). **Billing is PARKED** pending the LOI. |
| **§6 scoped storage** | 4 + 1 recon finding | Two predicted FAILures: data export writes app-private `user://data_export.json` with no SAF/share hand-off (GDPR-portability gap), and the creation-wizard `PortraitDialog` (`CharacterCreator.tscn:155-162`, `access = 2`, no `use_native_dialog`, **no `file_selected` handler anywhere**). |
| **"Before Sunday"** | 2 | One is now automated (`verify_apk.py` runs on every build); the other is the branch-merge owner decision. |

## Walk items that are implemented and simply un-walked

- **A5 / T9-42** — the p.82 Explore 97-100 leave-time branch. Producer `CrewTaskComponent.gd:3673`,
  consumer `UpkeepPhaseComponent.gd:1358`; both `has_method` guards resolve. Forceable since
  2026-09-04 via `DiceManager.queue_forced_result()`. ⭐ It was parked as a 4% roll "not worth
  grinding" and **that reasoning expired the day the forced-roll seam landed** — nobody went back.
- **A6 / the Step 0 travel panel** — needs `turns_played >= 10` (`UpkeepPhaseComponent.gd:2611`)
  and no armed rival, on the DUPLICATED save (`zone_fixture_1786210201.save`, already on device).
- **A7 / MOBILE breakpoint** — `wm size 1080x2400` + `wm density 420` → 411 dp, the class the
  tablet cannot reach natively and where T11-04 and T11-06 both lived.
- **A8** — the checklist's four un-numbered "worth a deliberate look" items, which carry no
  boxes and is exactly how they were missed for 15 deploys.
- **A9 / Delete All Data** — destructive; pull `files/` first, push back after.

## Recorded, deliberately NOT fixed

- **`auto_load_last_campaign`** — the setting is declared at `GameState.gd:79` and has **zero
  readers repo-wide**, while `_try_auto_load_last_campaign()` (`:150`) loads a campaign at every
  launch regardless. Wiring it would change boot behaviour for every existing user; deleting it
  is equally an owner call. This is the mechanism that made T11-49's absence-test wrong.
- **Renderer arm B (`gl_compatibility`)** — excluded from #29 on purpose. Flipping the renderer
  in the build that must verify a data-loss fix makes any regression unattributable. It is a
  15-minute flash, and its target quantity is GRAPHICS MEMORY (`docs/sop/android-runtime-testing.md:256-267`
  defines only FPS/frame-time/draw-call thresholds, so the SOP gives a procedure for the wrong axis).
- **Battlefield map pan/zoom** — `BattlefieldMapView.gd:1241` arms panning on `MOUSE_BUTTON_MIDDLE`
  only; `emulate_mouse_from_touch` synthesises LEFT, and there is zero `InputEventPanGesture` /
  `InputEventMagnifyGesture` in `src/`. Meanwhile `TacticalBattleUI.gd:847` tells the player
  *"pinch/scroll to zoom, drag to pan."* **A UI string promising an interaction with no
  implementation** — confirm on glass, then file it.

## Cannot be answered on a TB361FU at any effort

Haptics (no vibrator) · low-RAM behaviour (8 GB here; the 2764x1843 sheet export on a 3-4 GB
device is the likeliest OOM) · older Android (minSdk 29, this device is **Android 16 / SDK 36**)
· phone ergonomics · targetSdk 35 running on SDK 36. **One cheap phone closes all five** —
every gap is on the small/old/low-spec axis, so a second tablet buys nothing. The emulator is
not an option (godot#121035 — it cannot render this app, and a black `screencap` from it is
meaningless because capture is blind to SurfaceView).


---

# §1 safe-area insets — ALL FOUR BOXES ANSWERED on deploy #29 (2026-09-08)

The section that had **0 grep hits in the 407 KB sprint ledger**. It was unverifiable on
#28 for a structural reason, not a scheduling one: with no cutout on the panel, a correct
implementation and a broken one produce the **identical frame**. #29's `[SAFEAREA]` line
plus `cmd overlay enable …cutout.emulation.*` is what made it answerable.

## The instrument agrees with Android on every edge

Conversion is physical px x (design / window) = **x0.86207** on this device.

| Arm | Android's own `mDisplayCutout` | `[SAFEAREA]` raw | computed insets | check |
|---|---|---|---|---|
| landscape, none | `Rect(0,0-0,0)` | `P:(0,0) S:(2560,1600)` | all 0 | ✅ honest zero |
| landscape, `tall` | `Rect(96,0-0,0)` | `P:(96,0) S:(2464,1600)` | `left 82` | ✅ 96x0.86207 = 82.8 |
| landscape, `waterfall` | `Rect(0,40-0,40)` | `P:(0,40) S:(2560,1520)` | `top 34, bottom 34` | ✅ both edges, 40x0.86207 = 34.5 |
| **portrait, `tall`** | `Rect(40,96-40,0)` | `P:(40,96) S:(1520,2464)` | `left 34, top 82, right 34` | ✅ **all four edges** |

⭐ The far edges (`right`, `bottom`) are derived as `win - pos - size`, not read directly, and
they come out right — which is the half a single-edge test would never exercise.

## Box 3 — insets swap sides on rotation: **PASS**

The `tall` cutout is `left: 82` in landscape and `top: 82` in portrait, from the same overlay.
⚠ My first rotation harness reported *"ROTATION DID NOT TAKE"* on two perfectly good landscape
arms — it asserted `mCurrentRotation.endswith(str(user_rotation))`, but `user_rotation=N` maps
to `ROTATION_(N*90)`, so `1` -> `ROTATION_90`. **The harness was wrong, not the device.**
Recorded because a false negative here reads exactly like a device limitation.

## Box 1 — the notch does not overlap the title: **PASS, by a one-variable A/B**

| orientation | no cutout | `tall` cutout | verdict |
|---|---|---|---|
| **PORTRAIT** | `70baf888` | `e9dbfb2e` | **MOVED** — predicted to move |
| **LANDSCAPE** | `6a73d2bd` | `6a73d2bd` | identical — predicted identical |

**Both predictions held, and the pair is what makes this evidence.** Landscape is identical
because every inset is smaller than the clamp already in force (`title.offset_top = maxf(50, 82)`
is not reached; the centred title box is `minf(400, half_w - 82)` = 400 either way, and its left
edge sits at design x=703 against an 82 px inset). **An identical frame there is a legitimate
PASS, not a missing feature** — and only the log line can say so.

Portrait is where it binds. Measured title top: **82 -> 107 physical px = 21.6 design px**.
Predicted: `is_narrow` is true in portrait (`MainMenu.gd:1502`, `should_collapse_to_single_column()`),
so the rule is `maxf(margin_t, _top_right_overlay_bottom() + margin)` =
`maxf(0, 48+12) = 60` -> `maxf(82, 60) = 82`, i.e. **22 design px**. Measured 21.6. The whole
column moves down with it and nothing clips.

⚠ First measurement said 26 px because the row-detector scanned the full width and caught the
top-right gear/bug band. Re-measured over centre columns only. **A crude detector that finds
*something* bright will happily answer the wrong question.**

## Boxes 2 and 4 — the nav bar: **PASS in BOTH nav modes**

The device ships in **3-button** nav (`navigation_mode=0`), so gesture nav had to be switched on
deliberately — `settings put secure navigation_mode 2`, verified by read-back.

⭐ **The dashboard's bottom button row is at y 1526-1578 and the `navigationBars` inset source is
`frame=[0,1480][2560,1600]` — the entire row lives inside the nav bar's region.** That is exactly
the condition box 4 asks about, and it is invisible without pulling the inset sources.

Under `screen/immersive_mode=true` the source reports `visible=false` in both modes, and
**Manage Crew at (1070, 1552) opened the crew screen in both** — so nothing sits on top of the row
and it is reachable. Non-mutating buttons only; Save/Load/QA/Edit/Export/Quit/Resume were avoided
by design and the campaign md5 was `0bdbbc31` before and after every arm.

## §2 — the crew-card tap path: **PASS ON GLASS**

⚠ **CORRECTION, made before this claim could set.** I first wrote this up as "the #29
CharacterCard fix, confirmed on glass". **It is not.** The cards on this screen carry the title
*"[Captain] Bryn Ito"*, and that `"[Captain] "` prefix is built only at
`CrewManagementScreen.gd:164-168` — the **Dictionary** path, which hands a plain
`PanelContainer` from `BaseCampaignPanel:1021` to `TapGesture` at `:176`. That wiring is
**T11-28's** fix (Sep 5), not #29's.

`CharacterCard` is instantiated only on the `Character`-Resource path (`:106-114`), and a
**loaded save yields Dictionaries**, so that path is unreachable in this flow — exactly as
`TABLET_CHECKLIST_2026-08-02.md` already recorded it ("LATENT"). Reaching it needs a **freshly
created** campaign, whose `crew_data["members"]` still holds Character Resources (see the
`resource_vs_dict_2arg_get_abort` gotcha). **So the #29 CharacterCard fix remains
device-unconfirmed**, and the checklist box stays open.

What IS now proven on glass is the tap path a real player uses on a loaded campaign:

- **T11-28 control arm first**: a 600 ms drag across the crew grid left the frame on the crew
  screen — **a drag scrolls and does not navigate**.
- **One tap** on a crew card opened the Dex Kovac detail screen; **one Back returned to
  `038084c1`, the exact crew-list frame we came from**. One tap = one navigation.

⭐ **A new defect fell out of reading that prefix.** `BaseCampaignPanel.gd:1075` derives the
avatar initial as `char_name.substr(0, 1).to_upper()`, and `CrewManagementScreen.gd:165` passes
it the ALREADY-PREFIXED `"[Captain] Bryn Ito"` — so **the captain's avatar renders a literal
`[`** instead of `B`, visible in `b4_gesture_managecrew.png`. Filed as **T11-51**.

⚠ **CORRECTION — the second half of this row was WRONG and is fixed here rather than deleted.**
It originally also claimed the captain's avatar COLOUR was wrong, because the same decorated
string feeds `char_name.hash() % avatar_colors.size()` (`:1054`). **That claim is false, and it
is false by arithmetic, not by luck.** Godot's `String.hash()` is djb2 — `h = 5381; h = h*33 + c`
— and **33 ≡ 1 (mod 8)**, so every power of 33 is 1 (mod 8) and for an 8-entry palette
`hash(s) % 8 == (5381 + Σ chars) % 8`. Prefixing a constant P shifts the index by exactly
`Σ(P) % 8`, and **Σ("[Captain] ") = 920 ≡ 0 (mod 8)**. That prefix therefore **cannot** move the
colour index, for any name.

Measured with the defect fully reproduced: `Bryn Ito 4/4`, `Dex Kovac 2/2`, `Yuri Drake 5/5`.

⭐ **This nearly shipped as a false green in the TEST, which is the more expensive half.** My
first colour case looped six real crew names against `"[Captain] "` and **passed with the defect
live** — I first assumed a 1-in-8 hash collision and "strengthened" it by adding more names,
which cannot help against a property that holds for every input. The case now uses `"[MIA] "`
(Σ = 431 ≡ 7 mod 8), which genuinely shifts the index, and it is detection-proven: reverting
`identity.hash()` -> `char_name.hash()` fails it on three names. **A fixture that cannot vary the
quantity under test is not a weak test, it is a permanent false green** — same family as
[[reference_a_detection_proof_needs_a_discriminating_fixture]].

The colour derivation is still fixed and still worth pinning, because it is **latent**: the day a
card is decorated with `"★ "` (≡ 2) or `"(KIA) "` (≡ 6), the identity has to already be plumbed
through. The fix separates the DISPLAY string from the IDENTITY string
(`_create_character_card(..., identity_name)`), leaving the three undecorated callers untouched.
Pinned by `tests/unit/test_character_card_identity.gd` (6 cases).

⚠ The first Back tap at (120, 60) left the frame unchanged and the harness correctly refused to
call that a double-fire — the real `< Back` is at (92, 107). **A missed tap and a stacked screen
are indistinguishable from one frame**, which is why the harness prints both candidate hashes and
demands a match rather than reporting "no response" as a verdict.

## Structural note found while reading, NOT a defect

`CrewManagementScreen` has two card paths and they are disjoint: the `Character`-Resource path
(`:106-114`) instantiates the real `CharacterCard`, which self-connects one `TapGesture` in
`_ready()` and re-emits `card_tapped`; the Dictionary path (`:169-177`) gets a plain
`PanelContainer` from `BaseCampaignPanel:1021` and has the screen attach the only gesture. So the
#29 fix did **not** create a second connection here.

⚠ **CORRECTION — my note here was wrong, and wrong in the direction that matters.** It read:
*"`TapGesture.connect_tap()` has no guard against being called twice on the same control — a
second call would silently double every tap."* **It does not double-fire. The second callback is
INERT.**

Measured rather than reasoned (`tests/unit/test_card_tap_single_fire.gd`): connect two lambdas to
one Control, deliver one tap → **first fires 1, second fires 0**. The gesture's arm state lives on
the CONTROL (`_META_ARMED` / `_META_POS`, chosen so freeing the row frees the state) and the
release path **disarms before it fires**, so the first lambda consumes the arm and the second
reads `armed == false` and returns.

⭐ So keying the state on the control makes double-connection **fail SAFE** for exactly the defect
the T11-36 family is about. It is still a trap, just the opposite one: a second tap action wired
to an already-tapped control **never runs and nothing errors**. The remedy is one callback doing
both things, never two `connect_tap()` calls — now stated in the helper's own docblock and pinned
by a case, instead of the guard my wrong diagnosis would have added.

⚠ The practical rule for `CharacterCard` specifically: it self-connects in `_ready()`, so a screen
must bind to its `card_tapped` **signal**, not attach a second gesture.


---

# §6 scoped storage — 3 of 4 boxes answered, one is a CONFIRMED FAIL (2026-09-08, #29)

## Box 1 — save/load round-trip on real Android storage: **PASS**, three arms

| Arm | Result |
|---|---|
| **cold load** | `Continue Campaign` loads `tablet_qa_run_1786210201.save`, md5 stable across ~20 launches |
| **lifecycle flush** | `KEYCODE_HOME` moved the save's mtime 15:14 -> 15:15 and its md5 `0bdbbc31` -> `30d3b4ca` **at an identical 81,221 bytes** — `GameState._notification` (`:477-495`) fires and writes a same-length record (a timestamp field), i.e. the autosave-on-background is live |
| **round-trip closure** | relaunching after that flush reloads to `a1606c26`, the **byte-identical known-good dashboard frame** — so the flush wrote a complete, valid campaign, not a truncated one |

⭐ **Atomic-write integrity holds**: `.save` and `.bak` are both 81,221 bytes at the same mtime,
and the log carries **zero** `SaveFileWriter … recovered from …` lines — the marker that would
mean the primary had been found truncated and the backup used. The `.tmp -> flush -> .bak ->
verified rename` chain is doing its job on real scoped storage.

## Box 3 — "writes somewhere the user can actually reach": **CONFIRMED FAIL, and worse than predicted**

The plan predicted a destination problem. There are **two independent gaps, either fatal alone.**

**(a) The destination.** Measured after pressing *Export My Data*:
`files/data_export.json`, **9,200 bytes, mode `-rw-------`, owner `u0_a179`** — app-private
internal storage. `/sdcard/Download`, `/sdcard/Documents` and
`/sdcard/Android/data/<pkg>/files/` are all **empty**. `SettingsScreen._on_export_data_pressed()`
(`:786-815`) has no `FileDialog`, no SAF hand-off, no share intent, no `OS.shell_open`.

**(b) ⭐ The CONTENT is not the user's data.** This is the half the plan did not predict.
`LegalConsentManager.export_user_data()` (`:74-87`) has the docblock *"Collects all user:// files
into a manifest dictionary for **GDPR portability**"* — and `_collect_files_recursive` collects
**paths and sizes only**. The exported object is `{app_version, export_date, files[58]}`, each
entry `{path, size_bytes}`. Probed against the live campaign: **`Bryn Ito`, `Dex Kovac`,
`credits`, `crew`, `Far Runner`, `Gamma Prime` — all ABSENT.** A user who exports and opens the
result learns the NAMES AND SIZES of their files and none of their contents.

GDPR Art. 20 asks for the personal data "in a structured, commonly used and machine-readable
format". A file listing is neither the data nor portable. Filed as **T11-52**.

⚠ And the app asserts success: a green toast reads *"Data exported to data_export.json in your
user data folder."* — accurate about the filename, and "your user data folder" is a path no
Android user can open.

## Box 4 — `user://transfers/` survives an app restart: **PASS, fully walked**

Blocked as a WRITER test (`MainMenu.gd:20` `const A1_BUILD := true` disconnects Bug Hunt /
Tactics / Planetfall, so nothing can produce a file), so the READER was driven with a
hand-built envelope shaped from the real validator (`_validate_transfer_data:593-615`) rather
than invented, plus a deliberately truncated twin.

| Step | Result |
|---|---|
| valid envelope dropped in | detected, `target_mode` filter passed |
| truncated twin | **quarantined** to `xfer_bad.json.corrupt` with `ERROR: … unreadable transfer file quarantined as … the character it held could not be imported` |
| dialog | **"Veterans Awaiting Orders — 1 character(s) have transferred to this campaign: • Walk Probe — from bug_hunt"** [Later] [Muster In] |
| **Later** | dialog dismissed, **file kept**, save unchanged |
| **restart** (force-stop + relaunch) | **the dialog came back** — this is the box, and it is the half a one-shot test cannot see |
| **Muster In** | correctly **REFUSED**: *"1 veteran(s) left pending — crew at capacity."* |

⭐ **That refusal is the Core Rules p.63 crew cap, and it is right.**
`_apply_pending_transfers()`'s first check is
`if campaign.get_crew_size() >= campaign.get_campaign_crew_size(): skipped += 1; continue`. The
fixture campaign is **6/6**, so the transfer is refused, the file is correctly KEPT for later,
and the player is told why. The book rule got exercised for free.

## ⚠ The harness lesson of this section, and it bit TWICE

**I nearly filed "Muster In does nothing" as a defect.** The file stayed, the save was
unchanged, and the log was empty — three signals all consistent with a dead control. The
control was working perfectly and *told me so in a toast that had already faded* by my capture
at t+6 s.

The same thing happened on the data export, where I first wrote "no feedback appeared".
Sampling at **t+0.3 / 0.7 / 1.5 / 3.0 s** found both toasts; the app's toasts live ~1.5 s and
`adb exec-out screencap` alone costs 100-200 ms.

**Rule for this harness going forward: any UI-feedback assertion must sample sub-second, and
"nothing happened" is never a verdict until a fast sample has looked.** Same family as
[[reference_instrument_the_probes_own_premise]] and the fling measurement earlier today — the
third time this session that a probe coarser than the effect produced a confident false
negative.

## Campaign safety

The transfer test mutates by design (a pickup adds crew), so the save was copied to
`…save.walkbak` inside the app's own dir first and restored afterwards. Final state:
`0bdbbc31`, `files/transfers/` removed, `/data/local/tmp` staging files removed, and the saves
directory back to its original 8 entries.


---

# Walk status at the end of the 2026-09-08 session — BLOCKED ON HARDWARE

## Where it stopped

The tablet **dropped off USB** partway through §6's portrait-upload box. The signature was a
run in which every frame hash came back `d41d8cd9` — the md5 of an **empty** capture, i.e. the
harness was blind, not the app dead. `adb devices` then reported none, and a Windows PnP query
found no Android device either, so it is a cable / power / USB-debugging-authorisation issue
rather than software. `adb kill-server && adb start-server` did not recover it.

⚠ **Worth keeping as a harness rule**: `hashlib.md5(b"")` is `d41d8cd98f00b204e9800998ecf8427e`.
A capture harness that hashes screencap output should special-case zero bytes and abort, because
an empty capture otherwise reads as "a stable frame" — i.e. as a PASS on every box that asserts
"the frame did not move". Two boxes' worth of taps were issued against a disconnected device
before the constant was recognised.

## Answered this session (7 boxes, 25 -> 18 unticked)

| § | Boxes closed |
|---|---|
| **§1 safe area** | **all 4** — needed deploy #29's `[SAFEAREA]` instrument plus cutout emulation |
| **§6 scoped storage** | **3 of 4** — save round-trip PASS, transfers PASS, data export **FAIL (T11-52)** |

Plus, not a checklist box: the **crew-card tap path** verified on glass (one tap = one
navigation; a 600 ms drag scrolls without navigating).

## Left mid-flight, resume here

- **§6 portrait upload** — the walk was three taps from the answer. `Change Portrait` is at
  **(142, 307)** on the character detail screen, reached by Continue Campaign **(2320, 434)** ->
  Manage Crew **(1070, 1552)** -> a crew card **(1280, 350)**. A test image is already pushed to
  `/sdcard/Pictures/portrait_probe.png`. `CharacterDetailsScreen.gd:1232` sets
  `use_native_dialog = true`, so the SAF picker should open — **predicted PASS**, unlike
  `CharacterCreator.tscn:155-162` which is the predicted FAIL.
- **§2** — the `UnitActivationCard` double-fire (needs the battle Quick/Slow Actions phase) and
  the `DebugScreen` long-press (`DebugScreen.gd:122`, reachable from the **DEBUG** bar at the
  bottom of Settings).
- **§4 / §5 / A5 / A6 / A7 / A8 / A9** — untouched.

⭐ **The `CharacterCard` #29 fix is still device-unconfirmed** and needs a **freshly created**
campaign, because a loaded save yields Dictionaries and those take the already-fixed T11-28 path.

## Useful coordinates measured this session (landscape 2560x1600)

Main menu column x=2320: Continue 434 · Load 512 · New 590 · Onboard 670 · Co-op 748 ·
BattleSim 828 · BugHunt 906 · Tactics 984 · Planetfall 1064 · Settings 1142.
Dashboard bottom row y=1552: Resume 286 · Save 708 · ManageCrew 1070 · Load 1434 · Export 1758 ·
QA 1966 · Edit 2054 · Sheets 2162 · Quit 2378.
Character detail: `< Back` (92, 107) · `Change Portrait` (142, 307).
Settings (scrolled to the bottom): `Export My Data` (1272, 730) · `Delete All Data` (1272, 796)
— ⚠ only 66 px apart, and the second is A9.

## Desk work completed while blocked

**T11-51 fixed** (the captain's `[` avatar) — `BaseCampaignPanel._create_character_card()` now
takes an optional `identity_name`, defaulting to `char_name` so the three undecorated callers
are untouched; `CrewManagementScreen.gd:168` passes the bare name. Pinned by
`tests/unit/test_character_card_identity.gd` (6 cases), **both arms detection-proven**.
Gates: 40 cases / 0 failures across the new suite plus every suite touching those files, and
**all 8 lints exit 0**.

## Device state to restore on reconnect

`screen_off_timeout` was set to **1800000** and must go back to **120000**.
`navigation_mode` was returned to **0** (3-button) and cutout overlays were disabled, but both
should be re-verified. `/sdcard/Pictures/portrait_probe.png` is left in place for the resumed
test. The campaign save was last read as **`0bdbbc31`** with `files/transfers/` removed and the
saves directory back to its original 8 entries.


---

# T11-53 — every edit on the Character Details screen is silently discarded once the app has been backgrounded (2026-09-09, deploy #29)

⭐ **This started as "§6 box 2: does portrait upload work?" and the portrait turned out to be
the least of it.** The upload works perfectly. What does not work is *saving anything at all*
on that screen after the app has been backgrounded once — and opening the portrait picker
backgrounds the app, which is the only reason the portrait looked like the defect.

## What a player loses

Type notes on a crew member, tap **Change Portrait**, pick an image, tap **Save Changes** —
and the notes, the portrait, and any other edit are **gone with no error, no warning, and a
navigation back to the crew list that looks exactly like success.**

## The portrait chain itself is CORRECT — all four links verified

| Link | Result |
|---|---|
| `use_native_dialog = true` (`CharacterDetailsScreen.gd:1232`) opens the real SAF picker | ✅ `topResumedActivity=com.google.android.documentsui/…picker.PickActivity` — a Godot-internal FileDialog would have kept our own package resumed |
| the picker can browse real shared storage | ✅ Alarms/DCIM/Documents/Download/Pictures… and the `crew_log_*.pdf` files earlier sheet-export tests wrote there |
| the PNG is written to `user://portraits/` | ✅ `char_690708_7921.png`, 1540 B |
| it is named after the character | ✅ `char_690708_7921` is **Dex Kovac's real `character_id`**, not the `"char_%d" % ticks` fallback — I suspected the fallback from the shape of the name and was wrong |
| the hero card re-renders immediately | ✅ frame moved |

## The isolation, one variable at a time

| Run | Backgrounded first? | Edit | Result |
|---|---|---|---|
| notes only | **no** | `WALKPROBE0909` | **PERSISTED** |
| notes after a SAF picker round-trip | yes (picker) | `AFTERPICKER0909` | **LOST** |
| notes after a plain `KEYCODE_HOME` + resume, **no picker** | yes (HOME) | `BGONLY0909` | **LOST** |

⭐ **The third row is the one that matters.** It removes the picker entirely and the edit is
still lost, so the picker is incidental — **backgrounding is the cause**, and the defect is
therefore far broader than a portrait bug. Every step was frame-asserted, and the typed text
was verified *in the field* by pixel-diff (`…09BGONLY0909`) before the save was read, because
an unfocused field and a discarded edit look identical from the save alone.

## Where it breaks: the in-memory sync, not the disk write

Split test — after backgrounding, edit, **Save Changes**, then reopen the detail screen with no
further backgrounding: the card shows the **OLD** note (frame `79731bd6`, byte-identical to
before the edit). So the edit never reached the live crew dict; this is not a flush problem.

The suspect region is `CharacterDetailsScreen._sync_character_to_source_dict()` (`:1002-1042`),
whose four early returns are all silent:

```gdscript
if not current_character or not GameStateManager: return
if not GameStateManager.has_temp_data("source_crew_dict"): return
var source_dict: Dictionary = GameStateManager.get_temp_data("source_crew_dict")
if source_dict.is_empty(): return
```

Two mechanisms remain and they are indistinguishable from outside: either `source_crew_dict` is
**gone from temp_data** after the resume (early return), or it survives but now references an
**orphaned dict** — a member dictionary that is no longer the one inside
`campaign.crew_data["members"]`, which would happen if the campaign object were rebuilt from
disk on resume. ⚠ The second is plausible precisely because
`GameState._try_auto_load_last_campaign()` (`:150`) reloads a campaign unconditionally — the
same mechanism that made **T11-49**'s absence test wrong.

⚠ **Ruled OUT by reading, so the next build need not re-check them:** `portrait_path` IS an
`@export var` (`Character.gd:215`), IS emitted by `to_dictionary()` (`:1453`), and IS on
`EDITABLE_KEYS` (`CharacterDetailsScreen.gd:25`); and `get_crew_members()` returns the **live**
array (`FiveParsecsCampaignCore.gd:936`), not a duplicate.

⚠ **Also found while tracing, and worth a row of its own:**
`GameStateManager.mark_campaign_modified()` (`:241-242`) is **`pass`** — a no-op. `_on_save_pressed()`
calls it to mark the campaign dirty, so **"Save Changes" never schedules a save at all**; the
notes in the clean run survived only because the harness pressed HOME afterwards and the
lifecycle flush happened to catch the in-memory state. A player who taps Save Changes and then
force-stops loses the edit even in the working case.

## What the next build needs to print

One debug line inside `_sync_character_to_source_dict()` naming which of the four early returns
fired, plus the identity of `source_dict` against the live member dict. That single print
separates the two remaining mechanisms; everything above is already established without it.


---

# T11-54 — the Debug & Support log pane cannot be scrolled by finger; a drag selects text (2026-09-09, deploy #29)

The §2 box reads *"Long-press does not select text in RichTextLabel help/EULA content"*. **The
two surfaces it NAMES are fine.** The one it does not name is not.

## Measured, with a control arm

| Arm | Gesture | Result |
|---|---|---|
| **CONTROL** — the Settings page (long, scrollable, NOT selection-enabled) | 1500 ms press-drag | **SCROLLED** (`3d31e0d5` -> `acb2ac06`) — so the gesture itself works |
| **THE BOX** — `DebugScreen._log_display` | 1500 ms press-drag ACROSS the text | **SELECTED** — a blue highlight over eight log lines, captured in `sel_diff_across.png` |
| same, 2500 ms | identical frame | reproducible |

⚠ **My first attempt at this looked like a PASS and was worthless**: the drag ran from
y=900 to y=500, and the log text only occupies y≈295-600, so it began in empty space *below*
the content and produced no change at all. The pane also holds only ~12 lines right now, so
there was nothing to scroll either — **an unchanged frame there meant "nothing to do", not
"nothing happened"**. Dragging across the actual glyphs is what produced the answer.

## Why it matters — this is not a debug-only screen

`DebugScreen.gd:126` sets `selection_enabled = true` on a `RichTextLabel` that holds
**`MAX_LOG_LINES := 200`** lines at 12 px, far more than one screen. `scroll_following` is on
and `scroll_active` defaults true, so a scrollbar exists — but a finger drag is consumed by the
selection, leaving a thin scrollbar as the only touch affordance.

⭐ **And the screen is NOT release-gated.** `SettingsScreen._on_debug_pressed()` (`:1043`) is
wired to a `DEBUG` button built unconditionally at `:281-291` — the only `OS.is_debug_build()`
calls nearby belong to the unrelated `[T11-26]` print. The page tells the player *"This page
helps debug issues. Copy the log below and include it when reporting bugs."* So a real user,
following that instruction on a real tablet, cannot scroll the thing they are being asked to
read.

## The fix is not simply to turn selection off

There is already a **COPY TO CLIPBOARD** button beside it, which covers the primary use case
without any selection at all. Selection only adds the ability to grab a *subset* — worth little
against losing touch-scrolling entirely on the device the log is being read on. Either drop
`selection_enabled`, or keep it and give the pane a real touch-scroll path.

⚠ Same family as T11-28 and the `TouchScrollOpener` work: **a surface that consumes the drag is
unusable on glass even when it is perfectly fine with a mouse.** This one is not a mouse-filter
problem, so the existing sweep cannot see it — `TouchScrollOpener` opens filters, and
`selection_enabled` is a different mechanism entirely.

## Incidental: T11-50 re-confirmed on this build

The same capture shows the pane populated with real engine output — System Info, the Godot
banner, the Vulkan device (`ARM - Mali-G57 MC2`), `[T11-07]`, three `[SAFEAREA]` lines and
`[T11-26] SettingsScreen touch-scroll filters opened: 52`. On #28 this pane read *"No log
entries captured yet."*


---

# Session close — 2026-09-09. Checklist 25 -> 16 unticked

## Closed this session (9 boxes)

| § | Boxes | Verdict |
|---|---|---|
| **§1 safe area** | **4 of 4** | all PASS — needed #29's `[SAFEAREA]` instrument *plus* cutout emulation; unanswerable without both |
| **§2 touch** | 1 (long-press) | **FAIL — T11-54** |
| **§6 storage** | **4 of 4** | save round-trip PASS · transfers PASS · data export **FAIL (T11-52)** · portrait upload PASS-with-**T11-53** |

Plus, off-checklist: the crew-card tap path verified on glass, and T11-50 re-confirmed.

## Three defects opened, in ascending order of seriousness

- **T11-51** — the captain's avatar rendered a literal `[`. **FIXED** at the desk this session,
  6 cases, both arms detection-proven.
- **T11-54** — the release-reachable Debug & Support log pane cannot be scrolled by finger;
  the drag selects text. ⭐ Its "harmless because the pane is always short" mitigation **expired
  when T11-50 was fixed** in the same build.
- **T11-53** — ⭐ **the serious one.** Every edit on the Character Details screen — notes,
  portrait, anything — is **silently discarded** once the app has been backgrounded, and
  "Save Changes" navigates back looking exactly like success.

## What is still open

**16 checklist boxes**: §3 legibility (4, deferred by owner decision) · §4 performance (4 of 5;
cold start is ticked) · §5 plugins (2 answerable of 4 — haptics is hardware-blocked, billing
parked) · §2 multi-touch double-fire on `UnitActivationCard` · plus the "before Sunday" pair.

**Still device-unconfirmed**: the `CharacterCard` #29 fix, which needs a **freshly created**
campaign (a loaded save yields Dictionaries, which take the already-fixed T11-28 path);
`UnitActivationCard`, which needs the battle Quick/Slow Actions phase; and
`CharacterCreator.tscn`'s `PortraitDialog`, the predicted-FAIL twin of the working picker.

**Recorded, not fixed**: `auto_load_last_campaign` (dead setting, owner call) ·
`mark_campaign_modified()` is a `pass` no-op · renderer arm B · the battlefield pan/zoom UI
string promising an interaction with no implementation.

## Device state left clean

`screen_off_timeout` **120000** (restored) · `navigation_mode` **0** · no cutout overlays ·
`/sdcard/Pictures/portrait_probe.png` removed · `files/portraits/` emptied · the test note and
portrait_path cleared from the campaign, **and the edit verified safe by re-loading**: menu,
dashboard `a1606c26`, crew `038084c1` and the detail screen `43c4e4a1` all match their
pre-test frames, with no log errors.

## ⚠ The harness lesson of the whole session

**Five separate times a probe reported a result it had not earned**, and every one initially
read as a product defect:

1. two toasts missed because a 2-6 s capture is slower than a ~1.5 s toast;
2. a tap on a button *boundary* reported as "the control did nothing";
3. an **empty screencap** (`d41d8cd9…`, the md5 of zero bytes) from a disconnected device,
   reading as "the frame did not move" — i.e. as a PASS;
4. a long-press-drag that began in empty space *below* the text it was meant to select;
5. a colour assertion that could not vary the quantity it tested, and so was a permanent
   false green no matter how many names it looped over.

The common shape is not carelessness about the app — it is **asserting an outcome without
first proving the stimulus was delivered**. The harness now aborts on an empty capture and
asserts each navigation step against a known frame before continuing, which is what turned
T11-53 from "the portrait does not save" into a one-variable isolation.

⭐ And the corollary that actually found T11-53: **when a probe fails, suspect the probe first.**
Four consecutive runs said "the portrait does not persist" and all four were my own harness
under-driving the workflow. Only after the fifth run — fully frame-asserted — did the failure
survive, and *that* is when it was worth chasing. Two of my own recorded claims had to be
corrected the same way ([[reference_a_detection_proof_needs_a_discriminating_fixture]]).


---

# §5 Android plugins — 2 of 4 answered, and the other 2 are answered as *unanswerable*

Walked 2026-09-09 on deploy #29, device HNQ05SR3 / TB361FU.

## The instruments, and why they beat the ones the plan proposed

The plan's route for the review box was "seed `review_prefs.cfg` with `turns_completed=99`
and complete one turn". Reading the source first found two cheaper and *more* discriminating
instruments, and neither needs a turn of gameplay:

1. **The Rate button's EXISTENCE is the plugin-presence test.** `StoreScreen.gd:192-194`
   creates "Rate This App" only `if _review_mgr.is_review_available()`, which is
   `_platform != "offline"`, which on Android is exactly
   `Engine.has_singleton("InappReviewPlugin")` evaluated at autoload `_ready()`. So one
   screenshot of the store footer answers "is the plugin registered?" — with
   **"Restore Purchases" sitting beside it as a built-in control arm**, because that button
   is gated on a *different* predicate (`is_offline_mode()`).
2. **`last_prompt_timestamp` is a RECEIPT for the native flow.** It is set to "now" in one
   place only — `_record_review_prompt()` (`ReviewManager.gd:204`) — which has two callers:
   the **Steam** branch of `request_review()` (`:136`) and `_on_review_flow_launched()`
   (`:185`). On Android `_platform` is `"mobile"`, so `:185` is the only reachable writer,
   and it fires only when `InappReview` relays the **native plugin's** signal.

## Review: `InappReviewPlugin` two-step flow does not crash — **PASS**

| Evidence | Result |
|---|---|
| Dex probe of the APK **pulled off the device** | `InappReviewPlugin` **x12** in `classes.dex`; `com/google/android/play/core/review` **x83** |
| Control probes on that search | `org/godotengine` x460/x18/x2 and `GodotPlugin` x13 FOUND; `ZzQqNoSuchClassXyz` absent — so "absent" is meaningful |
| `is_review_available()` on device | TRUE — "Rate This App" is rendered in the store footer |
| `can_request_review()` gating | **one-variable A/B**: `last_prompt_timestamp` 1788633947 → 0, nothing else touched → the button goes **dim → bright white**, while "Restore Purchases" is pixel-identical in both frames |
| The live two-step flow | Play Core bound `com.android.vending/…InAppReviewService`, logging `ReviewService : requestInAppReview (com.reptarus.fiveparsecs)` → `onServiceConnected` → `OnRequestInstallCallback : onGetLaunchReviewFlowInfo` → `Unbind from service` |
| `_on_review_flow_launched()` fired | `last_prompt_timestamp` **0 → 1788972015** |
| Corroboration | that timestamp decodes to **09:40:15**; the Play Core callback is stamped **09:40:15.125**. Two independent instruments agreeing to the second. |
| Errors | none in logcat |

⚠ **What this does NOT claim: no review SHEET rendered.** That is expected, not a defect —
Google's in-app review API deliberately shows nothing when the quota is exhausted or the
user has already reviewed, and returns success anyway; a sideloaded build (not installed
from Play) is a second reason. The box asks whether the two-step flow *crashes*. It does not.

⭐ **The stale artifact was itself a finding before I touched anything.** The file already
held `last_prompt_timestamp=1788633947` = **2026-09-05 11:45:47**, which by the writer
analysis above means the native flow had already launched successfully on this tablet during
an earlier deploy. That is a lead, not a measurement — which is why it was re-run live rather
than reported from the file.

## Bug reporter: attach + submit path works end-to-end — **PASS**

Predicted from the APK before touching the device: `res://support_config.cfg` is **absent**
(control: other `.cfg` entries ARE packed), it does not exist on disk, and it is gitignored
at `.gitignore:22` — so `BugReportWebhook.is_configured()` is false and the **`mailto:`
fallback** must run. Confirmed on device.

| Step | Assertion | Result |
|---|---|---|
| **Control arm first** | Send with an EMPTY description | blocked with *"Please describe what happened before sending."*, and **`files/bug_reports/` was NOT created** — so any later file is attributable to a real submit |
| Attach — log | "Attach app log (N lines)" | **11**, then **15** on a later open — non-zero AND growing, so the tail is live, not cached |
| Attach — context | `context` keys | **22**, incl. `device_model: 'TB361FU'` (`OS.get_model_name()`, called nowhere else in the project), `platform: Android`, `app_version: 0.9.7-alpha1`, `build_type: debug`, `engine: 4.6-stable (official)`, `orientation: landscape`, `effective_columns: 4` |
| Attach — log content | real engine output | Godot banner, `Vulkan 1.3.219 - Forward Mobile - Using Device #0: ARM - Mali-G57 MC2`, `[T11-07]`, three `[SAFEAREA]`, `[T11-26] … filters opened: 52` |
| Save | `Save & Copy` → disk | `files/bug_reports/report_1788972636_a028.json`, 2077 bytes; the on-screen *"Saved at: user://bug_reports/report_1788972636_a028.json"* **matches the file on disk exactly** |
| Clipboard | `DisplayServer.clipboard_set()` | verified — Gboard's clipboard chip in the Gmail compose read **"FIVE PARSECS CAMPAIGN MANAGER — BUG REPORT ====…"** |
| Submit | `Send` → `mailto:` | `topResumedActivity=com.google.android.gm/.ComposeActivityGmailExternal` — a real external app, the same discriminator that proved the SAF picker |
| Submit payload | pre-filled draft | To **`aftermidnightmakers@gmail.com`** (= the `SUPPORT_EMAIL` const), subject *"FPCM Bug Report v0.9.7-alpha1 — Crash or freeze"*, body carrying Category/Version/Screen/Phase, the description, and the saved path |
| Webhook branch | correctly NOT taken | as predicted from the APK |

⭐ The clipboard half was expected to be untestable from adb — modern Android does not expose
the clipboard to the shell. It was verified by accident: **Gboard surfaces recent clipboard
entries as chips above the keyboard**, and ours was sitting there in the Gmail compose. Worth
remembering as a general instrument.

Draft **discarded** via Gmail's own overflow menu (never sent); both test reports deleted and
`files/bug_reports/` removed, restoring the pre-test state.

## Haptics: the helper actually buzzes — **UNANSWERABLE ON THIS HARDWARE**

`isVibratorControllerRegistered = false`, `capabilities = []`, feature absent from
`pm list features`. Recorded as blocked-by-hardware, **not** as untested. What *can* be said:
the **Touch & Haptics** card renders and **"Haptic Feedback" is ON**, with "Touch Sensitivity"
at 120% — so on a device with a vibrator the setting is live and would be consulted.

## Billing: `BillingClient` resolves — **PARKED, and now also MEASURED**

Parked by owner decision pending the LOI, so this is not chased. But the APK was already
pulled, so the fact was free: **the Google Play Billing plugin is entirely absent from the
build.** Five spellings probed — `BillingClient`, `com/android/billingclient`,
`godotgoogleplaybilling`, `GodotGooglePlayBilling`, `play/billing` — **zero hits each**, and
**zero APK entries** matching `billing`; the control `play/core` returns 91+4. On screen this
shows as the store banner **"Development Mode — No store connection"** with every product
button reading **"Not Available"**, i.e. `OfflineStoreAdapter`.

⭐ So the box is blocked for **two independent reasons**, and only one of them was known: the
LOI (a decision) *and* the plugin not being in the build (a fact). Un-parking billing will
need a build change, not just a decision.

---

## ⚠ New finding — the bug reporter's own details panel selects text instead of scrolling

`BugReportDialog.gd:186` sets `_details_label.selection_enabled = true` on the RichTextLabel
behind **"Show what is sent"**. A finger drag over it produces a **blue multi-line selection**
and no scroll; the scrollbar works.

⭐ **This completes T11-54's census.** `grep -rn "selection_enabled" src/` returns **exactly
two sites repo-wide**, and both are now measured on hardware:

| Site | Surface | Measured |
|---|---|---|
| `DebugScreen.gd:127` | `_log_display`, up to `MAX_LOG_LINES := 200` | **T11-54**, 2026-09-08 |
| `BugReportDialog.gd:186` | `_details_label`, `fit_content = true` | **this walk** |

Severity here is lower than T11-54, and the reason is structural: `BugReportDialog.gd:192`
pins the status label and the Cancel/Save/Send row **OUTSIDE** the ScrollContainer (*"Status
+ actions live OUTSIDE the scroll, pinned to the bottom"*), so the submit path is never
blocked by the swallowed drag — and **"Save & Copy" already captures the whole payload**,
which is what selection would otherwise be for. It is an informational panel the tester
cannot finger-scroll, not a broken submit.

⚠ `BugReportDialog` builds a `ScrollContainer` at `:122` and **never calls `TouchScrollOpener`
and never sets a `mouse_filter`** — and, being a `Window`, it is its own Viewport, so none of
the `CampaignScreenBase` / `BaseCampaignPanel` / `BasePhasePanel` sweeps can reach it. Same
structural blind spot as T11-11.

## ✅ Incidental verification — KeyboardAvoidance works on a player-facing `Window`

T11-11 named `BugReportDialog` as one of **two player-facing dialogs** that were structurally
blind to the soft keyboard; it was fixed at the desk and never verified on glass. Measured
here, with a deliberately **discriminating** arm:

- Focusing "What happened?" (y 589-749) is **not** discriminating — the keyboard line is
  **y=840**, so that field never needed to move. Recorded because it would otherwise look
  like a pass.
- Focusing the **lowest** input, "Your name or email" at **y≈974** — 134 px *under* the
  keyboard — moved it to **y≈773**, i.e. 67 px clear. A ~201 px scroll.
- The Window itself **never moved**: title-bar top is **y=368** in every frame, keyboard open
  or closed.

That is exactly the T11-15 design: **headroom-and-scroll where a ScrollContainer exists,
move-the-Window only where it does not.**

⚠ The keyboard edge had to be measured, not eyeballed: a naive "first differing row" diff
returned **y=589**, which is the TextEdit's **focus ring**, not the keyboard. A full-row
difference *profile* separates them cleanly — the ring scores 60-165, the keyboard 18k-36k.

---

## ⚠ Harness note — coordinate replay does not work on this device

Two identical swipes from the **identical** top frame (`3d31e0d5`) landed on `de40c096` one
run and `7529f7d9` the next, because `ScrollContainer` fling inertia varies per swipe. A
remembered tap coordinate is therefore only valid within the run that measured it.

The fix is `findbtn.py`: locate the control by **pixels** in whatever frame we actually
reached. Measured geometry — the button occupies x 64..308, and column **x=76** is clean
`#1F2937` fill for its full height (left of the glyphs, which break a naive run at x=150).
Discriminator against the full-width Legal & Privacy buttons, which share that fill: at
**x=400** the Browse button is background and a full-width one is not. Validated against the
known-good frame **and three control arms that must not match** — all three returned empty.

⭐ The guard earned its keep immediately: on the first replay attempt it **refused to tap**
because the frame was `ddc35bee` rather than the expected `de40c096`. Without it, that tap
would have landed on whatever happened to be at those coordinates, and the result would have
been reported as a store-screen reading.

⚠ **A frame-hash change is necessary but not sufficient.** Dragging the dialog body changed
the hash and read as "SCROLLED"; the pixels showed it had **focused a TextEdit and opened the
keyboard**. Same failure shape as the five recorded on 2026-09-08 — look at the frame, do not
trust the hash alone.


---

# §4 ARM performance and thermals — 3 of 5 closed

Walked 2026-09-09, deploy #29, TB361FU. The two left open are the expensive pair
(15-minute thermal window + memory across 5 turns), which the plan says to run together.

## ⚠ First, the instrument — `dumpsys gfxinfo` is STRUCTURALLY BLIND to this app

Godot renders through a **SurfaceView**, which bypasses the HWUI pipeline that `gfxinfo`
measures. Measured on the dashboard after a dozen scrolls and flings:

```
Total frames rendered: 0
Janky frames: 0 (0.00%)
50th / 90th / 95th / 99th percentile: 4950ms   (the empty-bucket sentinel)
HISTOGRAM: 5ms=0 6ms=0 … 4950ms=0
Pipeline=Skia (OpenGL)
```

⭐ **`Janky frames: 0 (0.00%)` reads like a perfect score and means "nothing was measured".**
The tell is `Total frames rendered: 0` one line above it. This is the empty-screencap trap in
a new costume — a zero that presents as a pass. Do not report gfxinfo numbers for this app.

**The instrument that works** is `dumpsys SurfaceFlinger --latency '<layer>'`, where the layer
is `aab36fa SurfaceView[com.reptarus.fiveparsecs/com.godot.game.GodotAppLauncher](BLAST)#7011`
(from `dumpsys SurfaceFlinger --list`). It emits the display refresh period followed by one row
per frame: `desiredPresentTime actualPresentTime frameReadyTime`, in ns. Harness:
`pacing.py`, `--latency-clear` before each arm.

## Frame pacing: no hitching on Campaign Dashboard scroll — **PASS**

| Arm | median | p90 | p95 | p99 | max | >33 ms | >50 ms |
|---|---|---|---|---|---|---|---|
| **IDLE** (dashboard, no input, 4 s) | 11.17 ms | 22.23 | 22.26 | 22.30 | 22.39 | **0** | **0** |
| **SCROLLING** (right column, 10 alternating swipes) | 22.20 ms | 22.23 | 22.23 | 22.24 | **22.24** | **0** | **0** |

**p90 = p95 = p99 = max = 22.24 ms.** That is not merely "no hitch", it is *no variance at
all* — the strongest possible reading for this box. Zero frames over the 33 ms drop threshold,
zero over the SOP's 50 ms hitch threshold (`docs/sop/android-runtime-testing.md:263-265`).

⚠ **The scrolling arm had to be re-run.** The first attempt swiped 12 times and every frame
came back byte-identical (`0a168e8e`) — the column had already reached its stop four swipes
earlier, so pacing was being measured while **nothing was scrolling**. The rerun alternates
down/up and asserts the frame moved: **9 of 10 swipes moved it**. Same lesson as the five
recorded on 2026-09-08: prove the stimulus landed before believing the outcome.

## ⭐ Measured incidentally: the app renders 60 fps and the panel shows 45

Two instruments, sampled **simultaneously** over the same scroll:

- **In-app counter: `FPS: 60`** on all 10 frames. It is `Engine.get_frames_per_second()`
  (`SettingsManager.gd:416`) — the *render-loop iteration rate*, which is what the app can see
  about itself.
- **SurfaceFlinger present interval: a steady 22.20 ms** — i.e. **45 distinct images per
  second reach the glass**.

The panel is **90 Hz** (refresh period `11111111` ns = 11.11 ms, straight off the trace) and
`project.godot:26` sets **`run/max_fps=60`** with vsync at Godot's default (enabled).

**Likely mechanism (inference, not measured):** 60 fps cannot align to 90 Hz — a 16.67 ms
frame always misses the next 11.11 ms vsync and waits for the one after, landing on every
*second* refresh. 2 × 11.11 = 22.22 ms = 45 fps, which is exactly what the trace shows, with
the idle arm showing the expected mixed 11.11/22.22 cadence when the app is not animating.

⚠ **This is not a defect and it does not fail the box** — an even 45 fps is smooth. It is a
*smoothness-vs-battery* opportunity: raising the cap to match the panel would present on every
refresh. It is also an owner call, and `CLAUDE.md` already anticipated exactly this case
("FPS cap applies to high-refresh displays; expose via Settings UI later if needed") — that
note can now cite a measurement.

⚠ **And it retires the FPS counter as a pacing instrument**: it reported 60 throughout, which
was true of the render loop and wrong about what the player saw.

## Battlefield map pan/zoom smooth with a full terrain set — **the interaction DOES NOT EXIST on touch**

The box cannot be answered as asked, and *that is the finding*. Confirmed by reading, then
measured on hardware.

**By reading** — `BattlefieldMapView.gd` `_gui_input`:
- **pan** arms on **`MOUSE_BUTTON_MIDDLE`** only
- **zoom** on **`MOUSE_BUTTON_WHEEL_UP` / `WHEEL_DOWN`** only
- `MOUSE_BUTTON_LEFT` runs `_handle_click()` — the tap-a-sector popover
- **zero `InputEventPanGesture` and zero `InputEventMagnifyGesture` repo-wide**

Android's `emulate_mouse_from_touch` synthesises **LEFT** only — never MIDDLE, never WHEEL.
So on glass: tap works, pan cannot fire, zoom cannot fire.

⭐ **It is TWO surfaces, not one.** `HexStarMap.gd:6` records that its pan/zoom was *"adapted
from BattlefieldMapView (the only pan/zoom in the codebase)"*, and it inherited the binding —
`HexStarMap.gd:207` arms panning on `MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT`, zoom on WHEEL.
The codebase has exactly one pan/zoom implementation, it was copied once, and **both copies
are mouse-only**.

**Measured on the Galaxy Log** — chosen deliberately because it is reachable from the dashboard
and needs no battle:

| Arm | Gesture | Result |
|---|---|---|
| **A** | three finger drags across the map, three directions, 600 ms each | frame **byte-identical** (`9b4947d3`) all three times — no pan |
| **B (control)** | tap the *Foch II* hex | frame changed (`a7911e77`), `WorldDetailPopup` opened with real data (Corporate State, Danger 4, Visits 1, Missions 1) |

The control arm is what makes A meaningful: input **does** reach the map, so "nothing happened"
is the drag having no handler, not a dead screen.

⚠ **Pinch is not testable with this harness** — `adb shell input` is single-touch. But the code
read is conclusive on its own: a handler that does not exist cannot fire. Recorded as a
structural absence, not as an untested case.

### ⚠ The defect worth filing: a UI string promises an interaction with no implementation

`TacticalBattleUI.gd:853`:

> *"Terrain locked for battle — tap a sector for its rules; pinch/scroll to zoom, drag to pan."*

Of the three interactions that sentence promises a tablet player, **one works**. "pinch/scroll
to zoom" and "drag to pan" have no touch code path at all. This is the same family as the
`CheatSheetPanel` trap already in `CLAUDE.md` — *a displayed claim that exists nowhere else is
a lie waiting to be found* — except here the claim is about an interaction rather than a number.

Either wire the gestures (`InputEventPanGesture` / `InputEventMagnifyGesture`, or arm pan on
LEFT-drag once `TapGesture`'s 16 px slop distinguishes it from a tap) or correct the string.
**Correcting the string is the smaller change and stops the app lying to the player today.**

## Cold-start time to MainMenu — **PASS** (already measured, now ticked)

`am start -W`, `LaunchState: COLD`: **796 ms** and **817 ms** on two runs, against deploy #27's
**979 ms** — a **−18.7 %** improvement. A third sample later the same day read 899 ms. All well
inside any reasonable budget for a cold launch. Recorded at
`docs/qa/TABLET_BASELINE_2026-09-08.md` §"Cold start" and in the deploy-#28 comparison table;
the box had simply never been ticked.

## Minor, recorded not filed — `WorldDetailPopup` values sit under the scrollbar

In the Galaxy Log's planet popup the value column is right-aligned with **no gutter reserved
for the vertical scrollbar**, so the bar is drawn over the last glyph or two: at 2× the
magnification "Foch II" loses part of its second `I`, and the Danger Level `4` and Missions
Completed `1` touch the bar. Cosmetic, legible in context, one line of right padding on the
scroll content. Noted so it is not rediscovered as new.


---

# §4 addendum — pan/zoom IS testable, and it PASSES (correction)

Walked 2026-09-09, deploy #29, TB361FU, after the §4 section above was written.

## ⚠ The correction, stated first

The §4 entry above concluded *"the interaction does not exist on touch"* and recorded the box
as **unanswerable as asked**. The touch half of that is correct and still stands. The
**conclusion drawn from it was wrong**: I reasoned from one binding to "untestable" without
asking whether any other route reached the same code. **Three do**, and the answer is a PASS.

⭐ **The evidence was in the source I had already read.** `BattlefieldMapView.gd:129` says:

```gdscript
focus_mode = Control.FOCUS_ALL  # Enable keyboard input for pan/zoom shortcuts
```

`HexStarMap.gd:62` says the same (*"So keyboard pan/reset works."*). A **keyboard** pan/zoom
path is deliberate, commented, and `adb shell input keyevent` drives it natively. I had
grepped for `MOUSE_BUTTON_*` and `InputEventPanGesture`, found the answer I expected, and
stopped — the `InputEventKey` branch is thirty lines below the one I quoted.

## The three routes, all measured on hardware

| Route | Binding | Driver | Result |
|---|---|---|---|
| **Keyboard** | arrows pan (24 px), `+`/`-` zoom (0.15), `0` reset | `input keyevent` | **works** |
| **Wheel** | `MOUSE_BUTTON_WHEEL_UP` / `WHEEL_DOWN` | `input mouse scroll <x> <y> --axis VSCROLL,n` | **works** |
| **Middle-drag** | `MOUSE_BUTTON_MIDDLE` + motion | `uinput` virtual mouse | **works** |
| Finger | — | `input swipe` | **nothing** (tap-a-sector only) |

⭐ **SDK 36's `input` has verbs the older docs do not.** `input --help` on this device lists
`scroll <x> <y> [--axis VSCROLL,n]` for pointer sources, and `keyevent` accepts a **key list**
plus `--delay <ms>` in one invocation — which is what makes a *continuous* 40–125 Hz pan
possible from adb instead of one stepped key per round-trip. Read the device's own `--help`;
do not assume the command set.

⭐ **`/system/bin/uinput` exists and works.** It is an `app_process` wrapper around
`com.android.commands.uinput.Uinput`, takes a JSON command stream on stdin, and registered
`Device 79: FPCM Virtual Mouse` with `BTN_MIDDLE` + `REL_*`. ⚠ It **destroys the device when
stdin closes**, so the trailing `delay` is what keeps it alive long enough to capture.
⚠ **Android applies pointer acceleration to relative input**: one `REL_X 1216` landed the
cursor at ≈2500 px (~2×). Creep in ~20 px steps, where acceleration is ≈1:1.

## Frame pacing — the box's actual question

`dumpsys SurfaceFlinger --latency` on the Godot SurfaceView, 90 Hz panel (11.11 ms):

| Arm | median | p90 | p95 | p99 | max | >33 ms | >50 ms |
|---|---|---|---|---|---|---|---|
| **IDLE** (map on screen, no input) | 11.13 ms | 22.24 | 33.33 | 33.34 | 33.36 | **0** | **0** |
| **PAN** 80 steps @ 25 ms | 11.12 ms | 22.30 | 33.33 | 33.34 | 33.37 | **0** | **0** |
| **ZOOM** 40 steps @ 25 ms | 11.13 ms | 22.24 | 33.33 | 33.36 | 33.36 | **0** | **0** |
| **PAN STRESS** 160 steps @ 8 ms | 11.12 ms | 22.24 | **22.26** | 33.34 | 33.38 | **0** | **0** |

⭐ **The pan and zoom arms are indistinguishable from IDLE**, and tripling the input rate
*improved* p95 (33.33 → 22.26) because more frames present at 2 refreshes instead of 3.
Redrawing a full terrain set is below the measurement floor. ⚠ State the limit: this measures
**redraw cost under a stepped synthetic input**, not a continuous finger drag — the pacing is
bounded by the 40–125 Hz injection rate, not by the renderer. What it *does* establish is that
no interval exceeded the SOP's 50 ms hitch threshold, at any input rate, on any arm.

⚠ Note the median here is **11.12 ms (90 fps)** where the dashboard scroll measured a steady
**22.20 ms (45 fps)**. The map is a redraw-on-demand `_draw()` canvas, so it presents on the
refresh after each input rather than on a fixed 60 fps cadence.

## Determinism — three byte-identical returns

Stronger than "the frame moved", and the reason these arms are trustworthy:

- **PAN**: 20 LEFT + 20 UP → `ae79cd11`; then 20 RIGHT + 20 DOWN → **`041c2f3b`, byte-identical
  to baseline**. The 160-step stress arm returns byte-identically too.
- **ZOOM**: `+`,`+` → `74b39348`; `-` → **`42f273fd`, byte-identical to the one-step-in frame**.
- **RESET**: `KEYCODE_0` after two zooms *and* two pans → **`041c2f3b`, byte-identical**.
- **CONTROL**: `KEYCODE_J` (unbound) → **byte-identical**. The map is not repainting on any input.

## Control arms that make the above mean something

| Arm | Expected | Measured |
|---|---|---|
| `KEYCODE_J` (unbound key) | no change | **0 px** |
| `input mouse scroll --axis SCROLL,2` (generic axis, not VSCROLL) | no change | **0 px, bbox None** |
| virtual mouse parked over the map, **no button** | cursor only | **1,823 px**, bbox (1627,813)-(1675,861) — a 48×48 pointer |
| virtual mouse **MIDDLE held**, same drag | map pans | **818,427 px (20 %)**, bbox (792,88)-(2165,927) — the map's own rect |

⭐ The last two are the pair that matters: a visible mouse cursor changes ~1.8 k px; the pan
changes 818 k. Without the cursor-only arm, "the frame moved" would not have separated them —
and the first attempt at this *did* fail that way, moving only the cursor while the map sat
still, which the pixel diff caught immediately.

⚠ **Sub-pixel float residue, recorded not filed.** Wheel-zoom in, in, out differs from
wheel-zoom in by **259 px (0.006 %)** scattered across the map rect. `1.0 + 0.15 + 0.15 − 0.15`
is `1.1499999999999997`, not `1.15`, so grid lines land on different subpixels. Invisible, and
`KEYCODE_0` resets to exact constants. Noted so it is not rediscovered as a rendering defect.

## ✅ Incidental: T11-49 re-verified on hardware, free

Leaving via **Return** from the Battle Simulator is *precisely* the T11-49 defect (the handler
called `_clear_battle_checkpoint()` → `clear_active_battle()` → `save_campaign()` on a campaign
it did not own). Pulled the campaign save immediately before and after:

```
pre   bytes= 81221  md5=07988ca5  active_battle=True  active_battlefield=True  turns=9.0
post  bytes= 81221  md5=07988ca5  active_battle=True  active_battlefield=True  turns=9.0
```

**Byte-identical.** On the pre-fix build this same tap took the save to 63,641 bytes with
`active_battle` erased.

## ⚠ Harness note — the SurfaceFlinger layer handle is per-launch

`pacing.py` had the layer baked in as `aab36fa …#7011` from the previous session. After a
relaunch the surface is `502c4ab …#7095`, so `--latency` returned **zero rows** and the report
said *"only 0 frames captured — NOT ENOUGH TO JUDGE"*. That is the honest failure mode, but it
is one line away from being read as "nothing to see". `pacing.layer()` now resolves it from
`dumpsys SurfaceFlinger --list` on every run and prints what it bound to.


---

# §4 addendum 2 — pinch IS testable, and the root cause is a one-line project setting

Walked 2026-09-09, deploy #29. The pan/zoom entries above twice recorded pinch as
*"not testable with `adb shell input` (single-touch) — a structural absence, not an untested
case."* Both halves of that are now superseded: it **is** testable, it **was** tested, and the
reason it does nothing is **not** the one the earlier entries assumed.

## ⭐ The root cause: `enable_pan_and_scale_gestures` is `false`

Godot 4.6 registers an Android-only project setting that decides whether multi-touch is
translated into gesture events at all. Asked of the engine directly (a `SceneTree` probe
enumerating `ProjectSettings.get_property_list()`, since the online class reference documents
`InputEventMagnifyGesture` but never says which platforms **emit** it):

```
input_devices/pointing/android/enable_pan_and_scale_gestures    = false
input_devices/pointing/android/enable_long_press_as_right_click = false
input_devices/pointing/android/rotary_input_scroll_axis         = 1
input_devices/pointing/emulate_touch_from_mouse                 = true
input_devices/pointing/emulate_mouse_from_touch                 = true
```

`project.godot:107-109` contains **only** `pointing/emulate_touch_from_mouse=true`, so
`enable_pan_and_scale_gestures` is absent and takes the engine default of **false**.
`ClassDB` confirms all three gesture classes exist (`InputEventGesture`,
`InputEventMagnifyGesture`, `InputEventPanGesture`) — they are simply never emitted here.

⚠ **So there are TWO independent blockers, either fatal alone** — the recurring shape in this
codebase:

| # | Blocker | Evidence |
|---|---|---|
| 1 | The engine will not emit gesture events on Android | `enable_pan_and_scale_gestures = false`, absent from `project.godot` |
| 2 | The app has no handler if it did | `grep -rn "InputEvent\(Magnify\|Pan\)Gesture" src/` → **0 hits** |

⭐ **This upgrades the finding from "the interaction does not exist" to a concrete two-part
fix**: set the project setting, then add a `_gui_input` branch for the two gesture events.
The zoom/pan *code* those handlers would call is already proven working (see the addendum
above — three input routes, pixel-deterministic, 0 hitches).

## Pinch, actually injected and actually measured

⭐ **`adb shell input` is single-touch, but `uinput` is not.** A virtual multi-touch
touchscreen registered through `/system/bin/uinput`, mirroring the real `himax-touchscreen`
ABS ranges exactly (`ABS_MT_POSITION_X` 0..15999, `Y` 0..25599 — **10x the 1600x2560 panel**),
with `INPUT_PROP_DIRECT` so Android classifies it as a touchscreen rather than a touchpad.
Protocol B, two slots, real `ABS_MT_TRACKING_ID` lifecycle.

**Control arm — Android's own pointer-location overlay** (`settings put system
pointer_location 1`) rendered into the screencap and reads **`P: 2 / 2`** with both crosshairs
drawn on the map. That is the device itself certifying two live pointers, which no frame diff
could establish.

| Phase | Grid crop (900,400)-(1600,900) | Full frame |
|---|---|---|
| two fingers DOWN | **0 px** | — |
| fully SPREAD (the pinch) | **0 px** | — |
| after RELEASE | **0 px** | **119,409 px, bbox (421,93)-(848,373)** |

⭐ **The map changed by exactly zero pixels through the whole gesture.** The only thing that
changed anywhere on screen is bbox (421,93)-(848,373) — **the `SectorRulesPopover` rect**.
`emulate_mouse_from_touch` turned the *first* pointer into a synthetic LEFT click, which ran
`_handle_click()` and opened *"Sector D2"*; the second pointer did nothing at all.

**A pinch on the battlefield map is read as a single tap.** That is now measured, not inferred.

## ⚠ Harness notes worth keeping

- **`uinput` destroys its device when stdin closes.** A trailing `delay` command is what keeps
  it alive long enough to capture. `dumpsys input | grep 'FPCM Virtual'` after the run shows
  nothing, which is success, not failure.
- **Android applies pointer acceleration to relative (mouse) input** — one `REL_X 1216` landed
  the cursor at ~2500 px. Absolute MT coordinates have no such problem; creep in ~20 px steps
  for a virtual mouse.
- **ROTATION_90 mapping, measured off the pointer overlay's own readout**: panel is natural
  portrait 1600x2560, screen is 2560x1600, and **`screen_x = panel_y`, `screen_y = panel_x`**
  (in px; ABS units are 10x). Verified: panel Y 7800/17800 landed at screen x 781/1779, and
  panel X 8000 landed at screen y 800.
- ⚠ **Do not read the `has_setting()` column as "present in project.godot"** —
  `ProjectSettings.has_setting()` returns true for every *registered* setting, default or not.
  Grep the file.


---

# §2 touch physics — the double-fire box closed, and a NEW defect found next to it

Walked 2026-09-09, deploy #29, TB361FU, using the `uinput` virtual multi-touch harness built
for the pinch test above.

## Multi-touch does not double-fire a button — **PASS**

**Instrument choice matters here.** A toggle is the wrong target: `is_activated = !is_activated`
means a double-fire returns to the original state and reads as *"nothing happened"*, which is
indistinguishable from *"the tap never landed"*. The Battle Simulator's Crew Size `SpinBox`
(range 3-6) is a **counter**, so one press is +1 and a double-fire is +2 — a readable number
instead of an ambiguous absence.

| Gesture | Value | Fires |
|---|---|---|
| single-finger tap (**control**) | 3 → **4** | **1** |
| two fingers, same SYN frame | 3 → **3** | **0** |
| two fingers, **staggered** (finger 2 lands while finger 1 is held) | 3 → **3** | **0** |

**Placement proof**: Android's pointer-location overlay read **`P: 2 / 2`** at
**`X: 222.1, Y: 1070.0`** — exactly the injected panel coordinates — with both crosshairs
straddling the up chevron. Without that, "the value did not change" would not distinguish a
suppressed press from a missed target.

⭐ **The answer is stronger than the box asks and slightly different in shape: multi-touch does
not double-fire, it SUPPRESSES the press.** The staggered arm is the discriminating one —
finger 1 had already pressed, and the arrival of finger 2 cancelled it. `emulate_mouse_from_touch`
emulates pointer 0 only, and a second pointer cancels the emulated press. Recorded as a mild
usability note rather than a defect: a tap with a second finger resting on the glass does
nothing, which reads as palm rejection.

⚠ **Two stale premises in the old box text, both corrected at the row.** It named
`UnitActivationCard` and `CharacterCard` as still carrying the T11-36 dual-family shape — **both
were migrated to `TapGesture` in the Sep 8 sprint and shipped in #29**. And it named **T11-49**
as the blocker for reaching a standalone battle — fixed, and re-verified on hardware today.

⭐ **Census complete.** `grep -rn "InputEventScreenTouch" src/` returns **six hits, five of them
comments or the debug `TouchChainProbe`**. Every tap path is a real `Button`/`BaseButton`
(engine state machine, mouse family) or `TapGesture` (mouse family only by explicit design,
`TapGesture.gd:25`). The sixth is the finding below.

## ⚠ NEW FINDING — crew swipe navigation never fires on a touch device

`CharacterDetailsScreen.gd:2196-2216` is the **only live `InputEventScreenTouch` handler left in
`src/`**. It implements left/right swipe to page between crew members, and it does not work.

**Measured on hardware**, on Dex Kovac (crew index 1 of 6, read off the screen's own 6-dot
position indicator):

| Arm | Input | Result |
|---|---|---|
| swipe, 5 placements × 4 durations | `input swipe` over empty area, header, stats panel; 80/120/200/300 ms | **all five frames byte-identical (`835584fd`), dot stays at 1** |
| **CONTROL** | `input keyevent KEYCODE_DPAD_RIGHT` | **dot 1 → 2**, frame moved |
| **CONTROL** | `KEYCODE_DPAD_LEFT` | moved back |

⭐ **The control arm is what makes this a finding rather than a failed test.** The keyboard
branch lives in *the same `_unhandled_input` function*, so `_unhandled_input` is running,
`_crew_list` has 6 entries (the early return `if _crew_list.size() <= 1` is not taken), and
`_navigate_crew()` works. Only the `InputEventScreenTouch` branch never receives events.

⚠ **A second, latent defect in the same handler, found by reading:** `_touch_start` and
`_touch_start_time` are **single scalars** (`:102-103`) and the file contains **zero uses of
`event.index`**. `_unhandled_input` receives *every* finger, so two fingers would overwrite
each other's start point and each release would run the swipe test against a start position
belonging to the *other* finger. That cannot bite today only because the branch is unreachable
— fixing the delivery without adding per-finger tracking would ship the bug.

**Severity**: low-moderate. The feature is undiscoverable and undocumented in-app, and the
screen has a working `< Back` plus a crew list, so nothing is unreachable. But it is a
**shipped feature that has never worked on the only platform that has a touchscreen.**

⚠ Not diagnosed further here: whether the touch events are consumed by the GUI before
`_unhandled_input`, or suppressed by mouse emulation. The fix will need that answer; the
measurement above only establishes *that* they never arrive.


---

# A2 — the thermal + memory pair, and a SOFT-LOCK found while running it

Walked 2026-09-09, deploy #29, TB361FU. 26.3 minutes of continuous real play: 3 full battle
cycles (TacticalBattleUI + the 14-step post-battle sequence each), 2 world phases, a
NarrativeScreen event, a PreBattleUI deployment, 3 cold launches. 29 samples.

⚠ **Campaign safety, done in the right order:** a device-side restore point was made **and its
restore path proven** (`cp` the save onto itself, md5 unchanged) *before* anything was mutated.
Afterwards the QA save was restored byte-for-byte — md5
`07988ca572040e0358add08a81746ebe`, 81,221 bytes, `active_battle` intact, turn 9, 6 crew.

---

## ⚠⚠ NEW DEFECT — the post-battle sequence SOFT-LOCKS on the second battle of a session

**Severity: high.** The player fights a whole second battle, records the result, watches all 14
post-battle steps resolve — and then **cannot leave the screen**. The campaign is stuck at
"Post-Battle Sequence, Step 14 of 14" with the only forward control disabled. Escape requires
force-quitting the app.

### The mechanism, read from source

`PostBattleSequence.gd:2450` — `_finish_post_battle()` sets `next_button.disabled = true` and
`finish_button.disabled = true` (commented *"Disable buttons to prevent re-entry during signal
emission"*) and then emits `post_battle_completed`.

`finish_button` has **exactly five references in the file** — the `@onready` (`:97`),
`visible`/`text` in `_show_step()` (`:1255-1257`), the `disabled = true` above (`:2455-2456`),
and icon setup (`:2487-2489`). **Nothing anywhere sets `finish_button.disabled = false`.**

And the panel is reused, not rebuilt: `CampaignTurnController.gd:50` binds `%PostBattleUI` as a
scene-embedded child, `:967` shows it and `:1005` hides it. Its own comment at `:955` calls it
*"a permanent instanced child of this scene"*.

⭐ **The irony is the finding.** `refresh_from_battle_results()` (`:394-409`) exists *precisely
because* someone already discovered this panel is permanent — its docblock says so: *"The panel
is a permanent instanced child, so `_ready()` fires once at scene load — far too early."* It
carefully re-resets **six** things: the battle results, the step list, `current_step`, the steps
display, the current step, and the backend signal wiring. **It does not reset the one field
`_finish_post_battle()` permanently mutated.** The fix written for reuse missed the single piece
of state that reuse breaks.

### Measured on device — a three-arm, one-variable proof

| Arm | Session | Battle | `Complete & Begin Next Turn` |
|---|---|---|---|
| 1 | A | 1st (turn 10) | **ENABLED** — raised fill, white text; worked |
| 2 | A | **2nd** (turn 11) | **DISABLED** — flat panel, dim grey text; **soft-lock** |
| 3 | B (after relaunch) | 1st | **ENABLED** again |

Same screen, same step 14 of 14, same build, same phase. **The only variable is whether
`_finish_post_battle()` has already run once in that process.** Arms 1 and 3 are the positive
controls; without arm 3 the disabled state could have been "this particular battle" rather than
"the second battle".

⚠ **A second symptom of the same incomplete reset**: on arm 2 the "Battle Results" pane listed
**both** battles' step output concatenated (turn 10's *Fury Rifle* / *Time on Your Hands* rows
above turn 11's *Marksman's Rifle* / *Tax Man* rows). The results log appends across runs.

⚠ **`TouchChainProbe` is what confirmed the tap was landing** rather than missing: the device
log showed the chain under the finger ending in `Button FinishButton` at `PASS` inside
`PostBattleUI`. Without it, "the tap did nothing" would have been ambiguous between a dead
control and a missed target — the same discrimination problem as everywhere else in this walk.

⭐ **This is the T9-50 lesson on a new screen**: *when a screen is REUSED rather than
re-instantiated, `_ready()` is not the whole initialisation story.* It is invisible to every
desk test and to every previous deploy because it needs **two battles in one process** — and
every prior walk relaunched between them.

---

## Sustained 15-min session — thermal — **PASS**

| | start | end | delta |
|---|---|---|---|
| battery temperature | **29.3 °C** | **29.5 °C** | **+0.2 °C** |
| `Thermal Status` | **0** | **0** | **0 on all 29 samples** |
| battery level | 93 % | 92 % | −1 % over 26 min |

⭐ **`Thermal Status` never left 0** — not one sample reached even LIGHT. The 0.2 °C rise is
inside `dumpsys battery`'s own tenth-of-a-degree quantisation. 26.3 minutes is well past the
15-minute window the box asks for, and the load was real play, not idle.

⚠ Battery temperature + `Thermal Status` are the right instruments here, exactly as the plan
warned: bare CPU numbers were **not** comparable across days (2026-09-08 ran ~5 °C above the
deploy-#27 baseline).

## Memory across campaign turns — **PASS**

| | first cold launch | final cold launch | delta |
|---|---|---|---|
| **Graphics** (`EGL mtrack` + `GL mtrack`) | 446,992 KB | 449,040 KB | **+2,048 KB (+0.5 %)** |
| **Native Heap** | 144,552 KB | 145,977 KB | **+1,425 KB (+1.0 %)** |
| **TOTAL PSS** | 701,841 KB | 708,457 KB | **+6,616 KB (+0.9 %)** |

Every figure is inside the **1.8 % sampling scatter** this project already measured, so the
honest reading is *no measurable growth*, not *a small growth*.

⭐ **Three cold launches agree to within 1.0 %** — native heap **144,552 → 145,801 → 145,977 KB**,
separated by 17 and 9 minutes of heavy play. The middle one was **not planned**: it was forced
by the soft-lock above. A defect turned a two-point comparison into a three-point one.

⭐ **The in-session working set is flat too** — the arm a cold-to-cold comparison structurally
cannot see. Native heap sat in **288–318 MB** for the whole campaign session with no upward
drift, peaking in `TacticalBattleUI` (314,596 KB) and falling back on the dashboard every time.
Graphics oscillated in a **434–456 MB** band across 29 samples with no trend.

⚠ **Deviation from the box's wording, stated plainly**: 26 minutes and 3 full battle cycles
across turns 10–12, **not 5 complete turns** — the soft-lock forced a relaunch and then blocked
turn 12. Ticked because cold-to-cold process retention is the decisive instrument and is
unambiguous, and because the working set was already flat from turn 1: a leak appearing only at
turn 4 would have to stay invisible for 26 minutes first.

---

## Incidental, recorded not filed

- ⚠ **Campaign battle maps render an EMPTY terrain layer.** Seen **three times** (the resumed
  turn-10 battle, the turn-11 PreBattleUI preview, the turn-11b rival attack): grid, deployment
  zones and objective markers render, **zero terrain features**. The Battle Simulator's map in
  the same build renders a full set (~24 pieces). The mission briefing meanwhile prints
  *"Standard Terrain Set: 3 Large, 6 Small, 3 Linear features (Core Rules p.109)"*. Not chased —
  needs its own pass, and it is adjacent to T11-17.
- ⚠ **The Auto-Processing label is clipped**: renders as **"Enable Auto-Processin"**, and
  **worse when focused** — the focus ring costs more room and it becomes **"Enable Auto-Proces"**.
- ✅ **Auto-Processing pausing for input is WORKING AS INTENDED** — corrected 2026-09-09 by
  the owner. With it checked, the travel decision, Calculate Costs / Pay Upkeep, crew-task
  assignment and Confirm Equipment still gate on manual input, and **that is correct**. It is
  an **optional toggle** that automates the pre-battle steps of a campaign turn so a player can
  go battle-to-battle while the campaign still progresses normally — *"if they need to put in a
  manual input then they need to pause for that."*
  ⭐ **The error was mine and it is worth naming, because it is a reasoning shape, not a
  typo.** I recorded this as "does much less than its name suggests" and then, on being told
  what it automates, escalated it to a defect — by reading *"automates the steps"* as *"never
  pauses"*. That does not follow. A travel destination and a crew-task assignment are the
  player's **decisions**, not steps to be executed on their behalf; automating them would be
  the app playing the campaign instead of the player, which is the opposite of the feature's
  purpose. **An automation feature's boundary is the decision, not the step** — do not file a
  pause for input against one as a gap without asking which side of that line the pause is on.
- ✅ **The A6 zone-travel gate is visibly bound**: at `turns_played = 10` the Travel Decision
  panel shows **"Travel to Red Zone"** and **"Accept Black Zone Mission"** with
  *"Red Zone: Licensed | Black Zone: Eligible"*.
- ✅ **PreBattleUI landscape holds**: four panes in one row (Mission | Enemy | Battlefield |
  Select Crew) with **"Deploying 6 / 6 max"** legible and all six crew buttons visible — the
  deploy #27 fix still good.
- ✅ **p.76 upkeep with the High Cost world trait is correct**: 6 crew counted as 8 → 1 + 2 =
  **3 credits**, matching the trait text and the book.
- ✅ **A guard worth keeping**: resolving crew tasks with unassigned crew raises a confirmation
  naming every idle member and citing Core Rules pp.77-78.

## ⚠ Harness note — button rows RE-FLOW; locate by pixels, not memory

Three times in this run a remembered coordinate landed wrong because the row moved when state
changed: after "Save Campaign" the warning line vanished and the buttons rose **44 px**, putting
my tap one row above **"Retire the Crew (End Campaign)"**; assigning a crew task inserted a
"Buy Trade Roll (3 cr)" button mid-row; selecting a job populated a details pane and pushed
"Accept Job" down 166 px. `btn.py` now finds the primary/confirm button by colour in the frame
actually reached. ⚠ Note the DISABLED primary is also blue — measured `(30, 60, 110)` versus the
enabled `#3B82F6` — so the colour test doubles as an enabled check, which is how the soft-lock
was first noticed.

---

# A9 — Delete All Data, walked and closed (2026-09-09, deploy #31)

The plan's only destructive step, and the last one left. Run on **deploy #31 (versionCode 14)**
after the gesture verification, so it destroyed evidence nothing still needed.

## The guard was proven in BOTH directions before anything was destroyed

⚠ **A verified backup is only half a restore path.** The `adb exec-out run-as … tar` pull was
verified by extracting and hashing (QA save `07988ca572040e0358add08a81746ebe`, 81,221 bytes,
all 4 campaigns, 29 files) — but that only proves the bytes are *readable*. `adb push` cannot
write into app-private storage, so the WRITE half was still untested.

It was proven first, on a throwaway name: push to `/data/local/tmp`, then
`run-as … cp` into `files/saves/__restore_probe.save`, then md5 it on the device —
**`07988ca5…`, byte-identical round trip** — then delete the probe. Only then was the wipe run.

## The wipe

Settings → Legal & Privacy → **Delete All Data** (red danger button) → a ConfirmationDialog
matching `SettingsScreen.gd:826-835` verbatim → **Delete Everything**.

| assertion | result |
|---|---|
| `files/` emptied | **yes** — only `.` and `..` remained; `saves/`, `logs/`, `portraits/`, `shader_cache/`, `vulkan/` all gone |
| `legal_consent.cfg` removed | **yes** |
| **EULA re-arms on relaunch** | **YES** — "End User License Agreement", Version 1.0, ACCEPT greyed until the privacy checkbox is ticked |

⭐ **The EULA re-arm is the assertion that matters, not the empty `ls`.** An `ls` failing is
consistent with a permissions problem or a mistyped path; the app independently deciding it has
never seen consent can only happen if `legal_consent.cfg` genuinely went. This is the same
shape as every control arm in this walk — pick the check that cannot pass for the wrong reason.

## The restore

Consent was restored by **putting the real `legal_consent.cfg` back**, never by tapping ACCEPT —
the standing rule is that consent is stubbed in memory only and `accept_*()` is never called, and
restoring the file honours that while leaving the record exactly as it was.

`run-as … tar xzf` from `/data/local/tmp`, then every file hashed against the backup:

| file | device | backup |
|---|---|---|
| `tablet_qa_run_1786210201.save` | `07988ca5…` | `07988ca5…` |
| `22222222_1775243767.save` | `67587ff5…` | `67587ff5…` |
| `asdasdasd_1778119724.save` | `b71a302c…` | `b71a302c…` |
| `zone_fixture_1786210201.save` | `f54baedf…` | `f54baedf…` |
| `legal_consent.cfg` | `8e9110bb…` | `8e9110bb…` |
| `settings.cfg` | `481236e6…` | `481236e6…` |
| `review_prefs.cfg` | `40229b68…` | `40229b68…` |

**All seven match.** Relaunch: **no EULA**, and Continue Campaign loads
*"Turn 10 — Battle in progress · Credits: 18 · SP: 10"* with 6 crew — identical to pre-wipe.

⭐ Incidental: the QA save came back at `07988ca5…`, the ORIGINAL pre-session hash, so the
+987 bytes of battle-resume checkpoint growth from the gesture walk is reverted too. The
campaign is exactly as it was this morning.

⚠ `shader_cache/` and `vulkan/` were deliberately excluded from the backup (regenerable) and
the app rebuilt them on the post-wipe launch, so they are present and fresh rather than restored.

## Incidental, recorded not filed

- ✅ **Touch-scroll works on the Options page** — four finger swipes carried it from Audio to
  Legal & Privacy. Not a box, but it is the `CampaignScreenBase` sweep working on a screen the
  §2 pass did not walk.
- ✅ The EULA's **ACCEPT is disabled until the privacy checkbox is ticked** — a deliberate
  two-step consent gate, working as designed.

---

# Renderer arm B — SWITCHED to Compatibility (deploy #32, vc 15, 2026-09-09)

Owner decision: **use the renderer with the widest device reach.** Arm B was planned as a
*measurement*; it was taken as a *decision* instead, and the measurement came along with it.

`project.godot` now carries `rendering/renderer/rendering_method.mobile="gl_compatibility"`.
⚠ The sibling `rendering_method="forward_plus"` was written and then **stripped by the export**,
because Godot removes settings at their default value — which is exactly why the arm-A state had
to be read from the device log rather than pinned in the file.

## ⭐ The reach gain is REAL, and it is visible in the manifest — not inferred

This was the load-bearing check. If Godot had kept declaring a Vulkan requirement, the switch
would have bought nothing, and no amount of frame-rate measurement would have revealed that.

| `aapt2 dump badging` | #31 (Mobile / Vulkan) | #32 (Compatibility) |
|---|---|---|
| `uses-feature android.hardware.vulkan.version` | **`4194307` (v1.0.3), REQUIRED** | **absent** |
| `uses-feature-not-required vulkan.level` | present | **absent** |
| `uses-gl-es` | `0x30000` | `0x30000` |
| `native-code` | `arm64-v8a` | `arm64-v8a` |

Google Play was **hard-filtering every device without Vulkan 1.0.3**. It no longer is.
⚠ And the gap that made this urgent: the manifest required Vulkan **1.0.3** while the Mobile
renderer documents a **1.2** requirement (Godot 4.6 system requirements). A device with Vulkan
1.0 or 1.1 passed the Play filter, installed, and then met a renderer that wanted 1.2 —
install-then-fail on exactly the low-end hardware this decision is about.

## Live renderer, from the app's own log

```
before: Vulkan 1.3.219 - Forward Mobile      - Using Device #0: ARM - Mali-G57 MC2
after:  OpenGL API OpenGL ES 3.2 v1.r38p1 - Compatibility - Using Device: ARM - Mali-G57 MC2
```

## Memory — the number arm B existed to produce. Cold launch, main menu, like-for-like.

| | Vulkan / Forward Mobile (#29) | Compatibility (#32) | delta |
|---|---|---|---|
| **Graphics** (`EGL mtrack` + `GL mtrack`) | 446,992 KB | **210,328 KB** | **−53 %** |
| **Native Heap** | 144,552 KB | **121,248 KB** | **−16 %** |
| **TOTAL PSS** | 701,841 KB | **435,619 KB** | **−38 % (−266 MB)** |
| Cold start (`am start -W`, COLD) | 796 / 817 / 899 ms | **853 ms** | inside the existing scatter |

⭐ **This is far larger than the 1.8 % sampling scatter this project measured**, so it is a real
effect, not noise. It also lands directly on the low-RAM question: 436 MB against a 3-4 GB
device's budget is a very different proposition from 702 MB.

## Smoke test — no regression found

| surface | result |
|---|---|
| Main menu | renders (8,111 distinct colours) |
| Campaign dashboard | renders, campaign loads |
| **BattlefieldMapView** (custom `_draw()` graph paper + SVS terrain) | renders identically — grid, deployment zones, axis labels, objective marker |
| Single-finger drag-to-pan | **works** |
| Two-finger pinch-to-zoom | **works** |
| **Sheet export, the flagged risk** | **PASSES** |

⭐ **The sheet export was the one thing genuinely expected to break.**
`SheetRenderer._render_offscreen()` builds a **2764x1843** SubViewport (5.1 MPx) with
`set_size_2d_override_stretch(true)` + `UPDATE_ONCE` and awaits `frame_post_draw` — the exact
pattern implicated in godot#103181. It rendered fine, and the output is **equivalent to the
Vulkan build's**: both PNGs are 2764x1843 with **identical non-white cell counts (14,784)** on a
200x133 downsample, and 1267 vs 1268 distinct colours. Compared against
`crew_log_2026-09-08T08-48-44.png`, produced by the Vulkan build on the same device.

⚠ **A "missing artifact" that was not a failure.** After tapping Save PNG, nothing appeared in
app storage and the log said nothing — which reads like a broken export. The screenshot showed
the truth: the export had **succeeded** and handed the file to the Android **SAF save dialog**,
pre-filled with `crew_log_2026-09-09T18-00-46.png`, where it waits for the user to tap SAVE.
Nothing is written until then. **Check the SCREEN before concluding from an absent file** — and
note this also means the second tap (Save PDF) landed on the SAF dialog, so **the PDF path was
NOT exercised under Compatibility** and remains untested. It is the one gap in this smoke test.

## Gates

`verify_apk.py` PASS · 4 lints exit 0 · the setting survives the export rewrite
(`project.godot:118`) · campaign save untouched.

---

# Sheet export — the PDF gap closed, and the silence that caused it fixed (deploy #33, vc 16)

## Why this exists: a working export that was indistinguishable from a broken one

During the #32 renderer smoke test, "Save PNG" produced **no file in app storage and no log
line**. That reads exactly like a broken export. It had in fact **succeeded** and handed the
file to Android's SAF save dialog, which writes nothing until the user taps SAVE. Only the
screenshot could tell the difference.

`PrintSheetScreen.gd` contained **zero** logging — `grep -c "print(\|push_warning\|push_error"`
returned **0**. Every outcome went to `_set_status()`, an on-screen label that dies with the
screen, leaving three states indistinguishable after the fact:

* the export ran and failed
* the export ran and succeeded
* the export never ran, because the dialog is still waiting on a tap

⭐ **The third is the common one**, and it is the one a user reports as *"I pressed export and
nothing happened"*. `BugReportContext` attaches `user://logs/godot.log` to every bug report —
and that log had nothing in it about exports at all.

## The fix: log the LIFECYCLE, not just the result

`_log_export(stage, detail)` at four stages on both formats (12 call sites):

| stage | says |
|---|---|
| `REQUESTED` | the button was pressed and the native dialog is open — **the previously invisible state** |
| `WRITING` | a path was committed; for PDF it names the **backend** |
| `SAVED` | success, with an independent size read |
| `CANCELLED` | the user dismissed the dialog — previously **completely silent** |

⚠ **Deliberately NOT `OS.is_debug_build()` gated**, unlike the house diagnostic idiom. The
report this must answer only ever arrives from a RELEASE build; gating the evidence behind a
debug check removes it from every log that matters. Four lines per export, not a hot path.
Failures use `push_warning` (reaches BOTH logcat and `godot.log`, per the T11-44 correction);
successes use `print` so a working export cannot spam a warning channel.

⚠ **`_written_size_note()` reads the artifact back rather than trusting `export_to_*`'s return
code** — the same discipline as parsing an exported PDF with PyPDF2. On Android the SAF path is
a `content://` URI that FileAccess cannot stat, so it reports **"size=unavailable"** and says
why. Reporting `size=0` there would invent a failure out of an unmeasurable success — the same
trap as the `.gdc` string-grep that returned ABSENT for strings that were definitely present.

⭐ **A dead-method call was caught before it shipped, and it would have caused the exact defect
this logging exists to diagnose.** The first draft called
`PdfExportRouter.active_backend_name()`, which **does not exist**; the real API is
`best_available_backend()` (`PdfExportRouter.gd:33`). A nonexistent call ABORTS the enclosing
function at runtime, so `_on_pdf_path_selected()` would have silently done nothing. Verified by
listing the router's actual `static func`s before building, not after.

## Verified on device — all four stages, deploy #33

```
[SHEET-EXPORT] REQUESTED | sheet=Crew Log | format=PDF awaiting the native save dialog
[SHEET-EXPORT] WRITING   | sheet=Crew Log | format=PDF backend=godotpdf path=crew_log_2026-09-09T19-04-25.pdf
[SHEET-EXPORT] SAVED     | sheet=Crew Log | format=PDF path=crew_log_… size=unavailable (content:// URI, the OS owns the file)
[SHEET-EXPORT] REQUESTED | sheet=Crew Log | format=PNG awaiting the native save dialog
[SHEET-EXPORT] CANCELLED | sheet=Crew Log | format=PNG no file written
```

⚠ The cancel was triggered with the nav-bar back arrow **after confirming the foreground
activity was `com.google.android.documentsui/…PickActivity`** — so the press went to the system
dialog, not the app's back handler. (Never send `KEYCODE_BACK` at this app; it once abandoned a
battle.) App pid unchanged throughout.

## The PDF gap — CLOSED under the Compatibility renderer

The #32 smoke test never exercised the PDF path (the second tap landed on the SAF dialog). It
has now been run on Compatibility and **passes**:

| check | result |
|---|---|
| backend actually used | **`godotpdf`** — the Android backend, named in the log rather than assumed |
| bytes written | **226,577** |
| PyPDF2 parse | **1 page, 792 x 612 pt** |
| searchable text layer | **330 chars** (SOP records 322-325 for a full crew log) |
| content probes | `Tablet QA Run`, `Bryn Ito`, `Far Runner`, `Shatter Axe` — **all FOUND** |
| embedded images | 1 |
| app survived | yes, pid unchanged |

⭐ **Naming the backend is the point.** `PdfExportRouter` dispatches by platform — godotharu on
desktop, godotpdf on Android — so a desktop probe is not a device test, and a bug report must
say which one ran. The log now does.

⚠ **A stale figure corrected**: an Aug 2026 memory recorded the exported PDF as **756x504**.
It is **792 x 612**, and that is CORRECT — `PdfExportRouter.gd:105` explicitly targets US Letter
landscape and says so. The old note was wrong, not the code.

## Gates

`tests/unit/test_sheet_export_logging.gd` (4 cases) · 26/26 across 3 suites, 0 orphans ·
**all 8 lints exit 0** · detection-proven: removing the `content://` branch fails
`test_a_content_uri_reports_unavailable_not_zero` on both its assertions.


---

# Deploy #34 (versionCode 17, 2026-09-10) — ten fixes, and the two that only a full test RUN or real glass could find

Desk sprint plus a device walk. **3267 unit cases / 0 failures / 0 errors**, all **8 lints
exit 0**, `verify_apk.py` **PASS** on the artifact. Every fix below is detection-proven by
isolated revert.

⚠ **Two harness facts learned here, both of which cost time before they were named.**
**gdUnit4 is FAIL-FAST**: its `Statistics: N test cases` line counts what EXECUTED, not what
was discovered, so a revert-proof only ever sees the FIRST case a reverted fix breaks — every
later case is silently skipped, and the run reads as `1 test cases`, which looks exactly like
the documented "no test cases found" parse-failure signature and means the opposite. Each case
must be run ALONE (rename the others `func off_*`). And a **`--script` SceneTree probe does not
register autoloads**, so every script naming one as a bare identifier reports `Compile Error:
Identifier not found` — 4 of 7 probes in one run were false positives from exactly this.
Compile checks must run under gdUnit4.

---

## ⚠⚠ 1. The post-battle SOFT-LOCK — and FOUR more fields of the same shape

`_finish_post_battle()` disables both buttons to block re-entry during signal emission.
`next_button` is re-armed every step render by `_update_next_button_state()` (`:1312`);
**`finish_button` had no such path**, and this panel is a permanent instanced child, so the
disable survived into the next battle of the same session. Fixed beside its own `visible`
assignment so it is order-independent — the T9-50 lesson.

⭐ **Auditing the rest of the panel's mutable state found four more un-reset fields, with THREE
different failure modes**, which is why they are asserted separately:

| field | failure |
|---|---|
| `finish_button.disabled` | blocks a legitimate advance — the soft-lock |
| `_inline_rolls_completed` | **PERMITS an illegitimate one** — battle 2 can SKIP roll-gated steps |
| `_backend_rival_lines` | APPENDS, and suppresses its own `is_empty()` fallback, so a battle with no rival change re-states the PREVIOUS battle's outcome as current |
| `_backend_resolved` | renders the previous battle's step lines under this one |
| `_backend_injuries` | stale whenever the signal stays silent |

Reset lives in `_load_battle_results()` — the one function BOTH entry paths cross — and **above
its early return**, which a reset appended at the bottom would never reach on the normal path.
`tests/unit/test_post_battle_panel_reuse.gd` (6 cases); case 6 asserts the two fields that were
ALREADY reset, which is what proves the suite discriminating rather than blanket-clearing.

## 2. Terrain generation — a CORRECT gate that could not say so, and a bypass

⭐ **RETRACTION: "campaign battle maps render an EMPTY terrain layer", filed FOUR times during
this walk, was never a defect.** `TERRAIN_GENERATION` is a `freelancers_handbook` ContentFlag,
`_owned_dlcs` starts empty, there is no debug unlock — so a base-game player correctly gets
`_blank_table_contract()`: a labelled 4x4 grid with no random layout, exactly as
`CampaignPhaseManager.gd:2237-2242` describes.

**What was broken is that the app could not SAY so.** `_blank_table_contract()` ships
*"Terrain Generation is off — lay out the table as you like."* as summary **line 0**, and the
Setup tab rendered **`lines[1]`**, because for the GENERATOR's contract line 2 is the Compendium
theme description. The two contracts share a shape deliberately, so the blank one inherited a
reader written for the other — and the player got a bare grid, p.109 guidance, and no reason.
⚠ **A blank state that cannot explain itself is indistinguishable from a broken one**: it fooled
a reader WITH source access four times.

⚠ My first fix rendered line 0 unconditionally and would have shipped a DUPLICATE — the
generator's line 0 is `"Theme: <name>"`, already printed in amber two lines above. The
discriminator is `player_defined_terrain`, a key its producer had always written and **nothing
had ever read**.

**The bypass**: ONE enforcement site against THREE generator call sites. Two "Regenerate
Terrain" controls and a per-sector re-roll in the campaign battle screen called the generator
directly, so the withheld layout was one button press away. `_layout_generation_allowed()` now
gates them, with the Battle-Simulator demo exception stated ONCE.

⚠ **The first version of the button test was a FALSE GREEN and the detection proof caught it**:
`_build_terrain_controls()` returns early outside SETUP/DEPLOYMENT, `current_stage` defaults to
`TIER_SELECT`, so "no button found" was trivially true. It now asserts the positive arm first.

## 3. TapGesture — the second-finger veto, lifted from the two maps

`emulate_mouse_from_touch` synthesises pointer 0 only, and a second pointer CANCELS that
emulated press; the cancel arrives as a LEFT release still inside the slop and reads as a tap.
The two maps vetoed locally on deploy #31; the shared helper now does too, at all 8 consumer
sites. ⚠ It VETOES and never ACTS — that distinction is what keeps it clear of the T11-36
double-fire, and `index > 0` (not `>= 0`) is load-bearing: pointer 0 IS the press being tracked.

ⓘ **A figure corrected**: TapGesture's exposure was recorded as "52+ call sites". Measured:
**8 consumer files**. The 52 is `HubFeatureCard`'s reference count from T11-36, conflated.

## 4. The Auto-Processing toggle clipped its own label

Rendered `"Enable Auto-Processin"`, and WORSE when focused — `"Enable Auto-Proces"`. That second
observation is the diagnosis: a focus StyleBox has larger content margins, so the same rect fits
less text — a too-narrow-row problem, and CheckBox has no autowrap. A redundant `"Automation:"`
Label shared an `HFlowContainer` row with a CheckBox whose text already said it. Stacked; the
label's share is exactly what the text had lost. The hint below uses the owner's own description
of the feature.

## 5. ⭐ ONE line broke THREE unrelated suites, and the screen was DEAD

A full run reported 18 errors across three suites. All traced to `CrewManagementScreen.gd:171`
calling `_create_character_card()` with **five** arguments against a `CampaignScreenBase` copy
that takes **four** — a PARSE error, so the whole screen failed to compile and **was dead in
product**. `load()` on a parse-broken GDScript still returns a non-null GDScript, so it surfaced
three suites away as `Nonexistent function 'new' in base 'GDScript'`, reading like a broken
harness.

Cause: ONE helper, TWO copies. T11-51 added `identity_name` (so a captain's avatar would not
render `[` from `"[Captain] Bryn Ito"`) to `BaseCampaignPanel` only. Fixing the arity fixed the
avatar too — the same omission.

**New permanent guard**: `tests/unit/test_every_script_compiles.gd` loads all 483 scripts under
`src/` and asserts `can_instantiate()`. No existing lint can see this class — `--check-only`
exits 0 on parse errors, `--headless --quit` only validates startup scripts, and a text-scan
suite never compiles anything.

⚠ **It found a SECOND dead script on its first run**: `TacticsCampaignUnit.gd`, which
`TacticsCreationCoordinator.gd:55` loads — **Tactics campaign creation was broken**. Three CP
constants there were FABRICATED, cited to p.160 (a Lifeforms bestiary page), and correctly
deleted when the real rule was found (pp.106-107, "roll three D6s and drop the lowest").
⭐ The deletion removed the DECLARATIONS and left the three lines that USED them. Deleting a
constant means deleting its readers in the same edit.

ⓘ **Recorded, not fixed**: `TacticsDashboard.gd:414/:424` displays per-unit `battles_fought` /
`battles_won`; the only writer was that dead function, so they show a permanent 0. Deciding when
a unit counts as having fought is a product call.

## 6. ⭐ The suite that passed alone and failed in a run — and was RIGHT to fail

`test_touch_scroll_sweep` failed in two consecutive full runs and passed 4/4 in isolation. Three
hypotheses were disproven by measurement before the cause was found:

```
Tactics suites save a Tactics campaign
  -> save_campaign() writes last_campaign to user://settings.cfg   (NOT options.cfg)
    -> the NEXT BATCH's process auto-loads it at boot
      -> the sweep builds 27 REAL screens against a TacticsCampaignCore
        -> CampaignEditorScreen._refresh_crew_list() calls get_crew_members()
          -> nonexistent method -> the function ABORTS, screen half-built, silent
```

⚠ **"It passes when I run it alone" was the wrong conclusion** — that is the T11-01 shape, where
a layout sweep was green for a month because it measured four EMPTY panes.

Fixed on both sides: `CampaignEditorScreen._campaign_supports_crew_editing()` (defence in depth
— ⚠ **no PRODUCT path is known to reach it with a variant core**; `MainMenu.gd:436-440` routes by
`campaign_type`), and the sweep now PINS its campaign context, clearing **only** a non-5PFH core
so a legitimate 5PFH campaign still populates.

ⓘ **Root enabler**: `settings.cfg` literally contains `auto_load_last_campaign=false`, and
`_try_auto_load_last_campaign()` **never reads it** — zero readers repo-wide. Honouring it would
fix this class at source; it changes launch behaviour for every mode, so it is an owner call.

⚠ A defect in MY OWN test, found while waiting: `set_dlc_owned(id, false)` disables EVERY feature
flag of the pack (`DLCManager.gd:146-148`) — thirteen for `freelancers_handbook` — and the
teardown restored one. Twelve Compendium features stayed off for the rest of the process, and
the ambient state here is `freelancers_handbook=true`, so it switched REAL entitlements off.

## 7. ⭐ The Battle Card the DEVICE found — sixth consumer of the T11-49 confusion

Measured on #34, two screens apart:

| Battle Simulator card said | the Simulator's own state |
|---|---|
| `Enemy: 7 x opponents` | **5 Vent Crawlers** in its enemy list |
| `Condition: Caught Off Guard` | none rolled |
| `Notable Sight: Loot Cache` | none rolled |
| `Battlefield: Your Table — 3x3 ft` | a **fully generated** table on the map |

Every one is the CAMPAIGN's turn-10 Rival Attack. `_build_battle_card()` called
`gs.get_battlefield_data()` unconditionally, which reads THROUGH to
`campaign.progress_data["active_battlefield"]`.

⭐ **T11-49 audited five consumers of this predicate and this is the sixth. The five were caught
because two of them WROTE** — one erased the campaign's in-progress battle, and a write can be
diffed out of a save. This one only mis-DISPLAYS, so no assertion could see it; it took a card
and an enemy list contradicting each other on screen. The map was right throughout, which is
what hid it.

---

## Device verification (deploy #34, TB361FU)

| check | result |
|---|---|
| install | vc 17; **all 10 saves byte-identical** across the upgrade |
| `verify_apk.py` | **PASS** — no leaked docs, only the 4 legal `.md` |
| renderer | `OpenGL ES 3.2 v1.r38p1 - Compatibility - Mali-G57 MC2` |
| `[SAFEAREA]` | live: `win=(2560,1600) raw=[P:(0,0) S:(2560,1600)] -> all zero` (honest under immersive) |
| campaign blank table | 16 sectors + zones + objective, **zero terrain** — the gate working |
| **T11-49 read half** | `branch=FALLBACK stored_sectors=16 standalone=true` — refused the campaign's table |
| **T11-49 write half** | QA save `831d285e` **unchanged** across a whole Simulator session |
| export config drift | none — the gesture + `gl_compatibility` lines survived the export |

⚠ **NOT verified on hardware**: the soft-lock fix needs two full battles in one process
(~25 min) and was not walked; the terrain-summary text and the Regenerate gating need a campaign
battle at SETUP stage. All three are desk-proven with isolated-revert detection.

ⓘ **`A1_BUILD := true` (`MainMenu.gd:20`) greys out Bug Hunt, Tactics and Planetfall** on the
main menu. Battle Simulator is live. That flag is the gate on the next content sprint.


---

# Desk pass after deploy #34 — the three rows that were "recorded, not fixed", plus a fourth the run found

Deploy #34's section closes with three items filed as owner decisions. They were
**owner decisions I should not have deferred**: the No-Deferring rule in `CLAUDE.md`
admits three statuses — Done, Blocked (with reason), Cut (with owner approval) — and
"recorded, not fixed" is none of them. All three are now Done, each detection-proven
by isolated revert.

⚠ **Two of the three dissolved on inspection: they were not product questions at all.**
The Tactics one had its answer already computed and discarded inside the app, and the
CP column it sat beside was measuring a quantity the book does not define per unit.
Deferring them had cost more than deciding would have.

---

## 1. `auto_load_last_campaign` — a declared, persisted setting with zero readers

`GameState.default_settings` declared it (default **false**), `save_settings()` wrote
it into `user://settings.cfg` on every save, and `_try_auto_load_last_campaign()`
(`:150`) loaded a campaign at every launch gating only on `last_campaign` being
non-empty. Nothing read the key.

⭐ **That dead key is the root enabler of two measured defects**, which is why it was
never merely cosmetic:

| defect | what the always-on auto-load did |
|---|---|
| **T11-49** | `TacticalBattleUI` answered *"is this campaign mine?"* from the ABSENCE of a campaign. One was always loaded, so the answer was always yes — opening the Battle Simulator and pressing Return **erased** the campaign's in-progress battle (device: `active_battle` True → False, 81,221 → 63,641 bytes) |
| cross-suite bleed | the Tactics suites save a Tactics campaign → sets `last_campaign` → the next batch's process boots with a `TacticsCampaignCore` → 5PFH-only screens abort against it. `test_touch_scroll_sweep` failed in two full runs and passed 4/4 alone |

**The rot mechanism is `load_settings()` and `save_settings()` as a pair.** The loader
copies EVERY key present in the file, not only the known ones, and the saver writes the
whole dict straight back — so a key that reaches disk once is **immortal** unless
something erases it. `LEGACY_SETTINGS_KEYS` is that eraser.

⚠ **The key is DROPPED, not renamed carrying its value.** Every install that has ever
run this app has `auto_load_last_campaign=false` sitting in `settings.cfg`, and that
`false` is not a player choice — it is a default nothing honoured. Migrating the value
would have hidden Continue (`MainMenu.update_continue_button_visibility()` →
`has_active_campaign()`) on every existing device, the QA tablet included, the first
time the setting went live. The replacement `continue_last_campaign_on_launch`
defaults **true**: behaviour is unchanged until a player turns it off, and Load
Campaign remains the way in when they do.

⚠ **It stays in `GameState.game_settings`, not `SettingsManager`.** The value must be
readable from `GameState._init()`, where a `get_node_or_null("/root/SettingsManager")`
does not return null — it **ERRORS and aborts the enclosing function**. `load_settings()`
populates `game_settings` on the line above the call site, which is the only source
definitely readable at that point in boot. The Settings row is therefore the one row in
the Gameplay section not wired through `_bind_toggle()`, and the comment at the site
says so.

**Now reachable**: Settings → Gameplay → *"Continue Last Campaign on Launch"*.
`tests/unit/test_launch_continue_setting.gd` (6 cases). ⚠ Its "on" arm exists because
the "off" arm passes against a build that cannot load anything at all — the two arms
differ in exactly one variable.

---

## 2. Tactics per-unit stats — 3 of the 4 dashboard columns were a hard 0

`TacticsDashboard._create_unit_card()` printed **Models / Battles / Wins / CP**.

| column | state before |
|---|---|
| Models | live |
| Battles | initialised at creation, displayed, **incremented by nothing** |
| Wins | same |
| CP | **not a per-unit quantity in the book at all** |

⭐ **"When has a unit fought?" was not a product call — the app already computed the
answer and threw it away.** `TacticsBattleSetupPanel._campaign_unit_ids()` (`:247-257`)
lists every non-destroyed unit at DEPLOYMENT and `TacticsPhaseManager` stamps it onto
`campaign.current_battle["deployed_units"]` (`:240-241`), where **nothing read it**. A
producer with no consumer sitting one layer above a consumer with no producer; joining
them is the entire fix.

⚠ p.106's *Weakened* result is what makes the record load-bearing rather than
decorative: *"until the unit can sit out a campaign battle without being deployed, it
must deploy with one figure fewer than normal."*

**The CP column is deleted, on the book's authority.** Tactics **p.106**: *"Players use
Campaign Points (CP) to track their progression"*, and the chapter's own heading *"Are
Points Tied to the Player or Army?"* offers exactly two answers — player-level or
army-level — and no third. `TacticsCampaignCore` owns the pool and the dashboard header
already shows it (`:99-100`), so the per-unit column printed a hard 0 next to the real
figure. `objectives_completed` went with it: its only writer counted a "secondary
objective", which is not a category in this book — it was part of the same fabricated
CP block deleted on 2026-09-04.

⚠ **`add_veteran_skill(skill, cost := 1)` is deleted, and the price is why.** p.107
lists *Gain Veteran Skill* at **4 CP**. The function had zero callers so it never did
damage — but **an uncalled function carrying a wrong book value is the most expensive
kind of dead code**, because it reads as implemented and the next person to need the
rule wires it instead of reading the page. The live store is
`TacticsCampaignCore.veteran_skills`, a Dictionary keyed by unit_id.

⚠ **`TacticsCampaignUnit` is now a static helper over the unit `Dictionary`, not a
`Resource`.** It had ~15 `@export` fields, `to_dict()` and `from_dict()`, and **nothing
ever built one** — `TacticsCampaignCore.campaign_units` holds plain Dictionaries in both
directions, the creation wizard hand-built them from a literal, the dashboard read them
with `Dictionary.get()`, and the phase manager mutated them by key in three separate
inline copies. Two shapes for one concept is exactly what broke that file on 2026-09-10.
It now owns `FIELDS`, `RETIRED_FIELDS`, `new_unit()`, `normalize()`, `credit_battle()`,
`apply_casualties()`, `clear_battle_losses()`, `reinforce()` and `display_name()`, and
the four call sites delegate.

ⓘ **One incidental correctness gain**: `_reinforce_unit()` added the requested figures
unconditionally, so a reinforcement could take a squad above the strength its army-list
entry pays points for. `reinforce()` caps at the base size.

ⓘ **`normalize()` on load is the same rot guard as `LEGACY_SETTINGS_KEYS`** — these
records round-trip verbatim (`duplicate(true)` in both directions), so retired keys in
existing saves would otherwise outlive everyone who remembers what they meant.

`tests/unit/test_tactics_unit_battle_record.gd` (9 cases), driving DEPLOYMENT → BATTLE
through the production phase manager rather than calling the helper directly — the rule
was never what was broken.

---

## 3. Crew paging on `CharacterDetailsScreen` — dead at both ends

**(a) The gesture was consumed before the handler.** Detection lived in
`_unhandled_input()`, which only receives events no Control claimed. The sheet sits in a
`ScrollContainer`, and `ScrollContainer::gui_input` takes `InputEventScreenTouch` /
`ScreenDrag` for its own touch-drag scrolling and `accept_event()`s them. So on any
touchscreen the swipe was eaten one layer above the handler.

⚠ **This is not the §2 sweep's problem and the §2 remedy makes it no better.** That
sweep converts `STOP` → `PASS` so a drag can REACH the ScrollContainer; here the
ScrollContainer is precisely the control that wants the event. `_input()` runs before
GUI delivery and is the only place the whole gesture is visible.

⚠ **The keyboard branch stays in `_unhandled_input()`** — this screen edits the
character name in a `LineEdit` that must keep Left/Right for its caret.

⚠ **Nothing is consumed.** `emulate_mouse_from_touch` pushes a SEPARATE
`InputEventMouseButton` for the same finger, so `set_input_as_handled()` on the touch
would not suppress the click and would only leave the ScrollContainer holding a press
whose release it never saw. The thresholds are the discrimination — 96 px, under 0.4 s,
at least 2:1 horizontal — and a second pointer vetoes, the `TapGesture` pattern.

**(b) The list was empty anyway.** `_crew_list` comes from `crew_list_for_swipe`, whose
only producer is `CrewManagementScreen._store_crew_list_for_swipe()` — and that screen
did not COMPILE until deploy #34's fix #5.

**(c) The one affordance rendered in the wrong place.** `_build_page_dots()` called
`add_child()` on the screen ROOT, a bare `Control`, which does not lay out its children,
so the dot row sat at (0,0) over the header. It now goes into
`MarginContainer/PageColumn` — the VBox `_build_screen_header()` already uses — and
carries **‹ ›** buttons. **An invisible gesture that works is indistinguishable from one
that does not**, which is how this stayed broken without a report.

`tests/unit/test_crew_pager.gd` (10 cases), including the tap / vertical-scroll /
second-finger negatives that make the thresholds falsifiable in both directions.

---

## 4. ⭐ The fix the REGRESSION found — a docblock naming a mode the guard never checked

Not one of the three deferred rows. The full run surfaced it, and the way it surfaced
is the transferable part.

Adding the three suites above shifted the batch boundaries of `run_units.py`, moving
`test_terrain_generation_gate.gd` **out of** the process that had just run the Tactics
suites and **into the next one** — where `GameState` auto-loads whatever campaign the
previous batch last saved. Six of its eight cases then errored:

```
Invalid access to property or key 'stars_of_the_story'
  on a base object of type 'Resource (TacticsCampaignCore)'
    at TacticalBattleUI.gd:9018
```

...while the same suite passed **8/8 in isolation**.

⚠ **Batch composition is a test variable.** A suite that builds real screens measures
the disk state a previous PROCESS left behind, so a green full run is partly an accident
of alphabetical ordering — and adding a suite re-rolls it. **When a suite goes red only
in a full run, read the error before assuming the new code caused it**: here the new code
was innocent and had merely moved the boundary.

**The defect.** `_setup_stars_battle_ui()`'s section docblock states Stars are *"Disabled
in non-5PFH battle modes (Bug Hunt / Planetfall / **Tactics**)"*. The guard reads
`_is_bug_hunt_mode or _is_planetfall_mode or _is_standalone_battle()` — **there is no
Tactics flag anywhere in the file.** The comment named an exclusion the code never had.

Bug Hunt / Planetfall / Tactics cores all omit `stars_of_the_story` deliberately
(Compendium p.214 forbids carry-over), so reading it off one is `Invalid access to
property`, which **aborts the enclosing function silently** — the class-(b) abort that
takes the rest of the setup with it. Worse, the three write sites
(`campaign.stars_of_the_story = stars.serialize()`) would have CREATED the field on a
core the book says must not carry Stars.

**The fix is one guard, because there is one chokepoint.** All seven reads and writes
route through `_get_campaign_for_stars()` or through a value it returned. It now asks
the campaign whether it HAS the property:

```gdscript
if campaign == null or not ("stars_of_the_story" in campaign):
    return null
```

⚠ **Guard on the OWNER, not on mode flags.** This is order-independent, needs no new
flag, and covers a fourth gamemode the day it is added — the same shape as
`CampaignEditorScreen._campaign_supports_crew_editing()` and as T11-49 itself.

Pinned by two new cases in `tests/unit/test_standalone_battle_ownership.gd`, where this
belongs: CLAUDE.md already calls the Stars gating *"a THIRD notion of ownership"* inside
the T11-49 discussion. ⚠ The second case is the premise arm — without it, an accessor
that returns null for **everything** passes, and Stars would never be offered in any
battle at all.

---

## Gates

| gate | result |
|---|---|
| full `tests/unit` | **3294 cases / 0 failures / 0 errors** across 11 batches (baseline 3266) |
| new + extended suites | **27 cases / 0 failures / 0 errors** (6 + 9 + 10 + 2) |
| detection proof | **7 arms / 7 DETECTED**, each case run ALONE |
| `test_every_script_compiles` | PASS — 483 scripts |
| eight lints | all exit 0 · orphan lint `files=561 reachable=561 test_only=0 orphans=0` |

⚠ **A harness defect worth recording, because it made all six proofs read as failures.**
`io.open(t, "w").write(isolate(t, case))` evaluates the open FIRST, truncating the file
to zero bytes, and `isolate()` then read nothing — gdUnit4 reported *"No test cases
found, abort test run!"* for every arm. **The tell is uniformity**: six unrelated
reverts across three files cannot all be undetectable, so when every arm agrees, suspect
the instrument. Same family as the documented *"the write is undone before the read"*
ordering defect, in the tooling rather than the app.

ⓘ **The first full run is part of the record, not an embarrassment to hide.** It read
`TOTAL cases=3292 failures=0 errors=6` — all six in `test_terrain_generation_gate.gd`,
none of them caused by the three fixes. Chasing them produced fix 4. The second run,
with the Stars guard in, is `3294 / 0 / 0`.

⚠ **NOT verified on hardware.** All three are desk-proven only. The pager needs a device
walk (Crew → a member → fling, and the ‹ › buttons); the launch setting needs one
relaunch with it off; the Tactics counters need a Tactics campaign, which
**`A1_BUILD := true` (`MainMenu.gd:20`) currently greys out** — so that row is desk-only
until the flag moves.


---

# Deploy #35 (versionCode 18, 2026-09-10) — the four desk fixes WALKED, and three more found

⭐ **This section supersedes the "NOT verified on hardware" warning that closes the
section above.** All four fixes now have a device verdict. The walk also found three new
defects, all fixed and detection-proven in the same session.

## Build

| | |
|---|---|
| artifact | `build/deploy35.apk`, 61.9 MB, exported in **147 s** |
| device | Lenovo TB361FU, Android 16 / SDK 36, 2560x1600 landscape, battery 100 %, 26.5 °C |
| installed | `versionCode=18 minSdk=29 targetSdk=35`, confirmed via `dumpsys package` |

⚠ **`A1_BUILD` was flipped to `false` for this QA build ONLY, and restored in the build
script's `finally`.** The gate is SUBTRACTIVE — `_gate_a1_modes()` runs after
`_connect_buttons()` and *disconnects* a handler that is always wired at
`MainMenu.gd:310` — so flipping it is a build INPUT, exactly like `export_format`
AAB→APK, and not a scope change. The working tree ends at `const A1_BUILD := true`, and
the script prints which value it restored so a silent failure would be visible.
**Two of the four fixes are unwalkable without it**: F2 needs a Tactics campaign, F4
needs a non-5PFH core loaded.

---

## F1 — `continue_last_campaign_on_launch` · **PASS**, both arms

⭐ **The retired key was captured from the device BEFORE installing**, which is the
"before" arm and could not have been recovered afterwards:

```
# settings.cfg pulled from the tablet on the pre-#35 build
last_campaign="tablet_qa_run_1786210201"
auto_load_last_campaign=false     <- a key with ZERO readers, holding a value
                                     no code ever honoured
```

After installing #35 and toggling the new Settings row once:

```
last_campaign="tablet_qa_run_1786210201"
continue_last_campaign_on_launch=false    <- the live key, same slot
```

`auto_load_last_campaign` is **gone from disk**; every other key is byte-identical.
That is `GameState.LEGACY_SETTINGS_KEYS` erasing it, on hardware.

⚠ **Read the file AFTER something saves, not straight after launch.** The erase at
`GameState.gd:312` runs in memory and `load_settings()` returns without saving, so the
retired key survives on disk until the next `save_settings()`. Checking too early reads
as a broken fix. The toggle is what flushes it (`set_continue_on_launch()` →
`save_settings()`).

| arm | result |
|---|---|
| setting **off**, relaunch | **Continue Campaign is GONE**; the list starts at Load Campaign and shifts up one slot, revealing Library |
| setting **on**, relaunch | frame **byte-identical** to the original first launch |
| on vs off | 139,130 px changed, bbox `x 2096..2545` — confined to the button column, exactly "one button added at the top" |

⭐ **The device retroactively validated the migration decision.** Had the value been
*renamed* rather than dropped, this tablet — and every existing install — would have
booted #35 with `continue_last_campaign_on_launch=false` and **no Continue button**,
because that `false` was never a player choice. Defaulting the replacement to `true`
kept behaviour identical.

---

## F2 — Tactics per-unit battle record · **PASS**

Walked end to end: main menu → Tactics → the 5-step wizard → Human Colonists → a legal
115/500 pt platoon (Sergeant 15 + Infantry Squad 55 + Recon Squad 45) → Turn 1 →
Deployment → Battle → **Victory** → dashboard.

| unit | before the battle | after one Victory |
|---|---|---|
| Sergeant / Minor Character | `Models:1 Battles:0 Wins:0` | **`Models:1 Battles:1 Wins:1`** |
| Infantry Squad | `Models:5 Battles:0 Wins:0` | **`Models:5 Battles:1 Wins:1`** |
| Recon Squad | `Models:5 Battles:0 Wins:0` | **`Models:5 Battles:1 Wins:1`** |

**Three columns, no CP column** — the p.106 correction on glass, with the real
campaign-level figure in the header (`TURN 1 | OP TURN 1 | CP 12 | UNITS 3 | WINS 1`).

The saved record confirms the shape at the data level:

```
keys on unit[0]: base_unit_id, battles_fought, battles_won, current_models,
                 custom_name, is_destroyed, models_lost_current, models_lost_total,
                 selected_upgrades, species_id, unit_id     <- all 11 FIELDS
RETIRED keys leaked into units: NONE                        <- normalize() holding
```

⚠ **The deployed-vs-not-deployed discrimination is NOT verified on hardware, and cannot
be from this screen.** `TacticsBattleSetupPanel._campaign_unit_ids()` lists every
non-destroyed unit, so the flow deploys the WHOLE roster ("Deploying 3 unit(s)") and
there is no partial-deployment UI to produce a negative case. The saved `current_battle`
is `{}` post-battle, so the run cannot even distinguish which branch of
`_credit_deployed_units()` executed. That arm rests on
`test_a_unit_that_did_not_deploy_is_not_credited`, which is detection-proven.
**Recorded as a limitation, not glossed as a pass.**

ⓘ Incidental confirmations: the p.134 Infantry Platoon limits render correctly
("1-2 Platoon Leaders / 2-4 Troop units / 0-3 Support units (fewer than troops) /
Specialists: 1 per 2 troops") and a legal army validates; the p.106 CP award moved
**0 → 12** on one victory, against the pre-Sep-4 fabricated maximum of 3.

---

## F4 — the Stars-of-the-Story owner guard · **PASS**

Tested through the real auto-load path rather than a contrived one. After the Tactics
campaign, `last_campaign` is the Tactics save, so a relaunch loads a
**`TacticsCampaignCore`** as `current_campaign`; Battle Simulator then opens
`TacticalBattleUI` against it — exactly the condition that produced
`Invalid access to property 'stars_of_the_story'`.

The battle screen **built end to end** — battle card, the three p.110 deployment steps,
pre-battle checklist, full terrain map, six Isolationists, footer — and the device log
carries **no `stars_of_the_story` access, no `Invalid access`, no SCRIPT ERROR**. Had
`_setup_stars_battle_ui()` aborted, the enclosing function would have unwound and taken
the rest of that setup with it.

**The control arm, from real device saves on both sides:**

| core | `stars_of_the_story` | guard behaviour |
|---|---|---|
| 5PFH `tablet_qa_run` | **present** | returns the campaign → Stars work |
| Tactics `tacticsqa35` | **absent** (Compendium p.214) | returns null → no abort |

ⓘ **T11-49 regression check, free with this run**: the 5PFH save is **byte-identical**
(82,307 bytes) across a whole Battle Simulator session — `active_battle` still present,
`turns_played` 9.0. And the simulator's Battle Card showed its OWN briefing (Wilderness
3x3, Isolationists), not the campaign's, so deploy #34's sixth-consumer fix holds.

---

## F3 — the crew pager · **PASS**, five arms

Crew → Dex Kovac → `CharacterDetailsScreen`. The pager renders as `‹ ○●○○○○ ›` **at the
bottom of the page, below Save Changes** — inside `MarginContainer/PageColumn`, not at
(0,0) over the header. That is the parenting fix visually: the screen root is a bare
`Control`, which lays out no children, so anything added to it lands at its default rect.

| arm | result |
|---|---|
| `›` arrow tap | Dex Kovac → **Yuri Drake**; full-page diff; dots `○○●○○○`; stats and equipment both change |
| horizontal fling (1920→768 @ y934, 200 ms) | Finn Mendez → **Nyx Ward**; full-page diff; dots `○○○○○●` |
| **short swipe, 60 px** (< the 96 px floor) | **IDENTICAL frame** — correctly rejected |
| **vertical swipe** | **IDENTICAL frame** — correctly rejected |
| pager parenting | child of `PageColumn` |

The fling is a frame that could not have existed before the fix: `_unhandled_input()`
never saw the touch, because `ScrollContainer::gui_input` claimed it and called
`accept_event()` one layer up.

---

# Three defects the walk found, all fixed

## F5 — the hero-card buttons leaked on every page turn

Paging produced a **second, clipped "Change Portrait" button** at the card's top edge.

`populate_ui()` guarded with `hero_card.get_node_or_null("__ChangePortraitBtn")`, but
`_setup_portrait_upload()` adds the button to `__HeroOverlay`, a **child** of hero_card
(the card is a Container and would otherwise override the button's anchors — see the
docblock on `_get_or_create_hero_overlay()`). `get_node_or_null(name)` is a DIRECT-CHILD
lookup, not a search, so the guard asked for a grandchild by its bare name, got null
every time, and was **permanently false**. Identical at the `__PrintSheetBtn` call site.

⭐ **The guards were written for the pre-overlay layout and never moved when the buttons
did** — the writer relocated, the reader stayed. Same shape as the `TacticsCampaignUnit`
break earlier the same day, where deleted constants left their readers behind.

⚠ **It cost nothing while `populate_ui()` ran once per screen entry.** The crew pager
made it re-entrant, which is what turned a dormant defect into a visible one. A
permanently-false guard is free until the guarded code runs twice.

⚠ **The first version of the test was GREEN against a live leak, and the detection
harness is what caught it.** Measured directly with a throwaway probe:

```
[PROBE] pass=0 children=["__ChangePortraitBtn", "__PrintSheetBtn"]
[PROBE] pass=1 children=[..., "@Button@128", "@Button@129"]
[PROBE] pass=3 children=[..., "@Button@210", "@Button@211", "@Button@292", "@Button@293"]
```

**When an explicit `name` collides with a sibling, Godot DISCARDS the requested name**
and falls back to its default `@<ClassName>@<id>` form. The leaked copies are called
`@Button@128`, so a substring count for `"ChangePortrait"` reports exactly ONE however
many leak. The test now counts the overlay's **Button children**. *Assert where the
damage lands.*

## F6 — the battle history read two keys nobody wrote

`TacticsDashboard._build_battle_history()` renders
`"Turn %d: %s — CP earned: %d"` from `entry.get("turn", 0)` and
`entry.get("cp_earned", 0)`, while the producer appended only `{"won": true}`.
Measured on device: a **Turn-1 victory that awarded 12 CP** displayed as
**"Turn 0: Victory — CP earned: 0"**.

A consumer read with no producer write is a **silent default, never an error**, which is
why nothing caught it — the recurring shape this repo's data-flow sweep is named for.
Fixed at `TacticsCampaignCore.record_battle()`, the chokepoint that both appends the
entry and computes the award, so the two cannot drift.

ⓘ **One suspicion checked and dismissed rather than reported**: the save has no
top-level `campaign_points`, which looked like the 12 CP was not being persisted. It is —
`state.campaign_points_earned = 12`. No data loss.

## F7 — the CP spend prices were a flat 1 CP against a book table of 1-4

The Advancement phase offered three buttons — "Unit Upgrade (1 CP)", "Roster Change
(1 CP)", "Battle Advantage (1 CP)" — and `_on_spend_cp()` charged a flat
`_cp_spent += 1` regardless. **Tactics pp.107-108 price eleven distinct purchases at
1-4 CP.** The headline error: *"Unit Upgrade (1 CP): Acquire a veteran skill"* against
p.107's **Gain Veteran Skill (4 CP)** — `tactics_source.txt` line 7099.

⭐ **This is the SPEND-side twin of the award bug fixed 2026-09-04**, and it survived that
fix because the auditor was reading what CP a player EARNS and never looked at what they
PAY. Both are the same defect: a fabricated flat number standing in for a book table.

⭐ **It is also the live copy of a value I had just deleted as dead.** Earlier the same
session `TacticsCampaignUnit.add_veteran_skill(skill, cost := 1)` was removed precisely
because 1 CP contradicts p.107 — *"an uncalled function carrying a wrong book value is
the most expensive kind of dead code"*. The corpse was removed and the disease was still
in the UI. **When deleting dead code for a wrong value, grep the value, not the function.**

Fixed with `TacticsCampaignCore.CP_PURCHASES`, a page-cited SSOT of all 13 purchases.
The panel's explanatory card **and** its buttons are generated from it, so the prose a
player reads is the CP they are charged, and `_on_spend_cp()` charges the table's price
behind an affordability guard (a 4 CP skill is not reachable on 2 remaining CP).

⚠ **The EFFECTS remain unwired, exactly as before, and the site says so.** This corrects
what a purchase COSTS — a rules value the book states outright — and does not invent the
unit-picker feature the effects need.

---

## Gates

| gate | result |
|---|---|
| full `tests/unit` | **3304 cases / 0 failures / 0 errors** across 11 batches (3294 before these three fixes; +10 is exactly the cases added) |
| extended suites | **26 cases / 0 failures** (`test_tactics_campaign_points` 6 → 14, `test_crew_pager` 10 → 12) |
| detection proof, new fixes | **3 arms / 3 DETECTED**, each case run ALONE |
| detection proof, original four | 7 arms / 7 DETECTED (deploy #34 desk pass) |
| `test_every_script_compiles` | PASS — 483 scripts |
| eight lints | all exit 0 · orphan lint `files=561 reachable=561 test_only=0 orphans=0 unwired_rules=0` |

⚠ **Suite COUNT is unchanged (305 files).** The two new fixes extend existing suites
rather than adding new ones, deliberately: adding a suite re-rolls the batch boundaries,
and that is what surfaced the Stars bug on the previous full run.

ⓘ **`unwired_rules` is now 0, so CLAUDE.md's note that `TacticsOperationalMap.gd` has
"zero callers" is STALE.** It is wired — `TacticsOperationalMapPanel.gd:25` preloads it
and `TacticsTurnController.gd:63` loads that panel for Phase 7 — and this walk watched it
render: Cohesion 5/5, Player Battle Points 1/3 after the victory, and the nine
Operational Turn Steps cited to pp.96-99.
