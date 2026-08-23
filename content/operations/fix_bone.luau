-- Set the bone back (tg operation_generic.dm:369-425): heals 40, clears
-- the drilled/sawed states.
return {
    id = "fix_bone", name = "set the bone",
    requires = { "skin_open" }, any = { "bone_drilled", "bone_sawed" },
    clears = { "bone_drilled", "bone_sawed" },
    heal = { brute = 40 },
    time = 4,
    implements = {
        { tool = "bonegel", mult = 1 },
        { item = "bone_gel", mult = 1 },
    },
}
