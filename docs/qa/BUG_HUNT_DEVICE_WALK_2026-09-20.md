# Bug Hunt device walk — runbook and results sheet

**Written for:** whoever drives the tablet session, which may be a different Claude session
than the one that wrote Sprint 1. Everything needed is here; nothing assumes the sprint's
working context.

**Status:** ✅ WALKED on **deploy #36** (versionCode 19, 2026-09-21/22) and torn down clean.
The RESULT lines below were NOT filled in; the walk kept a window-by-window ledger instead, which
is the record: `docs/qa/BUG_HUNT_DEVICE_WALK_2026-09-21_FINDINGS.md`. Desk fixes are appended at the bottom of that file.
(This line read "NOT YET WALKED" until 2026-09-24; the ledger lived only in a session scratchpad
until then.)

**Subject:** Sprint 1 of *Bug Hunt on the foundations* — committed as `d1e541ccb`
(Phases 0-3) and **`ca6172011`** (Phases 4-7, 43 files, +6,561/-959). This walk is the last
owed item of Phase 7; its desk half is green.

**Ledger:** `docs/audits/BUG_HUNT_PARITY_AUDIT_2026-09-10.md`.
**Procedure this builds on:** `docs/sop/android-runtime-testing.md`.

---

## 0. What this walk is actually testing

Sprint 1 found Bug Hunt's **data** near byte-exact against Compendium pp.163-226 and its
**delivery** broken almost everywhere. Four defects were fatal to play, and the walk exists
to confirm each one is dead on real hardware:

| # | Measured on HEAD before the sprint | Where the walk proves it |
|---|---|---|
| 1 | **No played mission ever scored an objective** — so Court Martial fired every turn and the campaign had no reachable win | Step 7 |
| 2 | **A Bug Hunt turn could never END** — every campaign stuck on turn 1 | Steps 9-10 |
| 3 | The mission tally was counted **three times** | Step 8 |
| 4 | A muster-out **deleted** the veteran instead of writing a transfer file | Step 12 |

⚠ **Desk-green says nothing about touch.** Godot delivers no `InputEvent`s headless, so the
3,440 unit cases pin the STATE these fixes leave behind, never the gesture. The device is the
authority.

---

## 1. Prepare the build

### 1a. Flip the Alpha-1 gate — inside a `finally`

Bug Hunt is **Alpha-2**, hidden behind one constant:

```
src/ui/screens/mainmenu/MainMenu.gd:20    const A1_BUILD := true
```

With it `true`, the Bug Hunt button stays enabled but its handler is rebound to a
coming-soon note (`:273-296`) — so **the mode is unreachable and nothing below step 2 can
happen**. Flip it to `false` for the build, and flip it back in a `finally`, not at the end
of a happy path.

> ⚠ Flipping it changes nothing else. The comment at `:266-268` says so, and the gate is a
> single early `return` — no other edit is needed or wanted.

**RESULT:** `A1_BUILD` flipped to false at ______ · restored at ______ · `git diff src/ui/screens/mainmenu/MainMenu.gd` empty afterwards? ______

### 1b. Export

Two routes, both live. **Method A (editor one-click Remote Deploy) is preferred** and avoids
every trap in 1c — see the SOP §T2. Use the CLI only if the editor route is unavailable.

⚠ **The preset is AAB, despite the `.apk` path.** `export_presets.cfg` holds
`export_path="./FiveParsecsTest03.apk"` (`:11`) next to `gradle_build/export_format=1`
(`:33`), and **1 is AAB**. A CLI export must flip `export_format` to `0` and flip it back —
which is exactly the tracked-config change that gets stranded by 1c.

### 1c. ⚠ The Gradle-daemon trap (CLI route only)

The console binary is a thin forwarder. Godot's Android export shells out to `gradlew`, whose
**client exits while the daemon keeps running** with `idleTimeout=10800000` (3 hours), holding
the forwarder's inherited stdout handle. So the exporter exits, **the APK lands on disk**, and
the wrapper sits there until the daemon times out. `subprocess.run` never returns and it looks
like a hang.

- **Check the ARTIFACT, not the process.** `ls build/*.apk` (or the preset's `export_path`)
  answers "did it build?"; the process table does not.
- **The CPU delta is the discriminator.** A real Gradle build burns whole cores; an idle
  daemon burns nothing. Measure `Get-Process java` CPU-seconds over ~8 s of wall clock — a
  ~0.0 delta means idle, not slow.
- **Kill the DAEMON, not the wrapper.** `Get-Process java | Stop-Process -Force` lets the
  wrapper exit and the script's `finally` restore the preset. Killing the wrapper instead
  strands `export_format` flipped in tracked config.
- ⛔ **Do not kill the long-lived `Godot_v4.6-stable_win64.exe … -e` process** — that is the
  editor, and it coexists with headless exports fine.

### 1d. Install

```powershell
$adb = "C:\Users\admin\Documents\Android\Sdk\platform-tools\adb.exe"   # NOT on PATH
& $adb devices -l                                   # must list the TB361FU
& $adb install -r ".\FiveParsecsTest03.apk"
& $adb shell am start -n "com.reptarus.fiveparsecs/com.godot.game.GodotAppLauncher"
```

⚠ It must be a **debug** build (`OS.is_debug_build()`), or the QA card in step 3 does not
exist and the whole forcing half of this walk is unreachable.

⚠ Raise the screen timeout before a long walk and restore it after:
`settings put system screen_off_timeout 1800000` → `120000`.

**RESULT:** device ______ · versionCode ______ · debug build confirmed ______

---

## 2. The forcing seam — read this before step 3

`DiceManager.queue_forced_result(context_key, value)` (`DiceManager.gd:78`) parks a value that
the **next** roll whose context contains `context_key` consumes, **once**. Both ends are gated
on `OS.is_debug_build()`. Sprint 1 Phase 3 routed 21 raw Bug Hunt rolls through it and added
25 Bug Hunt rows to `QAScenarioDialog.FORCEABLE_ROLLS`.

Four properties that decide whether a queued value does what you meant:

1. **Matching is a case-insensitive SUBSTRING**, so `"Bug Hunt Casualty"` reaches a roll made
   as `"Bug Hunt Casualty: Cpl. Vance"`.
2. **An out-of-range value is DISCARDED, never clamped** — deliberately, because clamping
   would arm a different row than you asked for. A dropped value and a value that simply
   never fired look **identical on screen**. Judge by the outcome, never by the fact that you
   pressed Queue.
3. `_take_forced` returns on the **first queued key that matches, in insertion order**. No Bug
   Hunt key is a prefix of another (the table's own comments state this as a design rule), so
   arming several at once is safe.
4. `_forced_results` is key → FIFO, so one key can be queued repeatedly to drive an ordered
   sequence of rolls.

⚠ **Creation-time rolls cannot be forced on this walk.** The QA card lives on the Bug Hunt
*dashboard*, which does not exist until the campaign does — so Origin, Basic Training and
Service History (step 2) are **observe-only**. Record what came up; do not hunt for a control
that is not there.

### The 25 Bug Hunt rows, verbatim

| Context key | Die | Force | Why that value |
|---|---|---|---|
| `Bug Hunt Enlistment: die 1` | d6 | 6 | p.212 — 2D6 + Combat ≥ 7 |
| `Bug Hunt Enlistment: die 2` | d6 | 1 | 6+1 lands **on** the boundary |
| `Bug Hunt Special Assignment die 1` | d6 | 6 | p.183 |
| `Bug Hunt Special Assignment die 2` | d6 | 6 | 12 clears every row |
| `Bug Hunt Support die 1` | d6 | 6 | pp.188-189 |
| `Bug Hunt Support die 2` | d6 | 6 | pp.188-189 |
| `Bug Hunt Priority: die 1` | d6 | 1 | p.187 — Priority is the **lower** of 2D6 |
| `Bug Hunt Priority: die 2` | d6 | 6 | p.187 |
| `Bug Hunt Objective: type` | d6 | 6 | p.185 |
| `Bug Hunt Signals: count` | d6 | 6 | p.208 (optional rule; 6 clears the 4+ threshold) |
| `Bug Hunt Tactical Location: type` | d6 | 6 | p.191 — 1 Distract, 2-3 Block, 4-5 Neutralize, 6 Delay |
| `Bug Hunt Commendation: die 1` | d6 | 6 | p.172 — each 6 is +1 XP and +1 Reputation |
| `Bug Hunt Commendation: die 2` | d6 | 1 | 6/1 = one commendation, 6/6 = two |
| `Bug Hunt Origin` | d100 | 1 | p.171 — 01-09 Core systems world (+1 Rep) |
| `Bug Hunt Basic Training` | d100 | 1 | p.171 — 01-15 Ground forces (+1 Combat, +1 Tough) |
| `Bug Hunt Service History` | d100 | 26 | p.172 — 26-40 fringe-space patrol (a Combat Op) |
| `Bug Hunt Court Martial` | d6 | 1 | p.201 — only on 0 weighted objectives; 1 removes the leader |
| `Bug Hunt Casualty` | d100 | 1 | p.202 — 01-05 Gruesome fate: dead, equipment lost |
| `Bug Hunt Recovery Time` | d6 | 6 | p.202 — 1D3 rolled as ceil(1D6/2), so 6 = 3 |
| `Bug Hunt Muster Out` *(min 2)* | d12 | 12 | p.203 — 2D6 vs the row target; 12 musters on every row |
| `Bug Hunt Reputation` | d6 | 5 | p.203 — 1D6 per objective, 5-6 = +1 Rep |
| `Bug Hunt Operational Progress` | d100 | 100 | p.205 — rolls over 100 into Parade: **the only win** |
| `Bug Hunt Military Life` | d100 | 16 | p.206 — 16-20 Time in the Brig |
| `Bug Hunt Brawl` | d6 | 1 | p.206 — the 01-05 Got in a fight check |
| `Bug Hunt Subject Pick` | d100 | 1 | pp.205-206 — **which** character a per-character table hits |

⚠ **`Bug Hunt Muster Out` carries `"min": 2`** because it is a **2D6**, and the picker honours
it per row. Queuing 1 on a 2D6 row is silently DISCARDED (property 2 above), which once left
the status line reading "Queued 1" over a random roll.

⚠ **Queue `Bug Hunt Subject Pick` BEFORE any per-character table** (Casualty, Military Life),
or the table hits a random marine and the observation is unattributable.

⚠ **Save `Bug Hunt Operational Progress = 100` for LAST.** The `above_100` row is
`campaign_victory: true`, `triggers_r_and_r: true` **and `reset_progress: true`** — it wipes
the modifiers you would otherwise be reading and changes the next turn's shape. Force a
non-win value first if you want to watch the modifier move, and take the Parade at the end.

---

## 3. The walk

Take a screencap at every step. Two consecutive **byte-identical** frames mean a tap did
nothing — a known trap that flawed the deploy #25 record.

### Step 1 — Main menu

Tap **Bug Hunt**. It must navigate, not show the coming-soon note.

- ✅ PASS: the creation wizard opens.
- ❌ FAIL: a "coming soon" note → `A1_BUILD` is still `true` in the installed build.

**RESULT:** ______

### Step 2 — Creation (4-step wizard)

Walk Config → Characters → Equipment (auto-completes; Bug Hunt is standard issue) → Review.

- ⓘ **Known and deferred, not a finding:** asking for 5 main characters generates **4**
  (audit Row D; the p.170 five-marine option is explicitly out of Sprint 1). Record the count
  but do not file it.
- Origin / Basic Training / Service History are unforced here (§2). Record what came up.

**RESULT:** marines ______ · rolls observed ______

### Step 3 — Dashboard, and the QA card

The dashboard must show a **"QA - Force a Roll"** card (`BugHuntDashboard.gd:122`,
`:127-134`, `:318-319`), gated the same way the 5PFH dashboard's QA button is.

- ❌ No card → the build is not a debug build, and steps 4-12 cannot be driven.
- The dialog opens with `popup_centered_ratio(0.92)` — never a fixed size, because a
  hard-coded 900×620 clipped both controls off-screen at the tablet's portrait geometry.

**RESULT:** QA card present ______ · dialog fully on screen in **both** orientations ______

### Step 4 — Special Assignments

Arm `Bug Hunt Special Assignment die 1` = 6 and `die 2` = 6 (12 clears every p.183 row), then
roll.

**RESULT:** assignment granted ______

### Step 5 — Mission

Arm, in this order: `Bug Hunt Priority: die 1` = 1, `die 2` = 6, `Bug Hunt Objective: type`
= 6, `Bug Hunt Signals: count` = 6.

Two things to read off the briefing:

1. **Priority must be 1**, not 6 — p.187 takes the **lower** of 2D6. A 6 means the mini() is
   gone and the roll is being read as a 2D6 sum.
2. **Spawn points must EQUAL the spawn rating.** A phantom `get("base_count", 2)` used to add
   two spawn points to every mission and turn the book's *"if 0, none"* into *"if 0, two"*.
   Verified at the data layer (0/1/3 → 0/1/3); this is its device arm.

**RESULT:** priority ______ · spawn rating ______ → spawn points ______ · signals ______

### Step 6 — Battle

Play or auto-resolve through `TacticalBattleUI` in `bug_hunt` mode. **Morale is hidden** in
this mode — *"There is no morale system in Bug Hunt"* (Compendium, *Nowhere to run*).

**RESULT:** battle completed ______ · morale UI absent ______

### Step 7 — ⭐ Debrief: the headline test of the whole sprint

This is the single most important observation on the walk.

**The failure string is exact and on screen.** If the mission was not stamped, the debrief
card renders, in warning colour:

> **"No mission was stamped for this turn, so Objectives cannot be scored here."**

- ❌ **That sentence appearing after a played mission means Phase 4's stamp did not reach the
  device**, and everything downstream (objective XP, Reputation, Operational Progress, the
  win) is dead exactly as it was on HEAD.
- ✅ **PASS** is the opposite: a tickable **CheckBox per objective**, each labelled with its
  name and — for a weighted one — a `" — Vital, counts as 2"` / `" — Critical, counts as 3"`
  suffix (pp.185, 201). Plus a **"Signals investigated (of N)"** SpinBox and an **"MVP (+1 XP,
  p.204)"** dropdown with the first participant preselected.

Tick **at least one** objective. Then, at post-battle:

- ⭐ **Court Martial must NOT fire.** It fires only on **0** weighted objectives (p.201). On
  HEAD it fired every single turn because no played mission ever scored anything.

**RESULT:** stamp warning absent ______ · objectives listed ______ · weights shown ______ ·
signals spin present ______ · MVP dropdown present ______ · **Court Martial fired? ______**

### Step 8 — Post-battle (p.202 slice)

Arm `Bug Hunt Subject Pick` = 1 **first**, then `Bug Hunt Casualty` = 1 (01-05 Gruesome fate:
dead, equipment lost), `Bug Hunt Reputation` = 5, `Bug Hunt Military Life` = 16 (Time in the
Brig).

Read off the receipt:

- The forced marine is **dead**, and their equipment is gone.
- **The tally rises by exactly 1** — for a character who took the field and is not in Sick
  Bay. On HEAD it rose three times (panel +1, panel +1 per XP award, phase manager +1).
- Reputation, XP and the Military Life row all land with their page cites.
- Sick Bay is ticked **before** this turn's wounds are added, so a one-turn Casualty costs the
  marine a turn out of action (`BugHuntPhaseManager.gd:232-233` before `:239`).

**RESULT:** casualty applied to the forced marine ______ · tally before ______ → after ______
· Reputation ______ · Military Life row ______

### Step 9 — The turn must END

Press **Start Next Turn**.

- ✅ Turn **2** opens on **Special Assignments**.
- ✅ Press it a **second** time: the finished turn's XP, tally and Reputation are **not**
  applied again.
- ❌ On HEAD `current_phase` was never set, so this re-ran the finished turn's post-battle
  effects instead of opening turn 2.

**RESULT:** turn ______ · phase ______ · second press re-applied anything? ______

### Step 10 — Reopen the save

Force-stop, relaunch, Continue.

- ✅ Resumes **where it was left**, not at turn 1 Special Assignments.
- ⚠ Read `user://logs/godot.log` **before** force-stopping — it **rotates on launch**.

```powershell
& $adb shell run-as com.reptarus.fiveparsecs cat files/logs/godot.log
& $adb shell run-as com.reptarus.fiveparsecs ls files/saves/
```

**RESULT:** resumed at turn ______ phase ______

### Step 11 — Enlist

From the dashboard, tap **Enlist**.

- ✅ It offers a **standard 5PFH** save.
- ❌ It offers the **Bug Hunt** save → the mode predicate regressed. On HEAD the filter read a
  `"type"` key no producer writes, so it was always true and a Bug Hunt marine could be
  enlisted into Bug Hunt as a "5PFH veteran".
- ⓘ With **no** 5PFH save on disk it must offer **nothing** — that is correct, not a bug.

**RESULT:** offered ______

### Step 12 — Muster out, and the transfer file

Arm `Bug Hunt Muster Out` = **12** (⚠ min 2 — it is a 2D6; a queued 1 is discarded). Muster a
named veteran out.

- ✅ A file appears in `user://transfers/`.
- ❌ The veteran simply **vanishes** → the HEAD defect is back. On HEAD muster-out called
  `remove_main_character()` and wrote nothing, so the veteran was **deleted**.

```powershell
& $adb shell run-as com.reptarus.fiveparsecs ls files/transfers/
& $adb shell run-as com.reptarus.fiveparsecs cat files/transfers/<id>.json
```

Check the envelope: `schema_version 2`, `direction`, `source_mode: "bug_hunt"`, `target_mode`,
`character`, and a lossless `snapshot`.

**RESULT:** transfer file ______ · `target_mode` ______ · `snapshot` present ______

### Step 13 — The Parade (take this last)

Arm `Bug Hunt Operational Progress` = 100. The `above_100` row is *"Time to hold a parade!"* —
`campaign_victory: true`, +1 Reputation, R&R, and `reset_progress: true`.

⭐ **This is the first reachable win condition Bug Hunt has ever had.** Before Sprint 1 no
played mission scored an objective, so Operational Progress never moved and `above_100` was
unreachable by construction.

**RESULT:** victory recorded ______ · Reputation +1 ______ · progress reset ______

---

## 4. Close out

1. Restore `A1_BUILD := true` (the `finally` from 1a).
2. `settings put system screen_off_timeout 120000`.
3. ⭐ **`git diff project.godot export_presets.cfg` must be EMPTY.**
   An export is a **writer** of tracked config, not just a reader: it rewrites
   `project.godot` (discarding every `;` comment and re-sorting keys) and a CLI export flips
   `export_format`. A stranded Gradle daemon is the usual reason this comes back dirty.
4. Delete any probe saves the walk created. ⛔ **Never delete a save that is not a probe
   artifact** — `user://saves/` holds the user's real campaigns.
5. Append the filled sheet to `docs/qa/TABLET_QA_SPRINT_2026-08.md` as a new deploy section,
   and record any finding at its row in
   `docs/audits/BUG_HUNT_PARITY_AUDIT_2026-09-10.md`.

**FINAL:** `git diff project.godot export_presets.cfg` empty? ______ ·
`git status --porcelain` ______

---

## 5. Reading the device — traps that have cost sessions here

- **"Settled" is not "hung."** Two byte-identical frames mean the screen has finished
  drawing. Scroll the full page before concluding a control did nothing; the control that
  advances the flow has been below the fold before.
- **A greyed control is usually correct** — it greys because it succeeded.
- **CPU is meaningless without a baseline.** This app idles at ~32% on the main menu and ~37%
  on the dashboard because Godot renders continuously. ~55% is unremarkable.
- **Button positions MOVE when siblings appear.** Re-locate between taps rather than chaining
  blind ones.
- ⛔ **`adb keyevent KEYCODE_BACK` reaches the app's own back handler** and has abandoned a
  battle in progress. Use `KEYCODE_ENTER` to dismiss the IME.
- ⚠ **Swiping over a focused `SpinBox` types into it** — and this walk is full of SpinBoxes
  (the forcing value, signals investigated). Scroll on a drawer's left edge instead.
- **`adb logcat` returns nothing for this app on this device.** The usable log is
  `user://logs/godot.log` via `run-as`, and it **rotates on launch** — read before
  force-stopping. `push_warning` / `push_error` reach it with a GDScript backtrace; check
  both channels, since a walk that skips `godot.log` has missed a finding before.
- **Auto-rotate resets between runs.** `user_rotation` writes are silently ignored while
  auto-rotate is on. Write both settings, read them back, and confirm
  `mCurrentRotation=ROTATION_n` in `dumpsys window` before capturing anything — three
  captures once came back byte-identical because the rotation never happened, which reads
  exactly like a clean pass.
