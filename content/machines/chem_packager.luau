-- The chem packager: the extruder that turns a beaker of finished
-- solution into pills you can put in a pocket. tg's
-- `/obj/machinery/chem_master` ("ChemMaster 3000",
-- code/modules/reagents/chemistry/machinery/chem_master.dm:3-8).
--
-- What this file is, is the noun: what it is called, what it looks
-- like, that it is solid and that it runs off the mains. What it DOES
-- is fixtures/chem_packager.luau, which is where the departure from
-- tg's machine is written down at length.
--
-- NO DOCK, deliberately. The two machines beside it on the bench take a
-- vessel INTO a `HolderSlot` and work on it there, because both of them
-- work over time -- a thermostat drives towards a setpoint and a shelf
-- mints into whatever is under the nozzle -- and a slot is what lets
-- them keep working while the chemist walks away. Packaging is one
-- gesture with a beginning and an end, so the beaker stays in the hand
-- that brought it: you hold it against the extruder and it prints.
--
-- WHAT TG'S WINDOW HAS THAT THIS ONE CANNOT SAY: tg's ChemMaster is
-- mostly a separator -- a buffer, a per-reagent transfer, a container
-- picker over pills, patches, bottles and condiment packs, a printed
-- name, and a pill-coating duration (chem_master.dm:283,473,507-539).
-- Every one of those is a window act, and a window act never reaches
-- content (docs/TGUI.md, "Action boundary"): the module roster is the
-- engine's and closed. So this machine has exactly one operation and no
-- window at all, and the parts of tg's panel that are choices wait for
-- the day a packager module exists to carry them.
return {
    id = "chem_packager",
    name = "chem packager",
    sprite = "chem_packager",
    examine = {
        flavor = "A hopper over a slotted extruder, with a tray at the "
            .. "bottom for what comes out. It only knows one shape.",
    },
    dense = true,
    corded = true,
    -- Its own file: a packager is not a vending machine and must never
    -- learn to be one.
    script = "chem_packager",
}
