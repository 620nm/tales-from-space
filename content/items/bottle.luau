-- The bottle: fifty units with a neck on it. Same size as the beaker
-- and a different shape of thing to carry it in -- a beaker is what you
-- mix in and a bottle is what you put on a shelf afterwards.
--
-- Capacity is tg's `volume = 50` at the documented bridge of
-- 1 u = 0.025 mol (docs/CHEMISTRY.md); the picture and the fill prefix
-- are both tg's `bottle` (bottle.dm:6-7; `volume = 50` at :12,
-- `fill_icon_thresholds` at :13).
--
-- The three gestures are the vessel's rather than the beaker's: your
-- own tile is a swig, another vessel within reach is a pour, the deck
-- is a spill. (Content files cannot `require` one another, so each one
-- spells them out; see card.luau on the same tradeoff.)
local U = 0.025

local content = {
    id = "bottle",
    name = "bottle",
    sprite = "bottle",
    examine = {
        flavor = "Glass with a neck on it, made for carrying rather than "
            .. "mixing. What ends up on the shelf.",
    },
    capacity_mol = 50 * U,
    -- tg's bottle: `volume = 50` (cups/bottle.dm:12), the cup base's
    -- own figure. One unit is one millilitre.
    volume_ml = 50,
    -- A neck has a stopper in it. What a shelf keeps is corked, so what
    -- is in it stays in it: a bottle does not breathe with the room the
    -- way an open beaker does, and what ferments inside one builds a
    -- pressure of its own (docs/CHEMISTRY.md 9). Pouring, drinking and
    -- spilling are all you pulling the cork, and none of them asks
    -- about the lid -- the seal is what the bottle does while nobody is
    -- handling it.
    sealed = true,
    fill_sprites = {
        { 1, "bottle_fill_1" },
        { 20, "bottle_fill_20" },
        { 40, "bottle_fill_40" },
        { 60, "bottle_fill_60" },
        { 80, "bottle_fill_80" },
        { 100, "bottle_fill_100" },
    },
    acts_on_items = true,
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        local function total(obj)
            local read = sim.matter_read(obj)
            local c = read and read.contents
            if c == nil then
                return nil
            end
            local n = 0
            for _, phases in pairs(c) do
                for _, moles in pairs(phases) do
                    n = n + moles
                end
            end
            return n
        end

        if clicked ~= nil and clicked.entity ~= nil then
            if total(clicked.entity) == nil then
                return { replaced = false }
            end
            if (total(self) or 0) < 0.001 then
                sim.message.send({ recipient = user, message = "The bottle is empty." })
                return true
            end
            -- tg's cup default `amount_per_transfer_from_this = 10`
            -- (_cup.dm:4), which is also the beaker's gesture.
            sim.matter.transfer({
                from = self,
                to = clicked.entity,
                amount = 10 * U,
                phases = { "liquid" },
            })
            sim.message.send({ recipient = user, message = "You pour from the bottle." })
            return true
        end

        local px, py = user.tile.x, user.tile.y
        if x == px and y == py then
            if (total(self) or 0) < 0.001 then
                sim.message.send({ recipient = user, message = "The bottle is empty." })
                return true
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/drink", at = ev.at })
            sim.matter.transfer({
                from = self,
                to = user,
                amount = 2 * U,
                phases = { "liquid" },
            })
            sim.message.send({ recipient = user, message = "You drink from the bottle." })
            return true
        end

        local turf = sim.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" then
            return { replaced = false }
        end
        if (total(self) or 0) < 0.001 then
            sim.message.send({ recipient = user, message = "The bottle is empty." })
            return true
        end
        sim.matter.transfer({
            from = self,
            to = ev.at.matter,
            amount = "all",
            phases = { "liquid" },
        })
        sim.message.send({ recipient = user, message = "You tip the bottle out onto the deck." })
        return true
    end)
end

return content
