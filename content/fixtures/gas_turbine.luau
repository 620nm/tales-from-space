local gas_turbine = require("@lib/gas_turbine")

-- The gas turbine's handlers (lib/gas_turbine.luau): every section hears
-- its own panel, the core rotor answers the multitool that links the line,
-- and the console answers the multitool carrying a rotor.
local content = { id = "gas_turbine" }
if sim ~= nil then
    for _, key in ipairs(gas_turbine.message_keys()) do
        sim.define("message", key, { placeholders = {} })
    end
    sim.define("script_var", gas_turbine.LINKED, { replicate = "sight" })
    sim.define("script_var", gas_turbine.CONSOLE_LINK, { replicate = "server" })
    for _, id in ipairs(gas_turbine.SECTIONS) do
        local behavior = sim.define("behavior", "lunatic/tfs:" .. id, { prototype = id })
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
    console:handle("interaction.use", { kind = "replace", route = "interact" }, gas_turbine.link_console)
end
return content
