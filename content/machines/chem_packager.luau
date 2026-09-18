-- Dock and product controls; fixtures/chem_packager.luau owns operations.
-- See docs/PETROCHEMISTRY.md and docs/CHEMISTRY.md.
-- tg: code/modules/reagents/chemistry/machinery/chem_master.dm:3-8.
return {
    id = "chem_packager",
    visual_layer = "fixture",
    energy_network = "power",
    name_label = "lunatic/tfs:entity.chem_packager.name",
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
            {
                key = "make_resin_pellet",
                label = "lunatic/tfs:action.chem_packager.make_resin_pellet",
            },
            {
                key = "mold_plastic_sheet",
                label = "lunatic/tfs:action.chem_packager.mold_plastic_sheet",
            },
            {
                key = "make_toner_cartridge",
                label = "lunatic/tfs:action.chem_packager.make_toner_cartridge",
            },
        },
    },
    -- Its own file: a packager is not a vending machine and must never
    -- learn to be one.
    script = "chem_packager",
}
