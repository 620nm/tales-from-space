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
    -- WHAT IT DOES WHEN SOMEBODY OVERFILLS IT. tg's handheld tank
    -- ladder, verbatim: nothing at all below 30 atm, brute damage
    -- between there and 35, and by 35 it is going within a pass
    -- (`handle_tolerances`, code/game/objects/items/tanks/tanks.dm:
    -- 366-368, over TANK_LEAK_PRESSURE / TANK_RUPTURE_PRESSURE,
    -- code/__DEFINES/atmospherics/atmos_piping.dm:60,62). Past 40 atm
    -- the ending is violent rather than merely final
    -- (TANK_FRAGMENT_PRESSURE, :64) -- which the ledger records and
    -- nothing else acts on yet, the blast being unported
    -- (sim/chemistry/failure.rs).
    --
    -- 200 integrity is `/obj/item`'s own (code/game/objects/items.dm:71)
    -- and half of it is where a tank gives (`integrity_failure = 0.5`,
    -- tanks.dm:39): from there it LEAKS -- still a tank, no longer a
    -- sealed one -- and sheds a quarter of what it holds every pass
    -- until it is empty or gone (tanks.dm:342-345).
    --
    -- ONE tg SUBTLETY IS FOLDED IN RATHER THAN BUILT: tg's tank wears
    -- `bomb = 10` armour (`/datum/armor/item_tank`, tanks.dm:68-71),
    -- and `run_atom_armor` takes that 10% off every point of the BOMB
    -- damage this ladder deals -- so a tg tank effectively holds
    -- 200/0.9 = 222 points of it. There is no armour system here and a
    -- vessel does not want one, so the number stays 200 and a tank
    -- here gives up about a tenth sooner than tg's. Noted rather than
    -- silently absorbed, because the day armour lands this is the
    -- comment that says the rating was never rescaled.
    failure = {
        integrity = 200,
        break_at = 0.5,
        leak_kpa = 30 * 101.325,
        rupture_kpa = 35 * 101.325,
        fragment_kpa = 40 * 101.325,
        on_break = "leak",
        -- tg plays this the moment it springs (`playsound(src,
        -- 'sound/effects/spray.ogg', 10, TRUE, -3)`, tanks.dm:386) and
        -- says exactly this (`"[src] springs a leak!"`, tanks.dm:385).
        sound = "spray",
        message = "The tank springs a leak!",
    },
    -- And what the object itself has to say about going: the hiss of a
    -- tank's worth of gas arriving where a tank used to be. What the
    -- failure DID -- the gas in the room, the tank gone, the rows on
    -- the record -- is the engine's and is already done by the time
    -- this runs (docs/LUAU-API.md, `on_rupture`).
    on_rupture = function(ctx, self, user, x, y)
        ctx.sound("spray", x, y)
    end,
    on_use_self = function(ctx, self, user)
        ctx.toggle_internals(user, self)
        gauge(ctx, self, user)
    end,
}
