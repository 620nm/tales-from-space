-- The distributable source is the only airlock cycle policy.
return { source = [==[
-- Public access by default. Change this function to deny requests.
local function permitted(request)
    -- For an engineering-only policy, return request.engineering instead.
    return true
end
local commands = {}
local result = { commands = commands }
local state = mem("cycle")
local function command(mac, op, extra)
    local c = extra or {}
    c.mac, c.op, c.id = mac, op, state.id .. ":" .. state.phase
    table.insert(commands, c)
end
local function remember()
    mem("cycle", state)
    return result
end
local function fault()
    for _, d in ipairs(devices) do
        if d.kind == "vent" then command(d.mac, "vent", { on = false }) end
    end
    state.phase = "fault"
    result.status, result.timer = "fault", false
    return remember()
end
if event.kind == "button" then
    -- Consult the guest for every press, including repeats and interruptions.
    if not permitted(event) then
        return { commands = {}, status = "denied", accepted = false }
    end
    local vent, doors, button = nil, {}, nil
    for _, d in ipairs(devices) do
        if d.kind == "vent" then vent = d end
        if d.kind == "door" then table.insert(doors, d) end
        if d.mac == event.mac and d.kind == "button" then button = d end
    end
    local generation = (mem("generation") or 0) + 1
    mem("generation", generation)
    state = { id = tostring(generation), phase = "close" }
    if not vent or #doors ~= 2 or not button then return fault() end
    -- The reference layout runs west (interior) to east (space).
    table.sort(doors, function(a, b) return a.x < b.x end)
    -- Both buttons request the next destination, including during a cycle.
    local inward = mem("last_inward") ~= true
    mem("last_inward", inward)
    state.vent = vent.mac
    state.close = inward and doors[2].mac or doors[1].mac
    state.open = inward and doors[1].mac or doors[2].mac
    state.inward = inward
    command(state.vent, "vent", { on = false })
    local closing = inward and doors[2] or doors[1]
    if closing.door.moving then
        state.phase = "wait_close"
    else
        command(state.close, "bolt", { bolted = false })
        command(state.close, "close")
    end
    result.status, result.replace, result.accepted = "working", true, true
    result.timer = { id = state.id, ticks = 600 }
    return remember()
end
if not state then return result end
if event.kind == "timeout" then
    if event.id == state.id then return fault() end
    return result
end
-- A new request can meet a motor already moving. Wait for its actual rest,
-- then issue the new generation; old completions never advance its later phases.
if state.phase == "wait_close" and event.kind == "door" and event.mac == state.close then
    for _, d in ipairs(devices) do
        if d.mac == state.close and not d.door.moving then
            state.phase = "close"
            command(state.close, "bolt", { bolted = false })
            command(state.close, "close")
            return remember()
        end
    end
    return result
end
if event.id ~= state.id .. ":" .. state.phase then return result end
if state.phase == "fault" or state.phase == "idle" then return result end
if event.kind == "door" then
    local operation = (state.phase == "close" or state.phase == "open") and state.phase or "set_bolted"
    if event.operation ~= operation then return result end
end
if not event.success then return fault() end
local expected = state.phase == "pressure" and state.vent
    or ((state.phase == "open" or state.phase == "bolt_open")
        and state.open or state.close)
if event.mac ~= expected then return result end
if state.phase == "close" then
    state.phase = "bolt_close"
    command(state.close, "bolt", { bolted = true })
elseif state.phase == "bolt_close" then
    state.phase = "pressure"
    command(state.vent, "vent", { on = true, direction = state.inward and "fill" or "drain",
        target = state.inward and 101.325 or 0 })
    command(state.vent, "watch", { target = state.inward and 100 or 10,
        comparison = state.inward and "at_least" or "below", ticks = 500 })
elseif state.phase == "pressure" then
    state.phase = "open"
    command(state.vent, "vent", { on = false })
    command(state.open, "bolt", { bolted = false })
    command(state.open, "open")
elseif state.phase == "open" then
    state.phase = "bolt_open"
    command(state.open, "bolt", { bolted = true })
elseif state.phase == "bolt_open" then
    state.phase = "idle"
    result.status, result.timer = "idle", false
end
return remember()
]==] }
