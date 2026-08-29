-- One physical machine-board shell, programmed for the machine or
-- structure it will make a frame become. The variants are identities,
-- not procedures: the generic frame reads the installed board's target
-- and requirements, while each product keeps its own behavior in its
-- machine or structure file.
--
-- Stock-part sockets are derived from each product's `parts.slots`
-- (docs/CONTENT-SCHEMA.md §1.10b). A board lists only stack materials
-- which have no socket of their own.
return {
    id = "machine_board",
    name = "unprogrammed machine board",
    sprite = "board",
    inhand_sprite = { "held_board_l", "held_board_r" },
    category = "machine components",
    variants = {
        chem_dispenser = {
            name = "machine board (chem dispenser)",
            -- tg machine_circuitboards.dm:752-762. The two matter bins,
            -- capacitor and servo are product sockets; the pane remains.
            board = {
                machine = "chem_dispenser",
                parts = { glass = 1 },
            },
        },
        chem_heater = {
            name = "machine board (reaction chamber)",
            -- tg machine_circuitboards.dm:803-809. Its micro-laser is a
            -- product socket and the pane is the remaining stack part.
            board = {
                machine = "chem_heater",
                parts = { glass = 1 },
            },
        },
        chemdrobe = {
            name = "machine board (ChemDrobe)",
            board = { machine = "chemdrobe" },
        },
        games_vendor = {
            name = "machine board (Good Clean Fun)",
            board = { machine = "games_vendor" },
        },
        nanomed_plus = {
            name = "machine board (NanoMed Plus)",
            board = { machine = "nanomed_plus" },
        },
        thermomachine = {
            name = "machine board (temperature control unit)",
            -- tg machine_circuitboards.dm:406-415. The bins and lasers
            -- are sockets; cable and glass are stack materials. This
            -- target is a structure because it occupies a pipe run.
            board = {
                structure = "thermomachine",
                parts = {
                    cable_coil = 1,
                    glass = 1,
                },
            },
        },
        tool_vendor = {
            name = "machine board (YouTool)",
            board = { machine = "tool_vendor" },
        },
        tv = {
            name = "machine board (television)",
            board = { machine = "tv" },
        },
        vendor = {
            name = "machine board (vending)",
            board = { machine = "vendor" },
        },
    },
}
