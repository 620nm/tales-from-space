local gas_turbine = require("@lib/power/gas_turbine")
local gas_turbine_run = require("@lib/power/gas_turbine_run")
local gas_turbine_console = require("@lib/power/gas_turbine_console")
local gas_turbine_service = require("@lib/power/gas_turbine_service")
local gas_turbine_wrench = require("@lib/power/gas_turbine_wrench")

-- The gas turbine's handlers (lib/power/gas_turbine.luau): every section
-- links the line it completes when it stands up (starting a rotor mapped
-- running), hears its own panel and turns to a wrench while it is open
-- (lib/power/gas_turbine_wrench.luau), the core rotor checks its line to
-- a bare hand and answers its `turbine.control` service on the device
-- network (lib/power/gas_turbine_service.luau), and the console picks a
-- rotor on its hub and drives it over that service
-- (lib/power/gas_turbine_console.luau). A section set running takes its
-- turns of the run (lib/power/gas_turbine_run.luau), whose record the rotor keeps.
local content = { id = "gas_turbine" }
if sim ~= nil then
    for _, key in ipairs(gas_turbine.message_keys()) do
        sim.define("message", key, { placeholders = {} })
    end
    for _, key in ipairs(gas_turbine_wrench.message_keys()) do
        sim.define("message", key, { placeholders = {} })
    end
    for _, key in ipairs(gas_turbine_console.message_keys()) do
        sim.define("message", key, { placeholders = {} })
    end
    sim.define("script_var", gas_turbine.LINKED, { replicate = "sight" })
    sim.define("script_var", gas_turbine_console.TARGET, { replicate = "server" })
    for _, row in ipairs(gas_turbine_run.messages()) do
        sim.define("message", row.key, { placeholders = row.placeholders })
    end
    sim.define("script_var", gas_turbine_run.RUN, { replicate = "server" })
    sim.define("script_var", gas_turbine.STARTS_RUNNING, { replicate = "server" })
    for _, id in ipairs(gas_turbine.SECTIONS) do
        local behavior = sim.define("behavior", "lunatic/tfs:" .. id, { prototype = id })
        behavior:handle(
            "entity.initialize.done",
            { kind = "react" },
            function(ev: EntityInitializeDonePayload)
                gas_turbine.on_section_initialized(ev)
                gas_turbine_run.on_section_initialized(ev)
                gas_turbine_service.on_initialized(ev)
            end
        )
        behavior:handle(
            "structure.changed",
            { kind = "react" },
            function(ev: StructureChangedPayload)
                gas_turbine.on_section_changed(ev)
                gas_turbine_run.on_section_changed(ev)
            end
        )
        local use = gas_turbine_wrench.turn
        if id == gas_turbine.CORE then
            use = function(ev: InteractionUsePayload): boolean | { replaced: boolean }
                if gas_turbine_wrench.turn(ev) == true then
                    return true
                end
                return gas_turbine.check_line(ev)
            end
            behavior:handle("examine.lines", { kind = "transform" }, gas_turbine.examine_lines)
            behavior:handle(
                "link.service.delivery",
                { kind = "react" },
                gas_turbine_service.on_delivery
            )
        end
        behavior:handle("interaction.use", { kind = "replace", route = "interact" }, use)
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
    console:handle("link.service.reply", { kind = "react" }, gas_turbine_console.on_reply)
    -- Send verdicts and directory changes name no one console; each
    -- handler filters to its own kind.
    sim.handle("link.service.send.done", { kind = "react" }, gas_turbine_console.on_send_done)
    sim.handle("link.directory.changed", { kind = "react" }, function()
        gas_turbine_service.on_directory_changed()
        gas_turbine_console.on_directory_changed()
    end)
end
return content
