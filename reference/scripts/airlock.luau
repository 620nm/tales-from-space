-- AIRLOCK: west is the station, east is space. Either button changes direction.
-- This program runs again for each button press, door report, or pressure report.
-- event describes that report; devices lists the equipment joined to this box.
-- local gives a value a name. A table, written { ... }, groups related values.

-- A function is a named set of instructions. Change this one to control access.
local function permitted(request)
    -- Replace the next line with: return request.engineering
    -- to require engineering access. true allows a press; false refuses it.
    return true
end

local commands = {}
local result = { commands = commands }
-- mem remembers values between reports: one argument reads, two arguments save.
local state = mem("cycle")

-- Add an instruction to the outgoing list. mac is the equipment's address.
-- Each instruction carries a cycle number and step so old replies are ignored.
local function command(mac, operation, settings)
    local instruction = settings or {}
    instruction.mac = mac
    instruction.op = operation
    instruction.id = state.id .. ":" .. state.phase
    table.insert(commands, instruction)
end

local function remember()
    mem("cycle", state)
    return result
end

-- Stop pumping on trouble. Never assume a stuck door has shut safely.
local function fault()
    for _, device in ipairs(devices) do
        if device.kind == "vent" then
            command(device.mac, "vent", { on = false })
        end
    end
    state.phase = "fault"
    result.status = "fault"
    result.timer = false
    return remember()
end

-- BUTTON PRESS: choose a destination and close the door on the other side.
if event.kind == "button" then
    if not permitted(event) then
        return { commands = {}, status = "denied", accepted = false }
    end

    local vent = nil
    local doors = {}
    local button = nil
    -- ipairs visits each entry in a list; table.insert adds an entry to a list.
    for _, device in ipairs(devices) do
        if device.kind == "vent" then vent = device end
        if device.kind == "door" then table.insert(doors, device) end
        if device.kind == "button" and device.mac == event.mac then
            button = device
        end
    end

    local cycle_number = (mem("generation") or 0) + 1
    mem("generation", cycle_number)
    state = { id = tostring(cycle_number), phase = "close" }
    -- #doors counts the doors. We need exactly two and a working button and vent.
    if not vent or #doors ~= 2 or not button then return fault() end

    table.sort(doors, function(a, b) return a.x < b.x end)
    local interior = doors[1]
    local exterior = doors[2]
    -- The first accepted press requests entry. Every later press reverses it.
    local inward = mem("last_inward") ~= true
    mem("last_inward", inward)
    local closing = interior
    local opening = exterior
    if inward then
        closing = exterior
        opening = interior
    end
    state.vent = vent.mac
    state.close = closing.mac
    state.open = opening.mac
    state.inward = inward

    command(state.vent, "vent", { on = false })
    if closing.door.moving then
        state.phase = "wait_close"
    else
        command(state.close, "bolt", { bolted = false })
        command(state.close, "close")
    end
    result.status = "working"
    result.replace = true
    result.accepted = true
    result.timer = { id = state.id, ticks = 600 }
    return remember()
end

-- Without a previous button press there is no cycle to continue.
if not state then return result end
if event.kind == "timeout" then
    if event.id == state.id then return fault() end
    return result
end

-- A second press may catch a door in motion. Wait for it to stop, then close it.
if state.phase == "wait_close" and event.kind == "door" and event.mac == state.close then
    for _, device in ipairs(devices) do
        if device.mac == state.close and not device.door.moving then
            state.phase = "close"
            command(state.close, "bolt", { bolted = false })
            command(state.close, "close")
            return remember()
        end
    end
    return result
end

-- Only the report for the current cycle and step may move us forward.
if event.id ~= state.id .. ":" .. state.phase then return result end
if state.phase == "fault" or state.phase == "idle" then return result end
if event.kind == "door" then
    local operation = "set_bolted"
    if state.phase == "close" or state.phase == "open" then
        operation = state.phase
    end
    if event.operation ~= operation then return result end
end
if not event.success then return fault() end

local expected_address = state.close
if state.phase == "pressure" then
    expected_address = state.vent
elseif state.phase == "open" or state.phase == "bolt_open" then
    expected_address = state.open
end
if event.mac ~= expected_address then return result end

-- CYCLE STEPS: shut, secure, change pressure, open, secure again.
-- elseif chooses the first matching step; it does not run every step at once.
if state.phase == "close" then
    state.phase = "bolt_close"
    command(state.close, "bolt", { bolted = true })

elseif state.phase == "bolt_close" then
    state.phase = "pressure"
    local direction = "drain"
    local pump_target = 0
    local safe_pressure = 10
    local comparison = "below"
    if state.inward then
        direction = "fill"
        pump_target = 101.325
        safe_pressure = 100
        comparison = "at_least"
    end
    -- Pressures are in kPa. The watch reports when it is safe to open.
    command(state.vent, "vent", {
        on = true, direction = direction, target = pump_target,
    })
    command(state.vent, "watch", {
        target = safe_pressure, comparison = comparison, ticks = 500,
    })

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
    result.status = "idle"
    result.timer = false
end

return remember()
