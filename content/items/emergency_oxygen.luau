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

return {
    id = "emergency_oxygen",
    name = "emergency oxygen tank",
    sprite = "emergency_oxygen",
    ui = { modules = { "held_tank" } },
    inhand_sprite = { "held_emergency_oxygen_l", "held_emergency_oxygen_r" },
    -- tg tanks.dm:26-27.
    pickup_sound = "gas_tank_pickup",
    drop_sound = "gas_tank_drop",
    gas_tank = {
        volume_l = 3,
        fill = { { substance = "o2", kpa = 10 * 101.325 } },
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
    -- (sim/holder/pressure_failure.rs).
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
    -- The activate-in-hand key, which is where tg puts the valve
    -- (`toggle_internals` off the tank's own action button) -- and
    -- then the panel tg opens from the other one
    -- (`attack_self_secondary` -> `ui_interact`, tanks.dm:431-433),
    -- because "handle your bottle" is one gesture here and the panel
    -- is the gauge: what is in it, what it reads, and the release
    -- valve a breath is drawn at. Whether the valve OPENS is the
    -- engine's to decide: apparatus on the face, tank on the body,
    -- body alive. Closing is never refused, and neither is looking.
    on_use_self = function(ctx, self, user)
        ctx.toggle_internals(user, self)
        ctx.open_ui(user, self)
    end,
}
