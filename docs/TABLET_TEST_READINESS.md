# Tablet Test Readiness — verified Aug 3 2026

Everything here was measured on this branch today, not estimated. Commands to
re-run each check are in §6. Where a number contradicts an older doc, this file
is right and the older doc is stale.

---

## 1. Verdict

**The build is tablet-testable now.** Nothing in the build, deploy, layout or
runtime path blocks handing an APK to a tester.

What blocks a **trustworthy** test — one where a tester's bug reports are worth
reading — is smaller and more specific than the 73-row audit backlog implies:
**five visible lies and one class of dead switch.** A tester who flips a toggle
that does nothing, or reads "Roll for advancement" and watches nothing happen,
spends the session cataloguing our known gaps instead of finding unknown ones.

Estimated pre-tablet work: **2-3 sessions**, itemised in §4.

---

## 2. What was verified green

| Check | Result |
|---|---|
| Script parse sweep | **608 scripts, 0 parse errors** |
| Unit + integration tests | **~2,376 cases, 0 failures, 0 errors** |
| Layout sweep, tablet sizes | **all tablet sizes pass** (162/168 overall; the 6 failures are phone-only, §5) |
| Android APK builds | **68 MB, Jul 29**, arm64-v8a |
| APK confidentiality | **clean** — no `CLAUDE.md`, no Modiphius docs, **0 test files packed** |
| `lint_signal_wiring` | **CLEAN (0)** — was 67 in CLAUDE.md |
| `lint_autoload_lookups` | **CLEAN (0)** — was 35 |

The APK check was done by **unzipping the artifact**, not by reading the export
config — the seven pattern hits are all legitimate (`eula.md`,
`privacy_policy.md`, `credits.md`, `third_party_licenses.md` are meant to ship;
`meeting.json` / `meeting.png` are narrative scene art). The confidentiality risk
recorded in memory from the July build is closed.

---

## 3. Real defects found while verifying

Four were fixed today. They were found by running the **full** suite rather than
the suites I had touched — none of them appear in the 73-row audit.

| Defect | Status |
|---|---|
| **Full Squad** (p.84) blocked when the roster couldn't be read — 0 available < required, so any failed lookup made every Full Squad job permanently unacceptable | fixed `2025226f7` |
| **Reputation Required** (p.84) same shape — "no campaign" returned 0, indistinguishable from a real campaign with no history here | fixed `2025226f7` |
| **Insanity enemy count** — I changed it to 0 off p.65 alone, then reverted: p.93 says "Hardcore **or Insanity**, add +1", and defines a Specialist as a re-arming not a body. Original data was right; the test pinning 0 was wrong | fixed `9f20724b7` |
| Injury Table equipment/stat consequences, Equipment Malfunction target, Sick Bay reductions | fixed `bffe2c8d1`, `d945a3ecb`, `b14974c37` |

Both p.84 gates were the audit's own defect family **inverted**: not a missing
read skipping a rule, but a missing read silently *enforcing* one.

---

## 4. What actually blocks a trustworthy tablet test

### 4a. Dead switches a tester will flip · ~½ session · **highest value on this page**

Visible in Settings and the creation wizard, and they change nothing:
Factions, Elite Enemies, Stealth/Street Fight/Salvage, Terrain Generation, the
12 Compendium difficulty toggles.

Hide or label them. Hours against weeks, and it converts "this app is broken"
into "that isn't in yet."

**But do the one-wire fix first (4b) — it moves three of those toggles out of
this list entirely.**

### 4b. Stealth / Street Fight / Salvage — one producer wire · ~1 session

Traced by hand today. Data, loaders, generators, resolvers, panels and the
`TacticalBattleUI` dispatch all exist and agree on the key — the generators stamp
`"type": "stealth"` and the UI branches on exactly that. The **only** caller of
all three generators is `src/core/campaign/phases/WorldPhase.gd:927/932/938`, a
file with zero instantiations.

Third time that same dead file has held live rules hostage — CLAUDE.md already
records it holding the only callers of `record_invaded_planet()`, `repair_hull()`
and the fuel consumer. Audit row **L61** is sized *medium, "and therefore the
whole Stealth, Street Fight and Salvage chapters"*. It is one wire, and it
unblocks **L69, L70, L71, L141** behind it.

### 4c. Five visible lies · ~1 session

Each is something a tester sees and reports, every session:

| Row | What the player sees |
|---|---|
| **L143** | Post-battle step 9 says "Roll for advancement", prints `Rolled 5 - …`, and changes nothing. **Every battle.** |
| **L47** | The Deployment Conditions panel renders blank for every battle; its buttons act on nothing. |
| **L167** | Job details render `OVERVIEW: `, `SPECIFIC OBJECTIVE: `, `TIME CONSTRAINT: ` with nothing after the colon. |
| **L158** | The app says a Person of Interest is 11" away and worth +1 story point; reaching them awards nothing. |
| **L176** | A character whose last Sick Bay turn ticks off takes a full Crew Task the same turn. |

### 4d. Test-harness reliability · ~½ session

The full suite **cannot complete in one process**. It segfaults deterministically
at suite 193 inside gdUnit4's GC stage, after **all tests have passed**, with
leaked RIDs (32 CanvasItem, 31 Texture, 34 ShapedText).

Cause is cumulative orphan nodes, concentrated in five suites:

| Orphans | Suite |
|---|---|
| 1236 | `test_battle_tier_integration.gd` |
| 187 | `test_campaign_wizard_flow.gd` |
| 95 | `test_campaign_creation_data_flow.gd` |
| 60 | `test_final_panel_ui_improvements.gd` |

Per the gdUnit4 docs (checked via context7), the fix is `auto_free()` on every
node those suites instantiate. **This is a harness defect, not a product one** —
run in two batches and everything is green — but until it is fixed nobody can
get a single green full-suite signal, which is exactly the signal you want
before shipping a tester build.

Also: **`test_campaign_wizard_flow.gd` fails its own setup** ("No coordinator
available") on every case, so the campaign-creation wizard has an integration
suite that exercises nothing.

---

## 5. Verified NOT to be tablet blockers

- **The 6 layout failures are phone-only** (338×733, 310×551). Every tablet size
  passes. All six share **one** root cause: the `"Ship debt: 25 cr (+1/turn)"`
  Label in `UpkeepPhaseComponent`'s TravelPanel autowraps inside an
  `HBoxContainer` and collapses to 1×480 — the autowrap-in-a-horizontal-container
  trap already in memory. It cascades to 3 screens × 2 phone sizes. Fix it when
  phones matter; it does not block a tablet session.
- **40 of the 73 open audit rows are DLC or endgame content** a tester cannot
  reach in an evening (factions, Elite enemies, Red/Black Zone at 10+ turns).
- **`lint_handoff_contracts` reports 100 rule-silencing findings** — 35
  orphan-reads, 64 uncalled rules, 1 dead producer. This is the best standing
  instrument for the audit's defect family and it should replace hand-counted row
  tallies, but most entries are Planetfall (out of scope) or Compendium chapters.
  The 1 dead producer is `progress_data[fuel_credits]` in the dead `TravelPhase.gd`.
- **`lint_data_ownership`**: 2 findings, both direct `campaign.credits` /
  `campaign.story_points` writes in `TravelEventResolver.gd`. Real, small, not
  player-visible.

---

## 6. Re-verify

```powershell
$G = "C:\Users\admin\Desktop\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64_console.exe"
$R = "c:\Users\admin\SynologyDrive\Godot\five-parsecs-campaign-manager"

# Parse sweep — grep for "Parse Error" SEPARATELY, the summary line is not the verdict
& $G --headless --path $R --script tests/tools/verify_scripts_parse.gd

# Tests — MUST be run in two batches until 4d is fixed, or it segfaults at ~193
& $G --path $R --script addons/gdUnit4/bin/GdUnitCmdTool.gd -c -a tests/unit --quit-after 3000
& $G --path $R --script addons/gdUnit4/bin/GdUnitCmdTool.gd -c -a tests/integration --quit-after 900
# read the CASE COUNT, not the exit code — a parse error reports "No test cases found" and exits 0

# Layout — NOT --headless; needs a real window
& $G --path $R --script tests/tools/verify_layout.gd

# Lints
py scripts/lint_signal_wiring.py; py scripts/lint_autoload_lookups.py
py scripts/lint_data_ownership.py; py scripts/lint_handoff_contracts.py

# APK contents — unzip the artifact, never trust the export config
py -c "import zipfile,re; z=zipfile.ZipFile('build/fpfh-0.9.7-sideload.apk'); print([n for n in z.namelist() if re.search(r'CLAUDE|MODIPHIUS|^docs/|/tests/',n,re.I)])"
```

---

## 7. Order

| # | Item | Effort |
|---|---|---|
| 1 | **4b** wire the 3 mission generators into the live World Phase | 1 session |
| 2 | **4a** hide/label the remaining dead switches | ½ session |
| 3 | **4c** the five visible lies | 1 session |
| 4 | **4d** `auto_free` the 4 leaking suites + fix the wizard-flow fixture | ½ session |

**Then ship a tester build.** Everything else on the 73-row backlog is either
unreachable in one sitting or invisible without an expansion, and is better
driven by what the tester actually reports.
