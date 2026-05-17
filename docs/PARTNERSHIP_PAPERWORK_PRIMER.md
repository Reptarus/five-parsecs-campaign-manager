# Partnership paperwork primer

**Owner**: Elijah Rhyne
**Purpose**: Conceptual mental model for how publishing-partnership paperwork progresses from initial agreement to binding contract. Written for Phase 1 (Modiphius / 5PFH Digital) but generalizes to Phase 2 (additional IP integrations).
**Status**: General reference, not legal advice. Get actual legal counsel before signing anything binding.

## The three-stage progression

In a typical publishing-partnership deal (and in Modiphius's process specifically per Chris's May 8 reply), paperwork moves through three distinct stages. Each stage locks in more specifics, requires more commitment from both sides, and has a higher walk-away cost.

The stages exist because both parties need a way to:

1. **Agree the deal is worth pursuing** before investing in legal drafting (LOI stage)
2. **Settle the operational specifics** while building real working trust (MOU stage)
3. **Lock everything legally enforceable** before either side has too much at stake (Definitive Agreement stage)

Each stage answers different questions and creates different obligations.

## Real estate analogy that maps cleanly

| Real estate equivalent | Partnership paperwork | What it locks in |
|-----------------------|----------------------|------------------|
| **Offer letter** ("I'll buy your house for X if we can agree on basic terms") | **LOI** (Letter of Intent) | The intent + key terms (price, scope, timeline). Walk-away cost is reputational, not legal. |
| **Purchase agreement** ("Here's what we're each doing between now and closing") | **MOU** (Memorandum of Understanding) | Specific obligations on both sides, milestones, payment schedule. Partly enforceable. Real money in some clauses. |
| **Closing documents** ("Final binding contract, all edge cases handled") | **Definitive Agreement** (from boilerplate) | Everything. Termination, breach, audit, IP reversion, acquisition scenarios. Fully binding. Significant walk-away cost. |

You can't skip stages. You can't sign the Definitive Agreement without the LOI and MOU having done their work first.

## Stage 1: Letter of Intent (LOI)

### What it is

A short document (typically 1-3 pages, sometimes up to 5-6) capturing the agreed shape of the deal. Mostly non-binding. Signals both parties intend to proceed and roughly on these terms.

### What gets decided

- Deal structure (e.g., for our Modiphius deal: $X recoupment + 50/50 split + maintenance fee)
- Scope (5PFH + 5L digital projects, expandable via addendum)
- Rough timeline (Steam EA late Sept 2026)
- Key dollar figures (or at minimum agreed ranges)
- IP license outline (general scope; specifics drafted at MOU stage)
- Anticipated next steps and roughly when

### What does NOT get decided

- Payment milestones and triggers (MOU stage)
- Specific deliverables (MOU stage)
- Legal mechanics — termination, audit, jurisdiction, sublicensing, IP attribution — all Definitive Agreement stage
- Edge cases (what if acquisition, what if breach, what if either party can't deliver)

### What "non-binding" actually means

Most LOI clauses are non-binding INTENT to negotiate in good faith toward a definitive contract. But some LOI clauses are explicitly binding even when the rest isn't:

- **Exclusivity / no-shop**: You can't negotiate the same deal with another publisher during a defined window (typically 30-90 days)
- **Confidentiality**: Don't disclose deal terms publicly
- **Governing law for disputes about the LOI itself**: If you fight over what the LOI meant, this is the venue
- **Costs / break-up fees**: If either side walks, who pays for the legal work already done

Read each clause carefully. "This LOI is non-binding" at the top doesn't mean every clause is non-binding.

### The three gotchas

1. **Anchors set in LOI carry forward.** If you accept $25K $X in the LOI, getting it to $35K in the MOU is much harder. Mid-stage repricing reads as bad faith.

2. **Reputational cost is real cost.** Backing out of an LOI without strong reason burns the relationship. For Phase 1 / Phase 2 arc thinking, the relationship is the asset. Treat LOI signature as a real commitment even when the document says it isn't.

3. **The LOI sets the negotiation tone.** A clean, mutually-respectful LOI process means MOU and Definitive Agreement also go cleanly. A combative LOI means every subsequent stage is harder.

### Our current state on the LOI

Per `MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #8 (Chris's May 8 reply): "ys we can get LOI done as soon as agreement is confirmed."

The May 18 conversation is the bridge from "agree the shape" to "ready to write the LOI." Once that bridge is crossed, the LOI gets drafted (Modiphius-side, per Chris's wording), reviewed, and signed within 2-3 weeks per the Phase A.2 schedule.

## Stage 2: Memorandum of Understanding (MOU)

### What it is

A longer working document (typically 5-15 pages) that adds operational specifics to the LOI shape. Partly binding. The intermediate document between non-binding LOI and fully-binding Definitive Agreement.

### What gets decided

- **Payment milestones**: when does $X get paid (if paid), when does maintenance fee start, what triggers recoupment milestone events
- **Specific deliverables on both sides**: builds Modiphius's marketing-support commitment into specifics, names what Developer ships and when
- **IP attribution language**: exact copyright lines, trademark notices, "used under license" phrasing
- **Asset delivery from Modiphius**: what art, logos, materials get provided and when
- **Operational unblocks**: Monday.com setup, pricing approval workflow, app naming, store listing handoff
- **Working cadence**: weekly Gavin sync, bi-weekly strategic with Chris

### What does NOT get decided

- Full legal machinery — that's the Definitive Agreement
- Specific termination scenarios beyond high-level intent
- Audit rights specifics
- Edge case handling (acquisition, force majeure, IP disputes, etc.)

### Our anticipated MOU stage

Per `MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #3a Item 1: MOU drafting during alpha + refinement, roughly Jun-Jul 2026. Aligns with closed alpha (May 25 - early Jul) running in parallel with MOU operational-specifics conversation. Operational items deferred during Phase A become MOU agenda.

## Stage 3: Definitive Agreement (derived from boilerplate)

### What it is

The full legal contract. Long (20-50+ pages typically). Fully binding. Once signed, this is the document that governs the partnership for its entire term.

The "boilerplate" Chris referenced (Entry #8 May 8) is the template Modiphius uses as the starting point for this document. It's pre-written by their legal team across past deals. We negotiate modifications to align with our Phase 1 / Phase 2 arc.

### What gets decided (everything)

- IP license grant scope (game mechanics, text, terminology, artwork, trade dress)
- Sublicensing rights to platform stores (Steam, Apple, Google all require this)
- Term and termination (how long the contract runs, when either side can exit)
- Termination + IP reversion (what happens to deliverables on termination)
- Audit rights (Developer's ability to verify Modiphius's revenue reporting)
- Governing law and jurisdiction (England and Wales vs US)
- Confidentiality (post-launch)
- Representations and warranties (each side asserts certain things are true)
- Indemnification (who covers legal costs if a third party sues)
- Force majeure (what happens if events outside either party's control disrupt the deal)
- Assignment (can either side transfer the contract to a successor — relevant if Modiphius gets acquired)
- Phase-2-closing clauses (engine ownership, exclusivity, IP-grab, non-compete, ROFR — see `BOILERPLATE_REVIEW_CHECKLIST.md`)

### When this stage happens for us

Per `MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #3a Item 1: Definitive Agreement during beta + EA prep, roughly Aug-Sep 2026. **Must be signed before Steam EA goes live.** Cannot launch a real revenue-generating product on incomplete paperwork.

### Why the boilerplate review checklist exists

`BOILERPLATE_REVIEW_CHECKLIST.md` is the protection layer for this stage. Seven critical Phase-2-closing clauses to watch for, plus other clauses worth careful review. Read the checklist before the boilerplate sample lands so you know what to look for.

## The progression as a single timeline (our deal specifically)

```
NOW (2026-05-13)
   │
   ▼
May 18-22:  Bridge conversation
            Land $X range, maintenance fee range, scope confirmation, Phase 2 placeholder
            (No paperwork signed yet — this is "agree the shape")
   │
   ▼
End of May / early June:  LOI signed
            Stage 1 — captures key terms, mostly non-binding except specific clauses
            Modiphius drafts; Developer reviews; both sign
            ⚠ Three gotchas apply
   │
   ▼
June - July:  MOU drafting (during closed alpha)
            Stage 2 — adds operational specifics, partly binding
            Most operational items from Apr 29 13-item list get resolved here
            ⚠ Phase-2-closing clauses start getting tested
   │
   ▼
Aug - Sep:  Definitive Agreement (during beta + EA prep)
            Stage 3 — full legal contract, fully binding
            Boilerplate review checklist applies here
            ⚠ Must be signed before Steam EA launch
   │
   ▼
Late Sep 2026:  Steam EA launches
            Partnership-on-paper is complete
            Phase 1 = prove the thesis begins in earnest
```

## How this differs across publishers

Some publishers consolidate stages:

- **Two-stage**: LOI + Definitive Agreement (skipping MOU). More common with small / fast-moving publishers. Higher risk of operational details getting handled informally.
- **Single-stage**: Just sign the Definitive Agreement directly. Rare for indie deals. More common with established developers who've worked with the publisher before.

Some publishers add stages:

- **Term Sheet** between LOI and MOU: a more detailed financial structure than the LOI but less detailed than the MOU
- **Side Letters**: separate documents addressing specific topics (e.g., a marketing-cooperation side letter alongside the main Definitive Agreement)

Modiphius appears to use the standard three-stage progression per Chris's May 8 wording. Worth confirming verbally at May 18 that this is correct: "Just to make sure I understand your process — is the standard LOI then MOU then Definitive Agreement based on your boilerplate, or do you do it differently?"

## Phase 2 implications (additional IPs later)

When Phase 1 succeeds and Modiphius wants to do Star Trek Adventures / Achtung Cthulhu / Fallout / Dune integrations:

- **Each additional IP probably needs its own LOI → MOU → Definitive Agreement progression**, not just an addendum to the existing contract. Why: each IP has its own licensor (Paramount for Star Trek, Bethesda for Fallout, etc.) and Modiphius's relationship with each licensor has its own constraints.

- **Master Agreement option**: alternatively, a Master Services Agreement (MSA) between Developer and Modiphius could cover terms that apply across all IPs, with per-IP "Statements of Work" (SOWs) for the specifics. This is the cleanest structure for multi-IP platform R&D work but requires Modiphius to be comfortable with it.

- **Phase 2 placeholder in Phase 1 LOI**: per `feedback_phase1_prove_phase2_lockin.md` and `MEETING_PREP_2026-05-18.md`, we want a line in the Phase 1 LOI explicitly acknowledging the wider 5x-system / multi-IP conversation happens after Phase 1 succeeds. Names the next conversation without binding either side.

## What to do at each stage

### Now (pre-LOI)

- Review Modiphius's LOI template if Chris shares it (current Draft #C asks for this)
- Build informed asks for the May 18 call (per `MEETING_PREP_2026-05-18.md`)
- Hold operational items for post-LOI per Chris's sequencing

### LOI stage (next 2-3 weeks)

- Read EVERY clause, not just the obviously-binding ones
- Get legal review on the developer side before signing (US attorney with indie game / IP licensing experience)
- Confirm Phase 2 placeholder language is included
- Confirm scope is 5PFH + 5L digital with addendum mechanism for expansion
- Verify $X figure and quarterly maintenance fee figure are captured (or at minimum, agreed ranges)

### MOU stage (Jun-Jul)

- Resolve operational items deferred from Phase A
- Drive specifics on Modiphius's marketing-support commitment
- Lock IP attribution language
- Sublicensing language samples provided (per Chris's May 8 ask)
- Watch for Phase-2-closing clause precursors creeping in

### Definitive Agreement stage (Aug-Sep)

- Apply `BOILERPLATE_REVIEW_CHECKLIST.md` against the actual boilerplate language
- US attorney legal review (mandatory at this stage)
- Negotiate Phase-2-closing clauses to Phase-2-preserving language
- Sign before Steam EA launches

## Posture reminders across all stages

- **Grace in tone, honesty in substance** (per `feedback_negotiation_grace_posture.md`)
- **Phase 1 = prove the thesis. Phase 2 = lock-in.** Don't extract from Phase 1 in ways that close Phase 2 (per `feedback_phase1_prove_phase2_lockin.md`)
- **No em dashes in any drafting language** (per `feedback_no_em_dashes.md`)
- **The relationship is the asset.** Every paperwork stage either strengthens or weakens it.

## Cross-references

- `docs/MODIPHIUS_CORRESPONDENCE_JOURNAL.md` — chronological correspondence log, current paperwork-progression state
- `docs/MEETING_PREP_2026-05-18.md` — May 18 LOI-focused talking points
- `docs/BOILERPLATE_REVIEW_CHECKLIST.md` — Definitive Agreement stage protection
- `docs/BROADENING_SCOPE_SKETCH.md` — supports LOI scope conversation
- `docs/PARTNERSHIP_DEAL_STRUCTURE_RESEARCH.md` — industry context for deal structures
- Memory: `feedback_phase1_prove_phase2_lockin.md` — Phase 1 / Phase 2 arc rule
- Memory: `feedback_negotiation_grace_posture.md` — grace posture rule
