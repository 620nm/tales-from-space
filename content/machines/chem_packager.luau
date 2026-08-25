-- The chem packager: the extruder that turns a beaker of finished
-- solution into pills you can put in a pocket. tg's
-- `/obj/machinery/chem_master` ("ChemMaster 3000",
-- code/modules/reagents/chemistry/machinery/chem_master.dm:3-8).
--
-- What this file is, is the noun: what it is called, what it looks
-- like, that it is solid, that it runs off the mains, that it holds a
-- vessel, and what its one button says. What it DOES is
-- fixtures/chem_packager.luau, which is where the departure from tg's
-- machine is written down at length.
--
-- A DOCK AND A BUTTON, like the two machines beside it on the bench.
-- tg's ChemMaster takes the beaker in (`beaker.forceMove(src)`,
-- chem_master.dm) and prints from the machine rather than from your
-- hand, and so does this: `chem.device = "slot"` is a dock with no
-- instrument over it, and `ui.actions` is the one operation the machine
-- offers. The window draws what is standing in it, the eject button
-- that hands it back, and `package`.
--
-- WHAT TG'S WINDOW HAS THAT THIS ONE DOES NOT: tg's ChemMaster is
-- mostly a separator -- a buffer, a per-reagent transfer, a container
-- picker over pills, patches, bottles and condiment packs, a printed
-- name, and a pill-coating duration (chem_master.dm:283,473,507-539).
-- Each of those is another button and another number, and the number
-- half needs a setpoint whose ends are native state; this machine has
-- the one operation and takes the whole vessel, which is the shape the
-- pack wants and not a limit it ran into.
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
    chem = {
        device = "slot",
    },
    ui = {
        modules = { "dock", "actions" },
        actions = {
            { key = "package", label = "package" },
        },
    },
    -- Its own file: a packager is not a vending machine and must never
    -- learn to be one.
    script = "chem_packager",
}
