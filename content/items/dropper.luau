-- The dropper: five units of anything, moved a unit at a time. The
-- precision end of the bench, where the beaker is the bulk end.
--
-- Capacity is tg's `volume = 5` at the documented bridge of 1 u = 0.025
-- mol (docs/CHEMISTRY.md); the picture is tg's `dropper0`
-- (dropper.dm:5,10).
--
-- ONE UNIT A SQUEEZE, which is the bottom of tg's own
-- `possible_transfer_amounts = list(1, 2, 3, 4, 5)` (dropper.dm:9)
-- rather than its default of 5. A dropper that emptied itself in one
-- click would be a slower beaker; the reason the thing exists is that
-- it can move less than a beaker can. tg spells the choice as a dial
-- and this bench has no dial on a vessel yet, so the file takes the
-- useful end of tg's list and the dial is deferred.
--
-- The three gestures are the beaker's, because they are the vessel's
-- rather than the beaker's: your own tile is a swig, another vessel
-- within reach is a pour, the deck is a spill. (Content files cannot
-- `require` one another, so each one spells them out; see card.luau on
-- the same tradeoff.)
local U = 0.025

local content = {
    id = "dropper",
    name = "dropper",
    sprite = "dropper",
    examine = {
        flavor = "A glass pipette under a rubber bulb. For the doses a "
            .. "beaker is too generous to measure.",
    },
    capacity_mol = 5 * U,
    -- tg's dropper: `volume = 5` (reagent_containers/dropper.dm:10).
    volume_ml = 5,
    -- tg's dropper has no `fill_icon_thresholds` at all: it overrides
    -- `update_overlays` to add the one `dropper` state whenever there
    -- is anything in it (dropper.dm:87-93). Five units is too small a
    -- bulb to draw a level in, so the ladder here is one rung.
    fill_sprites = {
        { 1, "dropper_fill" },
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
                sim.message.send({ recipient = user, message = "The dropper is empty." })
                return true
            end
            sim.pour(self, clicked.entity, 1 * U,
                "The dropper is empty.", "The other vessel is full to the brim.")
            sim.message.send({ recipient = user, message = "You squeeze a drop out of the dropper." })
            return true
        end

        local px, py = user.tile.x, user.tile.y
        if x == px and y == py then
            if (total(self) or 0) < 0.001 then
                sim.message.send({ recipient = user, message = "The dropper is empty." })
                return true
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/drink", at = ev.at })
            sim.drink(self, user, 1 * U)
            sim.message.send({ recipient = user, message = "You squeeze the dropper onto your tongue." })
            return true
        end

        local turf = sim.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" then
            return { replaced = false }
        end
        if (total(self) or 0) < 0.001 then
            sim.message.send({ recipient = user, message = "The dropper is empty." })
            return true
        end
        sim.spill(self, x, y,
            "The dropper is empty.", "You can't reach that from here.")
        sim.message.send({ recipient = user, message = "You squeeze the dropper out onto the deck." })
        return true
    end)
end

return content
