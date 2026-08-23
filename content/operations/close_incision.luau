-- Mend the incision (tg operation_generic.dm:146-208): clears every open
-- state and heals 40 of the saw's damage. A lit welder is hot enough.
return {
    id = "close_incision", name = "mend the incision",
    any = { "skin_cut", "skin_open" },
    clears = { "skin_cut", "skin_open", "vessels_unclamped", "vessels_clamped",
               "organs_cut", "bone_drilled", "bone_sawed", "cavity_open" },
    heal = { brute = 40 }, heal_if = "bone_sawed", -- mends the saw's 50, only if it was sawed
    time = 2.4,
    implements = {
        { tool = "cautery", mult = 1 },
        { tool = "suture", mult = 1 },
        { tool = "welder", heat = true, mult = 1.5 },
        { heat = true, mult = 3.33 },       -- anything over the boil
    },
}
