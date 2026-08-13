-- Every chill room needs one. Corded: no powered outlet in range, no
-- reruns.
return {
    id = "tv_flatpack",
    name = "television flatpack",
    sprite = "tv",
    deploys = "tv",
    on_use = function(ctx, self, user, x, y)
        if ctx.turf(x, y) ~= "floor" then
            return "pass"
        end
        ctx.system_msg(user, "You start assembling the television.")
        if ctx.do_after(user, 3.0) and ctx.turf(x, y) == "floor" then
            ctx.deploy(self, x, y)
        else
            ctx.system_msg(user, "You stop assembling.")
        end
    end,
}
