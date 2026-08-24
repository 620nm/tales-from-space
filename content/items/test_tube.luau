-- The test tube: thirty units, and the vessel you keep a batch in once
-- the beaker is needed for the next one. A rack of these is what a
-- chemist's bench looks like.
--
-- Capacity is tg's `volume = 30` at the documented bridge of
-- 1 u = 0.025 mol (docs/CHEMISTRY.md). The picture is tg's `test_tube`
-- and the fill ladder is its `fill_icon_state = "tube"`, which is why
-- the two names differ: the glass comes off the chemistry sheet and
-- the level off the fillings sheet (_cup.dm:797-806; `volume = 30`
-- at :805).
--
-- The three gestures are the vessel's rather than the beaker's: your
-- own tile is a swig, another vessel within reach is a pour, the deck
-- is a spill. (Content files cannot `require` one another, so each one
-- spells them out; see card.luau on the same tradeoff.)
local U = 0.025

local content = {
    id = "test_tube",
    name = "test tube",
    sprite = "test_tube",
    examine = {
        flavor = "A narrow tube of glass. Where a finished batch waits "
            .. "while the beaker gets on with the next one.",
    },
    capacity_mol = 30 * U,
    -- tg's test tube: `volume = 30` (cups/_cup.dm:805). Narrow enough
    -- that a tube of something warm saturates its own headspace in one
    -- pass and then sits there.
    volume_ml = 30,
    -- tg's cup default `amount_per_transfer_from_this = 10` (_cup.dm:4),
    -- which is also the beaker's gesture: a pour is a pour whatever it
    -- comes out of.
    fill_sprites = {
        { 1, "tube_fill_1" },
        { 20, "tube_fill_20" },
        { 40, "tube_fill_40" },
        { 60, "tube_fill_60" },
        { 80, "tube_fill_80" },
        { 100, "tube_fill_100" },
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
                sim.message.send({ recipient = user, message = "The tube is empty." })
                return true
            end
            sim.pour(self, clicked.entity, 10 * U,
                "The tube is empty.", "The other vessel is full to the brim.")
            sim.message.send({ recipient = user, message = "You pour from the tube." })
            return true
        end

        local px, py = user.tile.x, user.tile.y
        if x == px and y == py then
            if (total(self) or 0) < 0.001 then
                sim.message.send({ recipient = user, message = "The tube is empty." })
                return true
            end
            sim.sound.play({ asset = "lunatic/tfs:sound/drink", at = ev.at })
            sim.drink(self, user, 2 * U)
            sim.message.send({ recipient = user, message = "You drink from the tube." })
            return true
        end

        local turf = sim.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" then
            return { replaced = false }
        end
        if (total(self) or 0) < 0.001 then
            sim.message.send({ recipient = user, message = "The tube is empty." })
            return true
        end
        sim.spill(self, x, y,
            "The tube is empty.", "You can't reach that from here.")
        sim.message.send({ recipient = user, message = "You tip the tube out onto the deck." })
        return true
    end)
end

return content
