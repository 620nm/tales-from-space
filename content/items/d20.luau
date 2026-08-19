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
-- on it at all (dice.dm:103-109). The engine's only text effect is
-- `ctx.system_msg`, which speaks to ONE player, so a roll here is
-- private to whoever caused it. A visible-message effect belongs beside
-- the speech/hearing seam (one rule for who hears what, already
-- implemented once for `say`), not bolted on for a toy — so the toy
-- ships with the narrower message and this note.
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

return {
    id = "d20",
    name = "d20",
    sprite = "d20",
    on_use_self = function(ctx, self, user)
        local result = ctx.random(1, SIDES)
        ctx.sound("dice_roll", ctx.pos(user))
        ctx.system_msg(user, "You roll the d20. It lands on " .. result .. "." .. comment(result))
    end,
    on_throw_land = function(ctx, self, user, x, y)
        local result = ctx.random(1, SIDES)
        ctx.sound("dice_roll", x, y)
        ctx.system_msg(
            user,
            "The d20 rolls to a stop, landing on " .. result .. "." .. comment(result)
        )
    end,
}
