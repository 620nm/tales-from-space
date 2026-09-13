-- Editable AP controller example for the addressed fax services.
-- `devices` is the direct-member projection; `directory` is the separate,
-- bounded whole-tree service directory. Both contain data only.

local state = mem("fax") or { sequence = 0, pending = 0 }
local result = { commands = {} }

local function chunks(text)
    local out, at, limit = {}, 1, math.min(#text, 8192)
    while at <= limit do
        local finish = math.min(limit, at + 4096 - 1)
        -- Luau strings are bytes. Do not split inside a UTF-8 continuation.
        while finish > at and finish < #text
            and string.byte(text, finish + 1) >= 0x80
            and string.byte(text, finish + 1) <= 0xBF do
            finish -= 1
        end
        table.insert(out, string.sub(text, at, finish))
        at = finish + 1
    end
    return out
end

local function find(service)
    for _, row in ipairs(directory or {}) do
        if row.service == service then return row end
    end
end

local function send_print()
    local destination = find("fax.print")
    if destination == nil then return end
    state.sequence += 1
    state.pending += 1
    local id = "fax:" .. tostring(state.sequence)
    table.insert(result.commands, {
        op = "service", id = id, to = destination.mac,
        service = "fax.print", request = true,
        payload = { chunks = chunks("Printed by an AP-hosted DiSL controller.\n") },
    })
    result.timer = { id = id, ticks = 120 }
end

local function send_loaded()
    local targets = {}
    for _, row in ipairs(directory or {}) do
        if row.service == "fax.send" then table.insert(targets, row) end
    end
    if #targets < 2 then return end
    state.sequence += 1
    state.pending += 1
    local id = "fax:" .. tostring(state.sequence)
    table.insert(result.commands, {
        op = "service", id = id, to = targets[1].mac,
        service = "fax.send", request = true,
        payload = { to = targets[2].mac },
    })
    result.timer = { id = id, ticks = 120 }
end

if event.kind == "button" and event.engineering then
    if state.sequence % 2 == 0 then send_print() else send_loaded() end
elseif event.kind == "service" then
    -- The native reply token is deliberately not copied into guest state.
    -- Native routing authenticated the sender, service and token; this guest
    -- only consumes a bounded service result.
    local payload = type(event.payload) == "table" and event.payload or {}
    if state.pending > 0 and (payload.kind == "fax.printed" or payload.kind == "fax.sent"
        or payload.kind == "fax.failed") then
        state.pending -= 1
        result.status = payload.kind == "fax.failed" and "fault" or "idle"
        result.timer = false
    end
elseif event.kind == "service_done" then
    -- A refused send has no delivery/reply to consume. A completed send still
    -- waits for the endpoint's correlated service result.
    if state.pending > 0 and event.outcome ~= "completed" then
        state.pending -= 1
        result.status = "fault"
        result.timer = false
    end
elseif event.kind == "timeout" and state.pending > 0 then
    state.pending = 0
    result.status = "fault"
end

mem("fax", state)
return result
