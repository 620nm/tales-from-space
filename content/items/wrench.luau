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
-- ONE PULL, ONE LENGTH -- the wirecutters' rule, for the same reason.
-- tg unwrenches the single fitting you clicked, and stacks its five
-- piping layers a thousandth of a draw layer apart so you can aim at
-- one (atmos_piping.dm:80-81 and the comment above it). We have no
-- cursor down there, so a pull takes the TOPMOST layer and leaves the
-- runs beneath it plumbed. It also means the refund is honest: one
-- length up, one length in your hand.
--
-- Structures claim a click before this hook ever runs, so a wrench on a
-- girder still bolts the girder; this only sees tiles nothing else
-- wanted.
local TOPMOST_FIRST = { 16, 8, 4, 2, 1 }

local function top_layer(mask)
    for _, bit in ipairs(TOPMOST_FIRST) do
        if mask % (bit * 2) >= bit then
            return bit
        end
    end
    return nil
end

return {
    id = "wrench",
    name = "wrench",
    sprite = "wrench",
    inhand_sprite = { "held_wrench_l", "held_wrench_r" },
    tool = "wrench",
    on_use = function(ctx, self, user, x, y)
        if top_layer(ctx.pipe(x, y)) == nil then
            return "pass"
        end
        ctx.system_msg(user, "You start unwrenching the pipe...")
        if not ctx.do_after(user, 1.0) then
            ctx.system_msg(user, "You stop unwrenching.")
            return
        end
        local layer = top_layer(ctx.pipe(x, y))
        if layer == nil then
            return
        end
        ctx.sound("ratchet", x, y)
        ctx.cut_pipe(x, y, layer)
        ctx.spawn_item("pipe", x, y)
        ctx.system_msg(user, "The pipe comes free.")
    end,
}
