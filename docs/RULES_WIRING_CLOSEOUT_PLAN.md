# Rules Wiring — Closeout Plan

**Ground truth Aug 3 2026: 73 open / 7 partial / 62 fixed of 143 rows** in the
Core Rules audit — **plus an unmeasured Compendium backlog** (§2), which is the
larger and more commercially important half.
Branch `campaign-editor-and-fixits`. Companion to `RULES_WIRING_AUDIT_2026-08.md`
(the ledger); this file is the *route*, the ledger is the *record*.

> **Revised Aug 3 (second pass).** The first draft deferred the Compendium as
> "DLC, invisible without the expansion". That was wrong on the facts. The
> Compendium **is the product being sold** — `compendium_bundle` plus the
> per-book unlocks agreed with Modiphius on Jul 27 ("$9.99 one-time base +
> per-book unlocks APPROVED"). A paid unlock that changes nothing is materially
> worse than a free-content gap: one is an unfinished feature, the other is
> selling an empty box. Compendium readiness is now the spine of this plan.

---

## 0. Re-measure before you trust any count

The header count has drifted twice, in both directions. Never plan off it:

```powershell
py -c "
import pathlib, collections
rows=[]
for l in pathlib.Path('docs/RULES_WIRING_AUDIT_2026-08.md').read_text(encoding='utf-8').split(chr(10)):
    if not l.startswith('| '): continue
    c=[x.strip() for x in l.strip().strip('|').split('|')]
    if len(c)<5 or c[0] in ('Domain','Area') or set(c[0])<=set('- '): continue
    rows.append((c[0], c[-1]))
print(collections.Counter(s.split()[0] for _,s in rows))
print(collections.Counter(d for d,s in rows if s.startswith('OPEN')))
"
```

A status cell can read `OPEN — VERDICT CONFIRMED …`, so matching the literal
`| OPEN |` undercounts. Match on `startswith('OPEN')`.

**Re-verify a row before working it.** Two of two spot-checks today were stale —
Patron Time Frame (L93) and the p.123 XP keys (L80) had both shipped weeks
earlier under a different row's commit. Rows written before the July/August
sprints describe a codebase that no longer exists.

---

## 1. The Compendium readiness map — verified by hand, solo

> **Two retractions.** (a) The Aug 2 audit used eight parallel auditors and gave a
> 236-page book to one of them; it missed fifteen Compendium chapters outright.
> (b) My own follow-up measurement — "19 of 33 ContentFlags gate nothing" — was
> **also wrong**, and wrong the same way: I grepped `ContentFlag.X` and never saw
> the string form. `compendium_equipment.gd` gates through
> `dlc_mgr.ContentFlag.get("NEW_TRAINING")`, so four flags I called dead are
> gated fine. Counting one spelling of a thing is not measuring it.
>
> **Counting flag references is not a readiness signal and has been dropped.**
> A reference proves a gate exists, not that the rule reaches play — which is
> precisely what the 143-row audit was for. The only check that works is the
> per-chapter trace in §1b, done by hand.

### 1a. What the reference count does establish

Counting BOTH `ContentFlag.X` and `"X"` string forms, excluding the store and
settings UI that merely lists flags: **exactly two flags have no reference
anywhere in `src/`.**

| Flag | Pack | Evidence |
|---|---|---|
| `DEPLOYMENT_VARIABLES` | Freelancer's | `data/compendium/deployment_variables.json` has **zero loaders** |
| `ELITE_ENEMIES` | Freelancer's | `data/elite_enemy_types.json` loads via DataManager and nothing consults it |

That is the whole reliable output of that method. Everything else needs tracing.

### 1b. The trace that works — producer → key → consumer

Follow the data, not the flag. Worked example, and the biggest find of this pass:

**Stealth / Street Fight / Salvage is COMPLETE and severed at one point.**

| Layer | State |
|---|---|
| Data | `data/compendium/{stealth_missions,street_fights,salvage_jobs}.json` ✓ |
| Loaders | `src/data/compendium_{stealth_missions,street_fights,salvage_jobs}.gd` ✓ |
| Generators | `StealthMissionGenerator` / `StreetFightGenerator` / `SalvageJobGenerator` — each stamps `"type": "stealth" / "street_fight" / "salvage"` ✓ |
| Resolvers | `StealthResolver`, `SalvageResolver`, routed via `BattleResolverRouter` ✓ |
| Panels | `StealthMissionPanel`, `StreetFightPanel`, `SalvageMissionPanel` — instantiated and signal-wired in `TacticalBattleUI._setup_*_panel` ✓ |
| Dispatch | `TacticalBattleUI:4422-4428` branches on `mission_dict.get("type")` against exactly those three strings ✓ |
| **Producer call site** | **`src/core/campaign/phases/WorldPhase.gd:927/932/938` — the ONLY caller of all three generators, in a file with zero instantiations** ✗ |

`WorldPhaseController.gd:35` preloads `WorldPhase.gd` and never instantiates it.
This is the same file CLAUDE.md already records as holding the only callers of
`record_invaded_planet()`, `repair_hull()` and the fuel consumer — **"dead files
hold live rules hostage", third occurrence, same file.**

So audit row **L61** ("Mission Selection … and therefore the whole Stealth,
Street Fight and Salvage chapters", sized *medium*) is **not a chapter of work.
It is one producer wire in the live World Phase**, and landing it makes L69,
L70, L71 and L141 testable at once — five rows behind one call site.

**Trailblazer's "NEW KIT" is also further along than I said.**
`data/compendium/compendium_equipment.json` already carries all four sections —
`advanced_training` (5), `compendium_bot_upgrades` (6), `new_ship_parts` (3),
`psionic_equipment` (3) — DLC-gated in `compendium_equipment.gd` and consumed by
`AdvancementPhasePanel` (with the Compendium p.28 one-upgrade-per-turn cap),
`TradePhasePanel` and `PreBattleChecklist`. It needs verification per item, not
implementation.

---

## 2. What is actually unknown

Chapters with no audit row and no verified trace yet. These need the §1b
treatment one at a time, by hand:

PvP · Co-op · AI Variations · Escalating Battles (`escalating_battles.json` has
**zero loaders** despite `EscalatingBattlesManager.gd` existing) · Dramatic
Combat · Detailed Injuries · Casualty Tables · Expanded Quests · Expanded
Connections · Expanded Loans · Name Generation (`NameGenerationTables.json` is
read by `Character.gd` and `CharacterGeneration.gd` — check whether it is gated
or shipping free) · Fringe World Strife · Terrain Generation (the battlefield
generator is live and always on — check whether that is a leak).

**I am not going to put a number on this.** Every number produced so far — the
auditors' 40, my 19 — has been wrong. The chapters get traced one at a time and
the count is whatever it turns out to be.

---

## 3. Phases

### Phase 0 — Trace the Compendium by hand, chapter by chapter · solo

No fan-out. The method is §1b: find the data file, find the loader, find the
producer, find the consumer, and name the break. It took about ten minutes per
chapter for Stealth/Salvage/Street and produced a one-wire fix where the audit
had claimed a medium chapter of work.

Order: start with the chapters that already have data files and loaders, because
those are the ones most likely to be one wire from working —
`escalating_battles.json` and `deployment_variables.json` (both zero loaders),
then Terrain Generation and Name Generation (check for leakage), then the
chapters with no data file at all.

**First actionable item is already found: wire the three mission generators into
the live World Phase.** That is Phase 2f below and it should probably go first
of everything.

---

### Phase 1 — Ledger hygiene · no code · ½ session

Confirmed duplicate pairs, each the same finding written from two domains:

| Pair | Finding |
|---|---|
| L54 ≡ L92 | Credits for +1 on crew tasks / 3-credit extra Trade roll |
| L59 ≡ L20 | Affiliated Patron jobs → faction Loyalty |
| L18 ≡ L109 | Faction generation (existence vs quantity/types) |
| L28 ≡ L110 | Fringe World Strife arrival vs Instability tracking |
| L137 ≡ L138 | The fabricated shop economy (prices vs the market system) |

Removes 5-8 rows with no code. Re-verify any row whose text predates the July
sprints while you are in there.

---

### Phase 2 — Core Rules loop, the tester-visible half · ~3 sessions

Still worth doing before the tablet test, because a broken *free* core loop
undermines the paid content sitting on top of it. Ordered by what a tester hits:

**2a. One damage vocabulary** (1 session). Four spellings of "this item is
broken", three of which no gate honours:

| Key | Written by | Read by |
|---|---|---|
| `item_damaged` marker | Injury Table, Character Events, travel | Repair Your Kit |
| `damaged: true` | Campaign Event 45-48 | Assign Equipment, Purchase Items |
| `needs_repair` + `quality` | `LootTableResolver` (loot 26-45) | a label only |
| `requires_repair` | post-battle loot entries | a label only |

Loot rolls 26-45 are 20% of every loot result and the book says they cannot be
used until Repaired. Closes **L35, L136**, most of **L38**. Cheap only because
the injury work just built the producer and the repair path.

**2b. Battle setup residuals** (½ session): **L47** the Deployment Conditions
panel renders blank every battle, **L44** Guardian-AI attachment, **L158**
Notable Sights award nothing, **L46**, **L159**, **L146**.

**2c. Turn / upkeep / world** (1 session): **L177**, **L176**, **L175**, **L96**;
partials **L88** step 3, **L54/L92**, **L173** (12 world traits needing only a
call site).

**2d. Post-battle, unblocked half** (½ session): **L143** — the wizard says
"Roll for advancement" and prints results that change nothing, *after every
battle*; **L84** Medical school / Bot technician rerolls, newly meaningful now
that the Injury Table has real consequences.

**2e. Expanded Missions display bugs** (¼ session): **L167** renders
`OVERVIEW: ` with nothing after the colon. Cosmetic, instantly visible.
(Note: this is *Freelancer's Handbook* content — it belongs to Phase 4 by
product, but it is a 15-minute display fix, so take it here.)

---

### Phase 3 — Fixer's Guidebook · after the one-wire fix (§1b) lands

25 known open rows plus whatever 0b adds. **Order is forced by dependency:**

1. **Faction generation** (L18/L109) — a new campaign has zero factions for its
   entire life, so *every other faction row is unobservable until this lands*.
2. Loyalty (L21, L23) → Faction Jobs (L19) → Affiliated jobs (L20/L59) →
   Favors (L22) → Activities (L153, L24) → Events (L154) → Destruction (L25) →
   Invasion interaction (L26).
3. Fringe World Strife: arrival check (L28) → Instability tracking (L110) →
   step placement (L29) → faction effects (L27).
4. Salvage: finding jobs (L69) → Illegal jobs (L70) → the Scrapper trade (L71).
5. Stealth / Street Fight: mission-type plumbing (L61) then the rules (L141).
6. The three dead flags: **Fringe World Strife, Expanded Loans, Name Generation**.

---

### Phase 4 — Freelancer's Handbook · sized by the Phase 0 traces

Known rows: **L30** (the 12 difficulty toggles — transcribed, unwired),
**L62** (Elite enemies), **L140/L165** (Expanded Missions), **L155** (Terrain
Generation should be optional), **L31** partial (Progressive Difficulty Option 2).

Plus the unaudited chapters behind the dead flags: PvP, Co-op, AI Variations,
Deployment Variables, Expanded Quests, Expanded Connections, Dramatic Combat,
Detailed Injuries.

**PvP and Co-op deserve an early scope call** — they may be out of scope for a
single-player companion app entirely, in which case the honest move is to remove
the flags rather than sell them. That is a decision, not a task.

---

### Phase 5 — Trailblazer's Toolkit · verify NEW KIT per item, do not rebuild it

Krag, Skulkers and Psionics are live and were verified in the creation-wizard
audit. The gap is the **entire "NEW KIT" chapter (pp.25-27)**: New Training, New
Bot Upgrades, New Ship Parts, Psionic Equipment — four dead flags, four short
book sections. **This is the cheapest pack to be able to honestly call complete**,
and worth doing early for exactly that reason: one of three unlocks goes from
"partly there" to "done".

---

### Phase 6 — Red & Black Zone · 1-2 sessions

Ten rows (L60, L63-L68, L119, L164, L166). **Core Rules Appendix III, not
Compendium** — no unlock required, reachable in any campaign at 10+ turns. The
player is currently told about Threat Conditions, Time Constraints and improved
rewards that do not exist.

---

## 4. Blocked, and the unblock condition

Six items sit in files held by the parallel **Story Track** session (36
uncommitted files). Committing by explicit path has kept the trees disjoint all
sprint; that holds until they land.

| Row | File held |
|---|---|
| L75 Precursor double-roll | `PostBattlePhase.gd`, `CharacterEventEffects.gd` |
| L83 Character Events 11-12 / 20-23 / 63-66 / 72-75 | `CharacterEventEffects.gd` |
| L170 Character Events 52-55 / 24-26 / 42-45 / 67-68 | `CharacterEventEffects.gd` |
| L169 Campaign Events 79-81 / 98-100 / 57-59 / 82-84 | `CampaignEventEffects.gd` |
| L112 Gather the Loot — one roll per battle | `LootProcessor.gd` |
| L50 (partial) Private Transport | `RivalEncounterCheck.gd` |

L83/L169/L170 are three rows in two files — do them as one pass the moment it
clears.

---

## 5. Residuals that are NOT rules gaps

- **Auto-resolve cannot produce `first_casualty_by` / `unique_kills`.** The
  played path asks the player; a simulated fight has no notion of whose shot
  landed first. Under-pays by up to 2 XP. Deriving it would fabricate detail.
- **`fled_early_crew` has no producer** (L124, marked CORRECTED). The app tracks
  bail-outs for enemies only.
- **Busy (p.84) is a cadence question, not a missing flag** — wiring
  `offers_new_job_on_success()` as written is a provable no-op. Bundle with L139.
- **Elite Rank perks (p.65) need player-choice UI** the creation wizard has no
  concept of.

---

## 6. Open decisions — these gate the schedule, and they are yours

1. **Is PvP / Co-op in scope at all** for a single-player companion? If not,
   remove the two flags rather than carry them as debt (Phase 4).
2. **Job-offer cadence (L139 + Busy).** "Find a Patron" should gate whether an
   offer exists at all (p.77), but the book never states a per-turn offer rate.
   One judgement call settles two rows.
3. **Does "Compendium complete" mean all three packs, or one pack fully done
   first?** Trailblazer's is one session from honest completeness (Phase 5);
   Fixer's is the biggest by a wide margin. Shipping one *finished* unlock beats
   three half-finished ones, both for a tester and for the Modiphius conversation.

---

## 7. Ordering

| # | Phase | Effort | Why here |
|---|---|---|---|
| 1 | **Wire the 3 mission generators** into the live World Phase | ~1 session | Verified one-wire fix; unblocks 5 audit rows and a third of Fixer's |
| 2 | **0** trace the Compendium chapter by chapter, solo | ongoing | Everything below is unschedulable without it; ~10 min/chapter |
| 3 | **1** ledger hygiene | ½ session | −5 to −8 rows, no code |
| 4 | **5** verify Trailblazer's NEW KIT per item | ½ session | Already built and gated; confirm each of the 17 items applies |
| 5 | **2a-2e** Core Rules loop | ~3 sessions | The free floor under the paid content |
| 6 | **3 / 4** Fixer's, Freelancer's | sized by the traces | No estimate until traced |
| 7 | **6** Red & Black Zone | 1-2 sessions | Core Rules, no unlock, endgame |
| 8 | **blocked half** post-battle events | 1 session | When the Story Track tree clears |

**Definition of done:** every rule a player paid for reaches play, traced
producer → key → consumer, not inferred from a grep count.

**Method note, permanent:** no auditor fan-out on this codebase. Two passes now
have produced confident wrong numbers — the auditors missed fifteen chapters of
the Compendium, and a flag-reference count missed the string-keyed gate form.
Trace by hand and cite `file:line`.
