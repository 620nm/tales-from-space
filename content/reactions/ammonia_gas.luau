-- The door between the bench's ammonia and the real one: warm liquid
-- ammonia past 700 K and it becomes `nh3`, as GAS.
--
-- This is the whole of policy D3 in one file (docs/reagents.md). The
-- reagent `ammonia` is a room-temperature liquid because tg's is and
-- because nitrous oxide is made out of it; `nh3` is the molecule with
-- a real phase curve, which boils at 239.8 K and therefore cannot sit
-- in a beaker. A reaction rather than a flipped curve, so a chemist
-- chooses when the change happens by choosing whether to heat the
-- vessel -- and every recipe that stands on the liquid keeps standing.
--
-- WHERE THE WINDOW GOES, and why it is so high.
--
-- The rule for both gas gates on this shelf: a gate sits above every
-- temperature its own reactant is worked at by something already
-- shipped. Ammonia's other consumer is nitrous oxide, and the bench
-- works ammonia HOT to get it -- 525-600 K is the n2o window itself,
-- and a chemist overshooting it holds ammonia at 650 K and comes back
-- down into the window from above (tests/chem_window_test.luau). So
-- anything below about 660 K would mean that making laughing gas
-- destroyed the ammonia on the way to making it.
--
-- 700/720, then: fifty kelvin of clearance over the hottest shipped
-- ammonia work, so the gesture is a deliberate dial rather than an
-- accident. This is a DEPARTURE from the effort plan's 330/345, which
-- assumed the gate only had to clear the shared mixing plateau; it does
-- not, and the n2o path is what proves it.
--
-- NO UPPER CUTOFF -- hotter only means faster up to the plateau. An
-- evaporation has a floor and no ceiling: past the gate, liquid ammonia
-- leaves as gas at ANY higher temperature. The old 900/920 put a lid on
-- it eighty kelvin under the heater's own 1000 K stop, and the engine
-- reads a bell as ZERO above `temp_max`, so a bench dialled all the way
-- up made nothing whatever. `opt_hi`/`temp_max` are parked at
-- 5000/10000 because the loader wants `opt_hi < temp_max` and will not
-- take an infinity; nothing on this station reaches either.
--
-- `energy = 0`: the change of substance costs nothing on its own, and
-- the heat of vaporization is where it belongs, on the nh3 phase curve.
-- Charging both would be paying for the same physics twice.
--
-- `volatile`: the first trip of this rule in a given vessel is a ledger
-- row, because "somebody's beaker started making ammonia gas" is
-- exactly the kind of thing a shift asks about afterwards.
return {
    id = "ammonia_gas",
    reactants = { ammonia = 1.0 },
    products = { ["nh3:gas"] = 1.0 },
    energy = 0.0,
    volatile = true,
    rate = {
        bell = {
            temp_min = 700.0,
            opt_lo = 720.0,
            opt_hi = 5000.0,
            temp_max = 10000.0,
            exponent = 2.0,
            base_rate = 0.05,
        },
    },
}
