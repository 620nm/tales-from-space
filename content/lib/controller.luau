-- Capability-scoped controller program slot: only joined, reachable members enter the guest.
local controller = {}
-- Opaque task resources only; deadlines and guest state remain entity-owned.
local timers = {}
local pending_services = {}

local function members(host)
    for key, pending in pairs(pending_services) do
        if pending.host == nil or not pending.host.alive then pending_services[key] = nil end
    end
    local hs = sim.link_state(host)
    local handles, rows, directory = {}, {}, {}
    if hs == nil or hs.suspended then return handles, rows, directory end
    local reach = {}
    for _, obj in ipairs(sim.query.link_reach(host)) do
        local state = sim.link_state(obj)
        if state then reach[state.mac] = true end
    end
    for _, obj in ipairs(sim.query.link_members(host)) do
        local state = sim.link_state(obj)
        if state and not state.suspended and reach[state.mac] then
            local door = sim.door.state(obj)
            local vent = sim.atmos.read(obj)
            local kind = door and "door" or (vent and "vent" or (state.class == "control_button" and "button"))
            if kind then
                handles[state.mac] = obj
                table.insert(rows, { mac = state.mac, kind = kind, x = obj.tile.x, y = obj.tile.y,
                    door = door, vent = vent })
            end
        end
    end
    -- Keep the service directory separate from direct members. A reachable
    -- service may be behind another endpoint and still be a legal target.
    for _, service in ipairs({ "fax.print", "fax.send" }) do
        local cursor = 0
        local pages = 0
        repeat
            local page = sim.query.link_directory(host, service, cursor)
            for _, row in ipairs(page.rows or {}) do
                table.insert(directory, { mac = row.mac, service = row.service, name = row.name })
            end
            cursor = page.next
            pages += 1
        until cursor == nil or pages >= 32
    end
    return handles, rows, directory
end

local function finite(n, low, high)
    return type(n) == "number" and n == n and n >= low and n <= high
end
local function token(s)
    return type(s) == "string" and #s > 0 and #s <= 64
        and not s:find("%c")
end
local function address(s)
    return type(s) == "string" and #s == 17 and s == s:lower()
        and s:match("^%x%x%-%x%x%-%x%x%-%x%x%-%x%x%-%x%x$") ~= nil
end

-- The statuses a room hears. A button event's `voice` repeats one to every
-- press, said at the pressed button's tile, once per packet (`said`).
local STATUS_LINES = {
    fault = "lunatic/tfs:lib.controller.fault",
    denied = "lunatic/tfs:lib.controller.denied",
    unprogrammed = "lunatic/tfs:lib.controller.unprogrammed",
}
local function status(host, value, voice)
    local line = STATUS_LINES[value]
    if host.vars["controller_status"] == value and not (voice and line) then return end
    host.vars["controller_status"] = value
    if line == nil or (voice and voice.said[value]) then return end
    if voice then voice.said[value] = true end
    sim.message.broadcast({ at = if voice then voice.at else host.tile, radius = 5, message = sim.msg(line, {}) })
end

local function fail(host, handles, why, voice)
    device_queue.clear(host)
    local commands = {}
    for mac, obj in pairs(handles) do
        if sim.atmos.read(obj) then table.insert(commands, { mac = mac, op = "vent", id = "fault", on = false }) end
    end
    if #commands > 0 then device_queue.send(host, { kind = "device.commands", commands = commands }) end
    status(host, why, voice)
    host.vars["controller_timer"] = nil
    local key = tostring(host)
    if timers[key] then timers[key].task:cancel(); timers[key] = nil end
end

local function fields(value, allowed)
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
end
local COMMAND_FIELDS = {
    open = { mac = true, op = true, id = true },
    close = { mac = true, op = true, id = true },
    bolt = { mac = true, op = true, id = true, bolted = true },
    vent = { mac = true, op = true, id = true, on = true, direction = true, target = true },
    watch = { mac = true, op = true, id = true, target = true, comparison = true, ticks = true },
    -- The controller host originates an addressed service request. `to` is
    -- data and native link.send checks the live tree and advertisement again.
    service = { op = true, id = true, to = true, service = true, payload = true,
        request = true },
}

-- Validate the complete plan before applying any of it.
local function valid(result, handles)
    if type(result) ~= "table" or type(result.commands) ~= "table" or #result.commands > 6 then return false end
    if not fields(result, { commands = true, status = true, timer = true, replace = true, accepted = true }) then return false end
    if result.accepted ~= nil and type(result.accepted) ~= "boolean" then return false end
    if result.replace ~= nil and type(result.replace) ~= "boolean" then return false end
    if result.status ~= nil and result.status ~= "idle" and result.status ~= "working"
        and result.status ~= "denied" and result.status ~= "fault" then return false end
    if result.timer ~= nil and result.timer ~= false then
        if type(result.timer) ~= "table" or not fields(result.timer, { id = true, ticks = true }) or not token(result.timer.id)
            or not finite(result.timer.ticks, 1, 1200) or result.timer.ticks % 1 ~= 0 then return false end
    end
    local count = 0
    local services = 0
    for index, command in pairs(result.commands) do
        count += 1
        if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #result.commands
            or type(command) ~= "table" or not token(command.id) then return false end
        local allowed = COMMAND_FIELDS[command.op]
        if allowed == nil or not fields(command, allowed) then return false end
        local obj = handles[command.mac]
        if command.op ~= "service" and obj == nil then return false end
        if command.op == "open" or command.op == "close" then
            if sim.door.state(obj) == nil then return false end
        elseif command.op == "bolt" then
            if sim.door.state(obj) == nil or type(command.bolted) ~= "boolean" then return false end
        elseif command.op == "vent" then
            if sim.atmos.read(obj) == nil or type(command.on) ~= "boolean" then return false end
            if command.on and (not finite(command.target, 0, 1000)
                or (command.direction ~= "fill" and command.direction ~= "drain")) then return false end
        elseif command.op == "watch" then
            if sim.atmos.read(obj) == nil or not finite(command.target, 0, 1000)
                or (command.comparison ~= "at_least" and command.comparison ~= "below")
                or not finite(command.ticks, 1, 1200) or command.ticks % 1 ~= 0 then return false end
        elseif command.op == "service" then
            services += 1
            if services > 1 then return false end
            if not address(command.to) or not token(command.service)
                or type(command.request) ~= "boolean" or command.payload == nil then return false end
        else return false end
    end
    return count == #result.commands
end

local function schedule(host, timer)
    if timer == nil then return end
    for identity, row in pairs(timers) do
        if not row.host.alive then timers[identity] = nil end
    end
    local key = tostring(host)
    if timers[key] then
        timers[key].task:cancel()
        timers[key] = nil
    end
    if timer == false then host.vars["controller_timer"] = nil; return end
    local due = sim.tick() + timer.ticks
    host.vars["controller_timer"] = { id = timer.id, due = due }
    local task = sim.spawn_task(host, function()
        sim.sleep(math.max(1, due - sim.tick()))
        timers[key] = nil
        local current = host.vars["controller_timer"]
        if current and current.id == timer.id and current.due == due then
            host.vars["controller_timer"] = nil
            controller.run(host, { kind = "timeout", id = current.id })
        end
    end)
    timers[key] = { host = host, task = task }
end

-- `voice` is set for a button event only (see `status`).
function controller.run(host, event, voice)
    local service_state = pending_services[tostring(host)]
    if event.kind == "timeout" and service_state and service_state.active
        and service_state.active.id == event.id then
        if service_state.active.token == nil then
            service_state.active.abandoned = true
        else
            service_state.active = nil
        end
    end
    local handles, rows, directory = members(host)
    -- An empty slot stops the cycle like a fault, but names the cause.
    if sim.disl.slot_program(host, "controller") == nil then
        fail(host, handles, "unprogrammed", voice)
        return false
    end
    local answer = program_slot.run(host, "controller", {
        event = event, devices = rows, directory = directory,
    })
    if not valid(answer, handles) then fail(host, handles, "fault", voice); return false end
    if answer.status then status(host, answer.status, voice) end
    if answer.replace then device_queue.clear(host) end
    schedule(host, answer.timer)
    local device_commands = {}
    for _, command in ipairs(answer.commands) do
        if command.op == "service" then
            local key = tostring(host)
            local pending = pending_services[key] or { host = host, active = nil }
            if pending.active ~= nil then
                -- A second request cannot be admitted while its native token
                -- is outstanding. Refuse it at the bridge boundary without
                -- re-entering the guest (which could request it again).
                status(host, "fault", voice)
            else
                pending.active = command
            end
            pending_services[key] = pending
        else
            table.insert(device_commands, command)
        end
    end
    local pending = pending_services[tostring(host)]
    if pending and pending.active ~= nil and pending.active.sent ~= true then
        local command = pending.active
        command.sent = true
        sim.link.send({ subject = host, to = command.to, service = command.service,
            payload = command.payload, request = command.request })
    end
    if #device_commands > 0 then
        if not device_queue.send(host, { kind = "device.commands", commands = device_commands }) then
            fail(host, handles, "fault", voice)
        end
    end
    return answer.accepted == true
end

function controller.device(ev)
    local state = sim.link_state(ev.self)
    local p = ev.payload
    if state == nil or state.suspended or state.parent ~= ev.from or type(p) ~= "table"
        or p.kind ~= "device.commands" or type(p.commands) ~= "table" or #p.commands > 64 then return end
    local commands = {}
    for _, command in ipairs(p.commands) do
        if type(command) == "table" and command.mac == state.mac then table.insert(commands, command) end
    end
    local handles = { [state.mac] = ev.self }
    if not valid({ commands = commands }, handles) then return end
    for _, command in ipairs(commands) do
        local obj = handles[command.mac]
        if command.op == "open" then sim.door.open({ subject = obj, request_id = command.id })
        elseif command.op == "close" then sim.door.close({ subject = obj, request_id = command.id })
        elseif command.op == "bolt" then
            sim.door.set_bolted({ subject = obj, request_id = command.id, bolted = command.bolted })
        elseif command.op == "vent" then
            local args = { entity = obj, on = command.on }
            if command.on then
                args.target_kpa = command.target
                args.release_below_kpa = command.direction == "fill" and command.target or 0
                args.siphon_above_kpa = command.direction == "drain" and command.target or 1000
            end
            sim.atmos.configure(args)
        elseif command.op == "watch" then
            sim.atmos.watch_pressure({ entity = obj, request_id = command.id, target_kpa = command.target,
                comparison = command.comparison, timeout_ticks = command.ticks })
        end
    end
end

local function receive_one(ev, p, said)
    if type(p) ~= "table" or (p.kind ~= "button" and p.kind ~= "door" and p.kind ~= "pressure") then return end
    local handles = members(ev.self)
    local sender = handles[ev.from]
    if sender == nil then return end
    local event = { kind = p.kind, mac = ev.from }
    if p.kind == "button" then
        if sim.link_state(sender).class ~= "control_button" or type(p.engineering) ~= "boolean"
            or not finite(p.sequence, 1, 9007199254740991) or p.sequence % 1 ~= 0 then return end
        local seen = ev.self.vars["controller_request"] or {}
        if p.sequence <= (seen[ev.from] or 0) then return end
        event.sequence = p.sequence
        event.engineering = p.engineering
    elseif p.kind == "door" then
        if not sim.door.state(sender) or not token(p.id) or type(p.success) ~= "boolean"
            or (p.operation ~= "open" and p.operation ~= "close" and p.operation ~= "set_bolted") then return end
        event.id, event.success, event.operation = p.id, p.success, p.operation
    else
        if not sim.atmos.read(sender) or not token(p.id) or type(p.success) ~= "boolean" then return end
        event.id, event.success = p.id, p.success
    end
    local voice = if event.kind == "button" then { at = sender.tile, said = said } else nil
    local accepted = controller.run(ev.self, event, voice)
    if event.kind == "button" and accepted then
        local seen = ev.self.vars["controller_request"] or {}
        for mac in pairs(seen) do if handles[mac] == nil then seen[mac] = nil end end
        seen[ev.from] = event.sequence
        ev.self.vars["controller_request"] = seen
    end
end

function controller.message(ev)
    local p = ev.payload
    if ev.service ~= nil then
        -- Addressed traffic has its service name in the native occurrence,
        -- not in the portable payload. Present one bounded guest event for
        -- both delivery and private reply anchors.
        if not token(ev.service) or p == nil then return end
        local key = tostring(ev.self)
        local pending = pending_services[key]
        local active = pending and pending.active
        if active == nil or active.token == nil or ev.correlation == nil
            or active.token ~= ev.correlation or active.service ~= ev.service
            or active.to ~= ev.from then return end
        local payload = type(p) == "table" and p or {}
        local expected = active.service == "fax.print" and "fax.printed"
            or (active.service == "fax.send" and "fax.sent" or nil)
        if payload.kind ~= expected and payload.kind ~= "fax.failed" then return end
        if active.abandoned then pending.active = nil; pending_services[key] = nil; return end
        pending.active = nil
        pending_services[key] = nil
        controller.run(ev.self, {
            kind = "service", service = ev.service, payload = payload,
            request_id = active.id,
        })
    elseif type(p) == "table" and (p.kind == "buttons" or p.kind == "completions") then
        if type(p.events) ~= "table" or #p.events > 16 then return end
        for _, request in ipairs(p.events) do
            if type(request) ~= "table" or (request.kind ~= "button" and request.kind ~= "door" and request.kind ~= "pressure") then return end
        end
        local said = {}
        for _, request in ipairs(p.events) do receive_one(ev, request, said) end
    else
        receive_one(ev, p, {})
    end
end

function controller.service_send_done(ev)
    if ev.self == nil or sim.disl.slot_program(ev.self, "controller") == nil then return end
    if not token(ev.service) or not token(ev.outcome) then return end
    local key = tostring(ev.self)
    local pending = pending_services[key]
    local active = pending and pending.active
    if active == nil or active.to ~= ev.to or active.service ~= ev.service then return end
    if active.abandoned then pending.active = nil; pending_services[key] = nil; return end
    if ev.outcome == "completed" and ev.requested and ev.correlation ~= nil then
        active.token = ev.correlation
        return
    end
    if ev.outcome == "completed" then
        pending.active = nil
        pending_services[key] = nil
        return
    end
    if ev.outcome ~= "completed" then
        pending.active = nil
        pending_services[key] = nil
        controller.run(ev.self, { kind = "service", service = ev.service,
            payload = { kind = "fax.failed" }, request_id = active.id })
    end
end

function controller.door(ev)
    if ev.success and ev.operation == "set_bolted" then
        sim.sound.play({ at = ev.subject.tile, asset = ev.bolted
            and "lunatic/tfs:sound/airlock_bolts_down" or "lunatic/tfs:sound/airlock_bolts_up" })
    end
    device_queue.completion(ev.subject, { kind = "door", id = ev.request_id,
        operation = ev.operation, success = ev.success })
end
function controller.pressure(ev)
    device_queue.completion(ev.entity, { kind = "pressure", id = ev.request_id, success = ev.success })
end
function controller.button(ev)
    sim.sound.play({ at = ev.subject.tile, asset = "lunatic/tfs:sound/click" })
    -- Every press takes a number; hosts dedupe per sender, so a hostless one costs nothing.
    local sequence = (sim.var("mod", "button_sequence") or 0) + 1
    sim.script_var.set({ scope = "mod", key = "button_sequence", value = sequence })
    -- Nothing joined above, or cut off: no host will ever hear this press.
    local state = sim.link_state(ev.subject)
    if state == nil or state.suspended or state.parent == nil then
        sim.message.send({ recipient = ev.actor, message = sim.msg("lunatic/tfs:lib.controller.unanswered", {}) })
        return
    end
    local queued = device_queue.button(ev.subject, { kind = "button", sequence = sequence,
        engineering = sim.has_access(ev.actor, "engineering") })
    if not queued then
        sim.message.send({ recipient = ev.actor, message = sim.msg("lunatic/tfs:lib.controller.busy", {}) })
    end
end

return controller
