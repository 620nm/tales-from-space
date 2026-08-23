-- Cauterise your OWN wound (tg _operation.dm:134-171): x2 time, 5 burn,
-- any heat source. Only the patient can do it to themselves.
return {
    id = "close_incision_self", name = "cauterise your own wound",
    self_only = true,
    any = { "skin_cut", "skin_open" },
    clears = { "skin_cut", "skin_open", "vessels_unclamped", "vessels_clamped",
               "organs_cut", "bone_drilled", "bone_sawed", "cavity_open" },
    damage = { burn = 5 },
    time = 4.8,
    implements = {
        { heat = true, mult = 1 },
    },
}
