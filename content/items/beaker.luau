-- The bare beaker: empty off the shelf, and the vessel everything else
-- on a chem bench is poured into. Fifty millilitres of glass, which is
-- the whole of what it holds.
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
local content = {
    id = "beaker",
    name = "beaker",
    sprite = "beaker",
    examine = {
        flavor = "Graduated glass with a lip on it. Whatever a bench is "
            .. "doing, it is doing it in one of these.",
    },
    inhand_sprite = { "held_beaker_l", "held_beaker_r" },
    -- How big the GLASS is, which is the whole of how much it holds:
    -- what fits is what the liquid takes up, and the space left above
    -- it is what a vapour saturates -- and therefore how fast an open
    -- beaker of anything volatile gives itself to the room. tg's cup
    -- base declares `volume = 50` (reagent_containers/cups/_cup.dm:6);
    -- one of tg's units is one millilitre.
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
        -- What is in it, in moles: the reading's own total, which is
        -- the same sum over the same mixture (sim/owner.rs, `reading`).
        -- `nil` for a thing with no inside at all.
        local function total(obj)
            local read = sim.matter_read(obj)
            return read and read.moles
        end

        -- 1. A vessel you pointed at: pour into it.
        if clicked ~= nil and clicked.entity ~= nil then
            if total(clicked.entity) == nil then
                return { replaced = false } -- not something that holds anything
            end
            -- ...unless it is a FIXTURE standing full of gas, which is
            -- a charge and not a pour (items/bottle.luau). A beaker
            -- cannot take one: a mouth with no stopper in it lets the
            -- charge back out on the next exchange, so this is refused
            -- in the same words the dispenser uses over an open glass
            -- (docs/BENCH.md 4). `kind` is the engine's word for
            -- what was pointed at -- an `item` is carried, a `machine`
            -- is bolted down -- and never a name for any one of them.
            if clicked.kind == "machine" then
                sim.message.send({
                    recipient = user,
                    message = "That would only escape: seal a vessel first.",
                })
                return true
            end
            if (total(self) or 0) < 0.001 then
                sim.message.send({ recipient = user, message = "The beaker is empty." })
                return true
            end
            sim.matter.transfer({ from = self, to = clicked.entity, amount = 0.25, phases = { "liquid", "solid" } })
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
            sim.matter.transfer({ from = self, to = user, amount = 0.05, phases = { "liquid", "solid" } })
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
        sim.matter.transfer({ from = self, to = ev.at.matter, amount = "all", phases = { "liquid", "solid" } })
        sim.message.send({ recipient = user, message = "You tip the beaker out onto the deck." })
        return true
    end)
end

return content
