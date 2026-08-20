-- A table: the first thing on this station a crewman can arrange
-- rather than merely drop things on.
--
-- tg's `/obj/structure/table`
-- (code/game/objects/structures/tables_racks.dm:15-40). Two of its
-- lines are the whole file:
--
--   * `smoothing_groups = SMOOTH_GROUP_TABLES` and `canSmoothWith` the
--     same (:29-31) -- a run of tables is drawn as one surface, and
--     which tables count as the same surface is a word ("tables") that
--     this file and reinforced_table.luau agree on. The engine keeps no
--     roster of groups; it only asks whether two entries said the same
--     word.
--   * a click with something in hand puts that thing DOWN on it, at the
--     pixel you pointed at (`table_place_act`, :387-402). Here that is
--     `surface = true` and nothing else: the mechanism is the engine's
--     (sim/surface.rs), and it runs LAST, after every hook this pack
--     declares, which is what lets a deck of cards deal at a table
--     instead of being put down on one.
--
-- Dense but not opaque, as tg's is: it stops you walking through and
-- does not stop you seeing over. tg lets you climb one (PASSTABLE);
-- this pack has no climbing yet, so a table is a wall you can see past.
--
-- WHAT IS NOT PORTED: flipping (`can_flip`, :43-45 -- a second art set
-- and a cover mechanic), the glass tables and their shards, the
-- integrity/smash path, and the rolling table. Each needs a system that
-- does not exist here; none of them changes what a table IS.
return {
    id = "table",
    name = "table",
    -- The isolated frame. Everything else it can wear is derived from
    -- the prefix below and interned at load, so a family missing one of
    -- the forty-seven is a startup error rather than an invisible
    -- table.
    sprite = "table-0",
    dense = true,
    opaque = false,
    surface = true,
    smooth = {
        group = "tables",
        sprites = "table",
    },
    -- No `build`: a table is raised on a frame (structures/table_frame.luau),
    -- never out of thin air on bare deck, which is tg's own order.
    transitions = {
        -- tg's two ways out, and they differ by exactly one thing: the
        -- ratchet takes the legs with it. A screwdriver lifts the top
        -- off and leaves the frame standing
        -- (`screwdriver_act_secondary`, :325-331, with `atom_deconstruct`
        -- keeping `frame`, :407-418); a wrench takes the lot, which tg
        -- spells by clearing `frame` first so the framestack drops
        -- instead (:332-341).
        {
            tool = "screwdriver",
            secs = 2.0,
            yields = { metal = 1 },
            leaves = "table_frame",
            gone = true,
            start = "You start unscrewing the table top.",
            done = "The top comes off, and the frame is left standing.",
        },
        {
            tool = "wrench",
            secs = 4.0,
            yields = { metal = 1, rod = 2 },
            gone = true,
            start = "You start deconstructing the table.",
            done = "The table comes apart.",
        },
    },
}
