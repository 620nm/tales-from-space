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
--   * interaction.use@self -- strike it, or snuff it. tg wants an igniter of
--     1000 K or hotter to light one (items.dm:274-278); nothing in this
--     pack has a temperature of its own to be measured, so the toggle
--     is bare and the requirement waits for the first thing that does.
--   * interaction.use with a vessel named -- hold the flame against it, which is
--     tg's `expose_temperature(get_temperature())` (items.dm:284-287).
--     `acts_on_items` is what lets a click that NAMES a beaker be this
--     burner's business rather than a pickup.
local U = 0.025

local content = {
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
    -- tg's `max_volume = 50` (items.dm:164-172): the reservoir, and
    -- the whole of what it holds. What it ships with is the 15 units
    -- of spirit below, through the documented dose bridge of
    -- 1 u = 0.025 mol (docs/CHEMISTRY.md).
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
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local lit = self.state == "lit"
        if lit then
            sim.set_flame(self, false)
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.burner.you_snuff_the_burner_out", {}),
            })
            return true
        end
        sim.set_flame(self, true)
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.burner.you_light_the_burner", {}),
        })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        if clicked == nil or clicked.entity == nil then
            return { replaced = false }
        end
        if sim.matter_read(clicked.entity) == nil then
            return { replaced = false } -- not something that holds anything
        end
        if self.state ~= "lit" then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.burner.the_burner_isn_t_lit", {}),
            })
            return true
        end
        sim.expose_heat(self, clicked.entity)
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.burner.you_warm_it_over_the", {}),
        })
        return true
    end)
end

return content
