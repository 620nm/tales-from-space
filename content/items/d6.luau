-- Six sides, and the whole of what a die does: it is rolled, and then
-- somebody reads it. Ported from tg's `/obj/item/dice/d6`
-- (code/game/objects/items/dice.dm:48-60, 156-157).
--
-- Two hooks, because tg rolls at exactly two moments: `attack_self`
-- rolls it in your hand (dice.dm:68-69), and `throw_impact` rolls it
-- again where it lands (dice.dm:71-75). The second is the entire reason
-- the engine grew a landing hook — a die is a thing whose interesting
-- behaviour happens after it stops moving, and there was no seam for
-- that until now.
--
-- Deliberately not ported: rigging (`rigged`/`rigged_value` and the
-- microwave that sets them, dice.dm:59-60), special faces (fudge dice
-- and the eight-ball, dice.dm:56, 193-198), the dice bag (dice.dm:9),
-- and `/obj/item/dice/d20/fate` with its whole table of magical
-- effects (dice.dm:266-446). What is here is a die.
--
-- No `throw_force`: tg gives dice none, so they inherit `/atom/movable`'s
-- 0 (atoms_movable.dm:86) and a thrown one is a nuisance, never a
-- weapon. `throw_range`/`throw_speed` are tg's defaults too, unstated.
--
-- THE PICTURE FOLLOWS THE ROLL. Each face is a declared appearance
-- state, and both hooks put the die into the one they rolled, so a die
-- lying on the deck shows what it came up. tg does this by pasting the
-- number onto the icon state -- `update_overlays` appends
-- `"[icon_state]-[result]"` (dice.dm:114-116) -- where a name it cannot
-- draw is an invisible object; here the roster is declared and every
-- picture is checked when this file loads.
--
-- Rolling in the HAND sets the state too. That is deliberate and it is
-- also tg's: `attack_self` rolls and updates the same appearance
-- (dice.dm:68-69), and the face is simply what you then see when the
-- die is put down.
local SIDES = 6

-- tg's `#define MIN_SIDES_ALERT 5` (dice.dm:1-3): below six sides a die
-- rolls a 1 too often for the remark to stay funny, so it says nothing.
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
    id = "d6",
    name = "d6",
    -- The resting picture, and the fallback for any state that named no
    -- cell of its own. Six faces name one each, so nothing falls back.
    sprite = "d6",
    -- One state per face, named for the number so a hook can reach it
    -- with `tostring(result)` and nothing has to map between them.
    states = { "1", "2", "3", "4", "5", "6" },
    -- Minted on six, which is the face `sprite = "d6"` is baked showing:
    -- an unrolled die out of the box looks exactly as it did before this
    -- file learned about states.
    state = "6",
    state_sprites = {
        ["1"] = "d6_1",
        ["2"] = "d6_2",
        ["3"] = "d6_3",
        ["4"] = "d6_4",
        ["5"] = "d6_5",
        ["6"] = "d6_6",
    },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local result = math.random(1, SIDES)
        sim.sound.play({ asset = "lunatic/tfs:sound/dice_roll", at = user.tile })
        sim.appearance.set_state({ entity = self, state = tostring(result) })
        -- tg says this to the roller and a fuller sentence to the room
        -- (dice.dm:102-107). We have no visible-message effect yet, so
        -- only the hand that rolled hears it; see the note in d20.luau.
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.d6.roll" .. variant(result), {
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
            message = sim.msg("lunatic/tfs:items.d6.land" .. variant(result), {
                face = result,
            }),
        })
    end)
end

return content
