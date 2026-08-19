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

local function comment(result)
    if SIDES > MIN_SIDES_ALERT and result == 1 then
        return " Ouch, bad luck."
    end
    return ""
end

return {
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
    on_use_self = function(ctx, self, user)
        local result = ctx.random(1, SIDES)
        ctx.sound("dice_roll", ctx.pos(user))
        ctx.set_state(self, tostring(result))
        ctx.system_msg(user, "You roll the d8. It lands on " .. result .. "." .. comment(result))
    end,
    on_throw_land = function(ctx, self, user, x, y)
        local result = ctx.random(1, SIDES)
        ctx.sound("dice_roll", x, y)
        ctx.set_state(self, tostring(result))
        ctx.system_msg(
            user,
            "The d8 rolls to a stop, landing on " .. result .. "." .. comment(result)
        )
    end,
}
