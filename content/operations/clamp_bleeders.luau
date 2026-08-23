-- Clamp the vessels shut (tg operation_generic.dm:215-253): the bleed
-- drops from 1.5/s to 0.2/s, and 20 brute of saw damage is mended.
return {
    id = "clamp_bleeders", name = "clamp the bleeders",
    requires = { "skin_open", "vessels_unclamped" },
    sets = { "vessels_clamped" }, clears = { "vessels_unclamped" },
    heal = { brute = 20 }, heal_if = "bone_sawed", -- mends 20 of the saw's damage, only if sawed
    time = 2.4,
    implements = {
        { tool = "hemostat", mult = 1 },
        { tool = "cutters", mult = 1.67 },
    },
}
