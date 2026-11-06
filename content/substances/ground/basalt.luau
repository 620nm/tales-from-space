-- Basalt: the dark volcanic rock that makes most planetary crust.
-- Basalt is a mix, not a compound, so one mole here is one mole of
-- oxide units at the rock's mean oxide mass.
--
-- Real values, not tg's (tg has no ground reagent). Mean oxide mass:
-- a typical tholeiitic basalt by weight is about 49% SiO2, 15% Al2O3,
-- 11% FeO, 11% CaO, 8% MgO, 2.5% Na2O, 1.5% TiO2; 98 g of it holds
-- 1.57 mol of oxide units, so 62.4 g/mol. Density 2.9 g/mL (solid,
-- unvesiculated; handbook range 2.8 to 3.0). Specific heat 0.84 J/(g*K)
-- near 298 K times 62.4 gives cv 52.4 J/(mol*K). `unmodeled = "solid"`:
-- it melts above 1400 K, past any map.
return {
    id = "basalt",
    name = "basalt",
    molar_mass = 62.4,
    cv = 52.4,
    phase = { unmodeled = "solid" },
    density = { solid = 2.9 },
    -- A blue-gray dark rock, the same gray the terrestrial art tools
    -- use for basalt (tools/art/terrestrial/schema_contract.py).
    color = "#5E626E",
}
