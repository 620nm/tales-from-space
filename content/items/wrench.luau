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
-- The client alpha-tests the actual stacked pipe art and appends the
-- selected layer to this hook. The server validates that exact length
-- before dispatch and again when applying the cut.
--
-- Structures claim a click before this hook ever runs, so a wrench on a
-- girder still bolts the girder; this only sees tiles nothing else
-- wanted.
--
-- And it only reaches plumbing the deck is not covering. A finished
-- floor tile hides its subfloor outright: in tg an intact turf's
-- levelupdate() sends COMSIG_OBJ_HIDE (code/game/turfs/turf.dm:503-506)
-- and the pipe sits at UNDERFLOOR_HIDDEN (code/__DEFINES/turfs.dm:50-54;
-- atmospherics registers for the signal in code/modules/atmospherics/
-- machinery/atmosmachinery.dm:135-145, `var/hide = TRUE` on line 38), so
-- the click never resolves against the pipe at all. Hence "pass" and NO
-- message: a run you cannot see is a run the game must not mention, and
-- "you can't reach the pipe" would be a probe for buried cable. Pry the
-- tile up and the same click works.
return {
    id = "wrench",
    name = "wrench",
    sprite = "wrench",
    inhand_sprite = { "held_wrench_l", "held_wrench_r" },
    stowed_sprite = "belt_wrench",
    tool = "wrench",
    on_use = function(ctx, self, user, x, y, _, target)
        -- Asked before the pipe question, so a covered tile answers the
        -- same whether or not anything runs under it.
        if ctx.turf(x, y) ~= "plating" then
            return "pass"
        end
        if target == nil or target.kind ~= "pipe" then
            return "pass"
        end
        local layer = target.layer
        if ctx.pipe(x, y) % (layer * 2) < layer then
            return "pass"
        end
        ctx.system_msg(user, "You start unwrenching the pipe...")
        if not ctx.do_after(user, 1.0) then
            ctx.system_msg(user, "You stop unwrenching.")
            return
        end
        if ctx.pipe(x, y) % (layer * 2) < layer then
            return
        end
        ctx.sound("ratchet", x, y)
        ctx.cut_pipe(x, y, layer)
        ctx.system_msg(user, "The pipe comes free.")
    end,
}
