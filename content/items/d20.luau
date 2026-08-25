-- Twenty sides: "the preferred die to throw at the GM" (tg's own desc,
-- `/obj/item/dice/d20`, code/game/objects/items/dice.dm:227-231).
--
-- The same two hooks as the d6 and one more remark: tg's `diceroll`
-- special-cases a natural twenty (dice.dm:92-93), which is the only
-- reason anybody keeps one of these in a pocket.
--
-- KNOWN GAP, and it is this file's to flag rather than to fix: tg's
-- roll is a `visible_message` — the die announces itself to everyone
-- who can see it, and a thrown one announces itself with nobody's hand
-- on it at all (dice.dm:103-109). This file still speaks with
-- `sim.message.send`, which reaches ONE player, so a roll here is
-- private to whoever caused it. `sim.message.broadcast` is the room
-- form and the mechanism the announcement wants; switching to it is a
-- content change with a sentence to write for the bystanders, not a
-- missing engine seam.
--
-- What is no longer a gap: the picture follows the roll. Twenty faces
-- are twenty declared appearance states, and both hooks put the die
-- into the one they rolled — so even where the SENTENCE reaches only
-- one player, the die on the deck shows its number to anyone who walks
-- past. See d6.luau for the whole of how, and tg's own
-- `"[icon_state]-[result]"` overlay at dice.dm:114-116 for the shape
-- this was ported from.
local SIDES = 20
local MIN_SIDES_ALERT = 5

local function comment(result)
    -- Order matters and is tg's: the natural twenty is assigned second
    -- and would win the tie if a die ever had both (dice.dm:90-93).
    if SIDES > MIN_SIDES_ALERT and result == 1 then
        return " Ouch, bad luck."
    end
    if SIDES == 20 and result == 20 then
        return " NAT 20!"
    end
    return ""
end

local content = {
    id = "d20",
    name = "d20",
    sprite = "d20",
    states = {
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
        "11", "12", "13", "14", "15", "16", "17", "18", "19", "20",
    },
    -- Minted on twenty, the face `sprite = "d20"` is baked showing —
    -- and the only number anybody wants a fresh one to be sitting on.
    state = "20",
    state_sprites = {
        ["1"] = "d20_1",
        ["2"] = "d20_2",
        ["3"] = "d20_3",
        ["4"] = "d20_4",
        ["5"] = "d20_5",
        ["6"] = "d20_6",
        ["7"] = "d20_7",
        ["8"] = "d20_8",
        ["9"] = "d20_9",
        ["10"] = "d20_10",
        ["11"] = "d20_11",
        ["12"] = "d20_12",
        ["13"] = "d20_13",
        ["14"] = "d20_14",
        ["15"] = "d20_15",
        ["16"] = "d20_16",
        ["17"] = "d20_17",
        ["18"] = "d20_18",
        ["19"] = "d20_19",
        ["20"] = "d20_20",
    },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local result = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = user.tile })
        sim.appearance.set_state({ entity = self, state = tostring(result) })
        sim.message.send({ recipient = user, message = "You roll the d20. It lands on " .. result .. "." .. comment(result) })
        return true
    end)
    script_definition:handle("throw.land.done", { kind = "react", route = "land" }, function(ev)
        local self, user, x, y = ev.entity, ev.thrower, ev.at.x, ev.at.y
        local result = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = ev.at })
        sim.appearance.set_state({ entity = self, state = tostring(result) })
        sim.message.send({ recipient = user, message = "The d20 rolls to a stop, landing on " .. result .. "." .. comment(result) })
    end)
end

return content
