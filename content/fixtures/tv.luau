-- The television: furniture with opinions. Powered through its cord
-- like the vendor; the programming is beyond anyone's control.
return {
    id = "tv",
    on_interact = function(ctx, self, user, x, y)
        if ctx.is_powered(self) then
            ctx.system_msg(user, "Reruns of Space Cops. Again.")
        else
            ctx.system_msg(user, "The screen is dark. It needs a powered outlet nearby.")
        end
    end,
}
