# Boilerplate / LOI / MOU review checklist

**Owner**: Elijah Rhyne
**Purpose**: Defensive checklist for reviewing Modiphius's boilerplate licensing contract and any LOI/MOU/Definitive Agreement that derives from it. Applied BEFORE signing anything binding.
**Posture**: This is not adversarial review. Modiphius is a small publisher acting in good faith. The checklist exists because boilerplate contracts are written for the publisher's interests by default, not because either party is acting in bad faith. Negotiating clauses to Phase-2-preserving language is normal partnership hygiene, not hostile.

## Why this checklist exists

Per Chris's May 8 reply (Entry #8 in `MODIPHIUS_CORRESPONDENCE_JOURNAL.md`):

> "We have a boilerplate agreement that will be used as the basis for the contract once the MOU is agreed."

Modiphius's boilerplate becomes the contract foundation. Boilerplate language is by definition pre-written for the publisher's typical needs across past deals, none of which were necessarily structured around:

- A solo developer doing platform R&D work
- A multi-deal arc (Phase 1 = prove thesis, Phase 2 = lock-in conversation, Phase N = additional IPs)
- A developer who needs to preserve leverage for Phase 2 negotiation

The checklist ensures Phase 1 LOI language does not foreclose Phase 2 negotiation leverage.

**Critical rule**: If a clause below appears in the boilerplate with red-flag language, do NOT sign without modification or explicit understanding. The cost of pausing to negotiate is low. The cost of signing through is potentially years of constrained negotiation leverage.

## Phase-2-closing clauses (the critical seven)

### 1. Engine / platform code ownership

**Red flag language**:

- "All software developed under this agreement shall be the property of [Publisher]"
- "Developer assigns all right, title, and interest in [Game] and the underlying engine/platform to [Publisher]"
- "[Publisher] shall own all intellectual property created under this Agreement"
- Any clause that doesn't carve out engine/platform code as Developer-retained

**Why this matters**: The GDScript platform code is the foundation for the T3 multi-project R&D thesis. If Modiphius owns the engine, every subsequent IP integration becomes their unilateral decision (or theirs alone to negotiate). This eliminates Phase 2 leverage entirely.

**Target language**: Modiphius licenses the IP-specific game content (5PFH-branded code, art, text, world-building); Developer retains ownership of the generic platform / engine / framework code. License back to Modiphius for use on derivative Modiphius projects only with Developer's involvement.

### 2. Exclusivity

**Red flag language**:

- "Developer shall not develop similar products for any other tabletop publisher during the Term"
- "Exclusive engagement with [Publisher]"
- "Developer agrees not to work on competing products"

**Why this matters**: Solo developer income diversification matters. Exclusivity locks Elijah into Modiphius for the contract term whether Phase 2 conversation goes well or not. Strips negotiation leverage.

**Target language**: No exclusivity on similar-genre products. Only restriction is on the specific Modiphius-licensed IPs (which is reasonable: don't build a competing FROM HOME companion app for someone else). Even on those, time-bounded to active Phase 1 development, not perpetual.

### 3. IP-grab language (re-use of platform code without Developer)

**Red flag language**:

- "[Publisher] may use the software developed hereunder for additional products without further obligation to Developer"
- "[Publisher] retains the right to license/sublicense the platform to third parties"
- "[Publisher] may engage additional developers to extend, modify, or derive products from the platform"
- Anything that lets Modiphius use the platform for Star Trek Adventures / Achtung Cthulhu / Fallout integrations WITHOUT engaging Elijah

**Why this matters**: This is the explicit Phase 2 closing move. If Modiphius can take the platform for other IPs without Elijah, the T3 multi-project R&D thesis flips from "Elijah's career foundation" to "Modiphius's free platform asset." Career-pivot stake evaporates.

**Target language**: Modiphius may not use the platform for additional IP integrations without engaging Developer on commercial terms to be negotiated for each subsequent project. ROFR (right of first refusal) for Developer on platform-derived products is acceptable; mandatory engagement is preferable.

### 4. Non-compete

**Red flag language**:

- "Developer shall not, during the Term and for [N years] thereafter, engage with any competitor"
- "Non-compete radius covering [tabletop game companion apps / solo RPG digital tools / similar genres]"
- Geographic non-compete clauses

**Why this matters**: Solo developer needs portfolio flexibility. Non-compete clauses are increasingly disfavored under US law (and California specifically bans most), but UK contracts may include them. Block or limit aggressively.

**Target language**: No general non-compete. At most, narrow exclusivity on the specific licensed IPs while actively under contract. No post-termination restrictions.

### 5. ROFR (Right of First Refusal) on Phase 2 terms

**Red flag language**:

- "[Publisher] shall have the right of first refusal on any future digital products by Developer"
- "Developer grants [Publisher] first option on subsequent projects"
- "Match-or-better clause" on Developer's other deals

**Why this matters**: ROFR sounds reasonable but it's leverage extraction. It forces Developer to bring Phase 2 terms to Modiphius first, on whatever terms Modiphius offers. Modiphius can then either accept Developer's terms or reject and let Developer go elsewhere. Either way, Developer can never get competitive bids without first signaling them to Modiphius.

**Target language**: No ROFR. Acceptable substitute: "Both parties agree to discuss expanded scope in good faith if Phase 1 deliverables are met." This is the Phase 2 placeholder language from the May 18 talking points. Names the conversation without granting leverage.

### 6. Termination + IP reversion

**Red flag language**:

- "Upon termination, all developer deliverables remain with [Publisher]"
- "Developer shall have no rights to any work product upon termination"
- "Termination for convenience clauses without compensation"
- One-sided termination rights (Modiphius can terminate at will; Developer cannot)

**Why this matters**: What happens to your platform if the partnership ends? Can Modiphius walk away and keep your code? Can you walk away and use the engine for other projects?

**Target language**: 

- Mutual termination rights (either side, with notice)
- On termination, IP rights revert: Modiphius retains rights to 5PFH-specific licensed content; Developer retains rights to platform / engine code; revenue accounting reconciled to termination date
- Pro-rata recoupment treatment if Modiphius has contributed budget that hasn't yet been fully recouped (their share carries forward or is forgiven based on termination reason)
- No "termination for convenience" without compensation to Developer (the work is already done)

### 7. Audit rights + reporting accuracy

**Red flag language**:

- No audit rights mentioned (silent treatment is bad)
- "[Publisher] shall report revenue annually" (annual reporting is too long)
- "[Publisher] determinations of net receipts shall be final and binding"
- One-sided audit obligations (Developer must allow audits but cannot conduct them)

**Why this matters**: In a structure where Modiphius controls the revenue counting (Steam payouts flow to Modiphius's bank account, Apple/Google to Modiphius's developer accounts), Developer's only protection on accurate accounting is audit rights. Without them, Modiphius could under-report or mis-categorize and Developer would never know.

**Target language**:

- Quarterly revenue reporting with itemized breakdown by SKU/platform
- Developer has right to audit Modiphius's records on reasonable notice (annually, or in response to specific concerns)
- Audit costs borne by Developer if findings are within tolerance, by Modiphius if findings are materially adverse to Developer
- "Net receipts" definition explicit and verifiable from platform-store payout records

## Other clauses worth careful review

### Maintenance fee mechanics (post-recoupment quarterly carve-out)

Make sure the LOI/MOU language captures:

- **Carve-out is FROM TOP**: maintenance fee paid to Developer before 50/50 split, not after
- **Real number locked**: the Chris-illustrative $1 was an example. Final number should be in the contract. Anchor: $2-3K/quarter per `MEETING_PREP_2026-05-18.md`
- **Fee adjustment mechanism**: inflation adjustment or periodic renegotiation, OR explicit "fee fixed for Term"
- **What triggers maintenance work**: tied to ongoing-dev availability, not a guaranteed-hours commitment that becomes a contractual obligation

### Recoupment mechanics (Reading B confirmed structure)

Make sure the LOI/MOU language captures:

- **$X = total dev budget figure** (final number locked)
- **Recoupment from net receipts** (NOT gross — "net" must be defined; platform fees, refunds, chargebacks all deductible before counted toward recoupment)
- **100% to Developer until recouped** (explicit)
- **50/50 split begins at recoupment milestone**, not at some other trigger

### Pro-rata recoupment (if Modiphius contributes budget)

Make sure the LOI/MOU language captures:

- **Pro-rata calculation method**: Modiphius's contributed share of total budget vs. total $X figure
- **Modiphius contribution trigger**: when does this kick in? Per Chris May 13: "a little time before we can confirm and will be dependant on the final proposed product." LOI should at least name the decision point.
- **No automatic pro-rata**: Modiphius's contribution should be a discretionary act with documented dollar amount, not implied or assumed.

### Active marketing commitment

Make sure the LOI/MOU language captures Chris's May 5 verbal commitment:

> "We would actively market this as a product, with a release plan, regular marketing support and build it in to future product development plans."

In writing, this should at least include:

- Newsletter inclusion at launch + key milestones
- Social media support
- Modiphius web store integration
- Store-page collaboration (Steam page, Apple/Google listings)
- "Future product development plans" inclusion (supports T3 thesis)

Specific deliverables can be soft; the COMMITMENT to active marketing should be hard.

### Governing law / jurisdiction

Per Entry #3a Item 5 ask, this is a real question:

- **Modiphius default**: England and Wales jurisdiction (UK company)
- **Developer concern**: US-based developer; UK litigation is expensive and inconvenient
- **Compromise options**:
  - Arbitration clause (faster, cheaper than court)
  - Mutual jurisdiction (either party's home court)
  - Choice-of-law England and Wales, choice-of-forum US (less common but possible)

Not blocking, but worth understanding before signing.

### IP attribution requirements

Make sure the LOI/MOU language captures:

- Exact copyright line ("© [year] Modiphius Entertainment Ltd. All rights reserved.")
- Trademark notices ("Five Parsecs From Home™ is a trademark of Modiphius Entertainment")
- "Used under license" phrasing
- Where attribution appears (splash screen, About panel, store listings, marketing materials)
- Modiphius logo placement requirements
- Developer attribution (Reptarus / Elijah Rhyne) explicitly required somewhere

### Sublicensing language for platform stores

Per Entry #8 Item 5, Chris asked us to provide samples. This is real research work:

- **Steam Distribution Agreement** sublicensing requirements
- **Apple Paid Apps Agreement** sublicensing requirements
- **Google Play Developer Distribution Agreement** sublicensing requirements

Each platform requires Modiphius to grant Developer rights to sublicense the licensed IP for that platform's distribution. Without this language, the app cannot legally be distributed on those stores.

Hold this research for post-LOI per Phase-1-aligned sequencing, but flag it as load-bearing for MOU drafting.

## What to do at each stage

### Before LOI signing

- **Boilerplate sample obtained and reviewed** against this checklist
- **Phase-2-closing clauses (the seven above) explicitly addressed**: either modified, explicitly understood, or noted for MOU-stage negotiation
- **LOI scope confirmed**: 5PFH + 5L digital per Chris May 8
- **Phase 2 placeholder language proposed and accepted** in LOI
- **Recoupment + maintenance fee structure captured** in LOI in line with May 13 walkthrough

### Before MOU drafting

- Sublicensing language samples provided to Modiphius (per Chris May 8 ask)
- Active marketing commitment specifics discussed
- Audit rights specifics agreed
- Termination + IP reversion mechanics agreed
- Governing law / jurisdiction agreed

### Before Definitive Agreement

- All MOU items hardened into legally binding form
- Legal review by US attorney on Developer side (recommended)
- Legal review by Modiphius's UK counsel on Publisher side
- Sign before Steam EA goes live

## Posture reminders

- **Negotiate clauses, not the relationship**. Modiphius is acting in good faith. The boilerplate is a starting point, not an opening salvo.
- **Frame asks as Phase-2-preserving, not Phase-1-extracting**. Chris already wants this to be a multi-project partnership. Clauses that close Phase 2 don't serve his strategy either.
- **Get legal review on the developer side before signing anything binding**. US attorney with experience in IP licensing and indie game development. Cost is modest, downside protection is significant.
- **No em dashes** in any contract drafting language we propose (style rule applies to outbound).
- **Grace in posture, honesty in substance**: the checklist is honest about what protects Phase 2. The conversation about each item is collaborative, not adversarial.

## Cross-references

- `docs/MODIPHIUS_CORRESPONDENCE_JOURNAL.md` Entry #8 (Chris's May 8 boilerplate confirmation), Entry #9 (May 13 structural clarification)
- `docs/MEETING_PREP_2026-05-18.md` (LOI talking points)
- `docs/PARTNERSHIP_DEAL_STRUCTURE_RESEARCH.md` (industry-standard clause patterns)
- Memory: `feedback_phase1_prove_phase2_lockin.md` (the arc rule this checklist defends)
- Memory: `feedback_negotiation_grace_posture.md` (the posture this checklist operates within)
