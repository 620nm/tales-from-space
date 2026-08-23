-- Drill a hole through the bone (tg operation_generic.dm:427-477).
return {
    id = "drill_bone", name = "drill the bone",
    requires = { "skin_open" }, blocked = { "bone_sawed", "bone_drilled" },
    sets = { "bone_drilled" },
    time = 3,
    implements = {
        { tool = "drill", mult = 1 },
        { tool = "screwdriver", mult = 4 },
        { sharp = "pointy", force_min = 10, mult = 6.67 },
    },
}
