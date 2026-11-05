local gas_turbine = require("@lib/gas_turbine")

-- The gas turbine's middle section and its brain: it checks that the line
-- is whole and is what the console links to. tg's `/obj/machinery/power/turbine/core_rotor`
-- (code/modules/power/turbine/turbine.dm:382-685).
--
-- Built on a machine frame from its board; its rotor part is the one
-- socket and goes in at the frame, where tg fits it through the open
-- hatch afterwards (turbine.dm:249-274). Turned with the panel open:
-- tg's wrench (`default_change_direction_wrench`, _machinery.dm:1069-1077)
-- is the Rotate gesture here.
return {
    id = "core_rotor",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.core_rotor.name",
    name = "core rotor",
    sprite = "core_rotor_closed_s",
    category = "power",
    script = "core_rotor",
    examine = {
        flavor = "The middle part of a turbine generator, contains the rotor and the "
            .. "main computer.",
    },
    actions = { gas_turbine.link_parts_row() },
    dense = true,
    states = gas_turbine.STATES,
    state_sprites = {
        closed = "core_rotor_closed_s",
        open = "core_rotor_open_s",
    },
    facings = gas_turbine.FACINGS,
    facing_sprites = gas_turbine.facing_sprites("core_rotor"),
    rotates = { "open" },
    parts = { slots = { "rotor" } },
    transitions = gas_turbine.section_transitions("core_rotor"),
}
