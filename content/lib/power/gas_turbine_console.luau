local actor_context = require("@lib/closets/actor_context")
local gas_turbine = require("@lib/power/gas_turbine")
local gas_turbine_service = require("@lib/power/gas_turbine_service")
local record_lib = require("@lib/power/gas_turbine_record")

-- The turbine console's window: tg's TurbineComputer (turbine_computer.dm
-- ui_data :57-78, ui_act :85-119) as a script document drawn by
-- ui/documents-turbine.ts. The console holds no rotor handle. It keeps
-- the address it is linked to, lists the working turbines on its own
-- hub, and reads and drives the chosen one over its `turbine.control`
-- service, so a dead cord or a released join reads in the window exactly
-- as it reads on the wire. Replies are cached per console and redraw the
-- window; an open window asks again every two seconds, tg's machine tick.
local gas_turbine_console = {}

local CHANNEL = "turbine"
local PRESENTATION = "power/turbine"
-- tg's ui_act names (:86, :102): the switch takes no input, the valve a
-- fraction as text. `select` is this pack's: the address it links to.
local ACTIONS: { [string]: number } = { toggle_power = 0, regulate = 16, select = 32 }
-- tg's machines tick every 2 s (SSmachines), which is also the rotor's pass.
local REFRESH_SECONDS = 2
-- A request longer than this is replaced rather than waited on.
local PENDING_SECONDS = 5

-- The address this console is linked to, as text. An address is an
-- identifier, never a handle: it is re-proved against the live hub on
-- every use (lib/power/gas_turbine_service.luau).
gas_turbine_console.TARGET = "lunatic/tfs:turbine_target"

local MESSAGE = "lunatic/tfs:lib.gas_turbine_console."

-- The run module's refusal words: the reader who pressed hears its
-- sentence for the one a reply names.
local REFUSALS: { [string]: boolean } = {
    not_linked = true,
    running = true,
    not_running = true,
    wrecked = true,
    too_fast = true,
}

-- Every key this module sends, for the roster file to define.
function gas_turbine_console.message_keys(): { string }
    return { MESSAGE .. "unlinked", MESSAGE .. "unreachable" }
end

type Watch = {
    console: Handle,
    readers: { [string]: Handle },
    beat: number,
    status: gas_turbine_service.Status?,
    status_mac: string?,
    pending_op: string?,
    pending_actor: Handle?,
    pending_since: number,
    status_pending_since: number,
}
local watches: { [string]: Watch } = {}
-- A watch whose task missed this many refreshes was canceled outright
-- (the engine's docs/luau-api/runtime.md) and is started afresh.
local STALE_REFRESHES = 2

local function slot(console: Handle): Watch
    local key = tostring(console)
    local current = watches[key]
    if current == nil then
        local created: Watch = {
            console = console,
            readers = {},
            beat = 0,
            pending_since = 0,
            status_pending_since = 0,
        }
        watches[key] = created
        return created
    end
    return current
end

local function selected(console: Handle): string?
    local target = console.vars[gas_turbine_console.TARGET]
    return if type(target) == "string" and target ~= "" then target else nil
end

-- The candidates as the window spells them: a name two rotors share
-- carries its address after it, as the fax directory does.
local function candidates(console: Handle): { gas_turbine_service.Candidate }
    local rows = gas_turbine_service.candidates(console)
    local names: { [string]: number } = {}
    for _, row in ipairs(rows) do
        names[row.name] = (names[row.name] or 0) + 1
    end
    for _, row in ipairs(rows) do
        if names[row.name] > 1 then
            row.name = row.name .. " [" .. row.mac .. "]"
        end
    end
    return rows
end

local function view(console: Handle): { [string]: any }
    local watch = slot(console)
    local target = selected(console)
    local rows: { any } = {}
    local available = false
    for _, row in ipairs(candidates(console)) do
        local mine = row.mac == target
        available = available or mine
        table.insert(rows, { mac = row.mac, name = row.name, selected = mine })
    end
    local out: { [string]: any } = {
        kind = "turbine",
        linked = target ~= nil,
        selected = target,
        available = available,
        candidates = rows,
        connected = false,
    }
    -- A rotor no longer standing on this hub keeps none of its readings:
    -- the cached reply is from a machine this console may not reach.
    local status = watch.status
    if status ~= nil and target ~= nil and watch.status_mac == target and available then
        out.connected = status.connected
        out.active = status.active
        out.rpm = status.rpm
        out.power_w = status.power_w
        out.integrity = status.integrity
        out.max_rpm = status.max_rpm
        out.max_temperature_k = status.max_temperature_k
        out.intake_k = status.intake_k
        out.intake = status.intake
    end
    return out
end

local function refresh(console: Handle): ()
    ui.update_all({ owner = console, channel = CHANNEL, view = view(console), actions = ACTIONS })
end

-- Send one operation at the linked rotor. The reply redraws; a send the
-- link refuses settles in `on_send_done`. A status poll and one reader
-- order may stand at once, each settled by its own answer; an order's
-- answer carries a status too, so a poll never crowds one out.
local function request(console: Handle, op: string, intake: number?, actor: Handle?): boolean
    local target = selected(console)
    if target == nil then
        return false
    end
    local watch = slot(console)
    local now = sim.tick()
    if op == "status" then
        if
            (watch.status_pending_since > 0 and now - watch.status_pending_since <= sim.ticks(PENDING_SECONDS))
            or (watch.pending_op ~= nil and now - watch.pending_since <= sim.ticks(PENDING_SECONDS))
        then
            return false
        end
        watch.status_pending_since = now
    else
        if watch.pending_op ~= nil and now - watch.pending_since <= sim.ticks(PENDING_SECONDS) then
            return false
        end
        watch.pending_op = op
        watch.pending_actor = actor
        watch.pending_since = now
    end
    sim.link.send({
        subject = console,
        to = target,
        service = gas_turbine_service.SERVICE,
        payload = { op = op, intake = intake },
        request = true,
    })
    return true
end

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
    local current = slot(console)
    current.readers[tostring(reader)] = reader
    if sim.tick() - current.beat <= STALE_REFRESHES * sim.ticks(REFRESH_SECONDS) and current.beat > 0 then
        return
    end
    current.beat = sim.tick()
    local key = tostring(console)
    sim.spawn_task(console, function()
        while true do
            sim.sleep(sim.ticks(REFRESH_SECONDS))
            current.beat = sim.tick()
            if not console.alive or not prune(current) then
                break
            end
            if selected(console) ~= nil then
                request(console, "status")
            else
                refresh(console)
            end
        end
        if watches[key] == current then
            watches[key] = nil
        end
    end)
end

local function open(console: Handle, reader: Handle): ()
    watch(console, reader)
    ui.open({
        viewer = reader,
        owner = console,
        channel = CHANNEL,
        view = view(console),
        actions = ACTIONS,
        presentation_key = PRESENTATION,
    })
    request(console, "status")
end

local function say(actor: Handle?, key: string): ()
    if actor ~= nil and actor.alive then
        sim.message.send({ recipient = actor, message = sim.msg(key, {}) })
    end
end

-- `link.service.reply` on the console: a rotor's answer. The cached copy
-- is the window's until the next answer replaces it.
function gas_turbine_console.on_reply(ev: LinkServiceReplyPayload): ()
    local console = ev.self
    if ev.service ~= gas_turbine_service.SERVICE or not console.alive then
        return
    end
    if selected(console) ~= ev.from then
        return
    end
    local watch = slot(console)
    local reply = gas_turbine_service.sanitize_reply(ev.payload)
    if reply == nil then
        watch.status, watch.status_mac = nil, nil
        watch.pending_actor, watch.pending_op = nil, nil
        watch.status_pending_since = 0
        refresh(console)
        return
    end
    -- Only the pending order's own answer settles it; a status answer
    -- beside it settles the poll and refreshes the cache.
    if reply.op == "status" then
        watch.status_pending_since = 0
    end
    local actor: Handle? = nil
    if watch.pending_op == reply.op then
        actor = watch.pending_actor
        watch.pending_actor, watch.pending_op = nil, nil
    end
    watch.status = reply.status
    watch.status_mac = if reply.status ~= nil then ev.from else nil
    if not reply.ok and actor ~= nil and reply.reason ~= nil then
        if REFUSALS[reply.reason] then
            say(actor, record_lib.MESSAGE .. reply.reason)
        elseif reply.op ~= "status" then
            say(actor, MESSAGE .. "unreachable")
        end
    end
    refresh(console)
end

-- A request the link never delivered settles here; the window stops
-- claiming its last reading.
function gas_turbine_console.on_send_done(ev: LinkServiceSendDonePayload): ()
    local console = ev.self
    if
        (console.base or console.prototype) ~= gas_turbine.CONSOLE
        or ev.service ~= gas_turbine_service.SERVICE
        or ev.outcome == "completed"
        or ev.to ~= selected(console)
        or not console.alive
    then
        return
    end
    local watch = watches[tostring(console)]
    if watch == nil then
        return
    end
    -- The verdict names the destination, not which of a poll and an
    -- order to it failed; with both standing it is not blamed on either.
    local ordered = watch.pending_op ~= nil and watch.status_pending_since == 0
    local actor = if ordered then watch.pending_actor else nil
    watch.pending_actor, watch.pending_op = nil, nil
    watch.status_pending_since = 0
    watch.status, watch.status_mac = nil, nil
    say(actor, MESSAGE .. "unreachable")
    refresh(console)
end

-- The candidate list is the forest's; a changed directory redraws it.
function gas_turbine_console.on_directory_changed(): ()
    for key, watch in pairs(watches) do
        if not watch.console.alive then
            watches[key] = nil
        else
            refresh(watch.console)
        end
    end
end

-- `interaction.use` on the console: an empty hand opens it. A tool keeps
-- its own step here, so anything in hand declines.
function gas_turbine_console.use(ev: InteractionUsePayload): boolean | { replaced: boolean }
    if ev.implement ~= nil then
        return { replaced = false }
    end
    open(ev.subject, ev.actor)
    return true
end

-- `interaction.act` on the console's window: pick a rotor, throw its
-- switch, set its valve -- each a service request, each answered by a
-- reply that redraws. The switch's direction reads the last reply, as
-- the button's label did.
function gas_turbine_console.act(ev: InteractionActPayload): boolean | { replaced: boolean }
    if ev.channel ~= CHANNEL then
        return { replaced = false }
    end
    local console, actor = ev.subject, ev.actor
    if ev.action == "select" then
        local wanted = ev.value
        for _, row in ipairs(candidates(console)) do
            if row.mac == wanted then
                console.vars[gas_turbine_console.TARGET] = wanted
                local watch = slot(console)
                watch.status, watch.status_mac = nil, nil
                watch.pending_actor, watch.pending_op = nil, nil
                watch.status_pending_since = 0
                refresh(console)
                request(console, "status")
                return true
            end
        end
        say(actor, MESSAGE .. "unreachable")
        refresh(console)
        return true
    end
    if selected(console) == nil then
        say(actor, MESSAGE .. "unlinked")
        refresh(console)
        return true
    end
    if ev.action == "toggle_power" then
        local watch = slot(console)
        local status = watch.status
        if status == nil or watch.status_mac ~= selected(console) then
            request(console, "status")
            return true
        end
        request(console, if status.active then "stop" else "start", nil, actor)
    elseif ev.action == "regulate" then
        -- tg drops a value that is no number (turbine_computer.dm:103-109);
        -- the rotor clamps the rest to 0.01..1 (:118).
        local fraction = tonumber(ev.value)
        if fraction ~= nil and fraction == fraction and math.abs(fraction) ~= math.huge then
            request(console, "set_intake", fraction, actor)
        end
    else
        return { replaced = false }
    end
    return true
end

return gas_turbine_console
