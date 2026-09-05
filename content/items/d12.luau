-- Twelve sides, and tg is unkind about it: "There's an air of neglect
-- about it." (`/obj/item/dice/d12`, code/game/objects/items/dice.dm:
-- 224-228). It is the solid nobody's table has a use for and every set
-- ships with, which is the joke and also the reason it is in the bag.
--
-- d6.luau is the family header. This is that shape at twelve.
local SIDES = 12

-- tg's `#define MIN_SIDES_ALERT 5` (dice.dm:1-3): below six sides a die
-- rolls a 1 too often for the remark to stay funny. d12 is over it.
local MIN_SIDES_ALERT = 5

-- Which of this die's lines a face reads under. A bad roll is a
-- DIFFERENT sentence rather than a clause glued onto one, so the whole
-- line is authored per outcome (docs/LOCALIZATION.md 5).
local function variant(result)
    if SIDES > MIN_SIDES_ALERT and result == 1 then
        return "_bad"
    end
    return ""
end

local content = {
    id = "d12",
    name = "d12",
    sprite = "d12",
    states = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12" },
    -- Minted on 12: the face `sprite = "d12"` is baked showing.
    state = "12",
    state_sprites = {
        ["1"] = "d12_1",
        ["2"] = "d12_2",
        ["3"] = "d12_3",
        ["4"] = "d12_4",
        ["5"] = "d12_5",
        ["6"] = "d12_6",
        ["7"] = "d12_7",
        ["8"] = "d12_8",
        ["9"] = "d12_9",
        ["10"] = "d12_10",
        ["11"] = "d12_11",
        ["12"] = "d12_12",
    },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local result = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = user.tile })
        sim.appearance.set_state({ entity = self, state = tostring(result) })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.d12.roll" .. variant(result), {
                face = result,
            }),
        })
        return true
    end)
    script_definition:handle("throw.land.done", { kind = "react", route = "land" }, function(ev)
        local self, user, x, y = ev.entity, ev.thrower, ev.at.x, ev.at.y
        local result = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = ev.at })
        sim.appearance.set_state({ entity = self, state = tostring(result) })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.d12.land" .. variant(result), {
                face = result,
            }),
        })
    end)
end

return content
