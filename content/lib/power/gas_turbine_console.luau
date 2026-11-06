local actor_context = require("@lib/closets/actor_context")
local gas_turbine = require("@lib/power/gas_turbine")
local gas_turbine_run = require("@lib/power/gas_turbine_run")
local multitool_buffer = require("@lib/tools/multitool_buffer")

-- The turbine console's window: tg's TurbineComputer (turbine_computer.dm
-- ui_data :57-78, ui_act :85-119) as a script document drawn by
-- ui/documents-turbine.ts. It reads the linked rotor only through
-- `gas_turbine_run.readout` and acts only through its start, stop and
-- set_intake. An open window refreshes every two seconds, tg's machine tick.
local gas_turbine_console = {}

local CHANNEL = "turbine"
local PRESENTATION = "power/turbine"
-- tg's ui_act names (:86, :102): the switch takes no input, the valve a
-- fraction as text.
local ACTIONS: { [string]: number } = { toggle_power = 0, regulate = 16 }
-- tg's machines tick every 2 s (SSmachines), which is also the rotor's pass.
local REFRESH_SECONDS = 2

local MESSAGE = "lunatic/tfs:lib.gas_turbine_console."

-- Every key this module sends, for the roster file to define.
function gas_turbine_console.message_keys(): { string }
    return { MESSAGE .. "unlinked" }
end

-- The rotor the console holds a link to, if it still stands (tg
-- `turbine_core?.resolve()`).
local function rotor_of(console: Handle): Handle?
    local rotor = multitool_buffer.resolve(console.vars[gas_turbine.CONSOLE_LINK])
    if rotor == nil or not rotor.alive then
        return nil
    end
    if (rotor.base or rotor.prototype) ~= gas_turbine.CORE then
        return nil
    end
    return rotor
end

local function view(console: Handle): { [string]: any }
    local rotor = rotor_of(console)
    if rotor == nil then
        return { kind = "turbine", linked = false }
    end
    local reading = gas_turbine_run.readout(rotor)
    return {
        kind = "turbine",
        linked = true,
        connected = reading.connected,
        active = reading.active,
        rpm = reading.rpm,
        power_w = reading.power_w,
        integrity = reading.integrity,
        max_rpm = reading.max_rpm,
        max_temperature_k = reading.max_temperature_k,
        intake_k = reading.intake_k,
        intake = reading.intake,
    }
end

local function refresh(console: Handle): ()
    ui.update_all({ owner = console, channel = CHANNEL, view = view(console), actions = ACTIONS })
end

-- Who each console's window may still be open for, keyed by the console;
-- a reader past arm's reach has had theirs closed (the engine's
-- docs/tgui/documents.md, Lifecycle and status). `beat` is the tick its
-- refresh task last woke.
type Watch = { console: Handle, readers: { [string]: Handle }, beat: number }
local watches: { [string]: Watch } = {}
-- A watch whose task missed this many refreshes was cancelled outright
-- (the engine's docs/luau-api/runtime.md) and is started afresh.
local STALE_REFRESHES = 2

local function prune(watch: Watch): boolean
    local any = false
    for key, reader in pairs(watch.readers) do
        if reader.alive and actor_context.adjacent(reader, watch.console) then
            any = true
        else
            watch.readers[key] = nil
        end
    end
    return any
end

-- One refresh task per console with a reader near it; it ends when the
-- console goes or the last reader walks away, and a dead one is replaced.
local function watch(console: Handle, reader: Handle): ()
    local key = tostring(console)
    local current = watches[key]
    local now = sim.tick()
    if current ~= nil then
        current.readers[tostring(reader)] = reader
        if now - current.beat <= STALE_REFRESHES * sim.ticks(REFRESH_SECONDS) then
            return
        end
    end
    local readers = if current ~= nil then current.readers else { [tostring(reader)] = reader }
    local started: Watch = { console = console, readers = readers, beat = now }
    watches[key] = started
    sim.spawn_task(console, function()
        while true do
            sim.sleep(sim.ticks(REFRESH_SECONDS))
            started.beat = sim.tick()
            if not console.alive or not prune(started) then
                break
            end
            refresh(console)
        end
        if watches[key] == started then
            watches[key] = nil
        end
    end)
end

local function open(console: Handle, reader: Handle): ()
    ui.open({
        viewer = reader,
        owner = console,
        channel = CHANNEL,
        view = view(console),
        actions = ACTIONS,
        presentation_key = PRESENTATION,
    })
    watch(console, reader)
end

-- `interaction.use` on the console: a multitool links it
-- (lib/power/gas_turbine.luau `link_console`); an empty hand opens it.
function gas_turbine_console.use(ev: InteractionUsePayload): boolean | { replaced: boolean }
    if ev.implement ~= nil then
        return gas_turbine.link_console(ev)
    end
    open(ev.subject, ev.actor)
    return true
end

-- A refusal is the run module's own sentence; the console only carries it.
local function refused(actor: Handle, ok: boolean, reason: string?): ()
    if not ok and reason ~= nil then
        sim.message.send({ recipient = actor, message = sim.msg(reason, {}) })
    end
end

-- `interaction.act` on the console's window: tg's `toggle_power` and
-- `regulate` (turbine_computer.dm:86-119). The run module refuses a start
-- on a broken or unpowered line and a stop above 1000 rpm.
function gas_turbine_console.act(ev: InteractionActPayload): boolean | { replaced: boolean }
    if ev.channel ~= CHANNEL then
        return { replaced = false }
    end
    local console, actor = ev.subject, ev.actor
    local rotor = rotor_of(console)
    if rotor == nil then
        sim.message.send({ recipient = actor, message = sim.msg(MESSAGE .. "unlinked", {}) })
    elseif ev.action == "toggle_power" then
        if gas_turbine_run.readout(rotor).active then
            refused(actor, gas_turbine_run.stop(rotor, actor))
        else
            refused(actor, gas_turbine_run.start(rotor, actor))
        end
    elseif ev.action == "regulate" then
        -- tg drops a value that is no number (:103-109); the run module
        -- clamps the rest to 0.01..1 (:118).
        local fraction = tonumber(ev.value)
        if fraction ~= nil and fraction == fraction and math.abs(fraction) ~= math.huge then
            gas_turbine_run.set_intake(rotor, fraction)
        end
    else
        return { replaced = false }
    end
    refresh(console)
    return true
end

return gas_turbine_console
