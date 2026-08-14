-- The first item to cross the content boundary. Robust — and, since
-- the chillstation redirect, an actual container: it ships stocked
-- with the engineering loop (open it from your hand to get at them).
return {
    id = "toolbox",
    name = "mechanical toolbox",
    sprite = "toolbox",
    inhand_sprite = { "held_toolbox_l", "held_toolbox_r" },
    storage = 7,
    holds = { "welder", "crowbar", "wirecutters", "screwdriver", "wrench", "cable_coil" },
    on_attack = function(ctx, self, user, target)
        ctx.damage(target, { brute = 10 })
        ctx.sound("smash", ctx.pos(target))
        ctx.system_msg(user, "You rob " .. ctx.name(target) .. " with the toolbox!")
        ctx.system_msg(target, ctx.name(user) .. " robs you with a toolbox!")
    end,
}
