# Process: Adopting From Upstream — Validate the Base Before Patching Gaps

This doc exists because of a concrete, expensive miss during OP15 (`infiniti`,
SM8850 / **canoe**) bringup. Read it before porting or adopting anything from a
community org or other upstream.

## The miss (worked example)

This device tree was hand-assembled off a **mismatched base**: the original bringup
tracked the SoC as **`sun`** (which is actually SM8750, the *previous* chip) and
also carried an ad-hoc **`sm8850`** label, while the real platform codename is
**`canoe`** (SM8850, QTI `UM_6_12_FAMILY`). The community org
`OnePlus-SM8850-Development` had the correct canoe base the entire time.

Three competing identifiers — `sm8850`, `sun`, `canoe` — coexisted in one tree.
That coexistence is the **fingerprint of a wrong/un-normalized base**, not a set of
local bugs. It was misread, repeatedly, as a series of independent gaps to patch:
211 missing paths, 144 missing libs, a post-fs-data freeze, naming oddities. Every
one of those was a *symptom* of the base divergence that was never surveyed.

Signals that were looked at and reasoned past:
- `TARGET_BOARD_PLATFORM := canoe` upstream vs `:= sm8850` here — noted, moved on.
- A `"sun"` branch in a vintf/init `select` — dismissed as "harmless, never fires."
- `TARGET_SEPOLICY_DIR := canoe` — a one-site override injecting the correct codename
  at exactly one lookup. It **proved** canoe was right and should have **screamed**
  the identifier was wrong everywhere. Patching that one site suppressed the signal.
- The org's `sm8850-common` repo was seen sitting next to `sepolicy_vndr` and *not*
  investigated, because "ours is heavily diverged, 30+ tier-1/2 commits."

The mechanism was **sunk-cost frame anchoring**: the volume of accumulated local
patching was treated as evidence the foundation was sound — when all of it was
*downstream* of the wrong base. More confident local reasoning makes this worse, not
better: richer justifications make a wrong frame feel more solid.

## The rules

1. **Competing platform / codename / identifier strings in one tree
   (`sm8850` + `sun` + `canoe`) = wrong base. STOP and audit the base.** Do not
   explain each occurrence away as locally inert.
2. **A targeted override that injects the "correct" value at one site is a global red
   flag, not a fix.** If the right value is needed there, the identifier is wrong
   everywhere — normalize globally instead.
3. **Patch volume is not evidence the base is sound.** Heavy local divergence is a
   reason to audit the base, not defend it. Sunk cost is a bias, not a signal.
4. **Adoption starts at the manifest/repo level, before any file-level work:**
   - Which repos does the upstream actually use (their manifest / `lineage.dependencies`)?
   - Which revisions/branches and platform-codename convention?
   - For each of our trees: real fork, hand-populated snapshot, or plain-LineageOS
     where upstream ships a diverged fork? (Measure divergence — `compare` / ahead-by.)
   - Normalize the platform identifier across the whole tree.
   - *Then* — and only then — chase file-level gaps.
5. Periodically ask outright: **"Am I optimizing within a frame I never validated?"**
   — especially when a fix list keeps growing.

## Checklist for "adopt X from the org"

- [ ] Pull the org's manifest + `lineage.dependencies`; list every repo + revision.
- [ ] Diff that set against our tree: missing repos, wrong-upstream forks, untracked
      hand snapshots, ahead/behind on shared repos.
- [ ] Confirm the single canonical platform codename and normalize it everywhere
      (board config, props, config selection, init scripts) in one pass.
- [ ] Prefer rebasing our tree onto the upstream base + overlaying only genuine deltas
      over carrying a hand-assembled snapshot forward.
- [ ] Only after the base + identifier are confirmed correct, address remaining
      file-level gaps.

See also the agent memory `feedback_question_the_base_before_patching` and
`project_may30_platform_naming_audit` for the full incident + the canoe convergence.
