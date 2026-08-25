-- First aid in a glass: libital solution. A beaker like any other, so
-- it wears the same three gestures as the empty one — your own tile is
-- a swig, another vessel within reach is a pour, the deck is a spill.
-- (Content files cannot `require` one another, so the gesture is spelled
-- out here as well; see card.luau on the same tradeoff.)
local content = {
    id = "beaker_libital",
    name = "beaker (libital)",
    sprite = "beaker",
    inhand_sprite = { "held_beaker_l", "held_beaker_r" },
    contents = { water = 0.20, libital = 0.15 },
    -- The beaker fill ladder, exactly as beaker.luau's (_cup.dm:452).
    fill_sprites = {
        { 1, "beaker_fill_1" },
        { 20, "beaker_fill_20" },
        { 40, "beaker_fill_40" },
        { 60, "beaker_fill_60" },
        { 80, "beaker_fill_80" },
        { 100, "beaker_fill_100" },
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
                sim.message.send({ recipient = user, message = "The beaker is empty." })
                return true
            end
            sim.matter.transfer({ from = self, to = clicked.entity, amount = 0.25, phases = { "liquid" } })
            sim.message.send({ recipient = user, message = "You pour from the beaker." })
            return true
        end

        local px, py = user.tile.x, user.tile.y
        if x == px and y == py then
            if (total(self) or 0) < 0.001 then
                sim.message.send({ recipient = user, message = "The beaker is empty." })
                return true
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/drink", at = ev.at })
            sim.matter.transfer({ from = self, to = user, amount = 0.05, phases = { "liquid" } })
            sim.message.send({ recipient = user, message = "You drink from the beaker. It tastes like a hospital." })
            return true
        end

        local turf = sim.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" then
            return { replaced = false }
        end
        if (total(self) or 0) < 0.001 then
            sim.message.send({ recipient = user, message = "The beaker is empty." })
            return true
        end
        sim.matter.transfer({ from = self, to = ev.at.matter, amount = "all", phases = { "liquid" } })
        sim.message.send({ recipient = user, message = "You tip the beaker out onto the deck." })
        return true
    end)
end

return content
