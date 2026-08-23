-- Saw through the ribcage (tg operation_generic.dm:306-366): 50 brute,
-- and no improvised edge under force 10 will do it -- the chest lock.
return {
    id = "saw_bone", name = "saw through the bone",
    requires = { "skin_open" }, blocked = { "bone_sawed", "bone_drilled" },
    sets = { "bone_sawed" },
    damage = { brute = 50 }, -- operation_generic.dm:358
    time = 5.4,
    implements = {
        { tool = "saw", mult = 1 },
        { sharp = "edged", force_min = 10, mult = 4 },
    },
}
