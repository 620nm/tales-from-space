-- The scripted vending machine from docs/luau-api.md's shipped-content
-- list: ctx.sleep demonstrates a plain suspension (no revalidation),
-- ctx.spawn_item a script-created entity with Script-actor provenance
-- in the shift ledger.
return {
    id = "vendor",
    name = "Robust Softdrinks vending machine",
    sprite = "vendor",
    on_interact = function(ctx, self, user)
        ctx.sound("vend", ctx.pos(self))
        ctx.system_msg(user, "The machine whirrs and clunks...")
        ctx.sleep(1.0)
        local x, y = ctx.pos(user)
        ctx.spawn_item("cola", x, y)
        ctx.system_msg(user, "A can of Space Cola drops into the tray.")
    end,
    on_bump = function(ctx, self, user)
        ctx.system_msg(user, "The vending machine wobbles. Nothing falls out.")
    end,
}
