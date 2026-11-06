local gas_turbine = require("@lib/power/gas_turbine")
local gas_turbine_wrench = require("@lib/power/gas_turbine_wrench")

-- The gas turbine's middle section and its brain: it checks that the line
-- is whole, is what the console links to, and feeds the grid while it
-- turns. tg's `/obj/machinery/power/turbine/core_rotor`
-- (code/modules/power/turbine/turbine.dm:382-685).
--
-- Built on a machine frame from its board; its rotor part is the one
-- socket and goes in at the frame, where tg fits it through the open
-- hatch afterwards (turbine.dm:249-274). A wrench turns it with the panel
-- open (lib/power/gas_turbine_wrench.luau), and only a wrench: it declares
-- no Alt+click turn, as tg's sections have none (_machinery.dm:1069-1077).
return {
    id = "core_rotor",
    visual_layer = "fixture",
    -- A source on the cable under it, its watts set by the running loop
    -- (lib/power/gas_turbine_turns.luau; tg `add_avail`, turbine.dm:685).
    energy_network = "power",
    output_w = 0,
    name_label = "lunatic/tfs:entity.core_rotor.name",
    name = "core rotor",
    sprite = "core_rotor_closed_s",
    category = "power",
    script = "core_rotor",
    -- tg's desc is turbine.dm:384; this is the pack's own line.
    examine = {
        flavor = "The heart of a gas turbine: the shaft the hot gas spins, and the "
            .. "electronics that keep the three sections in step.",
    },
    actions = { gas_turbine.link_parts_row(), gas_turbine_wrench.turn_row() },
    dense = true,
    -- tg's sections stop air (`can_atmos_pass = ATMOS_PASS_DENSITY`,
    -- turbine.dm:10), so the intake and the exhaust stay apart.
    airtight = true,
    -- The stage's sealed body of gas, tg's 3000 L
    -- (`gas_theoretical_volume`, turbine.dm:418).
    volume_ml = 3000000,
    states = gas_turbine.STATES,
    state_sprites = {
        closed = "core_rotor_closed_s",
        open = "core_rotor_open_s",
        running = "core_rotor_running_s",
    },
    scripted_states = gas_turbine.SCRIPTED_STATES,
    facings = gas_turbine.FACINGS,
    facing_sprites = gas_turbine.facing_sprites("core_rotor"),
    parts = { slots = { "rotor" } },
    -- What a map may place: a rotor already turning, its first run started
    -- once its line links at stand-up (the engine's
    -- docs/content-schema/placement.md; lib/power/gas_turbine_run.luau).
    placement = {
        running = {
            var = gas_turbine.STARTS_RUNNING,
            kind = "flag",
            default = false,
            label = "lunatic/tfs:editor.core_rotor.running",
        },
    },
    transitions = gas_turbine.section_transitions("core_rotor"),
}
