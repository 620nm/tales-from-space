local gas_turbine = require("@lib/power/gas_turbine")
local gas_turbine_console = require("@lib/power/gas_turbine_console")

-- The gas turbine's handlers (lib/power/gas_turbine.luau): every section
-- links the line it completes when it stands up and hears its own panel,
-- the core rotor answers the multitool that links the line, and the console
-- answers the multitool carrying a rotor and opens its window to an empty
-- hand (lib/power/gas_turbine_console.luau).
local content = { id = "gas_turbine" }
if sim ~= nil then
    for _, key in ipairs(gas_turbine.message_keys()) do
        sim.define("message", key, { placeholders = {} })
    end
    for _, key in ipairs(gas_turbine_console.message_keys()) do
        sim.define("message", key, { placeholders = {} })
    end
    sim.define("script_var", gas_turbine.LINKED, { replicate = "sight" })
    sim.define("script_var", gas_turbine.CONSOLE_LINK, { replicate = "server" })
    for _, id in ipairs(gas_turbine.SECTIONS) do
        local behavior = sim.define("behavior", "lunatic/tfs:" .. id, { prototype = id })
        behavior:handle(
            "entity.initialize.done",
            { kind = "react" },
            gas_turbine.on_section_initialized
        )
        behavior:handle("structure.changed", { kind = "react" }, gas_turbine.on_section_changed)
        if id == gas_turbine.CORE then
            behavior:handle(
                "interaction.use",
                { kind = "replace", route = "interact" },
                gas_turbine.link_parts
            )
        end
    end
    local console = sim.define(
        "behavior",
        "lunatic/tfs:" .. gas_turbine.CONSOLE,
        { prototype = gas_turbine.CONSOLE }
    )
    console:handle(
        "interaction.use",
        { kind = "replace", route = "interact" },
        gas_turbine_console.use
    )
    console:handle("interaction.act", { kind = "replace", route = "act" }, gas_turbine_console.act)
end
return content
