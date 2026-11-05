local gas_turbine = require("@lib/gas_turbine")

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
    examine = { flavor = "The input side of a turbine generator, contains the compressor." },
    dense = true,
    states = gas_turbine.STATES,
    state_sprites = {
        closed = "inlet_compressor_closed_s",
        open = "inlet_compressor_open_s",
    },
    facings = gas_turbine.FACINGS,
    facing_sprites = gas_turbine.facing_sprites("inlet_compressor"),
    rotates = { "open" },
    parts = { slots = { "compressor" } },
    transitions = gas_turbine.section_transitions("inlet_compressor"),
}
