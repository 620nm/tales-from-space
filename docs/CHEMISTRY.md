# Chemistry

This pack's chemistry shelf: which substances exist, which the dispenser
pours, the recipe ladder they climb, the medicine trunk on top of it, and
the conventions the files apply. Every mechanism named here is the
engine's; what is on this page is the pack's own roster and numbers.

Engine contracts (sibling checkout `../lunatic`): `docs/CHEMISTRY.md` is
the schema and the departures cited by letter, `docs/chemistry/rate-law.md`
the bell mapping, `docs/chemistry/substances.md` the substance field table,
`docs/BENCH.md` the bench mechanisms, `docs/REACTIONS.md` the rate models
and clamps. Files: `content/substances/`, `content/reactions/`,
`content/machines/chem_dispenser.luau`, `content/lib/vessel.luau`.

---

## The conventions this pack applies (D2)

A substance whose real physics nobody needs gets a *stated convention*
rather than an invented measurement, and the file says so in a comment.
This pack's figures:

| what | figure | where it applies |
|---|---|---|
| `cv` | `100.0` J/(mol·K), written explicitly | fictional and mixture-shaped leftovers: `phenol`, `diethylamine`, `ash`, `oil`, `lube`, `thermite`, `space_cleaner`, `salglu` |
| `cv` | Dulong–Petit, `3R ≈ 24.9` | elements without a measured figure: `radium`, `lithium` |
| `cv` | measured, cited in the file | everything with real physics: `water` 75.3 liquid, `chlorine` 33.9, `iodine`/`ammonia`/`co2`/`uf6` per phase |
| `molar_mass` | a plausible round number | same set as the flat `cv` |
| `density` | `1.0` g/mL | anything whose real density nobody reads |

The loader's own silence default is `75.0`, not `100.0`: the shelf
convention is a number the file WRITES. A file that says nothing has taken
water's figure by accident rather than this pack's by choice.

## The recipe ladder

Every recipe in `content/reactions/` is reachable from the dispenser shelf
plus a bottle and the reaction chamber:

| product | legs | note |
|---|---|---|
| salt | sodium + chlorine | under a lid (`chlorine:liquid`, D3) |
| space cleaner | ammonia + water | under a lid |
| lube | water + silicon | — |
| oil | welding fuel + carbon | — |
| ash | oil | 480 K |
| lye | ash + water + carbon | — |
| thermite | aluminium + iron oxide | the oxide replaced tg's loose oxygen leg |
| acetone | oil + welding fuel | — |
| ammonia | nitrogen + hydrogen | off canisters, in a bottle |
| carbon dioxide | carbon + an oxygen share | 777 K, o2 ≥ 50 kPa, in a bottle |
| nitrous oxide | ammonia + an oxygen share | 525–575 K, o2 ≥ 100 kPa, in a bottle |
| diethylamine | ammonia + ethanol | under a lid |
| phenol | water + chlorine + oil | under a lid |

## The dispenser shelf

The shelf is tg's own (`default_dispensable_reagents`,
`chem_dispenser.dm:54-79`; `default_upgrade_reagents` at `:81-88`), trimmed
to what this pack has substances for and to what a source can honestly hand
over. The whole argument lives in the file's own comment; the summary:

- **Off, because permanent (D19).** Oxygen, nitrogen, hydrogen, fluorine.
  They rest as gas at every temperature the nozzle reaches, so a press over
  an open vessel is refused; they reach chemistry off a canister through a
  connector port instead. tg lists all four — this is the departure.
- **On, because condensable.** Chlorine and ammonia are refused over an
  open beaker and land in a sealed bottle as liquid under their own vapour
  pressure (about 8 atm and 8.6 atm), which is a reactant a bench can use.
- **Promoted off tg's upgrade tier.** Ammonia, ash, saltpetre. tg gates
  that half behind a servo above tier three (`chem_dispenser.dm:467-471`),
  but a shelf is a ROSTER and `parts.scale` moves numbers, not rosters. A
  machine that ships with a locked half ships mis-configured.
- **Off, because they have recipes.** Acetone, diethylamine and oil are on
  tg's upgrade tier and stay off: a bench where the first medicine is two
  presses and a stir has nothing to learn in it.
- **Off, because a tap should not pour it into an open glass.** Radium.
- **Off, because nothing names it yet.** Iodine.
- **On, and on no tg shelf — this pack's own pacing departure (D1).** Salt
  (the bench's first product; everything downstream would otherwise wait on
  a bottle of liquid chlorine) and iron oxide (thermite's oxidiser).
- **Off the shelf and out of the registry entirely.** Stable plasma: tg's
  twin of the atmos gas, and there is one id per molecule here (D3).

Everything off the shelf arrives in a bottle or off a canister.

## The medicine trunk

Five medicines ship, over three intermediates (phenol, acetone,
diethylamine) and tg's base element shelf:

| medicine | legs | `metabolism_rate` | per tick, at standard purity | its cost |
|---|---|---|---|---|
| salglu | water + salt + sugar | 0.0025 | 0.25 brute + 0.25 burn, on a 1-in-3 roll | — |
| multiver | ash + salt, at 400 K | 0.0025 | 0.5 tox | 0.5 onto the lungs |
| libital | phenol + saltpetre, at 700 K | 0.003 | 1.5 brute | — (lunatic-calibrated, half tg's 3) |
| aiuri | ammonia + sulphuric acid, warm | 0.0025 | 2 burn | 0.25 onto the eyes |
| epinephrine | phenol + acetone + diethylamine + chlorine | 0.00125 | 0.5 of each of the four pools, **only past `crit`** | — |

Multiver and aiuri are `/datum/reagent/medicine/c2`, tg's medicine that
costs you something whatever the dose (`cat2_medicine_reagents.dm:1`), and
both halves ship: the organ damage is `sim.damage_organ` on the socket tg
names. Epinephrine reads the `crit` threshold declared in
`content/bodies/human.luau` — a pack word, never an engine one.

What did NOT port, said once rather than per file: multiver's stacking
bonus (it reads the whole bloodstream per tick and the hook is handed one
substance), salglu's blood-volume nudge (there is blood and no content call
that moves it), and epinephrine's stun, stamina and `losebreath` half (no
pool holds them).

**The trunk is not a tree.** The schema is proven at every rung and the
rest of tg's ~40–50 medical reagents are data entry, as are its labelled
bottle variants and the beaker's large/gold/bluespace siblings. What the
trunk does NOT have is a branch: no chem that converts one damage type into
another, no addiction or overdose (no per-holder reaction state to hang a
threshold on), and no inverse chems, which are what tg's purity system is
FOR.

## The bell numbers this pack carries

The engine's mapping from tg's three numbers plus an exponent onto four
is `docs/chemistry/rate-law.md`. Applying it here:

- **The shared mixing bell, `100 / 280 / 900 / 1000`**, on every recipe tg
  defaulted. tg's default plateau starts at 500 K, which would mean nothing
  on this bench mixes at room temperature.
- **`100 / 700 / 900 / 1500` on salglu and epinephrine.** They are not
  defaulted recipes: tg's `/datum/chemical_reaction/medicine` sets
  `optimal_temp = 700` and `temp_exponent_factor = 1.2` on the whole
  medicine family (`recipes/medicine.dm:2-11`), and a recipe states a
  temperature if any of its ANCESTORS does. The bell there is about a
  quarter at room temperature rather than zero: a beaker on the deck works,
  and the reaction chamber is four times faster.
- **Overheat bands are tg's own, number for number.** `ash` 500/900,
  `carbon_dioxide` 782/900, `nitrous_oxide` 550/575. Leave them alone.
- **`fermentation` 293/303, `base_rate = 0.00025`.** A live culture that
  dies when it boils, tuned slower on purpose.

## The breath columns

The three thresholds and the clock are the engine's; which substances fill
each column is this pack's, declared per substance:

| column | substance | numbers |
|---|---|---|
| `breath.breathable` | `o2` | tg's `safe_oxygen_min` |
| `breath.waste` | `co2` | tg's `safe_co2_max` |
| `breath.toxic` | `plasma` | tg's `safe_plasma_max` |

All three are tg's verbatim. This shelf is where a gas somebody INVENTS is
calibrated.

## Specs

The gas-share recipes stand on the sealed-vessel charge
(`content/lib/vessel.luau`, the pack's shared-code seam):
`carbon_dioxide` wants 50 kPa of oxygen over its carbon and
`nitrous_oxide` 100 kPa over its liquid ammonia.

| spec | what it drives |
|---|---|
| `tests/gas_fill_test.luau` | the charge off a canister, and both gas-share recipes firing behind their partial-pressure gates |
| `tests/vessel_failure_test.luau` | the pressure and failure pass a charged shell runs under |
| `tests/chem_trunk_test.luau` | the medicine ladder end to end |
| `tests/chem_reactions_test.luau` | the recipe ladder |
| `tests/chem_dispenser_test.luau` | the shelf and the dial |
