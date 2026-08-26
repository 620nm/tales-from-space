-- THE LADDER every stock part climbs, in one place.
--
-- tg ships four rungs of each part (research/stock_parts.dm:28-184) and
-- carries TWO numbers on each: `rating`, which is 1/2/3/4 and ORDERS
-- them, and `energy_rating`, which is 1/3/5/10 and is what the machines
-- that care about magnitude actually read. The engine keeps the same
-- pair — `component.tier` orders, `component.efficiency` is the
-- magnitude the scaling laws do arithmetic with
-- (docs/CONTENT-SCHEMA.md §1.10b).
--
-- THIS PACK'S EFFICIENCY LADDER IS ITS OWN: 1.0 / 1.5 / 2.0 / 3.0.
-- Neither of tg's two curves is right here. `rating` (1/2/3/4) is what
-- tg's own reaction chamber multiplies by, and it quadruples a machine
-- on the last rung; `energy_rating` (1/3/5/10) is ten times the base
-- part and would make a tier-4 freezer a different machine rather than
-- a better one. A station with no lathe, no research tree and no
-- deconstruction bench gets its better parts by finding them, so the
-- ladder is tuned so that finding one is worth the walk and losing one
-- is not the end of the shift: a full set of tier fours is three times
-- the plain machine, and tg's own reaction chamber ceiling (0.4 from
-- 0.1, chem_heater.dm:88 and :390) is still nearly reached.
--
-- Every `component` in `content/items/` reads its efficiency from here,
-- so the ladder cannot be spelled two ways.
local EFFICIENCY = { 1.0, 1.5, 2.0, 3.0 }

return {
    -- Indexed by tier. Read directly where a base item declares its own
    -- rung; `rung` below is for the variants.
    efficiency = EFFICIENCY,
    -- The `component` override one tier VARIANT of a part writes. The
    -- socket word is not in it on purpose: `kind` is the base item's
    -- single answer, and a variant inherits it (docs/CONTENT-SCHEMA.md
    -- §1.1a, the nested-field form) so no rung of a ladder can quietly
    -- become a different part.
    rung = function(tier)
        return { tier = tier, efficiency = EFFICIENCY[tier] }
    end,
}
