-- The scripted vending machine from docs/LUAU-API.md's shipped-content
-- list: ctx.sleep demonstrates a plain suspension (no revalidation),
-- ctx.spawn_item a script-created entity with Script-actor provenance
-- in the shift ledger.
return {
    id = "vendor",
    name = "Robust Softdrinks vending machine",
    sprite = "vendor",
    on_interact = function(ctx, self, user)
        if not ctx.is_powered(self) then
            ctx.system_msg(user, "The machine is dark and silent.")
            return
        end
        -- M7 second half: clicking the machine opens its real TGUI
        -- window (tg's untouched Vending interface); dispensing happens
        -- through its act() buttons now.
        ctx.open_ui(user, self)
    end,
    on_bump = function(ctx, self, user)
        ctx.system_msg(user, "The vending machine wobbles. Nothing falls out.")
    end,
}
