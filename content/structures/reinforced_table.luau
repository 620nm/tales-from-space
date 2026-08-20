-- A reinforced table: the same four legs, with a cover welded over the
-- top of them.
--
-- tg's `/obj/structure/table/reinforced`
-- (code/game/objects/structures/tables_racks.dm:744-755). It inherits
-- `smoothing_groups` from the plain table and never overrides them, so
-- the two ARE one surface: a reinforced table dropped into a run of
-- ordinary ones joins the row, and the row joins back. That is the
-- whole reason the group below is spelled the same word as
-- structures/table.luau's -- belonging is an agreement between two
-- content files, and the engine keeps no list of who is in what.
--
-- THE MATERIAL IS NOT PLASTEEL, because this pack has none. tg builds
-- this table from the plasteel stack (`table_type`, sheet_types.dm:324)
-- and builds a reinforced table from the reinforced-glass stack too
-- (glass.dm:173) -- both are `/obj/structure/table/reinforced`. So the
-- reinforced table a station with rglass and no plasteel can raise is
-- this one, and it comes apart into the sheets it was built from. The
-- art is tg's plain reinforced sheet because that is the family baked
-- (tfs/assets/sprites/90-smooth-structures.ron); when a plasteel stack
-- exists, it lays on this same frame and this file is where it lands.
--
-- WHAT IS PORTED THAT THE PLAIN TABLE HAS NOT GOT: the cover.
-- `deconstruction_ready = FALSE` (:748) means a reinforced table
-- refuses both its deconstruction steps until somebody has weakened the
-- weld -- tg's `welder_act_secondary` toggles that bit, fifty
-- deciseconds each way (:784-801). Two states, one welder, and the
-- refusals compose themselves out of the state names.
--
-- NOT PORTED: the armour table (:757-765) and the electrification the
-- reinforced table gets when its tile is wired (`attempt_electrocution`,
-- :819-830) -- one needs a damage model this pack has not got, the
-- other needs a cable under a table to mean something.
return {
    id = "reinforced_table",
    name = "reinforced table",
    sprite = "reinforced_table-0",
    dense = true,
    opaque = false,
    surface = true,
    -- Both states are bolted down and both wear a junction picture: a
    -- welded cover is not a thing you can see from across the room,
    -- exactly as tg's is not. What tells them apart is what a tool will
    -- do next, which is what `deconstruction_hints` says out loud
    -- (:777-782).
    states = { "welded", "loosened" },
    smooth = {
        group = "tables",
        sprites = "reinforced_table",
    },
    transitions = {
        -- The cover, both ways. tg's five seconds
        -- (`use_tool(src, user, 50)`, :791 and :798) and tg's fuel: the
        -- check is `tool_start_check(user, amount = 0)` (:785), so the
        -- torch is lit for it and spends nothing. Copied rather than
        -- tidied.
        {
            at = "welded",
            tool = "welder",
            secs = 5.0,
            to = "loosened",
            start = "You start weakening the reinforced table.",
            done = "The top cover is welded loose.",
        },
        {
            at = "loosened",
            tool = "welder",
            secs = 5.0,
            to = "welded",
            start = "You start strengthening the reinforced table.",
            done = "The top cover is welded firmly back on.",
        },
        -- ...and only then the two ways out the plain table has, on the
        -- plain table's own timings (:325-341). The state gate is tg's
        -- `if(!deconstruction_ready) return NONE`, which is what makes a
        -- reinforced table worth reinforcing.
        {
            at = "loosened",
            tool = "screwdriver",
            secs = 2.0,
            yields = { rglass = 1 },
            leaves = "table_frame",
            gone = true,
            start = "You start unscrewing the table top.",
            done = "The top comes off, and the frame is left standing.",
        },
        {
            at = "loosened",
            tool = "wrench",
            secs = 4.0,
            yields = { rglass = 1, rod = 2 },
            gone = true,
            start = "You start deconstructing the reinforced table.",
            done = "The reinforced table comes apart.",
        },
    },
}
