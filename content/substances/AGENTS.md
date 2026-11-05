# Substances and reactions: the interaction ledger

Every file under `content/substances/` and `content/reactions/` that this
convention has reached opens with an **interaction ledger**: Luau comments
saying which chemistry the pack builds, which of it needs a catalyst, and
which real chemistry it knows about and deliberately does not simulate.
The ledger is comments only. It is not a data module, a spec or a doc, and
nothing loads it; `trufflepig-agent refs <reaction id>` finds every row
that cites a reaction.

## Format

The ledger follows the file's title line and a blank comment line, and
ends at the next blank comment line (`--`). It has up to three sections,
always in this order and each at most once. A section with no rows is
left out, and so is a ledger with no rows at all.

```
-- interactions we use:
--   <equation> (<reaction id>)
-- interactions which require catalysts:
--   <equation>, catalyst <substance id>[, blocked by <substance id>] (<reaction id>)
-- interactions we know exist but don't need:
--   <equation or process>: <why it is not built>
```

- A **heading** is spelled exactly as above, colon included, on its own
  line after `-- `.
- A **row** is indented three spaces (`--   `). A row that wraps continues
  on lines indented five spaces (`--     `).
- An **equation** is ASCII, written in formulas with integer coefficients
  and ` -> `: `CH4 + 2 O2 -> CO2 + 2 H2O`. A phase mark `(g)`, `(l)` or
  `(s)` follows a formula only when the reaction's gate depends on that
  phase. A species with no formula is written as its substance id
  (`tholin`).
- A **reaction id** is the `id` of a `content/reactions/` file, which is
  also its file name, written bare in the row's last parentheses:
  `(methane_fire)`.
- A **catalyst** or **blocker** is a substance id as its file declares it,
  with no phase suffix (`iron`, `sulfuric_acid`). The reaction file holds
  the amount and the phase.
- A **known** row has no reaction id, because no reaction exists. Its
  reason is one clause: what the pack would need first, or why the
  outcome does not matter to play. A physical process that has no
  equation is named in a few words (`N2 dissolving in liquid CH4`).

## Which file carries a row

- **A reaction file** carries exactly one row: its own, under `use` or
  `catalysts`. It is the home of the reaction's numbers (gates, window,
  enthalpy); the row is its index line.
- **A substance file** repeats, word for word, the `use` and `catalysts`
  rows of the reactions it is most about: the fuel a fire burns, the
  feedstock a synthesis consumes, the reactant the reaction exists for.
  Each reaction is repeated in one substance file, never in every
  participant: oxygen does not list every fire.
- **A known row** lives in one substance file only, the substance it is
  most about. The `known` sections are the one home for chemistry the
  pack has decided not to simulate. A doc that mentions such a choice
  cites the substance file, and a new one is added there, never to a doc.

## Example

The head of `content/substances/petrochemicals/methane.luau`:

```
-- Methane: CH4, the cold world's air, its seas and its fuel.
--
-- interactions we use:
--   CH4 + 2 O2 -> CO2 + 2 H2O (methane_fire)
-- interactions which require catalysts:
--   CH4 -> C + 2 H2, catalyst iron (methane_pyrolysis)
-- interactions we know exist but don't need:
--   CH4 + H2O -> CO + 3 H2: steam reforming makes CO, which the pack
--     has no substance for
--
-- Numbers are the NIST WebBook's ...
```

Its reaction file, `content/reactions/methane_fire.luau`, opens with the
same row under the same heading.
