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
local SIDES = 6

-- tg's `#define MIN_SIDES_ALERT 5` (dice.dm:1-3): below six sides a die
-- rolls a 1 too often for the remark to stay funny, so it says nothing.
local MIN_SIDES_ALERT = 5

local function comment(result)
    if SIDES > MIN_SIDES_ALERT and result == 1 then
        return " Ouch, bad luck."
    end
    return ""
end

return {
    id = "d6",
    name = "d6",
    sprite = "d6",
    on_use_self = function(ctx, self, user)
        local result = ctx.random(1, SIDES)
        ctx.sound("dice_roll", ctx.pos(user))
        -- tg says this to the roller and a fuller sentence to the room
        -- (dice.dm:102-107). We have no visible-message effect yet, so
        -- only the hand that rolled hears it; see the note in d20.luau.
        ctx.system_msg(user, "You roll the d6. It lands on " .. result .. "." .. comment(result))
    end,
    on_throw_land = function(ctx, self, user, x, y)
        local result = ctx.random(1, SIDES)
        ctx.sound("dice_roll", x, y)
        ctx.system_msg(
            user,
            "The d6 rolls to a stop, landing on " .. result .. "." .. comment(result)
        )
    end,
}
