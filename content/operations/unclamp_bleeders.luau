-- Let the vessels bleed again (tg operation_generic.dm:259-304).
return {
    id = "unclamp_bleeders", name = "unclamp the bleeders",
    requires = { "skin_open", "vessels_clamped" },
    sets = { "vessels_unclamped" }, clears = { "vessels_clamped" },
    time = 2.4,
    implements = {
        { tool = "hemostat", mult = 1 },
        { tool = "cutters", mult = 1.67 },
    },
}
