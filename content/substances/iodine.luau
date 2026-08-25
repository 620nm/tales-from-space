-- Iodine: I2, the halogen in the medicine cabinet. NOT on the
-- dispenser shelf, though tg lists it there -- this pack's shelf is the
-- buttons a recipe actually needs, and nothing here names iodine yet.
-- It arrives in a bottle, the way radium does.
--
-- Real molar mass and the real molar heat capacity (I2, 54.4
-- J/(mol*K)), with an authored `unmodeled` rest phase per D2
-- (docs/CHEMISTRY.md). Iodine sublimes rather than melting under one
-- atmosphere, which is a `triple` curve and a genuinely interesting
-- one -- but no rule and no instrument here reads its vapour, so the
-- honest answer is the stated convention rather than a diagram that
-- only costs sweep time.
-- tg: /datum/reagent/iodine (other_reagents.dm:1995).
return {
    id = "iodine",
    name = "iodine",
    molar_mass = 253.81,
    cv = 54.4,
    phase = { unmodeled = "solid" },
    -- Real iodine, 4.93 g/mL.
    density = { solid = 4.93 },
    -- What it looks like through glass (tg: other_reagents.dm:1998).
    color = "#BC8A00",
}
