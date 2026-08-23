-- Open the organ cavity (tg operation_generic.dm:479-531): 10 brute.
return {
    id = "incise_organs", name = "incise the organs",
    requires = { "skin_open" }, blocked = { "organs_cut" },
    sets = { "organs_cut" },
    damage = { brute = 10 }, -- operation_generic.dm:524
    time = 2.4,
    -- tg allows "any edged, but NOT a saw" (operation_generic.dm:506);
    -- the implement schema cannot say "not a saw", and a generic edged
    -- entry would let a circular saw stand in for a scalpel here, so the
    -- improvised set is the shard alone (docs/SURGERY.md §6.7).
    implements = {
        { tool = "scalpel", mult = 1 },
        { item = "shard", mult = 2.25 },
    },
}
