local gas_turbine = require("@lib/power/gas_turbine")

-- The gas turbine's input section: it draws the gas in from the tile behind
-- it and compresses it for the rotor. tg's `/obj/machinery/power/turbine/
-- inlet_compressor` (code/modules/power/turbine/turbine.dm:276-332).
--
-- Built on a machine frame from its board; its compressor part is the one
-- socket and goes in at the frame, where tg fits it through the open
-- hatch afterwards (turbine.dm:249-274). Turned with the panel open:
-- tg's wrench (`default_change_direction_wrench`, _machinery.dm:1069-1077)
-- is the Rotate gesture here.
return {
    id = "inlet_compressor",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.inlet_compressor.name",
    name = "inlet compressor",
    sprite = "inlet_compressor_closed_s",
    category = "power",
    script = "inlet_compressor",
    -- tg's desc is turbine.dm:278; this is the pack's own line.
    examine = {
        flavor = "The intake end of a gas turbine. Its blades squeeze the gas "
            .. "before the rotor ever sees it.",
    },
    dense = true,
    -- tg's sections stop air (`can_atmos_pass = ATMOS_PASS_DENSITY`,
    -- turbine.dm:10), so the intake and the exhaust stay apart.
    airtight = true,
    -- The stage's sealed body of gas, tg's 1000 L
    -- (`gas_theoretical_volume`, turbine.dm:297).
    volume_ml = 1000000,
    states = gas_turbine.STATES,
    state_sprites = {
        closed = "inlet_compressor_closed_s",
        open = "inlet_compressor_open_s",
        running = "inlet_compressor_running_s",
    },
    scripted_states = gas_turbine.SCRIPTED_STATES,
    facings = gas_turbine.FACINGS,
    facing_sprites = gas_turbine.facing_sprites("inlet_compressor"),
    rotates = { "open" },
    parts = { slots = { "compressor" } },
    transitions = gas_turbine.section_transitions("inlet_compressor"),
}
