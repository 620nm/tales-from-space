local gas_turbine = require("@lib/power/gas_turbine")

-- The gas turbine's output section: it expels the spent gas onto the tile
-- ahead of it. tg's `/obj/machinery/power/turbine/turbine_outlet`
-- (code/modules/power/turbine/turbine.dm:335-379).
--
-- Built on a machine frame from its board; its stator part is the one
-- socket and goes in at the frame, where tg fits it through the open
-- hatch afterwards (turbine.dm:249-274). Turned with the panel open:
-- tg's wrench (`default_change_direction_wrench`, _machinery.dm:1069-1077)
-- is the Rotate gesture here.
return {
    id = "turbine_outlet",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.turbine_outlet.name",
    name = "turbine outlet",
    sprite = "turbine_outlet_closed_s",
    category = "power",
    script = "turbine_outlet",
    -- tg's desc is turbine.dm:337; this is the pack's own line.
    examine = {
        flavor = "The exhaust end of a gas turbine. Spent gas leaves through it, "
            .. "colder than it came in.",
    },
    dense = true,
    -- tg's sections stop air (`can_atmos_pass = ATMOS_PASS_DENSITY`,
    -- turbine.dm:10), so the intake and the exhaust stay apart.
    airtight = true,
    states = gas_turbine.STATES,
    state_sprites = {
        closed = "turbine_outlet_closed_s",
        open = "turbine_outlet_open_s",
        running = "turbine_outlet_running_s",
    },
    scripted_states = gas_turbine.SCRIPTED_STATES,
    facings = gas_turbine.FACINGS,
    facing_sprites = gas_turbine.facing_sprites("turbine_outlet"),
    rotates = { "open" },
    parts = { slots = { "stator" } },
    transitions = gas_turbine.section_transitions("turbine_outlet"),
}
