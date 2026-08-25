-- The bare beaker: empty off the shelf, and the vessel everything else
-- on a chem bench is poured into. Capacity is the 50-unit beaker at the
-- documented bridge of 1 u = 0.025 mol (docs/CHEMISTRY.md).
--
-- Three gestures, all of them one click with it in your active hand:
-- your own tile is a swig, another vessel within reach is a pour, and
-- the deck beside you is a spill.
--
-- All three are THE SAME CALL with a different far end (docs/LUAU-API.md
-- section 8.2): `sim.matter.transfer({ from, to, amount, phases })`, where
-- `to` is a body's blood, another vessel, or the room over a tile
-- (`sim.cell`). What differs between a pour and a spill is which owner
-- is named and how much, and nothing else -- the trim against what is
-- there and what fits, the reach check, the proportional draw and the
-- row are all the engine's.
local U = 0.025

local content = {
    id = "beaker",
    name = "beaker",
    sprite = "beaker",
    examine = {
        flavor = "Graduated glass with a lip on it. Whatever a bench is "
            .. "doing, it is doing it in one of these.",
    },
    inhand_sprite = { "held_beaker_l", "held_beaker_r" },
    capacity_mol = 50 * U,
    -- ...and how big the GLASS is, which is a different question and
    -- now a load-bearing one: the space above the liquid is what its
    -- vapour saturates, and therefore how fast an open beaker of
    -- anything volatile gives itself to the room. tg's cup base
    -- declares `volume = 50` (reagent_containers/cups/_cup.dm:6), which
    -- is the same 50 the capacity above is measured in units of -- one
    -- unit is one millilitre, which is what makes the bridge readable.
    volume_ml = 50,
    -- What it shows through the glass. tg's beaker declares
    -- `fill_icon_thresholds = list(0, 1, 20, 40, 60, 80, 100)`
    -- (_cup.dm:452) against the fill sheet's `beaker1`..`beaker100`;
    -- the 0 stop is dropped because nothing on that sheet answers to
    -- it, and below 1% tg draws no fill either.
    fill_sprites = {
        { 1, "beaker_fill_1" },
        { 20, "beaker_fill_20" },
        { 40, "beaker_fill_40" },
        { 60, "beaker_fill_60" },
        { 80, "beaker_fill_80" },
        { 100, "beaker_fill_100" },
    },
    -- Clicking another loose vessel has to reach this hook rather than
    -- picking it up: pouring is a thing you do TO the thing you named.
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

        -- 1. A vessel you pointed at: pour into it.
        if clicked ~= nil and clicked.entity ~= nil then
            if total(clicked.entity) == nil then
                return { replaced = false } -- not something that holds anything
            end
            if (total(self) or 0) < 0.001 then
                sim.message.send({ recipient = user, message = "The beaker is empty." })
                return true
            end
            sim.matter.transfer({ from = self, to = clicked.entity, amount = 0.25, phases = { "liquid" } })
            sim.message.send({ recipient = user, message = "You pour from the beaker." })
            return true
        end

        -- 2. Your own tile: a swig.
        local px, py = user.tile.x, user.tile.y
        if x == px and y == py then
            if (total(self) or 0) < 0.001 then
                sim.message.send({ recipient = user, message = "The beaker is empty." })
                return true
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/drink", at = ev.at })
            sim.matter.transfer({ from = self, to = user, amount = 0.05, phases = { "liquid" } })
            sim.message.send({ recipient = user, message = "You drink from the beaker." })
            return true
        end

        -- 3. The deck beside you: tip it out.
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
