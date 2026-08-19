-- Four sides. tg calls it "the nerd's caltrop" and means it literally:
-- `/obj/item/dice/d4` fits a caltrop component that does 1-4 brute to
-- anybody who walks over it (code/game/objects/items/dice.dm:132-142).
-- Deliberately not ported -- a caltrop is a check on the MOVEMENT seam,
-- one rule for every sharp thing on the deck, not a hook a single die
-- carries. The die ships; the tack in the carpet waits for the seam.
--
-- The rest is d6.luau, which is this family's header: two hooks because
-- tg rolls at exactly two moments (`attack_self` in the hand and
-- `throw_impact` where it lands, dice.dm:68-75), one declared appearance
-- state per face, and the picture following the roll rather than being
-- pasted onto an icon name. Read that file for the whole of why.
--
-- WHAT IS MISSING HERE and is present on every bigger die: the remark.
-- tg only comments on a roll when `sides > MIN_SIDES_ALERT` (5,
-- dice.dm:1-3, 90-91), and four is under it -- rolling the worst face
-- one time in four is not bad luck, it is Tuesday. So this file has no
-- `comment` function at all, and that absence is the port.
local SIDES = 4

return {
    id = "d4",
    name = "d4",
    sprite = "d4",
    states = { "1", "2", "3", "4" },
    -- Minted on four: the face `sprite = "d4"` is baked showing.
    state = "4",
    state_sprites = {
        ["1"] = "d4_1",
        ["2"] = "d4_2",
        ["3"] = "d4_3",
        ["4"] = "d4_4",
    },
    on_use_self = function(ctx, self, user)
        local result = ctx.random(1, SIDES)
        ctx.sound("dice_roll", ctx.pos(user))
        ctx.set_state(self, tostring(result))
        ctx.system_msg(user, "You roll the d4. It lands on " .. result .. ".")
    end,
    on_throw_land = function(ctx, self, user, x, y)
        local result = ctx.random(1, SIDES)
        ctx.sound("dice_roll", x, y)
        ctx.set_state(self, tostring(result))
        ctx.system_msg(user, "The d4 rolls to a stop, landing on " .. result .. ".")
    end,
}
