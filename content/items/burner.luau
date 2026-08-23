-- A bench burner: a small tank of spirit with a wick, for heating one
-- beaker at a time. tg's `/obj/item/burner`
-- (code/modules/reagents/chemistry/items.dm:151-291).
--
-- The tank is an ordinary Holder, so the fuel is ordinary matter: it
-- pours, it mixes, and a burner filled with something else burns at
-- whatever that something else burns at. tg ships three variants of
-- this object for exactly that reason (ethanol, oil, welding fuel);
-- here there is one burner and you fill it with what you like.
--
-- Two gestures, and they are both clicks, which is why they are here
-- and the burning between them is not (sim/holder/fuel_burn.rs):
--   * on_use_self -- strike it, or snuff it. tg wants an igniter of
--     1000 K or hotter to light one (items.dm:274-278); nothing in this
--     pack has a temperature of its own to be measured, so the toggle
--     is bare and the requirement waits for the first thing that does.
--   * on_use with a vessel named -- hold the flame against it, which is
--     tg's `expose_temperature(get_temperature())` (items.dm:284-287).
--     `acts_on_items` is what lets a click that NAMES a beaker be this
--     burner's business rather than a pickup.
local U = 0.025

return {
    id = "burner",
    name = "burner",
    sprite = "burner",
    examine = {
        flavor = "A small tank of spirit with a wick standing out of it. "
            .. "Enough flame to warm one vessel, and no more.",
    },
    -- Unlit first: the engine reads position 0 as cold and 1 as alight
    -- (the same off-first order an atmos device's positions keep), so a
    -- burner that runs dry unattended repaints itself without anything
    -- native learning what either picture is called.
    states = { "cold", "lit" },
    state_sprites = {
        cold = "burner",
        lit = "burner_lit",
    },
    flame = true,
    -- tg's `max_volume = 50` and `add_reagent(ethanol, 15)` on spawn
    -- (items.dm:164-172), through the documented bridge of 1 u = 0.025
    -- mol (docs/CHEMISTRY.md).
    capacity_mol = 50 * U,
    volume_ml = 50,
    -- A LID, and the first thing in the tree to wear one. tg's burner
    -- is a closed reservoir with a wick through the cap (items.dm:151-
    -- 291 -- it has no OPENCONTAINER flag, unlike every cup), and now
    -- that ethanol has a phase curve the flag has to be said out loud:
    -- an open one at station temperature would breathe its spirit into
    -- the room and stand empty in a couple of hours, having heated
    -- nothing. Sealed vessels trade nothing with the air
    -- (sim/holder/vent.rs).
    sealed = true,
    contents = { ethanol = 15 * U },
    acts_on_items = true,
    on_use_self = function(ctx, self, user)
        local lit = ctx.state(self) == "lit"
        if lit then
            ctx.set_flame(self, false)
            ctx.system_msg(user, "You snuff the burner out.")
            return
        end
        ctx.set_flame(self, true)
        ctx.system_msg(user, "You light the burner.")
    end,
    on_use = function(ctx, self, user, x, y, choice, clicked)
        if clicked == nil or clicked.entity == nil then
            return "pass"
        end
        if ctx.contents(clicked.entity) == nil then
            return "pass" -- not something that holds anything
        end
        if ctx.state(self) ~= "lit" then
            ctx.system_msg(user, "The burner isn't lit.")
            return
        end
        ctx.expose_heat(self, clicked.entity)
        ctx.system_msg(user, "You warm it over the burner.")
    end,
}
