-- The first item to cross the content boundary. Robust — and, since
-- the chillstation redirect, an actual container: it ships stocked
-- with the engineering loop (open it from your hand to get at them).
return {
    id = "toolbox",
    name = "mechanical toolbox",
    sprite = "toolbox",
    inhand_sprite = { "held_toolbox_l", "held_toolbox_r" },
    -- A boxful of loose steel, and it sounds like it. tg
    -- _toolbox.dm:19-21.
    pickup_sound = "toolbox_pickup",
    drop_sound = "toolbox_drop",
    storage = 7,
    holds = { "welder", "crowbar", "wirecutters", "screwdriver", "wrench", "cable_coil" },
    on_attack = function(ctx, self, user, target)
        ctx.damage(target, { brute = 10 })
        ctx.sound("smash", ctx.pos(target))
        -- One whole sentence per message, the name passed as an
        -- argument rather than glued on with `..`: a fragment joined in
        -- content is a fragment no catalog can decline
        -- (docs/LOCALIZATION.md §5). ctx has no msg(key, args) yet, so
        -- the frame still lives here; when it does, these two calls
        -- become keys and the arguments are already the arguments.
        ctx.system_msg(user, string.format("You rob %s with the toolbox!", ctx.name(target)))
        ctx.system_msg(target, string.format("%s robs you with a toolbox!", ctx.name(user)))
    end,
}
