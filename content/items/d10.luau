-- Ten sides. tg: "Useful for percentages."
-- (`/obj/item/dice/d10`, code/game/objects/items/dice.dm:212-216) --
-- which is true only in the pair it is half of, since a percentile roll
-- is this die read as the units beside a d00 read as the tens. Both are
-- in the bag (items/dice_bag.luau) for exactly that reason.
--
-- d6.luau is the family header. This is that shape at ten.
local SIDES = 10

-- tg's `#define MIN_SIDES_ALERT 5` (dice.dm:1-3): below six sides a die
-- rolls a 1 too often for the remark to stay funny. d10 is over it.
local MIN_SIDES_ALERT = 5

local function comment(result)
    if SIDES > MIN_SIDES_ALERT and result == 1 then
        return " Ouch, bad luck."
    end
    return ""
end

local content = {
    id = "d10",
    name = "d10",
    sprite = "d10",
    states = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" },
    -- Minted on 10: the face `sprite = "d10"` is baked showing.
    state = "10",
    state_sprites = {
        ["1"] = "d10_1",
        ["2"] = "d10_2",
        ["3"] = "d10_3",
        ["4"] = "d10_4",
        ["5"] = "d10_5",
        ["6"] = "d10_6",
        ["7"] = "d10_7",
        ["8"] = "d10_8",
        ["9"] = "d10_9",
        ["10"] = "d10_10",
    },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local result = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = user.tile })
        sim.appearance.set_state({ entity = self, state = tostring(result) })
        sim.message.send({ recipient = user, message = "You roll the d10. It lands on " .. result .. "." .. comment(result) })
        return true
    end)
    script_definition:handle("throw.land.done", { kind = "react", route = "land" }, function(ev)
        local self, user, x, y = ev.entity, ev.thrower, ev.at.x, ev.at.y
        local result = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = ev.at })
        sim.appearance.set_state({ entity = self, state = tostring(result) })
        sim.message.send({ recipient = user, message = "The d10 rolls to a stop, landing on " .. result .. "." .. comment(result) })
    end)
end

return content
