-- Carbon dioxide. tg: `/datum/chemical_reaction/carbondioxide`,
-- 3 CO2 from 1 carbon + 2 oxygen, `required_temp = 777` ("pure carbon
-- isn't especially reactive"), no thermic_constant
-- (recipes/others.dm:143-147).
--
-- THE DEPARTURE: the atoms balance. C + O2 -> CO2 is one for one for
-- one, and every participant here is a real molecule -- carbon the
-- element, oxygen the diatomic gas the station breathes, and the same
-- carbon dioxide a fire makes -- so there is nothing fictional for
-- tg's 1:2:3 to stand in for. The window and the reason for it are
-- tg's, verbatim.
--
-- IT NEEDS AN ATMOSPHERE, not a quantity. Oxygen is a permanent gas
-- and arrives from a canister, so the recipe runs in a sealed vessel
-- with a gas share over solid carbon; the gate says exactly that in
-- the unit a gauge reads -- fifty kilopascals of oxygen partial
-- pressure, which is half a room's worth and about what a bottle
-- charged off a port carries. `min` over the activities means the run
-- then paces itself against whichever of the two is scarcer
-- (docs/CHEMISTRY.md 5).
--
-- Bell by the documented mapping (docs/CHEMISTRY.md). tg's required
-- temperature is ABOVE its default optimal, so the rule's second clause
-- applies -- opt_lo = temp_min + 5 -- and the plateau starts as soon as
-- the window opens:
--   temp_min = 777, opt_lo = 782, opt_hi = 900 (default overheat),
--   temp_max = opt_hi + max(opt_lo - temp_min, 20) = 920
return {
    id = "carbon_dioxide",
    reactants = { ["carbon:solid"] = 1.0, ["o2:gas"] = 1.0 },
    products = { ["co2:gas"] = 1.0 },
    energy = 0.0,
    requires = {
        { partial_pressure_at_least = { substance = "o2", kpa = 50.0 } },
    },
    rate = {
        bell = {
            temp_min = 777.0,
            opt_lo = 782.0,
            opt_hi = 900.0,
            temp_max = 920.0,
            exponent = 2.0,
            -- Rescaled for the activity law: 0.05 / 8 (docs/CHEMISTRY.md §5).
            base_rate = 0.00625,
        },
    },
}
