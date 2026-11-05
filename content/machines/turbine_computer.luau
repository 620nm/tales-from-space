local gas_turbine = require("@lib/power/gas_turbine")

-- The gas turbine's control console. tg's `/obj/machinery/computer/
-- turbine_computer` (code/modules/power/turbine/turbine_computer.dm): a
-- multitool carrying a core rotor in its buffer links the console to that
-- rotor (:24-37). tg's window (rpm, power, integrity, intake, the power
-- switch, :50-119) reads and drives the native expansion device this pack
-- waits on, so the console opens none yet.
--
-- tg builds consoles on a computer frame finished with two glass panels
-- (code/game/machinery/computer/buildandrepair.dm:18,92); this pack has one
-- frame grammar, so the glass rides the board (items/electronics/
-- machine_board.luau) as the programming terminal's does.
return {
    id = "turbine_computer",
    visual_layer = "fixture",
    energy_network = "power",
    name_label = "lunatic/tfs:entity.turbine_computer.name",
    name = "gas turbine control computer",
    sprite = "turbine_computer",
    script = "turbine_computer",
    -- tg's desc is turbine_computer.dm:3; this is the pack's own line.
    examine = {
        flavor = "A console for running a gas turbine from somewhere it cannot reach you.",
    },
    actions = { gas_turbine.link_console_row() },
    sounds = { teardown = "smash" },
    dense = true,
    corded = true,
    -- tg's two generic rungs (`default_deconstruction_screwdriver`,
    -- _machinery.dm:1049; `default_deconstruction_crowbar`, :912), both
    -- instant; the frame stands up holding the board (the engine's
    -- docs/CONSTRUCTION.md).
    teardown = {
        open = "screwdriver",
        remove = "crowbar",
        into = "machine_frame",
        state = "boarded",
    },
}
