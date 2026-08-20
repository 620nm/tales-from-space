-- Carbon dioxide. tg: `/datum/chemical_reaction/carbondioxide`,
-- 3 CO2 from 1 carbon + 2 oxygen, `required_temp = 777` ("pure carbon
-- isn't especially reactive"), no thermic_constant
-- (recipes/others.dm:142-146).
--
-- The product goes into the BUILTIN gas, in the gas phase -- `co2:gas`
-- rather than a bare key -- because that is what it is. This is the
-- unification dividend said out loud: a beaker of it holds the same
-- substance an atmos cell does, so a spill or a boiled beaker puts real
-- carbon dioxide into the room and the room already knows what to do
-- with it.
--
-- Bell by the documented mapping (docs/reagents.md). tg's required
-- temperature is ABOVE its default optimal, so the rule's second clause
-- applies -- opt_lo = temp_min + 5 -- and the plateau starts as soon as
-- the window opens:
--   temp_min = 777, opt_lo = 782, opt_hi = 900 (default overheat),
--   temp_max = opt_hi + max(opt_lo - temp_min, 20) = 920
return {
    id = "carbon_dioxide",
    reactants = { carbon = 1.0, o2 = 2.0 },
    products = { ["co2:gas"] = 3.0 },
    energy = 0.0,
    rate = {
        bell = {
            temp_min = 777.0,
            opt_lo = 782.0,
            opt_hi = 900.0,
            temp_max = 920.0,
            exponent = 2.0,
            base_rate = 0.05,
        },
    },
}
