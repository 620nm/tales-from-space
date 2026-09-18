# Petrochemical lab

Naphtha is a liquid hydrocarbon blend represented by one C8H16 bookkeeping
unit. Its 112.22 g/mol mass and 0.75 g/mL density are gameplay conventions;
the unmodeled liquid phase keeps fuel, solvent and feedstock in a beaker.
The registry's rounded carbon dioxide mass leaves a small bookkeeping
rounding error in the gas synthesis step.

## The recipe ladder

Every recipe is reachable from the dispenser shelf plus bottles or gas
canisters and the reaction chamber:

| product | legs | bench |
| --- | --- | --- |
| naphtha | 8 carbon dioxide + 24 hydrogen → 1 naphtha + 16 water | 450–470 K, sealed vessel |
| polymer resin | naphtha, with polymer catalyst | 360–380 K |
| wax | naphtha, with sulphuric acid | 370–400 K |
| toner | 4 polymer resin + carbon + wax | 320–340 K |

The naphtha gas route folds reverse water-gas shift and Fischer–Tropsch
upgrading into one reaction. It is intentionally easier than an industrial
refinery: charge a sealed vessel with the two gases and at least 0.025 mol
of synthesis catalyst, heat it to 450–470 K, then cool, open the flask valve with self-use, and pour
the liquid naphtha. The catalyst remains in the vessel and is not consumed.

Naphtha can be poured directly from the dispenser for a short round. The
gas route exists for players who want to turn atmos byproducts into a fuel
and polymer feedstock. It does not require a second separation machine.

The resin route consumes one naphtha unit for one equal-mass polymer resin
unit when at least 0.05 mol of polymer catalyst is present. The wax route
uses sulphuric acid as its reusable catalyst at a slightly higher window.
If both catalysts are present, a blocked gate suppresses wax while polymer
catalyst selects resin. The polymer route does not block residual synthesis
catalyst, so a single vessel can go from gas synthesis to resin.

Toner is a warm solid composite: four resin units, one carbon-black unit,
and one wax unit become one toner unit. Its 573.11 g/mol bookkeeping mass
is the rounded weighted sum of those inputs. The mixing window stays below resin
and wax synthesis, so cooling and packaging do not restart either route.
The printer and fax consume toner as their existing resource, while a
toner reaction makes the powder from a basic beaker lab.

Acetone uses a separate oxidation step: naphtha + 2 oxygen → 2 acetone +
2 carbon + 2 water in a sealed bottle at 280–315 K, with at least 0.025 mol
of salt. This restores an oxygen-bearing input and preserves the formal
hydrocarbon atom balance. Neither the synthesis water nor its catalyst can
select acetone on their own.


## Equipment and products

The Chemistry Lab on Chillstation supplies the dispenser, reaction chamber,
chem packager, beakers, two filled resin pellets, and a sealed lab flask
with a gas supply. Use the
large 2 L flask for synthesis; an ordinary beaker is sufficient downstream.
A valve stroke transfers at most 2 mol of gas. Charge the flask three times
from the CO2/hydrogen supply to obtain a useful batch, then add 0.025 mol
synthesis catalyst and set the reaction chamber to 460 K. Keep the valve
closed while charging and heating; open it after cooling to pour. For resin,
leave the batch in the flask, add 0.05 mol polymer catalyst, heat to 370 K,
and dock the flask in the packager to recover the solid product.

The packager recovers pure solid products while leaving liquid catalysts
and water in the vessel. A resin pellet contains 0.1 mol of polymer resin;
a plastic sheet uses the same amount. A toner cartridge uses 0.025 mol of
toner and supplies 30 printing charges. Other solids prevent packaging.

The toner batch takes 0.1 mol resin, 0.025 mol carbon, and 0.025 mol wax.
Resin pellets provide a shortcut to the binder; making resin from naphtha
remains available. Naphtha and both dedicated catalysts are dispenser
substances so the gas route is optional during a short round.

## Model boundary

The gas route combines CO2 conversion and hydrocarbon synthesis into one
selective reaction. Real processes use catalyst beds and separate their
products; this lab abstracts both selectivity and processing temperatures.
The inspiration is the [ARPA-E CO2-to-olefins fuel pathway](https://arpa-e.energy.gov/programs-and-initiatives/search-all-projects/echo-fuels-electrified-co2-hydrogenation-olefins-liquid-hydrocarbon-fuels).
The resin, wax, and toner amounts are bookkeeping units for mixtures, not
claims that these materials are single molecules.
