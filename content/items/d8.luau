-- Eight sides. tg's whole description is "It feels... lucky."
-- (`/obj/item/dice/d8`, code/game/objects/items/dice.dm:206-210) and
-- that is the entire design document.
--
-- d6.luau is this family's header -- two hooks, one appearance state
-- per face, the picture following the roll. This file is that shape at
-- eight, and the only thing worth reading here is that eight is over
-- tg's `MIN_SIDES_ALERT`, so a 1 still earns the remark.
local SIDES = 8

-- tg's `#define MIN_SIDES_ALERT 5` (dice.dm:1-3): below six sides a die
-- rolls a 1 too often for the remark to stay funny. d8 is over it.
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
    id = "d8",
    name = "d8",
    sprite = "d8",
    states = { "1", "2", "3", "4", "5", "6", "7", "8" },
    -- Minted on 8: the face `sprite = "d8"` is baked showing.
    state = "8",
    state_sprites = {
        ["1"] = "d8_1",
        ["2"] = "d8_2",
        ["3"] = "d8_3",
        ["4"] = "d8_4",
        ["5"] = "d8_5",
        ["6"] = "d8_6",
        ["7"] = "d8_7",
        ["8"] = "d8_8",
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
            message = sim.msg("lunatic/tfs:items.d8.roll" .. variant(result), {
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
            message = sim.msg("lunatic/tfs:items.d8.land" .. variant(result), {
                face = result,
            }),
        })
    end)
end

return content
