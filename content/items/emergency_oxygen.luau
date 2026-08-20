-- The bottle every crewman wakes up with: three litres at ten
-- atmospheres, which is about twenty breaths and not one more. It is
-- not equipment, it is the reason a hull breach is a bad afternoon
-- rather than a death.
--
-- tg: /obj/item/tank/internals/emergency_oxygen (code/game/objects/
-- items/tanks/tank_types.dm:166-183) -- 3 L (:179), filled with oxygen
-- at 10*ONE_ATMOSPHERE (:183), distributing at
-- TANK_DEFAULT_RELEASE_PRESSURE (:178), small enough for a pocket
-- (:176) and carried on the belt (:175). Weight class and slot fit are
-- not things a prototype can say here yet, so this one rides the kit
-- like any other packed item; the numbers that DO exist are tg's.
--
-- The valve is left unstated because 16 kPa is already the engine's
-- default, and tg's own file sets it from the same define rather than
-- from a number.

-- tg tanks.dm:159, and the whole of what a tank tells you: what the
-- gauge on it reads, rounded the way tg rounds it. There is no examine
-- hook in the v0 surface (docs/luau-api.md lists seven, and examine is
-- not one), so the readout rides the gesture that already reaches for
-- the tank -- which is honest either way round, because content is not
-- told whether the valve it asked for actually opened.
local function gauge(ctx, self, user)
    local kpa = ctx.tank_kpa(self)
    if not kpa then
        return
    end
    local hundredths = math.floor(kpa * 100 + 0.5) / 100
    ctx.system_msg(user, "The pressure gauge reads " .. tostring(hundredths) .. " kPa.")
end

return {
    id = "emergency_oxygen",
    name = "emergency oxygen tank",
    sprite = "emergency_oxygen",
    inhand_sprite = { "held_emergency_oxygen_l", "held_emergency_oxygen_r" },
    -- tg tanks.dm:26-27.
    pickup_sound = "gas_tank_pickup",
    drop_sound = "gas_tank_drop",
    gas_tank = {
        volume_l = 3,
        fill = { { substance = "o2", kpa = 10 * 101.325 } },
    },
    -- The activate-in-hand key, which is where tg puts the valve too
    -- (`toggle_internals` off the tank's own click). Whether it opens
    -- is the engine's to decide: apparatus on the face, tank on the
    -- body, body alive. Closing is never refused.
    on_use_self = function(ctx, self, user)
        ctx.toggle_internals(user, self)
        gauge(ctx, self, user)
    end,
}
