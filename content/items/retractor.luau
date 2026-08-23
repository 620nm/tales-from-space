-- Holds an incision open (tg surgery_tools.dm:1-16).
return {
    id = "retractor", name = "retractor", sprite = "retractor",
    tool = "retractor", tool_speed = 1, surgical = true,
    -- Refused rather than swung on a patient, the reason on
    -- `info.surgery_refusal` (docs/SURGERY.md §6.3).
    on_attack = function(ctx, _self, user, _victim, info)
        if not info or not info.surgery_refusal then return end
        local why = info.surgery_refusal
        if why == "not_lying" then
            ctx.system_msg(user, "They need to be lying down for that.")
        elseif why == "obstructed" then
            ctx.system_msg(user, "The operation site is covered.")
        else
            ctx.system_msg(user, "There is nothing to retract there.")
        end
    end,
}
