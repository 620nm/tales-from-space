-- Capability-scoped device socket: only joined, reachable members enter the guest.
local controller = {}
-- Opaque task resources only; deadlines and guest state remain entity-owned.
local timers = {}

local function members(host)
    local hs = sim.link_state(host)
    local handles, rows = {}, {}
    if hs == nil or hs.suspended then return handles, rows end
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
    return handles, rows
end

local function finite(n, low, high)
    return type(n) == "number" and n == n and n >= low and n <= high
end
local function token(s)
    return type(s) == "string" and #s > 0 and #s <= 64
end

local function status(host, value)
    if host.vars["controller_status"] == value then return end
    host.vars["controller_status"] = value
    if value == "fault" or value == "denied" then
        sim.message.broadcast({ at = host.tile, radius = 5,
            message = sim.msg(value == "fault" and "lunatic/tfs:lib.controller.fault"
                or "lunatic/tfs:lib.controller.denied", {}) })
    end
end

local function fail(host, handles)
    device_queue.clear(host)
    local commands = {}
    for mac, obj in pairs(handles) do
        if sim.atmos.read(obj) then table.insert(commands, { mac = mac, op = "vent", id = "fault", on = false }) end
    end
    if #commands > 0 then device_queue.send(host, { kind = "device.commands", commands = commands }) end
    status(host, "fault")
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
    for index, command in pairs(result.commands) do
        count += 1
        if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #result.commands
            or type(command) ~= "table" or not token(command.id) then return false end
        local allowed = COMMAND_FIELDS[command.op]
        if allowed == nil or not fields(command, allowed) then return false end
        local obj = handles[command.mac]
        if obj == nil then return false end
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

function controller.cleanup(ev)
    if ev.outcome == "completed" then timers[ev.identity] = nil end
end

function controller.run(host, event)
    local handles, rows = members(host)
    local answer = socket.run(host, "controller", { event = event, devices = rows })
    if not valid(answer, handles) then fail(host, handles); return false end
    if answer.status then status(host, answer.status) end
    if answer.replace then device_queue.clear(host) end
    schedule(host, answer.timer)
    if #answer.commands > 0 then
        if not device_queue.send(host, { kind = "device.commands", commands = answer.commands }) then
            fail(host, handles)
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

local function receive_one(ev, p)
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
    local accepted = controller.run(ev.self, event)
    if event.kind == "button" and accepted then
        local seen = ev.self.vars["controller_request"] or {}
        for mac in pairs(seen) do if handles[mac] == nil then seen[mac] = nil end end
        seen[ev.from] = event.sequence
        ev.self.vars["controller_request"] = seen
    end
end

function controller.message(ev)
    local p = ev.payload
    if type(p) == "table" and (p.kind == "buttons" or p.kind == "completions") then
        if type(p.events) ~= "table" or #p.events > 16 then return end
        for _, request in ipairs(p.events) do
            if type(request) ~= "table" or (request.kind ~= "button" and request.kind ~= "door" and request.kind ~= "pressure") then return end
        end
        for _, request in ipairs(p.events) do receive_one(ev, request) end
    else
        receive_one(ev, p)
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
    if ev.implement ~= nil then return end
    sim.sound.play({ at = ev.subject.tile, asset = "lunatic/tfs:sound/click" })
    local sequence = (sim.var("mod", "button_sequence") or 0) + 1
    sim.script_var.set({ scope = "mod", key = "button_sequence", value = sequence })
    local queued = device_queue.button(ev.subject, { kind = "button", sequence = sequence,
        engineering = sim.has_access(ev.actor, "engineering") })
    if not queued then
        sim.message.send({ recipient = ev.actor, message = sim.msg("lunatic/tfs:lib.controller.busy", {}) })
    end
end

return controller
