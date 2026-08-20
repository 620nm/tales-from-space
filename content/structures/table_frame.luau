-- Four legs and four framing rods: the thing a table is before it has a
-- top on it (tg's `/obj/structure/table_frame`,
-- code/game/objects/structures/table_frames.dm:12-24).
--
-- It is a SEPARATE structure rather than a state of a table, and that
-- is tg's shape for a reason worth keeping: one frame becomes whichever
-- table the sheet you lay on it is made of
-- (`get_table_type`, table_frames.dm:54-95). Folding the frame into the
-- table would mean a steel frame that could only ever become a steel
-- table, and a second copy of it under every other top.
--
-- Not dense -- "You could easily pass through this" (:14) -- and not
-- bolted to anything: tg's frame is `anchored = FALSE`, so it shoves
-- like any other loose thing and the wind can drag it. A frame is also
-- not a surface. Nothing rests on four legs and a hole.
return {
    id = "table_frame",
    name = "table frame",
    sprite = "table_frame",
    dense = false,
    -- tg's `anchored = FALSE` (table_frames.dm:17), said in this pack's
    -- own vocabulary: there is one state and nothing holds it down.
    loose = true,
    -- Two rods, one second: tg's stack recipe, which is the only way to
    -- get one (`/obj/item/stack/rods`, rods.dm:3).
    build = {
        on = { "floor", "plating" },
        with = { rod = 2 },
        secs = 1.0,
        start = "You start bending the rods into a table frame.",
        done = "The table frame stands.",
    },
    transitions = {
        -- A sheet on the frame is a table, two seconds later
        -- (`item_interaction`, table_frames.dm:54-91). WHICH table is
        -- the sheet's answer in tg (`table_type`) and the frame's
        -- answer here, because a stack in this pack is a noun and does
        -- not carry a roster of what it can become.
        {
            with = { metal = 1 },
            secs = 2.0,
            leaves = "table",
            gone = true,
            start = "You start laying the sheet over the frame.",
            done = "The table stands.",
        },
        -- Reinforced glass, for want of plasteel. tg's reinforced table
        -- is the plasteel stack's `table_type` (sheet_types.dm:324) and
        -- its reinforced-glass twin is the rglass stack's
        -- (glass.dm:173) -- one is a reinforced table and so is the
        -- other. This pack has rglass and no plasteel, so the reinforced
        -- table it can build is the one it has the sheets for.
        {
            with = { rglass = 1 },
            secs = 2.0,
            leaves = "reinforced_table",
            gone = true,
            start = "You start laying the reinforced pane over the frame.",
            done = "The reinforced table stands.",
        },
        -- Three seconds with a ratchet and it is rods again -- tg's
        -- `wrench_act` (:41-48) and the framestack it hands back
        -- (`atom_deconstruct`, :97-98).
        {
            tool = "wrench",
            secs = 3.0,
            yields = { rod = 2 },
            gone = true,
            start = "You start taking the table frame apart.",
            done = "The table frame comes apart.",
        },
    },
}
