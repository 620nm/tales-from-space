-- Anchors and unanchors. A girder bolts to the deck under it (4 s,
-- tg's rate) and comes loose the same way -- and a loose girder is one
-- a crewmate can shove across the room, which is the whole reason the
-- distinction is worth having.
--
-- The same wrench pulls plumbing. That is not a second job bolted on:
-- in tg a pipe IS wrenched down, so unwrenching it is the same motion,
-- and a length that comes up gives back a length you can lay again.
-- Anything the run was holding goes into the room you are standing in,
-- which is why an engineer opens the shutoff before touching a charged
-- line.
--
-- Structures claim a click before this hook ever runs, so a wrench on a
-- girder still bolts the girder; this only sees tiles nothing else
-- wanted.
return {
    id = "wrench",
    name = "wrench",
    sprite = "wrench",
    inhand_sprite = { "held_wrench_l", "held_wrench_r" },
    tool = "wrench",
    on_use = function(ctx, self, user, x, y)
        if ctx.pipe(x, y) == 0 then
            return "pass"
        end
        ctx.system_msg(user, "You start unwrenching the pipe...")
        if ctx.do_after(user, 1.0) and ctx.pipe(x, y) ~= 0 then
            ctx.sound("ratchet", x, y)
            -- All five layers: you are pulling up what is under your
            -- feet, not choosing which of two crossing runs to spare.
            ctx.cut_pipe(x, y, 31)
            ctx.spawn_item("pipe", x, y)
            ctx.system_msg(user, "The pipe comes free.")
        else
            ctx.system_msg(user, "You stop unwrenching.")
        end
    end,
}
