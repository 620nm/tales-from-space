-- Reads what a wire is doing before you cut it, and defeats a safety
-- interlock if you would rather it did that.
--
-- It has a tool class now, and one machine in the game answers to it:
-- a multitool on a volumetric gas pump throws its pressure limiters
-- (tg's `multitool_act`, volume_pump.dm:162-170), after which the pump
-- will push past what the kit is rated for and leak a tenth of
-- everything it moves into the room. Nothing else in the construction
-- chain dispatches on the class yet -- a target that declares no
-- multitool step simply is not interested.
--
-- tg: /obj/item/multitool (multitool.dm:14).
return {
    id = "multitool",
    name = "multitool",
    sprite = "multitool",
    tool = "multitool",
    inhand_sprite = { "held_multitool_l", "held_multitool_r" },
    stowed_sprite = "belt_multitool",
    -- tg multitool.dm:28-29.
    pickup_sound = "multitool_pickup",
    drop_sound = "multitool_drop",
    -- The first half of the sentence at the top of this file: hold it
    -- against an open deck and it says what the cable under there is
    -- carrying, per channel (`ctx.segment_live`). A READ and nothing
    -- else -- what a machine draws, what a breaker is set to and what a
    -- bank has left are the grid's business and a window's, not a
    -- probe's (docs/POWER.md).
    --
    -- It declines every click it has nothing to say about, so nothing
    -- this tool already does is shadowed: a click that NAMES something
    -- is that thing's business (the gas pump's limiters, a machine's
    -- window), a finished floor hides its wiring, and a bare tile with
    -- no cable in it is not a wire at all. `on_use` is late in the click
    -- order but not last (docs/LUAU-API.md §9), so declining is what
    -- keeps the rungs below it reachable.
    on_use = function(ctx, self, user, x, y, choice, clicked)
        if clicked ~= nil and clicked.entity ~= nil then
            return "pass"
        end
        if not ctx.subfloor_exposed(x, y) then
            return "pass"
        end
        local live = ctx.segment_live(x, y)
        if live == nil then
            return "pass"
        end
        local carrying = {}
        if live.equipment then
            carrying[#carrying + 1] = "equipment"
        end
        if live.lighting then
            carrying[#carrying + 1] = "lighting"
        end
        if #carrying == 0 then
            ctx.system_msg(user, "The cable here is dead.")
        else
            ctx.system_msg(
                user,
                "The cable here is carrying " .. table.concat(carrying, " and ") .. "."
            )
        end
    end,
}
