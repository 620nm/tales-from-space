-- Make the first cut (tg operation_generic.dm:3-78). Opens the skin and
-- the vessels under it; the chest begins to bleed 1.5/s.
return {
    id = "incise_skin", name = "make an incision",
    part = { any = { "flesh" }, none = { "robotic" } },
    blocked = { "skin_cut", "skin_open" },
    sets = { "skin_cut", "vessels_unclamped" },
    time = 1.6, -- operation_generic.dm:19
    implements = {
        { tool = "scalpel", mult = 1 },
        { item = "shard", mult = 2.25 },       -- operation_generic.dm:14
        { tool = "screwdriver", mult = 5 },
        { sharp = "edged", mult = 3.33 },       -- any edged thing
    },
}
