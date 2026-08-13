-- The first item to cross the content boundary. Robust.
return {
    id = "toolbox",
    name = "mechanical toolbox",
    sprite = "toolbox",
    on_attack = function(ctx, self, user, target)
        ctx.damage(target, { brute = 10 })
        ctx.sound("smash", ctx.pos(target))
        ctx.system_msg(user, "You rob " .. ctx.name(target) .. " with the toolbox!")
        ctx.system_msg(target, ctx.name(user) .. " robs you with a toolbox!")
    end,
}
