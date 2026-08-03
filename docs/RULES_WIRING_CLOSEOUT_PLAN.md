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

## 1. The Compendium readiness map

Measured, not estimated — consumer counts are `ContentFlag.X` references in
`src/` excluding `DLCManager` itself and the five store/settings UI files that
merely list flags:

```powershell
# regenerate: counts real gameplay consumers per flag
grep -rn "ContentFlag\.<FLAG>" src/ --include=*.gd | grep -v DLCManager.gd |
  grep -vE "DLCContentCatalog|ExpansionFeatureSection|DLCFeatureToggleRow|StoreScreen|DLCPackCard"
```

**19 of 33 content flags gate no gameplay code at all.**

| Pack (= a purchasable unlock) | Flags | Gate nothing | Core Rules audit rows still open |
|---|---|---|---|
| **Trailblazer's Toolkit** | 7 | **4** | ~0 |
| **Freelancer's Handbook** | 17 | **12** | ~7 |
| **Fixer's Guidebook** | 9 | **3** | ~25 |

Per-flag detail:

| Pack | Live (consumers) | Gates nothing |
|---|---|---|
| Trailblazer's | Krag 6, Skulkers 5, Psionics 13 | **New Training, Bot Upgrades, New Ship Parts, Psionic Equipment** — the whole "NEW KIT" chapter (Compendium pp.25-27) |
| Freelancer's | No-minis 7, Progressive Difficulty 3, Escalating 3, Grid 1, Casualty tables 1 | **Difficulty Toggles, PvP, Co-op, AI Variations, Deployment Variables, Elite Enemies, Expanded Missions, Expanded Quests, Expanded Connections, Dramatic Combat, Terrain Generation, Detailed Injuries** |
| Fixer's | Factions 9, Salvage 6, Stealth 5, Street Fights 5, Intro Campaign 2, Prison Planet 1 | **Fringe World Strife, Expanded Loans, Name Generation** |

**"Gates nothing" has three meanings and they need different fixes.** Do not
conflate them:

1. **Missing** — no implementation (New Ship Parts, Psionic Equipment: no data
   file, no code).
2. **Transcribed but unwired** — the tables exist and nothing applies them.
   Confirmed for Expanded Missions (`src/data/compendium_missions_expanded.gd`,
   `data/RulesReference/ExpandedMissions.json`) and the Difficulty Toggles
   (`src/data/compendium_difficulty_toggles.gd`,
   `data/compendium/difficulty_toggles.json`). Same defect family as the whole
   Core Rules audit: data correct, no consumer.
3. **Shipping ungated** — implemented and reachable without owning the pack.
   That is **revenue leakage**, not a gap, and it is the one category that gets
   *worse* the more we build.

Classifying all 19 is the first task in §3 Phase 0.

---

## 2. The Compendium backlog is unmeasured, and the 40 audit rows undercount it

The Aug 2 audit used **eight parallel auditors, one per subsystem**. Exactly one
of them — `factions-world-compendium` — covered the Compendium, which is a
**236-page book**. That auditor found 20 open rows, essentially all in the
faction and Fringe World Strife chapters.

Chapters with **no audit rows at all**, cross-checked against the Compendium's
own contents page: New Training, New Bot Upgrades, New Ship Parts, Psionic
Equipment, PvP, Co-op, AI Variations, Escalating Battles, Dramatic Combat,
Detailed Injuries, Casualty Tables, Expanded Quests, Expanded Connections,
Expanded Loans, Name Generation.

**So "make the Compendium work" is not 40 rows, and I do not know what it is.**
Guessing a number here would be exactly the plan-built-on-assumption this project
forbids. The Core Rules number (143 findings) came from actually running the
audit; the Compendium deserves the same instrument before it gets a schedule.

---

## 3. Phases

### Phase 0 — Compendium audit + flag triage · **DO THIS FIRST** · 1-2 sessions

Two deliverables, both cheap relative to what they de-risk:

**0a. Classify the 19 dead flags** into missing / transcribed-but-unwired /
shipping-ungated. Mechanical: for each flag, grep for the feature (not the flag),
check for a data file, check whether the code path is reachable without the flag.
Output is a table. **The "shipping ungated" set is a paid-content leak and should
be gated in the same session** — it is the only category that is pure loss today.

**0b. Run the audit method on the Compendium, per pack.** Same rules as Aug 2:
quote the book, cite `file:line`, state the player-visible consequence. Scope it
per pack so the output maps onto what is actually sold. Expect the row count to
land somewhere well above 40; the point of Phase 0 is that we stop guessing.

Only after 0b can Phases 3-5 below be scheduled honestly.

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

### Phase 3 — Fixer's Guidebook · largest pack backlog · sized by Phase 0

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

### Phase 4 — Freelancer's Handbook · worst flag ratio (12 of 17 dead) · sized by Phase 0

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

### Phase 5 — Trailblazer's Toolkit · smallest backlog · likely 1 session

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
| 1 | **0a** flag triage + gate the leaks | ½ session | Stops paid content shipping free; mechanical |
| 2 | **0b** Compendium audit per pack | 1 session | Everything below is unschedulable without it |
| 3 | **1** ledger hygiene | ½ session | −5 to −8 rows, no code |
| 4 | **5** Trailblazer's "NEW KIT" | 1 session | First unlock that can be called *done* |
| 5 | **2a-2e** Core Rules loop | ~3 sessions | The free floor under the paid content |
| 6 | **3** Fixer's Guidebook | sized by 0b | Largest backlog; faction generation gates the rest |
| 7 | **4** Freelancer's Handbook | sized by 0b | Worst flag ratio; needs the PvP/Co-op call first |
| 8 | **6** Red & Black Zone | 1-2 sessions | Core Rules, no unlock, endgame |
| 9 | **4 (blocked half)** post-battle events | 1 session | When the Story Track tree clears |

**Definition of done, revised:** not "73 → 0". It is **every flag a player can
pay for does something, and every flag that does nothing is either finished or
removed.** A dead toggle inside a purchased unlock is the single worst thing this
app can show a tester or a publisher.
