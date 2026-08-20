-- The blue bottle: seventy litres at six atmospheres, worn on the back
-- in place of a pack. This is the one you take outside -- twenty-odd
-- times what the pocket bottle holds, which is the difference between
-- getting to the breach and getting back from it.
--
-- tg: /obj/item/tank/internals/oxygen (code/game/objects/items/tanks/
-- tank_types.dm:26-38), filled with oxygen at 6*ONE_ATMOSPHERE (:38)
-- and distributing at TANK_DEFAULT_RELEASE_PRESSURE (:32). Its volume
-- is TANK_STANDARD_VOLUME (tanks.dm:45, defined 70 at
-- code/__DEFINES/atmospherics/atmos_piping.dm:46) -- stated here
-- anyway, because a station standard that is only implied is a number
-- nobody can find.
--
-- ON THE BACK, like tg's ITEM_SLOT_BACK (tanks.dm:23): wearing one
-- costs you the backpack, which is the trade tg makes and the reason
-- the pocket bottle exists at all. A tank in a worn slot feeds the
-- lungs exactly as one in a hand does, so a suited crewman keeps both
-- hands for the job.

-- tg tanks.dm:159. See emergency_oxygen.luau for why the readout rides
-- the valve gesture rather than an examine hook.
local function gauge(ctx, self, user)
    local kpa = ctx.tank_kpa(self)
    if not kpa then
        return
    end
    local hundredths = math.floor(kpa * 100 + 0.5) / 100
    ctx.system_msg(user, "The pressure gauge reads " .. tostring(hundredths) .. " kPa.")
end

return {
    id = "oxygen_tank",
    name = "oxygen tank",
    sprite = "oxygen_tank",
    inhand_sprite = { "held_oxygen_tank_l", "held_oxygen_tank_r" },
    -- tg tanks.dm:26-27.
    pickup_sound = "gas_tank_pickup",
    drop_sound = "gas_tank_drop",
    slot = "back",
    worn_sprite = "worn_oxygen_tank",
    gas_tank = {
        volume_l = 70,
        fill = { { substance = "o2", kpa = 6 * 101.325 } },
    },
    on_use_self = function(ctx, self, user)
        ctx.toggle_internals(user, self)
        gauge(ctx, self, user)
    end,
}
