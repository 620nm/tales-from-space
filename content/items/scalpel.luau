-- The first thing a surgeon reaches for (tg surgery_tools.dm:208-231).
return {
    id = "scalpel", name = "scalpel", sprite = "scalpel",
    tool = "scalpel", tool_speed = 1, surgical = true,
    force = 10, sharp = "edged",
    -- A surgical tool with nothing to do is refused rather than swung,
    -- and the reason rides `info.surgery_refusal` (docs/SURGERY.md §6.3).
    -- The tool speaks; the engine says nothing.
    on_attack = function(ctx, _self, user, _victim, info)
        if not info or not info.surgery_refusal then return end
        local why = info.surgery_refusal
        if why == "not_lying" then
            ctx.system_msg(user, "They need to be lying down for that.")
        elseif why == "obstructed" then
            ctx.system_msg(user, "The operation site is covered.")
        else
            ctx.system_msg(user, "There is nothing to do there with the scalpel.")
        end
    end,
}
